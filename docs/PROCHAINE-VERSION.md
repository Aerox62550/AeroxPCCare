# Notes pour la prochaine version

Idées et demandes validées par Sam, à faire dans la prochaine mise à jour.

## Prêt sur la branche 2.0.2 : mémoire en mode discret

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
