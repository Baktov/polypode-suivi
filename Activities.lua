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

-- CAMPAGNES (section S) : avancement en chapitres, groupé par extension puis par patch. Liste tirée
-- du relevé des campagnes du jeu (/poly suivi scan, PolypodeSuiviScan : identifiants, noms,
-- chapitres), classée hors ligne par extension et patch (texture de la campagne, noms des chapitres,
-- BtWQuests) ; les campagnes techniques (rattrapage, tests, « passer l'introduction », didacticiels,
-- conteneurs) en sont écartées. ids = variantes d'une même campagne (Alliance / Horde,
-- congrégations, domaines de classe...) : le personnage suit celle qui lui est ouverte (voir
-- Suivi.lua : CampaignVariant). Nom affiché : celui du jeu (traduit), name = repli. Ordre : de la
-- plus ancienne à la plus récente (la dernière fait la colonne « Campagne »). Les campagnes en
-- cours hors liste sont affichées dans « Autres campagnes ». À METTRE À JOUR à chaque patch qui
-- ajoute une campagne : nouveau relevé, puis consolidation.
local MOP = LE_EXPANSION_MISTS_OF_PANDARIA or 4
local LEGION = LE_EXPANSION_LEGION or 6
local BFA = LE_EXPANSION_BATTLE_FOR_AZEROTH or 7
local SHADOWLANDS = LE_EXPANSION_SHADOWLANDS or 8
local DRAGONFLIGHT = LE_EXPANSION_DRAGONFLIGHT or 9
local TWW = LE_EXPANSION_WAR_WITHIN or 10
local MIDNIGHT = LE_EXPANSION_MIDNIGHT or 11
ns.CAMPAIGNS = {
	-- Mists of Pandaria
	{ expansion = MOP, patch = "5.0", name = "Mists of Pandaria", ids = { 248, 247 } },
	{ expansion = MOP, patch = "5.1", name = "Accostage", ids = { 249, 246 } },
	{ expansion = MOP, patch = "5.2", name = "Le roi-tonnerre", ids = { 250, 251 } },
	{ expansion = MOP, patch = "5.3", name = "Embrasement", ids = { 252 } },
	{ expansion = MOP, patch = "5.4", name = "Le siège d'Orgrimmar", ids = { 253, 254 } },
	-- Legion
	{ expansion = LEGION, patch = "7.0", name = "Azsuna", ids = { 275 } },
	{ expansion = LEGION, patch = "7.0", name = "Val'sharah", ids = { 277 } },
	{ expansion = LEGION, patch = "7.0", name = "Haut-Roc", ids = { 278 } },
	{ expansion = LEGION, patch = "7.0", name = "Tornheim", ids = { 280 } },
	{ expansion = LEGION, patch = "7.0", name = "Domaine de classe",
		ids = { 286, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302 } },
	{ expansion = LEGION, patch = "7.0", name = "Souffrenuit", ids = { 288 } },
	{ expansion = LEGION, patch = "7.1", name = "Insurrection", ids = { 289 } },
	{ expansion = LEGION, patch = "7.2", name = "Campagne du Déclin de la Légion", ids = { 290 } },
	{ expansion = LEGION, patch = "7.3", name = "Ombres d'Argus", ids = { 291 } },
	{ expansion = LEGION, patch = "Remix", name = "Legion Remix", ids = { 303 } },
	-- Battle for Azeroth
	{ expansion = BFA, patch = "8.0", name = "Battle for Azeroth", ids = { 215, 226 } },
	{ expansion = BFA, patch = "8.0", name = "Campagne militaire", ids = { 216, 225, 1, 2 } },
	{ expansion = BFA, patch = "8.2", name = "Nazjatar", ids = { 217, 223 } },
	{ expansion = BFA, patch = "8.2", name = "Mécagone", ids = { 218, 222 } },
	{ expansion = BFA, patch = "8.3", name = "Visions de N'Zoth", ids = { 219, 224 } },
	-- Shadowlands
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Campagne de l'Ombreterre", ids = { 125 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Le Bastion", ids = { 114 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Lame du Primat", ids = { 118 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Les bosquets de Sylvarden", ids = { 124 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Le maître de Revendreth", ids = { 111 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Les ténèbres à venir", ids = { 126 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Campagne de congrégation", ids = { 119, 115, 117, 113 } },
	{ expansion = SHADOWLANDS, patch = "9.0", name = "Le fil du destin", ids = { 131 } },
	{ expansion = SHADOWLANDS, patch = "9.1", name = "Chaînes de domination", ids = { 138 } },
	{ expansion = SHADOWLANDS, patch = "9.2", name = "Les secrets des Fondateurs", ids = { 158 } },
	-- Dragonflight
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Dracthyr, éveillez-vous", ids = { 159, 173 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "L'expédition du Dracaret", ids = { 165 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Rivages de l'Éveil", ids = { 169 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Plaines d'Ohn'ahra", ids = { 166 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Travée d'Azur", ids = { 174 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Thaldraszus", ids = { 189 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Dragonflight", ids = { 201 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Roharts iskaariens", ids = { 194 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Expédition du Dracaret", ids = { 197 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Vol draconique vert", ids = { 258 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Le dessein argenté", ids = { 192 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0", name = "Vol draconique", ids = { 256 } },
	{ expansion = DRAGONFLIGHT, patch = "10.0.7", name = "Caveaux de Zskera", ids = { 210 } },
	{ expansion = DRAGONFLIGHT, patch = "10.1", name = "Vol draconique bleu", ids = { 209 } },
	{ expansion = DRAGONFLIGHT, patch = "10.1", name = "Pierres de Vol", ids = { 227 } },
	{ expansion = DRAGONFLIGHT, patch = "10.1", name = "Étincelle d'ombreflamme", ids = { 228 } },
	{ expansion = DRAGONFLIGHT, patch = "10.2", name = "Gardiens du Rêve", ids = { 231 } },
	-- The War Within
	{ expansion = TWW, patch = "11.0", name = "The War Within", ids = { 312 } },
	{ expansion = TWW, patch = "11.0", name = "Chasse à la messagère", ids = { 242 } },
	{ expansion = TWW, patch = "11.0", name = "Visions d'Azeroth", ids = { 235 } },
	{ expansion = TWW, patch = "11.0", name = "Île de Dorn", ids = { 236 } },
	{ expansion = TWW, patch = "11.0", name = "Abîmes Retentissants", ids = { 237 } },
	{ expansion = TWW, patch = "11.0", name = "Les Arathis de Sainte-Chute", ids = { 238 } },
	{ expansion = TWW, patch = "11.0", name = "Azj-Kahet", ids = { 239 } },
	{ expansion = TWW, patch = "11.0", name = "Le Cœur obscur", ids = { 240 } },
	{ expansion = TWW, patch = "11.0.7", name = "Ombres persistantes", ids = { 260 } },
	{ expansion = TWW, patch = "11.1", name = "Terremine", ids = { 264 } },
	{ expansion = TWW, patch = "11.1.7", name = "Le destin du Kirin Tor", ids = { 265 } },
	{ expansion = TWW, patch = "11.1.7", name = "L'Aube rouge se lève", ids = { 267 } },
	{ expansion = TWW, patch = "11.2", name = "Le fil de la dague", ids = { 271 } },
	{ expansion = TWW, patch = "11.2", name = "Succession écologique", ids = { 283 } },
	{ expansion = TWW, patch = "11.2.7", name = "Visions d'un soleil occulté", ids = { 269 } },
	-- Midnight
	{ expansion = MIDNIGHT, patch = "12.0", name = "Midnight", ids = { 270 } },
	{ expansion = MIDNIGHT, patch = "12.0", name = "La guerre de l'Ombre et de la Lumière", ids = { 284 } },
	{ expansion = MIDNIGHT, patch = "12.0.7", name = "Le feuillet renforcé", ids = { 380 } },
	{ expansion = MIDNIGHT, patch = "12.0.7", name = "L'Omnium de Haut-Soleil", ids = { 381 } },
	{ expansion = MIDNIGHT, patch = "12.1", name = "L'appel du Vide", ids = { 333 } },
	{ expansion = MIDNIGHT, patch = "12.1", name = "La malédiction d'Ula'tek", ids = { 324, 332 } },
}

-- Campagnes du relevé écartées à la consolidation (rattrapage, tests, « passer l'introduction »,
-- didacticiels, conteneurs, doublons techniques). Avec ns.CAMPAIGNS, elles forment les campagnes
-- connues : une autre campagne présente dans le jeu fait apparaître, pour l'auteur seulement, le
-- bouton « Nouvelle campagne » de la fenêtre Suivi (relevé à refaire puis consolider).
ns.CAMPAIGNS_IGNORED = {
	3, 130, 133, 134, 135, 136, 137, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 153,
	154, 155, 156, 157, 160, 161, 162, 163, 164, 167, 168, 190, 191, 193, 198, 199, 200, 203, 206, 207,
	208, 212, 213, 214, 221, 229, 230, 233, 234, 241, 257, 261, 262, 263, 266, 268, 273, 274, 276, 279,
	281, 285, 287, 311, 313, 314, 315, 316, 318, 319, 320, 321, 322, 323, 328, 334, 335, 336, 337, 345,
	346, 352, 357, 358, 359, 382,
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
