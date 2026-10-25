# AEROX PC Care : confidentialité

AEROX PC Care est gratuit et ne vit pas de tes données : il n'y a ni publicité, ni compte à créer, ni revente de quoi que ce soit.
Cette page dit exactement ce qui quitte ton PC, quand, et ce qui n'en sort jamais.

## Ce qui n'est jamais envoyé ni lu

- Ton nom, celui du PC, ton adresse e-mail, tes fichiers (photos, documents, téléchargements, jeux).
- Tes mots de passe, les cookies et l'historique de tes navigateurs : AEROX ne les lit jamais, même pendant l'analyse de sécurité.
- La mémoire des autres programmes : AEROX ne la lit jamais.

## Ce qui peut être envoyé

| Quoi | Quand | Où | Contenu |
|---|---|---|---|
| **Statistiques anonymes** | De temps en temps (désactivables : onglet Aide > Statistiques anonymes) | Relais d'AEROX (Cloudflare) | Des compteurs seulement : version d'AEROX, types de problèmes trouvés (par exemple « écran bleu »), lenteurs non reconnues, réparations qui n'ont pas suffi. Jamais de nom, de nom de PC, de chemin ni d'identifiant. |
| **Rapport de bug** | Seulement si tu cliques sur « Envoyer le rapport », après l'avoir relu | Liste **publique** des bugs du logiciel sur GitHub | Version d'AEROX et de Windows, langue, date, erreurs du logiciel, fin du journal et ta description. Le nom de ton compte et les adresses e-mail y sont masqués. |
| **Avis** | Seulement si tu l'envoies | Page **publique** du logiciel sur GitHub | Ta note, ton pseudo et ton commentaire (gros mots masqués), la version d'AEROX, et un identifiant au hasard créé à l'installation pour que tu puisses modifier ton avis au lieu d'en publier un deuxième. |
| **Rapport de sécurité** | Seulement si tu cliques sur « Envoyer au développeur », après l'avoir relu | Salon Discord **privé** du développeur (jamais sur GitHub) | Le résultat de l'analyse de sécurité : programmes, dossiers et réglages suspects, avec un code à 6 caractères. Le nom de ton compte est masqué dans les chemins, les noms des comptes administrateurs et des fichiers de mots de passe ne sont pas copiés. |

Le relais ne garde jamais ton adresse IP telle quelle : seulement une empreinte brouillée avec une clé secrète, qui sert à limiter les envois
abusifs et disparaît au bout d'une heure (une journée pour les statistiques). Les statistiques sont additionnées par mois.
Le relais ne fait que transmettre : il n'envoie jamais d'ordre au logiciel.

## Ce qu'AEROX télécharge (sans rien envoyer de toi)

- La vérification des mises à jour d'AEROX et ses fichiers, depuis GitHub (le fichier est vérifié par son empreinte avant d'être installé).
- À ta demande seulement : le compteur de FPS (Intel PresentMon, refusé s'il n'est pas signé par Intel), le module de températures,
  le test de débit (Speedtest® by Ookla), la recherche de la page du BIOS de ton PC sur le site de son fabricant.

## Ce qui reste sur ton PC

Les journaux, l'historique des changements, les réglages et la quarantaine sont rangés dans `C:\Program Files\AeroxPCCare\protege`,
un dossier réservé aux administrateurs (sur la clé USB pour la version portable). Ils ne sont envoyés nulle part.
La désinstallation retire le logiciel et garde ces données, pour ne rien perdre en cas de réinstallation : tu peux supprimer ce dossier à la main.

## Une question, une demande de suppression ?

Écris au développeur sur le serveur Discord d'AEROX PC Care, ou ouvre une demande sur la page GitHub du logiciel.
Un rapport de bug ou un avis publié sur GitHub peut être retiré à ta demande.
