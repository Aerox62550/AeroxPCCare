# Rapports de bug et avis sans compte GitHub : mise en place du relais (10 minutes, gratuit)

Le bouton « Envoyer le rapport » du logiciel passe par un petit relais (Cloudflare Worker) qui
crée l'Issue sur GitHub. La clé d'accès GitHub reste dans le relais : elle n'est jamais dans le logiciel.

## 1. Le jeton GitHub (accès limité aux Issues de ce dépôt)
1. GitHub > photo de profil > **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens** > **Generate new token**.
2. Nom : `aerox-relais`. Expiration : 1 an (à renouveler ensuite).
3. **Repository access** : *Only select repositories* > `AeroxPCCare`.
4. **Permissions** > **Repository permissions** > **Issues** : *Read and write*. Rien d'autre.
5. **Generate token** et copie le jeton (il ne s'affiche qu'une fois). Ne le donne à personne.

## 2. Le relais Cloudflare
1. Crée un compte gratuit sur **dash.cloudflare.com**.
2. **Workers & Pages** > **Create** > **Create Worker** > nom : `aerox-relais` > **Deploy**.
3. **Edit code** : remplace tout par le contenu de `relais/worker.js`, puis **Deploy**.
4. **Settings** > **Variables and Secrets** :
   - **Add** > type *Text* > nom `REPO` > valeur `Aerox62550/AeroxPCCare`
   - **Add** > type *Secret* > nom `GITHUB_TOKEN` > colle le jeton de l'étape 1
   - **Deploy**.
5. Anti-abus (recommandé) : **Storage & Databases** > **KV** > **Create** (nom `aerox-limites`), puis dans le Worker :
   **Settings** > **Bindings** > **Add** > *KV namespace* > nom de variable `LIMITES` > `aerox-limites` > **Deploy**.
6. Note l'adresse du Worker, du style `https://aerox-relais.<ton-nom>.workers.dev`.

## 3. Brancher le logiciel
Mets cette adresse (une seule ligne) dans le fichier `relais.txt` à la racine du dépôt.
Le logiciel lit ce fichier sur GitHub : pas besoin de nouvelle version, tous les PC l'utilisent au prochain rapport.
Pour couper le relais : vide le fichier `relais.txt`.

Les rapports arrivent dans l'onglet **Issues** du dépôt (étiquette `bug`). Ils sont publics comme le dépôt,
mais ne contiennent ni nom d'utilisateur, ni nom du PC, ni adresse e-mail (remplacés automatiquement).

## 4. Avis (note + commentaire)
Le même relais publie les avis (bouton « Donner mon avis » du logiciel) dans les Issues, étiquette `avis`,
et calcule la note moyenne affichée par le badge du README (`https://aerox-relais.<ton-nom>.workers.dev/note`).
- Mise à jour du relais : Cloudflare > Workers & Pages > `aerox-relais` > **Edit code** > remplace tout par le contenu
  de `relais/worker.js` > **Deploy**. Rien d'autre à changer (même jeton, même espace KV `LIMITES`).
- Un seul avis par PC : s'il est renvoyé, l'avis existant est modifié.
- Supprimer un avis : ouvre-le dans les Issues > **Close issue** (il ne compte plus dans la note), ou tout en bas
  **Delete issue** pour l'effacer complètement. La note du badge se met à jour en 10 minutes au plus.

## 5. Statistiques anonymes et copie dans Discord
- **Statistiques** : le logiciel envoie des compteurs (versions utilisées, types de problèmes), jamais de nom, de nom de PC, de chemin ni d'identifiant.
  Elles demandent l'espace KV `LIMITES` (étape 5 plus haut). Pour les lire : GitHub > **Actions** > **Statistiques** > **Run workflow**.
- **Discord** (facultatif) : crée un webhook dans le salon voulu (Paramètres du salon > Intégrations > Webhooks) et colle son adresse **directement dans
  Cloudflare** (Settings > Variables and Secrets > *Secret* `DISCORD_BUGS` pour les rapports, `DISCORD_AVIS` pour les avis). Ne l'envoie à personne.
  La tâche Statistiques indique si l'envoi vers Discord a marché.
