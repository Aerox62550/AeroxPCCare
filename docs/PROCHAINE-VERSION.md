# Notes pour la prochaine version

Idées et demandes validées par Sam, à faire dans la prochaine mise à jour.

## Prêt sur la branche 2.4.3 : partager AEROX (objectif 30 testeurs avant la signature du 31 octobre)

- Carte « Partager AEROX à un ami » (onglet Aide) : copie un message tout prêt (ce que fait l'app + lien releases/latest + invitation Discord si connue) et l'affiche. Compteur anonyme « partage ».
- Fenêtre « Quoi de neuf » (affichée après chaque mise à jour) : encadré « Tu aimes AEROX ? partage-le à tes amis, et fais un retour sur le moindre souci » avec les boutons « Partager à un ami » et « Rejoindre le Discord » (demande de Sam).
- Suivi de l'objectif : compteur « actifs » des statistiques (PC distincts par mois).

## Publié en 2.4.2 : écrans noirs (carte graphique) et blocage par Windows 11

- Retour testeur : « son écran se met en veille rapidement et il revient à lui ». Le diagnostic (même alerte « tdr », pas de nouvelle catégorie) réunit maintenant toutes les traces d'un décrochage de la carte graphique sur 14 jours : événement Display 4101, erreurs des pilotes (nvlddmkm, amdkmdag/amdwddmg/atikmdag, igfx), rapports Windows Error Reporting « LiveKernelEvent » 141/117/1a1/1a8 et fichiers LiveKernelReports\WATCHDOG. Un même incident laisse plusieurs traces : regroupées à 2 minutes près (Merge-GpuResets). Chaque incident est écrit dans le journal avec ses sources.
- Comparaison avec la date d'installation du pilote graphique (Get-GpuDriverInstallDates) : « ça a commencé après le pilote du … » → installation propre puis version précédente ; « ça arrivait déjà avant et continue après » → pas la version du pilote : overclocking, température, câble / écran, alimentation. Conseils d'installation propre selon la marque (NVIDIA : Personnalisée > installation propre ; AMD : Réinitialisation d'usine ; Intel : Driver & Support Assistant). Température de la carte mentionnée si ≥ 83 °C. Grave à partir de 5 incidents. Un seul incident : noté comme normal.
- Démarrage : un module bloqué par le Contrôle intelligent des applications de Windows 11 (HRESULT 0x800711C7, « stratégie de contrôle d'application ») est expliqué tel quel (avant : « ton antivirus la bloque peut-être »). Solution de fond prévue le 31 octobre : signature numérique (SignPath Foundation gratuit pour l'open source, ou certificat payant).

## Publié en 2.4.1 : communauté Discord

- Bouton « Rejoindre la communauté Discord » (onglet Aide). Le lien vient du fichier discord.txt du dépôt (branche main), comme relais.txt : il se change sans nouvelle version. Seule une vraie invitation est acceptée (https://discord.gg/… ou https://discord.com/invite/…, rien d'autre). Sans fichier : « le lien arrive bientôt ».
- Relais : copie facultative des rapports de bug et des avis dans Discord (secrets Cloudflare DISCORD_BUGS et DISCORD_AVIS = adresses des webhooks, jamais dans le dépôt ni dans le logiciel). Embed avec titre, début du rapport et lien GitHub ; aucune mention possible (allowed_mentions vide) ; jamais bloquant (waitUntil, erreurs ignorées). Sans secret : rien ne change. Testé localement (GitHub et Discord simulés). **À faire par Sam : recopier relais/worker.js dans Cloudflare + créer les 2 webhooks et les 2 secrets.**

## Publié en 2.4.0 : AEROX comprend ce qui rame au lieu de dire « rien trouvé » + statistiques anonymes

Demande de Sam : l'app doit analyser elle-même et régler, pas dépendre des rapports (« imagine 10 000 personnes »). Cas d'origine : le PC du pote qui lague, Discord bugué, et AEROX qui ne trouvait rien.

- « Pourquoi mon PC rame ? » mesure beaucoup plus en 20 s : carte graphique (par programme, compteurs GPU Engine de Windows), processeur bridé par le PC (compteur « % Performance Limit » : chauffe, batterie, chargeur, mode silencieux), pilote qui monopolise le processeur (temps d'interruptions/DPC > 6 %), connexion (ping 1/s vers la box et vers Internet : moyenne, gigue, pertes), trafic réseau (téléchargement qui sature), place libre sur C:, mémoire virtuelle désactivée. Chaque piste a sa cause et son bouton (pilotes, place, mémoire virtuelle…).
- Section « Ce qui a été vérifié » avec les valeurs mesurées : plus jamais un simple « rien d'anormal » sans preuve.
- « Dis-moi ce qui rame » quand rien n'est trouvé (ou « Ce n'est pas ça ? ») : ça lague en ligne → analyse de la connexion 1 minute ; jeux qui saccadent → mesure lancée 1 minute plus tard, pendant le jeu (conseils adaptés : carte graphique ou processeur qui limite les FPS) ; lent à démarrer → programmes au démarrage ; un logiciel précis → dépannages ; tout est lent → diagnostic complet.
- Nouveau dépannage « Ça lague en ligne (jeu, Discord) » : 60 pings vers la box et vers Internet. Distingue le Wi-Fi / câble / CPL instable (entre le PC et la box), les pertes de paquets de la ligne (après la box), le ping élevé ou irrégulier, la connexion occupée par un téléchargement (programmes ouverts nommés : Steam, OneDrive…), le Wi-Fi faible ou en 2,4 GHz, un VPN par lequel passe la connexion, l'économie d'énergie de la carte réseau (bouton, confirmé et annulable). Un ping bloqué par le réseau n'est jamais compté comme des pertes (adresse abandonnée après 3 essais sans réponse, 1.1.1.1 → 8.8.8.8).
- Statistiques anonymes (désactivables, onglet Aide) : compteurs seulement (diag, probleme:<type>, lent:<piste>, lent:rien, lag:<piste>, symptome:<x>, inconnu:<mode>-<x>, echec:<type>, corrige:<type>, pascorrige:<type>, erreur:<vérification>), un envoi au plus toutes les 6 h, et une fois par mois « actifs » + version → nombre de PC actifs par mois. Aucun nom, nom de PC, fichier, chemin, identifiant ni adresse IP gardée. File d'attente dans le dossier protégé (300 max).
- Relais (relais/worker.js) : POST /stats (clés vérifiées, 60 max, 50 max par clé, une écriture KV par envoi, plafond 800 envois/jour pour rester dans l'offre gratuite KV), GET /stats (le logiciel vérifie que le relais sait recevoir ; sinon rien n'est envoyé et les compteurs attendent), GET /stats?voir=1 (compteurs des 3 derniers mois, triés). **À faire par Sam : recopier relais/worker.js dans le Worker Cloudflare, avec l'espace KV lié sous le nom LIMITES.** Testé localement avec un faux KV.
- Test Windows : faux relais local (HttpListener) pour vérifier tout l'envoi sans toucher au vrai relais ; la machine de test a les statistiques désactivées.

## Publié en 2.3.0 : grande mise à jour de correctifs (contrôle complet + rapports n° 18 et 19 + relecture Gemini n° 4)

- Données d'AEROX (journal, réglages, historique, bilans, fiches de jeux, rapports) : Program Files\AeroxPCCare\protege\donnees\<SID du compte> au lieu de %LOCALAPPDATA%\AeroxPCCare. Avant : dossier modifiable par n'importe quel programme du compte, alors qu'AEROX y écrit en administrateur (lien glissé → écriture admin détournée vers un fichier de Windows). Reprise unique au 1er lancement (fichiers ordinaires, aucun lien suivi, pas outils/maj, marque .reprise) ; l'ancien dossier reste. Lanceur : plantage.txt / erreurs_lanceur.txt au même endroit quand il est administrateur. Désinstallation : outils/maj/session supprimés, données gardées sauf si la personne choisit de les supprimer. Test Windows : reprise d'un vrai fichier, lien-piège (jonction vers System32) non suivi.
- Rapport de batterie : écrit dans le dossier protégé (avant : nom fixe dans ProgramData, piégeable) et ouvert par l'Explorateur dans la session (Open-LocalFile, seulement des fichiers du dossier protégé). Le bouton ne faisait plus rien depuis la 2.1.3 (lien file: refusé par Open-Url). XML temporaire de la batterie : dossier protégé, nom aléatoire (avant : %TEMP% avec nom prévisible).
- Boutons « Ouvrir Steam » (analyse d'espace) : steam:// autorisé dans Open-WinUri (ouvert par l'Explorateur, sans droits admin). Ne faisaient plus rien depuis la 2.1.3.
- « Réparer les fichiers Windows » : résultat de SFC lu dans CBS.log (lignes [SR] depuis le début du scan : Cannot repair / Repairing N>0 components ou Repairing corrupted file / Verify complete), identique dans toutes les langues ; texte FR/EN en secours ; sinon message neutre au lieu de « aucun fichier abîmé ».
- Mise à jour d'AEROX : refusée si GitHub ne donne pas l'empreinte SHA-256 (avant : installée sans vérification).
- Rapports n° 18 / 19 (fichier hosts « accès refusé » même en administrateur) : Write-HostsFile enlève la lecture seule (souvent mise par le logiciel qui a détourné le fichier), sinon reprend la propriété et remet les droits par défaut (takeown /a + icacls /reset) ; si c'est encore refusé : message qui nomme l'antivirus (SecurityCenter2) et dit quoi faire. Annulation (Restore-HostsBackup) par le même chemin. Test Windows : hosts en lecture seule réparé.
- Rapport n° 18 (« problème de pilote alors que la mise à jour est bonne ») : le périphérique est nommé (titre, cause : « Ce n'est pas la carte graphique : c'est … »), avec son type, la raison selon le code d'erreur et l'étape adaptée ; une ligne par périphérique dans le journal (avec identifiant matériel) ; « Réinstaller ce périphérique » (pnputil /remove-device puis /scan-devices) pour les codes 3/10/31/39/43, jamais disques, contrôleurs, processeur, carte mère ou affichage.
- Démarrage lent : composants de Windows (mises à jour qui finissent au démarrage, recherche, services) retirés de la liste des coupables (rien à décocher).
- DNS qui bloque : site considéré bloqué seulement sans adresse IPv4 NI IPv6 (ou adresse locale) — les connexions IPv6 ne donnent plus de faux « bloqué ».
- Gaming : état des outils gardé une minute (à-coups au rafraîchissement). Accueil : autres disques lus en arrière-plan (un disque USB en veille figeait la fenêtre), tuile mise à jour quand ils répondent.
- BIOS : plus de recherche vide quand Windows ne connaît ni la marque ni le modèle (explication à la place). Bug trouvé par le test Windows : Get-SystemInfo ne renvoie rien (il remplit $sync.SysInfo), donc si les infos du PC n'étaient pas encore chargées, la recherche partait sans la marque ni le modèle ; corrigé.
- Test de débit : le speedtest.exe d'Ookla n'est pas signé (vérifié sur le zip officiel 1.2.0) ; il n'est lancé en administrateur que si son empreinte SHA-256 est celle du programme officiel (ou s'il est signé par Ookla un jour). Sinon il est supprimé et le test passe par Cloudflare. Paramètre $Profile (variable réservée de PowerShell) renommé.

### Relecture Gemini n° 4 (partie 1, vérifiée point par point) — inclus dans la 2.3.0

- Raccourcis temporaires (.lnk / .url ouverts dans la session de la personne) : dossier protégé (Program Files\AeroxPCCare\protege\session) au lieu de ProgramData\AeroxPCCare, qu'un autre compte pouvait créer avant AEROX et dont il pouvait remplacer le raccourci (lancement sur le compte de la personne, droits limités : pas d'élévation admin, mais un autre compte pouvait faire lancer un programme chez elle). Vrai.
- Désinstallation : entrée HKLM dont le désinstalleur est hors de Windows / Program Files (D:\Jeux, dossier perso…) → lancé sur le compte de la personne, sans les droits admin d'AEROX (il demande l'UAC lui-même si besoin). Avant : lancé en admin alors qu'un compte standard pouvait remplacer le fichier. Vrai, important.
- Test de débit (AeroxSpeed.RunOokla) : garde-fou (aucune ligne pendant 20 s ou plus de 90 s) → speedtest.exe arrêté, passage sur Cloudflare. Avant : seul « Annuler » débloquait. Vrai.
- Complete-Job : la fenêtre de résultat (mises à jour, nettoyage, espace…) s'ouvre aussi quand l'analyse a noté une erreur mineure (affichée avant). Vrai.
- Identifiants winget coupés (« … ») : jamais retenus comme « se met à jour tout seul » ni comme échec d'installateur. Précaution (les rapports montrent des identifiants complets).
- Écran de démarrage du lanceur : icône libérée après usage. Mineur.

