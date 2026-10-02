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

-- CAMPAGNES (section S) : avancement en chapitres, groupé par extension puis par patch. L'API ne
-- dit pas à quelle extension appartient une campagne et son identifiant n'est publié nulle part :
-- chaque campagne est repérée par quelques quêtes (identifiants repris de BtWQuests, un addon par
-- extension, vérifiés sur Wowhead ; patch = nom du fichier BtWQuests, lancement de l'extension pour
-- les zones), et son identifiant est lu en jeu (C_CampaignInfo.GetCampaignID) ; id = identifiant
-- déjà connu (repris de DataStore / Altoholic), sans recherche. Deux entrées qui donnent la même
-- campagne n'en font qu'une (la première) ; une entrée dont aucune quête n'est une quête de
-- campagne est ignorée. Nom affiché : celui du jeu (traduit), name = repli. Les campagnes en cours
-- hors liste sont affichées dans « Autres campagnes ». Ordre : de la plus ancienne à la plus
-- récente (la dernière trouvée en jeu fait la colonne « Campagne »). Campagnes au sens du jeu
-- (chapitres) : depuis Battle for Azeroth seulement. À COMPLÉTER à chaque patch qui en ajoute une.
local BFA = LE_EXPANSION_BATTLE_FOR_AZEROTH or 7
local SHADOWLANDS = LE_EXPANSION_SHADOWLANDS or 8
local DRAGONFLIGHT = LE_EXPANSION_DRAGONFLIGHT or 9
local TWW = LE_EXPANSION_WAR_WITHIN or 10
local MIDNIGHT = LE_EXPANSION_MIDNIGHT or 11
ns.CAMPAIGNS = {
	-- Battle for Azeroth (campagne de guerre par faction)
	{ expansion = BFA, patch = "8.0", name = "War Campaign (Alliance)", quests = { 52544, 53332, 51201 } },
	{ expansion = BFA, patch = "8.0", name = "War Campaign (Horde)", quests = { 52746, 53333, 51435 } },
	{ expansion = BFA, patch = "8.1", name = "Tides of Vengeance (Alliance)", quests = { 53888, 54183 } },
	{ expansion = BFA, patch = "8.1", name = "Tides of Vengeance (Horde)", quests = { 53856, 54165 } },
	{ expansion = BFA, patch = "8.1.5", name = "My Brother's Keeper", quests = { 55033, 55087 } },
	{ expansion = BFA, patch = "8.1.5", name = "Righting Wrongs", quests = { 54754, 55124, 54097 } },
	{ expansion = BFA, patch = "8.2", name = "Welcome to Nazjatar (Alliance)", quests = { 56043, 55095 } },
	{ expansion = BFA, patch = "8.2", name = "Welcome to Nazjatar (Horde)", quests = { 56044, 55054 } },
	{ expansion = BFA, patch = "8.2", name = "The Legend of Mechagon", quests = { 54088, 55040, 55646 } },
	{ expansion = BFA, patch = "8.2", name = "Harnessing the Power", quests = { 55053, 55533 } },
	{ expansion = BFA, patch = "8.2.5", name = "The Price of Victory (Alliance)", quests = { 56719, 56979 } },
	{ expansion = BFA, patch = "8.2.5", name = "The Price of Victory (Horde)", quests = { 57088, 56833, 57147 } },
	{ expansion = BFA, patch = "8.3", name = "Visions of N'Zoth", quests = { 58498, 56209, 57220 } },
	-- Shadowlands
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Into the Maw", quests = { 61874, 59751, 60129 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Bastion", quests = { 59774, 57102, 57710 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Maldraxxus", quests = { 61107, 57386, 58351 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Ardenweald", quests = { 60763, 60341, 60624 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Revendreth", quests = { 57026, 57007, 58654 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Kyrian", id = 119 },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Necrolord", id = 115 },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Night Fae", id = 117 },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Venthyr", id = 113 },
	{ expansion = SHADOWLANDS, patch = "9.1", name = "Chains of Domination", id = 138 },
	{ expansion = SHADOWLANDS, patch = "9.2", name = "Secrets of the First Ones", id = 158 },
	{ expansion = SHADOWLANDS, patch = "9.2.5", name = "Knights of Blood", quests = { 65652, 63480 } },
	-- Dragonflight
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Dracthyr Awaken", quests = { 64865, 64863 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "The Waking Shores", quests = { 65437, 65989, 66115 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Ohn'ahran Plains", quests = { 65779, 66017 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "The Azure Span", quests = { 65686, 65864 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Thaldraszus", quests = { 66159, 66080 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Friend of the Dragon Isles", id = 190 },
	{ expansion = DRAGONFLIGHT, patch = "10.0.7", name = "Return to the Reach", quests = { 73076, 73157, 72592 } },
	{ expansion = DRAGONFLIGHT, patch = "10.1", name = "Embers of Neltharion", id = 203 },
	{ expansion = DRAGONFLIGHT, patch = "10.1.5", name = "Fractures in Time", quests = { 76140, 76141 } },
	{ expansion = DRAGONFLIGHT, patch = "10.1.7", name = "Reconciliation", quests = { 75919, 77098, 77417 } },
	{ expansion = DRAGONFLIGHT, patch = "10.2", name = "Guardians of the Dream", id = 231 },
	{ expansion = DRAGONFLIGHT, patch = "10.2.5", name = "Seeds of Renewal", quests = { 78863, 78865 } },
	{ expansion = DRAGONFLIGHT, patch = "10.2.7", name = "Hunt for the Harbinger", quests = { 81654, 79010 } },
	-- The War Within
	{ expansion = TWW, patch = "11.0", name = "Isle of Dorn", quests = { 78531, 78530, 78468 } },
	{ expansion = TWW, patch = "11.0", name = "The Ringing Deeps", quests = { 78555, 78557, 78685 } },
	{ expansion = TWW, patch = "11.0", name = "Hallowfall", quests = { 78658, 78659, 78929 } },
	{ expansion = TWW, patch = "11.0", name = "Azj-Kahet", quests = { 78350, 78384, 80399 } },
	{ expansion = TWW, patch = "11.0", name = "Against the Current", quests = { 79333, 79328, 81914 } },
	{ expansion = TWW, patch = "11.0", name = "To Kill a Queen", quests = { 82124, 82125 } },
	{ expansion = TWW, patch = "11.0.7", name = "Siren Isle", quests = { 84720, 84940, 82692 } },
	{ expansion = TWW, patch = "11.1", name = "Undermine", quests = { 83139, 83140, 83109 } },
	{ expansion = TWW, patch = "11.1.7", name = "Rise of the Red Dawn", quests = { 84638, 84639 } },
	{ expansion = TWW, patch = "11.1.7", name = "Arcane Desolation", quests = { 83031, 83499 } },
	{ expansion = TWW, patch = "11.2", name = "K'aresh", quests = { 84957, 85003, 85961 } },
	{ expansion = TWW, patch = "11.2.7", name = "Visions of a Shadowed Sun", quests = { 84996, 84997, 85804 } },
	-- Midnight
	{ expansion = MIDNIGHT, patch = "12.0", name = "The Light's Summons", quests = { 86769, 86770, 86805 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "Eversong Woods", quests = { 86733, 86734, 86637 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "Zul'Aman", quests = { 86708, 86710, 86683 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "Harandar", quests = { 86899, 86900, 86883 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "Arator's Journey", quests = { 86837, 86838, 86822 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "Voidstorm", quests = { 86543, 86549, 86509 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "The War of Light and Shadow", quests = { 88696, 88697, 90876 } },
	{ expansion = MIDNIGHT, patch = "12.1", name = "The Curse of Ula'tek", quests = { 92895, 92899, 92900 } },
}

-- Quêtes de proie de la Traque et leur difficulté (1 Normal, 2 Difficile, 3 Cauchemar), reprises
-- de Plumber (Modules/Shared/SharedData.lua : PreyQuestData) : nombre de traques faites cette
-- semaine par difficulté (4 par difficulté et par semaine). À METTRE À JOUR avec Plumber.
ns.PREY_QUESTS = {
	[91095] = 1, [91096] = 1, [91097] = 1, [91098] = 1, [91099] = 1, [91100] = 1, [91101] = 1, [91102] = 1,
	[91103] = 1, [91104] = 1, [91105] = 1, [91106] = 1, [91107] = 1, [91108] = 1, [91109] = 1, [91110] = 1,
	[91111] = 1, [91112] = 1, [91113] = 1, [91114] = 1, [91115] = 1, [91116] = 1, [91117] = 1, [91118] = 1,
	[91119] = 1, [91120] = 1, [91121] = 1, [91122] = 1, [91123] = 1, [91124] = 1, [91210] = 2, [91212] = 2,
	[91214] = 2, [91216] = 2, [91218] = 2, [91220] = 2, [91222] = 2, [91224] = 2, [91226] = 2, [91228] = 2,
	[91230] = 2, [91232] = 2, [91234] = 2, [91236] = 2, [91238] = 2, [91240] = 2, [91242] = 2, [91243] = 2,
	[91244] = 2, [91245] = 2, [91246] = 2, [91247] = 2, [91248] = 2, [91249] = 2, [91250] = 2, [91251] = 2,
	[91252] = 2, [91253] = 2, [91254] = 2, [91255] = 2, [91211] = 3, [91213] = 3, [91215] = 3, [91217] = 3,
	[91219] = 3, [91221] = 3, [91223] = 3, [91225] = 3, [91227] = 3, [91229] = 3, [91231] = 3, [91233] = 3,
	[91235] = 3, [91237] = 3, [91239] = 3, [91241] = 3, [91256] = 3, [91257] = 3, [91258] = 3, [91259] = 3,
	[91260] = 3, [91261] = 3, [91262] = 3, [91263] = 3, [91264] = 3, [91265] = 3, [91266] = 3, [91267] = 3,
	[91268] = 3, [91269] = 3, [95021] = 3, [95022] = 3, [95023] = 3, [95024] = 3,
}
