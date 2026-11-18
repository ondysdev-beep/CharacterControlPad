-- CharacterControlPad - Audit
-- Collects facts about the running client (API presence, CVars, gamepad devices,
-- existing gamepad bindings, action bars) into CharacterControlPadDB.audit.
-- Read-only: only getters are called, every call is wrapped in pcall.
-- SavedVariables are written to disk on /reload or logout.

local _, ns = ...

local Safe = ns.Safe

-- Calls fn(...) and returns ok, firstResult (sanitised). Missing function -> false, "MISSING".
local function Probe(fn, ...)
	if type(fn) ~= "function" then
		return false, "MISSING"
	end
	local ok, value = pcall(fn, ...)
	if not ok then
		return false, "ERROR: " .. tostring(value)
	end
	return true, value
end

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	return keys
end

-- Shallow-ish copy for SavedVariables (depth limited, non-plain values labelled).
local function Copy(value, depth)
	depth = depth or 0
	if type(value) ~= "table" or (issecretvalue and issecretvalue(value)) then
		return Safe(value)
	end
	if depth > 3 then
		return "<table>"
	end
	local out = {}
	for k, v in pairs(value) do
		out[tostring(k)] = Copy(v, depth + 1)
	end
	return out
end

------------------------------------------------------------------------
-- What to inspect
------------------------------------------------------------------------

local NAMESPACES = {
	"C_GamePad", "C_GamepadUI", "C_GamepadTargeting", "C_InputInterfaceStyle",
	"C_KeyBindings", "C_ActionBar", "C_EditMode", "C_CVar", "C_Console", "C_GameRules",
}

local GLOBALS = {
	-- bindings
	"SetBinding", "SetBindingClick", "SetBindingSpell", "SetBindingMacro", "SetBindingItem",
	"SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingSpell",
	"SetOverrideBindingMacro", "SetOverrideBindingItem", "ClearOverrideBindings",
	"GetBindingKey", "GetBindingAction", "GetBindingText", "SaveBindings", "GetCurrentBindingSet",
	-- actions / bars
	"UseAction", "GetActionInfo", "HasAction", "GetActionTexture", "GetActionBarPage",
	"ChangeActionBarPage", "GetBonusBarOffset", "GetActionBarToggles", "SetActionBarToggles",
	-- secure system
	"InCombatLockdown", "RegisterStateDriver", "UnregisterStateDriver", "SecureCmdOptionParse",
	"SecureHandlerWrapScript", "SecureHandlerSetFrameRef", "issecretvalue",
	-- gamepad helpers
	"IsGamePadFreelookEnabled", "SetGamePadFreeLook", "IsGamePadCursorControlEnabled",
	"SetGamePadCursorControl", "SetPreferredGamepadInteractTarget",
	-- Blizzard Lua utilities
	"InputUtil", "GamepadActionBarBindingUtil", "SecureActionButtonMixin", "ActionBarButtonMixin",
}

local CVARS = {
	"GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt",
	"GamePadEmulateEsc", "GamePadEmulateTapWindowMs", "GamePadCursorLeftClick",
	"GamePadCursorRightClick", "GamePadCursorAutoEnable", "GamePadCameraYawSpeed",
	"GamePadCameraPitchSpeed", "GamePadFaceMovementMaxAngle", "GamePadFaceMovementMaxAngleCombat",
	"GamePadTurnWithCamera", "GamePadOverlapMouseMs", "GamePadSingleActiveID",
	"InputDeviceInterfaceStyle", "GamepadUseCompactActionBar",
	"SoftTargetEnemy", "SoftTargetFriend", "SoftTargetInteract", "ActionButtonUseKeyDown",
}

-- Patterns used to discover extra CVars through C_Console.GetAllCommands().
local CVAR_PATTERNS = { "gamepad", "inputdevice", "interfacestyle" }

-- Binding key names from the client's GamePadConfig_Default.json.
local PAD_KEYS = {
	"PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
	"PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
	"PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
	"PADLSTICK", "PADRSTICK",
	"PADLSTICKUP", "PADLSTICKDOWN", "PADLSTICKLEFT", "PADLSTICKRIGHT",
	"PADRSTICKUP", "PADRSTICKDOWN", "PADRSTICKLEFT", "PADRSTICKRIGHT",
	"PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
	"PADFORWARD", "PADBACK", "PADSYSTEM", "PADSOCIAL",
}

