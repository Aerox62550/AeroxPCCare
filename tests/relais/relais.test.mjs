// Tests du relais Cloudflare (relais/worker.js) : exécutés par .github/workflows/relais.yml à chaque envoi qui touche le relais ou le logiciel.
// Aucun réseau, aucun module à installer : le KV de Cloudflare, GitHub et Discord sont simulés ici (Node 20 ou plus récent).
// Lancer à la main : node tests/relais/relais.test.mjs
import { readFileSync, writeFileSync, mkdtempSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ici = dirname(fileURLToPath(import.meta.url));
const racine = join(ici, '..', '..');
const sourceRelais = readFileSync(join(racine, 'relais', 'worker.js'), 'utf8');
const tmp = mkdtempSync(join(tmpdir(), 'aerox-relais-'));
writeFileSync(join(tmp, 'worker.mjs'), sourceRelais);          // le relais est un module ES ; on l'importe sous une extension qui l'indique
// Un exemplaire neuf du relais par test : il garde des compteurs en mémoire (comme un vrai Worker, qui peut être effacé à tout moment)
let nbChargements = 0;
let worker;
async function chargerRelais() { return (await import(pathToFileURL(join(tmp, 'worker.mjs')).href + '?essai=' + (++nbChargements))).default; }

// ---------------------------------------------------------------- Horloge réglable (le relais compte par heure et par jour)
const RealDate = Date;
let decalage = 0;
class FauxDate extends RealDate {
  constructor(...a) { if (a.length) super(...a); else super(RealDate.now() + decalage); }
  static now() { return RealDate.now() + decalage; }
}
globalThis.Date = FauxDate;
const reglerHeure = (iso) => { decalage = RealDate.parse(iso) - RealDate.now(); };
const avancer = (ms) => { decalage += ms; };
const HEURE = 3600000;

// ---------------------------------------------------------------- KV, GitHub et Discord simulés
const dormir = (ms) => new Promise((r) => setTimeout(r, ms));
class KV {
  constructor({ quotaEcritures = Infinity, delai = 0, lectureEnPanne = false } = {}) {
    this.m = new Map(); this.ecritures = 0; this.quota = quotaEcritures; this.delai = delai; this.lectureEnPanne = lectureEnPanne;
    this.ecrituresParCle = new Map();
  }
  async get(k) { if (this.delai) await dormir(this.delai); if (this.lectureEnPanne) throw new Error('KV GET failed: 500'); return this.m.has(k) ? this.m.get(k) : null; }
  async put(k, v) {
    if (this.delai) await dormir(this.delai);
    if (this.ecritures >= this.quota) throw new Error('KV PUT failed: 429 Too Many Requests');
    this.ecritures++; this.ecrituresParCle.set(k, (this.ecrituresParCle.get(k) || 0) + 1); this.m.set(k, v);
  }
}
let appels = [];               // tout ce que le relais a envoyé (GitHub, Discord)
let github = { panne: false, statut: 201, avis: [] };
globalThis.fetch = async (url, init = {}) => {
  const u = String(url);
  const methode = init.method || 'GET';
  const corps = init.body ? JSON.parse(init.body) : null;
  appels.push({ url: u, methode, corps });
  if (u.includes('api.github.com')) {
    if (github.panne) throw new Error('réseau coupé');
    if (methode === 'POST' && u.endsWith('/issues')) {
      if (github.statut !== 201) return new Response('{}', { status: github.statut });
      const n = appels.filter((c) => c.methode === 'POST' && c.url.endsWith('/issues')).length;
      return new Response(JSON.stringify({ number: n, html_url: 'https://github.com/o/r/issues/' + n }), { status: 201 });
    }
    if (methode === 'PATCH') { const n = Number(u.split('/').pop()); return new Response(JSON.stringify({ number: n, html_url: 'https://github.com/o/r/issues/' + n }), { status: 200 }); }
    if (methode === 'GET' && u.includes('/issues?')) return new Response(JSON.stringify(github.avis), { status: 200 });
  }
  return new Response('{}', { status: 200 });
};
const issuesCreees = () => appels.filter((c) => c.methode === 'POST' && c.url.endsWith('/issues'));
const dernierTicket = () => issuesCreees().at(-1).corps;
const appelsDiscord = () => appels.filter((c) => c.url.includes('discord.com'));
let attente = [];
const ctx = { waitUntil: (p) => { attente.push(p); } };
const WEBHOOK = 'https://discord.com/api/webhooks/123456789/abcDEF-ghi_jkl';
const mkEnv = (kv, plus = {}) => ({ REPO: 'o/r', GITHUB_TOKEN: 'jeton-de-test', LIMITES: kv, ...plus });
async function appeler(env, chemin, corps, { ip = '9.9.9.9', brut, entetes = {}, methode = 'POST' } = {}) {
  const init = { method: methode, headers: { 'X-Aerox': '1', 'Content-Type': 'application/json', 'CF-Connecting-IP': ip, ...entetes } };
  if (methode === 'POST') init.body = brut !== undefined ? brut : JSON.stringify(corps);
  try {
    const r = await worker.fetch(new Request('https://relais.test' + chemin, init), env, ctx);
    await Promise.all(attente); attente = [];
    const texte = await r.text();
    let json = null; try { json = JSON.parse(texte); } catch {}
    return { statut: r.status, texte, json };
  } catch (e) { return { statut: 'EXCEPTION', texte: String(e && e.message || e), json: null }; }
}
const lire = async (env, chemin) => appeler(env, chemin, undefined, { methode: 'GET' });

// ---------------------------------------------------------------- Mini cadre de test
const echecs = [];
let nbTests = 0;
function attendu(condition, message) { if (!condition) throw new Error(message); }
async function test(nom, code) {
  nbTests++;
  appels = []; attente = []; github = { panne: false, statut: 201, avis: [] };
  reglerHeure('2026-10-21T10:05:00Z');
  try { worker = await chargerRelais(); await code(); console.log(`[OK   ] ${nom}`); }
  catch (e) { echecs.push(`${nom} : ${e.message}`); console.log(`[ECHEC] ${nom} : ${e.message}`); }
}
const rapport = (extra = {}) => ({ title: '[Bug v2.5.3] ça ne démarre plus', body: '## Rapport AEROX PC Care\n- Version : 2.5.3\n\n### Ce qui s\'est passé\nÇa plante au démarrage 👍\n\n### Fin du journal\n```\nligne 1\n```', version: '2.5.3', ...extra });
const idAvis = (c) => c.repeat(32);

// ================================================================ R1. Texte venu d'un inconnu : nettoyé avant publication
await test('R1 · rapport : mentions, liens, images, balises, commentaires et renvois à d\'autres tickets sont neutralisés', async () => {
  const env = mkEnv(new KV());
  const r = await appeler(env, '/', rapport({
    title: 'Bug @octocat @everyone\nsecond titre <!-- caché -->',
    body: 'Salut @Aerox62550 et @github/team\n[Télécharge le correctif](https://evil.example/fix.exe)\n![pixel](https://evil.example/p.png)\n<img src="https://evil.example/p.png"> <a href="https://evil.example">clic</a> <script>x</script>\n<!-- texte caché -->\nVoir Aerox62550/AeroxPCCare#1 et #12\nwww.evil.example http://evil.example/a‮exe.txt\u0007\u0000'
  }));
  attendu(r.statut === 200 && r.json && r.json.ok, 'rapport refusé : ' + r.texte);
  const t = dernierTicket();
  const tout = t.title + '\n' + t.body;
  attendu(!/@(?!​)/.test(tout), 'une mention @ est restée active');
  attendu(!/\]\(/.test(tout), 'un lien Markdown est resté actif');
  attendu(!/:\/\/(?!​)/.test(tout), 'une adresse est restée cliquable');
  attendu(!/<(?=[a-zA-Z\/!?])/.test(tout), 'une balise HTML est restée active');
  attendu(!/<!--|-->/.test(t.body.replace(/_Envoyé[\s\S]*$/, '')) && !/<!--|-->/.test(t.title), 'un commentaire caché est resté');
  attendu(!/#\d/.test(tout), 'un renvoi vers un ticket (#12) est resté actif');
  attendu(!/\bwww\.(?!​)/i.test(tout), 'une adresse en www est restée cliquable');
  attendu(!/[‪-‮\u0000-\u0008]/.test(tout), 'un caractère de contrôle ou d\'inversion du texte est resté');
  attendu(!t.title.includes('\n'), 'le titre contient un saut de ligne');
  attendu(t.labels.length === 1 && t.labels[0] === 'bug', 'étiquette inattendue');
});
await test('R1 · rapport : le contenu normal reste intact (accents, titres, bloc de code, émojis, texte lisible)', async () => {
  const env = mkEnv(new KV());
  const src = rapport();
  await appeler(env, '/', src);
  const t = dernierTicket();
  attendu(t.title === src.title, 'titre modifié : ' + t.title);
  attendu(t.body.startsWith(src.body), 'le corps normal a été modifié :\n' + t.body);
  attendu(t.body.endsWith('_Envoyé depuis AEROX PC Care 2.5.3 (sans compte GitHub)._'), 'pied de page inattendu');
});
await test('R1 · rapport : la version affichée en pied de page ne peut contenir ni mise en forme ni lien', async () => {
  const env = mkEnv(new KV());
  await appeler(env, '/', rapport({ version: '2.5.3 **gras** [x](https://evil.example) @octocat' }));
  attendu(/_Envoyé depuis AEROX PC Care 2\.5\.3 \(sans compte GitHub\)\._$/.test(dernierTicket().body), 'pied de page : ' + dernierTicket().body.slice(-120));
});
await test('R1 · avis : commentaire et pseudo nettoyés, impossible de falsifier la note cachée', async () => {
  const env = mkEnv(new KV());
  const r = await appeler(env, '/avis', { note: 2, pseudo: 'Pirate @octocat\n**gras** <b>x</b>', commentaire: 'Nul @everyone <!-- note:5 --> [lien](https://evil.example) #7', version: '2.5.3', id: idAvis('a') });
  attendu(r.statut === 200 && r.json.ok, 'avis refusé : ' + r.texte);
  const t = dernierTicket();
  const tout = t.title + '\n' + t.body;
  attendu(!/@(?!​)/.test(tout) && !/\]\(/.test(tout) && !/#\d/.test(tout) && !/<(?=[a-zA-Z])/.test(tout), 'texte actif resté dans l\'avis');
  attendu((t.body.match(/<!-- note:/g) || []).length === 1 && /<!-- note:2 -->$/.test(t.body), 'la note cachée a été falsifiée : ' + t.body);
  attendu(!t.title.includes('\n'), 'saut de ligne dans le titre');
});
await test('R1 · Discord : aucun ping possible (allowed_mentions vide) et texte déjà nettoyé', async () => {
  const env = mkEnv(new KV(), { DISCORD_BUGS: WEBHOOK });
  await appeler(env, '/', rapport({ body: 'Salut @everyone @here <@123456789> [piège](https://evil.example)\n### Fin du journal\nx' }));
  const d = appelsDiscord();
  attendu(d.length === 1, 'envoi Discord attendu : ' + d.length);
  attendu(Array.isArray(d[0].corps.allowed_mentions.parse) && d[0].corps.allowed_mentions.parse.length === 0, 'allowed_mentions non vide');
  const desc = d[0].corps.embeds[0].description;
  attendu(!/@(?!​)/.test(desc) && !/\]\(https:\/\/evil/.test(desc), 'mention ou lien actif dans Discord : ' + desc);
});

// ================================================================ R2. Requêtes invalides : une réponse propre, jamais d'exception
await test('R2 · corps « null », liste, texte, nombre, JSON cassé, vide : erreur 400 propre sur les 3 adresses', async () => {
  const env = mkEnv(new KV());
  const mauvais = ['null', '[]', '"texte"', '123', 'true', '{', '', '\u0000\u0001\u0002', '{"a":'];
  for (const chemin of ['/', '/avis', '/stats']) for (const brut of mauvais) {
    const r = await appeler(env, chemin, undefined, { brut, ip: '5.5.5.' + (1 + Math.floor(Math.random() * 200)) });
    attendu(r.statut === 400 && r.json && typeof r.json.error === 'string', `${chemin} avec ${JSON.stringify(brut)} -> ${r.statut} ${r.texte.slice(0, 80)}`);
  }
});
await test('R2 · champs de mauvais type (titre objet, note nulle, ev liste…) : pas d\'exception', async () => {
  const env = mkEnv(new KV());
  const cas = [
    ['/', { title: { a: 1 }, body: ['x'], version: { v: 1 } }],
    ['/', { title: null, body: 'rapport', version: null }],
    ['/avis', { note: null }], ['/avis', { note: 'abc' }], ['/avis', { note: 4, commentaire: { x: 1 }, pseudo: ['a'], id: 12345, version: {} }],
    ['/stats', { v: { a: 1 }, ev: [1, 2] }], ['/stats', { v: 'x', ev: 'texte', nouveau_mois: 'oui' }], ['/stats', { ev: { 'probleme:a': { x: 1 }, 'lent:b': 'beaucoup', 'diag': -3 } }]
  ];
  let i = 0;
  for (const [chemin, corps] of cas) {
    const r = await appeler(env, chemin, corps, { ip: '6.6.6.' + (++i) });
    attendu(r.statut !== 'EXCEPTION' && r.statut !== 500, `${chemin} ${JSON.stringify(corps)} -> ${r.statut} ${r.texte}`);
    attendu(r.json && (r.json.ok === true || typeof r.json.error === 'string'), `réponse non JSON : ${r.texte}`);
  }
});
await test('R2 · GitHub injoignable ou qui refuse : erreur 502 claire (rapport et avis)', async () => {
  const env = mkEnv(new KV());
  github.panne = true;
  let r = await appeler(env, '/', rapport(), { ip: '2.2.2.1' });
  attendu(r.statut === 502 && /GitHub/.test(r.json.error), 'rapport, GitHub coupé : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/avis', { note: 5, id: idAvis('b') }, { ip: '2.2.2.2' });
  attendu(r.statut === 502, 'avis, GitHub coupé : ' + r.statut + ' ' + r.texte);
  github.panne = false; github.statut = 422;
  r = await appeler(env, '/', rapport(), { ip: '2.2.2.3' });
  attendu(r.statut === 502 && /422/.test(r.json.error), 'GitHub refuse : ' + r.statut + ' ' + r.texte);
});
await test('R2 · adresses et méthodes : accueil, refus sans en-tête, adresse inconnue', async () => {
  const env = mkEnv(new KV());
  let r = await appeler(env, '/', undefined, { methode: 'GET' });
  attendu(r.statut === 200 && /relais/.test(r.texte), 'accueil');
  r = await appeler(env, '/', rapport(), { entetes: { 'X-Aerox': '0' } });
  attendu(r.statut === 400, 'sans X-Aerox valide : ' + r.statut);
  r = await appeler(env, '/n-importe-quoi', rapport());
  attendu(r.statut === 404, 'adresse inconnue publiée comme rapport : ' + r.statut);
  attendu(issuesCreees().length === 0, 'un ticket a été créé par erreur');
  r = await appeler(env, '/', rapport()); attendu(r.statut === 200, 'POST / refusé');
  r = await appeler(env, '', rapport(), { ip: '9.9.9.8' }); attendu(r.statut === 200, 'POST sans barre refusé');
});

// ================================================================ R3. Statistiques : clés piégées
await test('R3 · la clé « constructor » (et autres noms de l\'objet) ne fausse plus les compteurs', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  // en texte brut : dans un objet JavaScript, « __proto__ » ne serait pas une clé comme les autres
  await appeler(env, '/stats', undefined, { brut: '{"v":"2.5.3","ev":{"constructor":1,"tostring":2,"valueof":1,"hasownproperty":1,"__proto__":1,"probleme:bsod":2}}' });
  await appeler(env, '/stats', { v: '2.5.3', ev: { constructor: 1, 'probleme:bsod': 1 } }, { ip: '9.9.9.1' });
  const s = JSON.parse(kv.m.get([...kv.m.keys()].find((k) => k.startsWith('stats:'))));
  attendu(s['probleme:bsod'] === 3, 'probleme:bsod = ' + s['probleme:bsod']);
  for (const [k, v] of Object.entries(s)) if (k !== '_jours') attendu(typeof v === 'number' && Number.isFinite(v), `valeur non numérique : ${k} = ${v}`);
  attendu(!Object.prototype.hasOwnProperty.call(s, 'constructor'), 'constructor enregistré');
});
await test('R3 · un fichier du mois déjà abîmé est réparé à la lecture, sans perdre les bons compteurs', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  kv.m.set('stats:2026-10', JSON.stringify({ constructor: 'function Object() { [native code] }1', 'probleme:bsod': 3, 'lent:memoire': '7', cassé: 5, actifs: 4, _jours: { '2026-10-20': 2, 'n-importe-quoi': 9, '2026-10-19': 'x' } }));
  const g = await lire(env, '/stats?voir=1');
  attendu(!/function Object/.test(g.texte), 'le texte parasite est affiché');
  await appeler(env, '/stats', { v: '2.5.3', ev: { 'probleme:bsod': 1 } });
  const s = JSON.parse(kv.m.get('stats:2026-10'));
  attendu(s['probleme:bsod'] === 4 && s.actifs === 4, 'bons compteurs perdus : ' + JSON.stringify(s));
  attendu(!('constructor' in s) || typeof s.constructor !== 'string', 'texte parasite conservé');
  attendu(!('lent:memoire' in s) && !('cassé' in s), 'valeurs non numériques conservées');
  attendu(s._jours['2026-10-20'] === 2 && !('n-importe-quoi' in s._jours), 'compteurs de jours mal réparés : ' + JSON.stringify(s._jours));
});

// ================================================================ R4. Limites d'envoi
await test('R4 · 5 rapports par heure et par adresse (envois l\'un après l\'autre) : le 6e est refusé, l\'heure suivante repart', async () => {
  const env = mkEnv(new KV());
  const codes = [];
  for (let i = 0; i < 7; i++) codes.push((await appeler(env, '/', rapport({ title: 't' + i }), { ip: '7.7.7.7' })).statut);
  attendu(codes.join() === '200,200,200,200,200,429,429', 'codes : ' + codes.join());
  attendu(issuesCreees().length === 5, 'tickets créés : ' + issuesCreees().length);
  avancer(HEURE);
  attendu((await appeler(env, '/', rapport(), { ip: '7.7.7.7' })).statut === 200, 'pas de reprise à l\'heure suivante');
});
await test('R4 · plafond global : 30 rapports par heure toutes adresses confondues, 100 par jour', async () => {
  const kv = new KV(); const env = mkEnv(kv, { DISCORD_BUGS: WEBHOOK });
  let ok = 0, refus = 0;
  for (let i = 0; i < 40; i++) { const r = await appeler(env, '/', rapport({ title: 'g' + i }), { ip: '10.0.0.' + (i + 1) }); if (r.statut === 200) ok++; else if (r.statut === 429) refus++; }
  attendu(ok === 30 && refus === 10, `acceptés ${ok}, refusés ${refus}`);
  const alertes = appelsDiscord().filter((c) => /Plafond/.test(c.corps.embeds[0].title));
  attendu(alertes.length === 1, 'alertes Discord : ' + alertes.length + ' (une seule par heure attendue)');
  // Les heures suivantes : 30 + 30 + 30 = 90, puis 10 de plus = 100 (plafond du jour) ; le suivant est refusé
  let total = 30;
  for (const h of [1, 2, 3]) {
    avancer(HEURE);
    for (let i = 0; i < 31 && total < 100; i++) { const r = await appeler(env, '/', rapport(), { ip: `10.${h}.0.${i + 1}` }); if (r.statut === 200) total++; }
  }
  attendu(total === 100, 'total accepté dans la journée : ' + total);
  avancer(HEURE);
  const r = await appeler(env, '/', rapport(), { ip: '10.9.9.9' });
  attendu(r.statut === 429, 'le plafond du jour n\'a pas bloqué : ' + r.statut);
  reglerHeure('2026-10-22T00:30:00Z');
  attendu((await appeler(env, '/', rapport(), { ip: '10.9.9.9' })).statut === 200, 'pas de reprise le lendemain');
});
await test('R4 · plafond global des avis : 15 par heure', async () => {
  const env = mkEnv(new KV());
  let ok = 0;
  for (let i = 0; i < 20; i++) { const r = await appeler(env, '/avis', { note: 4, commentaire: 'ok', id: idAvis('c') + i, version: '2.5.3' }, { ip: '11.0.0.' + (i + 1) }); if (r.statut === 200) ok++; }
  attendu(ok === 15, 'avis acceptés : ' + ok);
});
await test('R4 · 25 envois simultanés depuis la même adresse : 5 acceptés seulement (compteur en mémoire du Worker, sans course)', async () => {
  const env = mkEnv(new KV({ delai: 10 }));
  const rs = await Promise.all(Array.from({ length: 25 }, (_, i) => appeler(env, '/', rapport({ title: 's' + i }), { ip: '7.7.7.7' })));
  const ok = rs.filter((r) => r.statut === 200).length;
  attendu(ok === 5 && rs.filter((r) => r.statut === 429).length === 20, `acceptés ${ok} sur 25`);
  attendu(issuesCreees().length === 5, 'tickets créés : ' + issuesCreees().length);
  attendu((await appeler(env, '/', rapport(), { ip: '7.7.7.7' })).statut === 429, 'l\'envoi suivant n\'est pas bloqué');
});
await test('R4 · 100 envois simultanés de 100 adresses différentes : 30 acceptés (plafond de l\'heure)', async () => {
  const env = mkEnv(new KV({ delai: 10 }));
  const rs = await Promise.all(Array.from({ length: 100 }, (_, i) => appeler(env, '/', rapport({ title: 'm' + i }), { ip: '20.0.0.' + (i + 1) })));
  const ok = rs.filter((r) => r.statut === 200).length;
  attendu(ok === 30 && issuesCreees().length === 30, `acceptés ${ok}, tickets ${issuesCreees().length}`);
});
await test('R4 · 200 envois de statistiques simultanés depuis la même adresse : 20 acceptés, écritures KV bornées', async () => {
  const kv = new KV({ delai: 5 }); const env = mkEnv(kv);
  const rs = await Promise.all(Array.from({ length: 200 }, () => appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '21.0.0.1' })));
  attendu(rs.filter((r) => r.statut === 200).length === 20, 'acceptés : ' + rs.filter((r) => r.statut === 200).length);
  attendu(kv.ecritures <= 40, 'écritures KV : ' + kv.ecritures);
});

