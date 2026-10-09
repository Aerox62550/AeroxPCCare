# Notes pour la prochaine version

Idées et demandes validées par Sam, à faire dans la prochaine mise à jour.

## Prêt sur la branche (part au prochain patch, 1.2.7)

- Écran de chargement centré (logo, titre, étape, barre, pourcentage) et adapté à la mise à l'échelle de l'écran (125 %, 150 %…), fin liseré autour.
- Relecture à froid des versions 1.2.2 à 1.2.6, corrections :
  - « Ne plus signaler » sur le pilote d'une carte graphique ne masque plus celui de l'autre carte (PC avec deux cartes).
  - Les codes d'erreur Windows Update affichés sont les vrais (avant : toujours 0x80131501), donc les bonnes explications.
  - Un winget cassé sur le compte de la personne n'est plus présenté comme un problème « d'autre compte ».

## À faire

_(rien pour l'instant)_

## Fait

- 1.2.6 : pages web ouvertes dans la session de la personne quand AEROX tourne avec un compte admin séparé.
- 1.2.5 : winget activé pour le compte admin si besoin ; une vérification du diagnostic qui plante n'est plus affichée « OK ».
- 1.2.4 : « Ne plus signaler » ; liens web robustes (navigateurs installés, Explorateur, lien copié).
- 1.2.3 : écran de chargement avec une barre violette selon l'avancement réel du démarrage.
- 1.2.2 : vérification des pilotes directement dans le logiciel.
