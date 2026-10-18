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
//   LIMITES       : (liaison KV, recommandée) espace KV pour la limite anti-abus
//   DISCORD_BUGS  : (secret, facultatif) adresse du webhook du salon Discord des rapports de bug
//   DISCORD_AVIS  : (secret, facultatif) adresse du webhook du salon Discord des avis

const MAX_BODY = 60000;      // taille maximale d'un rapport (octets)
const PER_HOUR = 5;          // rapports maximum par heure et par adresse IP

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

// Limite anti-abus : quelques envois par heure et par adresse IP.
// Avec un espace KV lié sous le nom LIMITES (recommandé) la limite est fiable partout ;
// sinon on se rabat sur le cache (qui ne fonctionne pas sur les adresses *.workers.dev).
async function overLimit(request, env, kind) {
  const ip = request.headers.get('CF-Connecting-IP') || 'inconnu';
  const slot = Math.floor(Date.now() / 3600000);
  if (env.LIMITES) {
    const k = `${kind}${ip}:${slot}`;
    const n = Number(await env.LIMITES.get(k)) || 0;
    if (n >= PER_HOUR) return true;
    await env.LIMITES.put(k, String(n + 1), { expirationTtl: 3700 });
  } else {
    const key = new Request('https://limite.aerox/' + kind + encodeURIComponent(ip) + '/' + slot);
    const hit = await caches.default.match(key);
    const n = hit ? Number(await hit.text()) : 0;
    if (n >= PER_HOUR) return true;
    await caches.default.put(key, new Response(String(n + 1), { headers: { 'Cache-Control': 'max-age=3600' } }));
  }
  return false;
}