// ================================================================ R5. Statistiques : inondation
await test('R5 · familles inconnues, « actifs » et « version » envoyés par un PC : ignorés (rien n\'est écrit)', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  const r = await appeler(env, '/stats', { v: '2.5.3', ev: { 'spam:a': 5, spam: 1, actifs: 50, 'version:9-9-9': 50, 'probleme:Majuscule': 1, 'probleme:': 1, ['lent:' + 'x'.repeat(41)]: 1 } });
  attendu(r.statut === 200 && r.json.ok, 'réponse : ' + r.texte);
  attendu(kv.ecritures === 0, 'écritures KV : ' + kv.ecritures);
});
await test('R5 · nombre de compteurs différents plafonné (400 par mois, 100 par famille) ; les existants continuent de compter', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  for (let p = 0; p < 6; p++) {
    const ev = {}; for (let j = 0; j < 60; j++) ev['probleme:p' + p + 'x' + j] = 1;
    await appeler(env, '/stats', { v: '2.5.3', ev }, { ip: '12.0.0.' + p });
  }
  let s = JSON.parse(kv.m.get('stats:2026-10'));
  const nProbleme = Object.keys(s).filter((k) => k.startsWith('probleme:')).length;
  attendu(nProbleme === 100, 'compteurs « probleme » : ' + nProbleme);
  await appeler(env, '/stats', { v: '2.5.3', ev: { 'probleme:p0x0': 2, 'lent:memoire': 1, 'jeu:rien': 1 } }, { ip: '12.0.1.1' });
  s = JSON.parse(kv.m.get('stats:2026-10'));
  attendu(s['probleme:p0x0'] === 3 && s['lent:memoire'] === 1 && s['jeu:rien'] === 1, 'les vrais compteurs ne passent plus : ' + JSON.stringify({ a: s['probleme:p0x0'], b: s['lent:memoire'] }));
  attendu(JSON.stringify(s).length < 30000, 'fichier trop gros : ' + JSON.stringify(s).length);
  // Au total, jamais plus de 400 compteurs différents
  for (const fam of ['lent', 'jeu', 'lag', 'erreur', 'corrige']) {
    const ev = {}; for (let j = 0; j < 59; j++) ev[fam + ':z' + j] = 1;
    await appeler(env, '/stats', { v: '2.5.3', ev }, { ip: '12.1.0.' + fam.length });
    await appeler(env, '/stats', { v: '2.5.3', ev: Object.fromEntries(Object.keys(ev).map((k) => [k.replace(':z', ':y'), 1])) }, { ip: '12.2.0.' + fam.length });
  }
  s = JSON.parse(kv.m.get('stats:2026-10'));
  attendu(Object.keys(s).filter((k) => k !== '_jours').length <= 400, 'plus de 400 compteurs : ' + Object.keys(s).length);
});
await test('R5 · 20 envois par jour et par adresse : le 21e est refusé par une erreur (le logiciel garde ses compteurs)', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  const codes = [];
  for (let i = 0; i < 22; i++) codes.push((await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '13.0.0.1' })).statut);
  attendu(codes.slice(0, 20).every((c) => c === 200) && codes[20] === 429 && codes[21] === 429, 'codes : ' + codes.join());
  attendu(JSON.parse(kv.m.get('stats:2026-10')).diag === 20, 'diag = ' + JSON.parse(kv.m.get('stats:2026-10')).diag);
  const r = await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '13.0.0.1' });
  attendu(typeof r.json.error === 'string' && !('ok' in r.json), 'la réponse de refus doit être une erreur');
});
await test('R5 · plafond de 300 envois par jour : au-delà, erreur ; les écritures KV de statistiques restent bornées ; les rapports passent toujours', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  let ok = 0, refus = 0;
  for (let i = 0; i < 330; i++) {
    const r = await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1, 'probleme:a': 1 } }, { ip: `14.${Math.floor(i / 250)}.${i % 250}.1` });
    if (r.statut === 200) ok++; else if (r.statut === 429) refus++;
  }
  attendu(ok === 300 && refus === 30, `acceptés ${ok}, refusés ${refus}`);
  attendu(kv.ecritures <= 600, 'écritures KV : ' + kv.ecritures);
  const r = await appeler(env, '/', rapport(), { ip: '14.9.9.9' });
  attendu(r.statut === 200 && r.json.ok, 'un rapport légitime est refusé après l\'inondation de statistiques : ' + r.texte);
  reglerHeure('2026-10-22T09:00:00Z');
  attendu((await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '14.9.9.9' })).statut === 200, 'pas de reprise le lendemain');
});
await test('R5 · « nouveau_mois » compte un PC actif et sa version ; une version inventée est ignorée', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  await appeler(env, '/stats', { v: '2.5.3', nouveau_mois: true, ev: { 'maj:2-5-3': 1 } });
  await appeler(env, '/stats', { v: '<script>', nouveau_mois: true, ev: {} }, { ip: '9.9.9.1' });
  await appeler(env, '/stats', { v: '1.2.3.4.5', nouveau_mois: true, ev: {} }, { ip: '9.9.9.2' });
  const s = JSON.parse(kv.m.get('stats:2026-10'));
  attendu(s.actifs === 3 && s['version:2-5-3'] === 1 && s['maj:2-5-3'] === 1, JSON.stringify(s));
  attendu(Object.keys(s).filter((k) => k.startsWith('version:')).length === 1, 'version inventée acceptée : ' + Object.keys(s).join());
});
await test('R5 · GET /stats : le logiciel sait si les statistiques sont reçues ; ?voir=1 donne les compteurs et les plafonds du jour', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  let r = await lire(env, '/stats'); attendu(r.json.aerox === 'stats' && r.json.ok === true, r.texte);
  r = await lire({ REPO: 'o/r', GITHUB_TOKEN: 'x' }, '/stats'); attendu(r.json.ok === false, 'sans KV : ' + r.texte);
  await appeler(env, '/stats', { v: '2.5.3', ev: { 'probleme:bsod': 2, diag: 1 } });
  await appeler(env, '/', rapport(), { ip: '3.3.3.3' });
  r = await lire(env, '/stats?voir=1');
  attendu(r.json['2026-10'].compteurs['probleme:bsod'] === 2 && r.json['2026-10'].envois === 1, r.texte);
  attendu(/1\/100/.test(r.json.plafonds['rapports de bug']) && /1\/300/.test(r.json.plafonds['statistiques']), 'plafonds : ' + JSON.stringify(r.json.plafonds));
});

