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