- **Rapports de sécurité** (onglet Sécurité > « Envoyer au développeur ») : ils ne vont JAMAIS sur GitHub (public). Crée un salon Discord
  **privé** (visible de toi seul), un webhook dans ce salon, et colle son adresse dans le *Secret* `DISCORD_SECU`. Sans ce secret, le logiciel
  dit que l'envoi n'est pas encore activé. Chaque rapport arrive en fichier joint avec un code à 6 caractères : la personne te donne ce code
  sur Discord, tu lui réponds quels numéros cocher. Le relais n'envoie jamais rien au logiciel.
- **Secret facultatif `SEL_IP`** : un texte au hasard (20 caractères ou plus) qui sert à brouiller les adresses IP (voir plus bas). Sans lui, le relais
  utilise le jeton GitHub, ce qui revient au même ; inutile de l'ajouter sauf si tu préfères séparer les deux.

## 6. Protections intégrées (à connaître)
- **Texte nettoyé avant publication** : un rapport ou un avis venu d'un inconnu ne peut ni mentionner quelqu'un (`@`), ni citer un autre ticket (`#12`),
  ni cacher du texte (commentaires), ni afficher un lien, une image ou une balise cliquable (les adresses restent lisibles). Les gros mots sont déjà masqués par le logiciel.
- **Plafonds d'envoi** : 5 rapports (ou avis) par heure et par adresse ; au total 30 rapports par heure et 100 par jour, 15 avis par heure et 40 par jour ;
  statistiques : 20 envois par jour et par adresse, 300 par jour au total. Au-delà, le relais répond « très sollicité » ; le logiciel garde ses statistiques
  et les renvoie plus tard. Quand un plafond de rapports ou d'avis est atteint, **un message « Plafond d'envois atteint » arrive dans Discord** (au plus un par heure) :
  soit un vrai pic d'utilisation, soit du spam.
- **Limite connue** : le relais compte les envois dans sa mémoire (exact) et dans l'espace KV (qui ne sait que lire puis écrire). Si Cloudflare répartit un pic
  d'envois strictement simultanés sur plusieurs instances du relais, quelques envois de trop peuvent passer ; les plafonds suivants et les limites de GitHub bornent ensuite les dégâts.
- **Pannes** : si l'espace KV tombe en panne ou si son quota d'écritures du jour est épuisé (1000 sur l'offre gratuite), les rapports et les avis passent quand
  même (les limites sont alors levées), et les statistiques répondent « indisponible » proprement. Une inondation de statistiques ne peut pas épuiser ce quota :
  elle est arrêtée à 300 envois par jour. Chaque rapport accepté coûte 2 écritures, chaque avis 3, chaque envoi de statistiques 2.
- **Statistiques indicatives** : seuls les compteurs connus du logiciel sont acceptés, au plus 400 compteurs différents par mois. Rien ne peut empêcher quelqu'un
  d'envoyer de fausses valeurs : à lire comme des ordres de grandeur.
- **Adresse IP** : jamais écrite. Le relais ne garde qu'une empreinte secrète (HMAC-SHA-256 avec `SEL_IP`, à défaut le jeton GitHub) valable une heure pour les
  rapports et les avis, un jour pour les statistiques, qui sert uniquement à compter. L'identifiant d'un avis (un nombre au hasard propre à l'installation) est gardé pour pouvoir modifier cet avis.

## 7. Si quelqu'un envoie du spam
1. Ferme les tickets en masse : Issues > filtre (par exemple `label:bug`) > coche tout > **Close**. Supprime-les un par un si besoin (**Delete issue**).
2. Pour couper le relais tout de suite : vide le fichier `relais.txt` sur GitHub (les PC arrêtent de l'utiliser dès leur prochain rapport).
3. Si le jeton GitHub a pu fuiter : crée-en un nouveau (étape 1), remplace le secret `GITHUB_TOKEN` dans Cloudflare, supprime l'ancien jeton sur GitHub.
4. Bloquer une adresse précise n'est possible dans Cloudflare que si le relais a un domaine à lui (pas sur une adresse `*.workers.dev`) : Cloudflare > Security > WAF.

## 8. Mise à jour du relais
Quand `relais/worker.js` change (le journal des versions de `docs/PROCHAINE-VERSION.md` le dit) : Cloudflare > Workers & Pages > `aerox-relais` > **Edit code** > remplace tout par le
contenu du fichier > **Deploy**. Même jeton, même espace KV, rien d'autre à changer. Le fichier du dépôt est testé automatiquement (Actions > « Tester le relais »).
