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

CharacterControlPadDB = { setupDone = true }
local ns = {}
for _, f in ipairs({ "Core.lua", "Locale.lua", "Data.lua", "Profiles.lua", "BindingEngine.lua", "Compat.lua", "Commands.lua",
  "ConfigWindow.lua", "ActionPicker.lua", "QuickBind.lua", "ModifierPanel.lua", "ProfilesPanel.lua", "Wizard.lua",
  "Context.lua", "ContextPanel.lua" }) do
  assert(loadfile(ROOT .. f))("CharacterControlPad", ns)
end
local core = eventFrames[1]
local function fire(e, ...) core.scripts.OnEvent(core, e, ...) end
local passed = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end passed = passed + 1 end
local Context = ns.Context
local refresh = Context.Refresh

fire("ADDON_LOADED", "CharacterControlPad") fire("PLAYER_LOGIN")
local ctxOwner = function() return CharacterControlPadContextOwner end
ok(effective("PAD2") == "ACTIONBUTTON2", "template: Circle = main bar 2")

---------------- nothing open ----------------
refresh()
ok(effective("PAD2") == "ACTIONBUTTON2" and next(Context.wanted) == nil, "no window -> no context layer")
ok(ns.db.context.enabled == true and ns.db.context.hints == true, "defaults: enabled, hints on")

---------------- close windows ----------------
bagsOpen = true refresh()
ok(effective("PAD2") == "TOGGLEGAMEMENU" and layers[ctxOwner()].PAD2.priority == true, "bags open -> Circle closes (priority override)")
ok(effective("PAD1") == "ACTIONBUTTON1", "other buttons unchanged")
ok(CharacterControlPadContextHints == nil or not CharacterControlPadContextHints.shown, "no hint line for close only")
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
ok(effective("PAD1") == "CLICK CharacterControlPadContextFnPAD1:LeftButton" and effective("PAD3") == "ACTIONBUTTON3", "merchant without goods (empty buyback tab): Cross does nothing, so it cannot sell from the bags")
ok(effective("PAD4") == "CLICK CharacterControlPadContextPAD4:LeftButton" and CharacterControlPadContextPAD4.attributes.clickbutton == MerchantRepairAllButton, "Triangle repairs all via secure proxy")
ok(CharacterControlPadContextPAD4.attributes.type == "click" and CharacterControlPadContextPAD4.template == "SecureActionButtonTemplate", "proxy is a SecureActionButton of type click")
ok(effective("PADFORWARD") ~= "CLICK CharacterControlPadContextPADFORWARD:LeftButton", "sell junk disabled -> Options not taken")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "Circle closes the merchant")
local hints = CharacterControlPadContextHints
ok(hints and hints.shown and hints.anchorTo == MerchantFrame, "hint line under the merchant")
ok(hints.text.text:find("Sell from bags", 1, true) and hints.text.text:find("Repair all", 1, true) and hints.text.text:find("Close", 1, true), "hint lists sell switch, repair, close: " .. hints.text.text)
_G.MerchantItem3ItemButton = merchItem
mouseFocus = merchItem refresh()
ok(effective("PAD1") == "CLICK CharacterControlPadContextPAD1:RightButton" and CharacterControlPadContextPAD1.attributes.clickbutton == merchItem, "hover merchant item -> Cross = right click (buy)")
ok(effective("PAD3") == "ACTIONBUTTON3", "Square untouched while hovering a merchant item")
mouseFocus = bagItem refresh()
ok(effective("PAD3") == "CLICK CharacterControlPadContextPAD3:RightButton" and CharacterControlPadContextPAD3.attributes.clickbutton == bagItem, "hover bag item -> Square = right click (sell)")
ok(effective("PAD1") == "CLICK CharacterControlPadContextPAD1:RightButton" and CharacterControlPadContextPAD1.attributes.clickbutton == merchItem, "buy mode: Cross keeps buying the selected goods while the mouse is on a bag item")
mouseFocus = bag refresh()
ok(effective("PAD3") == "ACTIONBUTTON3", "container frame itself is not an item")
MerchantSellAllJunkButton.IsEnabled = function() return true end refresh()
ok(CharacterControlPadContextPADFORWARD.attributes.clickbutton == MerchantSellAllJunkButton, "Options sells junk when the button is usable")
_G.MerchantItem3ItemButton = nil

