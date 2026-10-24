-- Polypode Suivi: Grid — fenêtre « Grille » : personnages par compte (onglet Comptes) et par race / classe (onglet Matrice)

local _, ns = ...
local P = Polypode
local L = ns.L

-- FENÊTRE « GRILLE » (bouton « Grille » de la fenêtre Suivi, ns.ToggleGrid) :
--   Comptes — une ligne par personnage seul ou par équipe de Polypode (2 membres et plus, chaque
--     personnage dans une seule équipe : la plus grande), une colonne par compte WoW (nom donné
--     dans Polypode, P.GetCharacterAccount ; ordre et nombre réglés dans les options), à gauche
--     les métiers (option ; nom de l'équipe pour une ligne d'équipe) et le niveau (« niveau / ilvl » au niveau maximum). Trois blocs :
--     Solo, Multi 2/3, Multi 4/5/+.
--   Matrice — races en lignes groupées par faction, classes en colonnes groupées par armure
--     (icônes ; RACES sur Retail, FOREVER_RACES sur WoW Forever ; combinaisons impossibles presque
--     invisibles), une ligne par case (personnage le plus haut et « +n », coin doré au niveau
--     maximum), seulement les races jouées sauf « Toutes les races » ; en bas, une section
--     repliable de lignes libres (libellé et texte par classe) qu'on ajoute, renomme et supprime.
-- Onglet Comptes : personnage au niveau maximum en rouge. Données : section G de Suivi (classe, race,
-- niveau, ilvl, métiers), repli sur le roster de Polypode (classe, niveau).
-- RÉGLAGES (PolypodeSuiviGrid, fichier de compte, communs à tous les personnages) : count =
-- nombre de colonnes de comptes (nil = automatique), columns[i] = compte de la colonne i (vide =
-- automatique), professions = colonnes de métiers, rows = lignes libres { label, cells =
-- { [classe] = texte } }, version = heure serveur de la dernière modification. Synchronisés entre
-- clients connectés (le plus récent l'emporte) : SUIVIGRID:token:version:flag:k=v,... (flag N =
-- premier fragment, qui remplace tout ; + = suite), envoyé à chaque rencontre et 1 s après un
-- changement.

local IS_RETAIL = (tonumber((select(4, GetBuildInfo()))) or 0) >= 100000
local MAX_ACCOUNTS = 10
local SEND_DELAY = 1
local MIN_WIDTH, MIN_HEIGHT = 700, 300
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 1200, 700
local LINE_HEIGHT, CELL_PAD, GAP = 13, 4, 1
local FIXED_WIDTH = 90 -- colonnes Métier 1, Métier 2, Niveau
local RACE_WIDTH = 150 -- colonne des races (Matrice : icône et nom)
local CLASS_WIDTH = 76 -- colonnes de classes (Matrice : largeur fixe, un nom et « +n »)
local MIN_FLEX = 70 -- largeur minimale d'une colonne de compte
local OTHER_ACCOUNT = "\1autres" -- colonne des personnages sans compte affiché

-- Couleurs de fond des cases.
local BG_EMPTY = { 0.05, 0.05, 0.05, 0.9 }
local BG_FILLED = { 0.14, 0.14, 0.14, 0.95 }
local BG_HEADER = { 0.45, 0.45, 0.45, 1 }
local BG_MAX_LEVEL = { 0.75, 0.08, 0.08, 1 } -- personnage au niveau maximum
local BG_FREE_LABEL = { 0.25, 0.25, 0.25, 1 }
local BG_ADD = { 0.1, 0.25, 0.4, 1 }
local FACTION_BG = { A = { 0.2, 0.4, 0.7, 1 }, N = { 0.05, 0.45, 0.2, 1 }, H = { 0.6, 0.08, 0.08, 1 } }
-- Matrice : ce qui existe ressort, le reste s'efface (impossible presque invisible, vide possible
-- gris foncé, personnage teinté de la couleur de sa classe, niveau maximum = coin doré).
local BG_M_IMPOSSIBLE = { 0, 0, 0, 0.3 }
local BG_M_EMPTY = { 0.1, 0.1, 0.1, 0.9 }
local BG_M_HEADER = { 0.16, 0.16, 0.16, 1 }
local BG_M_LABEL = { 0.12, 0.12, 0.12, 1 }
local BG_M_GROUP = { 0.07, 0.07, 0.07, 1 }
local MAX_MARK = { 1, 0.82, 0, 1 }
-- Types d'armure (clés de ARMOR_BG et de CLASSES) affichés dans la langue choisie.
local ARMOR_LABELS = { Plaque = L["Plaque"], Maille = L["Maille"], Tissu = L["Tissu"], Cuir = L["Cuir"] }
local ARMOR_BG = {
	Plaque = { 0.75, 0.1, 0.1, 1 }, Maille = { 0.25, 0.45, 0.15, 1 },
	Tissu = { 0.2, 0.55, 0.9, 1 }, Cuir = { 0.5, 0.27, 0.05, 1 },
}

-- Classes, dans l'ordre des colonnes : fichier, armure, nom de repli.
local CLASSES = {
	{ "WARRIOR", "Plaque", "Guerrier" }, { "HUNTER", "Maille", "Chasseur" }, { "MAGE", "Tissu", "Mage" },
	{ "ROGUE", "Cuir", "Voleur" }, { "PRIEST", "Tissu", "Prêtre" }, { "WARLOCK", "Tissu", "Démoniste" },
	{ "PALADIN", "Plaque", "Paladin" }, { "DRUID", "Cuir", "Druide" }, { "SHAMAN", "Maille", "Chaman" },
	{ "MONK", "Cuir", "Moine" }, { "DEMONHUNTER", "Cuir", "Chasseur de démons" },
	{ "DEATHKNIGHT", "Plaque", "Chevalier de la mort" }, { "EVOKER", "Maille", "Évocateur" },
}

-- Races (fichier de UnitRace), dans l'ordre des lignes : fichier, nom de repli, faction (A / N / H),
-- classes jouables dans l'ordre de CLASSES (x = possible, - = impossible ; Midnight 12.0). À
-- mettre à jour quand une combinaison s'ouvre ; une case où se trouve un personnage est toujours
-- affichée possible, et une race inconnue ajoute sa ligne.
local RACES = {
	{ "Human", "Humain", "A", "xxxxxxx--x-x-" },
	{ "KulTiran", "Kultirassien", "A", "xxxxxx-xxx-x-" },
	{ "Dwarf", "Nain", "A", "xxxxxxx-xx-x-" },
	{ "DarkIronDwarf", "Nain sombrefer", "A", "xxxxxxx-xx-x-" },
	{ "NightElf", "Elfe de la nuit", "A", "xxxxxx-x-xxx-" },
	{ "VoidElf", "Elfe du Vide", "A", "xxxxxx---xxx-" },
	{ "Gnome", "Gnome", "A", "xxxxxx---x-x-" },
	{ "Mechagnome", "Mécagnome", "A", "xxxxxx---x-x-" },
	{ "Draenei", "Draeneï", "A", "xxxxxxx-xx-x-" },
	{ "LightforgedDraenei", "Draeneï sancteforge", "A", "xxxxxxx--x-x-" },
	{ "Worgen", "Worgen", "A", "xxxxxx-x-x-x-" },
	{ "Pandaren", "Pandaren", "N", "xxxxxx--xx-x-" },
	{ "Dracthyr", "Dracthyr", "N", "xxxxxx------x" },
	{ "EarthenDwarf", "Terrestre", "N", "xxxxxxx-xx---" },
	{ "Harronir", "Haranir", "N", "xxxxxx-xxx---" },
	{ "Orc", "Orc", "H", "xxxxxx--xx-x-" },
	{ "MagharOrc", "Orc mag'har", "H", "xxxxxx--xx-x-" },
	{ "Scourge", "Mort-vivant", "H", "xxxxxx---x-x-" },
	{ "Tauren", "Tauren", "H", "xxxxxxxxxx-x-" },
	{ "HighmountainTauren", "Tauren de Haut-Roc", "H", "xxxxxx-xxx-x-" },
	{ "Troll", "Troll", "H", "xxxxxx-xxx-x-" },
	{ "ZandalariTroll", "Troll zandalari", "H", "xxxxxxxxxx-x-" },
	{ "BloodElf", "Elfe de sang", "H", "xxxxxxx--xxx-" },
	{ "Nightborne", "Sacrenuit", "H", "xxxxxx---x-x-" },
	{ "Goblin", "Gobelin", "H", "xxxxxx--xx-x-" },
	{ "Vulpera", "Vulpérin", "H", "xxxxxx--xx-x-" },
}

