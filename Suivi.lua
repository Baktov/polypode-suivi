-- Polypode Suivi: Suivi — suivi de l'équipe : grande chambre forte, écus, ressources, renommées, runes

local _, ns = ...
local P = Polypode -- dépendance obligatoire (## Dependencies: Polypode), chargée avant nous

-- PANNEAU ACTIVITÉS (bouton « Activités » en haut à droite, option activityMode) : les activités
-- de Midnight (ns.ACTIVITIES, Activities.lua, liste reprise de Plumber) par catégorie, avec à
-- droite de chaque ligne les personnages qui l'ont faite (vert) ou commencée (jaune). Section A :
-- état par activité (q<id> / p<id> : 2 faite, 1 en cours ; c<id> : nombre de quêtes faites),
-- remise à zéro à la réinitialisation hebdomadaire (et quotidienne pour les activités daily).

-- Addon compagnon de Polypode, indépendant : bouton « Suivi » dans la barre de titre de la
-- fenêtre Polypode (P.AddTitleButton) et /poly suivi (P.RegisterSlashCommand). La fenêtre liste
-- les membres de l'équipe sélectionnée (leader en tête) avec un résumé par ligne ; le détail
-- est dans l'infobulle. Données, lues comme le « Résumé de l'extension » de Plumber :
--   V — grande chambre forte : progrès / seuil de chaque case (C_WeeklyRewards.GetActivities),
--       rangées R (raids), M (donjons), W (monde) ;
--   C — écus d'amélioration d'objet (monnaies, identifiants repris de Plumber, liste 12.0 ou 12.1) ;
--   R — ressources de Midnight possédées (monnaies c<id> et objets i<id>, liste reprise de Plumber) ;
--   F — renommées débloquées de l'extension (C_MajorFactions) ;
--   P — runes de pouvoir (arbre du résumé de l'extension de Midnight, C_Traits) : u = points non
--       dépensés, b = 1 si une rune est achetable (même calcul que Blizzard) ;
--   S — campagnes : chapitres faits / chapitres (C_CampaignInfo), liste ns.CAMPAIGNS (Activities.lua).
-- Le personnage joué est lu en direct ; les autres envoient leurs données par le message
-- SUIVI:token:nom-royaume:section:flag:k=v,k=v,... (flag N = premier fragment, + = suite ;
-- expéditeur vérifié), à chaque rencontre (P.RegisterPeerCallback) et 3 s après un changement
-- (seulement les sections modifiées). Toute API absente (ex. WoW Forever) laisse la section vide.
-- SAUVEGARDE : les données de chaque personnage (reçues, et celles du personnage joué) sont
-- gardées dans PolypodeSuiviData (fichier de compte), datées par section (heure serveur) ; la case
-- « Tous les personnages » (barre de titre de la fenêtre, option showAll) les liste toutes. Une
-- grande chambre forte datée d'avant la dernière réinitialisation hebdomadaire (mercredi matin,
-- C_DateAndTime.GetSecondsUntilWeeklyReset) est affichée remise à zéro.

local SEND_DELAY = 3 -- secondes : regroupe les rafales d'événements (monnaies, sacs)
local RUNES_SYSTEM_ID, RUNES_TREE_ID = 48, 1186 -- runes de pouvoir (Blizzard_MidnightLandingPage)

-- Rangées de la grande chambre forte : lettre, type Blizzard, libellé.
local VAULT_ROWS = {
	{ "R", "Raid", "Raids" },
	{ "M", "Activities", "Donjons" },
	{ "W", "World", "Monde" },
}

-- Écus, du plus haut au plus bas (Plumber, SharedData.lua).
local CRESTS_12_0 = { 3347, 3345, 3343, 3341, 3383 }
local CRESTS_12_1 = { 3446, 3445, 3444, 3443, 3442 }

-- Ressources de Midnight (Plumber, ResourceList.lua) : { "c" monnaie | "i" objet, identifiant }.
local RESOURCES = {
	{ "c", 3418 }, { "c", 3378 }, { "c", 3465 }, { "i", 273000 }, { "c", 3448 }, { "c", 3028 },
	{ "c", 3310 }, { "c", 3316 }, { "c", 3363 }, { "c", 3405 }, { "i", 242241 }, { "i", 246951 },
	{ "c", 3546 }, { "c", 3392 }, { "c", 2803 }, { "c", 3379 }, { "c", 3376 }, { "c", 3377 },
	{ "c", 1602 }, { "c", 1792 }, { "c", 2123 }, { "c", 2797 },
}

local SECTIONS = { "V", "C", "R", "F", "P", "A", "M", "W", "S" }

-- Options par personnage (PolypodeSuiviDB, Options → AddOns → Polypode → Suivi).
local DEFAULTS = {
	showAll = false, -- tous les personnages sauvegardés au lieu de l'équipe sélectionnée
	activityMode = false, -- panneau « Activités » au lieu du résumé
	showOldCampaigns = false, -- campagnes des extensions précédentes dans l'infobulle
	showFactions = false, -- renommées dans l'infobulle (inutile avec un seul compte Battle.net :
	-- elles y sont communes à tous les personnages)
	width = 620, height = 340, -- taille de la fenêtre (poignée de redimensionnement)
	sortDesc = false, -- tri : ordre inverse (sortColumn : "name", id de colonne, ou nil = sans tri)
}
local MIN_WIDTH, MIN_HEIGHT = 480, 200

local function SuiviSettings()
	return PolypodeSuiviDB or DEFAULTS
end

-- Mode solo de Polypode (0.54.0) : pas d'équipe, « Tous les personnages » est imposé.
local function IsSolo()
	return P.IsSoloMode ~= nil and P.IsSoloMode()
end

-- « Tous les personnages » en vigueur : l'option, ou le mode solo.
local function ShowAll()
	return SuiviSettings().showAll or IsSolo()
end

-- [nom-royaume] = { sections = { [section] = { [k] = v } }, at = date, times = { [section] = date } }
-- (dates = heure serveur). Remplacé à ADDON_LOADED par la table sauvegardée PolypodeSuiviData.
local received = {}
local lastSent = {} -- [section] = dernière chaîne envoyée aux clients connectés
local sendPending
local frame, listPanel
local settingsCategory -- catégorie « Suivi » du panneau d'options (BuildSettingsPanel)

-- SAISON : extension de la saison affichée (C_SeasonInfo.GetCurrentDisplaySeasonExpansion) et
-- numéro de saison dans l'extension (C_DelvesUI.GetCurrentDelvesSeasonNumber, 0 hors saison).
-- Renvoie extension, numéro (nil si inconnu ou hors saison).
local function CurrentSeason()
	local expansion = C_SeasonInfo and C_SeasonInfo.GetCurrentDisplaySeasonExpansion
		and C_SeasonInfo.GetCurrentDisplaySeasonExpansion()
	local number = C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber
		and C_DelvesUI.GetCurrentDelvesSeasonNumber()
	return expansion, (number and number > 0) and number or nil
end

local function IsMidnight(expansion)
	return LE_EXPANSION_MIDNIGHT ~= nil and expansion == LE_EXPANSION_MIDNIGHT
end

-- Écus par saison de Midnight (12.0 = saison 1, 12.1 = saison 2, d'après Plumber qui change de
-- liste au patch 12.1). Saison inconnue : liste selon la version du client.
local CRESTS_BY_SEASON = { [1] = CRESTS_12_0, [2] = CRESTS_12_1 }

local function CrestIDs()
	local expansion, number = CurrentSeason()
	if IsMidnight(expansion) and number and CRESTS_BY_SEASON[number] then
		return CRESTS_BY_SEASON[number]
	end
	return (select(4, GetBuildInfo()) or 0) >= 120100 and CRESTS_12_1 or CRESTS_12_0
end

-- Charges du catalyseur par saison de Midnight (Plumber, SharedData.lua : CatalystCurrencyID ;
-- saison 2 = flux de mana de Chancrevenin). Relevées avec les ressources (section R).
local CATALYST_BY_SEASON = { [1] = 3378, [2] = 3465 }

local function CatalystID()
	local expansion, number = CurrentSeason()
	if IsMidnight(expansion) and number and CATALYST_BY_SEASON[number] then
		return CATALYST_BY_SEASON[number]
	end
	return (select(4, GetBuildInfo()) or 0) >= 120100 and CATALYST_BY_SEASON[2] or CATALYST_BY_SEASON[1]
end

-- « Midnight, saison 2 » (nom de l'extension traduit par le jeu), ou nil si inconnue.
local function SeasonText()
	local expansion, number = CurrentSeason()
	if not expansion then
		return nil
	end
	local name = _G["EXPANSION_NAME" .. expansion] or ("Extension " .. expansion)
	return number and (name .. ", saison " .. number) or (name .. ", hors saison")
end

-- Vrai si les listes reprises de Plumber (écus, activités) ne couvrent pas la saison en cours :
-- autre extension, ou saison de Midnight non prévue.
local function ListsOutdated()
	local expansion, number = CurrentSeason()
	if not expansion or not number then
		return false
	end
	if not IsMidnight(expansion) then
		return true
	end
	return not (CRESTS_BY_SEASON[number] and ns.ACTIVITIES_SEASONS and ns.ACTIVITIES_SEASONS[number])
end

local function CurrencyInfo(id)
	local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
	if info and info.name and info.name ~= "" then
		return info
	end
end

-- LECTURE DU PERSONNAGE JOUÉ ------------------------------------------------------------

local function ReadVault()
	local data = {}
	local types = Enum and Enum.WeeklyRewardChestThresholdType
	if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities and types) then
		return data
	end
	for _, row in ipairs(VAULT_ROWS) do
		local activityType = types[row[2]]
		local activities = activityType and C_WeeklyRewards.GetActivities(activityType)
		if activities then
			table.sort(activities, function(a, b)
				return (a.index or 0) < (b.index or 0)
			end)
			for i, activity in ipairs(activities) do
				data[row[1] .. i] = (activity.progress or 0) .. "/" .. (activity.threshold or 0)
			end
		end
	end
	return data
end

local function ReadCrests()
	local data = {}
	for _, id in ipairs(CrestIDs()) do
		local info = CurrencyInfo(id)
		if info then
			data[tostring(id)] = info.quantity or 0
		end
	end
	return data
end

local function ReadResources()
	local data = {}
	for _, resource in ipairs(RESOURCES) do
		local kind, id = resource[1], resource[2]
		local quantity
		if kind == "c" then
			local info = CurrencyInfo(id)
			quantity = info and info.quantity
		elseif C_Item and C_Item.GetItemCount then
			quantity = C_Item.GetItemCount(id, true, false, true, true)
		end
		if quantity and quantity > 0 then
			data[kind .. id] = quantity
		end
	end
	return data
end

