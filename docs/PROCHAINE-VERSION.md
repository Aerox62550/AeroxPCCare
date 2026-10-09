# Notes pour la prochaine version

Idées et demandes validées par Sam, à faire dans la prochaine mise à jour.

## À faire

- **Écran de chargement : vraie barre de progression violette.**
  Aujourd'hui la barre défile en boucle (style « Marquee » de Windows, verte/grise) sans lien avec le chargement.
  À la place : une barre violette (#7C5CFF, la couleur de l'appli) qui se remplit selon l'avancement réel
  de l'ouverture (chargement de la DLL, du script, de l'interface, des infos du PC…), avec le texte de l'étape en cours.
  Piste : barre dessinée à la main dans `AeroxSplash` (launcher/Launcher.cs) + une méthode `AeroxSplash.SetProgress(pourcent, texte)`
  appelée par le script à chaque étape du démarrage.
