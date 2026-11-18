-- CharacterControlPad - Input diagnostics (Phase 2)
-- Shows raw gamepad input as the client delivers it to an addon frame:
-- button down/up, sticks, modifier state, device connect/disconnect, interface-style changes.
-- Never triggers any action. Listening is opt-in (/ccp debug listen) and only toggled out of combat.
-- Nothing is printed or stored unless debug mode is on (any /ccp debug command turns it on).
--
-- v0.1 finding: with SetPropagateKeyboardInput(true) the frame receives OnGamePadButtonDown
-- but never OnGamePadButtonUp. Releases are therefore detected by polling
-- C_GamePad.GetDeviceMappedState() while a button is known to be down.

local _, ns = ...

local Safe = ns.Safe

local LOG_MAX = 500
local STICK_PRINT_INTERVAL = 0.3
local STICK_MIN_LEN = 0.2
local POLL_INTERVAL = 0.03
-- Virtual sticks that are noisy (gyro drift) and duplicate others; not logged unless printing sticks.
local QUIET_STICKS = { Gyro = true, Look = true }

local listening = false
local printSticks = false
local frame
local pressed = {}       -- button -> GetTime() of its down event
local stickState = {}    -- stick -> { lastPrint, maxLen, active }
local buttonIndexCache = {}
local indexOffset        -- 0 or 1: mapped-state "buttons" table index = buttonIndex + offset
local pollElapsed = 0

-- Identify wizard
local IDENTIFY_SEQUENCE = {
	"Cross", "Circle", "Square", "Triangle",
	"L1", "R1", "L2", "R2", "L3 (left stick click)", "R3 (right stick click)",
	"D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right",
	"Create", "Options", "PS button", "Touchpad click", "Mute",
}
local identifyStep
-- An emulated modifier (e.g. L2 = SHIFT) that is tapped shorter than GamePadEmulateTapWindowMs
-- also sends its own button (PADLTRIGGER) on release. That DOWN belongs to the previous step.
local TAP_ATTRIBUTION_WINDOW = 0.6
local lastModifierRecord -- { name = physical name, t = GetTime() }

------------------------------------------------------------------------
-- Log (ring buffer in SavedVariables, readable from disk after /reload)
------------------------------------------------------------------------

-- Only records while debug mode is on (/ccp debug ...); otherwise nothing is stored.
local function Log(kind, a, b, c)
	if not (ns.db and ns.db.debug) then
		return
	end
	if type(ns.db.inputLog) ~= "table" then
		ns.db.inputLog = {}
	end
	local log = ns.db.inputLog
	log[#log + 1] = {
		t = string.format("%.3f", GetTime()),
		kind = kind,
		a = Safe(a),
		b = Safe(b),
		c = Safe(c),
	}
	while #log > LOG_MAX do
		table.remove(log, 1)
	end
end
ns.Log = Log

local function ModifierString()
	local s = ""
	if IsAltKeyDown() then s = s .. "ALT-" end
	if IsControlKeyDown() then s = s .. "CTRL-" end
	if IsShiftKeyDown() then s = s .. "SHIFT-" end
	return s
end

local function PressedList()
	local list = {}
	for button in pairs(pressed) do
		list[#list + 1] = button
	end
	table.sort(list)
	return table.concat(list, "+")
end

local function InterfaceStyleName(value)
	if Enum and Enum.InputDeviceInterfaceType then
		for k, v in pairs(Enum.InputDeviceInterfaceType) do
			if v == value then
				return k
			end
		end
	end
	return tostring(value)
end

local function CurrentStyleName()
	local fn = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
	if type(fn) ~= "function" then
		return "?"
	end
	local ok, style = pcall(fn)
	return ok and InterfaceStyleName(style) or "?"
end

------------------------------------------------------------------------
-- Button state polling (release detection)
------------------------------------------------------------------------

local function ButtonIndex(button)
	local idx = buttonIndexCache[button]
	if idx == nil then
		local ok, value = pcall(C_GamePad.ButtonBindingToIndex, button)
		idx = (ok and type(value) == "number") and value or false
		buttonIndexCache[button] = idx
	end
	return idx or nil
end

local function GetButtonStates()
	local ok, state = pcall(function()
		return C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID())
	end)
	if ok and type(state) == "table" and type(state.buttons) == "table" then
		return state.buttons
	end
	return nil