-- Noms affichés des races (langue choisie) ; le nom de RACES reste celui de la comparaison avec le
-- nom relevé en jeu (RaceKey). Éolides de WoW Forever : noms du client de Blizzard (italien et
-- portugais : noms anglais, pas de traduction connue).
local RACE_LABELS = {
	Human = L["Humain"], KulTiran = L["Kultirassien"], Dwarf = L["Nain"], DarkIronDwarf = L["Nain sombrefer"],
	NightElf = L["Elfe de la nuit"], VoidElf = L["Elfe du Vide"], Gnome = L["Gnome"], Mechagnome = L["Mécagnome"],
	Draenei = L["Draeneï"], LightforgedDraenei = L["Draeneï sancteforge"], Worgen = L["Worgen"], Pandaren = L["Pandaren"],
	Dracthyr = L["Dracthyr"], EarthenDwarf = L["Terrestre"], Harronir = L["Haranir"], Orc = L["Orc"], MagharOrc = L["Orc mag'har"],
	Scourge = L["Mort-vivant"], Tauren = L["Tauren"], HighmountainTauren = L["Tauren de Haut-Roc"], Troll = L["Troll"],
	ZandalariTroll = L["Troll zandalari"], BloodElf = L["Elfe de sang"], Nightborne = L["Sacrenuit"], Goblin = L["Gobelin"],
	Vulpera = L["Vulpérin"],
	["?eolide-ordre"] = L["Éolide de l'Ordre suprême"], ["?eolide-sculpte"] = L["Éolide des Sculpte-vents"],
}

