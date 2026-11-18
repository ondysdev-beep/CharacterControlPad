-- CharacterControlPad - profiles (SavedVariables)
-- CharacterControlPadDB.profiles[name] = { modifiers = {...}, bindings = { [bindingKey] = action } }
-- CharacterControlPadDB.characters["Name-Realm"] = profileName
-- Class-based profiles are prepared for (profile names are free text) but not automated yet.

local _, ns = ...

local DEFAULT_NAME = "Default"

local Profiles = {}
ns.Profiles = Profiles

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = DeepCopy(v)
	end
	return out
end
ns.DeepCopy = DeepCopy

local function CharacterKey()
	local name = UnitName("player") or "?"
	local realm = GetRealmName() or "?"
	return name .. "-" .. realm
end

function Profiles.Init()
	local db = ns.db
	if type(db.profiles) ~= "table" then
		db.profiles = {}
	end
	if type(db.characters) ~= "table" then
		db.characters = {}
	end
	if not db.profiles[DEFAULT_NAME] then
		db.profiles[DEFAULT_NAME] = ns.CreateDefaultProfile()
	end
	-- Repair profiles saved by older versions / edited by hand.
	for _, p in pairs(db.profiles) do
		if type(p.bindings) ~= "table" then
			p.bindings = {}
		end
		if type(p.modifiers) ~= "table" then
			p.modifiers = DeepCopy(ns.CreateDefaultProfile().modifiers)
		end
	end
	local key = CharacterKey()
	if not db.profiles[db.characters[key] or ""] then
		db.characters[key] = DEFAULT_NAME
	end
end

function Profiles.ActiveName()
	return ns.db.characters[CharacterKey()] or DEFAULT_NAME
end

function Profiles.Active()
	return ns.db.profiles[Profiles.ActiveName()]
end

function Profiles.Exists(name)
	return ns.db.profiles[name] ~= nil
end

function Profiles.List()
	local names = {}
	for name in pairs(ns.db.profiles) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

function Profiles.Use(name)
	if not Profiles.Exists(name) then
		return false, "no such profile: " .. tostring(name)
	end
	ns.db.characters[CharacterKey()] = name
	return true
end

-- Empty profile: default modifiers, no bindings (the player builds the layout).
function Profiles.CreateEmptyProfile()
	local p = ns.CreateDefaultProfile()
	p.bindings = {}
	return p
end

-- source: "empty" | "template" (default) | name of an existing profile to copy
function Profiles.Create(name, source)
	if not name or name == "" then
		return false, "missing name"
	end
	if Profiles.Exists(name) then
		return false, "profile already exists: " .. name
	end
	if source == "empty" then
		ns.db.profiles[name] = Profiles.CreateEmptyProfile()
	elseif source == nil or source == "template" then
		ns.db.profiles[name] = ns.CreateDefaultProfile()
	else
		if not Profiles.Exists(source) then
			return false, "no such profile: " .. tostring(source)
		end
		ns.db.profiles[name] = DeepCopy(ns.db.profiles[source])
	end
	return true
end

function Profiles.CountCharacters(name)
	local n = 0
	for _, assigned in pairs(ns.db.characters) do
		if assigned == name then
			n = n + 1
		end
	end
	return n
end

function Profiles.Rename(oldName, newName)
	if not Profiles.Exists(oldName) then
		return false, "no such profile: " .. tostring(oldName)
	end
	if not newName or newName == "" or Profiles.Exists(newName) then
		return false, "invalid or existing name: " .. tostring(newName)
	end
	ns.db.profiles[newName] = ns.db.profiles[oldName]
	ns.db.profiles[oldName] = nil
	for char, assigned in pairs(ns.db.characters) do
		if assigned == oldName then
			ns.db.characters[char] = newName
		end
	end
	return true
end

function Profiles.Delete(name)
	if not Profiles.Exists(name) then
		return false, "no such profile: " .. tostring(name)
	end
	if name == DEFAULT_NAME then
		return false, "the Default profile cannot be deleted (use /ccp profile reset)"
	end
	ns.db.profiles[name] = nil
	for char, assigned in pairs(ns.db.characters) do
		if assigned == name then
			ns.db.characters[char] = DEFAULT_NAME
		end
	end
	return true
end

function Profiles.Reset(name)
	if not Profiles.Exists(name) then
		return false, "no such profile: " .. tostring(name)
	end
	ns.db.profiles[name] = ns.CreateDefaultProfile()
	return true
end