local function ReadFactions()
	local data = {}
	if not (C_MajorFactions and C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.GetMajorFactionData) then
		return data
	end
	local expansion = GetClientDisplayExpansionLevel and GetClientDisplayExpansionLevel()
	for _, id in ipairs(C_MajorFactions.GetMajorFactionIDs(expansion) or {}) do
		local faction = C_MajorFactions.GetMajorFactionData(id)
		if faction and faction.isUnlocked and faction.renownLevel then
			data[tostring(id)] = faction.renownLevel
		end
	end
	return data
end

-- Vrai si une rune est achetable (repris de Blizzard_MidnightLandingPage : CanPurchaseRuneOfPower).
local function CanPurchaseRune(configID, unspent)
	if unspent == 0 then
		return false
	end
	for _, nodeID in ipairs(C_Traits.GetTreeNodes(RUNES_TREE_ID) or {}) do
		local nodeCosts = C_Traits.GetNodeCost(configID, nodeID)
		local canAfford = (#nodeCosts == 0) or (unspent >= nodeCosts[1].amount)
		if canAfford then
			local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
			if nodeInfo and nodeInfo.entryIDs then
				for _, entryID in ipairs(nodeInfo.entryIDs) do
					if C_Traits.CanPurchaseRank(configID, nodeID, entryID) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function ReadRunes()
	local data = {}
	if not (C_Traits and C_Traits.GetConfigIDBySystemID and C_Traits.GetTreeCurrencyInfo) then
		return data
	end
	local configID = C_Traits.GetConfigIDBySystemID(RUNES_SYSTEM_ID)
	if not configID then
		return data
	end
	local currencies = C_Traits.GetTreeCurrencyInfo(configID, RUNES_TREE_ID, false)
	local unspent = currencies and currencies[1] and currencies[1].quantity
	if unspent then
		data.u = unspent
		data.b = CanPurchaseRune(configID, unspent) and 1 or 0
	end
	return data
end

-- Clé d'une activité dans la section A.
local function EntryKey(entry)
	if entry.q then
		return "q" .. entry.q
	elseif entry.pool then
		return "p" .. entry.pool[1]
	end
	return "c" .. entry.count[1]
end

-- Clés des activités quotidiennes (remises à zéro chaque jour).
local DAILY_KEYS = {}
for _, category in ipairs(ns.ACTIVITIES or {}) do
	for _, entry in ipairs(category.entries) do
		if entry.daily then
			DAILY_KEYS[EntryKey(entry)] = true
		end
	end
end

-- Clés et quêtes de la liste fixe (le reste de la section A = quêtes dynamiques de la carte).
local FIXED_KEYS, FIXED_QUESTS = {}, {}
for _, category in ipairs(ns.ACTIVITIES or {}) do
	for _, entry in ipairs(category.entries) do
		FIXED_KEYS[EntryKey(entry)] = true
		for _, questID in ipairs(entry.q and { entry.q } or entry.pool or entry.count) do
			FIXED_QUESTS[questID] = true
		end
	end
end

-- Nom de repli des quêtes de carte connues (ns.MAP_QUESTS).
local MAP_QUEST_NAMES = {}
for _, entry in ipairs(ns.MAP_QUESTS or {}) do
	MAP_QUEST_NAMES[entry.q] = entry.name
end

-- Types de quêtes montrés par Plumber dans une catégorie de carte (répétable, méta, mission).
local function IsShownClassification(questID, info)
	local classes = Enum and Enum.QuestClassification
	if not classes then
		return false
	end
	local classification = (info and info.questClassification)
		or (C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification
			and C_QuestInfoSystem.GetQuestClassification(questID))
	return classification ~= nil and (classification == classes.Recurring or classification == classes.Meta
		or classification == classes.Calling)
end

local function WeeklyResetTime()
	local untilNext = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
		and C_DateAndTime.GetSecondsUntilWeeklyReset()
	return untilNext and GetServerTime() + untilNext - 7 * 24 * 3600
end

-- Quêtes dynamiques de la carte (ns.DYNAMIC_MAP) pour le personnage joué : proposées sur la carte,
-- ou de ns.MAP_QUESTS en cours (ou always), ou vues cette semaine (PolypodeSuiviDB.dynamicSeen :
-- une quête faite disparaît de la carte mais doit rester suivie jusqu'à la réinitialisation).
-- Renvoie { [questID] = true }.
local function DynamicQuestIDs()
	local ids = {}
	local map = ns.DYNAMIC_MAP
	if map and C_QuestLine and C_QuestLine.GetAvailableQuestLines then
		if C_QuestLine.RequestQuestLinesForMap then
			C_QuestLine.RequestQuestLinesForMap(map)
		end
		local sources = { C_QuestLine.GetAvailableQuestLines(map) or {} }
		if C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
			sources[2] = C_TaskQuest.GetQuestsOnMap(map) or {}
		end
		for _, source in ipairs(sources) do
			for _, info in ipairs(source) do
				local questID = info.questID
				if questID and not info.isHidden and (info.startMapID or info.mapID) == map
					and not FIXED_QUESTS[questID] and IsShownClassification(questID, info) then
					ids[questID] = true
				end
			end
		end
	end
	for _, entry in ipairs(ns.MAP_QUESTS or {}) do
		if entry.always or (C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(entry.q)) then
			ids[entry.q] = true
		end
	end
	local settings = PolypodeSuiviDB
	if settings then
		settings.dynamicSeen = settings.dynamicSeen or {}
		local seen, reset = settings.dynamicSeen, WeeklyResetTime()
		for questID, at in pairs(seen) do
			if reset and at < reset then
				seen[questID] = nil
			else
				ids[questID] = true
			end
		end
		for questID in pairs(ids) do
			seen[questID] = seen[questID] or GetServerTime()
		end
	end
	return ids
end

local function QuestDone(questID, accountwide)
	if accountwide and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
		return C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID)
	end
	return C_QuestLog.IsQuestFlaggedCompleted(questID)
end

local function ReadActivities()
	local data = {}
	if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
		return data
	end
	for _, category in ipairs(ns.ACTIVITIES or {}) do
		for _, entry in ipairs(category.entries) do
			local state = 0
			if entry.count then
				for _, questID in ipairs(entry.count) do
					if QuestDone(questID, entry.accountwide) then
						state = state + 1
					end
				end
			else
				for _, questID in ipairs(entry.q and { entry.q } or entry.pool) do
					if QuestDone(questID, entry.accountwide) then
						state = 2
						break
					elseif C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) then
						state = 1
					end
				end
			end
			if state > 0 then
				data[EntryKey(entry)] = state
			end
		end
	end
	-- Quêtes dynamiques de la carte (catégorie « Lune-d'Argent »).
	for questID in pairs(DynamicQuestIDs()) do
		local state = QuestDone(questID) and 2 or (C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) and 1) or 0
		if state > 0 then
			data["q" .. questID] = state
		end
	end
	return data
end

-- COURRIER (section M) : n = 1 si courrier non lu (HasNewMail, lisible à tout moment) ; relevé de
-- la boîte aux lettres, seulement quand elle est ouverte (MAIL_INBOX_UPDATE, comme Altoholic) :
-- u non lus, t total, x expiration la plus proche (heure serveur), s date du relevé. Relevé gardé
-- par personnage (PolypodeSuiviDB.mailScan).
local MAIL_WARNING = 3 * 24 * 3600 -- expiration à moins de 3 jours : signalée en rouge

-- SEMAINE (section W) : ce qui a été fait cette semaine, remis à zéro à la réinitialisation.
--   t1 / t2 / t3 — traques faites en Normal / Difficile / Cauchemar (ns.PREY_QUESTS, Plumber) ;
--   d<palier> — gouffres (et activités du monde : palier 1) par palier
--               (C_WeeklyRewards.GetSortedProgressForActivity, rangée Monde de la chambre forte) ;
--   h / m / p — donjons héroïques / mythiques / mythiques+ (C_WeeklyRewards.GetNumCompletedDungeonRuns),
--   k — niveaux des clés mythiques+ terminées, « 12.10.8 » (C_MythicPlus.GetRunHistory) ;
--   r<difficulté> — boss de raid tués par difficulté (DifficultyID : 17 LFR, 14 normal, 15
--                   héroïque, 16 mythique ; GetSortedProgressForActivity, rangée Raids).
--   n / f — donjons normaux / avec suivants, comptés par Polypode Suivi à l'ENTRÉE (aucune API ne
--           les suit : ils ne comptent pas pour la chambre forte), PolypodeSuiviDB.dungeonEntries.
--   x<genre><instanceID>-<difficulté> — exploration : entrées de la semaine dans chaque instance
--           (genre g gouffre, d donjon, r raid ; nom retrouvé par GetRealZoneText(instanceID)),
--           notées à l'ENTRÉE, PolypodeSuiviDB.dungeonEntries.visits.

-- Difficultés de donjon comptées à l'entrée : 1 normal, 205 avec suivants.
local COUNTED_DUNGEON_DIFFICULTIES = { [1] = "n", [205] = "f" }
local DELVE_DIFFICULTY = 208 -- gouffres (instance de type « scenario »)
local REENTRY_DELAY = 2 * 3600 -- même instance dans les 2 h (reload, déconnexion) : pas recomptée

-- Compteurs de la semaine du personnage joué, remis à zéro après la réinitialisation hebdomadaire.
local function DungeonEntries()
	local settings = PolypodeSuiviDB
	if not settings then
		return nil
	end
	local entries = settings.dungeonEntries
	local reset = WeeklyResetTime()
	if not entries or (reset and (entries.since or 0) < reset) then
		entries = { n = 0, f = 0, since = GetServerTime() }
		settings.dungeonEntries = entries
	end
	entries.visits = entries.visits or {} -- { ["d2811-1"] = { n = entrées, at = dernière } }
	return entries
end

-- Entrée dans une instance (PLAYER_ENTERING_WORLD) : notée dans l'exploration si c'est un gouffre,
-- un donjon ou un raid, et +1 au compteur si c'est un donjon normal ou avec suivants ; un retour
-- dans la même instance (même difficulté) dans les 2 h n'est pas recompté.
local function CountDungeonEntry()
	if not GetInstanceInfo then
		return
	end
	local _, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
	local kind = (instanceType == "party" and "d") or (instanceType == "raid" and "r")
		or (instanceType == "scenario" and difficultyID == DELVE_DIFFICULTY and "g")
	local entries = kind and instanceID and DungeonEntries()
	if not entries then
		return
	end
	local now = GetServerTime()
	local visitKey = kind .. instanceID .. "-" .. (difficultyID or 0)
	local visit = entries.visits[visitKey]
	if visit and now - visit.at < REENTRY_DELAY then
		visit.at = now
		return
	end
	entries.visits[visitKey] = { n = (visit and visit.n or 0) + 1, at = now }
	local key = kind == "d" and COUNTED_DUNGEON_DIFFICULTIES[difficultyID]
	if key then
		entries[key] = (entries[key] or 0) + 1
	end
end

