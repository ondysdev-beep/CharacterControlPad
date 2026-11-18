-- Context controls tests (Context.lua, ContextPanel.lua): a priority binding layer per open window.
local layers = {} -- owner -> { key -> { value, priority } }
local tempcvars, eventFrames = {}, {}
local cvars = { GamePadEmulateShift = "none", GamePadEmulateCtrl = "none", GamePadEmulateAlt = "none" }
local printed = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end
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
function Widget:GetScript(k) return self.scripts[k] end
function Widget:HookScript(k, fn) local old = self.scripts[k] self.scripts[k] = function(...) if old then old(...) end fn(...) end end
function Widget:Enable() self.enabled = true end
function Widget:Disable() self.enabled = false end
function Widget:IsEnabled() return self.enabled ~= false end
function Widget:SetChecked(v) self.checked = v and true or false end
function Widget:GetChecked() return self.checked == true end
function Widget:GetName() return rawget(self, "name") end
function Widget:SetAttribute(k, v) self.attributes[k] = v end
function Widget:GetAttribute(k) return self.attributes[k] end
function Widget:SetAllPoints(t) self.allPoints = t end
function Widget:SetPoint(p, rel) self.anchorTo = rel end
function Widget:GetStringWidth() return 200 end
function Widget:CreateFontString() return NewWidget() end
function Widget:CreateTexture() return NewWidget() end
function NewWidget() return setmetatable({ scripts = {}, attributes = {}, shown = true, enabled = true }, Widget) end
function CreateFrame(kind, name, parent, template)
  local f = NewWidget() if name then _G[name] = f f.name = name end
  f.template = template
  f.StartMoving = function() end f.StopMovingOrSizing = function() end
  f.children = {} if parent and rawget(parent, "children") then table.insert(parent.children, f) end
  eventFrames[#eventFrames+1] = f
  return f
end

-- Strict frame (no catch-all __index), like a real Blizzard frame: only the given methods exist.
local function Plain(fields)
  local f = { shown = true }
  f.IsShown = function(self) return self.shown end
  f.IsVisible = function(self) return self.shown end
  f.GetTop = function(self) return self.top or 0 end
  f.GetName = function(self) return self.name end
  f.GetParent = function(self) return self.parent end
  for k, v in pairs(fields or {}) do f[k] = v end
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
function ClearOverrideBindings(o) layers[o] = nil end
local function setLayer(o, prio, key, value) layers[o] = layers[o] or {} layers[o][key] = value and { value = value, priority = prio } or nil end
function SetOverrideBinding(o, prio, key, cmd) setLayer(o, prio, key, cmd) end
function SetOverrideBindingClick(o, prio, key, name, mouse) setLayer(o, prio, key, "CLICK " .. name .. ":" .. (mouse or "LeftButton")) end
-- effective binding: priority overrides first, then normal overrides
local function effective(key)
  local normal
  for _, l in pairs(layers) do local b = l[key] if b then if b.priority then return b.value end normal = b.value end end
  return normal
end
function GetBindingAction(key, checkOverride) return effective(key) or "" end
local mouseFocus
function GetMouseFoci() return { mouseFocus } end
local uiPanels = {}
function GetUIPanel(area) return uiPanels[area] end
local bagsOpen = false
function IsAnyBagOpen() return bagsOpen end
local looted = {}
function GetNumLootItems() return 3 end
function LootSlot(i) looted[#looted+1] = i end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers+1] = fn end }
local function runTimers() local t = timers timers = {} for _, fn in ipairs(t) do fn() end end
function HasAction(slot) return slot <= 24 end
function GetActionInfo(slot) return "spell", 900 + slot end
function GetActionTexture(slot) return 1 end
C_Spell = { GetSpellName = function(id) return "Spell" .. id end }
C_KeyBindings = { GetBindingIndex = function() return 1 end }
C_CVar = { GetCVar = function(n) return tempcvars[n] or cvars[n] end, SetTempCVar = function(n, v) tempcvars[n] = v end, RemoveTempCVar = function(n) tempcvars[n] = nil end }
C_AddOns = { IsAddOnLoaded = function() return false end }
Enum = { InputDeviceInterfaceType = { Mkb = 0, Gamepad = 1 } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return 0 end }
for i = 1, 12 do _G["ActionButton" .. i] = NewWidget() _G["ActionButton" .. i].action = i end
MainActionBar = NewWidget()

ForeverPadDB = { setupDone = true }
local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua",
  "ConfigWindow.lua", "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua",
  "Context.lua", "ContextPanel.lua" }) do
  assert(loadfile(ROOT .. f))("ForeverPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local Context = ns.Context
local refresh = Context.Refresh

fire("ADDON_LOADED", "ForeverPad") fire("PLAYER_LOGIN")
local ctxOwner = function() return ForeverPadContextOwner end
ok(effective("PAD2") == "ACTIONBUTTON2", "template: Circle = main bar 2")

---------------- nothing open ----------------
refresh()
ok(effective("PAD2") == "ACTIONBUTTON2" and next(Context.wanted) == nil, "no window -> no context layer")
ok(ns.db.context.enabled == true and ns.db.context.hints == true, "defaults: enabled, hints on")

---------------- close windows ----------------
bagsOpen = true refresh()
ok(effective("PAD2") == "TOGGLEGAMEMENU" and layers[ctxOwner()].PAD2.priority == true, "bags open -> Circle closes (priority override)")
ok(effective("PAD1") == "ACTIONBUTTON1", "other buttons unchanged")
ok(ForeverPadContextHints == nil or not ForeverPadContextHints.shown, "no hint line for close only")
bagsOpen = false refresh()
ok(effective("PAD2") == "ACTIONBUTTON2", "bags closed -> Circle back to the player's binding")
UISpecialFrames[1] = "SomeSpecialFrame" SomeSpecialFrame = Plain({ shown = true }) refresh()
ok(effective("PAD2") == "TOGGLEGAMEMENU", "Esc-closable special frame counts as a window")
SomeSpecialFrame.shown = false refresh()
ok(effective("PAD2") == "ACTIONBUTTON2", "special frame hidden -> layer gone")
local shift = effective("SHIFT-PAD2")
ok(shift == "ACTIONBUTTON6", "modifier combos never touched")

---------------- merchant ----------------
MerchantFrame = Plain({ name = "MerchantFrame" })
MerchantRepairAllButton = Plain({ name = "MerchantRepairAllButton", IsEnabled = function() return true end })
MerchantSellAllJunkButton = Plain({ name = "MerchantSellAllJunkButton", IsEnabled = function() return false end })
uiPanels.left = MerchantFrame
local merchItem = Plain({ name = "MerchantItem3ItemButton" })
local bag = Plain({ GetBagID = function() return 0 end })
local bagItem = Plain({ GetBagID = function() return 0 end, parent = bag })
mouseFocus = nil refresh()
ok(effective("PAD1") == "ACTIONBUTTON1" and effective("PAD3") == "ACTIONBUTTON3", "merchant, nothing hovered -> Cross/Square keep player's actions")
ok(effective("PAD4") == "CLICK ForeverPadContextPAD4:LeftButton" and ForeverPadContextPAD4.attributes.clickbutton == MerchantRepairAllButton, "Triangle repairs all via secure proxy")
ok(ForeverPadContextPAD4.attributes.type == "click" and ForeverPadContextPAD4.template == "SecureActionButtonTemplate", "proxy is a SecureActionButton of type click")
ok(effective("PADFORWARD") ~= "CLICK ForeverPadContextPADFORWARD:LeftButton", "sell junk disabled -> Options not taken")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "Circle closes the merchant")
local hints = ForeverPadContextHints
ok(hints and hints.shown and hints.anchorTo == MerchantFrame, "hint line under the merchant")
ok(hints.text.text:find("Buy", 1, true) and hints.text.text:find("Sell", 1, true) and hints.text.text:find("Repair all", 1, true) and hints.text.text:find("Close", 1, true), "hint lists buy, sell, repair, close: " .. hints.text.text)
mouseFocus = merchItem refresh()
ok(effective("PAD1") == "CLICK ForeverPadContextPAD1:RightButton" and ForeverPadContextPAD1.attributes.clickbutton == merchItem, "hover merchant item -> Cross = right click (buy)")
ok(effective("PAD3") == "ACTIONBUTTON3", "Square untouched while hovering a merchant item")
mouseFocus = bagItem refresh()
ok(effective("PAD3") == "CLICK ForeverPadContextPAD3:RightButton" and ForeverPadContextPAD3.attributes.clickbutton == bagItem, "hover bag item -> Square = right click (sell)")
ok(effective("PAD1") == "ACTIONBUTTON1", "Cross back to normal when not hovering a merchant item")
mouseFocus = bag refresh()
ok(effective("PAD3") == "ACTIONBUTTON3", "container frame itself is not an item")
MerchantSellAllJunkButton.IsEnabled = function() return true end refresh()
ok(ForeverPadContextPADFORWARD.attributes.clickbutton == MerchantSellAllJunkButton, "Options sells junk when the button is usable")