-- WoW Forever (contenu Vanilla) : neuf classes, dix races ; combinaisons dans l'ordre de
-- FOREVER_CLASSES (tableaux de l'utilisateur). Les deux races Éolides n'ont pas de fichier connu
-- (absent du code de Blizzard) : reconnues par leur nom traduit (RaceKey), d'où la clé « ? ».
local FOREVER_CLASSES = { "WARRIOR", "HUNTER", "MAGE", "ROGUE", "PRIEST", "WARLOCK", "PALADIN", "DRUID", "SHAMAN" }
local FOREVER_RACES = {
	{ "Human", "Humain", "A", "xxxxxxx--" },
	{ "Dwarf", "Nain", "A", "xx-xx-x-x" },
	{ "NightElf", "Elfe de la nuit", "A", "xx-xx--x-" },
	{ "Gnome", "Gnome", "A", "x-xxxx---" },
	{ "?eolide-ordre", "Éolide de l'Ordre suprême", "A", "xxxx---x-" },
	{ "Orc", "Orc", "H", "xxxx-x--x" },
	{ "Tauren", "Tauren", "H", "xx-----xx" },
	{ "Troll", "Troll", "H", "xxxxxx--x" },
	{ "Scourge", "Mort-vivant", "H", "x-xxxxx--" },
	{ "?eolide-sculpte", "Éolide des Sculpte-vents", "H", "xx-x---xx" },
}

-- Noms des Éolides dans les autres langues du client (formes féminines comprises), pour les
-- reconnaître quel que soit le client.
local FOREVER_RACE_NAMES = {
	["?eolide-ordre"] = { "High Order Skyborne", "Skyborne High Order", "Himmelsgeborener des Hohen Ordens",
		"Himmelsgeborene des Hohen Ordens", "Cielonato de la Orden Eminente", "Cielonata de la Orden Eminente" },
	["?eolide-sculpte"] = { "Éolide sculpte-vents", "Windshaper Skyborne", "Skyborne Windshaper",
		"Himmelsgeborener der Windformer", "Himmelsgeborene der Windformer", "Himmelsgeborene Windformer",
		"Cielonato Formavientos", "Cielonata Formavientos" },
}

-- Classes et races de la matrice selon le jeu.
local MATRIX_CLASSES, MATRIX_RACES = CLASSES, RACES
if not IS_RETAIL then
	MATRIX_CLASSES = {}
	for _, file in ipairs(FOREVER_CLASSES) do
		for _, class in ipairs(CLASSES) do
			if class[1] == file then
				MATRIX_CLASSES[#MATRIX_CLASSES + 1] = class
			end
		end
	end
	MATRIX_RACES = FOREVER_RACES
end

-- Colonnes de la matrice : classes groupées par armure (ARMOR_ORDER), dans l'ordre de
-- MATRIX_CLASSES dans un groupe ; index = position dans MATRIX_CLASSES (chaînes « x/- » des races).
local ARMOR_ORDER = { "Tissu", "Cuir", "Maille", "Plaque" }
local ARMOR_ICONS = {
	Tissu = "Interface\\Icons\\INV_Chest_Cloth_03", Cuir = "Interface\\Icons\\INV_Chest_Leather_01",
	Maille = "Interface\\Icons\\INV_Chest_Chain_05", Plaque = "Interface\\Icons\\INV_Chest_Plate03",
}
local MATRIX_COLUMNS = {}
for _, armor in ipairs(ARMOR_ORDER) do
	for index, class in ipairs(MATRIX_CLASSES) do
		if class[2] == armor then
			MATRIX_COLUMNS[#MATRIX_COLUMNS + 1] = { class = class, index = index }
		end
	end
end

-- Formes féminines des races (client français) : les noms du jeu (C_CreatureInfo.GetRaceInfo) sont
-- au masculin, et Polypode Data n'enregistrait que le nom traduit avant sa version 2.4.0 (rf).
local FEMININE_RACES = {
	["Humaine"] = "Human", ["Kultirassienne"] = "KulTiran", ["Naine"] = "Dwarf",
	["Naine sombrefer"] = "DarkIronDwarf", ["Pandarène"] = "Pandaren", ["Orque"] = "Orc",
	["Orque mag'har"] = "MagharOrc", ["Morte-vivante"] = "Scourge", ["Mort-vivante"] = "Scourge",
	["Taurène"] = "Tauren", ["Taurène de Haut-Roc"] = "HighmountainTauren", ["Trollesse"] = "Troll",
	["Trollesse zandalari"] = "ZandalariTroll", ["Gobeline"] = "Goblin", ["Vulpérine"] = "Vulpera",
}

-- Icônes en ligne (|A atlas|a), ou nil si l'atlas manque dans ce client.
local function AtlasMarkup(atlas, size)
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
		return ("|A:%s:%d:%d|a"):format(atlas, size, size)
	end
end

local function ClassIcon(classFile)
	return classFile and AtlasMarkup("classicon-" .. classFile:lower(), 16)
end

-- Icône de race (écran de création de personnage) : nom d'atlas tiré du fichier de race.
local RACE_ATLAS_NAMES = {
	Scourge = "undead", HighmountainTauren = "highmountain", LightforgedDraenei = "lightforged",
	ZandalariTroll = "zandalari", Harronir = "haranir", EarthenDwarf = "earthen",
}
local function RaceIcon(raceFile)
	if not raceFile or raceFile:find("^%?") then
		return nil
	end
	local name = RACE_ATLAS_NAMES[raceFile] or raceFile:lower()
	return AtlasMarkup("raceicon128-" .. name .. "-male", 16) or AtlasMarkup("raceicon-" .. name .. "-male", 16)
end

-- Nom de race comparable : minuscules, sans espaces, tirets ni apostrophes.
local function NormalizeRaceName(name)
	return (name:gsub("’", "'"):lower():gsub("[%s%-']", ""))
end

local frame, scroll, canvas, editor
local cells = {} -- cases réutilisées
local sendPending, receivingVersion

-- RÉGLAGES -------------------------------------------------------------------------------

local function Grid()
	PolypodeSuiviGrid = PolypodeSuiviGrid or {}
	local grid = PolypodeSuiviGrid
	grid.columns = grid.columns or {}
	grid.rows = grid.rows or {}
	if grid.professions == nil then
		grid.professions = true
	end
	return grid
end

local function WindowSettings()
	return PolypodeSuiviDB or {}
end

local function AccountLabels()
	return P.GetAccountLabels and P.GetAccountLabels() or {}
end

-- Nombre de colonnes de comptes : réglé, sinon tous les comptes connus (10 au plus).
local function AccountCount()
	local count = Grid().count
	if count then
		return math.max(1, math.min(MAX_ACCOUNTS, count))
	end
	return math.max(1, math.min(MAX_ACCOUNTS, #AccountLabels()))
end

-- Comptes des colonnes, dans l'ordre : ceux choisis, les colonnes « automatique » prenant les
-- comptes restants par ordre alphabétique.
local function AccountColumns()
	local labels, chosen = AccountLabels(), Grid().columns
	local count = AccountCount()
	local result, used = {}, {}
	for i = 1, count do
		local label = chosen[i]
		if label and label ~= "" and not used[label] then
			result[i], used[label] = label, true
		end
	end
	local nextLabel = 1
	for i = 1, count do
		if not result[i] then
			while labels[nextLabel] and used[labels[nextLabel]] do
				nextLabel = nextLabel + 1
			end
			if labels[nextLabel] then
				result[i], used[labels[nextLabel]] = labels[nextLabel], true
			end
		end
	end
	local list = {}
	for i = 1, count do
		if result[i] then
			list[#list + 1] = result[i]
		end
	end
	return list
end

-- SYNCHRO DES RÉGLAGES ----------------------------------------------------------------------

local function Escape(text)
	return (tostring(text or ""):gsub("%%", "%%25"):gsub(",", "%%2C"))
end

local function Unescape(text)
	return (tostring(text or ""):gsub("%%2C", ","):gsub("%%25", "%%"))
end

local function GridItems()
	local grid = Grid()
	local items = { "n=" .. (grid.count or ""), "p=" .. (grid.professions and 1 or 0) }
	for i = 1, MAX_ACCOUNTS do
		if grid.columns[i] and grid.columns[i] ~= "" then
			items[#items + 1] = "a" .. i .. "=" .. Escape(grid.columns[i])
		end
	end
	for r, row in ipairs(grid.rows) do
		items[#items + 1] = "r" .. r .. "=" .. Escape(row.label)
		for classFile, text in pairs(row.cells or {}) do
			if text ~= "" then
				items[#items + 1] = "r" .. r .. "." .. classFile .. "=" .. Escape(text)
			end
		end
	end
	return items
end

-- Envoie les réglages (fragmentés) à target, sinon aux clients connectés.
local function SendGrid(target)
	local grid = Grid()
	local token = P.GetTeamToken and P.GetTeamToken()
	if not (grid.version and token and P.WhisperOnline) then
		return -- jamais modifiés : rien à transmettre
	end
	local header = string.format("SUIVIGRID:%s:%d:N:", token, grid.version)
	local budget = (P.MAX_MESSAGE_LENGTH or 255) - #header
	local chunks, current, used = {}, {}, 0
	for _, item in ipairs(GridItems()) do
		local cost = #item + (#current > 0 and 1 or 0)
		if #current > 0 and used + cost > budget then
			chunks[#chunks + 1] = current
			current, used, cost = {}, 0, #item
		end
		current[#current + 1] = item
		used = used + cost
	end
	chunks[#chunks + 1] = current
	for i, chunk in ipairs(chunks) do
		P.WhisperOnline(string.format("SUIVIGRID:%s:%d:%s:%s", token, grid.version, i == 1 and "N" or "+",
			table.concat(chunk, ",")), target)
	end
end

local function FreeRow(index)
	local rows = Grid().rows
	for i = #rows + 1, index do
		rows[i] = { label = "", cells = {} }
	end
	rows[index].cells = rows[index].cells or {}
	return rows[index]
end

local function ApplyItem(k, v)
	local grid = Grid()
	if k == "n" then
		grid.count = tonumber(v)
	elseif k == "p" then
		grid.professions = v == "1"
	elseif k:match("^a%d+$") then
		grid.columns[tonumber(k:sub(2))] = Unescape(v)
	elseif k:match("^r%d+%.") then
		local index, classFile = k:match("^r(%d+)%.(.+)$")
		FreeRow(tonumber(index)).cells[classFile] = Unescape(v)
	elseif k:match("^r%d+$") then
		FreeRow(tonumber(k:sub(2))).label = Unescape(v)
	end
end

local function OnGridMessage(rest)
	local version, flag, data = strsplit(":", rest or "", 3)
	version = tonumber(version)
	if not version then
		return
	end
	local grid = Grid()
	if flag == "N" then
		if version <= (grid.version or 0) then
			receivingVersion = nil
			return
		end
		-- Plus récent : remplace tous les réglages (même table, sauvegardée).
		grid.count, grid.professions, grid.version = nil, true, version
		wipe(grid.columns)
		wipe(grid.rows)
		receivingVersion = version
	elseif flag ~= "+" or version ~= receivingVersion then
		return
	end
	for pair in (data or ""):gmatch("[^,]+") do
		local k, v = pair:match("^([^=]+)=(.*)$")
		if k then
			ApplyItem(k, v)
		end
	end
	if ns.RefreshGrid then
		ns.RefreshGrid()
	end
end

-- Réglage modifié ici : nouvelle version, envoi groupé aux clients connectés, fenêtre à jour.
local function GridChanged()
	local grid = Grid()
	grid.version = math.max(GetServerTime(), (grid.version or 0) + 1)
	if not sendPending then
		sendPending = true
		C_Timer.After(SEND_DELAY, function()
			sendPending = nil
			SendGrid()
		end)
	end
	ns.RefreshGrid()
end

-- PERSONNAGES ------------------------------------------------------------------------------

local function MaxLevel()
	if GetMaxLevelForPlayerExpansion then
		local ok, level = pcall(GetMaxLevelForPlayerExpansion)
		if ok and level then
			return level
		end
	end
	return MAX_PLAYER_LEVEL
end

local function ClassColorCode(classFile)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	return color and color.colorStr and ("|c" .. color.colorStr) or "|cffffffff"
end

local function ClassName(classFile)
	local names = LOCALIZED_CLASS_NAMES_MALE
	if names and names[classFile] then
		return names[classFile]
	end
	for _, class in ipairs(CLASSES) do
		if class[1] == classFile then
			return class[3]
		end
	end
	return classFile or "?"
end

-- Noms de race traduits (normalisés) → fichier de race : table du jeu (C_CreatureInfo.GetRaceInfo,
-- construite une fois) et correspondances apprises des sections G de Suivi (rn → r : formes
-- féminines comprises). Sert à placer les personnages dont seule la race traduite est connue
-- (Polypode Data).
local gameRaceFiles

local function RaceFilesByName(gSections)
	if not gameRaceFiles then
		gameRaceFiles = {}
		if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
			for raceID = 1, 150 do
				local ok, info = pcall(C_CreatureInfo.GetRaceInfo, raceID)
				if ok and info and info.raceName and info.clientFileString then
					gameRaceFiles[NormalizeRaceName(info.raceName)] = info.clientFileString
				end
			end
		end
	end
	local byName = {}
	for name, file in pairs(gameRaceFiles) do
		byName[name] = file
	end
	for _, g in pairs(gSections) do
		if g.rn and g.r and g.r ~= "" then
			byName[NormalizeRaceName(g.rn)] = g.r
		end
	end
	return byName
end

-- Section d'un personnage gardée par Polypode Data (P.GetCharacterData, Data 2.1.0), ou {}.
local function DataSection(key, section)
	return P.GetCharacterData and P.GetCharacterData(key, section) or {}
end

-- Nom d'un métier de Polypode Data (« skillLine/niveau/max/icône/nom »), ou nil.
local function DataProfessionName(value)
	local name = value and value:match("([^/]*)$")
	return name and name ~= "" and name or nil
end

-- Personnages du roster : [clé] = { key, name, class, race, raceName, level, ilvl, profs, account,
-- max }. Sources, de la plus sûre à la moins sûre : section G de Suivi, sections I (identité) et T
-- (métiers) de Polypode Data, roster de Polypode (classe, niveau). Niveau : le plus haut connu.
local function CharacterInfos()
	local infos = {}
	local own = P.GetCharKey()
	local received = ns.GetReceived and ns.GetReceived() or {}
	local maxLevel = MaxLevel()
	local roster = P.GetRoster and P.GetRoster() or {}
	local gSections = {}
	for key in pairs(roster) do
		if key == own and ns.ReadGrid then
			gSections[key] = ns.ReadGrid()
		else
			gSections[key] = received[key] and received[key].sections and received[key].sections.G or {}
		end
	end
	local raceFiles = RaceFilesByName(gSections)
	for key, entry in pairs(roster) do
		local g, identity = gSections[key], DataSection(key, "I")
		local level
		local levels = { g.l, identity.l, entry.level } -- trous possibles : pas d'ipairs
		for i = 1, 3 do
			local value = tonumber(levels[i])
			if value and value > 0 and (not level or value > level) then
				level = value
			end
		end
		local profs = {}
		local names = { g.m1, g.m2 }
		if not (g.m1 or g.m2) then
			local trades = DataSection(key, "T")
			names = { DataProfessionName(trades.p1), DataProfessionName(trades.p2) }
		end
		for _, name in pairs(names) do
			if name and name ~= "" then
				profs[#profs + 1] = name
			end
		end
		table.sort(profs)
		local raceName = g.rn or (identity.r ~= "" and identity.r or nil)
		-- Fichier de race : section G, puis Polypode Data (rf, 2.4.0), puis nom traduit (table du jeu,
		-- noms appris, formes féminines françaises).
		local race = (g.r and g.r ~= "") and g.r or (identity.rf and identity.rf ~= "" and identity.rf)
			or (raceName and (raceFiles[NormalizeRaceName(raceName)] or FEMININE_RACES[raceName])) or nil
		local class = (g.c and g.c ~= "") and g.c or (identity.c and identity.c ~= "" and identity.c) or entry.class
		infos[key] = {
			key = key,
			name = P.GetDisplayName and P.GetDisplayName(key) or key:match("^[^-]+"),
			class = class,
			race = race,
			raceName = raceName,
			level = level,
			ilvl = tonumber(g.i) or tonumber(identity.i),
			profs = profs,
			account = P.GetCharacterAccount and P.GetCharacterAccount(key),
			max = level ~= nil and maxLevel ~= nil and level >= maxLevel,
		}
	end
	return infos
end

local function SortKeys(keys, infos)
	table.sort(keys, function(a, b)
		local ia, ib = infos[a], infos[b]
		if ia.max ~= ib.max then
			return ia.max
		end
		if (ia.level or 0) ~= (ib.level or 0) then
			return (ia.level or 0) > (ib.level or 0)
		end
		return ia.name < ib.name
	end)
	return keys
end

-- Infobulle d'un personnage.
local function CharacterTooltip(info, team)
	GameTooltip:AddLine(ClassColorCode(info.class) .. info.name .. "|r")
	GameTooltip:AddDoubleLine(L["Compte"], info.account or L["non renseigné"], 0.6, 0.6, 0.6, 1, 1, 1)
	local other = info.max and 0.3 or 1 -- niveau maximum en rouge
	GameTooltip:AddDoubleLine(L["Niveau"], info.level and tostring(info.level) or "?", 0.6, 0.6, 0.6, 1, other, other)
	if info.ilvl then
		GameTooltip:AddDoubleLine(L["Niveau d'objet"], tostring(info.ilvl), 0.6, 0.6, 0.6, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine(L["Classe"], ClassName(info.class), 0.6, 0.6, 0.6, 1, 1, 1)
	if info.raceName or info.race then
		GameTooltip:AddDoubleLine(L["Race"], info.raceName or info.race, 0.6, 0.6, 0.6, 1, 1, 1)
	end
	GameTooltip:AddDoubleLine(L["Métiers"], #info.profs > 0 and table.concat(info.profs, ", ") or L["aucun connu"],
		0.6, 0.6, 0.6, 1, 1, 1)
	if team then
		GameTooltip:AddDoubleLine(L["Équipe"], team, 0.6, 0.6, 0.6, 1, 1, 1)
	end
	if not (info.race or info.raceName) then
		GameTooltip:AddLine(L["Race, ilvl et métiers connus après sa prochaine connexion (avec Polypode Suivi à jour, "
			.. "ou Polypode Data)."], 0.6, 0.6, 0.6, true)
	end
end

-- Texte d'une case : noms des personnages (couleur de classe, blanc au niveau maximum).
local function NamesText(keys, infos)
	local lines = {}
	for _, key in ipairs(keys) do
		local info = infos[key]
		lines[#lines + 1] = (info.max and "|cffffffff" or ClassColorCode(info.class)) .. info.name .. "|r"
	end
	return table.concat(lines, "\n")
end

local function AnyMax(keys, infos)
	for _, key in ipairs(keys) do
		if infos[key].max then
			return true
		end
	end
	return false
end

local function NamesTooltip(keys, infos, team)
	return function()
		for i, key in ipairs(keys) do
			if i > 1 then
				GameTooltip:AddLine(" ")
			end
			CharacterTooltip(infos[key], team)
		end
	end
end

-- ONGLET COMPTES ---------------------------------------------------------------------------

-- Texte des métiers d'une ligne : valeurs distinctes de ses personnages, jointes par « / ».
local function DistinctText(keys, infos, index)
	local seen, list = {}, {}
	for _, key in ipairs(keys) do
		local value = infos[key].profs[index]
		if value and not seen[value] then
			seen[value] = true
			list[#list + 1] = value
		end
	end
	return table.concat(list, " / ")
end

-- Niveau d'une ligne : le niveau (ou les niveaux de l'équipe, du plus haut au plus bas) ; « niveau / ilvl »
-- si tous sont au niveau maximum (ilvl le plus bas de l'équipe).
local function LevelText(keys, infos)
	local levels, seen, allMax, minIlvl = {}, {}, true, nil
	for _, key in ipairs(keys) do
		local info = infos[key]
		local level = info.level and tostring(info.level) or "?"
		levels[#levels + 1] = level
		seen[level] = true
		allMax = allMax and info.max
		if info.ilvl then
			minIlvl = math.min(minIlvl or info.ilvl, info.ilvl)
		end
	end
	local distinct = 0
	for _ in pairs(seen) do
		distinct = distinct + 1
	end
	local text = distinct == 1 and levels[1] or table.concat(levels, "/")
	if allMax and minIlvl then
		text = text .. " / " .. minIlvl
	end
	return text, allMax
end

-- Lignes de l'onglet : { title, rows = { { keys, team } } } par bloc (Solo, Multi 2/3, Multi 4/5/+).
local function AccountSections(infos)
	local teams = {}
	for name, team in pairs(P.GetTeams and P.GetTeams() or {}) do
		local members = {}
		for key in pairs(team.members or {}) do
			if infos[key] then
				members[#members + 1] = key
			end
		end
		if #members >= 2 then
			teams[#teams + 1] = { name = name, members = members }
		end
	end
	table.sort(teams, function(a, b)
		if #a.members ~= #b.members then
			return #a.members > #b.members
		end
		return a.name < b.name
	end)
	-- Chaque personnage dans une seule équipe (la plus grande) ; une équipe réduite à un seul
	-- personnage le laisse seul.
	local placed = {}
	local solo, small, large = { title = L["Solo"], rows = {} }, { title = L["Multi 2/3"], rows = {} },
		{ title = L["Multi 4/5/+"], rows = {} }
	for _, team in ipairs(teams) do
		local keys = {}
		for _, key in ipairs(team.members) do
			if not placed[key] then
				keys[#keys + 1] = key
			end
		end
		if #keys >= 2 then
			for _, key in ipairs(keys) do
				placed[key] = true
			end
			local section = #keys >= 4 and large or small
			section.rows[#section.rows + 1] = { keys = SortKeys(keys, infos), team = team.name }
		end
	end
	for key in pairs(infos) do
		if not placed[key] then
			solo.rows[#solo.rows + 1] = { keys = { key } }
		end
	end
	-- Solo : regroupés par métiers (comme le tableau d'origine), puis niveau décroissant, nom.
	local function ProfKey(row)
		local profs = infos[row.keys[1]].profs
		return #profs > 0 and table.concat(profs, "/") or "\255"
	end
	table.sort(solo.rows, function(a, b)
		local pa, pb = ProfKey(a), ProfKey(b)
		if pa ~= pb then
			return pa < pb
		end
		local ia, ib = infos[a.keys[1]], infos[b.keys[1]]
		if (ia.level or 0) ~= (ib.level or 0) then
			return (ia.level or 0) > (ib.level or 0)
		end
		return ia.name < ib.name
	end)
	for _, section in ipairs({ small, large }) do
		table.sort(section.rows, function(a, b)
			if #a.keys ~= #b.keys then
				return #a.keys < #b.keys
			end
			return a.team < b.team
		end)
	end
	return { solo, small, large }
end

local function BuildAccountsGrid()
	local infos = CharacterInfos()
	local accounts = AccountColumns()
	local showProfs = Grid().professions
	local accountIndex = {}
	for i, label in ipairs(accounts) do
		accountIndex[label] = i
	end
	local sections = AccountSections(infos)
	-- Colonne « Autres » : personnages sans compte, ou d'un compte non affiché.
	local needOther = false
	for _, info in pairs(infos) do
		if not (info.account and accountIndex[info.account]) then
			needOther = true
		end
	end
	if needOther then
		accounts[#accounts + 1] = OTHER_ACCOUNT
		accountIndex[OTHER_ACCOUNT] = #accounts
	end

	local columns = {}
	if showProfs then
		columns[#columns + 1] = { width = FIXED_WIDTH }
		columns[#columns + 1] = { width = FIXED_WIDTH }
	end
	columns[#columns + 1] = { width = FIXED_WIDTH }
	local firstAccount = #columns + 1
	for _ = 1, #accounts do
		columns[#columns + 1] = {}
	end

	local rows = {}
	for _, section in ipairs(sections) do
		if #section.rows > 0 then
			local header = {}
			if showProfs then
				header[1] = { text = section.title, bg = BG_HEADER, span = 2, justify = "LEFT" }
				header[3] = { text = L["Niveau"], bg = BG_HEADER }
			else
				header[1] = { text = section.title, bg = BG_HEADER }
			end
			for i, label in ipairs(accounts) do
				header[firstAccount + i - 1] = { text = label == OTHER_ACCOUNT and L["Autres"] or label, bg = BG_HEADER,
					tooltip = label == OTHER_ACCOUNT and function()
						GameTooltip:AddLine(L["Autres"])
						GameTooltip:AddLine(L["Personnages sans compte WoW, ou d'un compte qui n'a pas de colonne "
							.. "(Options > Polypode > Suivi > Grille)."], 1, 1, 1, true)
					end or nil }
			end
			rows[#rows + 1] = { cells = header, header = true }
			local lastProfs
			for _, row in ipairs(section.rows) do
				local cellsOfRow = {}
				if showProfs and row.team then
					-- Multi : nom de l'équipe sur les deux colonnes des métiers.
					cellsOfRow[1] = { text = row.team, span = 2, justify = "LEFT" }
				elseif showProfs then
					local p1, p2 = DistinctText(row.keys, infos, 1), DistinctText(row.keys, infos, 2)
					-- Solo : métiers écrits sur la première ligne de chaque groupe seulement.
					local profs = p1 .. "\1" .. p2
					if profs ~= lastProfs then
						cellsOfRow[1] = { text = p1 }
						cellsOfRow[2] = { text = p2 }
					end
					lastProfs = profs
				end
				local levelText, allMax = LevelText(row.keys, infos)
				cellsOfRow[showProfs and 3 or 1] = {
					text = levelText,
					bg = allMax and BG_MAX_LEVEL or nil,
					tooltip = row.team and function()
						GameTooltip:AddLine(L["Équipe « %s »"]:format(row.team))
						GameTooltip:AddLine(L["%d personnages ; au niveau maximum, niveau d'objet le plus bas de l'équipe."]
							:format(#row.keys), 1, 1, 1, true)
					end or nil,
				}
				local byAccount = {}
				for _, key in ipairs(row.keys) do
					local column = accountIndex[infos[key].account] or accountIndex[OTHER_ACCOUNT]
					byAccount[column] = byAccount[column] or {}
					table.insert(byAccount[column], key)
				end
				for column, keys in pairs(byAccount) do
					cellsOfRow[firstAccount + column - 1] = {
						text = NamesText(keys, infos),
						lines = #keys,
						bg = AnyMax(keys, infos) and BG_MAX_LEVEL or BG_FILLED,
						tooltip = NamesTooltip(keys, infos, row.team),
					}
				end
				rows[#rows + 1] = { cells = cellsOfRow }
			end
		end
	end
	return { columns = columns, rows = rows, empty = L["Aucun personnage dans le roster."] }
end

-- ONGLET MATRICE ---------------------------------------------------------------------------

-- Fond sombre teinté de la couleur d'une classe (case occupée).
local function ClassTint(classFile)
	local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if not color then
		return { 0.18, 0.18, 0.18, 0.95 }
	end
	return { color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.95 }
end

-- En-têtes : une case par armure (sur ses classes, icône et nom), puis les icônes des classes
-- (nom et armure dans l'infobulle ; nom de la classe si l'icône manque).
local function ClassHeaderRows()
	local armorRow, classRow = { [1] = { bg = BG_M_HEADER } }, { [1] = { bg = BG_M_HEADER } }
	local column = 2
	for _, armor in ipairs(ARMOR_ORDER) do
		local count = 0
		for _, entry in ipairs(MATRIX_COLUMNS) do
			if entry.class[2] == armor then
				count = count + 1
			end
		end
		if count > 0 then
			local color = ARMOR_BG[armor]
			armorRow[column] = {
				text = "|T" .. ARMOR_ICONS[armor] .. ":14:14|t " .. ARMOR_LABELS[armor],
				bg = { color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, 1 },
				span = count,
			}
			column = column + count
		end
	end
	for i, entry in ipairs(MATRIX_COLUMNS) do
		local classFile, armor = entry.class[1], entry.class[2]
		classRow[i + 1] = {
			text = ClassIcon(classFile) or ClassName(classFile),
			bg = BG_M_HEADER,
			tooltip = function()
				GameTooltip:AddLine(ClassColorCode(classFile) .. ClassName(classFile) .. "|r")
				GameTooltip:AddLine(ARMOR_LABELS[armor] or armor, 1, 1, 1)
			end,
		}
	end
	return { cells = armorRow, header = true }, { cells = classRow, header = true }
end

-- Ligne de sous-titre sur toute la largeur (faction, lignes libres) ; extra = champs de plus
-- (infobulle, clic).
local function GroupRow(text, count, extra)
	local spec = { text = text, bg = BG_M_GROUP, span = count, justify = "LEFT" }
	for k, v in pairs(extra or {}) do
		spec[k] = v
	end
	return { cells = { [1] = spec }, header = true }
end

local ShowEditor -- défini plus bas (champ de saisie posé sur une case)

local function ConfirmDeleteRow(index)
	local row = Grid().rows[index]
	if not row then
		return
	end
	StaticPopupDialogs.POLYPODE_SUIVI_GRID_DELETE_ROW = StaticPopupDialogs.POLYPODE_SUIVI_GRID_DELETE_ROW or {
		text = L["Supprimer la ligne « %s » de la matrice ?"],
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			table.remove(Grid().rows, data)
			GridChanged()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopup_Show("POLYPODE_SUIVI_GRID_DELETE_ROW", row.label ~= "" and row.label or L["sans nom"], nil, index)
end

-- Toutes les races (combinaisons manquantes comprises) ou seulement celles qui ont un personnage
-- (défaut) : case « Toutes les races » de la fenêtre, PolypodeSuiviDB.gridAllRaces.
local function ShowAllRaces()
	return WindowSettings().gridAllRaces == true
end

-- Groupes de lignes de races : factions de MATRIX_RACES, puis « Autres » (races absentes de la
-- table, race inconnue).
local FACTION_GROUPS = {
	{ "A", FACTION_ALLIANCE or L["Alliance"] }, { "N", L["Neutre"] }, { "H", FACTION_HORDE or L["Horde"] },
}

local function ColorCode(color)
	return ("|cff%02x%02x%02x"):format(math.min(255, math.floor(color[1] * 400)),
		math.min(255, math.floor(color[2] * 400)), math.min(255, math.floor(color[3] * 400)))
end

local function BuildMatrixGrid()
	local infos = CharacterInfos()
	local columns = { { width = RACE_WIDTH } }
	for i = 1, #MATRIX_COLUMNS do
		columns[i + 1] = { width = CLASS_WIDTH }
	end
	-- [race][classe] = { clés } ; races inconnues de MATRIX_RACES ajoutées après, personnages sans
	-- race connue sur une dernière ligne. Race au fichier inconnu : reconnue par son nom traduit.
	local byRace, unknownRaces = {}, {}
	local known, byName = {}, {}
	for _, race in ipairs(MATRIX_RACES) do
		known[race[1]] = true
		byName[NormalizeRaceName(race[2])] = race[1]
		for _, name in ipairs(FOREVER_RACE_NAMES[race[1]] or {}) do
			byName[NormalizeRaceName(name)] = race[1]
		end
	end
	for key, info in pairs(infos) do
		local race = info.race
		if (not race or not known[race]) and info.raceName then
			race = byName[NormalizeRaceName(info.raceName)] or race or info.raceName
		end
		race = race or "?"
		byRace[race] = byRace[race] or {}
		local class = info.class or "?"
		byRace[race][class] = byRace[race][class] or {}
		table.insert(byRace[race][class], key)
		if race ~= "?" and not known[race] then
			known[race] = true
			unknownRaces[#unknownRaces + 1] = { race, info.raceName or race, nil, string.rep("x", #MATRIX_CLASSES) }
		end
	end
	table.sort(unknownRaces, function(a, b)
		return a[2] < b[2]
	end)
	if byRace["?"] then
		unknownRaces[#unknownRaces + 1] = { "?", L["Race inconnue"], nil, string.rep("x", #MATRIX_CLASSES) }
	end

	-- Ligne d'une race : icône et nom (liseré de la faction), puis une case par classe ; nil si
	-- la race n'a aucun personnage et que seules les races jouées sont affichées.
	local allRaces = ShowAllRaces()
	local function RaceRow(race)
		local raceFile = race[1]
		local chars = byRace[raceFile] or {}
		local total = 0
		for _, keys in pairs(chars) do
			total = total + #keys
		end
		if total == 0 and not allRaces then
			return nil
		end
		local label = RACE_LABELS[raceFile] or race[2] -- nom de la table (les noms relevés peuvent être au féminin)
		local icon = RaceIcon(raceFile)
		local rowCells = { [1] = {
			text = (icon and (icon .. " ") or "") .. label,
			bg = BG_M_LABEL,
			stripe = race[3] and FACTION_BG[race[3]] or nil,
			justify = "LEFT",
			tooltip = function()
				GameTooltip:AddLine(label)
				if raceFile == "?" then
					GameTooltip:AddLine(L["Personnages dont la race sera connue à leur prochaine connexion (avec "
						.. "Polypode Suivi à jour, ou Polypode Data)."], 1, 1, 1, true)
				else
					GameTooltip:AddLine(L["%d personnage(s)"]:format(total), 1, 1, 1)
				end
			end,
		} }
		for i, entry in ipairs(MATRIX_COLUMNS) do
			local classFile = entry.class[1]
			local keys = chars[classFile]
			if keys then
				-- Le plus haut niveau d'abord, les autres comptés (« +n »), tous dans l'infobulle.
				SortKeys(keys, infos)
				local first = infos[keys[1]]
				rowCells[i + 1] = {
					text = ClassColorCode(first.class) .. first.name .. "|r",
					badge = #keys > 1 and ("+" .. (#keys - 1)) or nil,
					bg = ClassTint(classFile),
					mark = AnyMax(keys, infos),
					tooltip = NamesTooltip(keys, infos),
				}
			elseif race[4]:sub(entry.index, entry.index) ~= "x" then
				rowCells[i + 1] = { bg = BG_M_IMPOSSIBLE }
			else
				rowCells[i + 1] = { bg = BG_M_EMPTY }
			end
		end
		return { cells = rowCells }
	end

	local armorRow, classRow = ClassHeaderRows()
	local rows = { armorRow, classRow }
	-- Un groupe (sous-titre puis ses races), omis s'il n'a aucune ligne affichée.
	local function AddGroup(title, races)
		local groupRows = {}
		for _, race in ipairs(races) do
			groupRows[#groupRows + 1] = RaceRow(race)
		end
		if #groupRows > 0 then
			rows[#rows + 1] = GroupRow(title, #columns)
			for _, row in ipairs(groupRows) do
				rows[#rows + 1] = row
			end
		end
	end
	for _, group in ipairs(FACTION_GROUPS) do
		local races = {}
		for _, race in ipairs(MATRIX_RACES) do
			if race[3] == group[1] then
				races[#races + 1] = race
			end
		end
		AddGroup(ColorCode(FACTION_BG[group[1]]) .. group[2] .. "|r", races)
	end
	AddGroup("|cff999999" .. L["Autres"] .. "|r", unknownRaces)
	-- Personnages d'une classe inconnue (ni dans CLASSES) : ignorés de la matrice, rares.

	-- Lignes libres : section repliable (PolypodeSuiviDB.gridFreeCollapsed), sans rappel des en-têtes.
	local freeRows = Grid().rows
	local collapsed = WindowSettings().gridFreeCollapsed == true
	local toggle = collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up"
	rows[#rows + 1] = GroupRow("|T" .. toggle .. ":14:14|t " .. L["Lignes libres (%d)"]:format(#freeRows), #columns, {
		tooltip = function()
			GameTooltip:AddLine(L["Lignes libres"])
			GameTooltip:AddLine(L["Clic : afficher ou masquer les lignes libres (libellé et texte par classe, "
				.. "communes à tous vos personnages)."], 1, 1, 1, true)
		end,
		onClick = function()
			if PolypodeSuiviDB then
				PolypodeSuiviDB.gridFreeCollapsed = not collapsed
			end
			ns.RefreshGrid()
		end,
	})
	if collapsed then
		return { columns = columns, rows = rows }
	end
	for index, free in ipairs(freeRows) do
		local rowCells = { [1] = {
			text = free.label ~= "" and free.label or "|cff999999" .. L["(sans nom)"] .. "|r",
			bg = BG_FREE_LABEL,
			justify = "LEFT",
			tooltip = function()
				GameTooltip:AddLine(free.label ~= "" and free.label or L["Ligne sans nom"])
				GameTooltip:AddLine(L["Clic : renommer. Clic droit : supprimer la ligne."], 1, 1, 1, true)
			end,
			onClick = function(cell, mouseButton)
				if mouseButton == "RightButton" then
					ConfirmDeleteRow(index)
				else
					ShowEditor(cell, free.label, function(text)
						free.label = text
					end)
				end
			end,
		} }
		for i, entry in ipairs(MATRIX_COLUMNS) do
			local classFile = entry.class[1]
			local text = free.cells and free.cells[classFile] or ""
			rowCells[i + 1] = {
				text = text,
				bg = text ~= "" and BG_FILLED or BG_M_EMPTY,
				tooltip = function()
					GameTooltip:AddLine((free.label ~= "" and free.label or L["Ligne sans nom"]) .. " · "
						.. ClassName(classFile))
					if text ~= "" then
						GameTooltip:AddLine(text, 1, 1, 1, true)
					end
					GameTooltip:AddLine(L["Clic : modifier le texte (Entrée pour valider, Échap pour annuler)."],
						0.6, 0.6, 0.6, true)
				end,
				onClick = function(cell)
					ShowEditor(cell, text, function(value)
						free.cells = free.cells or {}
						free.cells[classFile] = value ~= "" and value or nil
					end)
				end,
			}
		end
		rows[#rows + 1] = { cells = rowCells }
	end
	rows[#rows + 1] = { cells = { [1] = {
		text = L["+ Ajouter une ligne"],
		bg = BG_ADD,
		span = #columns,
		justify = "LEFT",
		tooltip = function()
			GameTooltip:AddLine(L["Ajouter une ligne"])
			GameTooltip:AddLine(L["Clic : ajoute une ligne libre en bas de la matrice (libellé et texte par "
				.. "classe), commune à tous vos personnages."], 1, 1, 1, true)
		end,
		onClick = function()
			local rowsList = Grid().rows
			rowsList[#rowsList + 1] = { label = L["Nouvelle ligne"], cells = {} }
			GridChanged()
		end,
	} } }
	return { columns = columns, rows = rows }
end

-- AFFICHAGE ------------------------------------------------------------------------------

local function CellOnEnter(self)
	local data = self.data
	if data and data.onClick then
		self.hover:Show()
	end
	if data and data.tooltip then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		data.tooltip()
		if ns.ShowTooltip then
			ns.ShowTooltip()
		else
			GameTooltip:Show()
		end
	end
end

local function CellOnLeave(self)
	self.hover:Hide()
	GameTooltip_Hide()
end

local function AcquireCell(index)
	local cell = cells[index]
	if not cell then
		cell = CreateFrame("Button", nil, canvas)
		cell.bg = cell:CreateTexture(nil, "BACKGROUND")
		cell.bg:SetAllPoints()
		cell.hover = cell:CreateTexture(nil, "HIGHLIGHT")
		cell.hover:SetAllPoints()
		cell.hover:SetColorTexture(1, 1, 1, 0.12)
		cell.hover:Hide()
		-- Liseré à gauche (faction d'une race), coin doré (niveau maximum), compteur à droite (« +n »).
		cell.stripe = cell:CreateTexture(nil, "BORDER")
		cell.stripe:SetPoint("TOPLEFT")
		cell.stripe:SetPoint("BOTTOMLEFT")
		cell.stripe:SetWidth(3)
		cell.mark = cell:CreateTexture(nil, "BORDER")
		cell.mark:SetPoint("TOPRIGHT")
		cell.mark:SetSize(5, 5)
		cell.mark:SetColorTexture(MAX_MARK[1], MAX_MARK[2], MAX_MARK[3], MAX_MARK[4])
		cell.badge = cell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		cell.badge:SetPoint("RIGHT", -3, 0)
		cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cell.text:SetJustifyV("MIDDLE")
		cell.text:SetWordWrap(false)
		cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		cell:SetScript("OnEnter", CellOnEnter)
		cell:SetScript("OnLeave", CellOnLeave)
		cell:SetScript("OnClick", function(self, mouseButton)
			if self.data and self.data.onClick then
				self.data.onClick(self, mouseButton)
			end
		end)
		cells[index] = cell
	end
	return cell
end

local function LineCount(spec)
	if spec.lines then
		return spec.lines
	end
	local _, newlines = (spec.text or ""):gsub("\n", "")
	return newlines + 1
end

-- Pose la grille : colonnes { width (fixe) ou souples }, lignes { cells = { [colonne] = { text,
-- bg, justify, span, lines, tooltip, onClick } } } ; colonnes souples partageant la largeur visible
-- (MIN_FLEX au moins : au-delà, défilement horizontal par Maj + molette).
local function Render(grid)
	local viewWidth = scroll:GetWidth()
	local fixed, flexCount = 0, 0
	for _, column in ipairs(grid.columns) do
		if column.width then
			fixed = fixed + column.width + GAP
		else
			flexCount = flexCount + 1
			fixed = fixed + GAP
		end
	end
	local flex = flexCount > 0 and math.max(MIN_FLEX, math.floor((viewWidth - fixed) / flexCount)) or 0
	local lefts, widths, x = {}, {}, 0
	for i, column in ipairs(grid.columns) do
		lefts[i], widths[i] = x, column.width or flex
		x = x + widths[i] + GAP
	end
	local totalWidth = math.max(x - GAP, 1)

	local used, y = 0, 0
	for _, row in ipairs(grid.rows) do
		local lines = 1
		for _, spec in pairs(row.cells) do
			lines = math.max(lines, LineCount(spec))
		end
		local height = lines * LINE_HEIGHT + 2 * CELL_PAD
		local column = 1
		while column <= #grid.columns do
			local spec = row.cells[column] or {}
			local span = math.min(spec.span or 1, #grid.columns - column + 1)
			local width = lefts[column + span - 1] + widths[column + span - 1] - lefts[column]
			used = used + 1
			local cell = AcquireCell(used)
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", canvas, "TOPLEFT", lefts[column], -y)
			cell:SetSize(width, height)
			local bg = spec.bg or BG_EMPTY
			cell.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
			local stripe = spec.stripe
			cell.stripe:SetShown(stripe ~= nil)
			if stripe then
				cell.stripe:SetColorTexture(stripe[1], stripe[2], stripe[3], stripe[4] or 1)
			end
			cell.mark:SetShown(spec.mark == true)
			cell.badge:SetText(spec.badge or "")
			cell.badge:SetShown(spec.badge ~= nil)
			-- Texte entre le liseré et le compteur (nom tronqué, compteur toujours visible).
			local right = spec.badge and (cell.badge:GetStringWidth() + 6) or 3
			cell.text:ClearAllPoints()
			cell.text:SetPoint("TOPLEFT", stripe and 7 or 3, -CELL_PAD)
			cell.text:SetPoint("BOTTOMRIGHT", -right, CELL_PAD)
			cell.text:SetText(spec.text or "")
			cell.text:SetJustifyH(spec.justify or "CENTER")
			cell.text:SetFontObject(row.header and "GameFontNormalSmall" or "GameFontHighlightSmall")
			cell.data = (spec.tooltip or spec.onClick) and spec or nil
			cell.hover:Hide()
			cell:Show()
			column = column + span
		end
		y = y + height + GAP
	end
	for i = used + 1, #cells do
		cells[i]:Hide()
		cells[i].data = nil
	end
	canvas:SetSize(totalWidth, math.max(y, 1))
	frame.emptyText:SetShown(#grid.rows == 0)
	frame.emptyText:SetText(grid.empty or "")
end

-- Onglet affiché (PolypodeSuiviDB.gridTab : "accounts" / "matrix").
local function CurrentTab()
	local tab = WindowSettings().gridTab
	if tab == "matrix" then
		return "matrix"
	end
	return "accounts"
end

function ns.RefreshGrid()
	if not frame or not frame:IsShown() then
		return
	end
	if editor then
		editor:Hide()
	end
	local tab = CurrentTab()
	frame.accountsTab.activeTint:SetShown(tab == "accounts")
	frame.matrixTab.activeTint:SetShown(tab == "matrix")
	frame.allRacesCheck:SetShown(tab == "matrix")
	frame.allRacesCheck:SetChecked(ShowAllRaces())
	frame.helpText:SetText(tab == "matrix"
		and L["Coin doré : niveau maximum ; « +n » : autres personnages. Survol : détail ; Maj + molette : défilement horizontal."]
		or L["Rouge : niveau maximum. Survol : détail ; Maj + molette : défilement horizontal."])
	Render(tab == "matrix" and BuildMatrixGrid() or BuildAccountsGrid())
end

-- Champ de saisie posé sur une case (lignes libres de la matrice) : Entrée ou perte du focus
-- enregistre, Échap annule.
ShowEditor = function(cell, text, commit)
	if not editor then
		editor = CreateFrame("EditBox", nil, canvas, "InputBoxTemplate")
		editor:SetAutoFocus(false)
		editor:SetFontObject("GameFontHighlightSmall")
		editor:SetMaxLetters(80)
		local function Save(self)
			local save = self.commit
			self.commit = nil
			self:ClearFocus()
			self:Hide()
			if save then
				local value = strtrim(((self:GetText() or ""):gsub("[|\n]", "")))
				save(value)
				GridChanged()
			end
		end
		editor:SetScript("OnEnterPressed", Save)
		editor:SetScript("OnEditFocusLost", Save)
		editor:SetScript("OnEscapePressed", function(self)
			self.commit = nil
			self:ClearFocus()
			self:Hide()
		end)
	end
	editor:ClearAllPoints()
	editor:SetPoint("TOPLEFT", cell, "TOPLEFT", 6, 0)
	editor:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -2, 0)
	editor:SetFrameLevel(cell:GetFrameLevel() + 5)
	editor.commit = commit
	editor:SetText(text or "")
	editor:Show()
	editor:SetFocus()
	editor:HighlightText()
end

local function SetTab(tab)
	WindowSettings().gridTab = tab
	ns.RefreshGrid()
end

local function OpenGridOptions()
	local category = ns.gridSettingsCategory
	if category and Settings and Settings.OpenToCategory then
		frame:Hide()
		Settings.OpenToCategory(category:GetID())
	end
end

local function TabButton(text, width, tooltip, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(width, 20)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(text)
		GameTooltip:AddLine(tooltip, 1, 1, 1, true)
		if ns.ShowTooltip then
			ns.ShowTooltip()
		else
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeSuiviGridFrame", UIParent, "BackdropTemplate")
	local settings = WindowSettings()
	frame:SetSize(math.max(settings.gridWidth or DEFAULT_WIDTH, MIN_WIDTH),
		math.max(settings.gridHeight or DEFAULT_HEIGHT, MIN_HEIGHT))
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.9)
	frame:Hide()
	tinsert(UISpecialFrames, "PolypodeSuiviGridFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText(L["Grille des personnages"])
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	-- Bouton Options à gauche de la barre de titre (comme dans les fenêtres de Polypode).
	local optionsBtn = TabButton(L["Options"], 70, L["Ouvre les options de la grille (Options > AddOns > Polypode > "
		.. "Suivi > Grille)."], OpenGridOptions)
	optionsBtn:SetPoint("TOPLEFT", 6, -3)

	-- Onglets, à droite de la barre de titre (Matrice contre la croix) ; l'onglet affiché porte un
	-- voile bleu.
	local matrixTab = TabButton(L["Matrice"], 80, L["Personnages par race et par classe (combinaisons impossibles "
		.. "en gris), et lignes libres en bas."], function()
			SetTab("matrix")
		end)
	matrixTab:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
	local accountsTab = TabButton(L["Comptes"], 80, L["Personnages par compte WoW : seuls, puis par équipe de "
		.. "Polypode (une ligne par équipe). Colonnes réglées dans Options > Polypode > Suivi > Grille."],
		function()
			SetTab("accounts")
		end)
	accountsTab:SetPoint("RIGHT", matrixTab, "LEFT", -4, 0)
	frame.accountsTab, frame.matrixTab = accountsTab, matrixTab

	local panel = P.CreatePanel(frame, "")
	panel:SetPoint("TOPLEFT", 12, -36)
	panel:SetPoint("BOTTOMRIGHT", -12, 12)
	panel.header:SetFontObject("GameFontDisableSmall") -- aide de l'onglet (ns.RefreshGrid)
	frame.helpText = panel.header

	-- Matrice : case « Toutes les races » à droite de l'aide (décochée : races jouées seulement).
	local allRaces = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	allRaces:SetSize(20, 20)
	allRaces:SetPoint("TOPRIGHT", -110, -2)
	local allRacesLabel = allRaces:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	allRacesLabel:SetPoint("LEFT", allRaces, "RIGHT", 2, 0)
	allRacesLabel:SetText(L["Toutes les races"])
	allRaces:SetScript("OnClick", function(self)
		if PolypodeSuiviDB then
			PolypodeSuiviDB.gridAllRaces = self:GetChecked() and true or nil
		end
		ns.RefreshGrid()
	end)
	allRaces:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Toutes les races"])
		GameTooltip:AddLine(L["Cochée : toutes les races, pour voir les combinaisons qui manquent. Décochée : "
			.. "seulement les races qui ont un personnage."], 1, 1, 1, true)
		if ns.ShowTooltip then
			ns.ShowTooltip()
		else
			GameTooltip:Show()
		end
	end)
	allRaces:SetScript("OnLeave", GameTooltip_Hide)
	frame.allRacesCheck = allRaces

	-- Zone défilante : ScrollFrame piloté par une MinimalScrollBar (la barre des listes de Polypode,
	-- skinnée par P.SkinScrollBar pour EllesmereUI / ElvUI), affichée seulement si la grille déborde.
	scroll = CreateFrame("ScrollFrame", nil, panel)
	scroll:SetPoint("TOPLEFT", 8, -26)
	scroll:SetPoint("BOTTOMRIGHT", -22, 8)
	canvas = CreateFrame("Frame", nil, scroll)
	canvas:SetSize(1, 1)
	scroll:SetScrollChild(canvas)
	scroll:EnableMouseWheel(true)
	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scrollBar)
	scroll:HookScript("OnScrollRangeChanged", function(self)
		scrollBar:SetShown(self:GetVerticalScrollRange() > 0)
	end)
	scrollBar:Hide()
	if P.SkinScrollBar then
		P.SkinScrollBar(scrollBar)
	end
	-- Molette : vertical (par la barre) ; Maj + molette : horizontal (grille plus large que la fenêtre).
	scroll:SetScript("OnMouseWheel", function(self, delta)
		if IsShiftKeyDown() then
			local maxX = math.max(0, canvas:GetWidth() - self:GetWidth())
			self:SetHorizontalScroll(math.min(maxX, math.max(0, self:GetHorizontalScroll() - delta * 60)))
		else
			scrollBar:ScrollStepInDirection(-delta)
		end
	end)

	frame.emptyText = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	frame.emptyText:SetPoint("CENTER")
	frame.emptyText:Hide()

	-- Poignée de redimensionnement (coin bas-droit) ; taille gardée par personnage.
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(frame:GetFrameLevel() + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		local current = WindowSettings()
		current.gridWidth, current.gridHeight = frame:GetSize()
	end)
	-- Largeur changée : colonnes recalculées (regroupé à l'image suivante).
	local relayoutPending
	scroll:SetScript("OnSizeChanged", function()
		if not relayoutPending then
			relayoutPending = true
			C_Timer.After(0, function()
				relayoutPending = nil
				ns.RefreshGrid()
			end)
		end
	end)

	P.SkinFrame(frame)
	P.SkinPanel(panel)
	if P.SkinButton then
		P.SkinButton(accountsTab)
		P.SkinButton(matrixTab)
		P.SkinButton(optionsBtn)
	end
	-- Onglet affiché : voile bleu doux, posé après le skin (comme les boutons de Suivi).
	for _, button in ipairs({ accountsTab, matrixTab }) do
		local tint = button:CreateTexture(nil, "OVERLAY")
		tint:SetPoint("TOPLEFT", 2, -2)
		tint:SetPoint("BOTTOMRIGHT", -2, 2)
		tint:SetColorTexture(0.3, 0.65, 1, 0.25)
		tint:Hide()
		button.activeTint = tint
	end
	P.ui.suiviGridFrame = frame
end

-- Ouvre / ferme la fenêtre (bouton « Grille » de la fenêtre Suivi).
function ns.ToggleGrid()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		ns.RefreshGrid()
	end
end

-- OPTIONS : sous-catégorie « Grille » de la catégorie « Suivi » (appelée par BuildSettingsPanel).
function ns.BuildGridSettings(parent)
	if not (Settings and Settings.RegisterVerticalLayoutSubcategory and Settings.CreateSlider
		and Settings.CreateDropdown) then
		return
	end
	local category = Settings.RegisterVerticalLayoutSubcategory(parent, L["Grille"])
	local function Tip(text)
		return P.ColorClicks and P.ColorClicks(text) or text
	end

	local profSetting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_GRID_PROFESSIONS",
		Settings.VarType.Boolean, L["Afficher les métiers"], true,
		function()
			return Grid().professions
		end,
		function(value)
			Grid().professions = value and true or false
			GridChanged()
		end)
	Settings.CreateCheckbox(category, profSetting, Tip(L["Onglet « Comptes » de la grille : colonnes Métier 1 et "
		.. "Métier 2 à gauche. Réglage commun à tous vos personnages."]))

	local countSetting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_GRID_COUNT",
		Settings.VarType.Number, L["Nombre de colonnes de comptes"], AccountCount(),
		function()
			return AccountCount()
		end,
		function(value)
			value = math.floor(tonumber(value) or 1)
			if value ~= AccountCount() or not Grid().count then
				Grid().count = value
				GridChanged()
			end
		end)
	local sliderOptions = Settings.CreateSliderOptions(1, MAX_ACCOUNTS, 1)
	sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return tostring(math.floor(value))
	end)
	local countInit = Settings.CreateSlider(category, countSetting, sliderOptions, Tip(L["Onglet « Comptes » : "
		.. "nombre de colonnes de comptes WoW (10 au plus). Les personnages d'un compte sans colonne vont dans "
		.. "« Autres ». Réglage commun à tous vos personnages."]))

	for i = 1, MAX_ACCOUNTS do
		local setting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_GRID_COLUMN" .. i,
			Settings.VarType.String, L["Colonne %d"]:format(i), "",
			function()
				return Grid().columns[i] or ""
			end,
			function(value)
				value = value or ""
				if (Grid().columns[i] or "") ~= value then
					Grid().columns[i] = value ~= "" and value or nil
					GridChanged()
				end
			end)
		local init = Settings.CreateDropdown(category, setting, function()
			local container = Settings.CreateControlTextContainer()
			container:Add("", L["Automatique"])
			for _, label in ipairs(AccountLabels()) do
				container:Add(label, label)
			end
			return container:GetData()
		end, Tip(L["Compte WoW (nommé dans Polypode) de la colonne %d de l'onglet « Comptes ». Automatique : le premier "
			.. "compte pas encore placé, par ordre alphabétique. Grisée au-delà du nombre de colonnes. Réglage commun à "
			.. "tous vos personnages."]:format(i)))
		if init and init.SetParentInitializer then
			init:SetParentInitializer(countInit, function()
				return i <= AccountCount()
			end)
		end
	end
	Settings.RegisterAddOnCategory(category)
	ns.gridSettingsCategory = category
end

-- SYNCHRO ------------------------------------------------------------------------------------

if P.RegisterMessageHandler then
	P.RegisterMessageHandler("SUIVIGRID", OnGridMessage)
	P.RegisterPeerCallback(function(sender)
		SendGrid(sender)
	end)
end
