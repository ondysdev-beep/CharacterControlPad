-- Diagnostics cleanup tests: migration, silent login, /fpad debug namespace
local overrides, tempcvars, eventFrames = {}, {}, {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "none" }
local printed = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end
local Widget = {}
Widget.__index = function(t, k) return Widget[k] or function() end end
function Widget:SetText(s) self.text = s end
function Widget:GetText() return rawget(self, "text") end
function Widget:Show() self.shown = true local s = rawget(self, "scripts") if s and s.OnShow then s.OnShow(self) end end
function Widget:Hide() self.shown = false local s = rawget(self, "scripts") if s and s.OnHide then s.OnHide(self) end end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown == true end
function Widget:SetScript(k, fn) self.scripts[k] = fn end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function NewWidget() return setmetatable({ scripts = {}, shown = true, enabled = true }, Widget) end
function CreateFrame(kind, name, parent)
  local f = NewWidget() if name then _G[name] = f end
  f.StartMoving = function() end f.StopMovingOrSizing = function() end
  f.children = {} if parent and rawget(parent, "children") then table.insert(parent.children, f) end
  eventFrames[#eventFrames+1] = f
  return f
end
UIParent = NewWidget() UIParent.children = {} UISpecialFrames = {} GameTooltip = NewWidget()
SlashCmdList = {}
function geterrorhandler() return function(e) error(e) end end
function InCombatLockdown() return false end
function IsShiftKeyDown() return false end function IsControlKeyDown() return false end function IsAltKeyDown() return false end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function GetBuildInfo() return "1.60.1", "70959", "Nov 13 2026", 16001 end
function GetLocale() return "enUS" end
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function HasAction(slot) return false end
C_KeyBindings = { GetBindingIndex = function() return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
C_GamePad = { IsEnabled = function() return true end, GetActiveDeviceID = function() return 5 end, GetAllDeviceIDs = function() return {} end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }

-- SavedVariables from an old diagnostic build
ForeverPadDB = { setupDone = true, audit = { big = true }, inputLog = { {}, {} }, identify = { Cross = "PAD1" }, poc = {}, listenSetup = {}, inputScriptSupport = {}, buttonStateIndexOffset = 1 }

local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua", "ConfigWindow.lua",
  "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua", "Audit.lua", "InputDiagnostics.lua" }) do
  assert(loadfile(ROOT .. f))("ForeverPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local function printedHas(s) for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end return false end

fire("ADDON_LOADED", "ForeverPad")
local db = ForeverPadDB
ok(db.audit == nil and db.inputLog == nil and db.identify == nil and db.poc == nil and db.listenSetup == nil
  and db.inputScriptSupport == nil and db.buttonStateIndexOffset == nil, "old diagnostic data removed on load")
ok(db.setupDone == true, "player data kept")

printed = {}
fire("PLAYER_LOGIN")
ok(db.audit == nil and db.inputLog == nil, "login stores no diagnostics")
ok(#printed == 1 and printed[1]:find("/fpad = settings", 1, true), "exactly one chat line at login: " .. table.concat(printed, " || "))

printed = {}
fire("GAME_PAD_CONNECTED") fire("GAME_PAD_DISCONNECTED") fire("INPUT_DEVICE_INTERFACE_TRANSITION", 0, 0)
ok(#printed <= 1 and db.inputLog == nil, "device events silent and unlogged outside debug")

printed = {}
SlashCmdList.FOREVERPAD("help")
ok(printedHas("/fpad map") and printedHas("/fpad debug") and not printedHas("/fpad listen") and not printedHas("/fpad audit"), "help hides diagnostics")

printed = {}
SlashCmdList.FOREVERPAD("debug")
ok(printedHas("/fpad debug listen") and printedHas("/fpad debug audit") and printedHas("/fpad debug identify"), "debug help lists tools")
ok(not db.debug, "debug help alone does not enable debug")

SlashCmdList.FOREVERPAD("debug status")
ok(db.debug == true, "running a debug tool enables debug mode")
fire("GAME_PAD_CONNECTED")
ok(db.inputLog and #db.inputLog == 1 and db.inputLog[1].kind == "CONNECTED", "events logged in debug mode")
SlashCmdList.FOREVERPAD("debug audit")
ok(db.audit and db.audit.client and db.audit.client.interface == 16001, "manual audit stored")
SlashCmdList.FOREVERPAD("debug listen")
SlashCmdList.FOREVERPAD("debug off")
ok(not db.debug and db.audit == nil and db.inputLog == nil, "debug off clears data")
ok(ForeverPadInputDiagFrame.shown == false, "debug off stops listening")

-- old player commands still work, old diag names no longer top-level
printed = {}
SlashCmdList.FOREVERPAD("listen")
ok(printedHas("/fpad map") and not db.debug, "/fpad listen is no longer a top-level command (shows help)")

io.write("DEBUG CLEANUP TESTS PASSED: " .. passed .. "\n")
