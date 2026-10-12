// AEROX PC Care : relais des rapports de bug et des avis vers GitHub Issues (Cloudflare Worker, gratuit).
// Le logiciel envoie le rapport (ou l'avis) ici ; le relais le publie dans les Issues du dépôt avec une clé
// GitHub qui reste secrète (variable GITHUB_TOKEN du Worker), jamais dans le logiciel.
//   POST /       : rapport de bug (étiquette « bug »)
//   POST /avis   : avis (note 1 à 5 + commentaire), étiquette « avis », publié directement ; un seul avis par PC (modifiable)
//   GET  /note   : note moyenne pour le badge de la page GitHub (format shields.io)
//
// Variables du Worker :
//   REPO          : Aerox62550/AeroxPCCare
//   GITHUB_TOKEN  : (secret) jeton GitHub « fine-grained », accès au seul dépôt AeroxPCCare, permission Issues : Read and write
//   LIMITES       : (liaison KV, recommandée) espace KV pour la limite anti-abus

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

// Avis : note de 1 à 5, commentaire libre, pseudo facultatif. Publié tout de suite (Sam supprime après coup si besoin).
async function postReview(request, env) {
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
    if (u.ok) { const i = await u.json(); return json({ ok: true, number: i.number, url: i.html_url, updated: true }); }
  }
  const r = await gh(env, '/issues', 'POST', { title, body, labels: ['avis'] });
  if (!r.ok) return json({ error: `GitHub a refusé l'avis (${r.status}).` }, 502);
  const issue = await r.json();
  if (env.LIMITES && /^[0-9a-f]{16,64}$/.test(id)) await env.LIMITES.put('avis-pc:' + id, String(issue.number));
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
  async fetch(request, env) {
    const path = new URL(request.url).pathname.replace(/\/+$/, '');
    if (request.method === 'GET' && path === '/note') return badge(env);
    if (request.method !== 'POST') return new Response('AEROX PC Care : relais des rapports de bug et des avis.', { status: 200 });
    if (request.headers.get('X-Aerox') !== '1') return json({ error: 'Requête refusée.' }, 400);
    if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) return json({ error: 'Envoi trop long.' }, 413);
    if (path === '/avis') return postReview(request, env);
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
    return json({ ok: true, number: issue.number, url: issue.html_url });
  }
};
