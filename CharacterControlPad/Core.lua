-- CharacterControlPad - Core
-- Bootstrap, SavedVariables, event dispatch and slash commands.
-- CharacterControlPad never performs game actions itself: it only sets override bindings (out of combat)
-- and temporary modifier CVars; the client's binding system executes the actions.

local ADDON_NAME, ns = ...

ns.VERSION = "0.13.0"

local PREFIX = "|cff33ccffCCP|r"

function ns.Print(...)
	print(PREFIX, ...)
end

function ns.Printf(fmt, ...)
	local ok, msg = pcall(string.format, fmt, ...)
	print(PREFIX, ok and msg or ("<format error> " .. tostring(fmt)))
end

-- Converts any value into something safe to print / store in SavedVariables.
-- Secret values (Midnight/Forever restriction system) are never read, only labelled.
function ns.Safe(value)
	if issecretvalue and issecretvalue(value) then
		return "<secret>"
	end
	local t = type(value)
	if t == "nil" or t == "boolean" or t == "number" or t == "string" then
		return value
	end
	return "<" .. t .. ">"
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

-- event name -> true, or the error text if the client rejected the event name.
-- Doubles as a check of which events exist in this client.
ns.eventRegistration = {}

function ns.On(event, fn)
	if not handlers[event] then
		local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, event)
		ns.eventRegistration[event] = ok and true or tostring(err)
		if not ok then
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then
		return
	end
	for i = 1, #list do
		local ok, err = pcall(list[i], event, ...)
		if not ok then
			geterrorhandler()(err)
		end
	end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

local commands, commandOrder = {}, {}
local debugCommands, debugOrder = {}, {}

function ns.RegisterCommand(name, help, fn)
	commands[name] = { help = help, fn = fn }
	table.insert(commandOrder, name)
end

-- Diagnostics live under /ccp debug <name>; they are hidden from the normal help.
function ns.RegisterDebugCommand(name, help, fn)
	debugCommands[name] = { help = help, fn = fn }
	table.insert(debugOrder, name)
end

local function PrintHelp()
	ns.Printf("v%s - /ccp opens the settings window. Commands:", ns.VERSION)
	for _, name in ipairs(commandOrder) do
		ns.Printf("  /ccp %s - %s", name, commands[name].help)
	end
end

local function PrintDebugHelp()
	ns.Printf("Diagnostics (debug data saving is %s):", ns.db.debug and "|cff00ff00ON|r" or "OFF")
	for _, name in ipairs(debugOrder) do
		ns.Printf("  /ccp debug %s - %s", name, debugCommands[name].help)
	end
end

-- Diagnostic data kept in SavedVariables only while debug mode is on.
local DEBUG_FIELDS = { "audit", "inputLog", "identify", "poc", "listenSetup", "inputScriptSupport", "buttonStateIndexOffset" }

function ns.ClearDebugData()
	for _, field in ipairs(DEBUG_FIELDS) do
		ns.db[field] = nil
	end
end

function ns.SetDebug(enabled)
	ns.db.debug = enabled and true or nil
	if not enabled then
		if ns.StopListening then
			ns.StopListening()
		end
		ns.ClearDebugData()
	end
end

ns.RegisterCommand("debug", "diagnostic tools (/ccp debug help)", function(rest)
	local sub, args = (rest or ""):match("^(%S*)%s*(.-)$")
	sub = (sub or ""):lower()
	if sub == "on" then
		ns.SetDebug(true)
		ns.Print("Debug mode ON - diagnostic data is saved. /ccp debug off stops it and clears the data.")
		return
	elseif sub == "off" then
		ns.SetDebug(false)
		ns.Print("Debug mode OFF - diagnostic data cleared.")
		return
	end
	local entry = debugCommands[sub]
	if not entry then
		PrintDebugHelp()
		ns.Print("  /ccp debug on | off - save diagnostic data / stop and clear it")
		return
	end
	if not ns.db.debug then
		ns.SetDebug(true)
		ns.Print("Debug mode ON (diagnostic data is saved until /ccp debug off).")
	end
	entry.fn(args)
end)

SLASH_CHARACTERCONTROLPAD1 = "/ccp"
SLASH_CHARACTERCONTROLPAD2 = "/charactercontrolpad"
SlashCmdList.CHARACTERCONTROLPAD = function(msg)
	local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	local entry = commands[cmd]
	if entry then
		entry.fn(rest)
	elseif cmd == "" and ns.Config then
		ns.Config.Toggle()
	else
		PrintHelp()
	end
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

-- Until 0.12.0 the addon was called ForeverPad and saved ForeverPadDB. A player who renames the old
-- SavedVariables file to CharacterControlPad.lua gets the old table as the global ForeverPadDB; it
-- is taken over only if it looks like ours (another, unrelated addon is also called ForeverPad).
-- The old global itself is left alone.
function ns.LegacyData()
	local old = rawget(_G, "ForeverPadDB")
	if type(old) ~= "table" or type(old.profiles) ~= "table" or type(old.characters) ~= "table" then
		return nil
	end
	for _, profile in pairs(old.profiles) do
		if type(profile) ~= "table" or type(profile.bindings) ~= "table" or type(profile.modifiers) ~= "table" then
			return nil
		end
	end
	local copy = {}
	for k, v in pairs(old) do
		copy[k] = v
	end
	copy.migratedFrom = "ForeverPad"
	return copy
end

ns.On("ADDON_LOADED", function(_, name)
	if name ~= ADDON_NAME then
		return
	end
	if type(CharacterControlPadDB) ~= "table" then
		CharacterControlPadDB = ns.LegacyData() or {}
	end
	ns.db = CharacterControlPadDB
	ns.db.version = ns.VERSION
	-- Drop diagnostic data left by older builds (or a forgotten debug session from an old version).
	if not ns.db.debug then
		ns.ClearDebugData()
	end
	if ns.InitLocale then
		ns.InitLocale() -- before any window or chat message is produced
	end
end)
