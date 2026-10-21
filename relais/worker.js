// AEROX PC Care : relais des rapports de bug et des avis vers GitHub Issues (Cloudflare Worker, gratuit).
// Le logiciel envoie le rapport (ou l'avis) ici ; le relais le publie dans les Issues du dépôt avec une clé
// GitHub qui reste secrète (variable GITHUB_TOKEN du Worker), jamais dans le logiciel.
//   POST /       : rapport de bug (étiquette « bug »)
//   POST /avis   : avis (note 1 à 5 + commentaire), étiquette « avis », publié directement ; un seul avis par PC (modifiable)
//   GET  /note   : note moyenne pour le badge de la page GitHub (format shields.io)
//   POST /stats  : statistiques anonymes (compteurs seulement, additionnés par mois dans l'espace KV)
//   GET  /stats  : le logiciel vérifie que le relais sait les recevoir ; GET /stats?voir=1 : les compteurs des 3 derniers mois
//
// Variables du Worker :
//   REPO          : Aerox62550/AeroxPCCare
//   GITHUB_TOKEN  : (secret) jeton GitHub « fine-grained », accès au seul dépôt AeroxPCCare, permission Issues : Read and write
//   LIMITES       : (liaison KV, recommandée) espace KV pour les limites anti-abus et les statistiques
//   DISCORD_BUGS  : (secret, facultatif) adresse du webhook du salon Discord des rapports de bug
//   DISCORD_AVIS  : (secret, facultatif) adresse du webhook du salon Discord des avis
//   SEL_IP        : (secret, facultatif) texte secret qui sert à brouiller les adresses IP ; à défaut, GITHUB_TOKEN
//
// Règles de ce relais (le test tests/relais/relais.test.mjs les vérifie à chaque envoi sur GitHub) :
//   - tout ce qui arrive est du texte non fiable : nettoyé avant d'être publié (aucune mention, lien, image ni commentaire caché) ;
//   - une requête invalide, trop grosse ou un stockage en panne ne fait jamais planter le relais : réponse JSON propre ;
//   - l'adresse IP n'est jamais gardée telle quelle : seulement une empreinte secrète, valable une heure (une journée pour les statistiques) ;
//   - les statistiques ne peuvent pas épuiser les écritures KV du jour (offre gratuite : 1000) au détriment des rapports.

const MAX_BODY = 60000;       // texte d'un rapport : caractères conservés
const MAX_REQUEST = 100000;   // taille maximale d'une requête, en octets, contrôlée pendant la lecture
const PER_HOUR = 5;           // rapports (ou avis) maximum par heure et par adresse IP
// Plafonds toutes adresses confondues : quelqu'un qui contourne la limite par IP (envois simultanés, plusieurs adresses)
// ne peut pas inonder les Issues. Un vrai usage en est très loin (quelques rapports par jour).
const GLOBAL_CAPS = { bug: { hour: 30, day: 100 }, avis: { hour: 15, day: 40 } };
const HOOK_OF = { bug: 'DISCORD_BUGS', avis: 'DISCORD_AVIS' };
const TROP = {
  bug: 'Trop de rapports envoyés depuis ce réseau : réessaie dans une heure.',
  avis: "Trop d'envois depuis ce réseau : réessaie dans une heure."
};

const enc = new TextEncoder();

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json; charset=utf-8' } });
}

function gh(env, path, method = 'GET', body) {
  return fetch(`https://api.github.com/repos/${env.REPO}${path}`, {
    method,
    headers: {
      'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'aerox-pccare-relais',
      'Content-Type': 'application/json'
    },
    body: body ? JSON.stringify(body) : undefined
  });
}
// Même chose, mais renvoie null si GitHub ne répond pas (le relais répond alors proprement au lieu de planter)
async function ghTry(env, path, method, body) {
  try { return await gh(env, path, method, body); } catch { return null; }
}

