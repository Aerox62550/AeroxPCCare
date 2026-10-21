# AEROX PC Care : guide développeur

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `src/` | Le logiciel (PowerShell + WPF), en 4 parties assemblées à la construction : réglages, chargement de la DLL, fonctions qui touchent au PC (`$TaskLibrary`), interface. |
| `native/` | `AeroxPCCare.Native.dll` : tailles de dossiers, overlay, raccourci clavier, FPS, capteurs, NuGet, mise à jour, test de débit. |
| `launcher/` | `AeroxPCCare.exe` : demande les droits admin et exécute le script ; mode `--capteurs` (températures dans un processus séparé). |
| `installer/` | Script NSIS de l'installateur. |
| `docs/` | Mode d'emploi (copié dans le logiciel), ce guide, et la mise en place du relais des rapports (`RELAIS-RAPPORTS.md`). |
| `relais/` | Relais Cloudflare Worker : publie les rapports de bug et les avis dans les Issues sans que l'utilisateur ait un compte GitHub, et reçoit les statistiques anonymes. Adresse lue dans `relais.txt`. |
| `tests/` | `smoke.ps1` (test complet sur Windows), `installation/` (installateur, lanceur, mise à jour, PresentMon réel), `relais/` (relais, sans réseau). Voir « Les tests ». |
| `build.sh` | Construit le zip et l'installateur dans `build/`. |

Construire en local (Linux / WSL) : `sudo apt install mono-devel nsis zip python3` puis `./build.sh`.

## Publier une nouvelle version

Deux branches : **`prochaine-version`** (le travail et les tests, `canal.txt` = `test`) et **`main`** (ce que les
utilisateurs reçoivent, `canal.txt` = `public`). Rien n'est publié tant que `main` ne change pas.

1. **Travailler** sur `prochaine-version`. À chaque envoi, GitHub lance les tests (voir « Les tests ») ; tout doit être vert.
2. **Numéro de version** : augmente `$AppVersion` (`src/1_head.ps1`), puis mets le même numéro en première ligne de
   `docs/LISEZMOI.txt`, dans `docs/PROCHAINE-VERSION.md` et dans `$script:WhatsNew` (`src/3_ui.ps1`, la fenêtre « Quoi de neuf »,
   en mots simples). `1.2.1` pour une correction, `1.3.0` pour une nouvelle fonction.
3. **Publier** (seulement quand Sam a dit « publie ») : fusionner `prochaine-version` dans `main` avec `public` dans `canal.txt`
   et `## Prêt…` devenu `## Publié en X :` dans `docs/PROCHAINE-VERSION.md`. `publier.yml` construit le logiciel et crée la Release
   avec `AeroxPCCare_Setup.exe` et `AeroxPCCare_Portable.zip` ; elle refuse de publier si le code a changé depuis une version
   portant déjà ce numéro. Avec `test` dans `canal.txt`, la Release est une pré-version : seuls les PC en **canal test** la reçoivent
   (7 clics rapides sur le numéro de version en bas à gauche du logiciel).
4. **Revenir** sur `prochaine-version`, y fusionner `main`, remettre `test` dans `canal.txt`.

Le lien direct de l'installateur (`.../releases/latest/download/AeroxPCCare_Setup.exe`) donne toujours la dernière
version **publique**. Le **relais Cloudflare n'est pas publié par GitHub** : après une modification de `relais/worker.js`,
copie le fichier dans Cloudflare (`docs/RELAIS-RAPPORTS.md`, « Mise à jour du relais »).

À faire à chaque automne : ajouter la nouvelle version de Windows 11 dans `$script:Win11Versions` (`src/2_lib.ps1`, dates de fin
de support par édition), sinon AEROX ne signale plus les versions périmées.

## Les tests (tous automatiques, à chaque envoi sur `prochaine-version`)

