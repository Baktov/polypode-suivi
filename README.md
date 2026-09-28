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
avec une ligne par membre de l'équipe sélectionnée (leader en tête) :

- nom en couleur de classe ;
- **Coffre n/9** : cases débloquées de la grande chambre forte ;
- **Runes n** (en vert) : points de runes de pouvoir à dépenser, s'il y en a ;
- les **écus** d'amélioration d'objet (icône et quantité).

Au survol d'un personnage, l'infobulle détaille :

- **Grande chambre forte** : progrès de chaque case (raids, donjons, monde), en vert une fois
  atteinte ;
- **Amélioration d'objet** : chaque écu ;
- **Ressources** possédées (marne de Lumière du Vide, bons communautaires, sous-pièce, éclats
  de Dundun, fragments de clé de coffre, honneur, conquête...) ;
- **Renommées** débloquées de l'extension (masquables, voir Options) ;
- **Runes de pouvoir** : points à dépenser, et si une rune est achetable ;
- la date des informations d'un autre personnage.

La liste défile ; Échap ferme la fenêtre ; elle suit l'équipe sélectionnée.

### Activités

Le bouton **Activités** (en haut à droite) remplace le résumé par le panneau des **activités de
l'extension**, rangées comme dans Plumber : Gouffres, Traque, Forces de Zul'jarra, Cour de
Lune-d'Argent, Tribu amani, Harandar, La Singularité, Duellum. À droite de chaque activité, les
personnages suivis qui l'ont **faite** (vert) ou **commencée** (jaune, « … ») ; pour une série de
quêtes (bonus de renom, traque du monde), « nom n/total ». Les activités habituelles (quêtes
hebdomadaires) sont toujours listées ; les autres (quotidiennes, boss, avis de recherche...)
apparaissent dès qu'un personnage suivi les a faites ou commencées. L'infobulle donne l'état de
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
  (liste des écus 12.0 ou 12.1 selon le client). Ils seront à mettre à jour à la prochaine
  extension.
- Sur **WoW Forever**, ce qui n'existe pas (runes, écus de Midnight...) reste simplement vide.

---

## Options

Dans **Options → AddOns → Polypode → Suivi** (réglage propre à chaque personnage) :

| Option | Défaut | Effet |
|---|---|---|
| Tous les personnages | Non | La fenêtre liste tous les personnages dont des informations ont été enregistrées au lieu de l'équipe sélectionnée (même case que dans la barre de titre de la fenêtre) |
| Afficher les renommées | Non | Détaille les renommées de l'extension dans l'infobulle de chaque membre. Inutile avec un seul compte Battle.net : les renommées y sont communes à tous les personnages |

---

## Version

`1.4.0` : panneau « Activités » (bouton en haut à droite).
`1.3.0` : bouton « Options » dans la barre de titre de la fenêtre.
`1.2.1` : « Afficher les renommées » décochée par défaut (remise à décochée une fois sur les personnages déjà réglés).
`1.2.0` : case « Tous les personnages », informations sauvegardées et datées, grande chambre forte remise à zéro à la réinitialisation hebdomadaire.
`1.1.0` : option « Afficher les renommées ».
`1.0.0` : première version (grande chambre forte, écus, ressources, renommées, runes de pouvoir).
