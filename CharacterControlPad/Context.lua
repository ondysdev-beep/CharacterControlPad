-- CharacterControlPad - context controls
-- While a game window is open, a few controller buttons temporarily get a meaning that fits it:
--   Circle      closes windows (the game's own Esc command, TOGGLEGAMEMENU)
--   merchant    D-pad chooses goods, confirm buys one; Touchpad switches to the bags (confirm
--               sells); Triangle repairs everything, Options sells all junk
--   NPC/quests  D-pad Up/Down chooses an option, Cross confirms (accept / continue / complete)
--   dialogs     Cross accepts, Circle declines (popups, ready check, dungeon queue, role check)
--   loot        D-pad Up/Down chooses an item, confirm takes it, Square takes everything
--   bags        D-pad moves over the items, confirm uses the selected one (like a right click)
--   placing     confirm places what is being placed (campfire ...) at the cursor, Circle cancels
--   mail        Cross opens all mail;  bank: Square moves the hovered item;  trainer: Cross trains
-- "confirm" = the button the player chose on the Windows tab (Cross by default).
--
-- How it stays safe:
--   * the layer is a separate set of *priority* override bindings on its own owner frame, so the
--     player's layout (BindingEngine.lua) is never touched; when the window closes, the layer is gone;
--   * only unmodified buttons are used, so L1/R1 combos keep their normal actions;
--   * clicks go through a SecureActionButton ("type" = "click", attribute "clickbutton" = the Blizzard
--     button). The binding press is a hardware event, so the Blizzard button runs untainted, exactly
--     as if the player clicked it with the mouse. CharacterControlPad calls no protected function itself;
--   * bindings may only change out of combat: the layer is dropped when combat starts
--     (PLAYER_REGEN_DISABLED, still before the lockdown) and comes back after it. In combat the
--     player's own layout always applies.

local _, ns = ...

local L = ns.L

local Context = {}
ns.Context = Context

local KEY = {
	CROSS = "PAD1", CIRCLE = "PAD2", SQUARE = "PAD3", TRIANGLE = "PAD4",
	OPTIONS = "PADFORWARD", UP = "PADDUP", DOWN = "PADDDOWN", LEFT = "PADDLEFT", RIGHT = "PADDRIGHT",
	TOUCHPAD = "PADBACK",
}
Context.KEY = KEY

-- Order = order in the settings panel.
Context.GROUPS = { "close", "popup", "bags", "placing", "merchant", "quest", "loot", "mail", "bank", "trainer" }

-- Buttons the player may choose as "confirm" (use the selected item, take the selected loot,
-- confirm a quest option, place a campfire ...).
Context.CONFIRM_KEYS = { KEY.CROSS, KEY.SQUARE, KEY.TRIANGLE }

local REFRESH_INTERVAL = 0.1

local owner
local proxies, funcButtons = {}, {}
local bound = {} -- key -> signature of what is bound now
local highlight, hintFrame
local nav = { list = {}, index = 1, signature = "" }
local bag = { selected = nil, lastHover = nil } -- D-pad selection in the bags
-- Merchant: "buy" = the D-pad selection is on the goods, "sell" = it is in the bags (Touchpad toggles).
local merchant = { mode = "buy", selected = nil, lastHover = nil, afterPage = nil }
local tipTarget -- bag item whose tooltip the addon shows

------------------------------------------------------------------------
-- Settings (account wide): CharacterControlPadDB.context = { enabled, hints, off = { [group] = true } }
------------------------------------------------------------------------

function Context.Settings()
	ns.db.context = type(ns.db.context) == "table" and ns.db.context or {}
	local s = ns.db.context
	if s.enabled == nil then
		s.enabled = true
	end
	if s.hints == nil then
		s.hints = true
	end
	s.off = type(s.off) == "table" and s.off or {}
	local valid = false
	for _, key in ipairs(Context.CONFIRM_KEYS) do
		if s.confirm == key then
			valid = true
		end
	end
	if not valid then
		s.confirm = KEY.CROSS
	end
	return s
end

function Context.ConfirmKey()
	return Context.Settings().confirm
end

function Context.IsConfirmKey(key)
	for _, k in ipairs(Context.CONFIRM_KEYS) do
		if k == key then
			return true
		end
	end
	return false
end

-- "Take everything" in the loot window: Square, or Cross when Square is the confirm button.
function Context.AllKey()
	return Context.ConfirmKey() == KEY.SQUARE and KEY.CROSS or KEY.SQUARE
end

function Context.IsGroupOn(group)
	local s = Context.Settings()
	return s.enabled and not s.off[group]
end

------------------------------------------------------------------------
-- Frame helpers (read only - Blizzard frames are never modified)
------------------------------------------------------------------------

local function Frame(nameOrFrame)
	local f = nameOrFrame
	if type(f) == "string" then
		f = _G[f]
	end
	return type(f) == "table" and f or nil
end

local function Shown(f)
	f = Frame(f)
	if not f or type(f.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(f.IsShown, f)
	return ok and shown == true
end

local function Visible(f)
	f = Frame(f)
	if not f or type(f.IsVisible) ~= "function" then
		return false
	end
	local ok, visible = pcall(f.IsVisible, f)
	return ok and visible == true
end

local function Usable(f)
	f = Frame(f)
	if not Visible(f) then
		return false
	end
	if type(f.IsEnabled) == "function" then
		local ok, enabled = pcall(f.IsEnabled, f)
		return ok and enabled ~= false
	end
	return true
end

local function FrameName(f)
	if type(f) == "table" and type(f.GetName) == "function" then
		local ok, name = pcall(f.GetName, f)
		if ok and type(name) == "string" then
			return name
		end
	end
	return nil
end

function Context.MouseFocus()
	if type(GetMouseFoci) == "function" then
		local ok, foci = pcall(GetMouseFoci)
		if ok and type(foci) == "table" then
			return foci[1]
		end
	end
	if type(GetMouseFocus) == "function" then
		local ok, focus = pcall(GetMouseFocus)
		if ok then
			return focus
		end
	end
	return nil
end

-- MerchantItem1ItemButton ... (MerchantFrame.xml, merchant and buyback tab)
function Context.IsMerchantItem(f)
	local name = FrameName(f)
	return name ~= nil and name:match("^MerchantItem%d+ItemButton$") ~= nil
end

-- Bag slot: ContainerFrameItemButtonMixin (GetBagID) inside a container frame (also GetBagID).
function Context.IsBagItem(f)
	if type(f) ~= "table" or type(f.GetBagID) ~= "function" or type(f.GetBankTabID) == "function" then
		return false
	end
	local ok, parent = pcall(f.GetParent, f)
	return ok and type(parent) == "table" and type(parent.GetBagID) == "function"
end

-- Bank slot: BankPanelItemButtonMixin (BankFrameTemplates.lua).
function Context.IsBankItem(f)
	return type(f) == "table" and type(f.GetBankTabID) == "function" and type(f.GetContainerSlotID) == "function"
end

local function ByTop(list)
	table.sort(list, function(a, b)
		local okA, ta = pcall(a.GetTop, a)
		local okB, tb = pcall(b.GetTop, b)
		return ((okA and ta) or 0) > ((okB and tb) or 0)
	end)
	return list
end

local function AnyWindowOpen()
	if type(GetUIPanel) == "function" then
		for _, area in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
			local ok, panel = pcall(GetUIPanel, area)
			if ok and Shown(panel) then
				return true
			end
		end
	end
	if type(UISpecialFrames) == "table" then
		for _, name in ipairs(UISpecialFrames) do
			if Shown(name) then
				return true
			end
		end
	end
	if type(IsAnyBagOpen) == "function" then
		local ok, open = pcall(IsAnyBagOpen)
		if ok and open then
			return true
		end
	end
	for _, name in ipairs({ "GameMenuFrame", "WorldMapFrame", "LootFrame", "SettingsPanel" }) do
		if Shown(name) then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- Lists navigated with the D-pad (NPC dialog, quest windows)
------------------------------------------------------------------------

local GOSSIP_TYPES = { [3] = true, [4] = true, [5] = true } -- option, active quest, available quest

local function GossipList()
	local panel = Shown("GossipFrame") and GossipFrame.GreetingPanel
	local box = type(panel) == "table" and panel.ScrollBox
	if type(box) ~= "table" or type(box.GetFrames) ~= "function" then
		return nil
	end
	local ok, frames = pcall(box.GetFrames, box)
	if not ok or type(frames) ~= "table" then
		return nil
	end
	local list = {}
	for _, b in ipairs(frames) do
		local data
		if type(b.GetElementData) == "function" then
			local okData, d = pcall(b.GetElementData, b)
			data = okData and d or nil
		end
		if type(data) == "table" and GOSSIP_TYPES[data.buttonType] and Visible(b) then
			list[#list + 1] = b
		end
	end
	return ByTop(list)
end

-- Returns list, defaultIndex
local function QuestList()
	if not Shown("QuestFrame") then
		return nil
	end
	local list = {}
	if Shown("QuestFrameGreetingPanel") then
		local pool = QuestFrameGreetingPanel.titleButtonPool
		if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
			for b in pool:EnumerateActive() do
				if Visible(b) then
					list[#list + 1] = b
				end
			end
		end
		return ByTop(list), 1
	elseif Shown("QuestFrameDetailPanel") then
		if Usable("QuestFrameAcceptButton") then
			list[1] = QuestFrameAcceptButton
		end
		return list, 1
	elseif Shown("QuestFrameProgressPanel") then
		if Usable("QuestFrameCompleteButton") then
			list[1] = QuestFrameCompleteButton
		end
		return list, 1
	elseif Shown("QuestFrameRewardPanel") then
		local rewards = Frame("QuestInfoRewardsFrame")
		if rewards and type(rewards.RewardButtons) == "table" then
			for _, b in ipairs(rewards.RewardButtons) do
				if Visible(b) and rawget(b, "type") == "choice" then
					list[#list + 1] = b
				end
			end
		end
		ByTop(list)
		if Usable("QuestFrameCompleteQuestButton") then
			list[#list + 1] = QuestFrameCompleteQuestButton
		end
		return list, 1
	end
	return nil
end

-- Loot window (Blizzard_UIPanels_Game/Mainline/LootFrame.lua): ScrollBox element frames with
-- GetSlotIndex() and an .Item button; looted entries are hidden (LOOT_SLOT_CLEARED).
local function LootList()
	local frame = Frame("LootFrame")
	local box = frame and rawget(frame, "ScrollBox")
	if type(box) ~= "table" or type(box.GetFrames) ~= "function" then
		return nil
	end
	local ok, frames = pcall(box.GetFrames, box)
	if not ok or type(frames) ~= "table" then
		return nil
	end
	local list = {}
	for _, f in ipairs(frames) do
		if type(f) == "table" and type(f.GetSlotIndex) == "function" and rawget(f, "Item") and Visible(f) then
			list[#list + 1] = f
		end
	end
	return ByTop(list)
end

-- Bag item buttons on screen (Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua): the combined
-- backpack and the separate bag frames keep their slots in container.Items[1 .. GetBagSize()].
local function BagList()
	local list = {}
	local function Add(container)
		if not Shown(container) or type(container.GetBagSize) ~= "function" then
			return
		end
		local items = rawget(container, "Items")
		local ok, size = pcall(container.GetBagSize, container)
		if type(items) ~= "table" or not ok or type(size) ~= "number" then
			return
		end
		for i = 1, size do
			local b = items[i]
			if type(b) == "table" and Visible(b) then
				list[#list + 1] = b
			end
		end
	end
	Add(Frame("ContainerFrameCombinedBags"))
	local holder = Frame("ContainerFrameContainer")
	local frames = holder and rawget(holder, "ContainerFrames")
	if type(frames) == "table" then
		for _, f in ipairs(frames) do
			Add(f)
		end
	end
	return list
end
Context.BagList = BagList

local function Center(f)
	if type(f) ~= "table" or type(f.GetCenter) ~= "function" then
		return nil
	end
	local ok, x, y = pcall(f.GetCenter, f)
	if ok and type(x) == "number" and type(y) == "number" then
		return x, y
	end
	return nil
end

local DIRECTIONS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, 1 }, down = { 0, -1 } }

-- Nearest button in a screen direction from "from" (straight lines preferred over diagonals).
function Context.Neighbor(list, from, direction)
	local fx, fy = Center(from)
	local d = DIRECTIONS[direction]
	if not fx or not d then
		return nil
	end
	local best, bestScore
	for _, b in ipairs(list) do
		local x, y = Center(b)
		if b ~= from and x then
			local dx, dy = x - fx, y - fy
			local along = dx * d[1] + dy * d[2]
			if along > 1 then
				local score = along + 3 * math.abs(dx * d[2] + dy * d[1])
				if not bestScore or score < bestScore then
					best, bestScore = b, score
				end
			end
		end
	end
	return best
end

-- Top-left item (highest row, then leftmost).
local function FirstItem(list)
	local best, bx, by
	for _, b in ipairs(list) do
		local x, y = Center(b)
		if x and (not best or y > by + 4 or (math.abs(y - by) <= 4 and x < bx)) then
			best, bx, by = b, x, y
		end
	end
	return best or list[1]
end

-- keep = after the list changes, stay at the same position (the next entry) instead of the default
local function UseList(list, defaultIndex, keep)
	local sig = tostring(#list) .. ":" .. tostring(list[1]) .. ":" .. tostring(list[#list])
	if sig ~= nav.signature then
		local fresh = nav.signature == ""
		nav.signature = sig
		if fresh or not keep then
			nav.index = defaultIndex or 1
		end
	end
	nav.list = list
	if nav.index > #list then
		nav.index = #list
	end
	if nav.index < 1 then
		nav.index = 1
	end
	return list[nav.index]
end

function Context.Navigate(step)
	local n = #nav.list
	if n == 0 then
		return
	end
	nav.index = ((nav.index - 1 + step) % n) + 1
	Context.Refresh()
end

function Context.NavIndex()
	return nav.index, #nav.list
end

------------------------------------------------------------------------
-- Context definitions. Each adds bindings (first claim of a key wins) and hint lines.
------------------------------------------------------------------------

local function LootAll()
	if type(GetNumLootItems) ~= "function" or type(LootSlot) ~= "function" then
		return
	end
	for slot = GetNumLootItems(), 1, -1 do
		pcall(LootSlot, slot)
	end
end

-- Takes the entry selected with the D-pad (same LootSlot call as LootAll, one slot).
local function LootSelected()
	local f = nav.list[nav.index]
	if type(f) ~= "table" or type(f.GetSlotIndex) ~= "function" or type(LootSlot) ~= "function" then
		return
	end
	local ok, slot = pcall(f.GetSlotIndex, f)
	if ok and type(slot) == "number" then
		pcall(LootSlot, slot)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Context.Refresh)
	end
end

local function Click(frame, label, button)
	return { kind = "click", frame = frame, button = button or "LeftButton", label = label }
end

local function Collector()
	local c = { want = {}, hints = {}, hinted = {}, anchor = nil, navTarget = nil }
	function c.Claim(key, spec)
		if not c.want[key] then
			c.want[key] = spec
		end
	end
	-- Hints describe the window even when the action needs a hovered item. Only the topmost window
	-- (the first group that adds a hint) is described, plus Circle = close.
	function c.Hint(key, text, anchor)
		c.hintGroup = c.hintGroup or c.group
		if c.group ~= c.hintGroup and c.group ~= "close" then
			return
		end
		if not c.hinted[key] then
			c.hinted[key] = true
			c.hints[#c.hints + 1] = { key = key, text = text }
		end
		c.anchor = c.anchor or Frame(anchor)
	end
	return c
end

local POPUPS = {
	{ frame = "ReadyCheckFrame", yes = "ReadyCheckFrameYesButton", no = "ReadyCheckFrameNoButton" },
	{ frame = "LFGDungeonReadyDialog", yes = "LFGDungeonReadyDialogEnterDungeonButton", no = "LFGDungeonReadyDialogLeaveQueueButton" },
	{ frame = "LFDRoleCheckPopup", yes = "LFDRoleCheckPopupAcceptButton", no = "LFDRoleCheckPopupDeclineButton" },
	{ frame = "LFGInvitePopup", yes = "LFGInvitePopupAcceptButton", no = "LFGInvitePopupDeclineButton" },
}

-- StaticPopup buttons live in popup.ButtonContainer (GameDialog.xml); GetButton(i) is the dialog's own accessor.
local function PopupButton(popup, index)
	if type(popup.GetButton) == "function" then
		local ok, b = pcall(popup.GetButton, popup, index)
		if ok and Frame(b) then
			return b
		end
	end
	local container = rawget(popup, "ButtonContainer")
	return (type(container) == "table" and Frame(rawget(container, "Button" .. index)))
		or Frame(rawget(popup, "button" .. index))
		or Frame(FrameName(popup) and (FrameName(popup) .. "Button" .. index))
end
Context.PopupButton = PopupButton

local function FirstPopup()
	for i = 1, 4 do
		local name = "StaticPopup" .. i
		if Shown(name) then
			return _G[name], PopupButton(_G[name], 1), PopupButton(_G[name], 2)
		end
	end
	for _, p in ipairs(POPUPS) do
		if Shown(p.frame) then
			return _G[p.frame], Frame(p.yes), Frame(p.no)
		end
	end
	return nil
end

local CONTEXTS = {}

CONTEXTS.popup = function(c)
	local popup, yes, no = FirstPopup()
	if not popup then
		return
	end
	if Usable(yes) then
		c.Claim(KEY.CROSS, Click(yes, L.CTX_ACCEPT))
		c.Hint(KEY.CROSS, L.CTX_ACCEPT, popup)
	end
	if Usable(no) then
		c.Claim(KEY.CIRCLE, Click(no, L.CTX_DECLINE))
		c.Hint(KEY.CIRCLE, L.CTX_DECLINE, popup)
	end
end

local function NavButtons(c, anchor)
	c.Claim(KEY.UP, { kind = "func", fn = function() Context.Navigate(-1) end, label = L.CTX_CHOOSE, sig = "nav-up" })
	c.Claim(KEY.DOWN, { kind = "func", fn = function() Context.Navigate(1) end, label = L.CTX_CHOOSE, sig = "nav-down" })
	c.Hint(KEY.UP, L.CTX_CHOOSE, anchor)
end

-- D-pad chooses an item, the confirm button takes it, Square (or Cross) takes everything.
CONTEXTS.loot = function(c)
	if not Shown("LootFrame") then
		return
	end
	local list = LootList()
	local confirm, all = Context.ConfirmKey(), Context.AllKey()
	if not list or #list == 0 then
		-- no item list available (other loot UI, or only coins being animated out): take everything
		c.Claim(confirm, { kind = "func", fn = LootAll, label = L.CTX_LOOT_ALL })
		c.Hint(confirm, L.CTX_LOOT_ALL, "LootFrame")
		return
	end
	c.navTarget = UseList(list, 1, true)
	c.Claim(confirm, { kind = "func", fn = LootSelected, label = L.CTX_LOOT_ONE, sig = "loot-selected" })
	c.Hint(confirm, L.CTX_LOOT_ONE, "LootFrame")
	c.Claim(all, { kind = "func", fn = LootAll, label = L.CTX_LOOT_ALL })
	c.Hint(all, L.CTX_LOOT_ALL)
	if #list > 1 then
		NavButtons(c)
	end
end

-- Placing something on the ground (campfire, ground-targeted spells and items): the confirm button
-- acts as a left click in the world at the cursor (moved with the touchpad or the mouse), Circle
-- cancels (Esc chain: SpellStopTargeting).
CONTEXTS.placing = function(c)
	if type(SpellIsTargeting) ~= "function" then
		return
	end
	local ok, targeting = pcall(SpellIsTargeting)
	if not ok or not targeting then
		return
	end
	local confirm = Context.ConfirmKey()
	c.Claim(confirm, { kind = "command", command = "CAMERAORSELECTORMOVE", label = L.CTX_PLACE })
	c.Hint(confirm, L.CTX_PLACE, UIParent)
	c.Claim(KEY.CIRCLE, { kind = "command", command = "TOGGLEGAMEMENU", label = L.CTX_CANCEL })
	c.Hint(KEY.CIRCLE, L.CTX_CANCEL)
end

function Context.MoveBag(direction)
	local nextItem = Context.Neighbor(BagList(), bag.selected, direction)
	if nextItem then
		bag.selected = nextItem
	end
	Context.Refresh()
end

local function BagAnchor()
	if Shown("ContainerFrameCombinedBags") then
		return ContainerFrameCombinedBags
	end
	local holder = Frame("ContainerFrameContainer")
	local frames = holder and rawget(holder, "ContainerFrames")
	if type(frames) == "table" then
		for _, f in ipairs(frames) do
			if Shown(f) then
				return f
			end
		end
	end
	return nil
end

-- Bags: the D-pad moves a selection over the items as they lie on screen; the confirm button acts
-- like a right click (use, equip, open). At a merchant / the bank, Square sells / moves the
-- selected item instead (same button as for the hovered item). An item hovered with the mouse or
-- the touchpad (the touchpad moves the mouse cursor) becomes the selection.
CONTEXTS.bags = function(c)
	if c.navTarget or c.dpadOwned then
		return -- the loot or quest window already uses the D-pad
	end
	local list = BagList()
	if #list == 0 then
		bag.selected, bag.lastHover = nil, nil
		return
	end
	local focus = Context.MouseFocus()
	local hovered = (Context.IsBagItem(focus) and Visible(focus)) and focus or nil
	if hovered and hovered ~= bag.lastHover then
		bag.selected = hovered
	end
	bag.lastHover = hovered
	local present = false
	for _, b in ipairs(list) do
		if b == bag.selected then
			present = true
		end
	end
	if not present then
		bag.selected = FirstItem(list)
	end
	local target = bag.selected
	c.navTarget = target
	c.tip = (target ~= hovered) and target or nil

	local key, label = Context.ConfirmKey(), L.CTX_USE
	if Shown("MerchantFrame") then
		label = L.CTX_SELL -- merchant in "sell" mode (in "buy" mode the merchant context owns the D-pad)
	elseif Shown("BankFrame") then
		key, label = KEY.SQUARE, L.CTX_MOVE
	end
	local anchor = BagAnchor()
	c.Claim(key, Click(target, label, "RightButton"))
	c.Hint(key, label, anchor)
	for direction, k in pairs({ up = KEY.UP, down = KEY.DOWN, left = KEY.LEFT, right = KEY.RIGHT }) do
		c.Claim(k, { kind = "func", fn = function() Context.MoveBag(direction) end, label = L.CTX_CHOOSE, sig = "bag-" .. direction })
	end
	c.Hint(KEY.UP, L.CTX_CHOOSE, anchor)
end

-- Goods on the current merchant page (MerchantItem1..12ItemButton, Blizzard_UIPanels_Game/Mainline/
-- MerchantFrame.xml; 10 per page, 12 on the buyback tab). Right click buys one / buys back.
local function MerchantList()
	local list = {}
	for i = 1, 12 do
		local b = Frame("MerchantItem" .. i .. "ItemButton")
		if b and Visible(b) then
			list[#list + 1] = b
		end
	end
	return list
end

-- Bottom-right item (lowest row, then rightmost).
local function LastItem(list)
	local best, bx, by
	for _, b in ipairs(list) do
		local x, y = Center(b)
		if x and (not best or y < by - 4 or (math.abs(y - by) <= 4 and x > bx)) then
			best, bx, by = b, x, y
		end
	end
	return best or list[#list]
end

function Context.MoveMerchant(direction)
	local nextItem = Context.Neighbor(MerchantList(), merchant.selected, direction)
	if nextItem then
		merchant.selected = nextItem
	end
	Context.Refresh()
end

function Context.ToggleMerchantMode()
	merchant.mode = (merchant.mode == "buy") and "sell" or "buy"
	Context.Refresh()
end

function Context.MerchantMode()
	return merchant.mode
end

local function AnyBagOpen()
	if type(IsAnyBagOpen) == "function" then
		local ok, open = pcall(IsAnyBagOpen)
		return ok and open == true
	end
	return #BagList() > 0
end

local function ResetMerchant()
	merchant.mode, merchant.selected, merchant.lastHover, merchant.afterPage = "buy", nil, nil, nil
end

-- Touchpad toggles buy / sell unless the player made it a modifier (then it cannot be pressed alone).
local function TouchpadFree()
	local profile = ns.Profiles and ns.Profiles.Active and ns.Profiles.Active()
	if type(profile) == "table" and type(profile.modifiers) == "table" then
		for _, m in ipairs(ns.MODIFIERS) do
			if profile.modifiers[m.id] == KEY.TOUCHPAD then
				return false
			end
		end
	end
	return true
end

-- Merchant. Touchpad switches between buying (D-pad over the goods) and selling (D-pad over the
-- bags, see "bags"); the confirm button buys / sells the item in the gold frame, one piece, like a
-- right click. At the end of a page Up / Down turns the page. Goods or a bag item hovered with the
-- mouse / touchpad become the selection. Square sells a hovered bag item. Triangle repairs (Cross
-- when Triangle confirms), Options sells junk.
CONTEXTS.merchant = function(c)
	if not Shown("MerchantFrame") then
		ResetMerchant()
		return
	end
	local confirm = Context.ConfirmKey()
	local focus = Context.MouseFocus()
	local hoverGoods = (Context.IsMerchantItem(focus) and Visible(focus)) and focus or nil
	local hoverBag = (not hoverGoods and Context.IsBagItem(focus) and Visible(focus)) and focus or nil
	if hoverBag and confirm ~= KEY.SQUARE then
		c.Claim(KEY.SQUARE, Click(hoverBag, L.CTX_SELL, "RightButton"))
	end

	local buying = merchant.mode == "buy"
	if TouchpadFree() then
		local label = buying and L.CTX_TO_SELL or L.CTX_TO_BUY
		c.Claim(KEY.TOUCHPAD, { kind = "func", fn = Context.ToggleMerchantMode, label = label, sig = "merchant-mode" })
	end

	if buying then
		local list = MerchantList()
		if c.navTarget then
			-- another window (loot) already uses the D-pad and the confirm button
		elseif #list > 0 then
			if hoverGoods and hoverGoods ~= merchant.lastHover then
				merchant.selected = hoverGoods
			end
			merchant.lastHover = hoverGoods
			if merchant.afterPage then
				merchant.selected = merchant.afterPage == "first" and FirstItem(list) or LastItem(list)
				merchant.afterPage = nil
			end
			local present = false
			for _, b in ipairs(list) do
				if b == merchant.selected then
					present = true
				end
			end
			if not present then
				merchant.selected = FirstItem(list)
			end
			local target = merchant.selected
			c.navTarget = target
			c.tip = (target ~= hoverGoods) and target or nil
			c.Claim(confirm, Click(target, L.CTX_BUY, "RightButton"))
			for direction, k in pairs({ up = KEY.UP, down = KEY.DOWN, left = KEY.LEFT, right = KEY.RIGHT }) do
				local inside = Context.Neighbor(list, target, direction)
				if not inside and direction == "down" and Usable("MerchantNextPageButton") then
					c.Claim(k, Click(MerchantNextPageButton, L.CTX_CHOOSE))
				elseif not inside and direction == "up" and Usable("MerchantPrevPageButton") then
					c.Claim(k, Click(MerchantPrevPageButton, L.CTX_CHOOSE))
				else
					c.Claim(k, { kind = "func", fn = function() Context.MoveMerchant(direction) end, label = L.CTX_CHOOSE, sig = "merchant-" .. direction })
				end
			end
			c.Hint(confirm, L.CTX_BUY, "MerchantFrame")
			c.Hint(KEY.UP, L.CTX_CHOOSE)
		else
			-- nothing to buy on this tab (e.g. an empty buyback tab): keep the bags from taking the
			-- D-pad and the confirm button, which would sell while the window is in buy mode
			merchant.afterPage = nil
			c.dpadOwned = true
			local idle = { kind = "func", fn = function() end, label = L.CTX_BUY, sig = "merchant-idle" }
			c.Claim(confirm, idle)
			for _, k in ipairs({ KEY.UP, KEY.DOWN, KEY.LEFT, KEY.RIGHT }) do
				c.Claim(k, idle)
			end
		end
		if TouchpadFree() then
			c.Hint(KEY.TOUCHPAD, L.CTX_TO_SELL, "MerchantFrame")
		end
	else
		if not AnyBagOpen() then
			c.Claim(confirm, { kind = "command", command = "OPENALLBAGS", label = L.CTX_OPEN_BAGS })
			c.Hint(confirm, L.CTX_OPEN_BAGS, "MerchantFrame")
		else
			c.Hint(confirm, L.CTX_SELL, "MerchantFrame")
			c.Hint(KEY.UP, L.CTX_CHOOSE)
		end
		if TouchpadFree() then
			c.Hint(KEY.TOUCHPAD, L.CTX_TO_BUY)
		end
	end
	local repairKey = (confirm == KEY.TRIANGLE) and KEY.CROSS or KEY.TRIANGLE
	if Usable("MerchantRepairAllButton") then
		c.Claim(repairKey, Click(MerchantRepairAllButton, L.CTX_REPAIR))
		c.Hint(repairKey, L.CTX_REPAIR)
	end
	if Usable("MerchantSellAllJunkButton") then
		c.Claim(KEY.OPTIONS, Click(MerchantSellAllJunkButton, L.CTX_SELL_JUNK))
		c.Hint(KEY.OPTIONS, L.CTX_SELL_JUNK)
	end
end

CONTEXTS.bank = function(c)
	if not Shown("BankFrame") then
		return
	end
	local focus = Context.MouseFocus()
	if (Context.IsBagItem(focus) or Context.IsBankItem(focus)) and Visible(focus) then
		c.Claim(KEY.SQUARE, Click(focus, L.CTX_MOVE, "RightButton"))
	end
	c.Hint(KEY.SQUARE, L.CTX_MOVE_HINT, "BankFrame")
end

CONTEXTS.mail = function(c)
	if Shown("InboxFrame") and Usable("OpenAllMail") then
		c.Claim(KEY.CROSS, Click(OpenAllMail, L.CTX_OPEN_ALL))
		c.Hint(KEY.CROSS, L.CTX_OPEN_ALL, "MailFrame")
	end
end

CONTEXTS.trainer = function(c)
	if Shown("ClassTrainerFrame") and Usable("ClassTrainerTrainButton") then
		c.Claim(KEY.CROSS, Click(ClassTrainerTrainButton, L.CTX_TRAIN))
		c.Hint(KEY.CROSS, L.CTX_TRAIN, "ClassTrainerFrame")
	end
end

CONTEXTS.quest = function(c)
	if c.navTarget or c.dpadOwned then
		return -- the loot window already uses the D-pad list
	end
	local list, default = QuestList()
	local anchor = "QuestFrame"
	if not list then
		list, default, anchor = GossipList(), 1, "GossipFrame"
	end
	if not list or #list == 0 then
		return
	end
	local target = UseList(list, default)
	c.navTarget = target
	c.Claim(Context.ConfirmKey(), Click(target, L.CTX_SELECT))
	if #list > 1 then
		NavButtons(c, anchor)
	end
	c.Hint(Context.ConfirmKey(), L.CTX_SELECT, anchor)
end

CONTEXTS.close = function(c)
	if AnyWindowOpen() then
		c.Claim(KEY.CIRCLE, { kind = "command", command = "TOGGLEGAMEMENU", label = L.CTX_CLOSE })
		if #c.hints > 0 then
			c.Hint(KEY.CIRCLE, L.CTX_CLOSE)
		end
	end
end

-- Evaluation order (priority): dialogs over everything, then the window-specific actions, Circle last.
local ORDER = { "popup", "placing", "loot", "merchant", "bank", "mail", "trainer", "quest", "bags", "close" }

function Context.Collect()
	local c = Collector()
	for _, group in ipairs(ORDER) do
		if Context.IsGroupOn(group) then
			c.group = group
			local ok, err = pcall(CONTEXTS[group], c)
			if not ok and ns.db.debug then
				ns.Printf("context %s: %s", group, tostring(err))
			end
		end
	end
	return c
end

------------------------------------------------------------------------
-- Binding the layer
------------------------------------------------------------------------

local function Signature(spec)
	if spec.kind == "command" then
		return "cmd:" .. spec.command
	elseif spec.kind == "click" then
		return "click:" .. tostring(spec.frame) .. ":" .. spec.button
	end
	return "func:" .. (spec.sig or tostring(spec.fn))
end

local function AfterClick(proxy, _, down)
	-- a chosen quest reward moves the selection to the Complete button
	local target = nav.list[nav.index]
	if target and rawget(target, "type") == "choice" and nav.index < #nav.list then
		nav.index = #nav.list
	end
	-- a merchant page turned with the D-pad: continue at the top (next page) / bottom (previous page)
	local clicked = type(proxy) == "table" and type(proxy.GetAttribute) == "function" and proxy:GetAttribute("clickbutton")
	if down == false then
		-- the release edge of a key-down click: the page was already turned on the press
	elseif clicked ~= nil and clicked == Frame("MerchantNextPageButton") then
		merchant.afterPage = "first"
	elseif clicked ~= nil and clicked == Frame("MerchantPrevPageButton") then
		merchant.afterPage = "last"
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Context.Refresh)
	end
end

local function Proxy(key)
	local p = proxies[key]
	if not p then
		p = CreateFrame("Button", "CharacterControlPadContext" .. key, UIParent, "SecureActionButtonTemplate")
		p:SetSize(1, 1)
		-- Both edges registered: SecureActionButton_OnClick acts on exactly one of them
		-- (useOnKeyDown below), whichever way the client reports the binding press.
		p:RegisterForClicks("AnyDown", "AnyUp")
		p:SetAttribute("type", "click")
		p:SetAttribute("useOnKeyDown", true)
		p:HookScript("PostClick", AfterClick)
		proxies[key] = p
	end
	return p
end

local function FuncButton(key)
	local b = funcButtons[key]
	if not b then
		b = CreateFrame("Button", "CharacterControlPadContextFn" .. key, UIParent)
		b:SetSize(1, 1)
		b:RegisterForClicks("AnyDown")
		b:SetScript("OnClick", function(self)
			if type(self.fn) == "function" then
				local ok, err = pcall(self.fn)
				if not ok then
					geterrorhandler()(err)
				end
			end
			Context.Refresh()
		end)
		funcButtons[key] = b
	end
	return b
end

local function Bind(key, spec)
	if spec.kind == "command" then
		return pcall(SetOverrideBinding, owner, true, key, spec.command)
	elseif spec.kind == "click" then
		local p = Proxy(key)
		p:SetAttribute("clickbutton", spec.frame)
		return pcall(SetOverrideBindingClick, owner, true, key, p:GetName(), spec.button)
	elseif spec.kind == "func" then
		local b = FuncButton(key)
		b.fn = spec.fn
		return pcall(SetOverrideBindingClick, owner, true, key, b:GetName(), "LeftButton")
	end
	return false
end

local function ClearLayer()
	if owner and next(bound) then
		pcall(ClearOverrideBindings, owner)
	end
	wipe(bound)
end

-- Is the layer allowed at all right now?
local function Allowed()
	if not ns.db or InCombatLockdown() then
		return false
	end
	local s = ns.db.lastApply
	if type(s) ~= "table" or s.status ~= "active" then
		return false -- disabled, or Blizzard gamepad UI (it has its own window controls)
	end
	if ns.QuickBind and ns.QuickBind.IsActive() then
		return false
	end
	return Context.Settings().enabled
end

------------------------------------------------------------------------
-- Highlight (D-pad selection) and hint line
------------------------------------------------------------------------

local function UpdateHighlight(target)
	if not target then
		if highlight then
			highlight:Hide()
		end
		return
	end
	if not highlight then
		highlight = CreateFrame("Frame", "CharacterControlPadContextHighlight", UIParent)
		highlight:SetFrameStrata("FULLSCREEN_DIALOG")
		highlight.fill = highlight:CreateTexture(nil, "OVERLAY")
		highlight.fill:SetAllPoints()
		highlight.fill:SetColorTexture(1, 0.82, 0, 0.18)
		local edges = {
			{ "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
			{ "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil },
		}
		for _, e in ipairs(edges) do
			local t = highlight:CreateTexture(nil, "OVERLAY")
			t:SetColorTexture(1, 0.82, 0, 0.9)
			t:SetPoint(e[1])
			t:SetPoint(e[2])
			if e[3] then
				t:SetWidth(e[3])
			else
				t:SetHeight(e[4])
			end
		end
	end
	if highlight.target ~= target then
		highlight:ClearAllPoints()
		highlight:SetAllPoints(target)
		highlight.target = target
	end
	highlight:Show()
end

local HINT_ORDER = { KEY.CROSS, KEY.SQUARE, KEY.TRIANGLE, KEY.UP, KEY.TOUCHPAD, KEY.OPTIONS, KEY.CIRCLE }

function Context.HintText(hints)
	local byKey = {}
	for _, h in ipairs(hints) do
		byKey[h.key] = h.text
	end
	local parts = {}
	for _, key in ipairs(HINT_ORDER) do
		if byKey[key] then
			local b = ns.buttonByKey[key]
			local label = key == KEY.UP and L.CTX_DPAD or (b and b.label or key)
			parts[#parts + 1] = "|cffffd100" .. label .. "|r " .. byKey[key]
		end
	end
	return table.concat(parts, "     ")
end

local function UpdateHints(c)
	local show = Context.Settings().hints and #c.hints > 0 and c.anchor ~= nil
	if not show then
		if hintFrame then
			hintFrame:Hide()
		end
		return
	end
	if not hintFrame then
		hintFrame = CreateFrame("Frame", "CharacterControlPadContextHints", UIParent)
		hintFrame:SetFrameStrata("FULLSCREEN_DIALOG")
		hintFrame.bg = hintFrame:CreateTexture(nil, "BACKGROUND")
		hintFrame.bg:SetAllPoints()
		hintFrame.bg:SetColorTexture(0, 0, 0, 0.75)
		hintFrame.text = hintFrame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
		hintFrame.text:SetPoint("CENTER")
	end
	hintFrame.text:SetText(Context.HintText(c.hints))
	local w = hintFrame.text.GetStringWidth and hintFrame.text:GetStringWidth()
	hintFrame:SetSize((type(w) == "number" and w or 300) + 20, 22)
	if hintFrame.anchor ~= c.anchor then
		hintFrame:ClearAllPoints()
		if c.anchor == UIParent then
			hintFrame:SetPoint("TOP", UIParent, "TOP", 0, -180) -- no window (placing on the ground)
		else
			hintFrame:SetPoint("TOP", c.anchor, "BOTTOM", 0, -4)
		end
		hintFrame.anchor = c.anchor
	end
	hintFrame:Show()
end

-- Tooltip of the bag item selected with the D-pad (the mouse shows its own tooltip when hovering).
-- Tooltip of the item selected with the D-pad: a bag slot or merchant goods (the same merchant
-- button shows other goods on another page, so the item index is part of the key).
local function UpdateBagTip(target)
	local okId, id = false, nil
	if target then
		okId, id = pcall(target.GetID, target)
	end
	-- merchant buttons keep their index on other pages and on the buyback tab: add the tab and the item
	local extra = ""
	if target and Context.IsMerchantItem(target) and okId then
		local tab = Frame("MerchantFrame") and rawget(MerchantFrame, "selectedTab")
		local linkFn = (tab == 2) and GetBuybackItemLink or GetMerchantItemLink
		local okLink, link = false, nil
		if type(linkFn) == "function" then
			okLink, link = pcall(linkFn, id)
		end
		extra = ":" .. tostring(tab) .. ":" .. tostring(okLink and link)
	end
	local key = target and (tostring(target) .. ":" .. tostring(okId and id) .. extra) or nil
	if key == tipTarget then
		return
	end
	local tt = ns.GetTooltip and ns.GetTooltip()
	if not tt then
		return
	end
	if tipTarget and not target then
		tt:Hide()
	end
	tipTarget = key
	if not target or not okId or type(id) ~= "number" then
		return
	end
	local shown
	if Context.IsMerchantItem(target) then
		local buyback = Frame("MerchantFrame") and rawget(MerchantFrame, "selectedTab") == 2
		tt:SetOwner(target, "ANCHOR_RIGHT")
		shown = pcall(buyback and tt.SetBuybackItem or tt.SetMerchantItem, tt, id)
	else
		local okBag, bagID = pcall(target.GetBagID, target)
		if okBag and type(bagID) == "number" then
			tt:SetOwner(target, "ANCHOR_RIGHT")
			shown = pcall(tt.SetBagItem, tt, bagID, id)
		end
	end
	if shown then
		ns.ShowTooltip()
	elseif shown == false then
		tt:Hide()
	end
end

------------------------------------------------------------------------
-- Refresh: recompute the wanted layer and rebind only when it changed
------------------------------------------------------------------------

Context.lastHints = {}

function Context.Refresh()
	if InCombatLockdown() then
		return -- bindings are locked; the layer was dropped when combat started
	end
	local c = Allowed() and Context.Collect() or Collector()

	local changed = false
	for key, spec in pairs(c.want) do
		if bound[key] ~= Signature(spec) then
			changed = true
		end
	end
	for key in pairs(bound) do
		if not c.want[key] then
			changed = true
		end
	end
	if changed then
		owner = owner or CreateFrame("Frame", "CharacterControlPadContextOwner")
		ClearLayer()
		for key, spec in pairs(c.want) do
			if Bind(key, spec) then
				bound[key] = Signature(spec)
			end
		end
	end
	Context.wanted = c.want
	Context.lastHints = c.hints
	if not c.navTarget then
		nav.list, nav.signature = {}, ""
	end
	UpdateHighlight(c.navTarget)
	UpdateHints(c)
	UpdateBagTip(c.tip)
end

-- True while the context layer holds this key (the engine's conflict check ignores it then).
function Context.Owns(key)
	return bound[key] ~= nil
end

function Context.Reset()
	if not InCombatLockdown() then
		ClearLayer()
	end
	nav.list, nav.signature = {}, ""
	UpdateHighlight(nil)
	UpdateBagTip(nil)
	if hintFrame then
		hintFrame:Hide()
	end
end

------------------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------------------

local ticker = CreateFrame("Frame")
local elapsedSince = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	elapsedSince = elapsedSince + (elapsed or 0)
	if elapsedSince < REFRESH_INTERVAL then
		return
	end
	elapsedSince = 0
	if ns.db and ns.db.lastApply and not InCombatLockdown() then
		Context.Refresh()
	end
end)

-- Fired before the combat lockdown starts: the last moment bindings may change.
ns.On("PLAYER_REGEN_DISABLED", function()
	ClearLayer()
	nav.list, nav.signature = {}, ""
	UpdateHighlight(nil)
	UpdateBagTip(nil)
	if hintFrame then
		hintFrame:Hide()
	end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	Context.Refresh()
end)

-- The merchant may close while the layer is not refreshed (combat, quick bind, group switched off).
ns.On("MERCHANT_CLOSED", function()
	ResetMerchant()
end)

------------------------------------------------------------------------
-- /ccp context
------------------------------------------------------------------------

local function GroupLabel(group)
	return L["CTX_GROUP_" .. group:upper()]
end
Context.GroupLabel = GroupLabel

ns.RegisterCommand("context", "context controls window; on | off | status | hints on|off | <group> on|off", function(rest)
	local s = Context.Settings()
	local a, b = (rest or ""):lower():match("^(%S*)%s*(%S*)")
	if a == "" and ns.ContextPanel then
		ns.ContextPanel.Open()
		return
	elseif a == "on" or a == "off" then
		s.enabled = (a == "on")
	elseif a == "hints" and (b == "on" or b == "off") then
		s.hints = (b == "on")
	elseif a == "confirm" and ns.FindButton(b) and Context.IsConfirmKey(ns.FindButton(b).key) then
		s.confirm = ns.FindButton(b).key
	elseif CONTEXTS[a] and (b == "on" or b == "off") then
		s.off[a] = (b == "off") or nil
	else
		local list = {}
		for _, group in ipairs(Context.GROUPS) do
			list[#list + 1] = string.format("%s=%s", group, s.off[group] and "off" or "on")
		end
		local confirm = ns.buttonByKey[s.confirm]
		ns.Printf("Context controls %s, hints %s, confirm button %s. Groups: %s", s.enabled and "ON" or "OFF",
			s.hints and "on" or "off", confirm and confirm.label or tostring(s.confirm), table.concat(list, ", "))
		ns.Print("/ccp context on | off | hints on|off | confirm cross|square|triangle | <group> on|off")
		return
	end
	Context.Refresh()
	if ns.ContextPanel then
		ns.ContextPanel.Refresh()
	end
	ns.Print(L.CTX_SAVED)
end)
