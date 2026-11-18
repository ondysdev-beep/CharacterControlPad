-- ForeverPad - Binding Engine (Phase 5)
-- Turns the active profile into override bindings owned by ForeverPad:
--   SetOverrideBinding(owner, false, "SHIFT-PAD1", "ACTIONBUTTON5")
-- The client's binding system then performs the action (verified in Phase 3/4); the addon never
-- calls protected functions. Override bindings are not saved to the player's key bindings.
--
-- Modifiers (L1 = SHIFT, R1 = CTRL by default) are set with C_CVar.SetTempCVar, which is not
-- written to Config.wtf; RemoveTempCVar restores the player's own value.
--
-- Rules:
--   * bindings are only changed out of combat; changes requested in combat are applied after it;
--   * only active in the mouse & keyboard interface style (Mkb); in the Blizzard Gamepad UI
--     ForeverPad steps aside (that UI has its own static bindings and action slots).

local _, ns = ...

local Safe = ns.Safe
local Profiles = ns.Profiles
local L = ns.L

local Engine = {}
ns.Engine = Engine

local owner
local pending = false

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function CurrentStyleName()
	local fn = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
	if type(fn) ~= "function" then
		return "Mkb" -- API missing: behave as plain mouse & keyboard client
	end
	local ok, style = pcall(fn)
	if ok and Enum and Enum.InputDeviceInterfaceType then
		for k, v in pairs(Enum.InputDeviceInterfaceType) do
			if v == style then
				return k
			end
		end
	end
	return "?"
end
Engine.CurrentStyleName = CurrentStyleName

local function GetCVarValue(name)
	local ok, value = pcall(C_CVar.GetCVar, name)
	return ok and value or nil
end

function Engine.IsValidCommand(command)
	local fn = C_KeyBindings and C_KeyBindings.GetBindingIndex
	if type(fn) ~= "function" then
		return true
	end
	local ok, index = pcall(fn, command)
	return ok and index ~= nil
end

function Engine.ResolveCommand(action)
	if type(action) ~= "table" then
		return nil, "invalid action"
	end
	if action.type == "bar" then
		local bar = ns.BARS[tonumber(action.bar) or 0]
		local n = tonumber(action.button)
		if not bar then
			return nil, "unknown bar " .. tostring(action.bar)
		end
		if not n or n < 1 or n > ns.BAR_BUTTONS then
			return nil, "button out of range: " .. tostring(action.button)
		end
		return bar.prefix .. n
	elseif action.type == "command" then
		if type(action.command) ~= "string" or action.command == "" then
			return nil, "missing command"
		end
		return action.command
	end
	return nil, "unknown action type " .. tostring(action.type)
end

------------------------------------------------------------------------
-- Combos <-> binding keys
------------------------------------------------------------------------

local function ModifierOfKey(profile)
	local map = {}
	for _, m in ipairs(ns.MODIFIERS) do
		local key = profile.modifiers[m.id]
		if key and key ~= "none" then
			map[key] = m.id
		end
	end
	return map
end