| Test (GitHub Actions) | Ce qu'il vérifie | Durée |
|---|---|---|
| **Vérifier sur Windows** (`verifier.yml`, `tests/smoke.ps1`) | Le vrai logiciel sur Windows (Windows PowerShell 5.1) : toutes les pages et fenêtres, les analyses, les actions et leurs annulations sur une machine jetable, les seuils du diagnostic, les protections de sécurité ; puis la version portable. Un défaut corrigé = un test ajouté ici. | environ 15 min |
| **Tester l'installation** (`installation.yml`, `tests/installation/`) | Le vrai installateur et le vrai lanceur : installation dans Program Files, droits du dossier, fichier modifié refusé au lancement, reprise d'une ancienne installation, tâche « lancer avec Windows », mise à jour, désinstallation ; le vrai PresentMon d'Intel (signature, rangement, copie remplacée refusée). Sur Windows Server 2025 et Windows 11 ARM. | environ 10 min |
| **Tester le relais** (`relais.yml`, `tests/relais/relais.test.mjs`) | Le relais Cloudflare avec un stockage, GitHub et Discord simulés : textes nettoyés, requêtes invalides, plafonds d'envoi, statistiques, pannes du stockage, adresse IP jamais écrite ; et la liste des compteurs du logiciel = celle du relais. | 15 s |

Les résultats se lisent dans l'onglet Actions, ou par `gh api repos/<dépôt>/check-runs/<id>/annotations` : le **résumé des échecs est
toujours la première annotation** (GitHub ne garde que 10 annotations par étape et coupe chacune vers 4 000 octets : le détail est
découpé en blocs de 3 000 caractères). Le test du relais se lance aussi à la main :
`node tests/relais/relais.test.mjs` (Node 20 ou plus récent, rien à installer).

## Règles de sécurité à ne pas casser

AEROX tourne en **administrateur** : ce qu'un autre programme du PC peut modifier ne doit jamais être exécuté ni cru.

