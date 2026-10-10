# Notes pour la prochaine version

Idées et demandes validées par Sam, à faire dans la prochaine mise à jour.

## Prêt sur la branche (1.5.3)

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
