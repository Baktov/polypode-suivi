-- Polypode Suivi: Camp — relevé du camping de WoW Forever (auteur seulement), préparation de la section Camp

local _, ns = ...
local P = Polypode

-- RELEVÉ DU CAMPING (WoW Forever, auteur seulement : ns.IsOwner, défini dans Suivi.lua). Le jeu
-- n'a aucune API propre au camping : on relève ce qu'on peut lire pour trouver les identifiants
-- (objets, sorts, auras) et les noms français, avant de bâtir la section Camp (docs/PLAN_CAMPING.md
-- du dossier des modules). Deux sources, rangées dans PolypodeSuiviCamp (fichier du compte, écrit
-- au /reload ou à la déconnexion) :
--   snapshots — « /poly suivi camp » : auras du personnage, XP et repos, métiers, objets des sacs
--     liés au camp (identifiant connu ou description contenant « camp ») et leur recharge ;
--   events    — journal automatique : auras gagnées ou perdues et sorts lancés, notés seulement près
--     d'un feu (aura Campfire Nearby présente) ou quand le nom du sort contient « camp ».
-- Messages en français et en dur (outil de l'auteur, comme le relevé des campagnes).

if (tonumber((select(4, GetBuildInfo()))) or 0) >= 100000 then return end -- Retail : rien

local CAMP = {
	AURA_BENEFITS = 1229741, -- Camp Benefits (1 h)
	AURA_NEARBY = 1283391, -- Campfire Nearby
	ITEMS = { [279981] = true, [279979] = true }, -- Basic Campfire Kit, Camp Chair
	MAX_SNAPSHOTS = 30,
	MAX_EVENTS = 400,
}
ns.CAMP = CAMP

local function IsOwner()
	return ns.IsOwner ~= nil and ns.IsOwner()
end

-- Valeur lisible (les valeurs secrètes du client, s'il y en a, sont écartées).
local function Plain(value)
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function HasCampWord(text)
	return type(text) == "string" and text:lower():find("camp", 1, true) ~= nil
end

local function Store()
	PolypodeSuiviCamp = type(PolypodeSuiviCamp) == "table" and PolypodeSuiviCamp or {}
	local store = PolypodeSuiviCamp
	store.snapshots = store.snapshots or {}
	store.events = store.events or {}
	return store
end

local function Push(list, entry, max)
	list[#list + 1] = entry
	while #list > max do table.remove(list, 1) end
end

-- Auras du joueur : spellId → { name, harmful, duration, remaining, stacks, source }.
local function ReadAuras()
	local auras = {}
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return auras end
	local now = GetTime()
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 1, 80 do
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
			if not ok or not aura then break end
			local id = Plain(aura.spellId)
			if id then
				local expiration = Plain(aura.expirationTime)
				auras[id] = {
					name = Plain(aura.name),
					harmful = filter == "HARMFUL" or nil,
					duration = Plain(aura.duration),
					remaining = expiration and expiration > 0 and math.floor(expiration - now) or nil,
					stacks = Plain(aura.applications),
					source = Plain(aura.sourceUnit),
				}
			end
		end
	end
	return auras
end

local function ReadXP()
	local level, xp, xpMax = UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
	local rested = GetXPExhaustion and GetXPExhaustion() or 0
	return {
		level = level, xp = xp, xpMax = xpMax, rested = rested,
		restedPct = xpMax and xpMax > 0 and math.floor(rested * 1000 / xpMax) / 10 or nil,
		resting = IsResting and IsResting() or nil,
		restState = GetRestState and select(2, GetRestState()) or nil,
	}
end

local function ReadProfessions()
	local list = {}
	if not (GetProfessions and GetProfessionInfo) then return list end
	for _, index in pairs({ GetProfessions() }) do
		local ok, name, _, skill, maxSkill, _, _, skillLine = pcall(GetProfessionInfo, index)
		if ok and name then
			list[#list + 1] = { name = name, skill = skill, max = maxSkill, skillLine = skillLine }
		end
	end
	return list
end

-- Recharge d'un objet : secondes restantes (nil si aucune).
local function ItemCooldown(itemID)
	local getter = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
	if not getter then return nil end
	local ok, start, duration = pcall(getter, itemID)
	if ok and start and duration and start > 0 and duration > 1.5 then
		return math.floor(start + duration - GetTime())
	end
end

-- Objets des sacs liés au camp : identifiant connu, ou sort d'utilisation dont le nom ou la
-- description contient « camp ». Description pas encore chargée : noté (pending), relancer.
local function ReadCampItems()
	local items, seen = {}, {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then
		return items
	end
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, lastBag do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			local itemID = info and info.itemID
			if itemID and not seen[itemID] then
				seen[itemID] = true
				local spellName, spellID
				if C_Item and C_Item.GetItemSpell then spellName, spellID = C_Item.GetItemSpell(itemID) end
				local desc = spellID and C_Spell and C_Spell.GetSpellDescription
					and C_Spell.GetSpellDescription(spellID) or nil
				local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
				if CAMP.ITEMS[itemID] or HasCampWord(spellName) or HasCampWord(desc) or HasCampWord(itemName) then
					items[#items + 1] = {
						itemID = itemID, name = itemName, count = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(itemID),
						spellID = spellID, spell = spellName, desc = desc, cooldown = ItemCooldown(itemID),
					}
				elseif spellID and (desc == nil or desc == "") then
					items[#items + 1] = { itemID = itemID, name = itemName, spellID = spellID, pending = true }
				end
			end
		end
	end
	return items
end

local function Header()
	local version, build = GetBuildInfo()
	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	return {
		at = GetServerTime(), build = version .. "." .. build, locale = GetLocale(),
		char = P.GetCharKey and P.GetCharKey(), zone = GetZoneText(), subzone = GetSubZoneText(), mapID = mapID,
		combat = InCombatLockdown() or nil,
	}
end

function ns.ScanCamp(note)
	if not IsOwner() then return end
	local snap = Header()
	snap.note = note
	snap.auras = ReadAuras()
	snap.xp = ReadXP()
	snap.professions = ReadProfessions()
	snap.items = ReadCampItems()
	local store = Store()
	Push(store.snapshots, snap, CAMP.MAX_SNAPSHOTS)
	local benefits = snap.auras[CAMP.AURA_BENEFITS]
	UIErrorsFrame:AddMessage(string.format("Polypode Suivi : relevé du camp n° %d (%d objets de camp, repos %s %%%s, "
		.. "feu %s). Faites /reload pour écrire le fichier.", #store.snapshots, #snap.items,
		tostring(snap.xp.restedPct or 0), benefits and benefits.remaining
			and string.format(", bonus %d min", math.floor(benefits.remaining / 60)) or "",
		snap.auras[CAMP.AURA_NEARBY] and "proche" or "absent"), 0.2, 1, 0.6)
end

-- JOURNAL AUTOMATIQUE : différence des auras à chaque UNIT_AURA du joueur, sorts lancés.
local watch = { auras = nil }

local function NearCamp(auras)
	return auras[CAMP.AURA_NEARBY] ~= nil or auras[CAMP.AURA_BENEFITS] ~= nil
end

local function LogEvent(kind, id, name, extra)
	local entry = { t = GetServerTime(), kind = kind, id = id, name = name,
		char = P.GetCharKey and P.GetCharKey() }
	for k, v in pairs(extra or {}) do entry[k] = v end
	Push(Store().events, entry, CAMP.MAX_EVENTS)
	if P.Debug then P.Debug(string.format("Camp : %s %s (%s)", kind, tostring(name), tostring(id))) end
end

local function OnAuraChanged()
	local auras = ReadAuras()
	local previous = watch.auras
	watch.auras = auras
	if not previous then return end
	local near = NearCamp(auras) or NearCamp(previous)
	for id, aura in pairs(auras) do
		if not previous[id] and (near or HasCampWord(aura.name)) then
			LogEvent("gain", id, aura.name, { duration = aura.duration, harmful = aura.harmful,
				source = aura.source, rested = GetXPExhaustion and GetXPExhaustion() or 0 })
		end
	end
	for id, aura in pairs(previous) do
		if not auras[id] and (near or HasCampWord(aura.name)) then
			LogEvent("loss", id, aura.name, { harmful = aura.harmful })
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event, unit, _, spellID)
	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		if not IsOwner() then return end -- les autres joueurs : aucun événement suivi
		watch.auras = ReadAuras()
		self:RegisterUnitEvent("UNIT_AURA", "player")
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		self:RegisterEvent("UPDATE_EXHAUSTION")
	elseif event == "UNIT_AURA" then
		OnAuraChanged()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		spellID = Plain(spellID)
		local name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
		if spellID and ((watch.auras and NearCamp(watch.auras)) or HasCampWord(name)) then
			LogEvent("cast", spellID, name)
		end
	elseif event == "UPDATE_EXHAUSTION" then
		if watch.auras and NearCamp(watch.auras) then
			LogEvent("rested", nil, nil, { rested = GetXPExhaustion and GetXPExhaustion() or 0,
				xpMax = UnitXPMax("player") })
		end
	end
end)