-- "L1+Cross" -> "SHIFT-PAD1". Returns key, mainButton, isModifierTap  or  nil, error.
function Engine.ParseCombo(text, profile)
	local modOfKey = ModifierOfKey(profile)
	local buttons = {}
	for part in tostring(text or ""):gmatch("[^+]+") do
		local b = ns.FindButton(part)
		if not b then
			return nil, "unknown button: " .. part
		end
		buttons[#buttons + 1] = b
	end
	if #buttons == 0 then
		return nil, "empty combo"
	end

	local mods, main = {}, nil
	if #buttons == 1 then
		main = buttons[1]
	else
		for _, b in ipairs(buttons) do
			local modId = modOfKey[b.key]
			if modId then
				mods[modId] = true
			elseif main then
				return nil, "only one non-modifier button is allowed in a combo"
			else
				main = b
			end
		end
		if not main then
			return nil, "a combo needs one button that is not a modifier"
		end
	end

	local prefix = ""
	for _, m in ipairs(ns.MODIFIERS) do
		if mods[m.id] then
			prefix = prefix .. m.id .. "-"
		end
	end
	return prefix .. main.key, main, modOfKey[main.key] ~= nil
end

local buttonOrder = {}
for i, b in ipairs(ns.BUTTONS) do
	buttonOrder[b.key] = i
end

-- "CTRL-SHIFT-PAD1" -> "L1+R1+Cross" (profile's modifier buttons, in controller order).
-- short = true uses the compact labels ("L1+R1+X").
function Engine.KeyToCombo(key, profile, short)
	local field = short and "short" or "label"
	local mods, rest = {}, key
	for _, m in ipairs(ns.MODIFIERS) do
		local p = m.id .. "-"
		if rest:sub(1, #p) == p then
			rest = rest:sub(#p + 1)
			local modKey = profile.modifiers[m.id]
			local b = modKey and ns.buttonByKey[modKey]
			mods[#mods + 1] = { label = b and b[field] or (m.id .. "(unassigned)"), order = b and buttonOrder[b.key] or 99 }
		end
	end
	table.sort(mods, function(a, b)
		return a.order < b.order
	end)
	local parts = {}
	for _, m in ipairs(mods) do
		parts[#parts + 1] = m.label
	end
	local main = ns.buttonByKey[rest]
	parts[#parts + 1] = main and main[field] or rest
	return table.concat(parts, "+"), main
end

function Engine.IsModifierButton(profile, key)
	for _, m in ipairs(ns.MODIFIERS) do
		if profile.modifiers[m.id] == key then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- Describing actions (for /fpad list)
------------------------------------------------------------------------

-- Action slot shown by any action button frame: Blizzard (.action), secure attribute "action",
-- or LibActionButton-based bar addons (._state_action). nil if it is not an action-slot button.
function Engine.SlotForFrame(frame)
	if type(frame) ~= "table" then
		return nil
	end
	local slot = rawget(frame, "action")
	if type(slot) ~= "number" and type(frame.GetAttribute) == "function" then
		local ok, attr = pcall(frame.GetAttribute, frame, "action")
		slot = ok and tonumber(attr) or nil
	end
	if type(slot) ~= "number" then
		slot = rawget(frame, "_state_action")
	end
	return type(slot) == "number" and slot or nil
end

function Engine.SlotForBarButton(barIndex, button)
	local bar = ns.BARS[tonumber(barIndex) or 0]
	local n = tonumber(button)
	if not bar or not n then
		return nil
	end
	local slot = Engine.SlotForFrame(_G[bar.buttonPrefix .. n])
	if slot then
		return slot
	end
	if bar.page then
		return (bar.page - 1) * ns.BAR_BUTTONS + n
	end
	return n
end

local function DescribeSlot(slot)
	local okHas, has = pcall(HasAction, slot)
	if not okHas or has ~= true then
		return "empty"
	end
	local ok, actionType, id = pcall(GetActionInfo, slot)
	if not ok then
		return "?"
	end
	actionType, id = Safe(actionType), Safe(id)
	local name
	if actionType == "spell" and C_Spell and C_Spell.GetSpellName then
		local okName, n = pcall(C_Spell.GetSpellName, id)
		name = okName and Safe(n) or nil
	elseif actionType == "item" and C_Item and C_Item.GetItemNameByID then
		local okName, n = pcall(C_Item.GetItemNameByID, id)
		name = okName and Safe(n) or nil
	elseif actionType == "macro" and GetActionText then
		local okName, n = pcall(GetActionText, slot)
		name = okName and Safe(n) or nil
	end
	if type(name) == "string" and name ~= "" then
		return name
	end
	return tostring(actionType) .. ":" .. tostring(id)
end
Engine.DescribeSlot = DescribeSlot

function Engine.DescribeAction(action)
	if type(action) ~= "table" then
		return "?"
	end
	if action.type == "bar" then
		local bar = ns.BARS[tonumber(action.bar) or 0]
		local text = string.format("%s #%s", bar and bar.label or ("bar " .. tostring(action.bar)), tostring(action.button))
		local slot = Engine.SlotForBarButton(action.bar, action.button)
		if slot then
			text = text .. string.format(" [slot %d: %s]", slot, DescribeSlot(slot))
		end
		return text
	elseif action.type == "command" then
		return string.format("%s (%s)", ns.commandLabel[action.command] or action.command, tostring(action.command))
	elseif action.type == "click" then
		local frame = _G[tostring(action.button)]
		if type(frame) ~= "table" then
			return string.format("%s [button not found]", tostring(action.button))
		end
		local slot = Engine.SlotForFrame(frame)
		if slot then
			return string.format("%s [slot %d: %s]", tostring(action.button), slot, DescribeSlot(slot))
		end
		return tostring(action.button)
	end
	return "?"
end

------------------------------------------------------------------------
-- Modifiers (temporary CVars)
------------------------------------------------------------------------

local function RevertModifiers()
	for _, m in ipairs(ns.MODIFIERS) do
		pcall(C_CVar.RemoveTempCVar, m.cvar)
	end
end

local function ApplyModifiers(mods)
	local results = {}
	for _, m in ipairs(ns.MODIFIERS) do
		local wanted = mods[m.id] or "none"
		local current = GetCVarValue(m.cvar)
		if current ~= wanted then
			pcall(C_CVar.SetTempCVar, m.cvar, wanted)
			current = GetCVarValue(m.cvar)
		end
		results[m.id] = { wanted = wanted, actual = Safe(current), ok = (current == wanted) }
	end
	return results
end

------------------------------------------------------------------------
-- Gamepad cursor (temporary CVar)
------------------------------------------------------------------------
-- With GamePadCursorAutoEnable = 1 the client switches to its gamepad cursor whenever a window
-- opens and on Esc (Blizzard_Game/Shared/Game.lua, UIParentPanelManager.lua): the left stick then
-- moves the cursor and GamePadCursorLeftClick / RightClick buttons click - often R2 / R1, which
-- ForeverPad uses as modifiers. ForeverPad is meant for "character on the controller, windows
-- with the mouse", so by default it keeps the automatic cursor off while it is active.

-- Forever defaults (wowless data/products/wowf/cvars.yaml): AutoEnable 1, OnLogin 1, LeftClick
-- PADRTRIGGER, RightClick PADRSHOULDER, AutoDisableSticks 2, AutoDisableJump 1. Addons may not call
-- SetGamePadCursorControl in Forever (ADDON_ACTION_FORBIDDEN), so ForeverPad only uses CVars:
--   AutoEnable 0         - windows and Esc no longer switch to the cursor
--   AutoDisableSticks 2  - any stick input turns the cursor off (safety net)
--   AutoDisableJump 1    - jumping turns it off too
local CURSOR_CVARS = {
	{ name = "GamePadCursorAutoEnable", value = "0" },
	{ name = "GamePadCursorAutoDisableSticks", value = "2" },
	{ name = "GamePadCursorAutoDisableJump", value = "1" },
}
local CURSOR_CLICK_CVARS = { "GamePadCursorLeftClick", "GamePadCursorRightClick" }

function Engine.KeepCursorOff()
	return ns.db.keepCursorOff ~= false
end

local function RevertCursor()
	for _, c in ipairs(CURSOR_CVARS) do
		pcall(C_CVar.RemoveTempCVar, c.name)
	end
end

local function ApplyCursor()
	if not Engine.KeepCursorOff() then
		RevertCursor()
		return nil
	end
	local result = { ok = true, cvars = {} }
	for _, c in ipairs(CURSOR_CVARS) do
		local current = GetCVarValue(c.name)
		if current ~= nil then -- unknown CVar in this client: nothing to do
			if current ~= c.value then
				pcall(C_CVar.SetTempCVar, c.name, c.value)
				current = GetCVarValue(c.name)
			end
			local ok = (current == c.value)
			result.cvars[c.name] = { wanted = c.value, actual = Safe(current), ok = ok }
			result.ok = result.ok and ok
		end
	end
	return result
end

-- Modifier buttons that are also click buttons of the gamepad cursor: { { modifier, key }, ... }
function Engine.CursorConflicts(profile)
	local list = {}
	for _, cvar in ipairs(CURSOR_CLICK_CVARS) do
		local key = GetCVarValue(cvar)
		if type(key) == "string" and key ~= "" and key ~= "none" then
			for _, m in ipairs(ns.MODIFIERS) do
				if profile.modifiers[m.id] == key then
					list[#list + 1] = { modifier = m.id, key = key }
				end
			end
		end
	end
	return list
end

------------------------------------------------------------------------
-- Apply
------------------------------------------------------------------------

function Engine.Apply(reason)
	if InCombatLockdown() then
		if not pending then
			ns.Print(L.ENGINE_COMBAT_PENDING)
		end
		pending = true
		return false
	end
	pending = false
	owner = owner or CreateFrame("Frame", "ForeverPadBindingOwner")
	ClearOverrideBindings(owner)

	local state = {
		reason = reason,
		time = date("%Y-%m-%d %H:%M:%S"),
		style = CurrentStyleName(),
		profile = Profiles.ActiveName(),
		bound = 0,
		errors = {},
	}

	if not ns.db.enabled then
		RevertModifiers()
		RevertCursor()
		state.status = "disabled"
	elseif state.style ~= "Mkb" then
		RevertModifiers()
		RevertCursor()
		state.status = "paused (Blizzard gamepad UI)"
	else
		local profile = Profiles.Active()
		state.modifiers = ApplyModifiers(profile.modifiers)
		state.cursor = ApplyCursor()
		local expected = {} -- key -> binding string the client should report for it
		for key, action in pairs(profile.bindings) do
			if type(action) == "table" and action.type == "click" then
				-- Any named action button, e.g. buttons of bar addons (Bartender4, Dominos, ElvUI ...).
				local name = action.button
				if type(name) ~= "string" or name == "" then
					state.errors[key] = "missing button name"
				else
					local ok, setErr = pcall(SetOverrideBindingClick, owner, false, key, name, "LeftButton")
					if ok then
						state.bound = state.bound + 1
						expected[key] = "CLICK " .. name .. ":LeftButton"
					else
						state.errors[key] = tostring(setErr)
					end
				end
			else
				local command, err = Engine.ResolveCommand(action)
				if command and not Engine.IsValidCommand(command) then
					command, err = nil, "unknown binding command " .. command
				end
				if command then
					local ok, setErr = pcall(SetOverrideBinding, owner, false, key, command)
					if ok then
						state.bound = state.bound + 1
						expected[key] = command
					else
						state.errors[key] = tostring(setErr)
					end
				else
					state.errors[key] = err
				end
			end
		end
		-- Conflict check: another addon (e.g. ConsolePort) may own the same key with a priority override.
		state.conflicts = {}
		if type(GetBindingAction) == "function" then
			for key, want in pairs(expected) do
				-- keys temporarily held by ForeverPad's own context layer (Context.lua) are not conflicts
				local ownLayer = ns.Context and ns.Context.Owns(key)
				local ok, actual = pcall(GetBindingAction, key, true)
				if not ownLayer and ok and type(actual) == "string" and actual ~= "" and actual ~= want then
					state.conflicts[key] = actual
				end
			end
		end
		state.status = "active"
	end
	ns.db.lastApply = state
	return true, state
end

-- suffix: optional text appended to the summary line (e.g. the /fpad hint at login)
function Engine.PrintState(suffix)
	local s = ns.db.lastApply
	if not s then
		ns.Print("Binding engine has not run yet.")
		return
	end
	if s.status ~= "active" then
		ns.Printf(L.ENGINE_INACTIVE, s.status == "disabled" and L.STATE_DISABLED or L.STATE_PAUSED, s.profile, s.style, suffix or "")
		return
	end
	local profile = Profiles.Active()
	local modText = {}
	for _, m in ipairs(ns.MODIFIERS) do
		local r = s.modifiers and s.modifiers[m.id]
		local key = profile.modifiers[m.id]
		if key and key ~= "none" then
			local b = ns.buttonByKey[key]
			modText[#modText + 1] = string.format("%s=%s%s", b and b.label or key, m.id,
				(r and not r.ok) and "|cffff0000(NOT SET: " .. tostring(r.actual) .. ")|r" or "")
		end
	end
	local errorCount = 0
	for key, err in pairs(s.errors) do
		errorCount = errorCount + 1
		ns.Printf(L.ENGINE_BIND_ERROR, Engine.KeyToCombo(key, profile), tostring(err))
	end
	for key, other in pairs(s.conflicts or {}) do
		errorCount = errorCount + 1
		ns.Printf(L.ENGINE_CONFLICT, Engine.KeyToCombo(key, profile), tostring(other))
	end
	ns.Printf(L.ENGINE_ACTIVE,
		s.profile, s.bound, errorCount > 0 and string.format(L.ENGINE_ERRORS_SUFFIX, errorCount) or "",
		#modText > 0 and table.concat(modText, ", ") or L.MODIFIERS_NONE, suffix or "")
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

ns.On("PLAYER_LOGIN", function()
	Profiles.Init()
	if ns.db.enabled == nil then
		ns.db.enabled = true
	end
	Engine.Apply("login")
	Engine.PrintState(L.LOGIN_HINT)
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	if pending then
		Engine.Apply("after combat")
		Engine.PrintState()
	end
end)

ns.On("INPUT_DEVICE_INTERFACE_TRANSITION", function()
	Engine.Apply("interface style changed")
	Engine.PrintState()
end)