end

-- Learns whether the mapped-state table is 0- or 1-based relative to ButtonBindingToIndex.
local function LearnIndexOffset(button)
	if indexOffset then
		return
	end
	local idx = ButtonIndex(button)
	local states = idx and GetButtonStates()
	if not states then
		return
	end
	local at0, at1 = states[idx] == true, states[idx + 1] == true
	if at1 and not at0 then
		indexOffset = 1
	elseif at0 and not at1 then
		indexOffset = 0
	end
	if indexOffset and ns.db then
		ns.db.buttonStateIndexOffset = indexOffset
	end
end

local function Release(button, kind)
	local downAt = pressed[button]
	if not downAt then
		return
	end
	pressed[button] = nil
	local held = GetTime() - downAt
	ns.Printf("|cffff4444%s|r %s  held=%.2fs", kind, tostring(button), held)
	Log(kind, button, string.format("%.2f", held))
end

local function OnUpdate(_, elapsed)
	pollElapsed = pollElapsed + elapsed
	if pollElapsed < POLL_INTERVAL then
		return
	end
	pollElapsed = 0
	if not indexOffset or next(pressed) == nil then
		return
	end
	local states = GetButtonStates()
	if not states then
		return
	end
	for button in pairs(pressed) do
		local idx = ButtonIndex(button)
		if idx and states[idx + indexOffset] ~= true then
			Release(button, "UP_POLL")
		end
	end
end

------------------------------------------------------------------------
-- Identify wizard
------------------------------------------------------------------------

local function IdentifyPrompt()
	local name = IDENTIFY_SEQUENCE[identifyStep]
	if name then
		ns.Printf("|cffffff00IDENTIFY %d/%d:|r press |cffffff00%s|r  (/ccp debug skip if nothing appears)",
			identifyStep, #IDENTIFY_SEQUENCE, name)
		return
	end
	identifyStep = nil
	ns.Print("|cff00ff00Identify finished.|r Result:")
	for _, physical in ipairs(IDENTIFY_SEQUENCE) do
		ns.Printf("  %s = %s", physical, tostring(ns.db.identify[physical]))
	end
	ns.Print("Saved to CharacterControlPadDB.identify. /reload writes it to disk.")
end

local function IdentifyRecord(result, isModifier)
	if not identifyStep then
		return
	end
	if type(ns.db.identify) ~= "table" then -- debug mode switched off meanwhile
		identifyStep = nil
		return
	end
	local name = IDENTIFY_SEQUENCE[identifyStep]
	if not isModifier and lastModifierRecord and GetTime() - lastModifierRecord.t < TAP_ATTRIBUTION_WINDOW then
		-- Tap of the modifier pressed in the previous step, not an answer for this step.
		local prev = lastModifierRecord.name
		ns.db.identify[prev] = tostring(ns.db.identify[prev]) .. " (tap sends " .. result .. ")"
		ns.Printf("  -> %s tap also sends |cff00ff00%s|r", prev, result)
		Log("IDENTIFY_TAP", prev, result)
		lastModifierRecord = nil
		return
	end
	lastModifierRecord = isModifier and { name = name, t = GetTime() } or nil
	ns.db.identify[name] = result
	ns.Printf("  -> %s = |cff00ff00%s|r", name, result)
	Log("IDENTIFY", name, result)
	identifyStep = identifyStep + 1
	IdentifyPrompt()
end

------------------------------------------------------------------------
-- Frame scripts
------------------------------------------------------------------------

local function OnButtonDown(_, button)
	local mods = ModifierString()
	if pressed[button] then
		ns.Printf("|cffff8800REPEAT DOWN|r %s (no release seen before)", tostring(button))
		Log("REPEAT_DOWN", button, mods)
	end
	pressed[button] = GetTime()
	LearnIndexOffset(button)
	local bound = GetBindingAction and GetBindingAction(mods .. tostring(button), true) or nil
	ns.Printf("|cff00ff00DOWN|r %s  mods=[%s]  held=[%s]  binding(%s%s)=%s",
		tostring(button), mods, PressedList(), mods, tostring(button), tostring(Safe(bound)))
	Log("DOWN", button, mods, bound)
	IdentifyRecord(tostring(button))
end

local function OnButtonUp(_, button)
	if not pressed[button] then
		ns.Printf("|cffff8800UP WITHOUT DOWN|r %s", tostring(button))
		Log("UP_WITHOUT_DOWN", button)
		return
	end
	Release(button, "UP")
end

local function OnStick(_, stick, x, y, len)
	if issecretvalue and (issecretvalue(x) or issecretvalue(len)) then
		return
	end
	local key = tostring(stick)
	local st = stickState[key]
	if not st then
		st = { lastPrint = 0, maxLen = 0, active = false }
		stickState[key] = st
	end
	len = tonumber(len) or 0
	if len > st.maxLen then
		st.maxLen = len
	end
	local quiet = QUIET_STICKS[key] and not printSticks

	local now = GetTime()
	if len >= STICK_MIN_LEN then
		if not st.active then
			st.active = true
			if not quiet then
				Log("STICK_START", stick, string.format("%.2f,%.2f", tonumber(x) or 0, tonumber(y) or 0))
			end
		end
		if printSticks and now - st.lastPrint >= STICK_PRINT_INTERVAL then
			st.lastPrint = now
			ns.Printf("STICK %s  x=%.2f y=%.2f len=%.2f", key, tonumber(x) or 0, tonumber(y) or 0, len)
		end
	elseif st.active then
		st.active = false
		if not quiet then
			Log("STICK_STOP", stick)
		end
		if printSticks then
			ns.Printf("STICK %s released", key)
		end
	end
end

local function EnsureFrame()
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "CharacterControlPadInputDiagFrame", UIParent)
	frame:SetSize(1, 1)
	frame:SetPoint("TOPLEFT")
	frame:Hide()
	frame:SetScript("OnUpdate", OnUpdate)

	ns.inputScriptSupport = {}
	for script, fn in pairs({
		OnGamePadButtonDown = OnButtonDown,
		OnGamePadButtonUp = OnButtonUp,
		OnGamePadStick = OnStick,
	}) do
		local ok, err = pcall(frame.SetScript, frame, script, fn)
		ns.inputScriptSupport[script] = ok and true or tostring(err)
		if not ok then
			ns.Printf("|cffff0000Script %s not supported:|r %s", script, tostring(err))
		end
	end
	if ns.db then
		ns.db.inputScriptSupport = ns.inputScriptSupport
	end
	return frame
