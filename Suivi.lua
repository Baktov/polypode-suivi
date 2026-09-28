-- Polypode Suivi: Suivi — suivi de l'équipe : grande chambre forte, écus, ressources, renommées, runes

local P = Polypode -- dépendance obligatoire (## Dependencies: Polypode), chargée avant nous

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
--       dépensés, b = 1 si une rune est achetable (même calcul que Blizzard).
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

local SECTIONS = { "V", "C", "R", "F", "P" }

-- Options par personnage (PolypodeSuiviDB, Options → AddOns → Polypode → Suivi).
local DEFAULTS = {
	showAll = false, -- tous les personnages sauvegardés au lieu de l'équipe sélectionnée
	showFactions = false, -- renommées dans l'infobulle (inutile avec un seul compte Battle.net :
	-- elles y sont communes à tous les personnages)
}

local function SuiviSettings()
	return PolypodeSuiviDB or DEFAULTS
end

-- [nom-royaume] = { sections = { [section] = { [k] = v } }, at = date, times = { [section] = date } }
-- (dates = heure serveur). Remplacé à ADDON_LOADED par la table sauvegardée PolypodeSuiviData.
local received = {}
local lastSent = {} -- [section] = dernière chaîne envoyée aux clients connectés
local sendPending
local frame, listPanel

local function CrestIDs()
	return (select(4, GetBuildInfo()) or 0) >= 120100 and CRESTS_12_1 or CRESTS_12_0
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

local READERS = { V = ReadVault, C = ReadCrests, R = ReadResources, F = ReadFactions, P = ReadRunes }

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
	local vaultTime = entry.times and entry.times.V or entry.at
	local reset = LastWeeklyReset()
	if sections.V and reset and vaultTime and vaultTime < reset then
		local copy = {}
		for name, data in pairs(sections) do
			copy[name] = data
		end
		copy.V = {}
		for cell, value in pairs(sections.V) do
			local threshold = tostring(value):match("/(%d+)$")
			copy.V[cell] = "0/" .. (threshold or "0")
		end
		return copy, entry.at, true
	end
	return sections, entry.at, false
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

local function FormatMember(item)
	local text = CharacterName(item.key)
	local sections = DataFor(item.key)
	if not sections then
		return text .. "  |cff999999pas d'infos (Polypode Suivi absent ou pas encore reçu)|r"
	end
	local unlocked, total = VaultSummary(sections.V)
	if total > 0 then
		text = text .. "  |cffffd200Coffre " .. unlocked .. "/" .. total .. "|r"
	end
	local runes = tonumber(sections.P and sections.P.u)
	if runes and runes > 0 then
		text = text .. "  |cff40ff40Runes " .. runes .. "|r"
	end
	for _, id in ipairs(CrestIDs()) do
		local quantity = sections.C and sections.C[tostring(id)]
		local info = CurrencyInfo(id)
		if quantity and info then
			text = text .. "  " .. Icon(info.iconFileID) .. quantity
		end
	end
	return text
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
	return lines
end

-- Membres de l'équipe sélectionnée (leader en tête), ou tous les personnages sauvegardés encore
-- dans le roster (option showAll) ; texte d'en-tête et de liste vide.
local function BuildItems()
	if SuiviSettings().showAll then
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
	frame:SetSize(620, 340)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
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

	-- Case « Tous les personnages », à gauche de la barre de titre (option showAll, aussi dans
	-- le panneau d'options).
	local allCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	allCheck:SetSize(22, 22)
	allCheck:SetPoint("TOPLEFT", 8, -2)
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
		GameTooltip:Show()
	end)
	allCheck:SetScript("OnLeave", GameTooltip_Hide)
	frame.allCheck = allCheck

	listPanel = P.CreatePanel(frame, "")
	listPanel:SetPoint("TOPLEFT", 12, -36)
	listPanel:SetPoint("BOTTOMRIGHT", -12, 12)
	P.CreateScrollList(listPanel, FormatMember, nil, { tooltip = MemberTooltip })

	P.ui.suiviFrame = frame
	P.ui.suiviPanel = listPanel
	P.ui.suiviAllCheck = allCheck

	P.SkinFrame(frame)
	P.SkinPanel(listPanel)
end

-- Remplit la liste, si la fenêtre est ouverte.
function P.RefreshSuivi()
	if not frame or not frame:IsShown() then
		return
	end
	frame.allCheck:SetChecked(SuiviSettings().showAll) -- peut avoir changé dans les options
	local items, header, emptyText = BuildItems()
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
			return SuiviSettings().showAll
		end,
		function(value)
			SuiviSettings().showAll = value
			P.RefreshSuivi()
		end)
	Settings.CreateCheckbox(category, allSetting,
		"La fenêtre « Suivi » liste tous les personnages dont des informations ont été enregistrées "
		.. "(avec leur date) au lieu des membres de l'équipe sélectionnée. Même case que dans la barre "
		.. "de titre de la fenêtre. Réglage propre à ce personnage.")

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
end

local setup = CreateFrame("Frame")
setup:RegisterEvent("ADDON_LOADED")
setup:RegisterEvent("PLAYER_LOGIN")
setup:RegisterEvent("PLAYER_LOGOUT") -- dernières données du personnage joué, sauvegardées
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
	elseif event == "PLAYER_LOGOUT" then
		StoreOwn(ReadOwn())
	end
end)

-- Changements du personnage joué : envoi différé des sections modifiées, et fenêtre à jour.
local events = CreateFrame("Frame")
for _, event in ipairs({
	"PLAYER_ENTERING_WORLD", "WEEKLY_REWARDS_UPDATE", "CURRENCY_DISPLAY_UPDATE",
	"MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "TRAIT_CONFIG_UPDATED", "BAG_UPDATE_DELAYED",
}) do
	if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
		pcall(events.RegisterEvent, events, event)
	end
end
events:SetScript("OnEvent", function()
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
