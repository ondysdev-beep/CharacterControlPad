-- CharacterControlPad - modifier panel
-- Part of the Settings page of the settings window (Panel.Build).
-- Choose which controller buttons act as SHIFT / CTRL / ALT (emulated by the client through
-- GamePadEmulate* CVars, applied as temporary CVars by the engine). Changes are staged and
-- only applied with [Apply]; bindings that would become unreachable are listed first and
-- removed on apply. Layers are bound to modifiers, not buttons: moving SHIFT from L1 to L2
-- keeps the whole "SHIFT" layer, now reached with L2.

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Panel = {}
ns.ModifierPanel = Panel

local WIDTH = 520
local CANDIDATES = { "none", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK" }
local DISPLAY_ORDER = { "SHIFT", "CTRL", "ALT" }
local MAX_LISTED = 8

local frame
local pending = {}
local cells = {} -- [modId][candidateKey] = button

local function CandidateLabel(key)
	if key == "none" then
		return L.MODIFIERS_NONE
	end
	local b = ns.buttonByKey[key]
	return b and b.label or key
end

-- Binding keys the controller can no longer produce with the given modifier set:
-- a prefix whose modifier is unassigned, or a modifier held together with a modifier button.
function Panel.UnreachableKeys(profile, mods)
	local isModButton = {}
	for _, m in ipairs(ns.MODIFIERS) do
		local k = mods[m.id]
		if k and k ~= "none" then
			isModButton[k] = true
		end
	end
	local list = {}
	for key in pairs(profile.bindings) do
		local rest, hasPrefix, missing = key, false, false
		for _, m in ipairs(ns.MODIFIERS) do
			local p = m.id .. "-"
			if rest:sub(1, #p) == p then
				rest = rest:sub(#p + 1)
				hasPrefix = true
				if not mods[m.id] or mods[m.id] == "none" then
					missing = true
				end
			end
		end
		if missing or (hasPrefix and isModButton[rest]) then
			list[#list + 1] = key
		end
	end
	table.sort(list)
	return list
end

function Panel.CountLayers(mods)
	local n = 0
	for _, m in ipairs(ns.MODIFIERS) do
		if mods[m.id] and mods[m.id] ~= "none" then
			n = n + 1
		end
	end
	return 2 ^ n
end

local function IsDirty(profile)
	for _, m in ipairs(ns.MODIFIERS) do
		if (pending[m.id] or "none") ~= (profile.modifiers[m.id] or "none") then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------

function Panel.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local profile = Profiles.Active()
	for modId, row in pairs(cells) do
		for key, cell in pairs(row) do
			if (pending[modId] or "none") == key then
				cell:LockHighlight()
			else
				cell:UnlockHighlight()
			end
		end
	end
	frame.layers:SetText(string.format(L.MODS_LAYERS, Panel.CountLayers(pending)))

	local unreachable = Panel.UnreachableKeys(profile, pending)
	if #unreachable == 0 then
		frame.affected:SetText(L.MODS_NOTHING_REMOVED)
	else
		local combos = {}
		for i = 1, math.min(#unreachable, MAX_LISTED) do
			combos[#combos + 1] = Engine.KeyToCombo(unreachable[i], profile)
		end
		if #unreachable > MAX_LISTED then
			combos[#combos + 1] = "+" .. (#unreachable - MAX_LISTED)
		end
		frame.affected:SetText(string.format(L.MODS_REMOVED, table.concat(combos, ", ")))
	end

	local locked = InCombatLockdown()
	if IsDirty(profile) and not locked then
		frame.apply:Enable()
		frame.revert:Enable()
	else
		frame.apply:Disable()
		frame.revert:Disable()
	end
	for _, row in pairs(cells) do
		for _, cell in pairs(row) do
			if locked then
				cell:Disable()
			else
				cell:Enable()
			end
		end
	end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

local function Choose(modId, key)
	pending[modId] = key
	if key ~= "none" then
		for _, other in ipairs(DISPLAY_ORDER) do
			if other ~= modId and pending[other] == key then
				pending[other] = "none" -- one button = one modifier
			end
		end
	end
	Panel.Refresh()
end

local function Apply()
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	local profile = Profiles.Active()
	for _, key in ipairs(Panel.UnreachableKeys(profile, pending)) do
		profile.bindings[key] = nil
	end
	for _, m in ipairs(ns.MODIFIERS) do
		profile.modifiers[m.id] = pending[m.id] or "none"
	end
	Engine.Apply("modifiers panel")
	if ns.Config then
		ns.Config.Refresh()
	end
	Panel.Refresh()
end

------------------------------------------------------------------------
-- Construction (embedded in the Settings page of the settings window)
------------------------------------------------------------------------

function Panel.Build(parent)
	frame = CreateFrame("Frame", "CharacterControlPadModifierPanel", parent)
	frame:SetAllPoints(parent)

	ns.CreateHeading(frame, L.MODS_TITLE, 0, 0)
	local help = ns.CreateText(frame, "GameFontHighlightSmall", 0, -26, WIDTH)
	help:SetText(L.MODS_HELP)

	for rowIndex, modId in ipairs(DISPLAY_ORDER) do
		local y = -66 - (rowIndex - 1) * 32
		local label = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormal")
		label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y - 4)
		label:SetText(modId)
		cells[modId] = {}
		for i, key in ipairs(CANDIDATES) do
			local b = ns.CreateButton(frame, CandidateLabel(key), 62, 24)
			b:SetPoint("TOPLEFT", frame, "TOPLEFT", 56 + (i - 1) * 64, y)
			b:SetScript("OnClick", function()
				Choose(modId, key)
			end)
			cells[modId][key] = b
		end
	end

	frame.layers = ns.CreateText(frame, "GameFontHighlight", 0, -170, WIDTH)
	frame.tap = ns.CreateText(frame, "GameFontDisableSmall", 0, -192, WIDTH)
	frame.affected = ns.CreateText(frame, "GameFontHighlightSmall", 0, -216, WIDTH)

	frame.apply = ns.CreateButton(frame, L.APPLY, 120, 24)
	frame.apply:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -290)
	frame.apply:SetScript("OnClick", Apply)

	frame.revert = ns.CreateButton(frame, L.MODS_REVERT, 120, 24)
	frame.revert:SetPoint("LEFT", frame.apply, "RIGHT", 8, 0)
	frame.revert:SetScript("OnClick", function()
		Panel.Reset()
	end)
	return frame
end

-- Staged choice = the profile's current modifiers (when the page opens, or "Revert").
function Panel.Reset()
	if not frame then
		return
	end
	local profile = Profiles.Active()
	for _, m in ipairs(ns.MODIFIERS) do
		pending[m.id] = profile.modifiers[m.id] or "none"
	end
	local okTap, tap = pcall(C_CVar.GetCVar, "GamePadEmulateTapWindowMs")
	frame.tap:SetText(string.format(L.MODS_TAP, okTap and tostring(tap or "?") or "?"))
	Panel.Refresh()
end

function Panel.Open()
	if ns.Config then
		ns.Config.Open("settings")
	end
end
