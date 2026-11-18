-- Quick bind mode tests (widget mocks as in ui_test.lua)
local overrides, tempcvars, eventFrames = {}, {}, {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "none" }
print = function() end
local combat, shift, ctrl, alt = false, false, false, false
local Widget = {}
Widget.__index = function(t, k) return Widget[k] or function() end end
function Widget:SetText(s) self.text = s end
function Widget:Show() self.shown = true local s = rawget(self, "scripts") if s and s.OnShow then s.OnShow(self) end end
function Widget:Hide() self.shown = false local s = rawget(self, "scripts") if s and s.OnHide then s.OnHide(self) end end
function Widget:IsShown() return self.shown == true end
function Widget:IsVisible() return self.shown == true end
function Widget:SetScript(k, fn) self.scripts[k] = fn end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function Widget:SetAllPoints(target) self.anchor = target end
function Widget:SetPropagateKeyboardInput(v) self.propagate = v end
function Widget:EnableGamePadButton(v) self.gamepad = v end
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
function IsShiftKeyDown() return shift end
function IsControlKeyDown() return ctrl end
function IsAltKeyDown() return alt end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function HasAction(slot) return slot <= 12 end
function GetActionInfo(slot) return "spell", 900 + slot end
function GetActionTexture(slot) if HasAction(slot) then return 1000 + slot end end
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
C_KeyBindings = { GetBindingIndex = function(c) return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
for i = 1, 12 do _G["ActionButton" .. i] = NewWidget() _G["ActionButton" .. i].action = i end
for i = 1, 12 do _G["MultiBarBottomLeftButton" .. i] = NewWidget() _G["MultiBarBottomLeftButton" .. i].shown = false end
MainActionBar = NewWidget()

local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua", "ConfigWindow.lua", "ActionPicker.lua", "QuickBind.lua" }) do
  assert(loadfile(ROOT .. f))("CharacterControlPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end

fire("ADDON_LOADED", "CharacterControlPad") fire("PLAYER_LOGIN")
local db = CharacterControlPadDB
CharacterControlPadDB.profiles.Default.bindings = {} -- start empty, like a player building their own layout
ns.Engine.Apply("test")

SlashCmdList.CHARACTERCONTROLPAD("") -- open config
local cf = CharacterControlPadConfigFrame
ok(cf.shown, "config open")
cf.quickBind.scripts.OnClick()
ok(ns.QuickBind.IsActive(), "quick bind starts from config button")
ok(not cf.shown, "config hidden during quick bind")
local cap = CharacterControlPadQuickBindCapture
ok(cap.shown and cap.gamepad == true and cap.propagate == false, "capture frame: gamepad on, propagation off")
local banner = CharacterControlPadQuickBindBanner
ok(banner.shown, "banner shown")

local overlays = {}
for _, c in ipairs(eventFrames) do if rawget(c, "bar") and rawget(c, "button") then overlays[c.bar * 100 + c.button] = c end end
ok(overlays[101] and overlays[112] and overlays[101].shown, "overlays for 12 main bar buttons")
ok(overlays[201] == nil, "no overlays for hidden bottom left bar")
ok(overlays[103].anchor == ActionButton3, "overlay anchored to its Blizzard button")

-- press without hover
cap.scripts.OnGamePadButtonDown(cap, "PAD1")
ok(banner.result.text:find("Hover") ~= nil and next(db.profiles.Default.bindings) == nil, "press without hover does nothing")

-- hover ActionButton3, press Cross
overlays[103].scripts.OnEnter(overlays[103])
cap.scripts.OnGamePadButtonDown(cap, "PAD1")
ok(db.profiles.Default.bindings.PAD1.bar == 1 and db.profiles.Default.bindings.PAD1.button == 3, "Cross -> Main bar #3")
ok(overrides.PAD1 == "ACTIONBUTTON3", "engine applied ACTIONBUTTON3")
ok(overlays[103].label.text == "X", "overlay label shows X")
ok(banner.result.text:find("Spell903") ~= nil, "result shows spell name")

-- L1 held (SHIFT) + Cross on same button
shift = true
cap.scripts.OnGamePadButtonDown(cap, "PAD1")
shift = false
ok(overrides["SHIFT-PAD1"] == "ACTIONBUTTON3", "L1+Cross -> same button")
ok(overlays[103].label.text == "X\nL1+X", "overlay shows both combos: " .. tostring(overlays[103].label.text))

-- move Cross to button 5 -> 'was' message
overlays[103].scripts.OnLeave(overlays[103])
overlays[105].scripts.OnEnter(overlays[105])
cap.scripts.OnGamePadButtonDown(cap, "PAD1")
ok(overrides.PAD1 == "ACTIONBUTTON5" and banner.result.text:find("was") ~= nil, "reassigning shows previous target")

-- L1 tap (modifier alone) is allowed as tap binding; R1 while L1 held is rejected
cap.scripts.OnGamePadButtonDown(cap, "PADLSHOULDER")
ok(overrides.PADLSHOULDER == "ACTIONBUTTON5", "L1 tap binding")
shift = true
cap.scripts.OnGamePadButtonDown(cap, "PADRSHOULDER")
shift = false
ok(overrides["SHIFT-PADRSHOULDER"] == nil and banner.result.text:find("modifier") ~= nil, "modifier+modifier rejected")

-- PS ignored
cap.scripts.OnGamePadButtonDown(cap, "PADSYSTEM")
ok(overrides.PADSYSTEM == nil, "PS button ignored")

-- right click clears all combos on button 5
overlays[105].scripts.OnClick(overlays[105], "RightButton")
ok(overrides.PAD1 == nil and overrides.PADLSHOULDER == nil and overrides["SHIFT-PAD1"] == "ACTIONBUTTON3", "right-click clears only that button")

-- Esc (banner hide) stops, config reopens
banner:Hide()
ok(not ns.QuickBind.IsActive() and not cap.shown and cap.gamepad == false, "Esc stops mode, capture off")
ok(not overlays[103].shown, "overlays hidden after stop")
ok(cf.shown, "config window reopened")

-- combat stops mode
SlashCmdList.CHARACTERCONTROLPAD("bind")
ok(ns.QuickBind.IsActive(), "/ccp bind starts")
combat = true
fire("PLAYER_REGEN_DISABLED")
ok(not ns.QuickBind.IsActive() and not cap.shown, "combat stops quick bind")
SlashCmdList.CHARACTERCONTROLPAD("bind")
ok(not ns.QuickBind.IsActive(), "cannot start in combat")
combat = false

io.write("QUICK BIND TESTS PASSED: " .. passed .. "\n")