-- engine conflict check ignores our own layer
ns.Engine.Apply("test")
ok(next(ns.db.lastApply.conflicts) == nil, "context layer is not reported as a conflict")

---------------- popup over merchant ----------------
local yes, no = Plain({ IsEnabled = function() return true end }), Plain({ IsEnabled = function() return true end })
StaticPopup1 = Plain({ name = "StaticPopup1", ButtonContainer = { Button1 = yes, Button2 = no } })
mouseFocus = merchItem refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == yes and effective("PAD1") == "CLICK ForeverPadContextPAD1:LeftButton", "popup: Cross accepts (beats buy)")
ok(ForeverPadContextPAD2.attributes.clickbutton == no and effective("PAD2") == "CLICK ForeverPadContextPAD2:LeftButton", "popup: Circle declines")
ok(hints.anchorTo == StaticPopup1 and not hints.text.text:find("Sell", 1, true), "hint describes only the popup")
no.shown = false refresh()
ok(effective("PAD2") == "TOGGLEGAMEMENU", "popup without a second button -> Circle = Esc")
StaticPopup1.shown = false
ReadyCheckFrame = Plain({}) ReadyCheckFrameYesButton = Plain({}) ReadyCheckFrameNoButton = Plain({})
refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == ReadyCheckFrameYesButton and ForeverPadContextPAD2.attributes.clickbutton == ReadyCheckFrameNoButton, "ready check: yes / no")
ReadyCheckFrame.shown = false