-- engine conflict check ignores our own layer
ns.Engine.Apply("test")
ok(next(ns.db.lastApply.conflicts) == nil, "context layer is not reported as a conflict")

---------------- popup over merchant ----------------
local yes, no = Plain({ IsEnabled = function() return true end }), Plain({ IsEnabled = function() return true end })
StaticPopup1 = Plain({ name = "StaticPopup1", ButtonContainer = { Button1 = yes, Button2 = no } })
mouseFocus = merchItem refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == yes and effective("PAD1") == "CLICK CharacterControlPadContextPAD1:LeftButton", "popup: Cross accepts (beats buy)")
ok(CharacterControlPadContextPAD2.attributes.clickbutton == no and effective("PAD2") == "CLICK CharacterControlPadContextPAD2:LeftButton", "popup: Circle declines")
ok(hints.anchorTo == StaticPopup1 and not hints.text.text:find("Sell", 1, true), "hint describes only the popup")
no.shown = false refresh()
ok(effective("PAD2") == "TOGGLEGAMEMENU", "popup without a second button -> Circle = Esc")
StaticPopup1.shown = false
ReadyCheckFrame = Plain({}) ReadyCheckFrameYesButton = Plain({}) ReadyCheckFrameNoButton = Plain({})
refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == ReadyCheckFrameYesButton and CharacterControlPadContextPAD2.attributes.clickbutton == ReadyCheckFrameNoButton, "ready check: yes / no")
ReadyCheckFrame.shown = false

---------------- groups off ----------------
SlashCmdList.CHARACTERCONTROLPAD("context merchant off")
mouseFocus = merchItem refresh()
ok(effective("PAD4") == "ACTIONBUTTON4" and effective("PAD1") == "ACTIONBUTTON1", "merchant group off")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "close group still on")
SlashCmdList.CHARACTERCONTROLPAD("context merchant on")
SlashCmdList.CHARACTERCONTROLPAD("context off") refresh()
ok(effective("PAD2") == "ACTIONBUTTON2" and effective("PAD4") == "ACTIONBUTTON4", "context controls off -> nothing")
SlashCmdList.CHARACTERCONTROLPAD("context on") refresh()
ok(effective("PAD4") == "CLICK CharacterControlPadContextPAD4:LeftButton", "back on")

---------------- combat ----------------
combat = true
fire("PLAYER_REGEN_DISABLED")
ok(effective("PAD2") == "ACTIONBUTTON2" and effective("PAD4") == "ACTIONBUTTON4" and layers[ctxOwner()] == nil, "combat start drops the layer")
ok(not hints.shown, "hints hidden in combat")
refresh()
ok(layers[ctxOwner()] == nil, "no rebinding during combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
ok(effective("PAD4") == "CLICK CharacterControlPadContextPAD4:LeftButton", "layer back after combat")

---------------- engine disabled / quick bind ----------------
SlashCmdList.CHARACTERCONTROLPAD("off") refresh()
ok(layers[ctxOwner()] == nil, "CharacterControlPad disabled -> no context layer")
SlashCmdList.CHARACTERCONTROLPAD("on") refresh()
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
ok(CharacterControlPadContextPAD1.attributes.clickbutton == opts[2], "gossip: first selectable entry (title skipped, sorted top-down)")
ok(CharacterControlPadContextHighlight.shown and CharacterControlPadContextHighlight.allPoints == opts[2], "selection highlighted")
ok(effective("PADDDOWN") == "CLICK CharacterControlPadContextFnPADDDOWN:LeftButton", "D-pad Down bound to navigation")
CharacterControlPadContextFnPADDDOWN.scripts.OnClick(CharacterControlPadContextFnPADDDOWN)
ok(CharacterControlPadContextPAD1.attributes.clickbutton == opts[3] and CharacterControlPadContextHighlight.allPoints == opts[3], "Down -> next option")
CharacterControlPadContextFnPADDUP.scripts.OnClick(CharacterControlPadContextFnPADDUP)
CharacterControlPadContextFnPADDUP.scripts.OnClick(CharacterControlPadContextFnPADDUP)
ok(CharacterControlPadContextPAD1.attributes.clickbutton == opts[4], "Up wraps around")
ok(CharacterControlPadContextHints.text.text:find("D-pad", 1, true) and CharacterControlPadContextHints.text.text:find("Confirm", 1, true), "gossip hint")
refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == opts[4], "selection kept across refreshes")
GossipFrame.shown = false uiPanels.left = nil refresh()
ok(not CharacterControlPadContextHighlight.shown and layers[ctxOwner()] == nil, "gossip closed -> highlight and layer gone")