// ---------------------------------------------------------------- Stockage
// Une panne de l'espace KV (quota d'écritures de la journée épuisé, par exemple) ne doit jamais empêcher un rapport de bug :
// les fonctions kv* avalent l'erreur, les fonctions store* se rabattent sur le cache de Cloudflare (inefficace sur les
// adresses *.workers.dev, mais sans effet néfaste), et sans aucun stockage les limites sont simplement levées.
async function kvGet(env, key) {
  if (!env.LIMITES) return null;
  try { return await env.LIMITES.get(key); } catch { return null; }
}
async function kvPut(env, key, value, opts) {
  if (!env.LIMITES) return false;
  try { await env.LIMITES.put(key, value, opts); return true; } catch { return false; }
}
const cacheKey = (key) => new Request('https://limite.aerox/' + encodeURIComponent(key));
async function storeGet(env, key) {
  if (env.LIMITES) { try { return await env.LIMITES.get(key); } catch { /* on essaie le cache */ } }
  try { const hit = await caches.default.match(cacheKey(key)); return hit ? await hit.text() : null; } catch { return null; }
}
async function storePut(env, key, value, ttl) {
  if (env.LIMITES) { try { await env.LIMITES.put(key, value, { expirationTtl: ttl }); return true; } catch { /* on essaie le cache */ } }
  try { await caches.default.put(cacheKey(key), new Response(value, { headers: { 'Cache-Control': 'max-age=' + ttl } })); return true; } catch { return false; }
}

// Empreinte de l'adresse IP (HMAC-SHA-256 avec une clé secrète du relais) : sert de clé de compteur, l'adresse elle-même n'est jamais écrite.
// Le créneau (l'heure, ou le jour) en fait partie : l'empreinte change à chaque créneau, on ne peut pas suivre un PC dans la durée.
async function ipHash(request, env, slot) {
  const ip = clientIp(request);
  const key = await crypto.subtle.importKey('raw', enc.encode(String(env.SEL_IP || env.GITHUB_TOKEN || 'aerox')), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(`${ip}|${slot}`)));
  return Array.from(sig.slice(0, 10), (b) => b.toString(16).padStart(2, '0')).join('');
}

// ---------------------------------------------------------------- Lecture et nettoyage de ce qui arrive
// Lit le corps JSON sans jamais garder plus de MAX_REQUEST octets : l'en-tête Content-Length peut manquer ou mentir.
// Renvoie { d } (un objet) ou { err } (la réponse à renvoyer).
async function readJson(request, nom) {
  const trop = () => ({ err: json({ error: `${nom} trop long.` }, 413) });
  const illisible = () => ({ err: json({ error: `${nom} illisible.` }, 400) });
  if (Number(request.headers.get('Content-Length') || 0) > MAX_REQUEST) return trop();
  const reader = request.body && request.body.getReader();
  if (!reader) return illisible();
  const chunks = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_REQUEST) { try { await reader.cancel(); } catch { /* déjà fermé */ } return trop(); }
    chunks.push(value);
  }
  const all = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) { all.set(c, off); off += c.byteLength; }
  let d;
  try { d = JSON.parse(new TextDecoder().decode(all)); } catch { return illisible(); }
  if (!d || typeof d !== 'object' || Array.isArray(d)) return illisible();
  return { d };
}