---------------- groups off ----------------
SlashCmdList.FOREVERPAD("context merchant off")
mouseFocus = merchItem refresh()
ok(effective("PAD4") == "ACTIONBUTTON4" and effective("PAD1") == "ACTIONBUTTON1", "merchant group off")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "close group still on")
SlashCmdList.FOREVERPAD("context merchant on")
SlashCmdList.FOREVERPAD("context off") refresh()
ok(effective("PAD2") == "ACTIONBUTTON2" and effective("PAD4") == "ACTIONBUTTON4", "context controls off -> nothing")
SlashCmdList.FOREVERPAD("context on") refresh()
ok(effective("PAD4") == "CLICK ForeverPadContextPAD4:LeftButton", "back on")

---------------- combat ----------------
combat = true
fire("PLAYER_REGEN_DISABLED")
ok(effective("PAD2") == "ACTIONBUTTON2" and effective("PAD4") == "ACTIONBUTTON4" and layers[ctxOwner()] == nil, "combat start drops the layer")
ok(not hints.shown, "hints hidden in combat")
refresh()
ok(layers[ctxOwner()] == nil, "no rebinding during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
ok(effective("PAD4") == "CLICK ForeverPadContextPAD4:LeftButton", "layer back after combat")

---------------- engine disabled / quick bind ----------------
SlashCmdList.FOREVERPAD("off") refresh()
ok(layers[ctxOwner()] == nil, "ForeverPad disabled -> no context layer")
SlashCmdList.FOREVERPAD("on") refresh()
ok(effective("PAD4") ~= "ACTIONBUTTON4", "enabled again")
local qbActive = ns.QuickBind.IsActive
ns.QuickBind.IsActive = function() return true end refresh()
ok(layers[ctxOwner()] == nil, "quick bind mode -> no context layer")
ns.QuickBind.IsActive = qbActive
MerchantFrame.shown = false uiPanels.left = nil mouseFocus = nil refresh()
ok(layers[ctxOwner()] == nil and not hints.shown, "merchant closed -> layer and hints gone")

---------------- gossip (D-pad list) ----------------
local opts = {}
for i, t in ipairs({ 1, 5, 3, 3 }) do -- title, available quest, two options
  opts[i] = Plain({ top = 500 - i * 20, GetElementData = function() return { buttonType = t } end })
end
GossipFrame = Plain({ GreetingPanel = { ScrollBox = { GetFrames = function() return { opts[3], opts[1], opts[2], opts[4] } end } } })
uiPanels.left = GossipFrame
refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == opts[2], "gossip: first selectable entry (title skipped, sorted top-down)")
ok(ForeverPadContextHighlight.shown and ForeverPadContextHighlight.allPoints == opts[2], "selection highlighted")
ok(effective("PADDDOWN") == "CLICK ForeverPadContextFnPADDDOWN:LeftButton", "D-pad Down bound to navigation")
ForeverPadContextFnPADDDOWN.scripts.OnClick(ForeverPadContextFnPADDDOWN)
ok(ForeverPadContextPAD1.attributes.clickbutton == opts[3] and ForeverPadContextHighlight.allPoints == opts[3], "Down -> next option")
ForeverPadContextFnPADDUP.scripts.OnClick(ForeverPadContextFnPADDUP)
ForeverPadContextFnPADDUP.scripts.OnClick(ForeverPadContextFnPADDUP)
ok(ForeverPadContextPAD1.attributes.clickbutton == opts[4], "Up wraps around")
ok(ForeverPadContextHints.text.text:find("D-pad", 1, true) and ForeverPadContextHints.text.text:find("Confirm", 1, true), "gossip hint")
refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == opts[4], "selection kept across refreshes")
GossipFrame.shown = false uiPanels.left = nil refresh()
ok(not ForeverPadContextHighlight.shown and layers[ctxOwner()] == nil, "gossip closed -> highlight and layer gone")

