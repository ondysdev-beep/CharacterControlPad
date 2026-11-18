-- Localization tests: auto Czech via WowfCZ, private fonts, translated UI/data, language switch, fallbacks
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
function Widget:CreateFontString(_, _, font) local w = NewWidget() w.font = font return w end
function Widget:CreateTexture() return NewWidget() end
function Widget:SetNormalFontObject(f) self.normalFont = f end
function Widget:SetFontObject(f) self.fontObject = f end
function NewWidget() return setmetatable({ scripts = {}, shown = true, enabled = true }, Widget) end
function CreateFrame(kind, name, parent)
  local f = NewWidget() if name then _G[name] = f end
  f.StartMoving = function() end f.StopMovingOrSizing = function() end
  f.children = {} if parent and rawget(parent, "children") then table.insert(parent.children, f) end
  eventFrames[#eventFrames+1] = f
  return f
end
-- font objects
local fontLoadWorks = true
local function FontObject(size) return { size = size, GetFont = function(self) return "Fonts\\FRIZQT__.TTF", self.size, "" end } end
for _, n in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall", "ChatFontNormal" }) do _G[n] = FontObject(12) end
function CreateFont(name)
  local f = { name = name }
  function f:CopyFontObject(o) self.size = o.size end
  function f:GetFont() return self.path, self.size, "" end
  function f:SetFont(path, size, flags) if not fontLoadWorks then return false end self.path = path self.size = size return true end
  _G[name] = f
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
function HasAction(slot) return slot <= 12 end
function GetActionInfo(slot) return "spell", 900 + slot end
function GetActionTexture() return 1 end
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
C_KeyBindings = { GetBindingIndex = function() return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
local wowfczState = 2
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnEnableState = function(name) if name == "WowfCZ" then return wowfczState end return 0 end }
local reloaded = 0
C_UI = { Reload = function() reloaded = reloaded + 1 end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
for i = 1, 12 do _G["ActionButton" .. i] = NewWidget() _G["ActionButton" .. i].action = i end
MainActionBar = NewWidget()

CharacterControlPadDB = { setupDone = true }
local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua",
  "ConfigWindow.lua", "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua" }) do
  assert(loadfile(ROOT .. f))("CharacterControlPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local function printedHas(s) for _, l in ipairs(printed) do if l:find(s, 1, true) then return true end end return false end

fire("ADDON_LOADED", "CharacterControlPad")
ok(ns.language == "csCZ", "auto -> Czech because WowfCZ is enabled")
ok(ns.Font("GameFontNormal") == "CharacterControlPad_GameFontNormal", "private font object created")
ok(CharacterControlPad_GameFontNormal.path:find("NotoSans") ~= nil and CharacterControlPad_GameFontNormal.size == 12, "private font uses bundled Noto Sans, same size")
ok(ns.L.CHANGE == "Změnit" and ns.L.QB_ASSIGNED == "|cff00ff00%s|r -> %s", "Czech strings with English fallback")
ok(ns.buttonById.CROSS.label == "Křížek" and ns.BARS[1].label == "Hlavní bar" and ns.commandLabel.JUMP == "Skok", "data labels translated")
ok(ns.FindButton("Cross") == ns.buttonById.CROSS and ns.FindButton("x") == ns.buttonById.CROSS, "English input still works for slash commands")

fire("PLAYER_LOGIN")
ok(printedHas("Profil 'Default' aktivní") and printedHas("/ccp = nastavení"), "login line in Czech")

SlashCmdList.CHARACTERCONTROLPAD("")
local cf = CharacterControlPadConfigFrame
ok(cf.status.text:find("Stav") and cf.status.text:find("aktivní"), "config status in Czech")
ok(cf.status.font == "CharacterControlPad_GameFontHighlightSmall", "config font strings use private font")
ok(cf.quickBind.text == "Přiřadit na barech" and cf.quickBind.normalFont == "CharacterControlPad_GameFontNormal", "buttons translated and re-fonted")
ok(cf.language.text == "English", "language button offers English")

-- tooltip: private tooltip, GameTooltip untouched
ns.ShowActionTooltip(cf, 1, "x")
ok(ns.tooltip ~= GameTooltip and CharacterControlPadTooltip ~= nil, "private tooltip frame used")

-- switch language -> reload
cf.language.scripts.OnClick()
ok(CharacterControlPadDB.language == "enUS" and reloaded == 1, "language button sets English and reloads UI")

-- /ccp lang
SlashCmdList.CHARACTERCONTROLPAD("lang auto")
ok(CharacterControlPadDB.language == "auto" and reloaded == 1, "/ccp lang auto (no forced reload)")

-- fresh load: explicit English even with WowfCZ; Blizzard fonts kept
CharacterControlPadDB.language = "enUS"
local ns2 = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua" }) do assert(loadfile(ROOT .. f))("CharacterControlPad", ns2) end
eventFrames[#eventFrames - 0].scripts.OnEvent(nil, "ADDON_LOADED", "CharacterControlPad")
ok(ns2.language == "enUS" and ns2.Font("GameFontNormal") == "GameFontNormal" and ns2.buttonById.CROSS.label == "Cross", "explicit English: no custom fonts, English labels")

-- font file failing to load -> fallback to Blizzard fonts, still Czech text
CharacterControlPadDB.language = "csCZ"
fontLoadWorks = false
local ns3 = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua" }) do assert(loadfile(ROOT .. f))("CharacterControlPad", ns3) end
eventFrames[#eventFrames].scripts.OnEvent(nil, "ADDON_LOADED", "CharacterControlPad")
ok(ns3.language == "csCZ" and ns3.Font("GameFontNormal") == "GameFontNormal" and not ns3.HasCustomFonts(), "missing font -> Blizzard fonts")

-- WowfCZ disabled -> auto English
CharacterControlPadDB.language = nil
wowfczState = 0
fontLoadWorks = true
local ns4 = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua" }) do assert(loadfile(ROOT .. f))("CharacterControlPad", ns4) end
eventFrames[#eventFrames].scripts.OnEvent(nil, "ADDON_LOADED", "CharacterControlPad")
ok(ns4.language == "enUS", "auto -> English without WowfCZ")

io.write("LOCALE TESTS PASSED: " .. passed .. "\n")