// Un texte venu d'un PC inconnu est publié sous le nom de Sam, sur une page publique : il ne doit pouvoir ni notifier quelqu'un (@),
// ni citer un autre ticket (#123, y compris dans un autre dépôt), ni cacher du texte (commentaires HTML), ni afficher une balise,
// un lien ou une image cliquable. Les adresses restent lisibles, simplement plus cliquables. Les caractères de contrôle et ceux
// qui inversent le sens d'un texte sont retirés.
const ZW = '​';
function clean(v, n) {
  return String(v == null ? '' : v)
    .replace(/\r/g, '')
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f​‎‏‪-‮⁠⁦-⁩﻿]/g, '')
    .replace(/<!--|-->/g, '')
    .replace(/@/g, '@' + ZW)
    .replace(/#(?=\d)/g, '#' + ZW)
    .replace(/<(?=[a-zA-Z\/!?])/g, '<' + ZW)
    .replace(/\]\(/g, ']' + ZW + '(')
    .replace(/:\/\//g, '://' + ZW)
    .replace(/\bwww\./gi, (m) => m + ZW)
    .replace(/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g, '')   // moitiés d'émoji orphelines
    .trim()
    .slice(0, n)
    .replace(/[\ud800-\udbff]$/, '');   // coupure au milieu d'un émoji
}
const oneLine = (v) => String(v == null ? '' : v).replace(/[\r\n]+/g, ' ');
// Numéro de version : le premier « 2.5.3 » trouvé dans le texte, rien d'autre
const versionOf = (v) => { const m = /\d{1,4}(?:\.\d{1,4}){0,3}/.exec(String(v == null ? '' : v)); return m ? m[0] : ''; };

// ---------------------------------------------------------------- Limites d'envoi
// Premier barrage, en mémoire du Worker : un compteur en mémoire se met à jour sans attente, donc sans course entre des envois
// simultanés (au contraire du KV, qui ne sait que lire puis écrire). Il ne voit que ce que voit ce Worker-ci (Cloudflare peut en
// lancer plusieurs et les efface quand il veut) : c'est un complément du KV, jamais un remplacement. Les adresses IP n'y restent
// que le temps de vie du Worker et ne sont jamais écrites nulle part.
const memo = new Map();
function memoHit(key, slot, max) {
  let e = memo.get(key);
  if (!e || e.slot !== slot) { if (memo.size > 5000) memo.clear(); e = { slot, n: 0 }; memo.set(key, e); }
  if (e.n >= max) return false;
  e.n++;
  return true;
}
const clientIp = (request) => request.headers.get('CF-Connecting-IP') || 'inconnu';

// Contrôle d'un envoi (rapport ou avis) : limite par adresse IP, puis plafonds globaux. Renvoie la réponse de refus,
// ou null si l'envoi est accepté. Les compteurs du KV se lisent puis s'écrivent (rien d'atomique) : des envois strictement
// simultanés qui arriveraient dans des Workers différents peuvent passer ensemble ; les plafonds globaux, le nettoyage du texte
// et les limites propres à GitHub bornent alors les dégâts. Seuls les envois acceptés écrivent dans le KV (2 écritures).
async function admit(request, env, ctx, kind) {
  const cap = GLOBAL_CAPS[kind];
  const t = new Date();
  const hour = Math.floor(t.getTime() / 3600000);
  const hh = String(t.getUTCHours());
  const day = t.toISOString().slice(0, 10);
  // (avant tout « await » : la vérification et l'incrément du compteur en mémoire ne peuvent pas être coupés par un autre envoi)
  if (!memoHit(`ip:${kind}:${clientIp(request)}`, hour, PER_HOUR)) return json({ error: TROP[kind] }, 429);
  if (!memoHit(`h:${kind}`, hour, cap.hour) || !memoHit(`d:${kind}`, day, cap.day)) {
    await alertCap(env, ctx, kind, hour);
    return json({ error: "Le service d'envoi est très sollicité en ce moment : réessaie un peu plus tard." }, 429);
  }
  const ipKey = `ip:${kind}:${await ipHash(request, env, hour)}:${hour}`;
  const nIp = Number(await storeGet(env, ipKey)) || 0;
  if (nIp >= PER_HOUR) return json({ error: TROP[kind] }, 429);
  const gKey = `g:${kind}:${day}`;
  let g = {};
  try { g = JSON.parse((await storeGet(env, gKey)) || '{}') || {}; } catch { g = {}; }
  const hours = (g.h && typeof g.h === 'object') ? g.h : {};
  const total = Number(g.t) || 0;
  const nHour = Number(hours[hh]) || 0;
  if (total >= cap.day || nHour >= cap.hour) {
    await alertCap(env, ctx, kind, hour);
    return json({ error: "Le service d'envoi est très sollicité en ce moment : réessaie un peu plus tard." }, 429);
  }
  await storePut(env, ipKey, String(nIp + 1), 3700);
  await storePut(env, gKey, JSON.stringify({ t: total + 1, h: { ...hours, [hh]: nHour + 1 } }), 90000);
  return null;
}

// Prévient dans Discord (une fois par heure et par sorte d'envoi) qu'un plafond est atteint : c'est soit un gros pic, soit du spam
async function alertCap(env, ctx, kind, hour) {
  const key = `alerte:${kind}:${hour}`;
  if (await storeGet(env, key)) return;
  if (!(await storePut(env, key, '1', 3700))) return;   // sans stockage, pas d'alerte : elle reviendrait à chaque refus
  const c = GLOBAL_CAPS[kind];
  discord(env, ctx, HOOK_OF[kind], {
    title: "⚠️ Plafond d'envois atteint",
    description: `Le relais refuse les nouveaux ${kind === 'bug' ? 'rapports de bug' : 'avis'} pour le moment (${c.hour} par heure et ${c.day} par jour au maximum, toutes adresses confondues). Si ce n'est pas un vrai pic d'utilisation, regarde les derniers tickets : quelqu'un envoie peut-être du spam.`,
    color: 0xf59e0b
  });
}

// ---------------------------------------------------------------- Discord
// Copie dans Discord (facultative) : jamais bloquante, et aucune mention possible (@everyone, @here, rôles, membres)
const DISCORD_HOOK = /^https:\/\/((canary|ptb)\.)?(discord|discordapp)\.com\/api\/(v\d+\/)?webhooks\/\d+\/[\w-]+\/?$/;
const cut = (t, n) => { t = String(t || ''); return t.length > n ? t.slice(0, n - 1) + '…' : t; };
// Dernier résultat de l'envoi vers Discord (sans l'adresse du webhook), visible dans GET /stats?voir=1 pour dépanner.
// Écrit seulement si le résultat change ou s'il a plus d'une heure (économise les écritures KV).
async function noteDiscord(env, hook, etat) {
  if (!env.LIMITES) return;
  const prev = await kvGet(env, 'discord:' + hook);
  if (prev) {
    const i = prev.indexOf(' · ');
    if (i > 0 && prev.slice(i + 3) === etat && Date.now() - Date.parse(prev.slice(0, i)) < 3600000) return;
  }
  await kvPut(env, 'discord:' + hook, `${new Date().toISOString()} · ${etat}`);
}
function discord(env, ctx, hook, embed) {
  const raw = env[hook];
  let p;
  if (!raw) p = noteDiscord(env, hook, 'secret absent');
  else {
    const url = String(raw).trim();
    if (!DISCORD_HOOK.test(url)) p = noteDiscord(env, hook, "le secret n'est pas une adresse de webhook Discord");
    else p = fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'AEROX PC Care', allowed_mentions: { parse: [] }, embeds: [embed] })
    }).then(async r => noteDiscord(env, hook, r.ok ? 'envoyé' : `refusé par Discord (${r.status}) ${(await r.text()).slice(0, 200)}`))
      .catch(e => noteDiscord(env, hook, 'erreur : ' + String(e && e.message || e).slice(0, 200)));
  }
  if (ctx && ctx.waitUntil) ctx.waitUntil(p);
}

