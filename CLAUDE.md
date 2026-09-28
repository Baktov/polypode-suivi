# CLAUDE.md — Polypode Suivi (Addon WoW)

Addon compagnon de **Polypode** (dossier voisin `../Polypode`, dépôt séparé) : fenêtre « Suivi de
l'équipe » (grande chambre forte, écus, ressources, renommées, runes de pouvoir de chaque membre
de l'équipe sélectionnée). Les conventions de Polypode s'appliquent (voir `../Polypode/CLAUDE.md`) :
commentaires en français, code en anglais, pas de librairie externe, pas de `print()`, bloc
`-- Polypode Suivi: Fichier — rôle` en tête de fichier, tout contenu de taille variable défile,
Retail (120000) et WoW Forever (16001) avec tests d'existence des API (lectures sous `pcall`).

## Architecture

| Fichier | Rôle |
|---|---|
| `Polypode_Suivi.toc` | `## Dependencies: Polypode`, SavedVariables de compte `PolypodeSuiviData` (données de chaque personnage, datées) et par personnage `PolypodeSuiviDB` (options) |
| `Suivi.lua` | Lecture du personnage joué par section (`V` grande chambre forte `C_WeeklyRewards.GetActivities` — rangées R/M/W —, `C` écus `CRESTS_12_0`/`CRESTS_12_1` selon `GetBuildInfo` >= 120100, `R` ressources `RESOURCES` (monnaies `c<id>`, objets `i<id>`, possédées seulement), `F` renommées `C_MajorFactions` de `GetClientDisplayExpansionLevel()`, `P` runes `C_Traits` système 48 / arbre 1186 : `u` points, `b` achetable — calcul repris de Blizzard_MidnightLandingPage). Identifiants repris de Plumber (`Modules/Shared/SharedData.lua`, `ExpansionLandingPage/Retail/ResourceList.lua`) : **à mettre à jour à chaque extension**. Synchro : message `SUIVI:token:nom-royaume:section:flag:k=v,...` (flag `N`/`+`, fragmenté, expéditeur vérifié par `P.IsSender`), envoyé par `P.WhisperOnline` à chaque HELLO/HI (`P.RegisterPeerCallback`) et 3 s après un événement (`WEEKLY_REWARDS_UPDATE`, `CURRENCY_DISPLAY_UPDATE`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, `TRAIT_CONFIG_UPDATED`, `BAG_UPDATE_DELAYED`, `PLAYER_ENTERING_WORLD` ; enregistrés si `C_EventUtils.IsEventValid`), sections modifiées seulement ; reçu par `P.RegisterMessageHandler("SUIVI")`. Fenêtre `PolypodeSuiviFrame` (`P.ToggleSuivi`, `P.RefreshSuivi`, `P.ui.suiviFrame` / `P.ui.suiviPanel`) : ligne par membre (leader en tête), détail en infobulle ; suit `P.RefreshUI` (`hooksecurefunc`). Bouton `P.AddTitleButton` (`P.ui.suiviButton`), commande `/poly suivi`. Sauvegarde : `received` = `PolypodeSuiviData[clé] = { sections, at, times = { [section] = date } }` (heure serveur), personnage joué stocké par `StoreOwn` (à chaque `SendAll` et à `PLAYER_LOGOUT`) ; `DataFor` renvoie une copie dont la grande chambre forte est remise à « 0/seuil » si `times.V` précède la dernière réinitialisation hebdomadaire (`LastWeeklyReset` : `C_DateAndTime.GetSecondsUntilWeeklyReset` − 7 jours ; la donnée enregistrée n'est pas modifiée). Options (`DEFAULTS`, `PolypodeSuiviDB` complété à `ADDON_LOADED`) : `showAll` (tous les personnages sauvegardés encore dans le roster, par ordre alphabétique ; case `P.ui.suiviAllCheck` à gauche de la barre de titre + case du panneau), `showFactions` (renommées dans l'infobulle, décochée par défaut ; migration unique `factionsDefaultOff`), case de la sous-catégorie « Suivi » de `P.optionsCategory` (locale `BuildSettingsPanel`, à `PLAYER_LOGIN` + 1 image) |

## Dépendances vers Polypode (API publique utilisée)

`P.AddTitleButton`, `P.RegisterSlashCommand`, `P.RegisterMessageHandler`, `P.RegisterPeerCallback`,
`P.WhisperOnline`, `P.IsSender`, `P.MAX_MESSAGE_LENGTH`, `P.RefreshUI` (accroche), `P.GetTeamToken`,
`P.GetCharKey`, `P.GetDisplayName`, `P.db.roster`, `P.GetSelectedTeam`, `P.GetTeamLeader`,
`P.GetTeamMembers`, `P.GetCharacter`, `P.SortedKeyItems`, `P.optionsCategory`, `P.CreatePanel`, `P.CreateScrollList`, `P.SetListData`,
`P.SkinFrame`, `P.SkinPanel`. Toute évolution de ces fonctions dans Polypode doit rester
compatible, ou ce fichier doit suivre.

## Pistes

- Onglet **Activités** (assauts, traque, gouffres...) : nécessite des tables d'identifiants de
  quêtes / widgets propres au patch (cf. Plumber `ExpansionLandingPage/Retail/MID_Activity.lua`).
- **Raids** (boss tués cette semaine) : `C_RaidLocks.IsEncounterComplete` + guide de l'aventurier.

## Après chaque modification

Mettre à jour `README.md` (et ce fichier si l'architecture change), commiter puis pousser sur
`origin` (https://github.com/Baktov/polypode-suivi).
