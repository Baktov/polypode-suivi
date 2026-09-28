-- Polypode Suivi: Activities — activités de Midnight suivies par personnage (panneau « Activités »)

local _, ns = ...

-- Liste reprise du « Résumé de l'extension » de l'addon Plumber (Modules/ExpansionLandingPage/
-- Retail/MID_Activity.lua), qui ne la partage pas avec les autres addons. Seules les activités
-- reposant sur une quête sont reprises (les lignes calculées par du code propre à Plumber —
-- réserve dorée, proies tuées, abondance, plafond des récompenses — ne le sont pas). À METTRE À
-- JOUR à chaque patch qui change les activités (comparer avec MID_Activity.lua de Plumber).
--
-- Catégorie : { name = libellé de repli, label = libellé fixe, faction = factionID (nom traduit
-- par le jeu), entries = { ... } }. Entrée :
--   { q = questID }                 une quête (état : 2 faite, 1 en cours) ;
--   { pool = { questID... } }       une quête parmi plusieurs (faite si l'une l'est) ;
--   { count = { questID... } }      nombre de quêtes faites parmi la liste (« n/total ») ;
--   name = titre de repli (anglais, si le jeu n'a pas encore le titre), label = libellé fixe ;
--   always = affichée même si personne ne l'a faite ni commencée (sinon : dès que quelqu'un) ;
--   daily = remise à zéro chaque jour (sinon chaque semaine) ;
--   accountwide = faite pour tout le compte (IsQuestFlaggedCompletedOnAccount).
-- Saisons de Midnight pour lesquelles cette liste est à jour (Plumber 1.9.6 : 12.0 et 12.1) ; hors
-- de ces saisons, la fenêtre signale « listes à mettre à jour ».
ns.ACTIVITIES_SEASONS = { [1] = true, [2] = true }

ns.ACTIVITIES = {
	{ name = "Delves", label = DELVES_LABEL, entries = {
		{ q = 93784, name = "A Gnawing Void of Curiosity", always = true, accountwide = true },
		{ q = 86371, label = "Prime de chasse au trésor", always = true },
		{ count = { 99222, 93821, 93819, 93822, 93820 }, label = "Bonus de renom des gouffres", always = true,
			accountwide = true },
	} },
	{ name = "Prey", label = "Traque", entries = {
		{ count = { 91458, 91523, 91590, 91591, 91592, 91594, 91595, 91596, 91207, 91601, 91602, 91604 },
			label = "Quêtes de traque du monde", always = true },
	} },
	{ name = "Zul'jarra's Forces", faction = 2772, entries = {
		{ q = 96995, name = "Turn Back the Surge", always = true },
		{ q = 95520, name = "Purging the Vaults", always = true },
		{ q = 96639, name = "Patrolling the Temple", daily = true },
		{ q = 96640, name = "Bounty of the Cursed", daily = true },
		{ q = 96641, name = "Relentless Strikes", daily = true },
		{ q = 96642, name = "Decisive Incursions", daily = true },
		{ q = 96643, name = "From Whence it Came", daily = true },
		{ q = 96644, name = "Essence of Malice", daily = true },
		{ q = 98419, name = "Shoulder to Shoulder", daily = true },
		{ q = 98420, name = "What's Out There?", daily = true },
	} },
	{ name = "Silvermoon Court", faction = 2710, entries = {
		{ q = 89289, name = "Favor of the Court", always = true },
		{ pool = { 90573, 90574, 90575, 90576 }, label = "Fortifier les pierres runiques", always = true },
		{ q = 92560, name = "Lu'ashal" },
	} },
	{ name = "Amani Tribe", faction = 2696, entries = {
		{ q = 89507, name = "Abundant Offerings", always = true },
		{ q = 92123, name = "Cragpine" },
	} },
	{ name = "Harandar", faction = 2704, entries = {
		{ q = 89268, name = "Lost Legends", always = true },
		{ pool = { 88993, 88994, 88995, 88996, 88997 }, label = "Relique de Harandar", always = true },
		{ q = 92034, name = "Thorm'belan" },
		{ q = 92013, name = "WANTED: Dionaea's Thorntusks" },
		{ q = 91970, name = "WANTED: Gelatonius" },
		{ q = 92012, name = "WANTED: Gorebarb's Pincers" },
		{ q = 91980, name = "WANTED: Hellebora's Thorn" },
		{ q = 91998, name = "WANTED: Muckmire's Choking Vines" },
		{ q = 92010, name = "WANTED: Slewstalk's Stalks" },
		{ q = 91982, name = "WANTED: Toadshade's Petals" },
	} },
	{ name = "The Singularity", faction = 2699, entries = {
		{ q = 90962, name = "Stormarion Assault", always = true },
		{ q = 94581, name = "Stand Your Ground" },
		{ q = 92636, name = "Predaxas" },
		{ q = 94790, name = "Research Console: Exploring the Void", always = true },
		{ q = 91700, name = "Darkness Unmade" },
		{ q = 86810, name = "Harvesting the Void" },
		{ q = 92407, name = "Hidey-Hole" },
	} },
	{ name = "Slayer's Duellum", faction = 2770, entries = {
		{ q = 89354, name = "Preparing for Battle", always = true },
	} },
}

