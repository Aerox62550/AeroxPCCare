<p align="center"><img src="launcher/aerox.png" width="96" alt=""></p>

<h1 align="center">AEROX PC Care</h1>

<p align="center">Diagnostic, nettoyage, mises à jour, réparation et optimisation de Windows 10 / 11.<br>
Pensé pour tout le monde : chaque problème est expliqué simplement, avec sa cause et un bouton pour le régler.</p>

<p align="center"><a href="https://github.com/Aerox62550/AeroxPCCare/releases/latest/download/AeroxPCCare_Setup.exe"><b>⬇ Télécharger AEROX PC Care (installateur Windows)</b></a></p>

<p align="center"><a href="https://github.com/Aerox62550/AeroxPCCare/issues?q=label%3Aavis+is%3Aopen"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Faerox-relais.sam-heitz.workers.dev%2Fnote" alt="Avis des utilisateurs"></a>
&nbsp;<a href="https://github.com/Aerox62550/AeroxPCCare/issues?q=label%3Aavis+is%3Aopen">Lire les avis</a></p>

---

## Ce qu'il fait

- **Diagnostic complet** : stockage, mémoire, stabilité (écrans bleus, plantages), mises à jour, pilotes,
  sécurité, réseau, démarrage, santé des disques, températures. Chaque problème affiche sa cause, sa
  conséquence et la réparation (automatique quand c'est possible).
- **Libérer de la place** : une seule liste de tout ce qui peut partir (fichiers inutiles, place gardée par Windows,
  vieux installateurs, jeux et logiciels pas utilisés depuis 3 mois), ce qui est sans risque déjà coché, un seul bouton.
- **Nettoyage approfondi** : fichiers temporaires, caches, anciennes mises à jour, Windows.old…
  avec la taille de chaque catégorie, et un arbre de ce qui prend de la place.
- **Mises à jour des logiciels** au choix, avec « Ignorer » pour ceux que tu ne veux pas mettre à jour.
- **Réparations** : connexion Internet, fichiers de Windows (DISM + SFC), disque, Windows Update bloqué.
- **Sécurité (anti-intrusion)** : analyse approfondie des traces de voleurs de mots de passe (antivirus saboté,
  lancements cachés, faux programmes de Windows, prise en main à distance, faux cheats téléchargés, mots de passe
  en clair), analyses complète et hors ligne de Windows Defender, et un guide « Mon compte a été piraté ».
- **Performances** : programmes au démarrage appli par appli, mode performances, effets visuels,
  logiciels inutiles à désinstaller (avec l'explication et le disque où ils se trouvent).
- **Gaming** : chaque jeu est reconnu tout seul et **chaque partie est notée** (FPS moyens, 1 % low,
  saccades, températures) avec un résumé à la fin et une **fiche par jeu** : évolution partie après partie,
  ce qui limite le jeu (processeur, carte graphique, limite de FPS) et quoi faire. Sans injection : aucun
  risque avec les anti-triche. Plus les mesures en direct, un **overlay** déplaçable et une **alerte surchauffe**.
- **Test de débit Internet** (ping, réception, envoi) avec l'explication du résultat.
- **Mon PC (BIOS)** : version et âge du BIOS, TPM, Secure Boot, UEFI, compatibilité Windows 11.
- **Aide à distance** avec Assistance rapide de Microsoft, et un rapport du PC à envoyer.
- **Écran bloqué à 60 Hz** : détecté et réglé à sa vraie fréquence (144, 165 Hz…), avec retour automatique.
- **Coupures de connexion** : carte réseau mise en veille, pilote Wi-Fi ancien, DNS lents, avec des corrections annulables.
- **Pilotes graphiques** : compare le pilote NVIDIA installé avec la dernière version officielle (âge du pilote pour AMD / Intel).
- **Historique des changements** : tout ce que le logiciel modifie est noté, avec un bouton « Annuler ».
- **Rapports de bug en un clic**, sans compte à créer.
- **Mise à jour automatique** du logiciel en un clic.

## Sécurité

- Ne touche jamais aux fichiers personnels (photos, documents, téléchargements, jeux).
- Uniquement des outils officiels de Windows. Pas de « nettoyeur de registre ».
- Point de restauration avant les réparations, confirmation avant les actions lourdes.
- Rien n'est envoyé sur Internet sans ton clic. Les rapports de bug ne contiennent ni ton nom,
  ni tes fichiers, ni tes mots de passe, et tu peux les relire avant de les envoyer.

## Installation

1. Télécharge **[AeroxPCCare_Setup.exe](https://github.com/Aerox62550/AeroxPCCare/releases/latest/download/AeroxPCCare_Setup.exe)**
   (ou dans la [dernière version](../../releases/latest), fichier `AeroxPCCare_Setup.exe`).
   ⚠️ Ne prends pas « Source code (zip) » : c'est le code du logiciel, pas le programme.
2. Lance-le. Si Windows affiche « Windows a protégé votre ordinateur » :
   **Informations complémentaires** > **Exécuter quand même** (le logiciel n'est pas encore signé).
3. Ouvre AEROX PC Care depuis le Bureau et clique sur **Lancer le diagnostic**.

**Version portable (clé USB)** : pour dépanner plusieurs PC sans rien installer, télécharge
**[AeroxPCCare_Portable.zip](https://github.com/Aerox62550/AeroxPCCare/releases/latest/download/AeroxPCCare_Portable.zip)**,
dézippe-le sur la clé et lance `AeroxPCCare.exe`. Réglages et historique restent sur la clé (un dossier par PC).

## Avis

Le logiciel est gratuit : la seule récompense, ce sont vos retours. Dans le logiciel : onglet **Aide** > **Donner mon avis**
(une note de 1 à 5 et un commentaire, sans compte, avec le pseudo de votre choix). Les avis sont publiés directement
et se lisent [ici](../../issues?q=label%3Aavis+is%3Aopen).

## Signaler un bug

Dans le logiciel : bouton **Signaler un bug**. Ou directement ici : [onglet Issues](../../issues/new/choose).

## Composants tiers

Téléchargés à la demande depuis leurs sources officielles, jamais inclus dans le logiciel :
[LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor) (MPL-2.0),
[PawnIO](https://github.com/namazso/PawnIO.Setup),
[PresentMon](https://github.com/GameTechDev/PresentMon) d'Intel (MIT).
Le test de débit utilise [Speedtest® CLI by Ookla](https://www.speedtest.net/apps/cli) (téléchargé à la demande, gratuit pour un usage personnel, [conditions](https://www.speedtest.net/about/eula)), et les serveurs publics de Cloudflare en secours.

## Développement

Voir [docs/DEVELOPPEUR.md](docs/DEVELOPPEUR.md).
