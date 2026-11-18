-- Rename migration: data saved by ForeverPad (<= 0.12.0) is taken over by CharacterControlPad.
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end

local function load(globals)
  for k in pairs({ CharacterControlPadDB = 1, ForeverPadDB = 1 }) do _G[k] = nil end
  for k, v in pairs(globals) do _G[k] = v end
  local script
  CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(_, _, fn) script = fn end }
  end
  SlashCmdList = {}
  print = function() end
  local ns = {}
  assert(loadfile(ROOT .. "Core.lua"))("CharacterControlPad", ns)
  script(nil, "ADDON_LOADED", "CharacterControlPad")
  return ns
end

local old = {
  enabled = true,
  characters = { ["Hero-Realm"] = "zkouska" },
  profiles = { zkouska = { modifiers = { SHIFT = "PADRTRIGGER" }, bindings = { PAD1 = { type = "command", command = "JUMP" } } } },
}
local ns = load({ ForeverPadDB = old })
ok(ns.db == CharacterControlPadDB and ns.db.profiles.zkouska.bindings.PAD1.command == "JUMP", "old ForeverPad profiles taken over")
ok(ns.db.characters["Hero-Realm"] == "zkouska" and ns.db.migratedFrom == "ForeverPad", "characters kept, migration noted")
ok(ForeverPadDB == old, "old global left alone")

ns = load({ ForeverPadDB = { layout = { x = 1 } } })
ok(next(ns.db.profiles or {}) == nil and ns.db.migratedFrom == nil, "unrelated ForeverPad addon data ignored")

ns = load({ ForeverPadDB = old, CharacterControlPadDB = { profiles = { Main = { bindings = {}, modifiers = {} } }, characters = {} } })
ok(ns.db.profiles.Main and not ns.db.profiles.zkouska, "existing CharacterControlPad data wins")

ns = load({})
ok(type(ns.db) == "table" and ns.db.migratedFrom == nil, "fresh install")

io.write("MIGRATE TESTS PASSED: " .. passed .. "\n")
