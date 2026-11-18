-- ForeverPad - slash commands for the binding engine and profiles
-- (A graphical configurator comes later; these commands are the Phase 5 interface.)

local _, ns = ...

local Engine = ns.Engine
local Profiles = ns.Profiles

local function ApplyAndReport(reason)
	local applied = Engine.Apply(reason)
	if applied then
		Engine.PrintState()
	end
end

local function SortedBindingKeys(profile)
	local order = {}
	for i, b in ipairs(ns.BUTTONS) do
		order[b.key] = i
	end
	local keys = {}
	for key in pairs(profile.bindings) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		local _, mainA = Engine.KeyToCombo(a, profile)
		local _, mainB = Engine.KeyToCombo(b, profile)
		local oa = mainA and order[mainA.key] or 99
		local ob = mainB and order[mainB.key] or 99
		if oa ~= ob then
			return oa < ob
		end
		if #a ~= #b then
			return #a < #b
		end
		return a < b
	end)
	return keys
end

------------------------------------------------------------------------
-- /fpad list | map | unmap
------------------------------------------------------------------------

ns.RegisterCommand("list", "show the controller mapping of the active profile", function()
	local profile = Profiles.Active()
	Engine.PrintState()
	for _, key in ipairs(SortedBindingKeys(profile)) do
		local combo = Engine.KeyToCombo(key, profile)
		ns.Printf("  |cffffff00%s|r -> %s", combo, Engine.DescribeAction(profile.bindings[key]))
	end
end)

local MAP_USAGE = "Usage: /fpad map <combo> bar <1-8> <1-12>  |  /fpad map <combo> cmd <COMMAND>  |  /fpad map <combo> click <ButtonFrameName>   (combo e.g. Cross, L1+Cross, L1+R1+Square)"

ns.RegisterCommand("map", "map a combo: /fpad map L1+Cross bar 1 5  |  /fpad map Touchpad cmd TOGGLEWORLDMAP", function(rest)
	local combo, kind, a, b = (rest or ""):match("^(%S+)%s+(%S+)%s*(%S*)%s*(%S*)$")
	if not combo then
		ns.Print(MAP_USAGE)
		return
	end
	local profile = Profiles.Active()
	local key, main, isTap = Engine.ParseCombo(combo, profile)
	if not key then
		ns.Print("|cffff0000" .. tostring(main) .. "|r")
		return
	end

	kind = kind:lower()
	local action
	if kind == "bar" then
		local bar, button = tonumber(a), tonumber(b)
		if not bar or not ns.BARS[bar] or not button or button < 1 or button > ns.BAR_BUTTONS then
			ns.Print("|cffff0000Bar must be 1-8 and button 1-12.|r Bars: 1 Main, 2 Bottom left, 3 Bottom right, 4 Right 1, 5 Right 2, 6-8 Bar 6-8.")
			return
		end
		action = { type = "bar", bar = bar, button = button }
	elseif kind == "cmd" or kind == "command" then
		local command = a:upper()
		if command == "" then
			ns.Print(MAP_USAGE)
			return
		end
		if not Engine.IsValidCommand(command) then
			ns.Printf("|cffff0000Unknown binding command '%s'.|r /fpad commands lists known ones.", command)
			return
		end
		action = { type = "command", command = command }
	elseif kind == "click" then
		-- any named action button, e.g. a Bartender4 / Dominos / ElvUI button (case-sensitive name)
		if a == "" then
			ns.Print(MAP_USAGE)
			return
		end
		action = { type = "click", button = a }
	else
		ns.Print(MAP_USAGE)
		return
	end

	profile.bindings[key] = action
	ns.Printf("%s -> %s", Engine.KeyToCombo(key, profile), Engine.DescribeAction(action))
	if isTap then
		ns.Printf("Note: %s is a modifier - this fires on a short tap (< %s ms), holding it still works as modifier.",
			main.label, tostring(C_CVar.GetCVar("GamePadEmulateTapWindowMs") or "?"))
	end
	ApplyAndReport("map")
end)

ns.RegisterCommand("unmap", "remove a combo: /fpad unmap L1+Cross", function(rest)
	local profile = Profiles.Active()
	local key, err = Engine.ParseCombo(rest, profile)
	if not key then
		ns.Print("|cffff0000" .. tostring(err) .. "|r")
		return
	end
	if not profile.bindings[key] then
		ns.Printf("%s is not mapped.", Engine.KeyToCombo(key, profile))
		return
	end
	profile.bindings[key] = nil
	ns.Printf("%s unmapped.", Engine.KeyToCombo(key, profile))
	ApplyAndReport("unmap")
end)

