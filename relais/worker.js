// AEROX PC Care : relais des rapports de bug vers GitHub Issues (Cloudflare Worker, gratuit).
// Le logiciel envoie le rapport ici ; le relais le publie dans les Issues du dépôt avec une clé
// GitHub qui reste secrète (variable GITHUB_TOKEN du Worker), jamais dans le logiciel.
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

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response('AEROX PC Care : relais des rapports de bug.', { status: 200 });
    if (request.headers.get('X-Aerox') !== '1') return json({ error: 'Requête refusée.' }, 400);
    if (Number(request.headers.get('Content-Length') || 0) > MAX_BODY) return json({ error: 'Rapport trop long.' }, 413);

    let data;
    try { data = await request.json(); } catch { return json({ error: 'Rapport illisible.' }, 400); }
    const title = String(data.title || '').slice(0, 120) || '[Bug] Rapport AEROX PC Care';
    const body = String(data.body || '').slice(0, MAX_BODY);
    const version = String(data.version || '').slice(0, 20);
    if (!body.trim()) return json({ error: 'Rapport vide.' }, 400);

    // Limite anti-abus : quelques rapports par heure et par adresse IP.
    // Avec un espace KV lié sous le nom LIMITES (recommandé) la limite est fiable partout ;
    // sinon on se rabat sur le cache (qui ne fonctionne pas sur les adresses *.workers.dev).
    const ip = request.headers.get('CF-Connecting-IP') || 'inconnu';
    const slot = Math.floor(Date.now() / 3600000);
    if (env.LIMITES) {
      const k = `${ip}:${slot}`;
      const n = Number(await env.LIMITES.get(k)) || 0;
      if (n >= PER_HOUR) return json({ error: 'Trop de rapports envoyés : réessaie dans une heure.' }, 429);
      await env.LIMITES.put(k, String(n + 1), { expirationTtl: 3700 });
    } else {
      const key = new Request('https://limite.aerox/' + encodeURIComponent(ip) + '/' + slot);
      const hit = await caches.default.match(key);
      const n = hit ? Number(await hit.text()) : 0;
      if (n >= PER_HOUR) return json({ error: 'Trop de rapports envoyés : réessaie dans une heure.' }, 429);
      await caches.default.put(key, new Response(String(n + 1), { headers: { 'Cache-Control': 'max-age=3600' } }));
    }

    const r = await fetch(`https://api.github.com/repos/${env.REPO}/issues`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'aerox-pccare-relais',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        title,
        body: body + `\n\n---\n_Envoyé depuis AEROX PC Care ${version} (sans compte GitHub)._`,
        labels: ['bug']
      })
    });
    if (!r.ok) return json({ error: `GitHub a refusé le rapport (${r.status}).` }, 502);
    const issue = await r.json();
    return json({ ok: true, number: issue.number, url: issue.html_url });
  }
};
