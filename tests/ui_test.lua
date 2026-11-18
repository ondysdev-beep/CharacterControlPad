-- Widget mocks: every frame/region records text, shown state, scripts, enabled state.
local overrides, tempcvars, eventFrames = {}, {}, {}
local cvars = { GamePadEmulateShift = "PADLTRIGGER", GamePadEmulateCtrl = "PADRTRIGGER", GamePadEmulateAlt = "none" }
local printed = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end
local combat = false
local Widget = {}
Widget.__index = function(t, k) return Widget[k] or function() end end
function Widget:SetText(s) self.text = s end
function Widget:GetText() return self.text end
function Widget:Show() self.shown = true local s = rawget(self, "scripts") if s and s.OnShow then s.OnShow(self) end end
function Widget:Hide() self.shown = false local s = rawget(self, "scripts") if s and s.OnHide then s.OnHide(self) end end
function Widget:IsShown() return self.shown == true end
function Widget:SetScript(k, fn) self.scripts[k] = fn end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:LockHighlight() self.locked = true end
function Widget:UnlockHighlight() self.locked = false end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function Widget:SetTexture(t) self.texture = t end
function NewWidget() return setmetatable({ scripts = {}, shown = true, enabled = true }, Widget) end
function CreateFrame(kind, name, parent, template)
  if template == "BasicFrameTemplateWithInset" and NO_TEMPLATE then error("Couldn't find inherited node") end
  local f = NewWidget() if name then _G[name] = f end
  f.StartMoving = function() end f.StopMovingOrSizing = function() end
  f.children = {} if parent and rawget(parent, "children") then table.insert(parent.children, f) end
  eventFrames[#eventFrames+1] = f
  return f
end
UIParent = NewWidget() UISpecialFrames = {} GameTooltip = NewWidget()
SlashCmdList = {}
function geterrorhandler() return function(e) error(e) end end
function InCombatLockdown() return combat end
function UnitName() return "Tester" end
function GetRealmName() return "Realm" end
function date() return "now" end
function GetTime() return 1 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function ClearOverrideBindings() for k in pairs(overrides) do overrides[k] = nil end end
function SetOverrideBinding(o, p, key, cmd) overrides[key] = cmd end
function HasAction(slot) return slot == 1 or slot == 61 end
function GetActionInfo(slot) return "spell", 915 end
function GetActionTexture(slot) if HasAction(slot) then return 136048 end end
C_Spell = { GetSpellName = function() return "Lightning Bolt" end }
C_KeyBindings = { GetBindingIndex = function(c) if c == "TOGGLESOCIAL" then return nil end return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
ActionButton1 = { action = 1 }
MainActionBar = NewWidget() MultiBarBottomLeft = NewWidget() MultiBarBottomLeft.shown = false

local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua", "ConfigWindow.lua", "ActionPicker.lua" }) do
  assert(loadfile(ROOT .. f))("ForeverPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end

fire("ADDON_LOADED", "ForeverPad") fire("PLAYER_LOGIN")
SlashCmdList.FOREVERPAD("")
local cf = ForeverPadConfigFrame
ok(cf and cf.shown, "/fpad opens config window")
ok(cf.title.text:find("ForeverPad") ~= nil, "window title")
ok(cf.status.text:find("Default") and cf.status.text:find("active"), "status line shows profile + active")
ok(cf.status.text:find("L1=SHIFT") and cf.status.text:find("R1=CTRL"), "status shows modifiers")

local function visibleRows()
  local r = {}
  for _, c in ipairs(cf.children) do if rawget(c, "bindingKey") and c.shown then r[#r+1] = c end end
  return r
end
local rows = visibleRows()
local dbg = {} for _, r in ipairs(rows) do dbg[#dbg+1] = tostring(r.bindingKey) .. (r.label and "" or "(nolabel)") end
ok(#rows == 18, table.concat(dbg, ",") .. "base layer: 18 rows (19 buttons minus PS), got " .. #rows)
ok(rows[1].bindingKey == "PAD1" and rows[1].text.text:find("Lightning Bolt"), "Cross row shows Lightning Bolt")
ok(rows[1].icon.texture == 136048, "Cross row icon from GetActionTexture")
local l1row
for _, r in ipairs(rows) do if r.bindingKey == "PADLSHOULDER" then l1row = r end end
ok(l1row and l1row.isTap and l1row.label.text:find("tap"), "L1 shown as tap row in base layer")

local tabs = {}
for _, c in ipairs(cf.children) do if type(rawget(c, "text")) == "string" and (c.text == "No modifier" or c.text == "L1" or c.text == "R1" or c.text == "L1+R1") then tabs[c.text] = c end end
ok(tabs["No modifier"] and tabs["L1"] and tabs["R1"] and tabs["L1+R1"], "4 layer tabs for 2 modifiers")
tabs["L1"].scripts.OnClick()
rows = visibleRows()
ok(#rows == 16 and rows[1].bindingKey == "SHIFT-PAD1", "L1 layer: 16 rows, first SHIFT-PAD1")
tabs["L1+R1"].scripts.OnClick()
rows = visibleRows()
ok(rows[1].bindingKey == "CTRL-SHIFT-PAD1", "L1+R1 layer key canonical CTRL-SHIFT-")

rows[1].change.scripts.OnClick()
local pk = ForeverPadActionPicker
ok(pk and pk.shown, "picker opens")
ok(pk.title.text == "Assign: L1+R1+Cross", "picker title: " .. tostring(pk.title.text))
local cells = {}
local function collect(f) for _, c in ipairs(f.children or {}) do if rawget(c, "bar") then cells[#cells+1] = c end collect(c) end end
collect(pk)
ok(#cells == 96, "96 bar cells")
local target
for _, c in ipairs(cells) do if c.bar == 3 and c.button == 7 then target = c end end
target.scripts.OnClick(target)
ok(ForeverPadDB.profiles.Default.bindings["CTRL-SHIFT-PAD1"].bar == 3, "picker stored bar 3")
ok(overrides["CTRL-SHIFT-PAD1"] == "MULTIACTIONBAR2BUTTON7", "engine applied new binding")
ok(not pk.shown, "picker closes after select")

rows = visibleRows()
rows[1].change.scripts.OnClick()
local cmdButtons = {}
local function collectCmd(f) for _, c in ipairs(f.children or {}) do if rawget(c, "command") then cmdButtons[c.command] = c end collectCmd(c) end end
collectCmd(pk)
for _, c in ipairs(pk.children) do if c.text == "UI commands" then c.scripts.OnClick() end end
ok(cmdButtons.TOGGLESOCIAL.enabled == false, "unavailable command disabled")
cmdButtons.TOGGLEWORLDMAP.scripts.OnClick(cmdButtons.TOGGLEWORLDMAP)
ok(overrides["CTRL-SHIFT-PAD1"] == "TOGGLEWORLDMAP", "command assigned via picker")

rows = visibleRows()
rows[1].clear.scripts.OnClick()
ok(overrides["CTRL-SHIFT-PAD1"] == nil and ForeverPadDB.profiles.Default.bindings["CTRL-SHIFT-PAD1"] == nil, "X clears binding")

combat = true
fire("PLAYER_REGEN_DISABLED")
rows = visibleRows()
ok(rows[1].change.enabled == false and cf.status.text:find("in combat"), "editing locked in combat")
rows[1].change.scripts.OnClick()
ok(not pk.shown, "picker refuses in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
ok(visibleRows()[1].change.enabled == true, "unlocked after combat")

for _, c in ipairs(cf.children) do if c.text == "Disable" then c.scripts.OnClick() end end
ok(ForeverPadDB.enabled == false and next(overrides) == nil and cf.status.text:find("disabled"), "Disable button turns engine off")

ForeverPadDB.enabled = true
SlashCmdList.FOREVERPAD("mod alt L2")
cf:Hide() SlashCmdList.FOREVERPAD("")
local layerTabs = 0
for _, c in ipairs(cf.children) do
  if c.shown and type(rawget(c, "text")) == "string" and not rawget(c, "bindingKey") and (c.text == "No modifier" or c.text:match("^[LR][12]")) then layerTabs = layerTabs + 1 end
end
ok(layerTabs == 8, "8 layer tabs with 3 modifiers, got " .. layerTabs)

NO_TEMPLATE = true
local f2 = ns.CreatePanelFrame("TestFallbackFrame", 100, 100)
ok(f2 ~= nil, "fallback frame without template")

io.write("UI TESTS PASSED: " .. passed .. "\n")