---------------- quest reward ----------------
local c1, c2 = Plain({ type = "choice", top = 300 }), Plain({ type = "choice", top = 260 })
QuestFrame = Plain({}) QuestFrameRewardPanel = Plain({})
QuestInfoRewardsFrame = Plain({ RewardButtons = { c2, c1, Plain({ type = "reward", top = 200 }) } })
QuestFrameCompleteQuestButton = Plain({ IsEnabled = function() return true end })
uiPanels.left = QuestFrame
refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == c1, "reward: first choice selected")
local idx, n = Context.NavIndex()
ok(n == 3, "two choices + Complete (plain rewards are not choices)")
ForeverPadContextPAD1.scripts.PostClick(ForeverPadContextPAD1) -- the secure click picked the choice
runTimers()
ok(ForeverPadContextPAD1.attributes.clickbutton == QuestFrameCompleteQuestButton, "after picking a reward, Cross completes the quest")
QuestFrameRewardPanel.shown = false
QuestFrameDetailPanel = Plain({}) QuestFrameAcceptButton = Plain({})
refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == QuestFrameAcceptButton and effective("PADDDOWN") == "OPENALLBAGS", "quest detail: Cross accepts, no D-pad list for one button")
QuestFrame.shown = false uiPanels.left = nil refresh()

