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
- l'ancienneté des informations d'un autre personnage.

La liste défile ; Échap ferme la fenêtre ; elle suit l'équipe sélectionnée.

---

## Fonctionnement

- Le personnage joué est lu en direct. Les autres envoient leurs informations par Polypode
  (message `SUIVI`) à chaque connexion d'un de vos clients, puis 3 secondes après un changement
  (coffre, monnaies, sacs, renommée, runes), et seulement ce qui a changé. Un personnage sans
  Polypode Suivi, ou pas encore vu, apparaît « pas d'infos ».
- Les informations sont lues comme le fait le « Résumé de l'extension » de l'addon **Plumber**
  (API publiques de WoW) ; les identifiants des écus et des ressources de Midnight en sont repris
  (liste des écus 12.0 ou 12.1 selon le client). Ils seront à mettre à jour à la prochaine
  extension.
- Pas encore d'**Activités** (assauts, traque, gouffres...) : elles reposent sur des tables
  d'identifiants de quêtes propres à chaque patch.
- Sur **WoW Forever**, ce qui n'existe pas (runes, écus de Midnight...) reste simplement vide.

---

## Options

Dans **Options → AddOns → Polypode → Suivi** (réglage propre à chaque personnage) :

| Option | Défaut | Effet |
|---|---|---|
| Afficher les renommées | Oui | Détaille les renommées de l'extension dans l'infobulle de chaque membre. Inutile avec un seul compte Battle.net : les renommées y sont communes à tous les personnages |

---

## Version

`1.1.0` : option « Afficher les renommées ».
`1.0.0` : première version (grande chambre forte, écus, ressources, renommées, runes de pouvoir).