// ---------------------------------------------------------------- Statistiques anonymes
// Le logiciel envoie des compteurs (« probleme:bsod » : 1, « lent:rien » : 2…), au plus toutes les 6 heures par PC. Rien d'autre
// n'est gardé : ni adresse IP, ni identifiant, ni texte libre. Une seule écriture KV par envoi accepté (plus une pour la limite par
// adresse). Les compteurs ne sont pas protégés contre quelqu'un qui enverrait de fausses valeurs : ils restent indicatifs.
//   - seules les familles de compteurs du logiciel sont acceptées (STATS_FROM_APP : à tenir d'accord avec $script:StatsPrefixes
//     de src/2_lib.ps1, le test tests/relais/relais.test.mjs compare les deux) ; « actifs » et « version » sont ajoutés par le relais ;
//   - nombre de compteurs différents plafonné par mois et par famille : le fichier du mois ne peut pas grossir sans fin ;
//   - STATS_PER_DAY envois acceptés par jour au total et STATS_PER_IP_DAY par adresse : une inondation de statistiques ne peut pas
//     épuiser le quota d'écritures KV de la journée (1000 sur l'offre gratuite), qui doit rester disponible pour les rapports.
const STATS_KEY = /^[a-z]+(:[a-z0-9][a-z0-9-]{0,39})?$/;
const STATS_FROM_APP = new Set(['probleme', 'lent', 'jeu', 'lag', 'diag', 'erreur', 'pascorrige', 'corrige', 'echec', 'inconnu', 'symptome', 'partage', 'maj']);
const STATS_PER_DAY = 300;
const STATS_PER_IP_DAY = 20;
const STATS_MAX_KEYS = 400;
const STATS_MAX_PER_PREFIX = 100;
const monthOf = (d) => d.toISOString().slice(0, 7);
const prefixOf = (k) => k.split(':')[0];

