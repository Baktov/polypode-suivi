# Polypode Suivi

Fenêtre **« Suivi de l'équipe »** pour [Polypode](https://github.com/Baktov/polypode), sous forme
d'addon séparé (chargé ou non depuis la liste des AddOns de WoW, par personnage) : pour chaque
membre de l'équipe sélectionnée, les informations du « Résumé de l'extension » qui comptent
pour faire avancer toute l'équipe.

Nécessite **Polypode 0.51.0** ou plus récent.

---

## Installation

1. Installer d'abord **Polypode** (dépendance obligatoire).
2. Placer le dossier `Polypode_Suivi` dans `World of Warcraft/_retail_/Interface/AddOns/`
   (et, pour **WoW Forever**, dans `World of Warcraft/_classic_beta_/Interface/AddOns/`, par
   exemple par une jonction `mklink /J`).
3. Cocher « Polypode Suivi » dans la liste des AddOns, **sur chaque personnage** dont vous
   voulez voir les informations : chacun envoie les siennes.

---

## Utilisation

Le bouton **Suivi** (barre de titre de la fenêtre Polypode) ou `/poly suivi` ouvre une fenêtre
présentée comme un **tableau sans trait** : une ligne d'en-tête (Personnage, Coffre, Runes, icônes
des écus, icône du catalyseur, Campagne, Traques, Gouffres, Donjons, Raids), puis une ligne par
membre de l'équipe sélectionnée (leader en
tête), aux colonnes alignées verticalement (à droite, à la largeur de leur plus long contenu ; le
nom prend la place restante et se tronque si la fenêtre est étroite ; une colonne vide chez tous
est masquée ; au survol, chaque en-tête indique ce que compte sa colonne — grande chambre
forte, nom de l'écu, catalyseur...).

**Tri** : un clic sur un en-tête trie le tableau par cette colonne (du plus grand au plus petit ;
« Personnage » : par nom, de A à Z), un second clic inverse l'ordre ; une flèche marque la colonne
triée, les personnages sans valeur restent en bas. Le tri est gardé par personnage ; sans tri
choisi, le leader est en tête.

Les colonnes :

- une **enveloppe** à gauche du nom si le personnage a du **courrier non lu**, ou un courrier qui
  expire dans moins de 3 jours ;
- nom en couleur de classe ;
- **Coffre** n/9 : cases débloquées de la grande chambre forte ;
- **Runes** n (en vert) : points de runes de pouvoir à dépenser, s'il y en a ;
- les **écus** d'amélioration d'objet (icône et quantité), de l'aventurier à gauche au mythique à droite ;
- les **charges du catalyseur** disponibles (monnaie de la saison : flux de mana de Chancrevenin
  en saison 2 de Midnight, 0 en gris) ;
- **Campagne** faits/total : chapitres terminés de la campagne la plus récente (« La malédiction
  d'Ula'tek » en 12.1 ; vert si terminée, gris si pas commencée) ;
- ce qui a été fait **cette semaine** : nombre de traques, gouffres, donjons et raids (en gris
  si zéro ; raids = boss tués).

Au survol d'un personnage, l'infobulle détaille :

- **Grande chambre forte** : progrès de chaque case (raids, donjons, monde), en vert une fois
  atteinte ;
- **Amélioration d'objet** : chaque écu ;
- **Ressources** possédées (marne de Lumière du Vide, bons communautaires, sous-pièce, éclats
  de Dundun, fragments de clé de coffre, honneur, conquête...) ;
- **Renommées** débloquées de l'extension (masquables, voir Options) ;
- **Runes de pouvoir** : points à dépenser, et si une rune est achetable ;
- **Campagnes (chapitres)** : avancement des campagnes de l'extension en cours, « patch – nom :
  faits/total » (ex. « 12.1 – La malédiction d'Ula'tek : 1/6 »), et, pour une campagne bloquée, ce
  qu'il faut faire pour la reprendre (texte du jeu, en gris). Avec l'option « Campagnes des
  extensions précédentes », suivent les extensions précédentes (de Mists of Pandaria à The War
  Within, de la plus récente à la plus ancienne) : campagnes commencées mais pas finies, et nombre
  de campagnes terminées par extension. Les campagnes à variantes (Alliance / Horde, congrégations
  de Shadowlands, domaines de classe de Legion) n'occupent qu'une ligne : celle du personnage ;
- la date des informations d'un autre personnage ;
- **Cette semaine** : traques faites par difficulté (Normal, Difficile, Cauchemar, sur 4), gouffres
  par palier, donjons héroïques / mythiques / mythiques+ avec le niveau des clés, boss de raid par
  difficulté (LFR, normal, héroïque, mythique). Remis à zéro à la réinitialisation hebdomadaire. Les
  donjons **normaux** et **avec suivants** ne sont suivis par aucune API de WoW (ils ne comptent
  pas pour la chambre forte) : Polypode Suivi les compte **à l'entrée** dans le donjon (marqués *),
  sans recompter un retour dans le même donjon dans les 2 heures (reload, déconnexion) ; un donjon
  abandonné compte donc aussi ;
- **Courrier** : « Courrier non lu », puis, d'après la dernière visite du personnage à la boîte aux
  lettres, le nombre de courriers non lus / total et l'**expiration la plus proche** (en rouge à
  moins de 3 jours). WoW ne donne ces détails que boîte aux lettres ouverte : ils sont relevés à
  chaque visite et gardés, datés (comme le fait Altoholic) ;
