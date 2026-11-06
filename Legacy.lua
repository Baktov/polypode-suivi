-- Polypode Suivi: Legacy — Héritage de WoW Forever : choix dans les arbres, piste de récompenses, défis les plus rentables

local _, ns = ...
local L = ns.L

-- HÉRITAGE, compléments de la section H (lue par ReadLegacy dans Suivi.lua) :
--   ns.ReadLegacyNodes(data) — choix du personnage joué dans les trois arbres, ajoutés à la section
--     H (donc synchronisés) : n<nodeID> = rang, ou « rang-entryID » pour un nœud à choix ;
--   ns.LegacyNodeLines(legacy, treeID) — lignes « Nom 2/3 » de ces choix pour l'infobulle d'un
--     personnage (noms lus sur place dans l'arbre du personnage joué, mis en cache) ;
--   ns.AddLegacyRewardLines(tooltip) — piste de récompenses (commune au compte, lue sur place) :
--     prochains paliers du renom de la faction d'Héritage, infobulle de l'en-tête « Héritage » ;
--   ns.AddLegacyChallengeLines(tooltip) — défis pas encore faits qui rapportent le plus de points
--     (C_Traits.GetTraitCurrencyForAchievement), infobulle de l'en-tête « Défis » ; liste calculée
--     au premier survol, oubliée à chaque haut fait obtenu.
-- Fichier chargé avant Suivi.lua ; rien sur Retail (constantes de l'Héritage absentes).

if (tonumber((select(4, GetBuildInfo()))) or 0) >= 100000 then return end

local REWARD_LINES = 3 -- paliers montrés dans l'infobulle « Héritage »
local CHALLENGE_LINES = 10 -- défis montrés dans l'infobulle « Défis »

local cache = { names = {}, nodeTree = nil, challenges = nil }

local function Consts()
	return Constants and Constants.LegacyConsts
end

local function TreeIDs()
	local consts = Consts()
	if not consts then
		return {}
	end
	return { consts.LEGACY_TREE_PROFESSIONS_ID, consts.LEGACY_TREE_ADVENTURE_ID, consts.LEGACY_TREE_PROGRESSION_ID }
end

local function TraitsReady()
	return C_Traits and C_Traits.GetConfigIDByTreeID and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
end

-- CHOIX DANS LES ARBRES -------------------------------------------------------------------

function ns.ReadLegacyNodes(data)
	if not TraitsReady() then
		return
	end
	for _, treeID in ipairs(TreeIDs()) do
		local configID = C_Traits.GetConfigIDByTreeID(treeID)
		if configID then
			for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
				local info = C_Traits.GetNodeInfo(configID, nodeID)
				-- Rangs achetés seulement : les nœuds donnés d'office ne coûtent rien et ne disent rien.
				if info and (info.ranksPurchased or 0) > 0 and (info.activeRank or 0) > 0 then
					local value = tostring(info.activeRank)
					if info.entryIDs and #info.entryIDs > 1 and info.activeEntry and info.activeEntry.entryID then
						value = value .. "-" .. info.activeEntry.entryID
					end
					data["n" .. nodeID] = value
				end
			end
		end
	end
end

-- Arbre de chaque nœud (les identifiants de nœud sont propres à un arbre).
local function NodeTree(nodeID)
	if not cache.nodeTree then
		if not TraitsReady() then
			return nil
		end
		cache.nodeTree = {}
		for _, treeID in ipairs(TreeIDs()) do
			for _, id in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
				cache.nodeTree[id] = treeID
			end
		end
	end
	return cache.nodeTree[nodeID]
end

-- Nom et rang maximum d'un nœud (entrée choisie, sinon la première), lus dans l'arbre du
-- personnage joué ; gardés en cache une fois le nom trouvé.
local function NodeLabel(nodeID, entryID)
	local key = nodeID .. "-" .. (entryID or "")
	if cache.names[key] then
		return cache.names[key].name, cache.names[key].max
	end
	local treeID = NodeTree(nodeID)
	local configID = treeID and C_Traits.GetConfigIDByTreeID(treeID)
	if not configID then
		return nil
	end
	local info = C_Traits.GetNodeInfo(configID, nodeID)
	entryID = entryID or (info and ((info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])))
	local entry = entryID and C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID)
	local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo
		and C_Traits.GetDefinitionInfo(entry.definitionID)
	local name = definition and definition.overrideName
	if (not name or name == "") and definition and definition.spellID and C_Spell and C_Spell.GetSpellName then
		name = C_Spell.GetSpellName(definition.spellID)
	end
	local max = (info and info.maxRanks and info.maxRanks > 0 and info.maxRanks) or (entry and entry.maxRanks)
	if name and name ~= "" then
		cache.names[key] = { name = name, max = max }
		return name, max
	end
	return nil, max
end

function ns.LegacyNodeLines(legacy, treeID)
	local lines = {}
	for k, v in pairs(legacy or {}) do
		local nodeID = tonumber(k:match("^n(%d+)$"))
		if nodeID and NodeTree(nodeID) == treeID then
			local rank, entryID = tostring(v):match("^(%d+)%-?(%d*)$")
			if rank then -- valeur mal formée (autre version) : ligne ignorée
				local name, max = NodeLabel(nodeID, tonumber(entryID))
				lines[#lines + 1] = string.format("%s %s", name or L["Bonus n° %d"]:format(nodeID),
					max and (rank .. "/" .. max) or rank)
			end
		end
	end
	table.sort(lines)
	return lines