---------------- loot / mail / trainer / bank ----------------
LootFrame = Plain({}) refresh()
ok(effective("PAD1") == "CLICK ForeverPadContextFnPAD1:LeftButton", "loot: Cross = loot all")
ForeverPadContextFnPAD1.scripts.OnClick(ForeverPadContextFnPAD1)
ok(#looted == 3 and looted[1] == 3, "loots every slot")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "loot window closable with Circle")
LootFrame.shown = false
MailFrame = Plain({}) InboxFrame = Plain({}) OpenAllMail = Plain({}) refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == OpenAllMail and effective("PAD1") == "CLICK ForeverPadContextPAD1:LeftButton", "mail: Cross opens all")
MailFrame.shown = false InboxFrame.shown = false
ClassTrainerFrame = Plain({}) ClassTrainerTrainButton = Plain({ IsEnabled = function() return false end }) refresh()
ok(effective("PAD1") == "ACTIONBUTTON1", "trainer: nothing selected -> Cross normal")
ClassTrainerTrainButton.IsEnabled = function() return true end refresh()
ok(ForeverPadContextPAD1.attributes.clickbutton == ClassTrainerTrainButton, "trainer: Cross learns")
ClassTrainerFrame.shown = false
BankFrame = Plain({}) local bankItem = Plain({ GetBankTabID = function() return 1 end, GetContainerSlotID = function() return 1 end })
mouseFocus = bankItem refresh()
ok(ForeverPadContextPAD3.attributes.clickbutton == bankItem and effective("PAD3") == "CLICK ForeverPadContextPAD3:RightButton", "bank: Square moves bank item")
mouseFocus = bagItem refresh()
ok(ForeverPadContextPAD3.attributes.clickbutton == bagItem, "bank: Square moves bag item")
BankFrame.shown = false mouseFocus = nil refresh()
ok(layers[ctxOwner()] == nil, "all closed -> no layer")

---------------- panel ----------------
SlashCmdList.FOREVERPAD("")
local cf = ForeverPadConfigFrame
ok(cf.contextButton and cf.contextButton.text == "Windows", "config footer has the Windows button")
cf.contextButton.scripts.OnClick()
local cp = ForeverPadContextPanel
ok(cp.shown and cp.title.text == "Context controls", "context panel opens")
local function check(label) for _, c in ipairs(cp.children) do if rawget(c, "label") and c.label.text == label then return c end end end
local lootCheck = check("Loot")
ok(lootCheck and lootCheck.checked == true, "group checkbox reflects setting")
lootCheck.checked = false lootCheck.scripts.OnClick(lootCheck)
ok(ns.db.context.off.loot == true, "unchecking turns the group off")
LootFrame.shown = true refresh()
ok(effective("PAD1") == "ACTIONBUTTON1", "loot group off -> Cross normal")
lootCheck.checked = true lootCheck.scripts.OnClick(lootCheck)
ok(ns.db.context.off.loot == nil and effective("PAD1") == "CLICK ForeverPadContextFnPAD1:LeftButton", "checking turns it back on immediately")
local master = check("Enable context controls")
master.checked = false master.scripts.OnClick(master)
ok(ns.db.context.enabled == false and layers[ctxOwner()] == nil and lootCheck.enabled == false, "master switch off disables groups")
master.checked = true master.scripts.OnClick(master)
local hintCheck = check("Show button hints under the window")
hintCheck.checked = false hintCheck.scripts.OnClick(hintCheck)
ok(ns.db.context.hints == false and not ForeverPadContextHints.shown, "hints can be hidden")
LootFrame.shown = false refresh()

---------------- locale ----------------
local missing = {}
for k in pairs(ns.LOCALES.enUS) do if (k:find("^CTX_") or k == "CLOSE") and ns.LOCALES.csCZ[k] == nil then missing[#missing+1] = k end end
table.sort(missing)
ok(#missing == 0, "every context string has a Czech translation, missing: " .. table.concat(missing, ", "))
for _, g in ipairs(Context.GROUPS) do
  ok(ns.LOCALES.enUS["CTX_GROUP_" .. g:upper()] and ns.LOCALES.enUS["CTX_DESC_" .. g:upper()], "labels for group " .. g)
end

io.write("CONTEXT TESTS PASSED: " .. passed .. "\n")