local MODIFIER_PREFIXES = {
	"", "ALT-", "CTRL-", "SHIFT-", "ALT-CTRL-", "ALT-SHIFT-", "CTRL-SHIFT-", "ALT-CTRL-SHIFT-",
}

local BAR_FRAMES = {
	"MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
	"MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7",
	"StanceBar", "PetActionBar", "PossessActionBar", "OverrideActionBar",
}

-- Binding commands of the standard keyboard bars (to see what the keyboard uses today).
local ACTION_BINDINGS = {
	"ACTIONBUTTON1", "ACTIONBUTTON2", "ACTIONBUTTON3", "ACTIONBUTTON4",
	"MULTIACTIONBAR1BUTTON1", "MULTIACTIONBAR2BUTTON1", "MULTIACTIONBAR3BUTTON1",
	"MULTIACTIONBAR4BUTTON1", "MULTIACTIONBAR5BUTTON1",
}

------------------------------------------------------------------------
-- Sections
------------------------------------------------------------------------

local function AuditClient()
	local version, build, buildDate, interface = GetBuildInfo()
	return {
		version = version,
		build = build,
		buildDate = buildDate,
		interface = interface,
		projectID = Safe(WOW_PROJECT_ID),
		projectCamelot = Safe(WOW_PROJECT_CAMELOT),
		isForever = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT),
		locale = GetLocale(),
		capturedAt = date("%Y-%m-%d %H:%M:%S"),
	}
end

local function AuditNamespaces()
	local out = {}
	for _, name in ipairs(NAMESPACES) do
		local ns_ = _G[name]
		if type(ns_) == "table" then
			out[name] = SortedKeys(ns_)
		else
			out[name] = "MISSING"
		end
	end
	return out
end

local function AuditGlobals()
	local out = {}
	for _, name in ipairs(GLOBALS) do
		out[name] = type(_G[name])
	end
	return out
end

local function AuditEnums()
	local out = {}
	for _, name in ipairs({ "InputDeviceInterfaceType", "BindingContext", "GamePadPowerLevel" }) do
		out[name] = (Enum and Enum[name]) and Copy(Enum[name]) or "MISSING"
	end
	return out
end

local function EnumName(enumTable, value)
	if type(enumTable) ~= "table" then
		return nil
	end
	for k, v in pairs(enumTable) do
		if v == value then
			return k
		end
	end
	return nil
end

local function AuditInterfaceStyle()
	local out = {}
	local ok, style = Probe(C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle)
	out.currentStyle = ok and Safe(style) or style
	out.currentStyleName = ok and EnumName(Enum and Enum.InputDeviceInterfaceType, style) or nil

	if C_KeyBindings and Enum and Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore then
		local okCtx, active = Probe(C_KeyBindings.IsBindingContextActive, Enum.BindingContext.GamepadModeInGameCore)
		out.gamepadBindingContextActive = okCtx and Safe(active) or active
	else
		out.gamepadBindingContextActive = "MISSING"
	end
	return out
end

local function GetCVarSafe(name)
	local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
	local ok, value = Probe(getter, name)
	if not ok then
		return value
	end
	if value == nil then
		return "<nil: unknown cvar>"
	end
	return Safe(value)
end

local function AuditCVars()
	local out = { known = {}, discovered = {} }
	for _, name in ipairs(CVARS) do
		out.known[name] = GetCVarSafe(name)
	end

	local ok, commandList = Probe(C_Console and C_Console.GetAllCommands)
	if ok and type(commandList) == "table" then
		for _, info in ipairs(commandList) do
			local cmd = type(info) == "table" and info.command
			if type(cmd) == "string" then
				local lower = cmd:lower()
				for _, pattern in ipairs(CVAR_PATTERNS) do
					if lower:find(pattern, 1, true) then
						out.discovered[cmd] = GetCVarSafe(cmd)
						break
					end
				end
			end
		end
	else
		out.discovered = "C_Console.GetAllCommands unavailable: " .. tostring(commandList)
	end
	return out
end