// ================================================================ R6. Espace KV en panne ou quota épuisé
await test('R6 · quota d\'écritures KV épuisé : rapports et avis passent encore, les statistiques répondent proprement', async () => {
  const env = mkEnv(new KV({ quotaEcritures: 0 }));
  let r = await appeler(env, '/', rapport(), { ip: '4.4.4.4' });
  attendu(r.statut === 200 && r.json.ok && r.json.number, 'rapport : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/avis', { note: 4, commentaire: 'ok', id: idAvis('d') }, { ip: '4.4.4.5' });
  attendu(r.statut === 200 && r.json.ok, 'avis : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '4.4.4.6' });
  attendu(r.statut === 503 && typeof r.json.error === 'string', 'statistiques : ' + r.statut + ' ' + r.texte);
  r = await lire(env, '/note'); attendu(r.statut === 200 && r.json.schemaVersion === 1, 'badge : ' + r.statut + ' ' + r.texte);
  r = await lire(env, '/stats?voir=1'); attendu(r.statut === 200, 'lecture des compteurs : ' + r.statut);
});
await test('R6 · espace KV entièrement en panne (lectures et écritures) : rapport et avis passent, statistiques en erreur propre', async () => {
  const env = mkEnv(new KV({ quotaEcritures: 0, lectureEnPanne: true }));
  let r = await appeler(env, '/', rapport(), { ip: '4.4.5.4' });
  attendu(r.statut === 200 && r.json.ok, 'rapport : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/avis', { note: 5, id: idAvis('e') }, { ip: '4.4.5.5' });
  attendu(r.statut === 200 && r.json.ok, 'avis : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip: '4.4.5.6' });
  attendu(r.statut === 503, 'statistiques : ' + r.statut + ' ' + r.texte);
});
await test('R6 · aucun espace KV lié : rapports et avis passent, statistiques indisponibles (503)', async () => {
  const env = { REPO: 'o/r', GITHUB_TOKEN: 'x' };
  let r = await appeler(env, '/', rapport(), { ip: '4.4.6.4' }); attendu(r.statut === 200, 'rapport : ' + r.statut + ' ' + r.texte);
  r = await appeler(env, '/avis', { note: 5, id: idAvis('f') }, { ip: '4.4.6.5' }); attendu(r.statut === 200, 'avis : ' + r.statut);
  r = await appeler(env, '/stats', { ev: { diag: 1 } }); attendu(r.statut === 503, 'stats : ' + r.statut);
});
await test('R6 · Discord : le dernier résultat n\'est réécrit qu\'une fois par heure (économie d\'écritures KV)', async () => {
  const kv = new KV(); const env = mkEnv(kv, { DISCORD_BUGS: WEBHOOK });
  for (let i = 0; i < 4; i++) await appeler(env, '/', rapport({ title: 'd' + i }), { ip: '15.0.0.' + i });
  attendu(kv.ecrituresParCle.get('discord:DISCORD_BUGS') === 1, 'écritures de la note Discord : ' + kv.ecrituresParCle.get('discord:DISCORD_BUGS'));
  attendu(appelsDiscord().length === 4, 'envois Discord : ' + appelsDiscord().length);
  attendu(/envoyé$/.test(kv.m.get('discord:DISCORD_BUGS')), 'note : ' + kv.m.get('discord:DISCORD_BUGS'));
});

// ================================================================ R7. Adresse IP
await test('R7 · l\'adresse IP n\'est écrite nulle part (ni clé ni valeur du KV) et l\'empreinte change chaque heure', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  const ip = '203.0.113.77';
  await appeler(env, '/', rapport(), { ip });
  await appeler(env, '/avis', { note: 5, id: idAvis('9') }, { ip });
  await appeler(env, '/stats', { v: '2.5.3', ev: { diag: 1 } }, { ip });
  const avant = [...kv.m.keys()].filter((k) => k.startsWith('ip:'));
  attendu(avant.length === 3, 'clés de limite : ' + avant.join());
  const tout = JSON.stringify([...kv.m.entries()]);
  attendu(!tout.includes(ip) && !tout.includes('203.0.113') && !tout.includes('113.77'), 'adresse IP retrouvée dans le KV');
  avancer(HEURE);
  await appeler(env, '/', rapport(), { ip });
  const apres = [...kv.m.keys()].filter((k) => k.startsWith('ip:bug:'));
  attendu(apres.length === 2 && apres[0].split(':')[2] !== apres[1].split(':')[2], 'l\'empreinte ne change pas d\'une heure à l\'autre : ' + apres.join());
});
await test('R7 · deux adresses différentes ont deux empreintes différentes ; sans clé secrète configurée, le relais fonctionne quand même', async () => {
  const kv = new KV(); const env = { REPO: 'o/r', LIMITES: kv };   // ni GITHUB_TOKEN ni SEL_IP
  await appeler(env, '/', rapport(), { ip: '1.1.1.1' });
  await appeler(env, '/', rapport(), { ip: '1.1.1.2' });
  attendu([...kv.m.keys()].filter((k) => k.startsWith('ip:bug:')).length === 2, 'empreintes : ' + [...kv.m.keys()].join());
});

// ================================================================ R8 et tailles
await test('R8 · le relais ne contrôle qu\'une fois l\'en-tête X-Aerox et la taille (plus de code en double)', async () => {
  attendu((sourceRelais.match(/headers\.get\('X-Aerox'\)/g) || []).length === 1, 'contrôle X-Aerox en double');
  attendu((sourceRelais.match(/headers\.get\('Content-Length'\)/g) || []).length === 1, 'contrôle Content-Length en double');
});
await test('Taille · 5 Mo sans Content-Length, ou Content-Length trop grand : refusés (413) sans créer de ticket', async () => {
  const env = mkEnv(new KV());
  const gros = JSON.stringify({ title: 't', body: 'x'.repeat(5 * 1024 * 1024), version: '2.5.3' });
  let r = await appeler(env, '/', undefined, { brut: gros, ip: '3.3.3.3' });
  attendu(r.statut === 413, 'sans en-tête : ' + r.statut);
  r = await appeler(env, '/', undefined, { brut: '{}', entetes: { 'Content-Length': '999999' }, ip: '3.3.3.4' });
  attendu(r.statut === 413, 'en-tête trop grand : ' + r.statut);
  r = await appeler(env, '/stats', undefined, { brut: gros, ip: '3.3.3.5' });
  attendu(r.statut === 413, 'statistiques : ' + r.statut);
  attendu(issuesCreees().length === 0, 'ticket créé');
});
await test('Taille · un rapport de 90 000 caractères est tronqué à 60 000 (le plafond de GitHub est 65 536)', async () => {
  const env = mkEnv(new KV());
  const r = await appeler(env, '/', rapport({ body: 'a'.repeat(90000) }));
  attendu(r.statut === 200, 'rapport refusé : ' + r.statut + ' ' + r.texte);
  attendu(dernierTicket().body.length <= 60000 + 200, 'taille : ' + dernierTicket().body.length);
});

// ================================================================ Fonctionnement normal (non-régression)
await test('Rapport normal : ticket « bug » créé, réponse { ok, number, url }, copie Discord avec lien vers le ticket', async () => {
  const env = mkEnv(new KV(), { DISCORD_BUGS: WEBHOOK });
  const r = await appeler(env, '/', rapport());
  attendu(r.statut === 200 && r.json.ok && r.json.number === 1 && /issues\/1$/.test(r.json.url), r.texte);
  const d = appelsDiscord();
  attendu(d.length === 1 && d[0].corps.embeds[0].url.endsWith('/issues/1') && /Voir le rapport complet/.test(d[0].corps.embeds[0].description), 'Discord : ' + JSON.stringify(d.map((x) => x.corps)));
  attendu(!/Fin du journal/.test(d[0].corps.embeds[0].description), 'la fin du journal ne doit pas aller dans Discord');
});
await test('Avis : créé, puis modifié (et non dupliqué) quand le même PC le renvoie ; pas de numéro réutilisé pour un autre PC', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  let r = await appeler(env, '/avis', { note: 5, commentaire: 'Génial', pseudo: 'Léa', version: '2.5.3', id: idAvis('1') });
  attendu(r.statut === 200 && r.json.number === 1 && !r.json.updated, r.texte);
  attendu(dernierTicket().labels[0] === 'avis' && dernierTicket().title.startsWith('★★★★★ 5/5 · Léa'), 'titre : ' + dernierTicket().title);
  r = await appeler(env, '/avis', { note: 4, commentaire: 'Très bien', pseudo: 'Léa', version: '2.5.4', id: idAvis('1') });
  attendu(r.statut === 200 && r.json.updated === true && r.json.number === 1, 'modification : ' + r.texte);
  attendu(issuesCreees().length === 1 && appels.some((c) => c.methode === 'PATCH'), 'doublon créé');
  r = await appeler(env, '/avis', { note: 3, id: idAvis('2') }, { ip: '9.9.9.2' });
  attendu(r.json.number === 2 && !r.json.updated, 'autre PC : ' + r.texte);
  r = await appeler(env, '/avis', { note: 6 }); attendu(r.statut === 400 && /Note/.test(r.json.error), 'note invalide : ' + r.texte);
});
await test('Badge : note moyenne des avis ouverts, mise en cache 10 minutes dans le KV', async () => {
  const kv = new KV(); const env = mkEnv(kv);
  github.avis = [{ body: 'x\n<!-- note:5 -->' }, { body: 'y\n<!-- note:4 -->' }, { body: 'sans note' }];
  let r = await lire(env, '/note');
  attendu(r.json.message === '★ 4,5 / 5 · 2 avis' && r.json.color === '8b5cf6', r.texte);
  const n = appels.length;
  r = await lire(env, '/note');
  attendu(appels.length === n && r.json.message === '★ 4,5 / 5 · 2 avis', 'pas de mise en cache');
  github.avis = []; kv.m.delete('badge');
  r = await lire(env, '/note'); attendu(/pas encore/.test(r.json.message), r.texte);
});