end

------------------------------------------------------------------------
-- Listen on/off
------------------------------------------------------------------------

local function StartListening()
	if listening then
		return true
	end
	if InCombatLockdown() then
		ns.Print("Cannot start listening in combat (input propagation is combat-restricted). Try again after combat.")
		return false
	end
	local f = EnsureFrame()
	local results = {}
	for _, call in ipairs({
		{ "EnableGamePadButton", true },
		{ "EnableGamePadStick", true },
		-- Let presses continue to the normal binding system, so diagnostics never block play.
		{ "SetPropagateKeyboardInput", true },
	}) do
		local method = f[call[1]]
		if type(method) == "function" then
			local ok, err = pcall(method, f, call[2])
			results[call[1]] = ok and "OK" or ("ERROR: " .. tostring(err))
		else
			results[call[1]] = "MISSING"
		end
	end
	if ns.db then
		ns.db.listenSetup = results
	end
	f:Show()
	wipe(pressed)
	listening = true
	ns.Printf("Listening ON (interface style %s). EnableGamePadButton=%s EnableGamePadStick=%s Propagate=%s",
		CurrentStyleName(), results.EnableGamePadButton, results.EnableGamePadStick, results.SetPropagateKeyboardInput)
	ns.Print("Press controller buttons. /ccp debug listen again to stop, /ccp debug sticks to print stick values.")
	Log("LISTEN_ON", CurrentStyleName())
	return true
end

