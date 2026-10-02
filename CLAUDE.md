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
| `Polypode_Suivi.toc` | `## Dependencies: Polypode`, SavedVariables de compte `PolypodeSuiviData` (données de chaque personnage, datées) et `PolypodeSuiviScan` (relevé des campagnes, auteur seulement), par personnage `PolypodeSuiviDB` (options) |
| `Activities.lua` | Données : `ns.PREY_QUESTS` (quête de proie → difficulté 1/2/3, Plumber `SharedData.lua` PreyQuestData), `ns.ACTIVITIES_SEASONS` (saisons de Midnight couvertes), `ns.DYNAMIC_MAP` (2393, Lune-d'Argent) + `ns.MAP_QUESTS` (quêtes de carte affichées si en cours ou `always`, Plumber `ActivityUtil.lua` MapQuests), `ns.ACTIVITIES` = catégories `{ name, label, faction, entries }`, entrées `{ q }` / `{ pool }` / `{ count }` (+ `name` de repli, `label`, `always`, `daily`, `accountwide`), reprises de Plumber `Modules/ExpansionLandingPage/Retail/MID_Activity.lua` (activités à quête seulement) : **à mettre à jour à chaque patch** |
| `Suivi.lua` | Lecture du personnage joué par section (`V` grande chambre forte `C_WeeklyRewards.GetActivities` — rangées R/M/W —, `C` écus `CRESTS_BY_SEASON[n]` selon la saison de Midnight (`CurrentSeason` : `C_SeasonInfo.GetCurrentDisplaySeasonExpansion` + `C_DelvesUI.GetCurrentDelvesSeasonNumber` ; repli `GetBuildInfo` >= 120100 → 12.1), `R` ressources `RESOURCES` (monnaies `c<id>`, objets `i<id>`, possédées seulement), `F` renommées `C_MajorFactions` de `GetClientDisplayExpansionLevel()`, `P` runes `C_Traits` système 48 / arbre 1186 : `u` points, `b` achetable — calcul repris de Blizzard_MidnightLandingPage, `A` activités `ReadActivities` : clé `EntryKey` q<id>/p<id> = 2 faite, 1 en cours, c<id> = nombre fait). Section `W` semaine (`ReadWeekly` : `t1..3` traques par difficulté via `ns.PREY_QUESTS`, `d<palier>` et `r<DifficultyID>` via `C_WeeklyRewards.GetSortedProgressForActivity` (Monde, Raid), `h`/`m`/`p` via `GetNumCompletedDungeonRuns`, `k` niveaux des clés via `C_MythicPlus.GetRunHistory`, `n`/`f` donjons normaux / avec suivants et `x<g|d|r><instanceID>-<difficulté>` exploration (entrées par instance, `dungeonEntries.visits`, nom par `GetRealZoneText`, catégorie « Exploration » en bas de l'infobulle ; gouffre = type « scenario » difficulté 208) comptés à l'entrée par `CountDungeonEntry` à `PLAYER_ENTERING_WORLD` (`GetInstanceInfo` : type « party », difficulté 1 / 205 ; même donjon dans les 2 h non recompté ; `PolypodeSuiviDB.dungeonEntries`, remis à zéro par `DungeonEntries` après la réinitialisation hebdomadaire) — `RequestMapInfo` au login ; vidée par `DataFor` après la réinitialisation hebdomadaire ; totaux `WeeklyTotals` avec repli sur la chambre forte). Section `M` courrier (`ReadMail` : `n` = `HasNewMail()` ; `u`/`t`/`x`/`s` = relevé `ScanMailbox` à `MAIL_INBOX_UPDATE`, boîte ouverte seulement — `GetInboxNumItems`, `GetInboxHeaderInfo` jours restants / lu —, gardé dans `PolypodeSuiviDB.mailScan`) : enveloppe à gauche du nom (non lu, ou expiration < 3 jours) et détail en infobulle. Panneau activités (option `activityMode`, bouton `P.ui.suiviActivityButton` en haut à droite « Activités » / « Résumé ») : `BuildActivityItems(clés)` (en-tête par catégorie, lignes `always` ou faites / commencées par un personnage suivi), texte de droite via `opts.decorate` (`ActivityRightText`), titres `C_QuestLog.GetTitleForQuestID` (demandés une fois, `QUEST_DATA_LOAD_RESULT` rafraîchit), catégories au nom de la faction ; `DataFor` remet la section A à zéro après la réinitialisation hebdomadaire (quotidienne pour `DAILY_KEYS`). Catégorie dynamique en tête (`DynamicQuestIDs` : `C_QuestLine.GetAvailableQuestLines` + `C_TaskQuest.GetQuestsOnMap` de `ns.DYNAMIC_MAP`, types répétable / méta / mission, + `ns.MAP_QUESTS` en cours, + quêtes vues cette semaine `PolypodeSuiviDB.dynamicSeen` ; les autres personnages l'alimentent par leurs clés `q<id>` hors `FIXED_KEYS`). Visibilité : `always`, fait / commencé par un suivi, ou actif ici (`IsActiveHere` : `C_TaskQuest.IsActive` / en cours). Icône `EntryIcon` : atlas du type de quête (`QUEST_ATLAS`, repris de Plumber) ou coche si tous les connus ont fini. Identifiants repris de Plumber (`Modules/Shared/SharedData.lua`, `ExpansionLandingPage/Retail/ResourceList.lua`) : **à mettre à jour à chaque extension**. Synchro : message `SUIVI:token:nom-royaume:section:flag:k=v,...` (flag `N`/`+`, fragmenté, expéditeur vérifié par `P.IsSender`), envoyé par `P.WhisperOnline` à chaque HELLO/HI (`P.RegisterPeerCallback`) et 3 s après un événement (`WEEKLY_REWARDS_UPDATE`, `CURRENCY_DISPLAY_UPDATE`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, `TRAIT_CONFIG_UPDATED`, `BAG_UPDATE_DELAYED`, `PLAYER_ENTERING_WORLD` ; enregistrés si `C_EventUtils.IsEventValid`), sections modifiées seulement ; reçu par `P.RegisterMessageHandler("SUIVI")`. Fenêtre `PolypodeSuiviFrame` (`P.ToggleSuivi`, `P.RefreshSuivi`, `P.ui.suiviFrame` / `P.ui.suiviPanel`), redimensionnable (poignée bas-droite `frame.resizeGrip`, `SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)`, taille dans `PolypodeSuiviDB.width` / `height`) : tableau sans trait : ligne d'en-tête `{ columnHeader = true }` puis une ligne par membre (leader en tête) ; colonnes `MemberColumns()` (coffre, runes, un écu par colonne, charges du catalyseur — `CATALYST_BY_SEASON` / `CatalystID()`, lues dans la section `R` —, traques, gouffres, donjons, raids) remplies dans `item.cells` et mesurées par `BuildMemberTable` (infobulle de chaque en-tête : `tip` de la colonne → `header.tips`, zone survolable `CellHover`) (largeurs dans `memberColumns`, 0 = masquée), placées depuis le bord droit par `LayoutCells` (dans `decorate`), le nom (`FormatMember`) prenant la place restante ; détail en infobulle ; suit `P.RefreshUI` (`hooksecurefunc`). Enregistré auprès de `P.RegisterCharacterData` (suppression d'un personnage dans Polypode → `received[clé]` oublié, sur tous les clients). Bouton `P.AddTitleButton` (`P.ui.suiviButton`), commande `/poly suivi`. Sauvegarde : `received` = `PolypodeSuiviData[clé] = { sections, at, times = { [section] = date } }` (heure serveur), personnage joué stocké par `StoreOwn` (à chaque `SendAll` et à `PLAYER_LOGOUT`) ; `DataFor` renvoie une copie dont la grande chambre forte est remise à « 0/seuil » si `times.V` précède la dernière réinitialisation hebdomadaire (`LastWeeklyReset` : `C_DateAndTime.GetSecondsUntilWeeklyReset` − 7 jours ; la donnée enregistrée n'est pas modifiée). Options (`DEFAULTS`, `PolypodeSuiviDB` complété à `ADDON_LOADED`) : `showAll` (lu par `ShowAll()` = option ou mode solo de Polypode `P.IsSoloMode` (0.54.0, locale `IsSolo`) : imposé, case cochée et grisée, setter du panneau ignoré ; tous les personnages sauvegardés encore dans le roster, par ordre alphabétique ; case `P.ui.suiviAllCheck` dans la barre de titre, à droite du bouton `P.ui.suiviOptionsButton` « Options » → `Settings.OpenToCategory` de la catégorie « Suivi » (locale `settingsCategory`, fenêtre fermée) + case du panneau), `showFactions` (renommées dans l'infobulle, décochée par défaut ; migration unique `factionsDefaultOff`), case de la sous-catégorie « Suivi » de `P.optionsCategory` (locale `BuildSettingsPanel`, à `PLAYER_LOGIN` + 1 image) |

**Campagnes** (section `S`, `Activities.lua` + `Suivi.lua`) :

- `ns.CAMPAIGNS` = `{ expansion, patch, name (repli), ids = { variantes } }`, de la plus ancienne à
  la plus récente (la dernière fait la colonne « Campagne »), Mists of Pandaria → Midnight ;
  `ns.CAMPAIGNS_IGNORED` = identifiants du relevé écartés (rattrapage, tests, « passer
  l'introduction », didacticiels, conteneurs `isContainerCampaign`, doublons techniques). Les deux
  listes sont tirées du relevé `PolypodeSuiviScan`.
- Lecture (`ReadCampaigns`) : par entrée, `CampaignVariant` choisit la variante ouverte au
  personnage (`GetState` ≠ `Invalid`), sinon celle où il a fait le plus de chapitres ;
  `CampaignChapters` : campagne `Complete` = tous les chapitres, sinon chapitre fait si
  `C_QuestLine.IsComplete(chapterID)` (un chapitre EST une suite de quêtes, comme
  `CampaignChapterMixin` de Blizzard), quête de récompense faite (presque toujours 0 hors BfA) ou
  avant `GetCurrentChapterID` (souvent nil). Valeur `<campaignID>=faits/total[~raison]`, raison =
  `CampaignFailureText` (`GetFailureReason().text` si `Stalled`, sans `,` `~` `|`, ≤ 160 octets) ;
  extensions précédentes envoyées seulement si commencées ; `GetAvailableCampaigns` hors liste →
  « Autres campagnes ». Affichage : `CampaignValue` (première variante présente),
  `CampaignProgressText`, `CampaignFailure` ; infobulle groupée par extension (en cours d'abord,
  puis précédentes si option `showOldCampaigns` : en cours + « n terminée(s) »).
- `C_CampaignInfo.GetCampaignID(questID)` ne répond que pour des quêtes chargées : ne pas s'en
  servir pour repérer une campagne (abandonné en 1.18.0).
- **Outils de l'auteur** (`IsOwner()` : `P.GetTeamToken()` == `OWNER_TOKEN`, hash djb2 du BattleTag,
  jamais le BattleTag en clair) : `/poly suivi scan` → `ScanCampaigns` (identifiants 1 à
  `SCAN_MAX_ID` = 1500 : champs de `CampaignInfo`, état, raison de blocage, chapitres avec
  `complete`) ; bouton « Nouveau » (`frame.scanButton`, à gauche de « Activités », fond rouge
  clignotant) si `UnknownCampaigns()` (cherchées une fois par session) trouve une campagne hors
  des deux listes ; clic = relevé.
- **Mise à jour après un patch** : relevé (bouton ou commande) puis `/reload` ; lire
  `WTF/Account/<compte>/SavedVariables/Polypode_Suivi.lua` (les comptes partagent ce fichier par
  lien), classer chaque nouvel identifiant dans `ns.CAMPAIGNS` (extension / patch d'après la
  texture `uiTextureKit`, les noms de chapitres, BtWQuests) ou `ns.CAMPAIGNS_IGNORED`.

**Tri du tableau** : chaque colonne de `MemberColumns()` a un `id` stable et une valeur `sort(sections)`
(nil = sans valeur, en bas) ; clic sur un en-tête (`CellHover`, bouton) ou sur « Personnage »
(`opts.onClick` de la ligne d'en-tête) → `SetSort` ; `PolypodeSuiviDB.sortColumn` (`"name"` ou id)
/ `sortDesc` ; `SortItems` dans `BuildMemberTable`, flèche `SortMark` (comme Polypode Data).

**Saison** : l'en-tête de la liste affiche `SeasonText()` (« Midnight, saison 2 ») et « listes à mettre à jour » si `ListsOutdated()` (autre extension, ou saison absente de `CRESTS_BY_SEASON` / `ns.ACTIVITIES_SEASONS`). À chaque nouvelle saison : ajouter ses écus à `CRESTS_BY_SEASON`, mettre à jour `Activities.lua` et `ns.ACTIVITIES_SEASONS` (d'après Plumber).

## Dépendances vers Polypode (API publique utilisée)

`P.AddTitleButton`, `P.RegisterSlashCommand`, `P.RegisterMessageHandler`, `P.RegisterPeerCallback`,
`P.WhisperOnline`, `P.IsSender`, `P.MAX_MESSAGE_LENGTH`, `P.RefreshUI` (accroche), `P.GetTeamToken`,
`P.GetCharKey`, `P.GetDisplayName`, `P.db.roster`, `P.GetSelectedTeam`, `P.GetTeamLeader`,
`P.GetTeamMembers`, `P.GetCharacter`, `P.SortedKeyItems`, `P.optionsCategory`, `P.CreatePanel`, `P.CreateScrollList`, `P.SetListData`,
`P.SkinFrame`, `P.SkinPanel`, `P.SkinButton`, `P.SkinCheckBox` (si présents), `P.Debug`. Toute évolution de ces fonctions dans Polypode doit rester
compatible, ou ce fichier doit suivre.

## Pistes

- Activités calculées par Plumber (réserve dorée, proies tuées, abondance, plafond des récompenses) :
  widgets / sorts propres au patch, non repris.
- **Raids** (boss tués cette semaine) : `C_RaidLocks.IsEncounterComplete` + guide de l'aventurier.

## Après chaque modification

Suivre la procédure commune de `../Polypode/CLAUDE.md` (section « Modules Polypode et
documentation »), sans attendre qu'on le demande :

1. incrémenter `## Version` du `.toc` et la rappeler à la fin du message de commit,
   « Description (x.y.z) » ;
2. `README.md` : ajouter `` `x.y.z` : description. `` en tête de la section « Version » (du plus
   récent au plus ancien) et mettre à jour les sections d'utilisation concernées ;
3. ce fichier : architecture (fichiers, fonctions, données, SavedVariables, messages) et liste
   « Dépendances vers Polypode » si une nouvelle fonction `P.*` est utilisée ;
4. si le périmètre du module change : section « Addons compagnons » du `README.md` de Polypode et
   liste des compagnons de son `CLAUDE.md` (commit dans ce dépôt-là aussi) ;
5. commiter puis pousser sur `origin` (https://github.com/Baktov/polypode-suivi).