end

-- PISTE DE RÉCOMPENSES --------------------------------------------------------------------

local function RewardName(reward)
	if reward.name and reward.name ~= "" then
		return reward.name
	end
	if reward.itemID and C_Item and C_Item.GetItemNameByID then
		local name = C_Item.GetItemNameByID(reward.itemID)
		if name then
			return name
		end
	end
	if reward.mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
		local name = C_MountJournal.GetMountInfoByID(reward.mountID)
		if name then
			return name
		end
	end
	if reward.spellID and C_Spell and C_Spell.GetSpellName then
		local name = C_Spell.GetSpellName(reward.spellID)
		if name then
			return name
		end
	end
	return L["récompense"]
end

local function LevelRewards(factionID, level)
	local names = {}
	local rewards = C_MajorFactions.GetRenownRewardsForLevel and C_MajorFactions.GetRenownRewardsForLevel(factionID, level)
	table.sort(rewards or {}, function(a, b)
		return (a.uiOrder or 0) < (b.uiOrder or 0)
	end)
	for _, reward in ipairs(rewards or {}) do
		names[#names + 1] = RewardName(reward)
	end
	return #names > 0 and table.concat(names, ", ") or L["récompense"]
end

function ns.AddLegacyRewardLines(tooltip)
	local consts = Consts()
	if not (consts and C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel and C_MajorFactions.GetRenownLevels) then
		return
	end
	local factionID = consts.LEGACY_REWARD_TRACK_FACTION_ID
	local current = C_MajorFactions.GetCurrentRenownLevel(factionID) or 0
	local levels = C_MajorFactions.GetRenownLevels(factionID) or {}
	table.sort(levels, function(a, b)
		return a.level < b.level
	end)
	tooltip:AddLine(" ")
	tooltip:AddLine(L["Piste de récompenses"])
	local shown = 0
	for _, info in ipairs(levels) do
		if info.level > current then
			local text = LevelRewards(factionID, info.level)
			if shown == 0 then
				tooltip:AddLine(L["Prochaine à %d points (encore %d) : %s"]:format(info.level, info.level - current, text),
					0.25, 1, 0.25, true)
			else
				tooltip:AddLine(L["%d points : %s"]:format(info.level, text), 0.7, 0.7, 0.7, true)
			end
			shown = shown + 1
			if shown >= REWARD_LINES then
				break
			end
		end
	end
	if shown == 0 then
		tooltip:AddLine(L["Toutes les récompenses de la piste sont obtenues."], 0.7, 0.7, 0.7, true)
	end
end

-- DÉFIS LES PLUS RENTABLES ----------------------------------------------------------------

-- Défis pas encore faits qui rapportent des points, du plus rentable au moins rentable :
-- { points, name, category } ; et le total de points qu'ils rapportent.
local function Challenges()
	if cache.challenges then
		return cache.challenges, cache.challengePoints
	end
	local consts = Consts()
	local list, total = {}, 0
	if consts and GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo
		and C_Traits and C_Traits.GetTraitCurrencyForAchievement then
		for _, categoryID in ipairs(GetCategoryList() or {}) do
			local category = GetCategoryInfo and GetCategoryInfo(categoryID)
			for index = 1, GetCategoryNumAchievements(categoryID) or 0 do
				local ok, id, name, _, completed = pcall(GetAchievementInfo, categoryID, index)
				if ok and id and not completed then
					local points = C_Traits.GetTraitCurrencyForAchievement(consts.LEGACY_POINTS_TRAIT_CURRENCY_ID, id) or 0
					if points > 0 then
						list[#list + 1] = { points = points, name = name, category = category }
						total = total + points
					end
				end
			end
		end
	end
	table.sort(list, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		return (a.name or "") < (b.name or "")
	end)
	cache.challenges, cache.challengePoints = list, total
	return list, total
end

function ns.AddLegacyChallengeLines(tooltip)
	local list, total = Challenges()
	tooltip:AddLine(" ")
	if #list == 0 then
		tooltip:AddLine(L["Aucun défi restant ne rapporte de points."], 0.7, 0.7, 0.7, true)
		return
	end
	tooltip:AddLine(L["Défis les plus rentables (personnage joué)"])
	for i = 1, math.min(CHALLENGE_LINES, #list) do
		local challenge = list[i]
		tooltip:AddDoubleLine(challenge.name or "?", L["%d pts"]:format(challenge.points), 1, 1, 1, 0.25, 1, 0.25)
		if challenge.category then
			tooltip:AddLine("  " .. challenge.category, 0.6, 0.6, 0.6)
		end
	end
	tooltip:AddLine(L["En tout : %d points à gagner par %d défis."]:format(total, #list), 0.7, 0.7, 0.7, true)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ACHIEVEMENT_EARNED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event)
	cache.challenges = nil
	if event == "PLAYER_ENTERING_WORLD" then
		cache.nodeTree = nil
	end
end)