// Copie dans Discord (facultative) : jamais bloquante, et aucune mention possible (@everyone, @here, rôles, membres)
const DISCORD_HOOK = /^https:\/\/((canary|ptb)\.)?(discord|discordapp)\.com\/api\/(v\d+\/)?webhooks\/\d+\/[\w-]+\/?$/;
const cut = (t, n) => { t = String(t || ''); return t.length > n ? t.slice(0, n - 1) + '…' : t; };
// Dernier résultat de l'envoi vers Discord (sans l'adresse du webhook), visible dans GET /stats?voir=1 pour dépanner
async function noteDiscord(env, hook, etat) {
  if (env.LIMITES) { try { await env.LIMITES.put('discord:' + hook, `${new Date().toISOString()} · ${etat}`); } catch {} }
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

// Statistiques anonymes : le logiciel envoie des compteurs (« probleme:bsod » : 1, « lent:rien » : 2…), au plus toutes
// les 6 heures par PC. Rien d'autre n'est gardé : ni adresse IP, ni identifiant, ni texte libre. Une seule écriture KV
// par envoi ; au-delà de STATS_PER_DAY envois par jour, les suivants sont ignorés (offre gratuite KV : 1000 écritures/jour).
const STATS_KEY = /^[a-z]+(:[a-z0-9][a-z0-9-]{0,39})?$/;
const STATS_PER_DAY = 800;
const monthOf = (d) => d.toISOString().slice(0, 7);

async function statsGet(env, url) {
  if (!url.searchParams.has('voir')) return json({ aerox: 'stats', ok: !!env.LIMITES });
  if (!env.LIMITES) return json({ error: "Pas d'espace KV lié sous le nom LIMITES." }, 503);
  const out = {};
  for (const h of ['DISCORD_BUGS', 'DISCORD_AVIS']) out[h] = (await env.LIMITES.get('discord:' + h)) || (env[h] ? 'configuré, rien envoyé depuis' : 'secret absent');
  const now = new Date();
  for (let i = 0; i < 3; i++) {
    const m = monthOf(new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1)));
    const raw = await env.LIMITES.get('stats:' + m);
    if (!raw) continue;
    let s; try { s = JSON.parse(raw); } catch { continue; }
    const envois = Object.values(s._jours || {}).reduce((a, b) => a + b, 0);
    delete s._jours;
    const tri = Object.fromEntries(Object.entries(s).sort((a, b) => b[1] - a[1]));
    out[m] = { envois, compteurs: tri };
  }
  return new Response(JSON.stringify(out, null, 2), { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
}

async function statsPost(request, env) {
  if (!env.LIMITES) return json({ error: 'Statistiques indisponibles.' }, 503);
  let d;
  try { d = await request.json(); } catch { return json({ error: 'Illisible.' }, 400); }
  const v = String((d && d.v) || '').replace(/[^0-9.]/g, '').slice(0, 12);
  const ev = (d && d.ev && typeof d.ev === 'object' && !Array.isArray(d.ev)) ? d.ev : {};
  const add = {};
  let n = 0;
  for (const [k, c] of Object.entries(ev)) {
    if (++n > 60) break;
    const c2 = Math.floor(Number(c));
    if (!STATS_KEY.test(k) || !(c2 >= 1)) continue;
    add[k] = Math.min(c2, 50);
  }
  // Une fois par mois et par PC : compte les PC actifs et les versions utilisées
  if (d && d.nouveau_mois === true) { add['actifs'] = 1; if (v) add['version:' + v.replace(/\./g, '-')] = 1; }
  if (!Object.keys(add).length) return json({ ok: true });
  const now = new Date();
  const key = 'stats:' + monthOf(now);
  const day = now.toISOString().slice(0, 10);
  let s = {};
  try { s = JSON.parse((await env.LIMITES.get(key)) || '{}'); } catch { s = {}; }
  s._jours = s._jours || {};
  if ((s._jours[day] || 0) >= STATS_PER_DAY) return json({ ok: true, ignore: true });
  s._jours[day] = (s._jours[day] || 0) + 1;
  for (const [k, c] of Object.entries(add)) s[k] = (s[k] || 0) + c;
  await env.LIMITES.put(key, JSON.stringify(s));
  return json({ ok: true });
}

// Avis : note de 1 à 5, commentaire libre, pseudo facultatif. Publié tout de suite (Sam supprime après coup si besoin).
async function postReview(request, env, ctx) {
  let d;
  try { d = await request.json(); } catch { return json({ error: 'Avis illisible.' }, 400); }
  const note = Math.round(Number(d.note));
  if (!(note >= 1 && note <= 5)) return json({ error: 'Note invalide.' }, 400);
  // « @ » neutralisé : un avis ne doit pas pouvoir notifier quelqu'un sur GitHub
  const clean = (v, n) => String(v || '').replace(/\r/g, '').replace(/@/g, '@\u200b').replace(/<!--|-->/g, '').trim().slice(0, n);
  const text = clean(d.commentaire, 1500);
  const pseudo = clean(d.pseudo, 30).replace(/\n/g, ' ') || 'Anonyme';
  const version = String(d.version || '').replace(/[^0-9.]/g, '').slice(0, 20);
  const id = String(d.id || '').toLowerCase();
  if (await overLimit(request, env, 'avis:')) return json({ error: 'Trop d\'envois : réessaie dans une heure.' }, 429);
  const stars = '★'.repeat(note) + '☆'.repeat(5 - note);
  const title = `${stars} ${note}/5 · ${pseudo}` + (text ? ` : ${text.split('\n')[0].slice(0, 60)}${text.length > 60 ? '…' : ''}` : '');
  const body = `## ${stars} ${note}/5\n\n${text ? text.split('\n').map(l => '> ' + l).join('\n') : '_(pas de commentaire)_'}\n\n— **${pseudo}**, avec AEROX PC Care ${version}\n\n<!-- note:${note} -->`;
  // Un seul avis par PC : s'il existe déjà, il est modifié (jamais rouvert s'il a été fermé)
  const known = (env.LIMITES && /^[0-9a-f]{16,64}$/.test(id)) ? await env.LIMITES.get('avis-pc:' + id) : null;
  if (known) {
    const u = await gh(env, `/issues/${known}`, 'PATCH', { title, body });
    if (u.ok) {
      const i = await u.json();
      discord(env, ctx, 'DISCORD_AVIS', { title: cut(`✏️ Avis modifié · ${stars} ${note}/5 · ${pseudo}`, 250), description: cut(text || '(pas de commentaire)', 1500), url: i.html_url, color: 0x8b5cf6, footer: { text: `AEROX PC Care ${version}` } });
      return json({ ok: true, number: i.number, url: i.html_url, updated: true });
    }
  }
  const r = await gh(env, '/issues', 'POST', { title, body, labels: ['avis'] });
  if (!r.ok) return json({ error: `GitHub a refusé l'avis (${r.status}).` }, 502);
  const issue = await r.json();
  if (env.LIMITES && /^[0-9a-f]{16,64}$/.test(id)) await env.LIMITES.put('avis-pc:' + id, String(issue.number));
  discord(env, ctx, 'DISCORD_AVIS', { title: cut(`${stars} ${note}/5 · ${pseudo}`, 250), description: cut(text || '(pas de commentaire)', 1500), url: issue.html_url, color: 0x8b5cf6, footer: { text: `AEROX PC Care ${version}` } });
  return json({ ok: true, number: issue.number, url: issue.html_url });
}

// Note moyenne des avis ouverts (un avis fermé ou supprimé ne compte plus) : badge shields.io
async function badge(env) {
  if (env.LIMITES) { const c = await env.LIMITES.get('badge'); if (c) return new Response(c, { headers: { 'Content-Type': 'application/json' } }); }
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
  if (env.LIMITES) await env.LIMITES.put('badge', out, { expirationTtl: 600 });
  return new Response(out, { headers: { 'Content-Type': 'application/json' } });
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '');
    if (request.method === 'GET' && path === '/note') return badge(env);
    if (request.method === 'GET' && path === '/stats') return statsGet(env, url);
    if (request.method !== 'POST') return new Response('AEROX PC Care : relais des rapports de bug et des avis.', { status: 200 });
    if (request.headers.get('X-Aerox') !== '1') return json({ error: 'Requête refusée.' }, 400);
    if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) return json({ error: 'Envoi trop long.' }, 413);
    if (path === '/avis') return postReview(request, env, ctx);
    if (path === '/stats') return statsPost(request, env);
    if (request.headers.get('X-Aerox') !== '1') return json({ error: 'Requête refusée.' }, 400);
    if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) return json({ error: 'Rapport trop long.' }, 413);

    let data;
    try { data = await request.json(); } catch { return json({ error: 'Rapport illisible.' }, 400); }
    const title = String(data.title || '').slice(0, 120) || '[Bug] Rapport AEROX PC Care';
    const body = String(data.body || '').slice(0, MAX_BODY);
    const version = String(data.version || '').slice(0, 20);
    if (!body.trim()) return json({ error: 'Rapport vide.' }, 400);

    if (await overLimit(request, env, '')) return json({ error: 'Trop de rapports envoyés : réessaie dans une heure.' }, 429);

    const r = await gh(env, '/issues', 'POST', {
      title,
      body: body + `\n\n---\n_Envoyé depuis AEROX PC Care ${version} (sans compte GitHub)._`,
      labels: ['bug']
    });
    if (!r.ok) return json({ error: `GitHub a refusé le rapport (${r.status}).` }, 502);
    const issue = await r.json();
    // Discord : le titre et le début du rapport (le rapport complet reste sur GitHub)
    // Dans Discord : version, Windows, ce qui s'est passé et les erreurs (sans la fin du journal ni l'en-tête répété)
    const resume = body.replace(/\r/g, '').replace(/<!--[\s\S]*?-->/g, '')
      .split(/\n#+ Fin du journal/)[0]
      .replace(/^#+ Rapport AEROX PC Care[^\n]*\n/, '')
      .replace(/#+ Bugs et erreurs enregistrés \(0 [^\n]*\)\n\(aucun\)\n?/, '')
      .trim();
    discord(env, ctx, 'DISCORD_BUGS', { title: cut(`🐞 ${title}`, 250), description: cut(resume, 900) + `\n\n[Voir le rapport complet sur GitHub](${issue.html_url})`, url: issue.html_url, color: 0xff6b6b, footer: { text: `AEROX PC Care ${version} · rapport n° ${issue.number}` } });
    return json({ ok: true, number: issue.number, url: issue.html_url });
  }
};