// Le fichier du mois : { c : compteurs, jours : envois acceptés par jour }, sans prototype (« constructor » ne peut plus
// fausser un compteur) et seulement des nombres (un fichier abîmé est réparé à la lecture). Lève une erreur si le KV ne répond pas.
async function loadStats(env, key) {
  const c = Object.create(null);
  const jours = Object.create(null);
  let s = {};
  try { s = JSON.parse((await env.LIMITES.get(key)) || '{}'); } catch (e) { if (e instanceof SyntaxError) s = {}; else throw e; }
  if (s && typeof s === 'object') {
    for (const [k, v] of Object.entries(s)) {
      if (k === '_jours') {
        if (v && typeof v === 'object') for (const [d, n] of Object.entries(v)) if (/^\d{4}-\d{2}-\d{2}$/.test(d) && Number.isFinite(n) && n >= 0) jours[d] = n;
      } else if (STATS_KEY.test(k) && Number.isFinite(v) && v >= 0) c[k] = v;
    }
  }
  return { c, jours };
}

async function statsGet(env, url) {
  if (!url.searchParams.has('voir')) return json({ aerox: 'stats', ok: !!env.LIMITES });
  if (!env.LIMITES) return json({ error: "Pas d'espace KV lié sous le nom LIMITES." }, 503);
  const out = {};
  for (const h of ['DISCORD_BUGS', 'DISCORD_AVIS']) out[h] = (await kvGet(env, 'discord:' + h)) || (env[h] ? 'configuré, rien envoyé depuis' : 'secret absent');
  const now = new Date();
  const day = now.toISOString().slice(0, 10);
  const hh = String(now.getUTCHours());
  const plafonds = {};
  for (const kind of ['bug', 'avis']) {
    let g = {};
    try { g = JSON.parse((await kvGet(env, `g:${kind}:${day}`)) || '{}') || {}; } catch { g = {}; }
    const cap = GLOBAL_CAPS[kind];
    plafonds[kind === 'bug' ? 'rapports de bug' : 'avis'] = `${Number(g.t) || 0}/${cap.day} aujourd'hui, ${Number(g.h && g.h[hh]) || 0}/${cap.hour} cette heure`;
  }
  for (let i = 0; i < 3; i++) {
    const m = monthOf(new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1)));
    let st;
    try { st = await loadStats(env, 'stats:' + m); } catch { continue; }
    if (!Object.keys(st.c).length && !Object.keys(st.jours).length) continue;
    const envois = Object.values(st.jours).reduce((a, b) => a + b, 0);
    if (i === 0) plafonds['statistiques'] = `${st.jours[day] || 0}/${STATS_PER_DAY} aujourd'hui`;
    out[m] = { envois, compteurs: Object.fromEntries(Object.entries(st.c).sort((a, b) => b[1] - a[1])) };
  }
  out.plafonds = plafonds;
  return new Response(JSON.stringify(out, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
}

async function statsPost(request, env) {
  if (!env.LIMITES) return json({ error: 'Statistiques indisponibles.' }, 503);
  const r = await readJson(request, 'Statistiques');
  if (r.err) return r.err;
  const d = r.d;
  const v = /^\d{1,3}(\.\d{1,3}){1,3}$/.test(String(d.v == null ? '' : d.v)) ? String(d.v) : '';
  const ev = (d.ev && typeof d.ev === 'object' && !Array.isArray(d.ev)) ? d.ev : {};
  const add = Object.create(null);
  let n = 0;
  for (const [k, c] of Object.entries(ev)) {
    if (++n > 60) break;
    const c2 = Math.floor(Number(c));
    if (!STATS_KEY.test(k) || !STATS_FROM_APP.has(prefixOf(k)) || !(c2 >= 1)) continue;
    add[k] = Math.min(c2, 50);
  }
  // Une fois par mois et par PC : compte les PC actifs et les versions utilisées
  if (d.nouveau_mois === true) { add['actifs'] = 1; if (v) add['version:' + v.replace(/\./g, '-')] = 1; }
  if (!Object.keys(add).length) return json({ ok: true });

  const now = new Date();
  const key = 'stats:' + monthOf(now);
  const day = now.toISOString().slice(0, 10);
  // Refus = erreur HTTP : le logiciel garde alors ses compteurs et les renvoie plus tard (une réponse « ok » les lui ferait perdre)
  const tropIp = { error: "Trop d'envois de statistiques aujourd'hui depuis ce réseau." };
  const tropJour = { error: "Le relais a atteint sa limite de statistiques pour aujourd'hui." };
  if (!memoHit(`ip:stats:${clientIp(request)}`, day, STATS_PER_IP_DAY)) return json(tropIp, 429);   // barrage en mémoire (voir plus haut)
  if (!memoHit('d:stats', day, STATS_PER_DAY)) return json(tropJour, 429);
  const ipKey = `ip:stats:${await ipHash(request, env, day)}:${day}`;
  const nIp = Number(await storeGet(env, ipKey)) || 0;
  if (nIp >= STATS_PER_IP_DAY) return json(tropIp, 429);
  let st;
  try { st = await loadStats(env, key); } catch { return json({ error: 'Statistiques indisponibles pour le moment.' }, 503); }
  if ((st.jours[day] || 0) >= STATS_PER_DAY) return json(tropJour, 429);

  const perPrefix = Object.create(null);
  for (const k of Object.keys(st.c)) perPrefix[prefixOf(k)] = (perPrefix[prefixOf(k)] || 0) + 1;
  let total = Object.keys(st.c).length;
  let changed = false;
  for (const [k, inc] of Object.entries(add)) {
    if (k in st.c) { st.c[k] += inc; changed = true; continue; }
    const p = prefixOf(k);
    if (total >= STATS_MAX_KEYS || (perPrefix[p] || 0) >= STATS_MAX_PER_PREFIX) continue;   // nouveau compteur refusé, les existants continuent
    st.c[k] = inc; total++; perPrefix[p] = (perPrefix[p] || 0) + 1; changed = true;
  }
  if (!changed) return json({ ok: true });
  st.jours[day] = (st.jours[day] || 0) + 1;
  try { await env.LIMITES.put(key, JSON.stringify({ ...st.c, _jours: st.jours })); } catch { return json({ error: 'Statistiques indisponibles pour le moment.' }, 503); }
  await storePut(env, ipKey, String(nIp + 1), 90000);
  return json({ ok: true });
}

// ---------------------------------------------------------------- Avis
// Avis : note de 1 à 5, commentaire libre, pseudo facultatif. Publié tout de suite (Sam supprime après coup si besoin).
async function postReview(request, env, ctx) {
  const r = await readJson(request, 'Avis');
  if (r.err) return r.err;
  const d = r.d;
  const note = Math.round(Number(d.note));
  if (!(note >= 1 && note <= 5)) return json({ error: 'Note invalide.' }, 400);
  const text = clean(d.commentaire, 1500);
  const pseudo = clean(oneLine(d.pseudo), 30) || 'Anonyme';
  const version = versionOf(d.version);
  const id = String(d.id == null ? '' : d.id).toLowerCase();
  const refus = await admit(request, env, ctx, 'avis');
  if (refus) return refus;
  const stars = '★'.repeat(note) + '☆'.repeat(5 - note);
  const title = `${stars} ${note}/5 · ${pseudo}` + (text ? ` : ${text.split('\n')[0].slice(0, 60)}${text.length > 60 ? '…' : ''}` : '');
  const body = `## ${stars} ${note}/5\n\n${text ? text.split('\n').map(l => '> ' + l).join('\n') : '_(pas de commentaire)_'}\n\n— **${pseudo}**, avec AEROX PC Care ${version}\n\n<!-- note:${note} -->`;
  // Un seul avis par PC : s'il existe déjà, il est modifié (jamais rouvert s'il a été fermé)
  const idOk = /^[0-9a-f]{16,64}$/.test(id);
  const known = idOk ? await kvGet(env, 'avis-pc:' + id) : null;
  if (known) {
    const u = await ghTry(env, `/issues/${encodeURIComponent(known)}`, 'PATCH', { title, body });
    if (u && u.ok) {
      const i = await u.json();
      discord(env, ctx, 'DISCORD_AVIS', { title: cut(`✏️ Avis modifié · ${stars} ${note}/5 · ${pseudo}`, 250), description: cut(text || '(pas de commentaire)', 1500), url: i.html_url, color: 0x8b5cf6, footer: { text: `AEROX PC Care ${version}` } });
      return json({ ok: true, number: i.number, url: i.html_url, updated: true });
    }
  }
  const res = await ghTry(env, '/issues', 'POST', { title, body, labels: ['avis'] });
  if (!res) return json({ error: "GitHub ne répond pas pour l'instant : réessaie plus tard." }, 502);
  if (!res.ok) return json({ error: `GitHub a refusé l'avis (${res.status}).` }, 502);
  const issue = await res.json();
  if (idOk) await kvPut(env, 'avis-pc:' + id, String(issue.number));
  discord(env, ctx, 'DISCORD_AVIS', { title: cut(`${stars} ${note}/5 · ${pseudo}`, 250), description: cut(text || '(pas de commentaire)', 1500), url: issue.html_url, color: 0x8b5cf6, footer: { text: `AEROX PC Care ${version}` } });
  return json({ ok: true, number: issue.number, url: issue.html_url });
}

// Note moyenne des avis ouverts (un avis fermé ou supprimé ne compte plus) : badge shields.io
async function badge(env) {
  const cached = await kvGet(env, 'badge');
  if (cached) return new Response(cached, { headers: { 'Content-Type': 'application/json' } });
  let sum = 0, n = 0;
  for (let page = 1; page <= 10; page++) {
    const r = await gh(env, `/issues?labels=avis&state=open&per_page=100&page=${page}`);
    if (!r.ok) break;
    const list = await r.json();
    for (const i of list) { const m = /<!-- note:([1-5]) -->/.exec(i.body || ''); if (m) { sum += Number(m[1]); n++; } }
    if (list.length < 100) break;
  }
  const avg = n ? (sum / n).toFixed(1).replace('.', ',') : '';
  const out = JSON.stringify({ schemaVersion: 1, label: 'avis', message: n ? `★ ${avg} / 5 · ${n} avis` : 'pas encore d\'avis', color: n ? '8b5cf6' : 'lightgrey', cacheSeconds: 600 });
  await kvPut(env, 'badge', out, { expirationTtl: 600 });
  return new Response(out, { headers: { 'Content-Type': 'application/json' } });
}

// ---------------------------------------------------------------- Rapport de bug
async function postReport(request, env, ctx) {
  const r = await readJson(request, 'Rapport');
  if (r.err) return r.err;
  const data = r.d;
  const title = clean(oneLine(data.title), 120) || '[Bug] Rapport AEROX PC Care';
  const body = clean(data.body, MAX_BODY);
  const version = versionOf(data.version);
  if (!body) return json({ error: 'Rapport vide.' }, 400);

  const refus = await admit(request, env, ctx, 'bug');
  if (refus) return refus;

  const res = await ghTry(env, '/issues', 'POST', {
    title,
    body: body + `\n\n---\n_Envoyé depuis AEROX PC Care ${version} (sans compte GitHub)._`,
    labels: ['bug']
  });
  if (!res) return json({ error: "GitHub ne répond pas pour l'instant : réessaie plus tard." }, 502);
  if (!res.ok) return json({ error: `GitHub a refusé le rapport (${res.status}).` }, 502);
  const issue = await res.json();
  // Discord : le titre et le début du rapport (le rapport complet reste sur GitHub)
  // Dans Discord : version, Windows, ce qui s'est passé et les erreurs (sans la fin du journal ni l'en-tête répété)
  const resume = body.replace(/<!--[\s\S]*?-->/g, '')
    .split(/\n#+ Fin du journal/)[0]
    .replace(/^#+ Rapport AEROX PC Care[^\n]*\n/, '')
    .replace(/#+ Bugs et erreurs enregistrés \(0 [^\n]*\)\n\(aucun\)\n?/, '')
    .trim();
  discord(env, ctx, 'DISCORD_BUGS', { title: cut(`🐞 ${title}`, 250), description: cut(resume, 900) + `\n\n[Voir le rapport complet sur GitHub](${issue.html_url})`, url: issue.html_url, color: 0xff6b6b, footer: { text: `AEROX PC Care ${version} · rapport n° ${issue.number}` } });
  return json({ ok: true, number: issue.number, url: issue.html_url });
}

// ---------------------------------------------------------------- Point d'entrée
async function route(request, env, ctx) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '');
  if (request.method === 'GET' && path === '/note') return badge(env);
  if (request.method === 'GET' && path === '/stats') return statsGet(env, url);
  if (request.method !== 'POST') return new Response('AEROX PC Care : relais des rapports de bug et des avis.', { status: 200 });
  if (request.headers.get('X-Aerox') !== '1') return json({ error: 'Requête refusée.' }, 400);
  if (path === '/avis') return postReview(request, env, ctx);
  if (path === '/stats') return statsPost(request, env);
  if (path === '') return postReport(request, env, ctx);
  return json({ error: 'Adresse inconnue.' }, 404);
}

export default {
  async fetch(request, env, ctx) {
    try { return await route(request, env, ctx); }
    catch (e) {
      console.error('relais :', e && e.message ? e.message : e);
      return json({ error: 'Le relais a rencontré une erreur : réessaie plus tard.' }, 500);
    }
  }
};