- Tout est installé dans `C:\Program Files\AeroxPCCare` (l'installateur ne laisse pas le choix). Le **lanceur** est la racine de confiance :
  il refuse un `.ps1` ou une DLL dont l'empreinte SHA-256 n'est pas celle de sa version.
- `protege\` (outils, sceaux des annulations, mises à jour) est réservé aux administrateurs. Un outil tiers n'y entre que si sa
  signature Windows est valide **et** l'organisation du certificat est exactement celle attendue (`Test-ToolSignature`).
- Une annulation de l'historique ne s'exécute que si elle est sur la liste blanche **et** porte un sceau noté par AEROX (`Test-UndoAuthorized`).
- « Lancer avec Windows » (tâche planifiée aux droits les plus élevés) n'est créé que pour un programme dans un dossier que seuls
  SYSTEM, les administrateurs et TrustedInstaller peuvent modifier (`Test-AdminOnlyPath`) ; la tâche existante est revérifiée à chaque démarrage.
- Le logiciel n'ouvre aucun port et ne reçoit aucun ordre : le relais reçoit des rapports, des avis et des compteurs, il n'envoie jamais de commande.
- Le relais traite tout ce qu'il reçoit comme du texte non fiable (nettoyage avant publication, plafonds, aucune adresse IP gardée en clair).
- La mise à jour exige l'empreinte SHA-256 de la Release. Le compte GitHub est donc la clé de tout : double authentification ou clé
  d'accès (passkey), protection de la branche `main`, publications immuables.

## 1. Les rapports de bug

Chaque PC garde un journal des bugs dans `bugs.jsonl`, dans le dossier de données d'AEROX
(`C:\Program Files\AeroxPCCare\protege\donnees\<compte Windows>`, ou `donnees\<nom du PC>` sur la clé en version portable) :
- `bug` : une vraie erreur du logiciel (exception imprévue), à corriger dans le code ;
- `erreur` : un problème du PC rencontré pendant une action (ex. : Edge ouvert, MAJ Windows en échec).

Quand l'utilisateur clique sur « Signaler un bug », le rapport regroupe :
- la version d'AEROX PC Care et de Windows, la langue ;
- le résultat du dernier diagnostic ;
- la description de l'utilisateur ;
- les bugs et erreurs enregistrés depuis son dernier rapport ;
- les 60 dernières lignes du journal.

Le nom d'utilisateur, le nom du PC et les adresses e-mail sont remplacés par `<utilisateur>` / `<email>`.

**Avec le relais** (`relais.txt`), « Envoyer le rapport » publie le rapport directement dans les Issues (étiquette `bug`), sans compte GitHub,
et une copie arrive dans le salon Discord des rapports. Sans relais, « Envoyer sur GitHub » ouvre une issue préremplie (compte GitHub gratuit
requis) et « Copier le rapport » permet de l'envoyer sur Discord. Le relais n'a que le droit de créer et modifier des Issues de ce dépôt ; il nettoie
le texte reçu (aucune mention `@`, aucun lien ou image cliquable) et limite les envois par adresse et au total (`docs/RELAIS-RAPPORTS.md`).

### Faire le point de temps en temps

Sur GitHub : onglet **Issues**, filtre `label:bug`. Pour chaque rapport :
1. regarde les lignes `[bug]` : elles donnent la fonction et la ligne du script qui a planté ;
2. corrige, puis ferme l'issue en citant la version qui corrige (« Corrigé dans 1.1.1 »).

Les statistiques anonymes (versions utilisées, types de problèmes) se lisent avec la tâche **Statistiques** (onglet Actions) : elle affiche aussi
les plafonds du jour du relais. Une nouvelle famille de compteurs dans le logiciel s'ajoute dans `$script:StatsPrefixes` (`src/2_lib.ps1`) **et**
dans `STATS_FROM_APP` (`relais/worker.js`, puis redéploiement du relais) : le test du relais compare les deux listes.

## 2. La mise à jour automatique

Au démarrage, le logiciel lit la dernière Release du dépôt. Si elle est plus récente, il propose
« Mettre à jour » : il télécharge `AeroxPCCare_Setup.exe` de la Release, vérifie son empreinte SHA-256
(fournie par GitHub), se ferme et lance l'installateur en mode `/UPDATE` (pas de questions, barre de
progression, puis relance du logiciel). C'est le même installateur que pour une première installation :
pas de copie de programmes « à la main », ce que les antivirus prennent pour un comportement suspect.

## Structure du script

- En haut : réglages (`$AppVersion`, `$GitHubRepo`).
- `$TaskLibrary` : tout ce qui touche au PC (diagnostic, nettoyage, réparations).
  Ces fonctions tournent en arrière-plan pour que la fenêtre ne fige jamais.
  - `Add-Issue` : ajoute un problème au diagnostic (cause, conséquence, réparation, étapes).
  - `Add-TaskError` : signale une erreur pendant une action (affichée dans la fenêtre d'erreur).
  - `Write-Bug` : écrit dans le journal des bugs.
- Le reste : l'interface (pages, cartes, fenêtres).

Ajouter une vérification au diagnostic : écris une fonction `Test-Truc` qui appelle `Add-Issue`
ou `Add-Ok`, puis ajoute-la dans la liste `$checks` de `Invoke-Diagnostic`.

## Composants tiers (téléchargés à la demande, jamais inclus dans le zip)

| Composant | Rôle | Source | Licence |
|---|---|---|---|
| LibreHardwareMonitorLib 0.9.6 (+ dépendances NuGet) | Températures, consommation, fréquences | nuget.org | MPL-2.0 |
| PawnIO | Pilote signé pour lire la température du processeur | winget `namazso.PawnIO` ou GitHub namazso/PawnIO.Setup | voir le projet |
| PresentMon (console) | Compteur de FPS (traces ETW de Windows, aucune injection) | winget `Intel.PresentMon.Console` (GitHub GameTechDev/PresentMon) ; copie rangée dans le dossier protégé seulement si signée « Intel Corporation » (vérifiée à chaque lancement) | MIT |

Ils sont rangés dans `C:\Program Files\AeroxPCCare\protege\outils` (dossier protégé : seuls les administrateurs
peuvent y écrire), même en version portable. Si tu publies le logiciel, cite ces projets et leurs licences dans la page GitHub.

## Réglages mémorisés

`reglages.json`, dans le dossier de données (voir plus haut) : journal ouvert/fermé, logiciels ignorés, position,
taille, transparence et infos de l'overlay, seuils d'alerte surchauffe, programmes au démarrage validés.
Il est écrit « tout ou rien » (`Write-FileAtomic` : fichier `.tmp` puis échange, l'ancien devient `reglages.json.bak`) ;
`Read-SettingsFile` relit le `.bak` si le fichier principal est abîmé.
