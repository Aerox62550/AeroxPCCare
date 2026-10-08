# Rapports de bug sans compte GitHub : mise en place du relais (10 minutes, gratuit)

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