-- Catégorie dynamique (Plumber : DynamicQuestMaps / DynamicQuestDataProvider, ActivityUtil.lua) :
-- quêtes répétables, méta et missions proposées sur la carte de Lune-d'Argent, trouvées par l'API
-- (C_QuestLine.GetAvailableQuestLines, C_TaskQuest.GetQuestsOnMap), plus ces quêtes affichées si le
-- personnage les a en cours (always = toujours affichée). Catégorie au nom de la carte.
ns.DYNAMIC_MAP = 2393
ns.MAP_QUESTS = {
	-- Méta hebdomadaires
	{ q = 98232, name = "Midnight: Vaults of Atal'Utek" }, { q = 93890, name = "Midnight: Abundance" },
	{ q = 93767, name = "Midnight: Arcantina" }, { q = 94457, name = "Midnight: Battlegrounds" },
	{ q = 93909, name = "Midnight: Delves" }, { q = 93911, name = "Midnight: Dungeons" },
	{ q = 93769, name = "Midnight: Housing" }, { q = 96727, name = "Midnight: Offworld Showdowns" },
	{ q = 93910, name = "Midnight: Prey" }, { q = 93912, name = "Midnight: Raid" },
	{ q = 95843, name = "Midnight: Ritual Sites" }, { q = 93889, name = "Midnight: Saltheril's Soiree" },
	{ q = 93892, name = "Midnight: Stormarion Assault" }, { q = 95842, name = "Midnight: Void Assaults" },
	{ q = 93913, name = "Midnight: World Boss" }, { q = 93766, name = "Midnight: World Quests" },
	-- Donjons
	{ q = 93751, name = "Windrunner Spire" }, { q = 93752, name = "Murder Row" },
	{ q = 93753, name = "Magister's Terrace" }, { q = 93754, name = "Maisara Caverns" },
	{ q = 93755, name = "Den of Nalorakk" }, { q = 93756, name = "The Blinding Vale" },
	{ q = 93757, name = "Voidscar Arena" }, { q = 93758, name = "Nexus-Point Xenas" },
	-- JcJ
	{ q = 93423, name = "Sparks of War: Eversong Woods" }, { q = 93424, name = "Sparks of War: Zul'Aman" },
	{ q = 93425, name = "Sparks of War: Harandar" }, { q = 93426, name = "Sparks of War: Voidstorm" },
}
if (select(4, GetBuildInfo()) or 0) >= 120100 then -- 12.1 : traque de Xal'atath, toujours affichée
	table.insert(ns.MAP_QUESTS, 1, { q = 98172, name = "Trailing Xal'atath", always = true })
end
