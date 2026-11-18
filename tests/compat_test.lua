-- Compatibility tests: click actions, conflict detection, addon detection, foreign buttons in quick bind
local overrides, clicks, tempcvars, eventFrames = {}, {}, {}, {}
local foreignBindings = {} -- simulate another addon owning a key with priority
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
function Widget:IsVisible() return self.shown == true end
function Widget:SetScript(k, fn) self.scripts[k] = fn end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function Widget:GetName() return rawget(self, "name") end
function Widget:GetObjectType() return rawget(self, "objectType") or "Frame" end
function Widget:GetParent() return rawget(self, "parent") end
function Widget:GetAttribute(k) local a = rawget(self, "attrs") return a and a[k] end
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
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function SetOverrideBindingClick(o, p, key, name, mouse) overrides[key] = "CLICK " .. name .. ":" .. (mouse or "LeftButton") end
function GetBindingAction(key, checkOverride) return foreignBindings[key] or overrides[key] or "" end
function HasAction(slot) return slot == 7 or slot <= 12 end
function GetActionInfo(slot) return "spell", 900 + slot end
function GetActionTexture(slot) return 2000 + slot end
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
C_KeyBindings = { GetBindingIndex = function() return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
C_AddOns = { IsAddOnLoaded = function(n) return (n == "ConsolePort" or n == "Bartender4"), true end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
MainActionBar = NewWidget()
-- Blizzard bars hidden (bar addon replaced them)
for i = 1, 12 do _G["ActionButton" .. i] = NewWidget() _G["ActionButton" .. i].action = i _G["ActionButton" .. i].shown = false end
-- Bartender-like button: Button with LAB state, a child texture under the mouse
BT4Button7 = NewWidget() BT4Button7.name = "BT4Button7" BT4Button7.objectType = "CheckButton" BT4Button7._state_action = 7
local bt4Icon = NewWidget() bt4Icon.objectType = "Texture" bt4Icon.parent = BT4Button7
local mouseFocus
function GetMouseFoci() return { mouseFocus } end

ForeverPadDB = { setupDone = true }
local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua",
  "ConfigWindow.lua", "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua" }) do
  assert(loadfile(ROOT .. f))("ForeverPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local function printedHas(s) for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end return false end

-- another addon owns PAD2 with priority
foreignBindings.PAD2 = "CLICK ConsolePortButton:LeftButton"
fire("ADDON_LOADED", "ForeverPad") fire("PLAYER_LOGIN")
local db = ForeverPadDB
ok(printedHas("ConsolePort is loaded") and printedHas("Bartender4 detected"), "known addons reported at login")
ok(db.lastApply.conflicts.PAD2 == "CLICK ConsolePortButton:LeftButton", "conflict detected for PAD2")
ok(db.lastApply.conflicts.PAD1 == nil, "no false conflict for PAD1")
ok(printedHas("Circle is overridden by another addon"), "conflict printed")

SlashCmdList.FOREVERPAD("")
local cf = ForeverPadConfigFrame
ok(cf.compat.text:find("ConsolePort") and cf.compat.text:find("Bartender4"), "config window shows compatibility notes")
ok(cf.errors.text:find("1 binding"), "conflict counted in errors line: " .. tostring(cf.errors.text))

-- /fpad map click
SlashCmdList.FOREVERPAD("map L2 click BT4Button7")
ok(db.profiles.Default.bindings.PADLTRIGGER.type == "click" and overrides.PADLTRIGGER == "CLICK BT4Button7:LeftButton", "/fpad map ... click")
local text, icon, slot = ns.Config.ActionInfo(db.profiles.Default.bindings.PADLTRIGGER)
ok(text:find("Spell907") and text:find("BT4Button7") and icon == 2007 and slot == 7, "click action shows slot content from LAB button")
local missing = ns.Config.ActionInfo({ type = "click", button = "NoSuchButton" })
ok(missing:find("button not found"), "missing frame reported")
ok(ns.Engine.DescribeAction(db.profiles.Default.bindings.PADLTRIGGER):find("slot 7"), "/fpad list describes click action")

-- quick bind on a foreign button (no overlays because Blizzard bars are hidden)
cf.quickBind.scripts.OnClick()
ok(ns.QuickBind.IsActive(), "quick bind active")
local cap = ForeverPadQuickBindCapture
mouseFocus = bt4Icon
cap.scripts.OnGamePadButtonDown(cap, "PAD3")
ok(overrides.PAD3 == "CLICK BT4Button7:LeftButton", "Square bound to hovered Bartender button via parent walk")
ok(ForeverPadQuickBindBanner.result.text:find("BT4Button7"), "banner reports foreign button")
-- hovering our own windows or nothing -> hover-first message
mouseFocus = ForeverPadQuickBindBanner
ForeverPadQuickBindBanner.name = "ForeverPadQuickBindBanner" ForeverPadQuickBindBanner.objectType = "Button"
cap.scripts.OnGamePadButtonDown(cap, "PAD4")
ok(overrides.PAD4 ~= "CLICK ForeverPadQuickBindBanner:LeftButton" and ForeverPadQuickBindBanner.result.text:find("Hover"), "own frames ignored")
mouseFocus = nil
cap.scripts.OnGamePadButtonDown(cap, "PAD4")
ok(ForeverPadQuickBindBanner.result.text:find("Hover"), "nothing under mouse -> hover hint")
-- plain non-action button is not accepted
local plain = NewWidget() plain.name = "SomeOptionsButton" plain.objectType = "Button"
mouseFocus = plain
cap.scripts.OnGamePadButtonDown(cap, "PAD4")
ok(overrides.PAD4 ~= "CLICK SomeOptionsButton:LeftButton", "non-action buttons ignored")
ns.QuickBind.Stop()

io.write("COMPAT TESTS PASSED: " .. passed .. "\n")