// ================================================================ Accord avec le logiciel
await test('Accord logiciel/relais : les familles de compteurs du logiciel sont toutes acceptées par le relais, et inversement', async () => {
  const lib = readFileSync(join(racine, 'src', '2_lib.ps1'), 'utf8');
  const m = /\$script:StatsPrefixes\s*=\s*@\(([^)]*)\)/.exec(lib);
  attendu(m, '$script:StatsPrefixes introuvable dans src/2_lib.ps1');
  const app = [...m[1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]).sort();
  const r = /STATS_FROM_APP\s*=\s*new Set\(\[([^\]]*)\]\)/.exec(sourceRelais);
  attendu(r, 'STATS_FROM_APP introuvable dans relais/worker.js');
  const relais = [...r[1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]).filter((p) => p !== 'maj').sort();
  const appSansMaj = app.filter((p) => p !== 'maj');
  attendu(JSON.stringify(appSansMaj) === JSON.stringify(relais), `listes différentes.\n  logiciel : ${appSansMaj.join(' ')}\n  relais   : ${relais.join(' ')}`);
  attendu(app.includes('maj') && /'maj'/.test(r[1]), '« maj » (envoyé par Send-Stats) doit être dans les deux listes');
  // Chaque appel de Add-StatsEvent du logiciel n'utilise que des familles connues
  const fichiers = readdirSync(join(racine, 'src')).filter((f) => f.endsWith('.ps1'));
  // Le texte qui suit « Add-StatsEvent » jusqu'à la fin de l'appel (parenthèses et guillemets équilibrés)
  const argumentsDe = (ligne, debut) => {
    let prof = 0, guillemet = null, sortie = '';
    for (let i = debut; i < ligne.length; i++) {
      const c = ligne[i];
      if (guillemet) { sortie += c; if (c === guillemet) guillemet = null; continue; }
      if (c === "'" || c === '"') { guillemet = c; sortie += c; continue; }
      if (c === '(') prof++;
      if (c === ')' && --prof < 0) break;
      if (prof === 0 && (c === ';' || c === '}')) break;
      sortie += c;
    }
    return sortie;
  };
  let appelsTrouves = 0;
  for (const f of fichiers) {
    for (const [n, ligne] of readFileSync(join(racine, 'src', f), 'utf8').split('\n').entries()) {
      if (!/Add-StatsEvent/.test(ligne) || /function Add-StatsEvent/.test(ligne)) continue;
      appelsTrouves++;
      const appel = argumentsDe(ligne, ligne.indexOf('Add-StatsEvent') + 'Add-StatsEvent'.length);
      for (const q of appel.matchAll(/'([^']*)'|"([^"]*)"/g)) {
        const mot = (q[1] ?? q[2]).split(':')[0];
        if (/^[a-z]+$/.test(mot)) attendu(app.includes(mot), `${f} ligne ${n + 1} : la famille « ${mot} » n'est pas dans $script:StatsPrefixes (ni dans le relais)`);
      }
    }
  }
  attendu(appelsTrouves >= 10, 'appels de Add-StatsEvent trouvés : ' + appelsTrouves + ' (le test ne lit plus le logiciel ?)');
});

console.log(`\n${nbTests} vérifications, ${echecs.length} échec(s)`);
for (const e of echecs) console.log('  - ' + e);
process.exit(echecs.length ? 1 : 0);