## Publié en 2.2.0 : diagnostic approfondi (Sam : « qu'elle comprenne et propose les solutions, comme pour les écrans bleus »)

- Démarrage lent (Test-BootSpeed, catégorie Démarrage) : journal Diagnostics-Performance de Windows, événements 101 logiciel / 102 pilote / 103 service / 106 tâche de fond / 109 périphérique sur 30 jours ; gardé si ça revient (≥ 2 fois) avec ≥ 3 s de retard moyen ; signalé si le dernier démarrage dépasse 45 s. Nom, type, retard moyen, nombre de fois ; conseils selon le type ; temps du dernier démarrage dans le journal.
- Extinctions brutales (power41) : champs de l'événement 41 lus : bouton maintenu (PowerButtonTimestamp) = le PC était figé ; pendant une veille (SleepInProgress) ; coupure nette = courant / alimentation / surchauffe. Cause et étapes selon le cas.
- Pilote graphique qui décroche (Display 4101, ≥ 2 en 7 jours) → « Vérifier les pilotes », installation propre, overclocking, températures, alimentation.
- Test de mémoire de Windows (MemoryDiagnostics-Results 1202 sur 90 jours) → critique ; 1201 → point OK.
- Logiciels qui se figent (Application 1002, ≥ 3 en 7 jours) → composant de Windows : réparer les fichiers ; logiciel : mises à jour ; conseil d'analyse « PC lent » au moment du figement.
- Disques (Test-DiskHealth) : erreurs de lecture disk 7 / 51 → critique avec le nom du disque (Harddisk N → disque physique) ; disk 153 ≥ 5 → câble / firmware ; Ntfs 55 / 98 → vérification du disque. Une requête par source d'événements.
- Après réparation (tdr, hang, diskbad, diskretry, ntfs) : seules les nouvelles erreurs comptent (comme crash / bsod / power41).
- Rapport n° 17 (VS Code (User) « mis à jour » puis encore proposé, à chaque fois) : winget annonce la 1.142.0 et installe en réalité l'installateur 1.141.2. Après les mises à jour, la liste est relue : si un logiciel réussi annonce encore la même version, il est rangé avec ceux qui se mettent à jour tout seuls (plus proposé pour cette version) et c'est expliqué.
- Rapport n° 17 (« Le PC s'est éteint brutalement 2 fois » marqué « c'est fait » puis toujours affiché) : « c'est fait » sur un problème lu dans l'historique (crash, bsod, power41, tdr, hang, disques) retient la date ; seuls les nouveaux comptent ensuite.
- Retour testeur (« son PC lag, AEROX ne trouve rien, Discord bugue, impossible de retélécharger Discord ») : nouveau Test-NetBlockers (catégorie Réseau) : proxy de la session (ProxyEnable/ProxyServer/AutoConfigURL) → « Désactiver le proxy » (annulable, Set-UserProxy) ; fichier hosts qui détourne des sites importants (Discord, Microsoft, Google, Steam, Epic, Riot, antivirus… ; télémétrie et pubs ignorées) → « Débloquer ces sites » (copie dans le dossier protégé, lignes retirées, annulable, Restore-HostsBackup vérifie l'origine) ; heure du PC fausse ≥ 5 min (en-tête Date d'un serveur Microsoft, d'abord en HTTP) → « Remettre à l'heure » (W32Time automatique + resync) ; DNS qui bloque discord.com / dl.discordapp.net / download.microsoft.com / store.steampowered.com (pas de réponse ou adresse locale) → conseils box / DNS public.
- Nouveau dépannage « Discord bugue ou ne s'installe plus » (Repair-Discord) : ferme Discord, vide ses caches (stable/PTB/Canary, connexion gardée), repère une installation abîmée (%LocalAppData%\Discord sans Update.exe → ancien dossier à la corbeille sur confirmation), vérifie que le téléchargement de Discord passe et dit pourquoi sinon (Test-SiteReachable : DNS/hosts, heure/antivirus, proxy, pare-feu, délai).
- Carte « Pas de son » : texte corrigé (le son n'est relancé que s'il est arrêté, depuis la 2.1.8).
- Avis et rapports de bug : gros mots masqués (1re lettre + étoiles) avant envoi : commentaire, pseudo, titre et description du rapport (Hide-Profanity). Demande de Sam après l'avis n° 14 (corrigé à la main sur GitHub).

## Publié en 2.1.9 : rapports n° 15 et 16, BIOS

- Écrans bleus (rapport n° 15 : 6 écrans bleus, seul le code était donné ; Sam : « le but c'est qu'on détecte les soucis et qu'on règle ») : AeroxDump.Analyze lit chaque petit rapport de plantage (C:\Windows\Minidump, format « PAGEDU64 » triage) : code, paramètres, liste des pilotes chargés (validée en entier : noms, adresses noyau, tailles ; sinon rien n'est désigné) et pilotes trouvés sur la pile ou visés par les paramètres. Coupable = premier pilote qui n'est pas de Microsoft (éditeur lu dans le fichier du pilote), sinon premier pilote Microsoft hors noyau, sinon « seulement Windows » (→ RAM / XMP / fichiers de Windows). Classé gpu / réseau / anti-triche / antivirus / stockage / USB / audio / autre, avec réparation adaptée (pilotes, logiciels, fichiers de Windows). Une ligne par écran bleu dans le journal (donc dans les rapports). En plus : erreurs matérielles WHEA et mémoire en XMP/EXPO (DDR4 > 3200, DDR5 > 6400). Test Windows sur un faux rapport de même structure ; à confirmer sur un vrai rapport de testeur.
- BIOS (retour Sam : « Mettre à jour » ouvrait une recherche, pas la page du BIOS) : Find-BiosPage (tâche de fond) essaie l'adresse exacte du modèle (ASUS supportonly/…/helpdesk_bios, MSI Motherboard|Laptop/…/support#bios, Gigabyte Motherboard/…(-rev-xx)/support, ASRock mb/AMD|Intel/…, Dell servicetag/<n° de série>/drivers, Lenovo products/<n° de série>/downloads) ; chaque adresse devinée est vérifiée (page 200, pas de 404, le modèle est dans la page) avant d'être ouverte, sinon la recherche du site du fabricant, sinon la recherche limitée à son site (comme avant). N° de série lu seulement pour ça, jamais dans les rapports. Test Windows : sondes sur des cartes connues pour voir quelles adresses passent.
- Rapport n° 15 (carte réseau « réglée » puis « toujours là ») : MSPower_DeviceEnable accepté par le pilote sans être appliqué. Relu aussitôt ; si toujours actif, réglage du pilote (PnPCapabilities 24) en plus, effectif au redémarrage, et dit clairement.
- Rapport n° 16 (Corsair iCUE : installateur en échec 0x8A150006, code 0xC000041D, à chaque optimisation) : 1er échec = explication (« son propre installateur a échoué : réessaie plus tard ou mets-le à jour depuis le logiciel ») ; 2e échec pour la même version = rangé avec les logiciels qui se mettent à jour tout seuls (plus proposé pour cette version).

## Publié en 2.1.8 : bilan avant / après sur tous les disques (retour testeur)

- Son (rapport n° 12 + retour Sam : « plus entendu sur Discord » juste après « Pas de son ») : PAS une coïncidence. Repair-Sound relançait toujours le service Audiosrv, ce qui coupe le son de tout le PC et fait perdre micro/casque à Discord. Maintenant : relancé seulement s'il est arrêté. Test Windows : le processus du service ne doit pas changer.
- Son et micro : appareil utilisé par Windows nommé (« Le son sort sur… », « Micro utilisé… », via AeroxAudio.DefaultId + InstanceId PnP), et conseil Discord précis : SteelSeries Sonar présent → Entrée « SteelSeries Sonar - Microphone », Sortie « SteelSeries Sonar - Chat » (recommandation SteelSeries) ; sinon les appareils « communications » de Windows.
- Extensions (« Gérer » ouvrait juste Chrome) : page de l'extension elle-même (chrome://extensions/?id=…, id vérifié), avec --profile-directory du bon profil ; adresse copiée dans le presse-papiers + consigne Ctrl+V si le navigateur refuse.
- Pilote graphique (« installé le 30 septembre » alors qu'installé le 16 octobre) : la date de Windows est celle du fabricant. Vraie date d'installation : journal Kernel-PnP/Configuration (événement 400 avec la carte et la version actuelle), sinon création de C:\Windows\INF\oemNN.inf. Affichage : « Version installée : X, installée le …, pilote daté du … par le fabricant ».
- Plantages (rapport n° 13 : « dwm.exe a planté 6 fois », réparation « Mettre à jour mes logiciels », vérification toujours en échec) : la vérification juste après relisait l'historique des 7 jours, forcément pareil. Maintenant : heure de la réparation retenue (crash, bsod, power41), seuls les plantages d'après comptent ; plantages liés à la carte graphique / dwm.exe : seuls ceux d'après l'installation du pilote actuel comptent ; dwm.exe et modules graphiques → « Vérifier les pilotes » ; autres composants de Windows → « Réparer les fichiers Windows » ; logiciels → mises à jour comme avant.
- Désinstallation (rapport n° 13 : The Elder Scrolls Online, « fichier spécifié introuvable ») : variables %…% remplacées, et désinstalleur absent → message clair (lanceur Steam/Epic/Bethesda…, ou Paramètres > Applications), pas compté comme bug.
- Photo du PC (Get-PcSnapshot) : place libre de chaque autre disque (Drives = { 'D:' = octets libres }). Bilan : une ligne « Espace libre sur D: » par disque présent avant ET maintenant. Les bilans commencés avant la 2.1.8 n'ont pas ces valeurs : les lignes apparaissent au bilan suivant (« Repartir de zéro » pour l'avoir tout de suite).

## Publié en 2.1.7 : espace disque (retour testeur, capture de l'analyse de D:)

- Constat : sur D:, « Tes plus gros fichiers » listait des fichiers de jeux (Epic .egstore, GTA V mods, Electrician Simulator) sans case à cocher : seuls les fichiers de C:\Users\… étaient supprimables. Voulu pour les fichiers de jeux (supprimés seuls, le jeu casse et le lanceur les retélécharge), mais mal expliqué, et les vrais fichiers perso de D: n'étaient pas supprimables non plus.
- Classement de chaque gros fichier (Get-BigFileKind) : dans le profil (hors AppData) ou dans un dossier perso (Téléchargements, Vidéos, Films, Images, Musique, Documents, Bureau, Sauvegardes…) = à toi ; dossier parent avec un .exe, un .egstore (Epic) ou steamapps = morceau de jeu/logiciel (remonte au dossier du jeu lui-même) ; AppData = jamais proposé.
- Fichiers à toi, sur tous les disques fixes : case à cocher + bouton « Corbeille » par ligne (confirmation, récupérable, la fenêtre reste ouverte, ligne grisée « À la corbeille ✓ »).
- Fichiers de jeux : nouvelle carte « Les jeux et logiciels qui prennent le plus de place » (nom + taille du dossier), explication, bouton « Voir les logiciels ».
- Analyse d'un autre disque que C: : bouton « Nettoyage approfondi » et carte « Fichiers inutiles de Windows » masqués (le nettoyage approfondi ne travaille que sur le disque de Windows).
- Retour testeur (capture) : « Mettre la sélection à la corbeille » sans case cochée fermait la fenêtre puis disait de cocher. Maintenant tout se fait dans la fenêtre : message si rien n'est coché (elle reste ouverte), sinon mise à la corbeille et lignes grisées.
- Choix du disque (capture : lettre, nom et place libre collés au milieu) : le modèle des boutons ActionBtn respecte HorizontalContentAlignment (Center par défaut, rien ne change ailleurs) ; nom à gauche, place libre à droite avec un espace.

## Publié en 2.1.6 : rapport n° 10 (disques, corbeille)

- Rapport n° 10 (« pas de diagnostic sur les autres disques que C ») : le diagnostic détaille maintenant chaque disque dans le journal (et donc dans les rapports de bug) : place libre de chaque lettre (internes, externes, amovibles) et santé de chaque disque physique avec ses lettres (« Samsung SSD 980 (C:, D:) : SSD, état Healthy »). Lettre sans disque physique lisible (clé USB, boîtier) : « santé non lisible par Windows ».
- Même rapport, autre bug vu dans le journal : analyse « Corbeille : 1,29 Go » puis « Corbeille vidée : 0 Ko ». L'analyse comptait les corbeilles de TOUS les comptes (dont d'anciens comptes ou une ancienne installation de Windows), le vidage ne touche que celle de la personne. Maintenant : taille annoncée = corbeille de la personne (sur tous les disques, amovibles compris), les autres comptes sont indiqués à part et jamais touchés ; vidage disque par disque, puis, si Windows n'a pas tout vidé, dossier de corbeille de la personne vidé par la suppression sûre ; reste éventuel signalé.