- **Exploration** (en bas) : nom des **gouffres**, **donjons** et **raids** où le personnage est
  entré cette semaine, avec la difficulté (donjons, raids) et le nombre d'entrées. Noté **à
  l'entrée** dans l'instance (un retour dans la même instance dans les 2 heures n'est pas
  recompté ; une instance abandonnée compte aussi), remis à zéro à la réinitialisation
  hebdomadaire.

La liste défile ; la fenêtre se **redimensionne** par la poignée du coin bas-droit (taille
gardée par personnage) ; Échap ferme la fenêtre ; elle suit l'équipe sélectionnée. L'en-tête de la
liste indique la **saison en cours** (« Midnight, saison 2 », d'après le jeu), et signale en
orange « listes à mettre à jour » si les écus ou les activités repris de Plumber ne couvrent pas
cette saison (nouvelle saison ou nouvelle extension).

### Activités

Le bouton **Activités** (en haut à droite) remplace le résumé par le panneau des **activités de
l'extension**, rangées comme dans Plumber : **Lune-d'Argent** (quêtes répétables, méta
hebdomadaires, donjons et étincelles de guerre proposées dans la ville, trouvées sur la carte),
Gouffres, Traque, Forces de Zul'jarra, Cour de Lune-d'Argent, Tribu amani, Harandar, La
Singularité, Duellum. Chaque activité a l'icône de son type de quête (comme dans Plumber), ou une
coche quand tous les personnages connus l'ont terminée. À droite de chaque activité, les
personnages suivis qui l'ont **faite** (vert) ou **commencée** (jaune, « … ») ; pour une série de
quêtes (bonus de renom, traque du monde), « nom n/total ». Les activités habituelles (quêtes
hebdomadaires) sont toujours listées ; les autres (quotidiennes, boss, avis de recherche...)
apparaissent dès qu'elles sont actives pour le personnage joué, ou qu'un personnage suivi les a
faites ou commencées. L'infobulle donne l'état de
chaque personnage. Le bouton **Résumé** revient à l'affichage par personnage.

Les titres sont ceux du jeu (en français). La liste des activités est reprise de Plumber, qui ne
la partage pas avec les autres addons : seules les activités reposant sur une quête sont suivies
(pas la réserve dorée, les proies tuées, l'abondance ni le plafond des récompenses), et elle est à
mettre à jour quand un patch change les activités. Les activités sont remises à zéro à la
réinitialisation hebdomadaire, et les quotidiennes chaque jour.

Le bouton **Options** (à gauche de la barre de titre) ouvre directement les options du suivi
(Options → AddOns → Polypode → Suivi). La case **Tous les personnages** (à sa droite, rappelée
dans les options)
affiche à la place **tous les personnages dont des informations ont été enregistrées**, par
ordre alphabétique, avec la date de leurs informations (« il y a 2 h », « du 24/09 à 21:10 »).

---

## Fonctionnement

- Le personnage joué est lu en direct. Les autres envoient leurs informations par Polypode
  (message `SUIVI`) à chaque connexion d'un de vos clients, puis 3 secondes après un changement
  (coffre, monnaies, sacs, renommée, runes), et seulement ce qui a changé. Un personnage sans
  Polypode Suivi, ou pas encore vu, apparaît « pas d'infos ».
- Les informations sont **sauvegardées** (fichier de compte, commun à vos comptes s'ils partagent
  leurs `SavedVariables`) avec leur date : un personnage déconnecté reste consultable avec ses
  dernières informations connues.
- **Réinitialisation hebdomadaire** : une grande chambre forte connue d'avant le dernier reset
  (mercredi matin) est affichée **remise à zéro** (seuils conservés), avec une mention dans
  l'infobulle, jusqu'à ce que le personnage envoie ses nouvelles informations.
- Les informations sont lues comme le fait le « Résumé de l'extension » de l'addon **Plumber**
  (API publiques de WoW) ; les identifiants des écus et des ressources de Midnight en sont repris
  (liste des écus choisie selon la saison de Midnight : saison 1 ou 2 ; selon la version du
  client si la saison est inconnue). Ils seront à mettre à jour à la prochaine
  extension.
- **Campagnes** : la liste des campagnes (identifiants du jeu, classées par extension et patch) est
  tirée d'un relevé de toutes les campagnes du jeu ; un chapitre est terminé quand sa suite de
  quêtes l'est (comme dans le journal de quêtes). Elle est à compléter quand un patch ajoute une
  campagne ; en attendant, une nouvelle campagne commencée apparaît dans « Autres campagnes ».
- Sur **WoW Forever**, ce qui n'existe pas (runes, écus de Midnight, campagnes...) reste simplement vide.

---

## Options

Dans **Options → AddOns → Polypode → Suivi** (réglage propre à chaque personnage) :

| Option | Défaut | Effet |
|---|---|---|
| Tous les personnages | Non | La fenêtre liste tous les personnages dont des informations ont été enregistrées au lieu de l'équipe sélectionnée (même case que dans la barre de titre de la fenêtre). Toujours cochée (et grisée) en **mode solo** de Polypode |
| Campagnes des extensions précédentes | Non | Ajoute à l'infobulle de chaque membre les campagnes des extensions précédentes (depuis Mists of Pandaria) : celles commencées mais pas finies, et le nombre de campagnes terminées par extension |
| Afficher les renommées | Non | Détaille les renommées de l'extension dans l'infobulle de chaque membre. Inutile avec un seul compte Battle.net : les renommées y sont communes à tous les personnages |

---

## Crédits

Polypode Suivi est **librement inspiré** du « Résumé de l'extension » de l'addon **Plumber**, de
**Peterodox**. Le code est écrit pour Polypode (aucun fichier de Plumber n'est inclus), mais les
**données** en sont reprises : identifiants des écus et des ressources de Midnight, liste et
classement des activités (identifiants de quêtes). Le calcul « une rune achetable » reprend
celui de l'interface Blizzard (`Blizzard_MidnightLandingPage`). Merci à Peterodox pour ce
travail de recensement.

---

## Version

`1.19.1` : correctif : l'avancement des campagnes d'un personnage était sauvegardé à zéro à la déconnexion (relevé fait pendant la sortie du monde, quand le jeu a déjà vidé ces données). La déconnexion garde le dernier relevé fait en jeu, et l'avancement sauvegardé d'une campagne ne recule plus (relevé trop tôt à la connexion).
`1.19.0` : outil de l'auteur : bouton « Nouveau » quand le jeu contient une campagne absente de la liste.
`1.18.0` : liste des campagnes reconstruite d'après un relevé du jeu (Mists of Pandaria à Midnight, variantes regroupées), chapitres comptés par suite de quêtes, raison du blocage d'une campagne.
`1.17.0` : tri du tableau par clic sur un en-tête de colonne.
`1.16.0` : option « Campagnes des extensions précédentes ».
`1.15.0` : avancement des campagnes (chapitres) par extension, colonne « Campagne ».
`1.14.1` : libellé « Tous les personnages » écarté de 5 px de sa case (skin EllesmereUI).
`1.14.0` : mode solo de Polypode (0.54.0) : « Tous les personnages » imposé, case cochée et grisée.
`1.13.3` : case « Tous les personnages » skinnée EllesmereUI / ElvUI (`P.SkinCheckBox`, Polypode 0.53.3).
`1.13.2` : personnage supprimé dans Polypode (Maj + clic) : ses données de suivi sont oubliées, ici et sur les autres clients connectés.
`1.13.1` : infobulle sur chaque colonne de la ligne d'en-tête.
`1.13.0` : colonne des charges du catalyseur.
`1.12.2` : plus d'infobulle sur la ligne d'en-tête (Polypode 0.51.1 requis).
`1.12.1` : infobulle de la ligne d'en-tête condensée.
`1.12.0` : résumé en tableau sans trait, colonnes alignées avec une ligne d'en-tête.
`1.11.0` : catégorie « Exploration » (gouffres, donjons et raids de la semaine, notés à l'entrée).
`1.10.0` : fenêtre redimensionnable (poignée bas-droite).
`1.9.0` : donjons normaux et avec suivants, comptés à l'entrée.
`1.8.0` : traques, gouffres, donjons et raids de la semaine, avec détail par difficulté.
`1.7.1` : écus de la liste rangés de l'aventurier (gauche) au mythique (droite).
`1.7.0` : saison en cours dans l'en-tête, écus choisis selon la saison, avertissement si les listes sont dépassées.
`1.6.0` : courrier non lu (enveloppe), nombre et expiration relevés à la boîte aux lettres.
`1.5.0` : icônes des activités, catégorie dynamique « Lune-d'Argent », activités actives affichées.
`1.4.0` : panneau « Activités » (bouton en haut à droite).
`1.3.0` : bouton « Options » dans la barre de titre de la fenêtre.
`1.2.1` : « Afficher les renommées » décochée par défaut (remise à décochée une fois sur les personnages déjà réglés).
`1.2.0` : case « Tous les personnages », informations sauvegardées et datées, grande chambre forte remise à zéro à la réinitialisation hebdomadaire.
`1.1.0` : option « Afficher les renommées ».
`1.0.0` : première version (grande chambre forte, écus, ressources, renommées, runes de pouvoir).