local function AuditGamePad()
	local out = {}
	local gp = C_GamePad
	if type(gp) ~= "table" then
		out.status = "MISSING"
		return out
	end

	local _, enabled = Probe(gp.IsEnabled)
	local _, activeID = Probe(gp.GetActiveDeviceID)
	local _, combinedID = Probe(gp.GetCombinedDeviceID)
	out.isEnabled = Safe(enabled)
	out.activeDeviceID = Safe(activeID)
	out.combinedDeviceID = Safe(combinedID)

	local okIDs, ids = Probe(gp.GetAllDeviceIDs)
	out.devices = {}
	if okIDs and type(ids) == "table" then
		for _, id in ipairs(ids) do
			local dev = { id = Safe(id) }
			local okM, mapped = Probe(gp.GetDeviceMappedState, id)
			if okM and type(mapped) == "table" then
				dev.name = Safe(mapped.name)
				dev.labelStyle = Safe(mapped.labelStyle)
				dev.buttonCount = Safe(mapped.buttonCount)
				dev.axisCount = Safe(mapped.axisCount)
				dev.stickCount = Safe(mapped.stickCount)
			else
				dev.mappedState = Safe(mapped)
			end
			local okR, raw = Probe(gp.GetDeviceRawState, id)
			if okR and type(raw) == "table" then
				dev.rawName = Safe(raw.name)
				dev.vendorID = Safe(raw.vendorID)
				dev.productID = Safe(raw.productID)
				dev.rawButtonCount = Safe(raw.rawButtonCount)
				dev.rawAxisCount = Safe(raw.rawAxisCount)
			end
			local _, power = Probe(gp.GetPowerLevel, id)
			dev.powerLevel = Safe(power)
			table.insert(out.devices, dev)
		end
	else
		out.devices = Safe(ids)
	end

	-- Button index -> binding key name / config name. Index base is unknown, so scan 0..40.
	out.buttonIndexMap = {}
	for i = 0, 40 do
		local _, binding = Probe(gp.ButtonIndexToBinding, i)
		local _, configName = Probe(gp.ButtonIndexToConfigName, i)
		if type(binding) == "string" or type(configName) == "string" then
			out.buttonIndexMap[tostring(i)] = { binding = Safe(binding), config = Safe(configName) }
		end
	end
	return out
end

local function AuditBindings()
	local out = { padBindings = {}, padBindingCount = 0, keyboardActionKeys = {} }
	if type(GetBindingAction) == "function" then
		for _, key in ipairs(PAD_KEYS) do
			for _, prefix in ipairs(MODIFIER_PREFIXES) do
				local full = prefix .. key
				local ok, action = Probe(GetBindingAction, full, true)
				if ok and type(action) == "string" and action ~= "" then
					out.padBindings[full] = action
					out.padBindingCount = out.padBindingCount + 1
				end
			end
		end
	else
		out.padBindings = "GetBindingAction MISSING"
	end

	if type(GetBindingKey) == "function" then
		for _, command in ipairs(ACTION_BINDINGS) do
			local ok, k1 = Probe(GetBindingKey, command)
			out.keyboardActionKeys[command] = ok and Safe(k1) or k1
		end
	end
	return out
end

