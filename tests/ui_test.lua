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

ok(cf.pages.controller.shown and cf.pageTabs.controller.selected, "controller page shown first")

-- slots around the controller picture, found by binding key
local function slotsByKey()
  local r, n = {}, 0
  for _, s in ipairs(cf.slots) do local k = rawget(s, "bindingKey") if k then r[k] = s n = n + 1 end end
  return r, n
end
local function click(s, mouse) s.scripts.OnClick(s, mouse or "LeftButton") end
local slots, count = slotsByKey()
ok(#cf.slots == 18 and count == 18, "base layer: 18 slots (19 buttons minus PS), got " .. count)
ok(#cf.markers == 18, "every slot has a marker on the controller picture")
ok(slots.PAD1.text.text == "Lightning Bolt" and slots.PAD1.sub.text == "Main bar #1", "Cross slot shows spell and where it lives")
ok(slots.PAD1.icon.texture == 136048 and slots.PAD1.glyph ~= nil, "Cross slot: action icon + Cross glyph")
ok(slots.PADLSHOULDER.isTap and slots.PADLSHOULDER.sub.text:find("tap"), "L1 shown as tap slot in base layer")
ok(slots.PADLSHOULDER.pillText.text == "L1", "L1 slot labelled with a text badge")
ok(slots.PADDUP.text.text:find("Jump") and slots.PADDUP.sub.text == "command", "command slot")

-- hovering a slot lights its button on the controller
slots.PAD1.scripts.OnEnter(slots.PAD1)
ok(slots.PAD1.marker.glow.shown and slots.PAD1.hover.shown, "hover highlights the controller button")
slots.PAD1.scripts.OnLeave(slots.PAD1)
ok(not slots.PAD1.marker.glow.shown, "highlight off after leave")

local tabs = {}
for _, b in ipairs(cf.layerButtons) do if b.shown then tabs[b.text] = b end end
ok(tabs["No modifier"] and tabs["L1"] and tabs["R1"] and tabs["L1+R1"], "4 layer buttons for 2 modifiers")
ok(tabs["No modifier"].selected and not tabs["L1"].selected, "base layer selected")
tabs["L1"].scripts.OnClick(tabs["L1"])
slots, count = slotsByKey()
ok(count == 16 and slots["SHIFT-PAD1"] ~= nil, "L1 layer: 16 slots, SHIFT-PAD1, got " .. count)
local held = 0
for _, s in ipairs(cf.slots) do if s.heldModifier then held = held + 1 ok(s.enabled == false, "held modifier slot not editable") end end
ok(held == 2, "L1 and R1 shown as held in the L1 layer")
tabs["L1+R1"].scripts.OnClick(tabs["L1+R1"])
slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"] ~= nil and tabs["L1+R1"].selected, "L1+R1 layer key canonical CTRL-SHIFT-")

-- holding a modifier shows its layer while held
local shiftDown = false
IsShiftKeyDown = function() return shiftDown end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
local page = cf.pages.controller
shiftDown = true page.scripts.OnUpdate(page, 0.1)
slots = slotsByKey()
ok(slots["SHIFT-PAD1"] ~= nil and tabs["L1"].selected, "holding L1 (SHIFT) shows the L1 layer")
shiftDown = false page.scripts.OnUpdate(page, 0.1)
slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"] ~= nil, "releasing returns to the chosen layer")

click(slots["CTRL-SHIFT-PAD1"])
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

slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"].sub.text == "Bottom right bar #7", "slot shows the new binding")
local m = slots["CTRL-SHIFT-PAD1"].marker
m.scripts.OnClick(m, "LeftButton")
ok(pk.shown, "clicking the button on the controller picture opens the picker")
local cmdButtons = {}
local function collectCmd(f) for _, c in ipairs(f.children or {}) do if rawget(c, "command") then cmdButtons[c.command] = c end collectCmd(c) end end
collectCmd(pk)
for _, c in ipairs(pk.children) do if c.text == "UI commands" then c.scripts.OnClick() end end
ok(cmdButtons.TOGGLESOCIAL.enabled == false, "unavailable command disabled")
cmdButtons.TOGGLEWORLDMAP.scripts.OnClick(cmdButtons.TOGGLEWORLDMAP)
ok(overrides["CTRL-SHIFT-PAD1"] == "TOGGLEWORLDMAP", "command assigned via picker")

slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"].text.text:find("World map"), "command shown in the slot")
click(slots["CTRL-SHIFT-PAD1"], "RightButton")
ok(overrides["CTRL-SHIFT-PAD1"] == nil and ForeverPadDB.profiles.Default.bindings["CTRL-SHIFT-PAD1"] == nil, "right-click clears binding")
slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"].text.text:find("not assigned"), "cleared slot shows not assigned")

combat = true
fire("PLAYER_REGEN_DISABLED")
slots = slotsByKey()
ok(slots["CTRL-SHIFT-PAD1"].enabled == false and cf.quickBind.enabled == false and cf.status.text:find("in combat"), "editing locked in combat")
click(slots["CTRL-SHIFT-PAD1"])
ok(not pk.shown, "picker refuses in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
ok(slotsByKey()["CTRL-SHIFT-PAD1"].enabled == true, "unlocked after combat")

cf.toggle.scripts.OnClick()
ok(ForeverPadDB.enabled == false and next(overrides) == nil and cf.status.text:find("disabled"), "Disable button turns engine off")

-- pages
cf.pageTabs.settings.scripts.OnClick()
ok(cf.pages.settings.shown and not cf.pages.controller.shown and cf.pageTabs.settings.selected, "Settings tab")
cf:Hide() SlashCmdList.FOREVERPAD("")
ok(cf.pages.settings.shown, "window reopens on the last page")
cf.pageTabs.controller.scripts.OnClick()

ForeverPadDB.enabled = true
SlashCmdList.FOREVERPAD("mod alt L2")
cf:Hide() SlashCmdList.FOREVERPAD("")
local layerTabs = 0
for _, b in ipairs(cf.layerButtons) do if b.shown then layerTabs = layerTabs + 1 end end
ok(layerTabs == 8, "8 layer buttons with 3 modifiers, got " .. layerTabs)

-- missing click target and empty bar slot
ForeverPadDB.profiles.Default.bindings.PAD5 = { type = "click", button = "NoSuchButton" }
ForeverPadDB.profiles.Default.bindings.PADFORWARD = { type = "bar", bar = 1, button = 2 }
cf.layerButtons[1].scripts.OnClick(cf.layerButtons[1])
slots = slotsByKey()
ok(slots.PAD5.text.text:find("button not found"), "missing click target flagged")
ok(slots.PADFORWARD.text.text:find("empty slot") and slots.PADFORWARD.sub.text == "Main bar #2", "empty bar slot")

NO_TEMPLATE = true
local f2 = ns.CreatePanelFrame("TestFallbackFrame", 100, 100)
ok(f2 ~= nil, "fallback frame without template")

io.write("UI TESTS PASSED: " .. passed .. "\n")