## Publié en 2.1.5 : overlay (retour testeur sur la 2.1.4)

- Cause trouvée (et confirmée par le test Windows) : en PowerShell, [math]::Min(1, 0.49) choisit la version « nombres entiers » et arrondit 0,49 à 0 (et 0,51 à 1). Le fond de l'overlay ne pouvait donc être que transparent (< 50 %) ou noir (≥ 50 %), et la taille était arrondie à 100 %, 200 % ou 300 %. Corrigé partout : premier nombre écrit en décimal ([double]) dans tous les Max/Min.
- Même cause, autre bug évité : [math]::Max(0, place libérée) plantait au-delà de 2 Go (OneDrive « en ligne seulement », mesure d'espace libéré).
- Overlay : taille minimum 70 % (en dessous, texte de 6 px forcément flou) ; ombre du texte plus fine sous 100 %.
- Test Windows : fond à 49 % et 51 % presque identiques, taille 250 % vraiment appliquée ; élément de démarrage de test : clé Run créée si absente.

## Publié en 2.1.4 : retours de testeurs (démarrage, mises à jour)

- Démarrage (retour d'un testeur : 3 applis décochées, toujours 9 au test suivant et encore cochées en revenant) : chaque désactivation est relue aussitôt (erreur claire + détails dans le rapport de bug si Windows ne l'a pas gardée). Identifiant stable « u|run|nom » / « m|run32|nom » : la fenêtre et la tâche de fond désignent toujours le même élément, quelle que soit l'écriture de la clé de la session (HKCU: ou HKEY_USERS\SID) ; anciens identifiants de l'historique acceptés. Élément demandé mais introuvable : noté dans le journal et le rapport.
- Démarrage : ce qu'AEROX a désactivé est retenu. Une appli de nouveau active (souvent l'appli elle-même qui se remet au démarrage à son lancement : Discord, Spotify…) est signalée par le diagnostic (« N appli(s) que tu avais décochée(s) se lancent de nouveau au démarrage ») et marquée « De nouveau actif » dans la fenêtre, avec la marche à suivre (désactiver son option « Lancer au démarrage » dans ses réglages). La laisser cochée = gardée, plus signalée. Plus comptée dans « programmes au démarrage à vérifier ».
- Mises à jour (rapport #9 : Edge et Epic Online Services en échec 0x8A15008E à chaque fois, Hytale « aucune mise à jour applicable ») : ces deux réponses de winget ne sont plus des erreurs. Le logiciel est retenu pour cette version (fichier dans le dossier protégé) : plus proposé ni compté par le diagnostic, affiché décoché avec l'explication dans « Choisir les mises à jour », de nouveau proposé dès qu'une autre version sort.

- Suggestion d'un testeur : les composants de mesure se désinstallent au choix (Gaming > En direct > « Désinstaller » à côté de « Installé ») : module de températures (dossier protégé + ancien emplacement, sinon il serait réinstallé tout seul), compteur de FPS (winget + copie du dossier protégé), pilote PawnIO (winget ; sinon marche à suivre Paramètres > Applications). Confirmation avec ce qu'on perd ; mesures arrêtées avant (fichiers libérés) puis relancées sans lui ; refusé pendant une partie suivie ; noté dans l'historique.
- Overlay (retour testeur : pas de transition du fond, flou à certaines tailles) : le curseur « Fond » change seulement la couleur du fond, tout de suite (plus de reconstruction de l'overlay ni d'enregistrement des réglages à chaque cran, qui saccadait) ; réglages enregistrés 0,7 s après le dernier mouvement (et à la fermeture). Valeur en % affichée à côté de « Taille » et « Fond ». Taille : plus d'agrandissement après coup (ScaleTransform), le texte est dessiné à sa vraie taille en pixels entiers, arrondi de mise en page, rendu « Display » jusqu'à 130 %.
- État du PC (retour testeur : seulement C: affiché) : tuile « Disques » de l'accueil avec C: puis les autres disques (internes, externes USB, amovibles), jusqu'à 4. Diagnostic : une ligne OK par disque (nom, amovible), alerte « plein » sous 5 % pour les disques non amovibles. Santé des disques : déjà tous les disques physiques.

## Publié en 2.1.3 : grand ménage sécurité et fiabilité (3e relecture Gemini + passage au crible complet)

- Dossier protégé Program Files\AeroxPCCare\protege (modifiable seulement en administrateur) : outils lancés avec les droits admin (module de températures, test de débit, copie de PresentMon), sauvegardes .reg des navigateurs, installateurs de mise à jour, sceaux des annulations. Avant : dossier perso (n'importe quel programme pouvait remplacer un outil et se faire lancer en administrateur). Ancien module de températures réinstallé tout seul dans le dossier protégé, ancien dossier vidé. Désinstallation : dossier protégé supprimé.
- PresentMon : seulement la copie du dossier protégé, copiée si signée par Intel (ou juste après son installation par AEROX). winget : la copie officielle de Program Files signée Microsoft d'abord, plus jamais trouvé par le PATH. nvidia-smi : emplacements officiels seulement.
- Au démarrage : modules PowerShell et PATH limités aux dossiers de Windows et de Program Files (plus de Documents ni de PATH de l'utilisateur) ; outils de Windows appelés par leur chemin System32.
- Liens, pages Windows et navigateurs ouverts par l'Explorateur (session normale, sans droits admin) : l'association d'un protocole ou le navigateur par défaut peuvent être changés sans droits admin. Pages internes du navigateur (chrome://…) ouvertes sans droits admin. Outils .msc / .cpl par leur chemin complet.
- Suppression sûre (AeroxSafeDelete) : chaque élément ouvert sans suivre les liens, vrai chemin vérifié (il doit rester dans le dossier nettoyé), supprimé par le même accès. Dossier à nettoyer qui est un lien ou qui passe par un lien : refusé. Utilisé par tout le nettoyage. Fichiers mis à la corbeille (doublons, gros fichiers) et réglages des navigateurs : refusés si un lien est sur le chemin. OneDrive « en ligne » : ne suit jamais une jonction, dossier OneDrive venant du registre vérifié (pas un dossier de Windows ni de programmes).
- Historique : chaque annulation est scellée (empreinte dans le dossier protégé) ; une annulation trafiquée dans l'historique (dossier perso) est refusée. Anciennes entrées sans sceau : seulement les réglages sans risque (pas les programmes en fond, le démarrage ni les sauvegardes du registre).
- Dossier perso d'AEROX : liens retirés au démarrage (sinon AEROX écrirait ailleurs). Rapport sur le Bureau : jamais dans un dossier de Windows ou de programmes.
- Mises à jour des logiciels (retour d'un pote de Sam : Antigravity en double, logiciels désinstallés réinstallés) : doublons retirés ; logiciel dont il ne reste qu'une trace dans Windows (désinstalleur et dossier disparus) repéré, pas mis à jour par « Tout mettre à jour », pas compté par le diagnostic, décoché avec explication dans la liste.
- Mémoire : les tâches en arrière-plan (vérifications, recherche de mise à jour, contexte des parties) sont libérées à la fin.
- Corbeille : place vraiment libérée (mesurée avant / après) ; avec le mot de passe d'un autre compte, la corbeille de la personne devant l'écran est vidée aussi.
- Gaming : saccades par heure calculées sur le temps vraiment joué ; fréquence de l'écran où tourne le jeu (pas toujours le principal), bouton « Passer à X Hz » sur le bon écran ; « Pourquoi mon PC rame » arrête d'abord les outils de mesure d'AEROX.
- Faux (vérifié) : courbe minute par minute (les pauses sont comptées exprès), conflit au réaffichage depuis la zone de notification.

## Publié en 2.1.2 : relectures externes (Gemini), points vérifiés et corrigés

- Désinstallation : logiciels et applis du Store de la personne devant l'écran (pas ceux du compte ADMIN) ; désinstalleur d'un logiciel « par utilisateur » lancé sur son compte ; « désinstallé » seulement quand l'entrée de Windows a disparu (vérifié toutes les 2 s, sinon « toujours installé » à la fermeture), problème du diagnostic réglé seulement dans ce cas.
- OneDrive « uniquement en ligne » : plus d'attrib -P récursif ; les éléments « Toujours conserver sur cet appareil » (Pinned) ne sont jamais touchés ; refusé si OneDrive n'est pas lancé.
- Nettoyage approfondi : « Annuler » arrête cleanmgr ; « terminé » seulement s'il a vraiment fini ; attente (5 min max) qu'aucun cleanmgr / DISM ne tourne avant cleanmgr et DISM, sinon étape passée avec un message.
- Compteur de FPS : ménage des programmes qui n'affichent plus rien (toutes les 5000 lignes). Le point « --v1_metrics refusé par PresentMon 2 » était faux (l'option existe en 2.x).
- Envoi rapport de bug / avis dans un fil séparé (la fenêtre ne fige plus jusqu'à 20 s) ; Assistance rapide (compte ADMIN) vérifiée sans figer la fenêtre.
- 2.1.2, 2e relecture Gemini (sécurité) :
  - Désinstalleur d'un logiciel « par utilisateur » (registre HKCU, modifiable par n'importe quel programme de la personne sans droits admin) : toujours lancé SANS les droits admin, sur le compte de la personne (sinon un programme malveillant pouvait se faire lancer en administrateur en se déguisant en logiciel à désinstaller).
  - Annulation « réglages imposés des navigateurs » : le fichier .reg de sauvegarde (dossier modifiable sans droits admin) est vérifié avant import : uniquement des clés SOFTWARE\Policies\Google\Chrome / Microsoft\Edge / BraveSoftware\Brave, sinon refusé.
  - Raccourcis temporaires dans ProgramData (Assistance rapide, liens) : nom imprévisible à chaque fois + ménage. (Pas d'élévation possible avant non plus : ils s'ouvrent sans droits admin.)
  - Fichier Preferences des navigateurs : écrit à côté puis remplacé d'un coup (déjà sauvegardé, vérifié et remis en cas de souci).
  - Faux : « Set-CpuMaxState ne gère pas le refus du fabricant » (le réglage est relu et un message clair s'affiche s'il n'a pas pris).
- Pas fait (gain faible) : statut des cartes Performances et infos de l'accueil calculés en arrière-plan.

## Publié en 2.1.2 : interface

- Icône pour chaque carte d'action (police d'icônes de Windows Segoe MDL2, rien à télécharger), carte qui s'éclaire au survol.
- Apparition douce des pages (fondu + léger glissement, 0,2 s).
- Petits textes gris plus clairs (#6B7389 → #7A8399, #5D6478 → #6E768B) pour la lisibilité.
- Accueil : carte « État de ton PC » en avant (dégradé violet, anneau plus grand, titre plus gros).
- Gaming : 3 sous-onglets « Mes jeux » (partie en cours, mes jeux, suivi automatique), « En direct » (mesures + composants), « Overlay en jeu ».
- Test automatique : captures d'écran de chaque page et fenêtre poussées sur la branche « captures » (pour vérifier le rendu réel à chaque version).

## Publié en 2.0.2 : mémoire en mode discret

- Demande de Sam : consommer le moins de RAM possible quand AEROX tourne caché, sans conséquence. Caché près de l'horloge : la page affichée est libérée (reconstruite à la réouverture, avant d'afficher la fenêtre), ramasse-miettes .NET, puis la mémoire inutilisée est rendue à Windows (SetProcessWorkingSetSize). Fait 2 s après la mise en veille, 45 s après une partie (mesures arrêtées), puis toutes les 15 min ; jamais pendant une partie ni pendant une opération. Résultats d'analyse, journal et réglages gardés.
- Test automatique : temps de démarrage et mémoire affichés à chaque version (fenêtre ouverte / cachée), page bien libérée puis reconstruite.

## Publié en 2.0.1

- Gaming, aucune affirmation sans preuve (demande de Sam : « fiable à 100 % ») : « processeur » seulement si un cœur est à ≥ 90 % avec la carte graphique < 75 %, ou le processeur à ≥ 80 % avec la carte graphique < 85 % ; pas de verdict si moins de 60 mesures avec le jeu au premier plan (« Pas de conclusion » plutôt qu'une conclusion fausse) ; la fiche affiche les mesures qui justifient le verdict (carte graphique %, processeur %, cœur le plus chargé %, FPS / Hz).
- Gaming, verdict plus juste (retour de Sam : Roblox sur Ryzen 7 7800X3D annoncé « limité par le processeur » avec la carte graphique à 30 %) : « processeur » seulement si un cœur est à ≥ 85 % ou le processeur à ≥ 80 % ; sinon, carte graphique < 70 % = « limité par le jeu lui-même » (moteur sur 1-2 cœurs, limite d'images). Limite de FPS reconnue aussi quand les FPS bougent un peu (carte graphique < 70 %). Nouveau conseil vert « déjà plus de FPS que ton écran n'en affiche ». Le verdict est recalculé à la lecture des fiches, donc les anciennes parties sont corrigées aussi.
- Gaming : Roblox (RobloxPlayerBeta dans AppData\Local\Roblox\Versions) reconnu par son dossier, donc aussi en fenêtre ; avant, seulement en plein écran via la détection générale.

## Publié en 2.0.0 : Gaming, carnet de performances par jeu (version 1)

- Onglet « Moniteur » renommé « Gaming ». En haut : partie en cours / dernière partie, « Mes jeux » (une ligne par jeu : FPS de la dernière partie, verdict, nombre de parties), « Suivi automatique », puis les mesures en direct, les composants et l'overlay comme avant.
- Détection automatique toutes les 3 s du programme au premier plan : jeux des boutiques reconnus par leur dossier (steamapps\common, Epic Games, Riot Games, _retail_ de Battle.net, EA, Ubisoft, GOG, XboxGames, Rockstar) ; autre programme en plein écran = jeu seulement s'il affiche au moins 20 images/s pendant quelques secondes (navigateurs, lecteurs vidéo, bureautique, Discord, OBS… exclus). Lanceurs, anti-triche, rapports de plantage jamais pris pour des jeux.
- Mesure de la partie : toutes les images du jeu via PresentMon (FPS moyen, 1 % low, 0,1 % low, saccades = image > 2,5× la moyenne récente et > +20 ms, FPS minute par minute) + une mesure par seconde des capteurs (températures max, utilisation moyenne CPU / GPU / cœur le plus chargé, VRAM et RAM max), seulement quand le jeu est au premier plan.
- Fin de partie (jeu fermé, au moins 3 minutes) : résumé d'une ligne dans le journal + notification Windows (clic = fiche du jeu). Fichier par jeu dans « jeux » (200 dernières parties), avec pilote graphique et fréquence de l'écran notés pour la version 2.
- Verdict : plafonné (FPS très stables sur une limite courante / V-Sync / Reflex), carte graphique (≥ 85 %), processeur (cœur max ≥ 85 % ou CPU ≥ 80 % ou GPU < 70 %), équilibré. Alertes : surchauffe (seuils de l'overlay), VRAM ≥ 95 %, RAM ≥ 90 %, saccades ≥ 30/h, écran sous sa fréquence max.
- Fiche du jeu : chiffres clés, courbe partie après partie (FPS + 1 % low), dernière partie minute par minute, « ce qui limite ce jeu et quoi faire » (boutons vers les fonctions existantes : pilotes, programmes en fond, « Pourquoi mon PC rame », Optimisations, fréquence de l'écran), meilleure / pire partie et pourquoi, 10 dernières parties, « Ce n'est pas un jeu », « Effacer l'historique ».
- Mode discret (options, désactivées par défaut) : la croix cache AEROX dans la zone de notification (clic droit > Quitter) ; lancement avec Windows par une tâche planifiée « AEROX PC Care (mode discret) » (droits admin sans demande, démarre 45 s après l'ouverture de session, caché). Pas en version portable ni avec le mot de passe d'un autre compte. Relancer AEROX (raccourci) réaffiche la fenêtre.
- Version 2 à faire : objectifs de FPS par jeu, tendances, alertes utiles (FPS en baisse depuis un pilote, GPU chaud toute la semaine, Discord gourmand), effet des changements entre deux parties, contrôles XMP/EXPO et carte graphique intégrée sur portable dans le diagnostic « Performances ».

## Publié en 1.9.0 : fiabilité

- Vérification après chaque réparation automatique : AEROX refait le contrôle de la catégorie en arrière-plan (« Vérification que c'est bien réglé… ») ; réglé → « ✅ Vérifié » ; toujours là → le problème reste ouvert avec un message « la réparation n'a pas suffi ». Pas de vérification quand un redémarrage est nécessaire, ni pour les choix faits par la personne (démarrage, logiciels…).
- Pilote graphique AMD/Intel : si sa version change entre deux diagnostics (mise à jour faite), plus d'alerte « pilote ancien » tant qu'elle ne change pas (carte ancienne dont le dernier pilote a plus d'un an : la boucle chez le frère de Sam).
- Pilotes Windows Update : un pilote déjà installé par AEROX et reproposé par Windows est signalé et décoché d'office (installer à nouveau ne change rien).
- Test automatique : un problème créé exprès (processeur bridé) doit être détecté, réparé, puis vérifié réglé.

## Publié en 1.8.0 : « Quoi de neuf »

- Après une mise à jour, au premier lancement : fenêtre « Quoi de neuf dans la X ? » avec les nouveautés depuis la version d'avant, en mots simples (rien au tout premier lancement). Revoir : onglet Aide > « Quoi de neuf ? ».
- À chaque nouvelle version : ajouter ses nouveautés en haut de $script:WhatsNew (src/3_ui.ps1).

## Publié en 1.7.2 : « Annuler » ne bloque plus jamais

- Nettoyage approfondi : « Annuler » marche maintenant (arrêt après l'étape en cours) ; le nettoyage de Windows (cleanmgr) s'arrête tout de suite si on annule, affiche son avancement chaque minute et ne peut pas durer plus de 10 minutes. Avant : il pouvait rester bloqué sans fin et « Annuler » était refusé (rapport n°7, PC du frère de Sam).
- Analyses (espace disque, diagnostic…) : si une étape de Windows ne rend pas la main 8 secondes après « Annuler », AEROX débloque l'écran tout de suite et la laisse finir en arrière-plan (lecture seule).
- Espace disque : l'arrêt est vérifié entre chaque étape (place gardée par Windows, OneDrive, logiciels oubliés).

## Publié en 1.7.1

- Correctif : « Jeux et logiciels pas utilisés depuis 3 mois » ne listait que les jeux Steam (la liste des logiciels était mal lue).
- Nettoyage approfondi : le nettoyage de Windows (cleanmgr) ne peut plus bloquer AEROX indéfiniment (15 minutes maximum, ou « Annuler »), Windows finit alors en arrière-plan.

## Publié en 1.7.0 : avis

- « Donner mon avis » (onglet Aide) : note de 1 à 5, commentaire, pseudo facultatif ; publié directement sur GitHub (Issues, étiquette « avis ») par le relais, un seul avis par PC (modifiable). Sam supprime après coup si besoin.
- Invitation discrète sur l'accueil à partir du 3e lancement : « Donner mon avis », « Plus tard » (14 jours), « Ne plus demander ».
- Page GitHub : badge « ★ note / 5 · N avis » mis à jour tout seul + lien « Lire les avis ».
- ⚠ Avant de publier : mettre à jour le code du relais Cloudflare (relais/worker.js), sinon l'envoi d'un avis échoue.

## Publié en 1.6.0 : place sur le disque

- « Ce qui prend de la place » : nouvelle section « Windows garde de la place pour lui » (disque système) avec cases à cocher et un bouton : stockage réservé (~7 Go, petits disques), fichier de veille prolongée réduit (démarrage rapide gardé ; décoché d'office sur portable), points de restauration limités à 5 % du disque (les plus récents gardés), anciennes versions de pilotes jamais utilisées (point de restauration avant), compression de Windows CompactOS (petits disques, décochée d'office). Tout est annulable dans l'historique sauf les anciens pilotes.
- Nouveaux conseils : OneDrive gardé en double sur le PC (« garder uniquement en ligne »), jeux Steam et logiciels pas lancés depuis 3 mois (d'après Windows), autre disque avec de la place (comment y déplacer Téléchargements / Vidéos / jeux Steam), plus gros fichiers perso à cocher et mettre à la corbeille.
- « Fichiers en double » (Nettoyage + fenêtre de l'espace disque) : Bureau, Documents, Images, Vidéos, Musique, Téléchargements de la personne devant l'écran ; comparaison au contenu ; un exemplaire toujours gardé ; copies à la corbeille. Les fichiers OneDrive uniquement en ligne ne sont jamais téléchargés.
- Liste des logiciels : date de dernière utilisation.

## Publié en 1.5.4 : grosse vérification

- Vérification automatique sur un vrai Windows (GitHub, machine jetable) à chaque envoi sur la branche : toutes les pages, le diagnostic, toutes les analyses et fenêtres, le blocage des notifications sur un faux profil Chrome, la version portable, puis les vraies actions (nettoyage, corbeille, mode performances, Assistant stockage, processeur, démarrage, programmes en fond, dépannages, test de connexion, vérification du disque, point de restauration) et leurs annulations depuis l'historique. Résultat : aucun plantage.
- Compte standard + mot de passe ADMIN : les programmes au démarrage, l'accès micro/caméra, l'Assistant stockage, les effets visuels, les caches nettoyés et le rapport d'aide sur le Bureau sont maintenant ceux de la personne devant l'écran (avant : ceux du compte admin).
- Réparer la connexion Internet : une adresse IP fixe réglée à la main est gardée (avant : remise en automatique).
- Retour aux DNS automatiques plus fiable.
- Cartes graphiques de machines virtuelles (Hyper-V, VMware, VirtualBox) plus signalées comme « pilote ancien ».

## Publié en 1.5.3

- Compte ADMIN séparé : Assistance rapide ne s'affichait pas en 1.5.2 (le programme lancé par la tâche planifiée se fermait avec elle). Lancement via un raccourci ouvert par l'Explorateur de la personne ; AEROX vérifie qu'elle s'est vraiment ouverte, sinon il explique comment l'ouvrir (ou l'installer depuis le Store) et note le détail pour le rapport de bug. Même correctif pour les pages des navigateurs.

## Publié en 1.5.2

- Compte standard + mot de passe d'un compte ADMIN : Assistance rapide s'ouvre maintenant chez la personne devant l'écran (avant : « Création du répertoire de données impossible », elle s'ouvrait dans le compte admin). Pareil pour les pages des Paramètres, le Store, l'appli Caméra et les pages des navigateurs.

## Publié en 1.5.1

- Correctif : la page Système plantait en 1.5.0 (nouvelle fonction de la fenêtre des navigateurs qui portait le même nom qu'une fonction de la page Système).
- Notifications : grandes enseignes, banques et sites français courants reconnus comme normaux (Castorama était proposé au blocage).

## Publié en 1.5.0

- Dépannages rapides (onglet Réparation) : « Pas de son » (service audio relancé, sorties désactivées réactivées, sourdine enlevée, volume remonté si ~0), « Le micro ne marche pas » (accès au micro réautorisé dans la confidentialité, micro réactivé, sourdine/niveau), « Webcam introuvable » (accès caméra réautorisé, webcam réactivée, état du pilote, appli Caméra pour tester, conseils cache/touche Fn), « L'imprimante n'imprime plus » (file vidée, service relancé, imprimante remise en ligne, état de chaque imprimante), « Bureau ou barre des tâches figés » (Explorateur relancé).

- Nettoyage des anciens composants (DISM) quand une mise à jour attend un redémarrage (0x800F0806) : plus affiché comme une erreur ; message simple « redémarre puis relance », et l'étape est sautée d'office si Windows signale un redémarrage en attente.

- « Pubs et fausses alertes de virus » (onglet Réparation + diagnostic, catégorie « Navigateurs ») : Chrome, Edge, Brave, Opera / Opera GX, tous les comptes et profils. Sites autorisés à envoyer des notifications (suspects/inconnus cochés, connus décochés) bloqués en un clic : navigateur fermé le temps de la modification, seule la valeur visée est changée dans ses réglages, sauvegarde avant. Réglages imposés (« Géré par ton organisation » : extensions forcées, page d'accueil, démarrage, moteur de recherche) retirés avec sauvegarde .reg, annulable dans l'historique ; jamais sur un PC d'entreprise (domaine). Extensions listées (hors magasin, imposées, qui changent l'accueil/la recherche signalées) et page d'accueil/recherche détournées : bouton qui ouvre la bonne page du navigateur. Firefox : conseils.

- Version portable (clé USB) : `AeroxPCCare_Portable.zip` publié avec chaque version. Fichier `portable.txt` à côté du programme : réglages, journaux et historique sur la clé (`donnees\<nom du PC>`, jamais mélangés entre PC), rien d'installé, la mise à jour propose le nouveau zip portable au lieu de l'installateur, « portable » affiché à côté du numéro de version.

## Publié en 1.4.0

- « Optimisation complète » (accueil) : parcours guidé point de restauration → diagnostic → programmes au démarrage → programmes cachés en fond → logiciels inutiles → nettoyage approfondi → mises à jour ; on choisit à chaque étape (fermer = passer), « Annuler » arrête le parcours ; à la fin, redémarrage proposé et diagnostic automatique au lancement suivant pour le bilan avant / après.
- « Programmes cachés en fond » (Performances + diagnostic, catégorie « En fond ») : tâches planifiées et services hors Microsoft, reconnus et expliqués (inutiles cochés d'office, inconnus décochés, à garder grisés : antivirus, pilotes, son, mises à jour des navigateurs…). Couper = tâche désactivée / service en manuel, annulable dans l'historique. Jamais de tâche de Windows.

- Bilan « Avant / après AEROX » dans le diagnostic : le premier diagnostic sert de point de départ, chaque diagnostic suivant compare note, problèmes à régler, temps de démarrage de Windows (mesuré par Windows, événement 100), programmes au démarrage, programmes en fond, mémoire utilisée, espace libre ; écarts en vert/orange ; bouton « Repartir de zéro ».

- Correctif : avec un seul problème restant, le diagnostic affichait « 15 problème(s) », « -14 corrigé(s) » (le problème unique était compté comme ses 15 champs).
- Wi-Fi Intel d'ancienne génération (3165/3168/7265 en 19.51.x, 3160/7260 en 18.33.x) : plus d'alerte « pilote ancien » quand c'est déjà la dernière version qu'Intel propose.

- Écran de chargement : centrage vertical calculé avec la hauteur réelle des textes (selon la police et l'échelle de l'écran), le bloc entier est au milieu du cadre.

## Publié en 1.3.0

- Bouton « Annuler » sur la barre de tâche en cours : arrêt immédiat des analyses, arrêt après l'élément en cours pour les mises à jour de logiciels et « Tout réparer », refus expliqué pour ce qui modifie Windows en profondeur (Windows Update, réparation, pilotes…).
- « Pourquoi mon PC rame ? » (onglet Performances + bouton dans le diagnostic) : mesure 20 s du processeur, de la mémoire et du disque, programmes qui consomment le plus (noms parlants), pistes concrètes (programme gourmand, RAM saturée avec conseil de barrette précis, disque saturé / HDD, mode économie d'énergie, processeur bridé, PC pas redémarré, trop de programmes au démarrage) avec boutons d'action.
- Diagnostic, nouvelle catégorie « Performances » : mode économie d'énergie sur PC fixe, processeur bridé (état max < 100 %), mémoire virtuelle désactivée.
- Espace disque : choix du disque à analyser, et en tête de la fenêtre « Ce que tu peux faire pour libérer de la place » (corbeille, Windows.old, veille prolongée, vieux installateurs des Téléchargements mis à la corbeille, Téléchargements/Vidéos, plus gros jeux Steam, plus gros fichiers avec « Afficher », nettoyage approfondi, logiciels par taille).

## À décider le 31 octobre

- Licence : rester en MIT, passer en GPL-3.0 (copies obligatoirement publiques et créditées, compatible signature gratuite SignPath) ou gratuiciel « tous droits réservés » (pas de modification autorisée, mais plus open source : certificat payant à prévoir).
- Signature numérique : SignPath Foundation (gratuit, éditeur « SignPath Foundation ») ou Certum Open Source (~49 €/an, au nom de Sam). Une fois signé : AEROX refusera toute mise à jour sans la signature officielle.
- En attendant : double authentification sur le compte GitHub (protège le canal des mises à jour).

## À faire

_(rien pour l'instant)_

## Fait

- 1.2.9 : batterie (portables), écran de chargement centré, « 0 logiciel » corrigé, économie d'énergie de la carte réseau corrigée.
- 1.2.6 : pages web ouvertes dans la session de la personne quand AEROX tourne avec un compte admin séparé.
- 1.2.5 : winget activé pour le compte admin si besoin.
- 1.2.4 : « Ne plus signaler » ; liens web robustes.
- 1.2.3 : écran de chargement avec une barre violette.
- 1.2.2 : vérification des pilotes directement dans le logiciel.