------------------------------------------------------------------------
-- /fpad mod
------------------------------------------------------------------------

ns.RegisterCommand("mod", "set modifier buttons: /fpad mod shift L1 | ctrl R1 | alt none", function(rest)
	local profile = Profiles.Active()
	local modName, buttonName = (rest or ""):match("^(%S+)%s+(%S+)$")
	if not modName then
		local parts = {}
		for _, m in ipairs(ns.MODIFIERS) do
			local key = profile.modifiers[m.id]
			local b = key and ns.buttonByKey[key]
			parts[#parts + 1] = string.format("%s=%s", m.id, b and b.label or tostring(key))
		end
		ns.Printf("Modifiers: %s. Change: /fpad mod <shift|ctrl|alt> <button|none>", table.concat(parts, ", "))
		return
	end
	modName = modName:upper()
	local valid = false
	for _, m in ipairs(ns.MODIFIERS) do
		if m.id == modName then
			valid = true
		end
	end
	if not valid then
		ns.Print("|cffff0000Modifier must be shift, ctrl or alt.|r")
		return
	end
	local newKey = "none"
	if buttonName:lower() ~= "none" then
		local b = ns.FindButton(buttonName)
		if not b then
			ns.Printf("|cffff0000Unknown button: %s|r", buttonName)
			return
		end
		for _, m in ipairs(ns.MODIFIERS) do
			if m.id ~= modName and profile.modifiers[m.id] == b.key then
				ns.Printf("|cffff0000%s is already the %s modifier.|r", b.label, m.id)
				return
			end
		end
		newKey = b.key
	end
	profile.modifiers[modName] = newKey
	ns.Printf("%s modifier = %s", modName, newKey == "none" and "none" or ns.buttonByKey[newKey].label)
	ApplyAndReport("modifiers")
end)

------------------------------------------------------------------------
-- /fpad commands | on | off | apply
------------------------------------------------------------------------

ns.RegisterCommand("commands", "list game/UI commands usable with /fpad map ... cmd", function()
	for _, c in ipairs(ns.COMMANDS) do
		local valid = Engine.IsValidCommand(c.command)
		ns.Printf("  %s%s|r - %s (%s)%s", valid and "|cffffff00" or "|cff888888", c.command, c.label, c.group,
			valid and "" or " |cffff0000not available in this client|r")
	end
	ns.Print("Any other Blizzard binding command name also works if the client knows it.")
end)

ns.RegisterCommand("on", "enable ForeverPad bindings", function()
	ns.db.enabled = true
	ApplyAndReport("enabled")
end)

ns.RegisterCommand("off", "disable ForeverPad bindings and restore your modifier settings", function()
	ns.db.enabled = false
	ApplyAndReport("disabled")
end)

ns.RegisterCommand("apply", "re-apply the active profile", function()
	ApplyAndReport("manual")
end)

------------------------------------------------------------------------
-- /fpad profile ...
------------------------------------------------------------------------

local PROFILE_USAGE = "/fpad profile [use|new|template|copy|rename|delete|reset] <name>  (new = empty, template = default layout)"

ns.RegisterCommand("profile", PROFILE_USAGE, function(rest)
	local sub, name = (rest or ""):match("^(%S*)%s*(.-)%s*$")
	sub = (sub or ""):lower()
	local active = Profiles.ActiveName()
	local ok, err

	if sub == "" then
		ns.Printf("Active profile: |cffffff00%s|r. Profiles: %s", active, table.concat(Profiles.List(), ", "))
		ns.Print(PROFILE_USAGE)
		return
	elseif sub == "use" then
		ok, err = Profiles.Use(name)
	elseif sub == "new" or sub == "template" then
		ok, err = Profiles.Create(name, sub == "new" and "empty" or "template")
		if ok then
			ok, err = Profiles.Use(name)
		end
	elseif sub == "copy" then
		ok, err = Profiles.Create(name, active)
		if ok then
			ok, err = Profiles.Use(name)
		end
	elseif sub == "rename" then
		ok, err = Profiles.Rename(active, name)
	elseif sub == "delete" then
		ok, err = Profiles.Delete(name)
	elseif sub == "reset" then
		ok, err = Profiles.Reset(active)
	else
		ns.Print(PROFILE_USAGE)
		return
	end

	if not ok then
		ns.Print("|cffff0000" .. tostring(err) .. "|r")
		return
	end
	ns.Printf("Done. Active profile: |cffffff00%s|r", Profiles.ActiveName())
	ApplyAndReport("profile " .. sub)
end)