local function ReadWeekly()
	local data = {}
	if ns.PREY_QUESTS and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		local counts = { 0, 0, 0 }
		for questID, difficulty in pairs(ns.PREY_QUESTS) do
			if counts[difficulty] and C_QuestLog.IsQuestFlaggedCompleted(questID) then
				counts[difficulty] = counts[difficulty] + 1
			end
		end
		for difficulty = 1, 3 do
			if counts[difficulty] > 0 then
				data["t" .. difficulty] = counts[difficulty]
			end
		end
	end
	local types = Enum and Enum.WeeklyRewardChestThresholdType
	local sorted = C_WeeklyRewards and C_WeeklyRewards.GetSortedProgressForActivity
	if types and sorted then
		for prefix, activityType in pairs({ d = types.World, r = types.Raid }) do
			for _, progress in ipairs(sorted(activityType, prefix == "d") or {}) do
				if progress.difficulty and progress.numPoints and progress.numPoints > 0 then
					data[prefix .. progress.difficulty] = progress.numPoints
				end
			end
		end
	end
	if C_WeeklyRewards and C_WeeklyRewards.GetNumCompletedDungeonRuns then
		local heroic, mythic, mythicPlus = C_WeeklyRewards.GetNumCompletedDungeonRuns()
		data.h = (heroic or 0) > 0 and heroic or nil
		data.m = (mythic or 0) > 0 and mythic or nil
		data.p = (mythicPlus or 0) > 0 and mythicPlus or nil
	end
	local entries = DungeonEntries()
	if entries then
		data.n = (entries.n or 0) > 0 and entries.n or nil
		data.f = (entries.f or 0) > 0 and entries.f or nil
		for visitKey, visit in pairs(entries.visits) do
			data["x" .. visitKey] = visit.n
		end
	end
	if C_MythicPlus and C_MythicPlus.GetRunHistory then
		local levels = {}
		for _, run in ipairs(C_MythicPlus.GetRunHistory(false, true) or {}) do
			if run.completed and run.level then
				levels[#levels + 1] = run.level
			end
		end
		table.sort(levels, function(a, b)
			return a > b
		end)
		if #levels > 0 then
			data.k = table.concat(levels, ".")
		end
	end
	return data
end

local function ScanMailbox()
	if not (GetInboxNumItems and GetInboxHeaderInfo and PolypodeSuiviDB) then
		return
	end
	local shown, total = GetInboxNumItems()
	local unread, expires = 0, nil
	for i = 1, shown or 0 do
		local _, _, _, _, _, _, daysLeft, _, wasRead = GetInboxHeaderInfo(i)
		if not wasRead then
			unread = unread + 1
		end
		if daysLeft then
			local at = GetServerTime() + math.floor(daysLeft * 24 * 3600)
			if not expires or at < expires then
				expires = at
			end
		end
	end
	PolypodeSuiviDB.mailScan = { u = unread, t = total or shown or 0, x = expires, s = GetServerTime() }
end

local function ReadMail()
	local data = { n = (HasNewMail and HasNewMail()) and 1 or 0 }
	local scan = PolypodeSuiviDB and PolypodeSuiviDB.mailScan
	if scan then
		data.u, data.t, data.x, data.s = scan.u, scan.t, scan.x, scan.s
	end
	return data
end

-- CAMPAGNES (section S) : <campaignID> = « chapitres faits/chapitres », pour les campagnes de
-- ns.CAMPAIGNS (identifiant lu en jeu d'après leurs quêtes repères) et celles proposées au
-- personnage hors liste (C_CampaignInfo.GetAvailableCampaigns). Chapitre fait : sa quête de
-- récompense est terminée, ou il précède le chapitre en cours (calcul de Blizzard, CampaignMixin).
-- Les campagnes des extensions précédentes ne sont envoyées que commencées (message plus court).
local campaignIDs = {} -- [entrée de ns.CAMPAIGNS] = identifiant de campagne (trouvé cette session)
local campaignQuestsRequested = false

-- Campagnes connues, dans l'ordre de ns.CAMPAIGNS sans doublon : { { id =, entry = } }, et
-- [identifiant] = entrée.
local function KnownCampaigns()
	local list, byID = {}, {}
	if not (C_CampaignInfo and C_CampaignInfo.GetCampaignID) then
		return list, byID
	end
	for _, entry in ipairs(ns.CAMPAIGNS or {}) do
		local id = entry.id or campaignIDs[entry]
		if not id then
			for _, questID in ipairs(entry.quests or {}) do
				local found = C_CampaignInfo.GetCampaignID(questID)
				if found and found > 0 then
					id = found
					campaignIDs[entry] = found
					break
				end
			end
		end
		if id and not byID[id] then
			byID[id] = entry
			list[#list + 1] = { id = id, entry = entry }
		end
	end
	-- Quêtes repères inconnues du client : demandées une fois au serveur (relu au prochain envoi).
	if #list < #(ns.CAMPAIGNS or {}) and not campaignQuestsRequested and C_QuestLog.RequestLoadQuestByID then
		campaignQuestsRequested = true
		for _, entry in ipairs(ns.CAMPAIGNS or {}) do
			if not (entry.id or campaignIDs[entry]) then
				for _, questID in ipairs(entry.quests or {}) do
					C_QuestLog.RequestLoadQuestByID(questID)
				end
			end
		end
	end
	return list, byID
end

-- Chapitres faits et nombre de chapitres d'une campagne, ou nil si elle n'en a pas.
local function CampaignChapters(campaignID)
	local chapterIDs = C_CampaignInfo.GetChapterIDs and C_CampaignInfo.GetChapterIDs(campaignID)
	if not chapterIDs or #chapterIDs == 0 then
		return nil
	end
	local total = #chapterIDs
	local states = Enum and Enum.CampaignState
	if states and C_CampaignInfo.GetState and C_CampaignInfo.GetState(campaignID) == states.Complete then
		return total, total
	end
	local current = C_CampaignInfo.GetCurrentChapterID and C_CampaignInfo.GetCurrentChapterID(campaignID)
	local currentIndex
	for i, chapterID in ipairs(chapterIDs) do
		if chapterID == current then
			currentIndex = i
		end
	end
	local done = 0
	for i, chapterID in ipairs(chapterIDs) do
		local info = C_CampaignInfo.GetCampaignChapterInfo and C_CampaignInfo.GetCampaignChapterInfo(chapterID)
		local rewardQuestID = info and info.rewardQuestID
		if (rewardQuestID and rewardQuestID > 0 and C_QuestLog.IsQuestFlaggedCompleted(rewardQuestID))
			or (currentIndex and i < currentIndex) then
			done = done + 1
		end
	end
	return done, total
end

local function ReadCampaigns()
	local data = {}
	if not (C_CampaignInfo and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
		return data
	end
	local current = GetClientDisplayExpansionLevel and GetClientDisplayExpansionLevel()
	local ids = {} -- { identifiant, vrai si envoyée même pas commencée }
	for _, known in ipairs((KnownCampaigns())) do
		ids[#ids + 1] = { known.id, known.entry.expansion == current }
	end
	for _, id in ipairs(C_CampaignInfo.GetAvailableCampaigns and C_CampaignInfo.GetAvailableCampaigns() or {}) do
		ids[#ids + 1] = { id, true }
	end
	for _, campaign in ipairs(ids) do
		local done, total = CampaignChapters(campaign[1])
		if total and (done > 0 or campaign[2]) then
			data[tostring(campaign[1])] = done .. "/" .. total
		end
	end
	return data
end

-- Nom traduit d'une campagne (repli : nom de la liste, puis numéro).
local function CampaignName(id, entry)
	local info = C_CampaignInfo and C_CampaignInfo.GetCampaignInfo and C_CampaignInfo.GetCampaignInfo(id)
	return (info and info.name ~= "" and info.name) or (entry and entry.name) or ("Campagne n° " .. id)
end

-- « faits/total » coloré : vert si terminée, gris si pas commencée.
local function CampaignProgressText(value)
	local done, total = tostring(value or ""):match("^(%d+)/(%d+)$")
	if not done then
		return nil
	end
	done, total = tonumber(done), tonumber(total)
	local color = (done >= total and "|cff40ff40") or (done == 0 and "|cff999999") or "|cffffffff"
	return color .. done .. "/" .. total .. "|r"
end

local READERS = { V = ReadVault, C = ReadCrests, R = ReadResources, F = ReadFactions, P = ReadRunes,
	A = ReadActivities, M = ReadMail, W = ReadWeekly, S = ReadCampaigns }

local function ReadOwn()
	local sections = {}
	for _, section in ipairs(SECTIONS) do
		local ok, data = pcall(READERS[section]) -- une API qui change ne doit pas tout bloquer
		sections[section] = ok and data or {}
	end
	return sections
end

-- SYNCHRO ---------------------------------------------------------------------------------

local function SectionItems(data)
	local items = {}
	for k, v in pairs(data) do
		items[#items + 1] = k .. "=" .. v
	end
	table.sort(items)
	return items
end

-- Envoie une section (fragmentée pour tenir dans un message) à target, sinon aux connectés.
local function SendSection(token, key, section, items, target)
	local header = string.format("SUIVI:%s:%s:%s:N:", token, key, section)
	local budget = (P.MAX_MESSAGE_LENGTH or 255) - #header
	local chunks, current, used = {}, {}, 0
	for _, item in ipairs(items) do
		local cost = #item + (#current > 0 and 1 or 0)
		if #current > 0 and used + cost > budget then
			chunks[#chunks + 1] = current
			current, used, cost = {}, 0, #item
		end
		current[#current + 1] = item
		used = used + cost
	end
	chunks[#chunks + 1] = current -- au moins un fragment, même vide
	for i, chunk in ipairs(chunks) do
		P.WhisperOnline(string.format("SUIVI:%s:%s:%s:%s:%s", token, key, section, i == 1 and "N" or "+",
			table.concat(chunk, ",")), target)
	end
end

-- Envoie les données du personnage joué : tout à target (rencontre), sinon aux clients
-- connectés les seules sections modifiées depuis le dernier envoi.
-- Sauvegarde les données du personnage joué, datées (pour « Tous les personnages » sur ses
-- autres clients et après déconnexion).
local function StoreOwn(sections)
	local now = GetServerTime()
	local times = {}
	for section in pairs(sections) do
		times[section] = now
	end
	received[P.GetCharKey()] = { sections = sections, at = now, times = times }
end

local function SendAll(target)
	local own = ReadOwn()
	StoreOwn(own)
	local token = P.GetTeamToken and P.GetTeamToken()
	if not token or not P.WhisperOnline then
		return
	end
	local key = P.GetCharKey()
	for section, data in pairs(own) do
		local items = SectionItems(data)
		local text = table.concat(items, ",")
		if target or text ~= lastSent[section] then
			if not target then
				lastSent[section] = text
			end
			SendSection(token, key, section, items, target)
		end
	end
end

local function OnSuiviMessage(rest, sender)
	local key, section, flag, data = strsplit(":", rest or "", 4)
	if not key or not section or not READERS[section] or not (P.IsSender and P.IsSender(sender, key)) then
		return
	end
	local entry = received[key] or { sections = {} }
	received[key] = entry
	if flag == "N" or not entry.sections[section] then
		entry.sections[section] = {}
	end
	local target = entry.sections[section]
	for pair in (data or ""):gmatch("[^,]+") do
		local k, v = pair:match("^([^=]+)=(.*)$")
		if k then
			target[k] = v
		end
	end
	local now = GetServerTime()
	entry.at = now
	entry.times = entry.times or {}
	entry.times[section] = now
	if P.RefreshSuivi then
		P.RefreshSuivi()
	end
end

-- Données d'un personnage : sections et âge (secondes), le personnage joué lu en direct ; nil si
-- rien n'a été reçu de lui.
-- Date (heure serveur) de la dernière réinitialisation hebdomadaire, ou nil si inconnue.
local function LastWeeklyReset()
	local untilNext = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
		and C_DateAndTime.GetSecondsUntilWeeklyReset()
	if untilNext then
		return GetServerTime() + untilNext - 7 * 24 * 3600
	end
end

-- Données d'un personnage : sections, date (heure serveur) et vrai si sa grande chambre forte,
-- d'avant la dernière réinitialisation hebdomadaire, est affichée remise à zéro. Le personnage
-- joué est lu en direct ; nil si rien n'est connu de lui.
local function DataFor(key)
	if key == P.GetCharKey() then
		return ReadOwn(), GetServerTime(), false
	end
	local entry = received[key]
	if not entry then
		return nil
	end
	local sections = entry.sections
	local reset = LastWeeklyReset()
	local copy -- copie modifiée pour l'affichage ; la donnée enregistrée reste intacte
	local function Copy()
		if not copy then
			copy = {}
			for name, data in pairs(sections) do
				copy[name] = data
			end
		end
		return copy
	end

	local vaultReset = false
	local vaultTime = entry.times and entry.times.V or entry.at
	if sections.V and reset and vaultTime and vaultTime < reset then
		local vault = {}
		for cell, value in pairs(sections.V) do
			local threshold = tostring(value):match("/(%d+)$")
			vault[cell] = "0/" .. (threshold or "0")
		end
		Copy().V = vault
		vaultReset = true
	end

	-- Semaine (traques, gouffres, donjons, raids) : vide après la réinitialisation hebdomadaire.
	local weekTime = entry.times and entry.times.W or entry.at
	if sections.W and reset and weekTime and weekTime < reset then
		Copy().W = {}
	end

	-- Activités : toutes remises à zéro après la réinitialisation hebdomadaire, les quotidiennes
	-- après la réinitialisation quotidienne.
	local activityTime = entry.times and entry.times.A or entry.at
	if sections.A and activityTime then
		local weekly = reset and activityTime < reset
		local untilDaily = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
			and C_DateAndTime.GetSecondsUntilDailyReset()
		local daily = untilDaily and activityTime < GetServerTime() + untilDaily - 24 * 3600
		if weekly or daily then
			local activities = {}
			for key, state in pairs(sections.A) do
				if not weekly and not DAILY_KEYS[key] then
					activities[key] = state
				end
			end
			Copy().A = activities
		end
	end
	return copy or sections, entry.at, vaultReset
end

-- PANNEAU ACTIVITÉS -------------------------------------------------------------------------

local titleRequested = {} -- [questID] = true : titre demandé au serveur (une fois par session)

-- Titre traduit d'une quête (demandé au serveur s'il manque ; la fenêtre se rafraîchit à son
-- arrivée, QUEST_DATA_LOAD_RESULT), ou nil.
local function QuestTitle(questID)
	local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
	if not title and not titleRequested[questID] and C_QuestLog.RequestLoadQuestByID then
		titleRequested[questID] = true
		C_QuestLog.RequestLoadQuestByID(questID)
	end
	return title
end

local function EntryTitle(entry)
	return entry.label or (entry.q and QuestTitle(entry.q)) or entry.name
		or (entry.q and MAP_QUEST_NAMES[entry.q]) or (entry.q and ("Quête n° " .. entry.q)) or "?"
end

-- Atlas Blizzard par type de quête (repris de Plumber, ActivityUtil.lua : QuestIconAtlas).
local QUEST_ATLAS = {}
if Enum and Enum.QuestClassification then
	local classes = Enum.QuestClassification
	QUEST_ATLAS = {
		[classes.Normal or -1] = "QuestNormal",
		[classes.Questline or -2] = "QuestNormal",
		[classes.Recurring or -3] = "quest-recurring-available",
		[classes.Meta or -4] = "quest-wrapper-available",
		[classes.Calling or -5] = "Quest-DailyCampaign-Available",
		[classes.Campaign or -6] = "Quest-Campaign-Available",
		[classes.Legendary or -7] = "UI-QuestPoiLegendary-QuestBang",
		[classes.Important or -8] = "importantavailablequesticon",
	}
end

-- Icône (texte) d'une activité : coche si tous les personnages connus l'ont terminée, sinon
-- l'atlas de son type de quête (répétable par défaut, comme les séries).
local function EntryIcon(item)
	local entry = item.activity
	local total = entry.count and #entry.count
	local known, complete = 0, 0
	for _, key in ipairs(item.keys) do
		local state = item.states[key]
		if state then
			known = known + 1
			if (total and state >= total) or (not total and state == 2) then
				complete = complete + 1
			end
		end
	end
	local atlas
	if known > 0 and complete == known then
		atlas = "checkmark-minimal-disabled"
	else
		local questID = entry.q or (entry.pool and entry.pool[1])
		local classification = questID and C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification
			and C_QuestInfoSystem.GetQuestClassification(questID)
		atlas = classification and QUEST_ATLAS[classification] or "quest-recurring-available"
	end
	return CreateAtlasMarkup and CreateAtlasMarkup(atlas, 16, 16) or ""
end

-- Vrai si l'activité est active pour le personnage joué (quête du monde active ou en cours),
-- comme les activités « shownIfActive » de Plumber.
local function IsActiveHere(entry)
	for _, questID in ipairs(entry.q and { entry.q } or entry.pool or {}) do
		if (C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(questID))
			or (C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID)) then
			return true
		end
	end
	return false
end

-- Nom d'une catégorie : libellé fixe, sinon nom traduit de la faction, sinon nom de repli.
local function CategoryTitle(category)
	if category.label then
		return category.label
	end
	if category.map then
		local map = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(category.map)
		return map and map.name or "Lune-d'Argent"
	end
	if category.faction then
		local major = C_MajorFactions and C_MajorFactions.GetMajorFactionData
			and C_MajorFactions.GetMajorFactionData(category.faction)
		if major and major.name then
			return major.name
		end
		local faction = C_Reputation and C_Reputation.GetFactionDataByID
			and C_Reputation.GetFactionDataByID(category.faction)
		if faction and faction.name then
			return faction.name
		end
	end
	return category.name
end

-- Lignes du panneau : en-tête par catégorie, puis ses activités (celles marquées always, ou que
-- l'un des personnages suivis a faite ou commencée), avec l'état de chaque personnage.
local function BuildActivityItems(keys)
	local items = {}

	-- Catégorie dynamique de la carte, en tête comme chez Plumber : quêtes trouvées ici, plus les
	-- quêtes dynamiques signalées par les autres personnages (clés q<id> hors liste fixe).
	local categories = {}
	if ns.DYNAMIC_MAP then
		local questIDs = DynamicQuestIDs()
		for _, key in ipairs(keys) do
			local sections = DataFor(key)
			for entryKey in pairs(sections and sections.A or {}) do
				local questID = tonumber(entryKey:match("^q(%d+)$"))
				if questID and not FIXED_KEYS[entryKey] then
					questIDs[questID] = true
				end
			end
		end
		local entries = {}
		for questID in pairs(questIDs) do
			entries[#entries + 1] = { q = questID, always = true }
		end
		table.sort(entries, function(a, b)
			return EntryTitle(a) < EntryTitle(b)
		end)
		categories[1] = { map = ns.DYNAMIC_MAP, entries = entries }
	end
	for _, category in ipairs(ns.ACTIVITIES or {}) do
		categories[#categories + 1] = category
	end

	for _, category in ipairs(categories) do
		local rows = {}
		for _, entry in ipairs(category.entries) do
			local entryKey, states, any = EntryKey(entry), {}, false
			for _, key in ipairs(keys) do
				local sections = DataFor(key)
				local state = sections and (tonumber(sections.A and sections.A[entryKey]) or 0)
				states[key] = state
				any = any or (state and state > 0)
			end
			if entry.always or any or IsActiveHere(entry) then
				rows[#rows + 1] = { activity = entry, category = category, states = states, keys = keys }
			end
		end
		if #rows > 0 then
			items[#items + 1] = { activityHeader = true, category = category }
			for _, row in ipairs(rows) do
				items[#items + 1] = row
			end
		end
	end
	return items
end

local function ShortName(key)
	local entry = P.db.roster[key]
	return entry and entry.name or key
end

-- Texte de droite d'une activité : personnages qui l'ont faite (vert) ou commencée (jaune) ;
-- pour un compte de quêtes, « nom n/total » (vert si complet).
local function ActivityRightText(item)
	local parts = {}
	local total = item.activity.count and #item.activity.count
	for _, key in ipairs(item.keys) do
		local state = item.states[key]
		if state and state > 0 then
			if total then
				parts[#parts + 1] = (state >= total and "|cff40ff40" or "|cffffd200") .. ShortName(key) .. " "
					.. state .. "/" .. total .. "|r"
			elseif state == 2 then
				parts[#parts + 1] = "|cff40ff40" .. ShortName(key) .. "|r"
			else
				parts[#parts + 1] = "|cffffd200" .. ShortName(key) .. "…|r"
			end
		end
	end
	return table.concat(parts, ", ")
end

local function ActivityTooltip(item)
	local entry = item.activity
	local lines = { EntryTitle(entry) }
	lines[#lines + 1] = "|cff999999" .. CategoryTitle(item.category) .. " — "
		.. (entry.daily and "quotidienne" or "hebdomadaire")
		.. (entry.accountwide and ", pour tout le compte" or "") .. "|r"
	lines[#lines + 1] = " "
	local total = entry.count and #entry.count
	for _, key in ipairs(item.keys) do
		local state = item.states[key]
		local status
		if not state then
			status = "|cff999999inconnu (pas d'infos)|r"
		elseif total then
			status = (state >= total and "|cff40ff40" or "|cffffffff") .. state .. "/" .. total .. "|r"
		elseif state == 2 then
			status = "|cff40ff40faite|r"
		elseif state == 1 then
			status = "|cffffd200en cours|r"
		else
			status = "|cff999999pas faite|r"
		end
		lines[#lines + 1] = P.GetDisplayName(key) .. " : " .. status
	end
	return lines
end

-- FENÊTRE ---------------------------------------------------------------------------------

local function Icon(fileID)
	return fileID and ("|T" .. fileID .. ":14:14|t") or ""
end

local function CharacterName(key)
	local entry = P.db.roster[key] or {}
	local name = P.GetDisplayName(key)
	local color = entry.class and C_ClassColor and C_ClassColor.GetClassColor(entry.class)
	return color and color:WrapTextInColorCode(name) or name
end

-- Cases débloquées de la grande chambre forte et nombre total de cases.
local function VaultSummary(vault)
	local unlocked, total = 0, 0
	for _, value in pairs(vault or {}) do
		local progress, threshold = tostring(value):match("^(%d+)/(%d+)$")
		if progress then
			total = total + 1
			if tonumber(threshold) > 0 and tonumber(progress) >= tonumber(threshold) then
				unlocked = unlocked + 1
			end
		end
	end
	return unlocked, total
end

-- Totaux de la semaine d'un personnage : traques, gouffres (tous paliers et activités du monde),
-- donjons (héroïques + mythiques + mythiques+), boss de raid (toutes difficultés). Repli sur le
-- progrès de la grande chambre forte si le détail manque.
local function WeeklyTotals(sections)
	local week = sections.W or {}
	local totals = { prey = 0, delves = 0, dungeons = 0, raid = 0 }
	for key, value in pairs(week) do
		local count = tonumber(value) or 0
		local prefix = key:sub(1, 1)
		if prefix == "t" then
			totals.prey = totals.prey + count
		elseif prefix == "d" then
			totals.delves = totals.delves + count
		elseif prefix == "r" then
			totals.raid = totals.raid + count
		elseif key == "h" or key == "m" or key == "p" or key == "n" or key == "f" then
			totals.dungeons = totals.dungeons + count
		end
	end
	local vault = sections.V or {}
	local function VaultProgress(cell)
		return tonumber(tostring(vault[cell] or ""):match("^(%d+)/")) or 0
	end
	if totals.raid == 0 then
		totals.raid = VaultProgress("R1")
	end
	if totals.dungeons == 0 then
		totals.dungeons = VaultProgress("M1")
	end
	return totals
end

-- Nombre de la semaine (gris si zéro).
local function WeeklyCount(count)
	return count > 0 and tostring(count) or ("|cff999999" .. count .. "|r")
end

-- Courrier d'un personnage : non lu (bool) et expiration la plus proche (heure serveur ou nil).
local function MailState(sections)
	local mail = sections and sections.M
	if not mail then
		return false, nil
	end
	return tonumber(mail.n) == 1, tonumber(mail.x)
end

local MAIL_ICON = "|TInterface\\Icons\\INV_Letter_15:14:14|t"

-- TABLEAU DU RÉSUMÉ : une ligne d'en-tête puis une ligne par personnage, en colonnes alignées
-- (sans trait) : coffre, runes, écus (du plus bas au plus haut), traques, gouffres, donjons,
-- raids. Les colonnes sont ancrées au bord droit, à la largeur de leur plus long contenu
-- (mesurée à chaque rafraîchissement) ; le nom prend la place restante et se tronque.
local COLUMN_GAP = 12
local memberColumns = {} -- largeurs des colonnes affichées, dans l'ordre (0 = colonne masquée)
local measure -- texte caché servant à mesurer les cellules

-- Colonnes : { en-tête, cellule(sections), id = identifiant stable (tri mémorisé), sort =
-- valeur(sections) pour le tri (nil = sans valeur), tip = { titre, texte } (infobulle de
-- l'en-tête) } ; une colonne d'écu par écu de la saison.
local function MemberColumns()
	local columns = {
		{ "Coffre", function(sections)
			local unlocked, total = VaultSummary(sections.V)
			return total > 0 and ("|cffffd200" .. unlocked .. "/" .. total .. "|r") or ""
		end, id = "vault", sort = function(sections)
			local unlocked, total = VaultSummary(sections.V)
			return total > 0 and unlocked or nil
		end, tip = { "Grande chambre forte", "Cases débloquées / cases au total." } },
		{ "Runes", function(sections)
			local runes = tonumber(sections.P and sections.P.u)
			return (runes and runes > 0) and ("|cff40ff40" .. runes .. "|r") or ""
		end, id = "runes", sort = function(sections)
			return tonumber(sections.P and sections.P.u)
		end, tip = { "Runes de pouvoir", "Points à dépenser." } },
	}
	-- Écus de gauche à droite du plus bas (aventurier) au plus haut (mythique) : la liste est
	-- rangée du plus haut au plus bas, parcourue à l'envers. En-tête : l'icône de l'écu.
	local crests = CrestIDs()
	for i = #crests, 1, -1 do
		local id = crests[i]
		local info = CurrencyInfo(id)
		if info then
			columns[#columns + 1] = { Icon(info.iconFileID), function(sections)
				return tostring(sections.C and sections.C[tostring(id)] or "")
			end, id = "crest" .. id, sort = function(sections)
				return tonumber(sections.C and sections.C[tostring(id)])
			end, tip = { info.name, "Écus possédés." } }
		end
	end
	-- Charges du catalyseur (en-tête : l'icône de la monnaie ; 0 en gris).
	local catalyst = CatalystID()
	local catalystInfo = CurrencyInfo(catalyst)
	if catalystInfo then
		columns[#columns + 1] = { Icon(catalystInfo.iconFileID), function(sections)
			if not sections.R then
				return ""
			end
			return tostring(sections.R["c" .. catalyst] or "|cff9999990|r")
		end, id = "catalyst", sort = function(sections)
			return sections.R and (tonumber(sections.R["c" .. catalyst]) or 0)
		end, tip = { catalystInfo.name, "Charges du catalyseur disponibles." } }
	end
	-- Campagne la plus récente de ns.CAMPAIGNS trouvée en jeu : chapitres faits (détail en infobulle).
	local known = KnownCampaigns()
	local latest = known[#known]
	if latest then
		columns[#columns + 1] = { "Campagne", function(sections)
			return CampaignProgressText(sections.S and sections.S[tostring(latest.id)]) or ""
		end, id = "campaign", sort = function(sections)
			return tonumber(tostring(sections.S and sections.S[tostring(latest.id)] or ""):match("^(%d+)/"))
		end, tip = { CampaignName(latest.id, latest.entry), "Chapitres terminés de la campagne la plus récente ("
			.. latest.entry.patch .. "). Toutes les campagnes : infobulle du personnage." } }
	end
	-- Semaine : nombres (détail en infobulle).
	for _, week in ipairs({
		{ "Traques", "prey", "Traques faites cette semaine (toutes difficultés)." },
		{ "Gouffres", "delves", "Gouffres et activités du monde de la semaine (tous paliers)." },
		{ "Donjons", "dungeons", "Donjons de la semaine : héroïques, mythiques, mythiques+, et "
			.. "normaux / avec suivants comptés à l'entrée." },
		{ "Raids", "raid", "Boss de raid tués cette semaine (toutes difficultés)." },
	}) do
		columns[#columns + 1] = { week[1], function(sections)
			return WeeklyCount(WeeklyTotals(sections)[week[2]])
		end, id = week[2], sort = function(sections)
			return WeeklyTotals(sections)[week[2]]
		end, always = true, tip = { week[1], week[3] } }
	end
	return columns
end

-- TRI PAR COLONNE (clic sur un en-tête, comme Polypode Data) : sortColumn = "name" ou id de
-- colonne, sortDesc = ordre inverse ; gardés dans PolypodeSuiviDB. Sans tri choisi : ordre de
-- l'équipe (leader en tête) ou alphabétique. Premier clic : noms de A à Z, nombres du plus grand
-- au plus petit ; clic suivant sur la même colonne : ordre inverse. Sans valeur : toujours en bas.
local SORT_UP = "|TInterface\\Buttons\\Arrow-Up-Up:12:12:0:-2|t"
local SORT_DOWN = "|TInterface\\Buttons\\Arrow-Down-Up:12:12:0:2|t"

-- Lettres accentuées (UTF-8) ramenées à leur lettre de base, pour trier les noms sans accents.
local ACCENT_MAP = {}
for base, letters in pairs({ a = "àáâãäåÀÁÂÃÄÅ", c = "çÇ", e = "èéêëÈÉÊË", i = "ìíîïÌÍÎÏ", n = "ñÑ",
	o = "òóôõöøÒÓÔÕÖØ", u = "ùúûüÙÚÛÜ", y = "ýÿÝ", ae = "æÆ", oe = "œŒ", ss = "ß" }) do
	for letter in letters:gmatch("[\195\197][\128-\191]") do
		ACCENT_MAP[letter] = base
	end
end

local function Normalize(text)
	return (tostring(text or ""):gsub("[\195\197][\128-\191]", ACCENT_MAP):lower())
end

local function SetSort(column)
	local settings = SuiviSettings()
	if settings.sortColumn == column then
		settings.sortDesc = not settings.sortDesc
	else
		settings.sortColumn = column
		settings.sortDesc = column ~= "name" -- nombres : du plus grand au plus petit
	end
	P.RefreshSuivi()
end

-- Flèche du tri en cours sur l'en-tête de la colonne column, sinon "".
local function SortMark(column)
	local settings = SuiviSettings()
	if column == nil or settings.sortColumn ~= column then
		return ""
	end
	return " " .. (settings.sortDesc and SORT_DOWN or SORT_UP)
end

-- Trie les personnages (items { key = }) selon le tri choisi ; colonne disparue (écus d'une autre
-- saison...) : ordre inchangé.
local function SortItems(items, columns)
	local settings = SuiviSettings()
	local sortColumn = settings.sortColumn
	local column
	for _, candidate in ipairs(columns) do
		if candidate.id == sortColumn and candidate.sort then
			column = candidate
		end
	end
	if sortColumn ~= "name" and not column then
		return
	end
	local values, names = {}, {}
	for _, item in ipairs(items) do
		names[item.key] = Normalize(P.GetDisplayName(item.key))
		if column then
			local sections = DataFor(item.key)
			local ok, value = pcall(column.sort, sections or {})
			values[item.key] = sections and ok and tonumber(value) or nil
		end
	end
	local desc = settings.sortDesc
	table.sort(items, function(a, b)
		if column then
			local va, vb = values[a.key], values[b.key]
			if va ~= vb then
				if va == nil or vb == nil then
					return vb == nil -- sans valeur : toujours en bas
				end
				if desc then
					return va > vb
				end
				return va < vb
			end
		elseif names[a.key] ~= names[b.key] then
			if desc then
				return names[a.key] > names[b.key]
			end
			return names[a.key] < names[b.key]
		end
		return names[a.key] < names[b.key]
	end)
end

-- Nom d'un personnage (enveloppe à gauche : courrier non lu, ou courrier qui expire bientôt).
local function FormatMember(item)
	if item.columnHeader then
		return "|cffffd200Personnage|r" .. SortMark("name")
	end
	local text = CharacterName(item.key)
	local sections = DataFor(item.key)
	if not sections then
		return text .. "  |cff999999pas d'infos (Polypode Suivi absent ou pas encore reçu)|r"
	end
	local unread, expires = MailState(sections)
	if unread or (expires and expires - GetServerTime() < MAIL_WARNING) then
		text = MAIL_ICON .. " " .. text
	end
	return text
end

-- Remplit item.cells de chaque personnage, ajoute la ligne d'en-tête en tête de liste et mesure
-- les colonnes (une colonne vide chez tous est masquée, sauf celles de la semaine).
local function BuildMemberTable(items)
	local columns = MemberColumns()
	SortItems(items, columns)
	local header = { columnHeader = true, cells = {}, tips = {}, ids = {} }
	local used = {}
	for _, item in ipairs(items) do
		local sections = DataFor(item.key)
		item.cells = {}
		for i, column in ipairs(columns) do
			local cell = sections and column[2](sections) or ""
			item.cells[i] = cell
			used[i] = used[i] or cell ~= "" or (column.always and sections ~= nil)
		end
	end
	if not measure then
		measure = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		measure:Hide()
	end
	local function Width(text)
		measure:SetText(text)
		return math.ceil(measure:GetStringWidth())
	end
	wipe(memberColumns)
	for i, column in ipairs(columns) do
		header.cells[i] = "|cffffd200" .. column[1] .. "|r" .. SortMark(column.id)
		header.tips[i] = column.tip
		header.ids[i] = column.sort and column.id
		local width = 0
		if used[i] then
			width = Width(header.cells[i])
			for _, item in ipairs(items) do
				width = math.max(width, Width(item.cells[i]))
			end
		end
		memberColumns[i] = width
	end
	table.insert(items, 1, header)
	return items
end

-- Zone survolable d'une cellule d'en-tête : infobulle de la colonne (hover.tip), et clic = trier
-- par cette colonne (hover.sortID, SetSort).
local function CellHover(row, i)
	row.cellHovers = row.cellHovers or {}
	local hover = row.cellHovers[i]
	if not hover then
		hover = CreateFrame("Button", nil, row)
		hover:SetFrameLevel(row:GetFrameLevel() + 2)
		local highlight = hover:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.08)
		hover:SetScript("OnClick", function(self)
			if self.sortID then
				SetSort(self.sortID)
			end
		end)
		hover:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(self.tip[1])
			GameTooltip:AddLine(self.tip[2], 1, 1, 1, true)
			if self.sortID then
				GameTooltip:AddLine("Clic : trier par cette colonne (clic suivant : ordre inverse)", 0.6, 0.6, 0.6, true)
			end
			GameTooltip:Show()
		end)
		hover:SetScript("OnLeave", GameTooltip_Hide)
		row.cellHovers[i] = hover
	end
	return hover
end

-- Place les cellules d'une ligne du tableau (lignes recyclées : tout est recalculé ici).
local function LayoutCells(row, data)
	row.cells = row.cells or {}
	for _, hover in pairs(row.cellHovers or {}) do
		hover:Hide()
	end
	local cells = data.cells or {}
	local offset = -4
	local firstCell
	for i = #memberColumns, 1, -1 do
		local cell = row.cells[i]
		if not cell then
			cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			cell:SetJustifyH("RIGHT")
			cell:SetWordWrap(false)
			row.cells[i] = cell
		end
		local width = memberColumns[i]
		if width > 0 and data.cells then
			cell:ClearAllPoints()
			cell:SetPoint("RIGHT", row, "RIGHT", offset, 0)
			cell:SetWidth(width)
			cell:SetText(cells[i] or "")
			cell:Show()
			offset = offset - width - COLUMN_GAP
			firstCell = cell
			local tip = data.tips and data.tips[i]
			if tip then
				local hover = CellHover(row, i)
				hover.tip = tip
				hover.sortID = data.ids and data.ids[i] or nil
				hover:ClearAllPoints()
				hover:SetPoint("TOP", row, "TOP")
				hover:SetPoint("BOTTOM", row, "BOTTOM")
				hover:SetPoint("LEFT", cell, "LEFT", -COLUMN_GAP / 2, 0)
				hover:SetPoint("RIGHT", cell, "RIGHT", COLUMN_GAP / 2, 0)
				hover:Show()
			end
		else
			cell:Hide()
		end
	end
	for i = #memberColumns + 1, #row.cells do
		row.cells[i]:Hide()
	end
	return firstCell
end

-- Date d'information en clair : « à l'instant », « il y a n min / h », sinon « du jj/mm à hh:mm ».
local function FormatWhen(at)
	local minutes = math.floor((GetServerTime() - at) / 60)
	if minutes < 1 then
		return "à l'instant"
	elseif minutes < 60 then
		return "il y a " .. minutes .. " min"
	elseif minutes < 24 * 60 then
		return "il y a " .. math.floor(minutes / 60) .. " h"
	end
	return "du " .. date("%d/%m à %H:%M", at)
end

local function MemberTooltip(item)
	local lines = { P.GetDisplayName(item.key) }
	local sections, at, vaultReset = DataFor(item.key)
	if not sections then
		lines[#lines + 1] = "|cff999999Pas d'infos : Polypode Suivi absent chez ce personnage, ou pas encore reçu.|r"
		return lines
	end
	if item.key ~= P.GetCharKey() then
		lines[#lines + 1] = "|cff999999Infos " .. FormatWhen(at) .. "|r"
	end
	if vaultReset then
		lines[#lines + 1] = "|cff999999Grande chambre forte remise à zéro (réinitialisation hebdomadaire "
			.. "depuis ces infos)|r"
	end

	-- Cette semaine : détail par difficulté.
	local week = sections.W or {}
	lines[#lines + 1] = " "
	lines[#lines + 1] = "|cffffd200Cette semaine|r"
	local prey = {}
	for difficulty, label in ipairs({ "Normal", "Difficile", "Cauchemar" }) do
		prey[#prey + 1] = label .. " " .. (tonumber(week["t" .. difficulty]) or 0) .. "/4"
	end
	lines[#lines + 1] = "  Traque : " .. table.concat(prey, ", ")
	local delves = {}
	for key, count in pairs(week) do
		local tier = tonumber(key:match("^d(%d+)$"))
		if tier then
			delves[#delves + 1] = { tier = tier, count = count }
		end
	end
	table.sort(delves, function(a, b)
		return a.tier > b.tier
	end)
	local delveParts = {}
	for _, delve in ipairs(delves) do
		delveParts[#delveParts + 1] = (delve.tier > 1 and ("palier " .. delve.tier) or "palier 1 / activités du monde")
			.. " ×" .. delve.count
	end
	lines[#lines + 1] = "  Gouffres : " .. (#delveParts > 0 and table.concat(delveParts, ", ") or "aucun")
	local dungeons = {}
	for key, label in pairs({ n = "normal*", f = "avec suivants*", h = "héroïque", m = "mythique",
		p = "mythique+" }) do
		if week[key] then
			dungeons[#dungeons + 1] = label .. " ×" .. week[key]
		end
	end
	table.sort(dungeons)
	local keys = week.k and tostring(week.k):gsub("%.", ", ")
	lines[#lines + 1] = "  Donjons : " .. (#dungeons > 0 and table.concat(dungeons, ", ") or "aucun")
		.. (keys and (" (clés " .. keys .. ")") or "")
	if week.n or week.f then
		lines[#lines + 1] = "  |cff999999* compté à l'entrée dans le donjon (non suivi par WoW)|r"
	end
	local raids = {}
	for _, difficultyID in ipairs({ 17, 14, 15, 16 }) do
		local count = week["r" .. difficultyID]
		if count then
			local name = GetDifficultyInfo and GetDifficultyInfo(difficultyID)
			raids[#raids + 1] = (name or ("difficulté " .. difficultyID)) .. " ×" .. count
		end
	end
	lines[#lines + 1] = "  Raid (boss) : " .. (#raids > 0 and table.concat(raids, ", ") or "aucun")

	-- Courrier : non lu, puis le dernier relevé de la boîte aux lettres (nombre, expiration).
	local unread, expires = MailState(sections)
	local mail = sections.M
	if unread or (mail and mail.s) then
		lines[#lines + 1] = " "
		lines[#lines + 1] = MAIL_ICON .. " " .. (unread and "|cffffd200Courrier non lu|r" or "|cffffd200Courrier|r")
		if mail and mail.s then
			lines[#lines + 1] = "  " .. (tonumber(mail.u) or 0) .. " non lu(s) sur " .. (tonumber(mail.t) or 0)
				.. " courrier(s)"
			if expires then
				local soon = expires - GetServerTime() < MAIL_WARNING
				lines[#lines + 1] = "  " .. (soon and "|cffff4040" or "") .. "Expiration la plus proche : le "
					.. date("%d/%m à %H:%M", expires) .. (soon and "|r" or "")
			end
			lines[#lines + 1] = "  |cff999999Relevé à la boîte aux lettres " .. FormatWhen(tonumber(mail.s)) .. "|r"
		else
			lines[#lines + 1] = "  |cff999999Nombre et expiration : ouvrez la boîte aux lettres de ce personnage|r"
		end
	end

	-- Grande chambre forte : une ligne par rangée, cases atteintes en vert.
	lines[#lines + 1] = " "
	lines[#lines + 1] = "|cffffd200Grande chambre forte|r"
	for _, row in ipairs(VAULT_ROWS) do
		local cells = {}
		for i = 1, 3 do
			local value = sections.V and sections.V[row[1] .. i]
			if value then
				local progress, threshold = value:match("^(%d+)/(%d+)$")
				local done = progress and tonumber(threshold) > 0 and tonumber(progress) >= tonumber(threshold)
				cells[#cells + 1] = done and ("|cff40ff40" .. value .. "|r") or value
			end
		end
		if #cells > 0 then
			lines[#lines + 1] = "  " .. row[3] .. " : " .. table.concat(cells, "   ")
		end
	end

	-- Écus.
	local crestLines = {}
	for _, id in ipairs(CrestIDs()) do
		local quantity = sections.C and sections.C[tostring(id)]
		local info = CurrencyInfo(id)
		if quantity and info then
			crestLines[#crestLines + 1] = "  " .. Icon(info.iconFileID) .. " " .. info.name .. " : " .. quantity
		end
	end
	if #crestLines > 0 then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd200Amélioration d'objet|r"
		for _, line in ipairs(crestLines) do
			lines[#lines + 1] = line
		end
	end

	-- Ressources possédées.
	local resourceLines = {}
	for _, resource in ipairs(RESOURCES) do
		local kind, id = resource[1], resource[2]
		local quantity = sections.R and sections.R[kind .. id]
		if quantity then
			local name, icon
			if kind == "c" then
				local info = CurrencyInfo(id)
				name, icon = info and info.name, info and info.iconFileID
			else
				name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
				icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
			end
			resourceLines[#resourceLines + 1] = "  " .. Icon(icon) .. " " .. (name or ("n° " .. id)) .. " : " .. quantity
		end
	end
	if #resourceLines > 0 then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd200Ressources|r"
		for _, line in ipairs(resourceLines) do
			lines[#lines + 1] = line
		end
	end

	-- Renommées (option showFactions).
	local factionLines = {}
	for id, level in pairs(SuiviSettings().showFactions and sections.F or {}) do
		local faction = C_MajorFactions and C_MajorFactions.GetMajorFactionData
			and C_MajorFactions.GetMajorFactionData(tonumber(id))
		factionLines[#factionLines + 1] = "  " .. (faction and faction.name or ("Faction " .. id))
			.. " : renom " .. level
	end
	if #factionLines > 0 then
		table.sort(factionLines)
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd200Renommées|r"
		for _, line in ipairs(factionLines) do
			lines[#lines + 1] = line
		end
	end

	-- Runes de pouvoir.
	local runes = tonumber(sections.P and sections.P.u)
	if runes then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd200Runes de pouvoir|r"
		lines[#lines + 1] = "  " .. runes .. " point(s) à dépenser"
			.. ((sections.P.b == 1 or sections.P.b == "1") and " |cff40ff40(une rune achetable)|r" or "")
	end

	-- Campagnes : par extension, « patch – nom : faits/total », l'extension en cours d'abord (toutes
	-- ses campagnes), puis les précédentes de la plus récente à la plus ancienne (option
	-- showOldCampaigns : celles en cours, et le nombre de terminées), puis celles hors liste.
	local campaigns = sections.S
	if campaigns and next(campaigns) then
		local known, byID = KnownCampaigns()
		local current = GetClientDisplayExpansionLevel and GetClientDisplayExpansionLevel()
		local groups, order = {}, {}
		for _, campaign in ipairs(known) do
			local value = campaigns[tostring(campaign.id)]
			local done, total = tostring(value or ""):match("^(%d+)/(%d+)$")
			local entry = campaign.entry
			local isCurrent = entry.expansion == current
			if done and (isCurrent or SuiviSettings().showOldCampaigns) then
				local group = groups[entry.expansion]
				if not group then
					group = { expansion = entry.expansion, lines = {}, finished = 0 }
					groups[entry.expansion] = group
					order[#order + 1] = group
				end
				done, total = tonumber(done), tonumber(total)
				if isCurrent or (done > 0 and done < total) then
					group.lines[#group.lines + 1] = "    " .. entry.patch .. " – " .. CampaignName(campaign.id, entry)
						.. " : " .. CampaignProgressText(value)
				elseif done >= total then
					group.finished = group.finished + 1
				end
			end
		end
		table.sort(order, function(a, b)
			if (a.expansion == current) ~= (b.expansion == current) then
				return a.expansion == current
			end
			return a.expansion > b.expansion
		end)
		local campaignLines = {}
		for _, group in ipairs(order) do
			if #group.lines > 0 or group.finished > 0 then
				campaignLines[#campaignLines + 1] = "  " .. (_G["EXPANSION_NAME" .. group.expansion]
					or ("Extension " .. group.expansion))
				for _, line in ipairs(group.lines) do
					campaignLines[#campaignLines + 1] = line
				end
				if group.finished > 0 then
					campaignLines[#campaignLines + 1] = "    |cff40ff40" .. group.finished .. " campagne(s) terminée(s)|r"
				end
			end
		end
		local others = {}
		for id, value in pairs(campaigns) do
			local progress = tonumber(id) and not byID[tonumber(id)] and CampaignProgressText(value)
			if progress then
				others[#others + 1] = "    " .. CampaignName(tonumber(id)) .. " : " .. progress
			end
		end
		if #others > 0 then
			table.sort(others)
			campaignLines[#campaignLines + 1] = "  Autres campagnes"
			for _, line in ipairs(others) do
				campaignLines[#campaignLines + 1] = line
			end
		end
		if #campaignLines > 0 then
			lines[#lines + 1] = " "
			lines[#lines + 1] = "|cffffd200Campagnes (chapitres)|r"
			for _, line in ipairs(campaignLines) do
				lines[#lines + 1] = line
			end
		end
	end

	-- Exploration : gouffres, donjons et raids où le personnage est entré cette semaine.
	local explored = { g = {}, d = {}, r = {} }
	local anyExplored = false
	for key, count in pairs(week) do
		local kind, instanceID, difficultyID = key:match("^x(%a)(%d+)%-(%d+)$")
		if kind and explored[kind] then
			instanceID, difficultyID = tonumber(instanceID), tonumber(difficultyID)
			local name = GetRealZoneText and GetRealZoneText(instanceID)
			local text = (name and name ~= "") and name or ("instance " .. instanceID)
			local difficulty = kind ~= "g" and GetDifficultyInfo and GetDifficultyInfo(difficultyID)
			if difficulty then
				text = text .. " (" .. difficulty .. ")"
			end
			count = tonumber(count) or 1
			explored[kind][#explored[kind] + 1] = count > 1 and (text .. " ×" .. count) or text
			anyExplored = true
		end
	end
	if anyExplored then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cffffd200Exploration|r"
		for _, group in ipairs({ { "g", "Gouffres" }, { "d", "Donjons" }, { "r", "Raids" } }) do
			local names = explored[group[1]]
			if #names > 0 then
				table.sort(names)
				lines[#lines + 1] = "  " .. group[2] .. " : " .. table.concat(names, ", ")
			end
		end
		lines[#lines + 1] = "  |cff999999Noté à l'entrée, cette semaine (retour dans les 2 h non recompté)|r"
	end
	return lines
end

-- Membres de l'équipe sélectionnée (leader en tête), ou tous les personnages sauvegardés encore
-- dans le roster (option showAll) ; texte d'en-tête et de liste vide.
local function BuildItems()
	if ShowAll() then
		local set = { [P.GetCharKey()] = true }
		for key in pairs(received) do
			if P.GetCharacter(key) then
				set[key] = true
			end
		end
		return P.SortedKeyItems(set), "Suivi : tous les personnages", "Aucune information enregistrée."
	end
	local team = P.GetSelectedTeam()
	if not team then
		return {}, "Suivi de l'équipe", "Sélectionnez une équipe."
	end
	local leader = P.GetTeamLeader(team)
	local items = P.SortedKeyItems(P.GetTeamMembers(team) or {}, function(key)
		return key == leader
	end)
	return items, "Suivi de l'équipe « " .. team .. " »", "Aucun personnage dans l'équipe."
end

local function Build()
	frame = CreateFrame("Frame", "PolypodeSuiviFrame", UIParent, "BackdropTemplate")
	local settings = SuiviSettings()
	frame:SetSize(math.max(settings.width or DEFAULTS.width, MIN_WIDTH),
		math.max(settings.height or DEFAULTS.height, MIN_HEIGHT))
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
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
	tinsert(UISpecialFrames, "PolypodeSuiviFrame") -- Échap ferme la fenêtre

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Suivi de l'équipe")
	frame.TitleText = title

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -4, -4)
	frame.CloseButton = closeBtn

	-- Bouton « Activités » / « Résumé » (en haut à droite) : bascule entre le résumé par
	-- personnage et le panneau des activités (option activityMode).
	local activityBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	activityBtn:SetSize(80, 20)
	activityBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
	activityBtn:SetScript("OnClick", function()
		SuiviSettings().activityMode = not SuiviSettings().activityMode
		P.RefreshSuivi()
	end)
	activityBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(SuiviSettings().activityMode and "Résumé" or "Activités")
		GameTooltip:AddLine(SuiviSettings().activityMode
			and "Revient au résumé par personnage (coffre, écus, ressources, runes)."
			or "Affiche les activités de l'extension (gouffres, traque, factions...) avec, à droite de "
				.. "chacune, les personnages qui l'ont faite (vert) ou commencée (jaune).", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	activityBtn:SetScript("OnLeave", GameTooltip_Hide)
	frame.activityButton = activityBtn
	P.ui.suiviActivityButton = activityBtn

	-- Bouton Options (barre de titre, à gauche, comme dans la fenêtre Polypode) : ouvre
	-- Options > AddOns > Polypode > Suivi, et ferme la fenêtre pour ne pas masquer le panneau.
	local optionsBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	optionsBtn:SetSize(70, 20)
	optionsBtn:SetPoint("TOPLEFT", 6, -3)
	optionsBtn:SetText("Options")
	optionsBtn:SetScript("OnClick", function()
		if settingsCategory and Settings and Settings.OpenToCategory then
			frame:Hide()
			Settings.OpenToCategory(settingsCategory:GetID())
		end
	end)
	optionsBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Options")
		GameTooltip:AddLine("Ouvre les options du suivi (Options > AddOns > Polypode > Suivi).", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	optionsBtn:SetScript("OnLeave", GameTooltip_Hide)
	P.ui.suiviOptionsButton = optionsBtn

	-- Case « Tous les personnages », à droite du bouton Options (option showAll, aussi dans le
	-- panneau d'options).
	local allCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	allCheck:SetSize(22, 22)
	allCheck:SetPoint("LEFT", optionsBtn, "RIGHT", 8, 0)
	local allText = allCheck.Text or allCheck.text
	if allText then
		allText:SetText("Tous les personnages")
		allText:SetFontObject("GameFontHighlightSmall")
	end
	allCheck:SetScript("OnClick", function(self)
		SuiviSettings().showAll = self:GetChecked() and true or false
		P.RefreshSuivi()
	end)
	allCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Tous les personnages")
		GameTooltip:AddLine("Cochée : tous les personnages dont des informations ont été enregistrées "
			.. "(avec leur date). Décochée : les membres de l'équipe sélectionnée.", 1, 1, 1, true)
		if IsSolo() then
			GameTooltip:AddLine("Imposée en mode solo (pas d'équipe).", 1, 0.25, 0.25, true)
		end
		GameTooltip:Show()
	end)
	allCheck:SetScript("OnLeave", GameTooltip_Hide)
	allCheck:SetMotionScriptsWhileDisabled(true) -- infobulle aussi grisée (mode solo)
	frame.allCheck = allCheck

	listPanel = P.CreatePanel(frame, "")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMRIGHT", -12, 12)

	-- Poignée de redimensionnement (coin bas-droit, comme la fenêtre de Polypode), au-dessus de
	-- la liste ; taille gardée par personnage.
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
		local current = SuiviSettings()
		current.width, current.height = frame:GetSize()
	end)
	frame.resizeGrip = grip
	-- Une liste pour les deux panneaux : membres (résumé) ou en-têtes et lignes d'activités.
	P.CreateScrollList(listPanel, function(data)
		if data.activityHeader then
			return "|cffffd200" .. CategoryTitle(data.category) .. "|r"
		elseif data.activity then
			return "  " .. EntryIcon(data) .. " " .. EntryTitle(data.activity)
				.. (data.activity.daily and " |cff999999(quotidienne)|r" or "")
		end
		return FormatMember(data)
	end, nil, {
		-- Clic sur la ligne d'en-tête (hors colonnes : leurs en-têtes ont leur propre clic) : tri
		-- par nom.
		onClick = function(data)
			if data.columnHeader then
				SetSort("name")
			end
		end,
		tooltip = function(data)
			if data.columnHeader then
				return nil -- pas d'infobulle sur la ligne d'en-tête
			elseif data.activityHeader then
				return { CategoryTitle(data.category) }
			elseif data.activity then
				return ActivityTooltip(data)
			end
			return MemberTooltip(data)
		end,
		-- Texte de droite des activités (personnages) ; colonnes du tableau pour le résumé.
		decorate = function(row, data)
			local firstCell = LayoutCells(row, data)
			if not row.rightText then
				row.rightText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
				row.rightText:SetPoint("LEFT", row, "CENTER", 0, 0)
				row.rightText:SetPoint("RIGHT", -4, 0)
				row.rightText:SetJustifyH("RIGHT")
				row.rightText:SetWordWrap(false)
			end
			if data.activity then
				row.rightText:SetText(ActivityRightText(data))
				row.rightText:Show()
				row.text:SetPoint("RIGHT", row.rightText, "LEFT", -6, 0)
			elseif firstCell then
				row.rightText:Hide()
				row.text:SetPoint("RIGHT", firstCell, "LEFT", -COLUMN_GAP, 0)
			else
				row.rightText:Hide()
				row.text:SetPoint("RIGHT", -4, 0)
			end
		end,
	})

	P.ui.suiviFrame = frame
	P.ui.suiviPanel = listPanel
	P.ui.suiviAllCheck = allCheck

	P.SkinFrame(frame)
	P.SkinPanel(listPanel)
	if P.SkinButton then
		P.SkinButton(optionsBtn)
		P.SkinButton(activityBtn)
	end
	if P.SkinCheckBox then -- Polypode 0.53.3
		P.SkinCheckBox(allCheck)
	end
	-- Libellé écarté de la case (après le skin : EllesmereUI le collait à son cadre).
	if allText then
		allText:ClearAllPoints()
		allText:SetPoint("LEFT", allCheck, "RIGHT", 5, 0)
	end
end

-- Remplit la liste, si la fenêtre est ouverte.
function P.RefreshSuivi()
	if not frame or not frame:IsShown() then
		return
	end
	frame.allCheck:SetChecked(ShowAll()) -- peut avoir changé dans les options
	frame.allCheck:SetEnabled(not IsSolo()) -- imposée (grisée) en mode solo
	local allText = frame.allCheck.Text or frame.allCheck.text
	if allText then
		allText:SetFontObject(IsSolo() and "GameFontDisableSmall" or "GameFontHighlightSmall")
	end
	local items, header, emptyText = BuildItems()
	if SuiviSettings().activityMode then
		frame.activityButton:SetText("Résumé")
		local keys = {}
		for i, item in ipairs(items) do
			keys[i] = item.key
		end
		items = #keys > 0 and BuildActivityItems(keys) or {}
		header = header:gsub("^Suivi", "Activités")
		emptyText = #keys > 0 and "Aucune activité à afficher." or emptyText
	else
		frame.activityButton:SetText("Activités")
		if #items > 0 then
			items = BuildMemberTable(items)
		end
	end
	-- Saison en cours, et avertissement si les listes reprises de Plumber ne la couvrent pas.
	local season = SeasonText()
	if season then
		header = header .. "  |cff999999· " .. season .. "|r"
	end
	if ListsOutdated() then
		header = header .. "  |cffff8000· listes à mettre à jour|r"
	end
	listPanel.header:SetText(header)
	listPanel.emptyText:SetText(emptyText)
	P.SetListData(listPanel, items)
end

-- Ouvre / ferme la fenêtre (bouton « Suivi », /poly suivi).
function P.ToggleSuivi()
	if not frame then
		Build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		P.RefreshSuivi()
	end
end

-- INTÉGRATION À POLYPODE -----------------------------------------------------------------

if P.AddTitleButton then
	P.AddTitleButton({
		text = "Suivi",
		width = 60,
		onClick = function()
			P.ToggleSuivi()
		end,
		tooltip = {
			"Suivi de l'équipe",
			"Grande chambre forte, écus, ressources, renommées et runes de pouvoir de chaque membre de "
				.. "l'équipe sélectionnée (détail au survol d'un personnage).",
		},
		onCreate = function(button)
			P.ui.suiviButton = button
		end,
	})
end

if P.RegisterSlashCommand then
	P.RegisterSlashCommand("suivi", P.ToggleSuivi, "suivi de l'équipe (coffre, écus, ressources, renommées, runes)")
end

-- Personnage supprimé dans Polypode (Maj + clic dans « Personnages disponibles », ou sur un
-- autre client) : ses données de suivi sont oubliées ici aussi (Polypode 0.53.0).
if P.RegisterCharacterData then
	P.RegisterCharacterData({
		name = "Polypode Suivi",
		describe = function(key)
			if received[key] and key ~= P.GetCharKey() then
				return "chambre forte, écus, ressources, renommées, activités et campagnes relevés"
			end
		end,
		remove = function(key)
			if key ~= P.GetCharKey() then
				received[key] = nil
				P.RefreshSuivi()
			end
		end,
	})
end

if P.RegisterMessageHandler then
	P.RegisterMessageHandler("SUIVI", OnSuiviMessage)
	P.RegisterPeerCallback(function(sender)
		SendAll(sender)
	end)
end

-- Équipe sélectionnée changée, synchro : la fenêtre suit P.RefreshUI.
hooksecurefunc(P, "RefreshUI", function()
	P.RefreshSuivi()
end)

-- OPTIONS : sous-catégorie « Suivi » du panneau de Polypode (P.optionsCategory, créée à son
-- PLAYER_LOGIN), ou catégorie « Polypode Suivi » à part si elle manque.
local function BuildSettingsPanel()
	if not (Settings and Settings.RegisterProxySetting) then
		return
	end
	local category
	if P.optionsCategory and Settings.RegisterVerticalLayoutSubcategory then
		category = Settings.RegisterVerticalLayoutSubcategory(P.optionsCategory, "Suivi")
	else
		category = Settings.RegisterVerticalLayoutCategory("Polypode Suivi")
	end
	local allSetting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_SHOW_ALL",
		Settings.VarType.Boolean, "Tous les personnages", DEFAULTS.showAll,
		function()
			return ShowAll()
		end,
		function(value)
			if IsSolo() then
				return -- imposée en mode solo : la case reste cochée
			end
			SuiviSettings().showAll = value
			P.RefreshSuivi()
		end)
	Settings.CreateCheckbox(category, allSetting,
		"La fenêtre « Suivi » liste tous les personnages dont des informations ont été enregistrées "
		.. "(avec leur date) au lieu des membres de l'équipe sélectionnée. Même case que dans la barre "
		.. "de titre de la fenêtre. Toujours cochée en mode solo de Polypode. Réglage propre à ce personnage.")

	local campaignSetting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_SHOW_OLD_CAMPAIGNS",
		Settings.VarType.Boolean, "Campagnes des extensions précédentes", DEFAULTS.showOldCampaigns,
		function()
			return SuiviSettings().showOldCampaigns
		end,
		function(value)
			SuiviSettings().showOldCampaigns = value
		end)
	Settings.CreateCheckbox(category, campaignSetting,
		"Dans l'infobulle de chaque personnage, ajoute aux campagnes de l'extension en cours celles des "
		.. "extensions précédentes (depuis Battle for Azeroth) : les campagnes commencées mais pas finies, "
		.. "et le nombre de campagnes terminées par extension. Réglage propre à ce personnage.")

	local setting = Settings.RegisterProxySetting(category, "POLYPODE_SUIVI_SHOW_FACTIONS",
		Settings.VarType.Boolean, "Afficher les renommées", DEFAULTS.showFactions,
		function()
			return SuiviSettings().showFactions
		end,
		function(value)
			SuiviSettings().showFactions = value
		end)
	Settings.CreateCheckbox(category, setting,
		"Dans la fenêtre « Suivi de l'équipe », détaille les renommées de l'extension de chaque "
		.. "membre dans son infobulle. Inutile avec un seul compte Battle.net : les renommées y sont "
		.. "communes à tous les personnages. Réglage propre à ce personnage.")
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

local setup = CreateFrame("Frame")
setup:RegisterEvent("ADDON_LOADED")
setup:RegisterEvent("PLAYER_LOGIN")
setup:RegisterEvent("PLAYER_LOGOUT") -- dernières données du personnage joué, sauvegardées
setup:RegisterEvent("QUEST_DATA_LOAD_RESULT") -- titre d'activité reçu du serveur
setup:SetScript("OnEvent", function(_, event, addonName)
	if event == "ADDON_LOADED" and addonName == "Polypode_Suivi" then
		PolypodeSuiviData = PolypodeSuiviData or {}
		received = PolypodeSuiviData
		PolypodeSuiviDB = PolypodeSuiviDB or {}
		-- 1.2.1 : renommées décochées par défaut ; la 1.1.0 avait enregistré « cochée » partout,
		-- remise une seule fois à la nouvelle valeur par défaut.
		if not PolypodeSuiviDB.factionsDefaultOff then
			PolypodeSuiviDB.showFactions = nil
			PolypodeSuiviDB.factionsDefaultOff = true
		end
		for key, value in pairs(DEFAULTS) do
			if PolypodeSuiviDB[key] == nil then
				PolypodeSuiviDB[key] = value
			end
		end
	elseif event == "PLAYER_LOGIN" then
		-- Différé d'une image : Polypode crée P.optionsCategory à son propre PLAYER_LOGIN.
		C_Timer.After(0, BuildSettingsPanel)
		-- Historique des clés mythiques+ (C_MythicPlus.GetRunHistory) : chargé à la demande.
		if C_MythicPlus and C_MythicPlus.RequestMapInfo then
			C_MythicPlus.RequestMapInfo()
		end
	elseif event == "QUEST_DATA_LOAD_RESULT" then
		P.RefreshSuivi()
	elseif event == "PLAYER_LOGOUT" then
		StoreOwn(ReadOwn())
	end
end)

-- Changements du personnage joué : envoi différé des sections modifiées, et fenêtre à jour.
local events = CreateFrame("Frame")
for _, event in ipairs({
	"PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE", "CURRENCY_DISPLAY_UPDATE",
	"MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "TRAIT_CONFIG_UPDATED", "BAG_UPDATE_DELAYED",
	"QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", -- activités
	"UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", -- courrier
	"CHALLENGE_MODE_COMPLETED", "ENCOUNTER_END", -- semaine (clés, boss)
}) do
	if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
		pcall(events.RegisterEvent, events, event)
	end
end
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		CountDungeonEntry() -- donjon normal / avec suivants : compté à l'entrée
	end
	if event == "MAIL_INBOX_UPDATE" then
		ScanMailbox() -- boîte ouverte : relevé immédiat, envoyé avec le reste
	end
	if sendPending then
		return
	end
	sendPending = true
	C_Timer.After(SEND_DELAY, function()
		sendPending = nil
		SendAll()
		P.RefreshSuivi()
	end)
end)
