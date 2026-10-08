# AEROX PC Care : guide développeur

## Organisation du dépôt

| Dossier | Contenu |
|---|---|
| `src/` | Le logiciel (PowerShell + WPF), en 4 parties assemblées à la construction : réglages, chargement de la DLL, fonctions qui touchent au PC (`$TaskLibrary`), interface. |
| `native/` | `AeroxPCCare.Native.dll` : tailles de dossiers, overlay, raccourci clavier, FPS, capteurs, NuGet, mise à jour, test de débit. |
| `launcher/` | `AEROX PC Care.exe` : demande les droits admin et exécute le script ; modes `--capteurs` (températures dans un processus séparé) et `--maj` (remplacement des fichiers lors d'une mise à jour). |
| `installer/` | Script NSIS de l'installateur. |
| `docs/` | Mode d'emploi (copié dans le logiciel) et ce guide. |
| `build.sh` | Construit le zip et l'installateur dans `build/`. |

Construire en local (Linux / WSL) : `sudo apt install mono-devel nsis zip python3` puis `./build.sh`.

## Publier une nouvelle version (automatique)

1. Corrige / ajoute ce qu'il faut, puis augmente `$AppVersion` dans `src/1_head.ps1` (ex. `1.0.0` → `1.0.1`).
2. Pousse sur la branche `main`.
3. GitHub Actions (« Publier une version ») voit le nouveau numéro, construit le logiciel et crée la
   **Release** `v1.0.1` avec :
   - `AeroxPCCare_v1.0.1.zip` : utilisé par la mise à jour automatique ;
   - `AeroxPCCare_Setup.exe` : l'installateur pour les nouveaux utilisateurs (lien direct stable :
     `https://github.com/Aerox62550/AeroxPCCare/releases/latest/download/AeroxPCCare_Setup.exe`).
4. Au prochain démarrage, chaque PC voit « Nouvelle version disponible » > **Mettre à jour**.

Tant que `$AppVersion` ne change pas, les envois sur `main` ne publient rien.
Numérotation : `1.0.1` pour une correction, `1.1.0` pour une nouvelle fonction.

## 1. Les rapports de bug

Chaque PC garde un journal des bugs dans `%LOCALAPPDATA%\AeroxPCCare\bugs.jsonl` :
- `bug` : une vraie erreur du logiciel (exception imprévue), à corriger dans le code ;
- `erreur` : un problème du PC rencontré pendant une action (ex. : Edge ouvert, MAJ Windows en échec).

Quand l'utilisateur clique sur « Signaler un bug », le rapport regroupe :
- la version d'AEROX PC Care et de Windows, la langue ;
- le résultat du dernier diagnostic ;
- la description de l'utilisateur ;
- les bugs et erreurs enregistrés depuis son dernier rapport ;
- les 60 dernières lignes du journal.

Le nom d'utilisateur, le nom du PC et les adresses e-mail sont remplacés par `<utilisateur>` / `<email>`.

**Avec GitHub configuré**, le bouton « Envoyer sur GitHub » ouvre une issue préremplie dans ton dépôt
(étiquette `bug`). L'utilisateur doit avoir un compte GitHub gratuit pour valider.
**Sans compte**, il clique sur « Copier le rapport » et te l'envoie sur Discord.

### Faire le point de temps en temps

Sur GitHub : onglet **Issues**, filtre `label:bug`. Pour chaque rapport :
1. regarde les lignes `[bug]` : elles donnent la fonction et la ligne du script qui a planté ;
2. corrige, puis ferme l'issue en citant la version qui corrige (« Corrigé dans 1.1.1 »).

### Pourquoi pas d'envoi 100 % automatique ?

Pour créer une issue sans compte, il faudrait mettre un jeton GitHub dans le script.
Or le script est lisible par tout le monde : le jeton serait volé et utilisé pour spammer ton dépôt.
La bonne solution, si un jour tu veux l'automatique, c'est un petit relais gratuit
(par ex. un Cloudflare Worker) qui garde le jeton côté serveur. On pourra le faire ensemble.

## 2. La mise à jour automatique

Au démarrage, le logiciel lit la dernière Release du dépôt. Si elle est plus récente, il propose
« Mettre à jour » : il télécharge le zip, vérifie son empreinte SHA-256 (fournie par GitHub), se ferme,
remplace ses fichiers et redémarre. L'ancienne version est gardée dans
`%LOCALAPPDATA%\AeroxPCCare\maj\ancienne_version` et remise en place si la copie échoue.

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
| PresentMon (console) | Compteur de FPS (traces ETW de Windows, aucune injection) | GitHub GameTechDev/PresentMon, signature Intel vérifiée | MIT |

Ils sont rangés dans `%LOCALAPPDATA%\AeroxPCCare\outils`. Si tu publies le logiciel, cite ces projets
et leurs licences dans la page GitHub.

## Réglages mémorisés

`%LOCALAPPDATA%\AeroxPCCare\reglages.json` : journal ouvert/fermé, logiciels ignorés, position,
taille, transparence et infos de l'overlay, seuils d'alerte surchauffe, programmes au démarrage validés.