---------------- quest reward ----------------
local c1, c2 = Plain({ type = "choice", top = 300 }), Plain({ type = "choice", top = 260 })
QuestFrame = Plain({}) QuestFrameRewardPanel = Plain({})
QuestInfoRewardsFrame = Plain({ RewardButtons = { c2, c1, Plain({ type = "reward", top = 200 }) } })
QuestFrameCompleteQuestButton = Plain({ IsEnabled = function() return true end })
uiPanels.left = QuestFrame
refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == c1, "reward: first choice selected")
local idx, n = Context.NavIndex()
ok(n == 3, "two choices + Complete (plain rewards are not choices)")
CharacterControlPadContextPAD1.scripts.PostClick(CharacterControlPadContextPAD1) -- the secure click picked the choice
runTimers()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == QuestFrameCompleteQuestButton, "after picking a reward, Cross completes the quest")
QuestFrameRewardPanel.shown = false
QuestFrameDetailPanel = Plain({}) QuestFrameAcceptButton = Plain({})
refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == QuestFrameAcceptButton and effective("PADDDOWN") == "OPENALLBAGS", "quest detail: Cross accepts, no D-pad list for one button")
QuestFrame.shown = false uiPanels.left = nil refresh()

---------------- loot / mail / trainer / bank ----------------
LootFrame = Plain({}) refresh()
ok(effective("PAD1") == "CLICK CharacterControlPadContextFnPAD1:LeftButton", "loot: Cross = loot all")
CharacterControlPadContextFnPAD1.scripts.OnClick(CharacterControlPadContextFnPAD1)
ok(#looted == 3 and looted[1] == 3, "loots every slot")
ok(effective("PAD2") == "TOGGLEGAMEMENU", "loot window closable with Circle")
LootFrame.shown = false refresh()

-- loot list: D-pad chooses, Cross takes the selected item, Square takes everything
local function lootEntry(slot, top) return Plain({ top = top, Item = Plain({}), GetSlotIndex = function() return slot end }) end
local e1, e2, e3 = lootEntry(1, 300), lootEntry(2, 250), lootEntry(3, 200)
local emptyEntry = Plain({ top = 350, GetSlotIndex = function() return 9 end }) -- base element without an item button
LootFrame = Plain({ ScrollBox = { GetFrames = function() return { e3, emptyEntry, e1, e2 } end } })
looted = {}
refresh()
ok(effective("PAD1") == "CLICK CharacterControlPadContextFnPAD1:LeftButton" and effective("PAD3") == "CLICK CharacterControlPadContextFnPAD3:LeftButton", "loot list: Cross and Square bound")
ok(effective("PADDDOWN") == "CLICK CharacterControlPadContextFnPADDDOWN:LeftButton" and effective("PAD2") == "TOGGLEGAMEMENU", "loot list: D-pad chooses, Circle closes")
ok(CharacterControlPadContextHighlight.shown and CharacterControlPadContextHighlight.allPoints == e1, "first item selected (entries without an item skipped, sorted top-down)")
CharacterControlPadContextFnPADDDOWN.scripts.OnClick(CharacterControlPadContextFnPADDDOWN)
ok(CharacterControlPadContextHighlight.allPoints == e2, "Down selects the next item")
CharacterControlPadContextFnPAD1.scripts.OnClick(CharacterControlPadContextFnPAD1)
ok(#looted == 1 and looted[1] == 2, "Cross takes only the selected item")
e2.shown = false runTimers()
ok(CharacterControlPadContextHighlight.allPoints == e3, "after taking it, the selection stays in place (next item)")
local lootHint = CharacterControlPadContextHints.text.text
ok(lootHint:find("Take", 1, true) and lootHint:find("Loot all", 1, true) and lootHint:find("D-pad", 1, true) and lootHint:find("Close", 1, true), "loot hint: " .. lootHint)
CharacterControlPadContextFnPAD3.scripts.OnClick(CharacterControlPadContextFnPAD3)
ok(#looted == 4, "Square takes everything")
e1.shown = false e3.shown = false refresh()
ok(not CharacterControlPadContextHighlight.shown and effective("PAD3") == "ACTIONBUTTON3", "nothing left -> no selection, Square back to normal")
LootFrame.shown = false refresh()
e1.shown, e2.shown, e3.shown = true, true, true
LootFrame.shown = true CharacterControlPadContextFnPADDDOWN.scripts.OnClick(CharacterControlPadContextFnPADDDOWN) refresh()
LootFrame.shown = false refresh() LootFrame.shown = true refresh()
ok(CharacterControlPadContextHighlight.allPoints == e1, "reopened loot window starts at the first item")
LootFrame.shown = false refresh()
MailFrame = Plain({}) InboxFrame = Plain({}) OpenAllMail = Plain({}) refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == OpenAllMail and effective("PAD1") == "CLICK CharacterControlPadContextPAD1:LeftButton", "mail: Cross opens all")
MailFrame.shown = false InboxFrame.shown = false
ClassTrainerFrame = Plain({}) ClassTrainerTrainButton = Plain({ IsEnabled = function() return false end }) refresh()
ok(effective("PAD1") == "ACTIONBUTTON1", "trainer: nothing selected -> Cross normal")
ClassTrainerTrainButton.IsEnabled = function() return true end refresh()
ok(CharacterControlPadContextPAD1.attributes.clickbutton == ClassTrainerTrainButton, "trainer: Cross learns")
ClassTrainerFrame.shown = false
BankFrame = Plain({}) local bankItem = Plain({ GetBankTabID = function() return 1 end, GetContainerSlotID = function() return 1 end })
mouseFocus = bankItem refresh()
ok(CharacterControlPadContextPAD3.attributes.clickbutton == bankItem and effective("PAD3") == "CLICK CharacterControlPadContextPAD3:RightButton", "bank: Square moves bank item")
mouseFocus = bagItem refresh()
ok(CharacterControlPadContextPAD3.attributes.clickbutton == bagItem, "bank: Square moves bag item")
BankFrame.shown = false mouseFocus = nil refresh()
ok(layers[ctxOwner()] == nil, "all closed -> no layer")

---------------- bags (D-pad selection, confirm button) ----------------
local bagFrame = Plain({ GetBagID = function() return 0 end, GetBagSize = function() return 5 end })
local function bagBtn(x, y) return Plain({ parent = bagFrame, GetBagID = function() return 0 end, GetID = function() return 1 end, GetCenter = function() return x, y end }) end
local items = { bagBtn(100, 300), bagBtn(140, 300), bagBtn(100, 260), bagBtn(140, 260), bagBtn(180, 260) }
bagFrame.Items = items
ContainerFrameCombinedBags = bagFrame
local function sel() return CharacterControlPadContextPAD1.attributes.clickbutton end
local function press(dir) local b = _G["CharacterControlPadContextFnPADD" .. dir] b.scripts.OnClick(b) end
bagsOpen = true mouseFocus = nil refresh()
ok(effective("PAD1") == "CLICK CharacterControlPadContextPAD1:RightButton" and sel() == items[1], "bags: Cross uses the top-left item (right click)")
ok(CharacterControlPadContextHighlight.shown and CharacterControlPadContextHighlight.allPoints == items[1], "bag selection highlighted")
ok(effective("PADDRIGHT") == "CLICK CharacterControlPadContextFnPADDRIGHT:LeftButton" and effective("PADDLEFT") == "CLICK CharacterControlPadContextFnPADDLEFT:LeftButton", "D-pad left/right move in the bags")
press("RIGHT") ok(sel() == items[2], "Right -> next item in the row")
press("DOWN") ok(sel() == items[4], "Down -> item below")
press("LEFT") ok(sel() == items[3], "Left")
press("UP") ok(sel() == items[1], "Up")
press("UP") ok(sel() == items[1], "no item above -> selection stays")
ok(ForeverPadTooltip == nil and CharacterControlPadTooltip ~= nil, "tooltip of the selected item uses the private tooltip")
ok(CharacterControlPadContextHints.text.text:find("Use", 1, true) and CharacterControlPadContextHints.text.text:find("D-pad", 1, true), "bag hint: " .. CharacterControlPadContextHints.text.text)
mouseFocus = items[5] refresh()
ok(sel() == items[5], "item hovered with the mouse / touchpad becomes the selection")
press("LEFT")
ok(sel() == items[4], "D-pad still moves while the mouse rests on an item")
mouseFocus = nil
SlashCmdList.CHARACTERCONTROLPAD("context confirm square") refresh()
ok(ns.db.context.confirm == "PAD3" and effective("PAD3") == "CLICK CharacterControlPadContextPAD3:RightButton" and effective("PAD1") == "ACTIONBUTTON1", "confirm button = Square")
SlashCmdList.CHARACTERCONTROLPAD("context confirm options") refresh()
ok(ns.db.context.confirm == "PAD3", "only Cross / Square / Triangle can confirm")
SlashCmdList.CHARACTERCONTROLPAD("context confirm cross")
-- merchant: buy mode (D-pad over the goods) <-> sell mode (D-pad over the bags), Touchpad toggles
local goods = {}
for i = 1, 4 do -- two columns, two rows on page 1
  local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
  goods[i] = Plain({ name = "MerchantItem" .. i .. "ItemButton", GetID = function() return i end, GetCenter = function() return 50 + col * 150, 400 - row * 50 end })
  _G["MerchantItem" .. i .. "ItemButton"] = goods[i]
end
local nextPage = Plain({ IsEnabled = function() return true end })
local prevPage = Plain({ IsEnabled = function() return false end })
MerchantNextPageButton, MerchantPrevPageButton = nextPage, prevPage
MerchantFrame.shown = true refresh()
ok(ns.Context.MerchantMode() == "buy" and sel() == goods[1] and effective("PAD1") == "CLICK CharacterControlPadContextPAD1:RightButton", "merchant opens in buy mode: Cross buys the first goods (right click)")
ok(CharacterControlPadContextHighlight.allPoints == goods[1], "goods selection highlighted")
ok(effective("PADBACK") == "CLICK CharacterControlPadContextFnPADBACK:LeftButton", "Touchpad = buy / sell switch")
local mh = CharacterControlPadContextHints.text.text
ok(mh:find("Buy", 1, true) and mh:find("Touchpad", 1, true) and mh:find("Sell from bags", 1, true) and mh:find("D-pad", 1, true), "merchant hint in buy mode: " .. mh)
press("RIGHT") ok(sel() == goods[2], "Right -> next goods")
press("DOWN") ok(sel() == goods[4], "Down -> goods below")
ok(effective("PADDDOWN") == "CLICK CharacterControlPadContextPADDDOWN:LeftButton" and CharacterControlPadContextPADDDOWN.attributes.clickbutton == nextPage, "bottom row: Down turns the page (secure click on the next page button)")
ok(effective("PADDUP") == "CLICK CharacterControlPadContextFnPADDUP:LeftButton", "Up still moves inside the page")
CharacterControlPadContextPADDDOWN.scripts.PostClick(CharacterControlPadContextPADDDOWN) runTimers()
ok(sel() == goods[1], "after turning the page the selection starts at the top")
press("DOWN") press("DOWN")
ok(sel() == goods[3] and CharacterControlPadContextPADDDOWN.attributes.clickbutton == nextPage, "Down at the bottom row again offers the next page")
local tipBefore = CharacterControlPadTooltip
ok(tipBefore ~= nil, "goods tooltip uses the private tooltip")
-- switch to selling: the D-pad goes to the bags, confirm sells
CharacterControlPadContextFnPADBACK.scripts.OnClick(CharacterControlPadContextFnPADBACK)
ok(ns.Context.MerchantMode() == "sell" and sel() == items[4], "Touchpad -> sell mode: Cross sells the selected bag item")
mh = CharacterControlPadContextHints.text.text
ok(mh:find("Sell", 1, true) and mh:find("Buy", 1, true), "merchant hint in sell mode: " .. mh)
press("LEFT") ok(sel() == items[3], "D-pad moves in the bags while selling")
bagsOpen = false bagFrame.shown = false refresh()
ok(effective("PAD1") == "OPENALLBAGS", "sell mode without open bags: Cross opens the bags")
bagsOpen = true bagFrame.shown = true
CharacterControlPadContextFnPADBACK.scripts.OnClick(CharacterControlPadContextFnPADBACK)
ok(ns.Context.MerchantMode() == "buy" and sel() == goods[3], "Touchpad again -> back to buying, selection kept")
mouseFocus = goods[2] refresh()
ok(sel() == goods[2], "goods under the mouse / touchpad become the selection")
CharacterControlPadContextFnPADBACK.scripts.OnClick(CharacterControlPadContextFnPADBACK)
local inBags = false for _, it in ipairs(items) do if sel() == it then inBags = true end end
ok(inBags and CharacterControlPadContextHighlight.allPoints == sel(), "sell mode: Cross sells the framed bag item even while the mouse rests on goods")
mouseFocus = nil
CharacterControlPadContextFnPADBACK.scripts.OnClick(CharacterControlPadContextFnPADBACK)
press("DOWN") press("UP")
ok(sel() == goods[1] or sel() == goods[2], "D-pad moves away from the hovered goods")
local framed = sel()
mouseFocus = goods[2] refresh() mouseFocus = goods[2] press("DOWN")
ok(sel() == goods[4], "mouse resting on goods: the D-pad selection wins after moving (Cross buys the framed goods)")
mouseFocus = nil
-- Triangle as the confirm button: repair moves to Cross
SlashCmdList.CHARACTERCONTROLPAD("context confirm triangle") refresh()
ok(effective("PAD4") == "CLICK CharacterControlPadContextPAD4:RightButton" and CharacterControlPadContextPAD4.attributes.clickbutton == goods[4], "Triangle confirms: buys the framed goods")
ok(effective("PAD1") == "CLICK CharacterControlPadContextPAD1:LeftButton" and CharacterControlPadContextPAD1.attributes.clickbutton == MerchantRepairAllButton, "Triangle confirms: Cross repairs")
SlashCmdList.CHARACTERCONTROLPAD("context confirm cross") refresh()
-- Touchpad used as a modifier: no buy / sell switch
ns.Profiles.Active().modifiers.ALT = "PADBACK" refresh()
ok(effective("PADBACK") ~= "CLICK CharacterControlPadContextFnPADBACK:LeftButton" and not CharacterControlPadContextHints.text.text:find("Touchpad", 1, true), "Touchpad as a modifier: no switch, no hint")
ns.Profiles.Active().modifiers.ALT = "none" refresh()
-- release edge of a page turn does not move the selection again
CharacterControlPadContextPADDDOWN.scripts.PostClick(CharacterControlPadContextPADDDOWN, "LeftButton", false) runTimers()
ok(sel() == goods[4], "release edge of the page button does not reset the selection")
-- merchant closed while the layer is not refreshed (combat): MERCHANT_CLOSED resets the mode
CharacterControlPadContextFnPADBACK.scripts.OnClick(CharacterControlPadContextFnPADBACK)
ok(ns.Context.MerchantMode() == "sell", "sell mode")
fire("MERCHANT_CLOSED")
ok(ns.Context.MerchantMode() == "buy", "MERCHANT_CLOSED resets to buy mode")
MerchantFrame.shown = false refresh()
ok(ns.Context.MerchantMode() == "buy", "closing the merchant resets to buy mode")
for i = 1, 4 do _G["MerchantItem" .. i .. "ItemButton"] = nil end
MerchantNextPageButton, MerchantPrevPageButton = nil, nil

---------------- placing (ground targeting) ----------------
SpellIsTargeting = function() return true end refresh()
ok(effective("PAD1") == "CAMERAORSELECTORMOVE" and effective("PAD2") == "TOGGLEGAMEMENU", "placing: Cross clicks in the world, Circle cancels")
ok(CharacterControlPadContextHints.anchorTo == UIParent and CharacterControlPadContextHints.text.text:find("Place", 1, true), "placing hint on screen")
SpellIsTargeting = function() return false end
bagsOpen = false bagFrame.shown = false refresh()
ok(layers[ctxOwner()] == nil and not CharacterControlPadContextHighlight.shown, "bags closed -> no layer, no selection")

---------------- loot with Square as the confirm button ----------------
SlashCmdList.CHARACTERCONTROLPAD("context confirm square")
e1.shown, e2.shown, e3.shown = true, true, true
LootFrame.shown = true looted = {} refresh()
ok(effective("PAD3") == "CLICK CharacterControlPadContextFnPAD3:LeftButton" and effective("PAD1") == "CLICK CharacterControlPadContextFnPAD1:LeftButton", "loot: Square takes, Cross takes all")
CharacterControlPadContextFnPAD3.scripts.OnClick(CharacterControlPadContextFnPAD3)
ok(#looted == 1 and looted[1] == 1, "Square took the selected item")
LootFrame.shown = false refresh()
SlashCmdList.CHARACTERCONTROLPAD("context confirm cross")

---------------- panel ----------------
SlashCmdList.CHARACTERCONTROLPAD("")
local cf = CharacterControlPadConfigFrame
ok(cf.pageTabs.windows and cf.pageTabs.windows.text == "Windows", "settings window has the Windows tab")
cf.pageTabs.windows.scripts.OnClick()
local cp = CharacterControlPadContextPanel
ok(cp.shown and cf.pages.windows.shown and not cf.pages.controller.shown, "Windows tab shows the context page")
ok(cp.heading.text == "Context controls", "context page heading")
cf:Hide() SlashCmdList.CHARACTERCONTROLPAD("context")
ok(cf.shown and cf.pages.windows.shown, "/ccp context opens the Windows page")
local function check(label) for _, c in ipairs(cp.children) do if rawget(c, "label") and c.label.text == label then return c end end end
local lootCheck = check("Loot")
ok(lootCheck and lootCheck.checked == true, "group checkbox reflects setting")
lootCheck.checked = false lootCheck.scripts.OnClick(lootCheck)
ok(ns.db.context.off.loot == true, "unchecking turns the group off")
LootFrame.shown = true refresh()
ok(effective("PAD1") == "ACTIONBUTTON1", "loot group off -> Cross normal")
lootCheck.checked = true lootCheck.scripts.OnClick(lootCheck)
ok(ns.db.context.off.loot == nil and effective("PAD1") == "CLICK CharacterControlPadContextFnPAD1:LeftButton", "checking turns it back on immediately")
local master = check("Enable context controls")
master.checked = false master.scripts.OnClick(master)
ok(ns.db.context.enabled == false and layers[ctxOwner()] == nil and lootCheck.enabled == false, "master switch off disables groups")
master.checked = true master.scripts.OnClick(master)
local hintCheck = check("Show button hints under the window")
hintCheck.checked = false hintCheck.scripts.OnClick(hintCheck)
ok(ns.db.context.hints == false and not CharacterControlPadContextHints.shown, "hints can be hidden")
local cbs = cp.confirmButtons
ok(#cbs == 3 and cbs[1].text == "Cross" and cbs[1].selected and not cbs[2].selected, "confirm button choice: Cross selected")
cbs[3].scripts.OnClick(cbs[3])
ok(ns.db.context.confirm == "PAD4" and cbs[3].selected and not cbs[1].selected, "choosing Triangle as the confirm button")
cbs[1].scripts.OnClick(cbs[1])
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