local function StopListening()
	if not frame or not listening then
		return
	end
	if InCombatLockdown() then
		ns.Print("Cannot stop listening in combat; it will keep logging until you retry after combat.")
		return
	end
	pcall(frame.EnableGamePadButton, frame, false)
	pcall(frame.EnableGamePadStick, frame, false)
	frame:Hide()
	listening = false
	identifyStep = nil
	wipe(pressed)
	local parts = {}
	for stick, st in pairs(stickState) do
		parts[#parts + 1] = string.format("%s max=%.2f", stick, st.maxLen)
	end
	ns.Print("Listening OFF." .. (#parts > 0 and (" Stick peaks: " .. table.concat(parts, ", ")) or ""))
	Log("LISTEN_OFF")
end
ns.StopListening = StopListening -- quick bind mode needs exclusive controller input

------------------------------------------------------------------------
-- Device / mode / session events (chat output and logging only in debug mode)
------------------------------------------------------------------------

local function DebugPrint(fmt, ...)
	if ns.db and ns.db.debug then
		ns.Printf(fmt, ...)
	end
end

ns.On("PLAYER_LOGIN", function()
	-- Session marker: every login and /reload. Tells test sessions apart in the saved log.
	local getter = C_CVar and C_CVar.GetCVar
	local shift = getter and getter("GamePadEmulateShift")
	local ctrl = getter and getter("GamePadEmulateCtrl")
	Log("LOGIN", CurrentStyleName(), "shift=" .. tostring(shift), "ctrl=" .. tostring(ctrl))
end)

ns.On("GAME_PAD_CONNECTED", function()
	DebugPrint("|cff00ff00Gamepad CONNECTED|r")
	Log("CONNECTED")
end)

ns.On("GAME_PAD_DISCONNECTED", function()
	local stuck = PressedList()
	DebugPrint("|cffff0000Gamepad DISCONNECTED|r%s", stuck ~= "" and ("  (buttons held at disconnect: " .. stuck .. ")") or "")
	Log("DISCONNECTED", stuck)
	wipe(pressed)
end)

ns.On("GAME_PAD_ACTIVE_CHANGED", function(_, isActive)
	Log("ACTIVE_CHANGED", isActive)
end)

ns.On("GAME_PAD_POWER_CHANGED", function(_, level)
	Log("POWER_CHANGED", level)
end)

ns.On("GAME_PAD_CONFIGS_CHANGED", function()
	Log("CONFIGS_CHANGED")
end)

ns.On("INPUT_DEVICE_INTERFACE_TRANSITION", function(_, newType, oldType)
	DebugPrint("Interface style changed: %s -> %s", InterfaceStyleName(oldType), InterfaceStyleName(newType))
	Log("INTERFACE_TRANSITION", InterfaceStyleName(newType), InterfaceStyleName(oldType))
end)

ns.On("MODIFIER_STATE_CHANGED", function(_, key, down)
	if listening then
		ns.Printf("MODIFIER %s %s", tostring(key), (down == 1) and "down" or "up")
		Log("MODIFIER", key, down)
		if down == 1 and identifyStep then
			IdentifyRecord("emulated " .. tostring(key), true)
		end
	end
end)

ns.On("PLAYER_REGEN_DISABLED", function()
	Log("COMBAT_START")
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	Log("COMBAT_END")
end)

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------

ns.RegisterDebugCommand("listen", "toggle live gamepad input logging (out of combat)", function()
	if listening then
		StopListening()
	else
		StartListening()
	end
end)

ns.RegisterDebugCommand("identify", "guided test: asks for each DualSense button and records its name", function()
	if not StartListening() then
		return
	end
	ns.db.identify = {}
	identifyStep = 1
	lastModifierRecord = nil
	Log("IDENTIFY_START", CurrentStyleName())
	IdentifyPrompt()
end)

ns.RegisterDebugCommand("skip", "skip the current identify step", function()
	if identifyStep then
		IdentifyRecord("SKIPPED")
	end
end)

ns.RegisterDebugCommand("sticks", "toggle printing of stick values while listening", function()
	printSticks = not printSticks
	ns.Printf("Stick printing %s.", printSticks and "ON" or "OFF")
end)

ns.RegisterDebugCommand("status", "short status: interface style, gamepad, listening", function()
	local okE, enabled = pcall(C_GamePad and C_GamePad.IsEnabled or error)
	local okD, dev = pcall(C_GamePad and C_GamePad.GetActiveDeviceID or error)
	ns.Printf("Interface style=%s  C_GamePad.IsEnabled=%s  activeDevice=%s  listening=%s  combat=%s",
		CurrentStyleName(), okE and tostring(Safe(enabled)) or "?",
		okD and tostring(Safe(dev)) or "?", tostring(listening), tostring(InCombatLockdown()))
end)

ns.RegisterDebugCommand("clearlog", "clear the saved input log", function()
	ns.db.inputLog = nil
	ns.Print("Input log cleared.")
end)
