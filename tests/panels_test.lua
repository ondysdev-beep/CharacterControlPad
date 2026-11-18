-- Modifier panel, profiles panel and setup wizard tests (widget mocks)
local overrides, tempcvars, eventFrames = {}, {}, {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "none", GamePadEmulateTapWindowMs = "350" }
print = function() end
local combat = false
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
function Widget:HookScript(k, fn) local old = self.scripts[k] self.scripts[k] = function(...) if old then old(...) end fn(...) end end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:LockHighlight() self.locked = true end
function Widget:UnlockHighlight() self.locked = false end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function NewWidget() return setmetatable({ scripts = {}, shown = true, enabled = true }, Widget) end
function CreateFrame(kind, name, parent, template)
  local f = NewWidget() if name then _G[name] = f end
  f.StartMoving = function() end f.StopMovingOrSizing = function() end
  f.children = {} if parent and rawget(parent, "children") then table.insert(parent.children, f) end
  eventFrames[#eventFrames+1] = f
  return f
end
UIParent = NewWidget() UIParent.children = {} UISpecialFrames = {} GameTooltip = NewWidget()
SlashCmdList = {}
function geterrorhandler() return function(e) error(e) end end
function InCombatLockdown() return combat end
function IsShiftKeyDown() return false end function IsControlKeyDown() return false end function IsAltKeyDown() return false end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function HasAction(slot) return slot <= 12 end
function GetActionInfo(slot) return "spell", 900 + slot end
function GetActionTexture(slot) return 1 end
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
C_KeyBindings = { GetBindingIndex = function(c) return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
for i = 1, 12 do _G["ActionButton" .. i] = NewWidget() _G["ActionButton" .. i].action = i end
MainActionBar = NewWidget()

local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua", "ConfigWindow.lua",
  "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua" }) do
  assert(loadfile(ROOT .. f))("ForeverPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local function findChild(f, text) for _, c in ipairs(f.children or {}) do if rawget(c, "text") == text then return c end local r = findChild(c, text) if r then return r end end end

---------------- wizard ----------------
fire("ADDON_LOADED", "ForeverPad") fire("PLAYER_LOGIN")
local db = ForeverPadDB
local wiz = ForeverPadSetupWizard
ok(wiz and wiz.shown, "wizard shows on first login")
findChild(wiz, "L1 + R1  (recommended)").scripts.OnClick()
local emptyBtn = findChild(wiz, "Empty - I will assign everything myself")
ok(emptyBtn ~= nil, "step 2 shown")
emptyBtn.scripts.OnClick()
local p = db.profiles.Default
ok(db.setupDone == true and next(p.bindings) == nil, "empty profile chosen, setup done")
ok(p.modifiers.SHIFT == "PADLSHOULDER" and C_CVar.GetCVar("GamePadEmulateShift") == "PADLSHOULDER", "L1+R1 applied")
ok(next(overrides) == nil, "no bindings after empty setup")
findChild(wiz, "Open settings").scripts.OnClick()
ok(not wiz.shown and ForeverPadConfigFrame.shown, "finish opens settings")

-- wizard not shown again
wiz.shown = false
fire("PLAYER_LOGIN")
ok(not wiz.shown, "wizard not shown after setupDone")

-- rerun with template + L2/R2
SlashCmdList.FOREVERPAD("setup")
findChild(wiz, "L2 + R2").scripts.OnClick()
findChild(wiz, "Template - start from a ready layout").scripts.OnClick()
ok(p.modifiers.SHIFT == "PADLTRIGGER" and overrides.PAD1 == "ACTIONBUTTON1", "template + L2/R2 via /fpad setup")
findChild(wiz, "Close").scripts.OnClick()

---------------- modifier panel ----------------
local cf = ForeverPadConfigFrame
if not cf.shown then SlashCmdList.FOREVERPAD("") end
cf.modifiersButton.scripts.OnClick()
local mp = ForeverPadModifierPanel
ok(mp.shown and mp.layers.text:find("4"), "modifier panel open, 4 layers")
ok(mp.apply.enabled == false, "apply disabled until change")
-- template has SHIFT-PADLTRIGGER bindings; making L2 the ALT modifier -> nothing (SHIFT is L2 now!). Instead: set SHIFT to L1
local function cell(mod, label) for _, c in ipairs(mp.children) do end end
-- find buttons by scanning children with text and position order: use internal grid via labels
local grid = {}
for _, c in ipairs(mp.children) do local t = rawget(c, "text") if t then grid[#grid+1] = c end end
-- buttons are created row by row: SHIFT row (7), CTRL row (7), ALT row (7)
local function btn(row, col) return grid[(row - 1) * 7 + col] end
ok(btn(1, 2).text == "L1" and btn(3, 1).text == "none", "grid layout")
btn(3, 4).scripts.OnClick() -- ALT = L2 ... but L2 is SHIFT -> SHIFT becomes none
ok(mp.layers.text:find("4") and mp.apply.enabled == true, "ALT=L2 moves L2 from SHIFT, still 4 layers")
ok(mp.affected.text:find("will be removed") ~= nil, "lists unreachable SHIFT- bindings")
btn(1, 2).scripts.OnClick() -- SHIFT = L1
ok(mp.layers.text:find("8"), "3 modifiers -> 8 layers")
ok(mp.affected.text:find("will be removed") ~= nil, "SHIFT-L2 style bindings (mod on mod) still listed")
mp.apply.scripts.OnClick()
ok(p.modifiers.ALT == "PADLTRIGGER" and p.modifiers.SHIFT == "PADLSHOULDER", "modifiers applied")
ok(p.bindings["SHIFT-PADLTRIGGER"] == nil and p.bindings["PADLTRIGGER"] ~= nil, "mod+mod binding removed, tap kept")
ok(overrides["SHIFT-PAD1"] == "ACTIONBUTTON5", "SHIFT layer kept, now reached with L1")
ok(C_CVar.GetCVar("GamePadEmulateAlt") == "PADLTRIGGER", "ALT cvar applied")

---------------- profiles panel ----------------
cf.profilesButton.scripts.OnClick()
local pp = ForeverPadProfilesPanel
ok(pp.shown and not mp.shown, "profiles panel replaces modifier panel")
ok(pp.active.text:find("Default"), "shows active profile")
findChild(pp, "New empty").scripts.OnClick(findChild(pp, "New empty"))
ok(tostring(pp.message.text):find("name"), "needs a name, got: " .. tostring(pp.message.text) .. " btn=" .. tostring(rawget(findChild(pp, "New empty"), "baseText")))
pp.nameBox:SetText("  Healer ")
findChild(pp, "New empty").scripts.OnClick(findChild(pp, "New empty"))
ok(ns.Profiles.ActiveName() == "Healer" and next(db.profiles.Healer.bindings) == nil, "new empty profile active (trimmed name)")
ok(next(overrides) == nil, "empty profile -> no bindings")
pp.nameBox:SetText("Tank")
findChild(pp, "New from template").scripts.OnClick(findChild(pp, "New from template"))
ok(ns.Profiles.ActiveName() == "Tank" and overrides.PAD1 == "ACTIONBUTTON1", "new from template")
-- list click -> use Default
local listBtn
for _, c in ipairs(pp.children) do if rawget(c, "profileName") == "Default" then listBtn = c end end
listBtn.scripts.OnClick(listBtn)
ok(ns.Profiles.ActiveName() == "Default", "clicking list uses profile")
-- delete needs confirm
local del = findChild(pp, "Delete active")
del.scripts.OnClick(del)
ok(db.profiles.Default ~= nil and del.text == "Click again to confirm", "delete asks confirmation")
del.scripts.OnClick(del)
ok(pp.message.text:find("cannot be deleted"), "Default cannot be deleted")
listBtn = nil
for _, c in ipairs(pp.children) do if rawget(c, "profileName") == "Tank" then listBtn = c end end
listBtn.scripts.OnClick(listBtn)
del = nil for _, c in ipairs(pp.children) do if rawget(c, "baseText") == "Delete active" then del = c end end
del.scripts.OnClick(del) del.scripts.OnClick(del)
ok(db.profiles.Tank == nil and ns.Profiles.ActiveName() == "Default", "Tank deleted after confirm")
-- clear all bindings with confirm
local clr; for _, c in ipairs(pp.children) do if rawget(c, "baseText") == "Clear all bindings" then clr = c end end
clr.scripts.OnClick(clr)
ok(next(db.profiles.Default.bindings) ~= nil, "clear waits for confirmation")
clr.scripts.OnClick(clr)
ok(next(db.profiles.Default.bindings) == nil and next(overrides) == nil, "clear all bindings")
-- rename
pp.nameBox:SetText("Main")
local ren; for _, c in ipairs(pp.children) do if rawget(c, "baseText") == "Rename active" then ren = c end end
ren.scripts.OnClick(ren)
ok(ns.Profiles.ActiveName() == "Main" and db.profiles.Default == nil, "rename active")
ok(cf.status.text:find("Main"), "config window status follows profile")

---------------- combat ----------------
combat = true
fire("PLAYER_REGEN_DISABLED")
ok(not pp.shown, "side panels close in combat")
cf.profilesButton.scripts.OnClick()
ok(not pp.shown, "cannot open in combat")
combat = false

io.write("PANEL TESTS PASSED: " .. passed .. "\n")