local function AuditActionBars()
	local out = { frames = {}, buttons = {}, populatedSlots = {} }

	for _, name in ipairs(BAR_FRAMES) do
		local f = _G[name]
		if type(f) == "table" and type(f.IsShown) == "function" then
			local okShown, shown = pcall(f.IsShown, f)
			local shownValue
			if okShown then
				shownValue = Safe(shown)
			else
				shownValue = "ERROR: " .. tostring(shown)
			end
			out.frames[name] = { exists = true, shown = shownValue }
		else
			out.frames[name] = { exists = false }
		end
	end

	for i = 1, 12 do
		local b = _G["ActionButton" .. i]
		if type(b) == "table" then
			local action = b.action
			if action == nil and type(b.GetAttribute) == "function" then
				local okA, attr = pcall(b.GetAttribute, b, "action")
				action = okA and attr or nil
			end
			out.buttons["ActionButton" .. i] = { action = Safe(action) }
		end
	end

	local _, page = Probe(GetActionBarPage)
	local _, bonus = Probe(GetBonusBarOffset)
	out.actionBarPage = Safe(page)
	out.bonusBarOffset = Safe(bonus)

	local okFirst, firstGamepadSlot = Probe(C_GamepadUI and C_GamepadUI.GetFirstGamepadActionStorageSlotIndex)
	out.firstGamepadActionStorageSlot = okFirst and Safe(firstGamepadSlot) or firstGamepadSlot

	local okToggles, t1 = pcall(function()
		return { GetActionBarToggles() }
	end)
	out.actionBarToggles = okToggles and Copy(t1) or "ERROR/MISSING"

	-- Which standard slots hold something (scan up to the first gamepad slot, max 300).
	local lastSlot = 180
	if okFirst and type(firstGamepadSlot) == "number" and firstGamepadSlot > 1 then
		lastSlot = math.min(firstGamepadSlot - 1, 300)
	end
	out.scannedSlots = lastSlot
	if type(HasAction) == "function" and type(GetActionInfo) == "function" then
		for slot = 1, lastSlot do
			local okH, has = pcall(HasAction, slot)
			if okH and has == true then
				local okI, actionType, id = pcall(GetActionInfo, slot)
				out.populatedSlots[tostring(slot)] = okI and (tostring(Safe(actionType)) .. ":" .. tostring(Safe(id))) or "ERROR"
			end
		end
	end
	return out
end

------------------------------------------------------------------------
-- Runner
------------------------------------------------------------------------

local pendingReason

local function PrintSummary(a)
	local c = a.client
	ns.Printf("Client %s (build %s), interface %s, Forever=%s",
		tostring(c.version), tostring(c.build), tostring(c.interface), tostring(c.isForever))
	ns.Printf("Interface style: %s (%s), gamepad binding context active: %s",
		tostring(a.interfaceStyle.currentStyleName), tostring(a.interfaceStyle.currentStyle),
		tostring(a.interfaceStyle.gamepadBindingContextActive))
	ns.Printf("GamePadEnable=%s  EmulateShift=%s  EmulateCtrl=%s  EmulateAlt=%s",
		tostring(a.cvars.known.GamePadEnable), tostring(a.cvars.known.GamePadEmulateShift),
		tostring(a.cvars.known.GamePadEmulateCtrl), tostring(a.cvars.known.GamePadEmulateAlt))
	local devices = a.gamepad.devices
	if type(devices) == "table" and #devices > 0 then
		for _, d in ipairs(devices) do
			ns.Printf("Device %s: %s (label %s, vendor %s, product %s)",
				tostring(d.id), tostring(d.name), tostring(d.labelStyle), tostring(d.vendorID), tostring(d.productID))
		end
	else
		ns.Print("No gamepad device reported by C_GamePad.")
	end
	ns.Printf("Existing PAD bindings in current mode: %s", tostring(a.bindings.padBindingCount))
	ns.Print("Saved to CharacterControlPadDB.audit - /reload writes it to disk.")
end

function ns.RunAudit(reason, quiet)
	if InCombatLockdown() then
		pendingReason = reason
		ns.Print("In combat - audit postponed until combat ends.")
		return
	end

	local a = { reason = reason }
	local sections = {
		client = AuditClient,
		namespaces = AuditNamespaces,
		globals = AuditGlobals,
		enums = AuditEnums,
		interfaceStyle = AuditInterfaceStyle,
		cvars = AuditCVars,
		gamepad = AuditGamePad,
		bindings = AuditBindings,
		actionBars = AuditActionBars,
	}
	for key, fn in pairs(sections) do
		local ok, result = pcall(fn)
		a[key] = ok and result or { sectionError = tostring(result) }
	end
	a.eventRegistration = Copy(ns.eventRegistration)

	ns.db.audit = a
	if not quiet then
		local ok, err = pcall(PrintSummary, a)
		if not ok then
			ns.Print("Audit captured, but summary failed (see CharacterControlPadDB.audit):", tostring(err))
		end
	end
end

ns.On("PLAYER_REGEN_ENABLED", function()
	if pendingReason then
		local reason = pendingReason
		pendingReason = nil
		ns.RunAudit(reason)
	end
end)

ns.RegisterDebugCommand("audit", "capture client/API/gamepad audit and print summary", function()
	ns.RunAudit("manual")
end)
