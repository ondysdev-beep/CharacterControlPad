-- Minimal WoW API stubs, then load addon files in TOC order and test engine logic.
local events, overrides, tempcvars, frames = {}, {}, {}, {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "none", GamePadEmulateTapWindowMs = "350" }
local printed = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end
function CreateFrame() local f = {} f.RegisterEvent = function(self, e) events[e] = true end f.SetScript = function(self, k, fn) self[k] = fn end
  f.SetSize = function() end f.SetPoint = function() end f.Hide = function() end f.Show = function() end frames[#frames+1] = f return f end
UIParent = {}
SlashCmdList = {}
function geterrorhandler() return function(e) error(e) end end
function InCombatLockdown() return false end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings(o) for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function HasAction(slot) return slot == 1 end
function GetActionInfo(slot) return "spell", 915 end
C_Spell = { GetSpellName = function(id) return "Lightning Bolt" end }
C_KeyBindings = { GetBindingIndex = function(c) if c == "NOPE" then return nil end return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end,
  SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
local style = 0
C_InputInterfaceStyle = { GetCurrentStyle = function() return style end }
ActionButton1 = { action = 1 }

local ns = {}
local function load(file) local chunk = assert(loadfile(ROOT .. file)); chunk("ForeverPad", ns) end
for _, f in ipairs({ "Core.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Commands.lua" }) do load(f) end

-- simulate ADDON_LOADED + PLAYER_LOGIN through the event frame
local function fire(e, ...) frames[1].OnEvent(frames[1], e, ...) end
local function check(cond, msg) if not cond then error("FAIL: " .. msg, 2) end print("ok  " .. msg) end

fire("ADDON_LOADED", "ForeverPad")
fire("PLAYER_LOGIN")
local db = ForeverPadDB
check(db.profiles.Default ~= nil, "default profile created")
check(db.characters["Tester-Realm"] == "Default", "character assigned to Default")
check(db.lastApply.status == "active", "engine active in Mkb")
check(overrides["PAD1"] == "ACTIONBUTTON1", "PAD1 -> ACTIONBUTTON1")
check(overrides["SHIFT-PAD1"] == "ACTIONBUTTON5", "SHIFT-PAD1 -> ACTIONBUTTON5")
check(overrides["CTRL-SHIFT-PAD4"] == "MULTIACTIONBAR1BUTTON4", "CTRL-SHIFT-PAD4 -> MULTIACTIONBAR1BUTTON4")
check(overrides["PADBACK"] == "TOGGLEWORLDMAP", "Touchpad -> world map")
check(C_CVar.GetCVar("GamePadEmulateShift") == "PADLSHOULDER", "temp cvar shift = L1")
check(C_CVar.GetCVar("GamePadEmulateCtrl") == "PADRSHOULDER", "temp cvar ctrl = R1")
check(cvars.GamePadEmulateShift == "PADLTRIGGER", "persistent cvar untouched")

local p = ns.Profiles.Active()
local key = ns.Engine.ParseCombo("L1+R1+Cross", p)
check(key == "CTRL-SHIFT-PAD1", "parse L1+R1+Cross")
check(ns.Engine.ParseCombo("r1+l1+x", p) == "CTRL-SHIFT-PAD1", "parse aliases / order independent")
local k2, _, tap = ns.Engine.ParseCombo("L1", p)
check(k2 == "PADLSHOULDER" and tap == true, "L1 alone = tap binding")
check(ns.Engine.ParseCombo("L1+R1", p) == nil, "L1+R1 rejected")
check(ns.Engine.ParseCombo("Cross+Circle", p) == nil, "two main buttons rejected")
check(ns.Engine.ParseCombo("Foo", p) == nil, "unknown button rejected")
check(ns.Engine.KeyToCombo("CTRL-SHIFT-PAD1", p) == "L1+R1+Cross", "key to combo label")
check(ns.Engine.DescribeAction(p.bindings["PAD1"]):find("Lightning Bolt") ~= nil, "describe shows spell name")

SlashCmdList.FOREVERPAD("map L2+Circle bar 3 7")
check(overrides["PADLTRIGGER"] == "MULTIACTIONBAR1BUTTON5", "L2 still plain trigger binding")
SlashCmdList.FOREVERPAD("map L1+L2 bar 3 7")
check(overrides["SHIFT-PADLTRIGGER"] == "MULTIACTIONBAR2BUTTON7", "map L1+L2 -> bar3 #7")
SlashCmdList.FOREVERPAD("map Mute cmd NOPE")
check(p.bindings["PAD5"] == nil, "invalid command refused")
SlashCmdList.FOREVERPAD("map Mute cmd sitorstand")
check(overrides["PAD5"] == "SITORSTAND", "command mapping (case-insensitive)")
SlashCmdList.FOREVERPAD("unmap Mute")
check(overrides["PAD5"] == nil, "unmap removes binding")

SlashCmdList.FOREVERPAD("mod alt L1")
check(p.modifiers.ALT == "none", "same button cannot be two modifiers")
SlashCmdList.FOREVERPAD("mod alt L2")
check(C_CVar.GetCVar("GamePadEmulateAlt") == "PADLTRIGGER", "alt = L2 applied")

SlashCmdList.FOREVERPAD("profile copy Hunter")
check(ns.Profiles.ActiveName() == "Hunter" and db.profiles.Hunter.bindings["SHIFT-PADLTRIGGER"] ~= nil, "profile copy + use")
SlashCmdList.FOREVERPAD("profile rename Hunter2")
check(db.profiles.Hunter2 and not db.profiles.Hunter and db.characters["Tester-Realm"] == "Hunter2", "rename keeps assignment")
SlashCmdList.FOREVERPAD("profile delete Default")
check(db.profiles.Default ~= nil, "Default cannot be deleted")
SlashCmdList.FOREVERPAD("profile delete Hunter2")
check(ns.Profiles.ActiveName() == "Default", "deleting active falls back to Default")

SlashCmdList.FOREVERPAD("off")
check(next(overrides) == nil and C_CVar.GetCVar("GamePadEmulateShift") == "PADLTRIGGER", "off clears bindings and restores modifiers")
SlashCmdList.FOREVERPAD("on")
check(overrides["PAD1"] == "ACTIONBUTTON1", "on re-applies")

style = 1
fire("INPUT_DEVICE_INTERFACE_TRANSITION", 1, 0)
check(next(overrides) == nil and db.lastApply.status:find("paused") ~= nil, "gamepad UI pauses engine")
check(C_CVar.GetCVar("GamePadEmulateShift") == "PADLTRIGGER", "gamepad UI restores modifiers")
style = 0

InCombatLockdown = function() return true end
SlashCmdList.FOREVERPAD("apply")
check(next(overrides) == nil, "no binding change in combat")
InCombatLockdown = function() return false end
fire("PLAYER_REGEN_ENABLED")
check(overrides["PAD1"] == "ACTIONBUTTON1", "pending apply after combat")

io.write("\nALL TESTS PASSED\n")
