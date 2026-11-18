-- ForeverPad - context controls
-- While a game window is open, a few controller buttons temporarily get a meaning that fits it:
--   Circle      closes windows (the game's own Esc command, TOGGLEGAMEMENU)
--   merchant    Cross buys the hovered merchant item, Square sells the hovered bag item,
--               Triangle repairs everything, Options sells all junk
--   NPC/quests  D-pad Up/Down chooses an option, Cross confirms (accept / continue / complete)
--   dialogs     Cross accepts, Circle declines (popups, ready check, dungeon queue, role check)
--   loot        Cross loots everything
--   mail        Cross opens all mail;  bank: Square moves the hovered item;  trainer: Cross trains
--
-- How it stays safe:
--   * the layer is a separate set of *priority* override bindings on its own owner frame, so the
--     player's layout (BindingEngine.lua) is never touched; when the window closes, the layer is gone;
--   * only unmodified buttons are used, so L1/R1 combos keep their normal actions;
--   * clicks go through a SecureActionButton ("type" = "click", attribute "clickbutton" = the Blizzard
--     button). The binding press is a hardware event, so the Blizzard button runs untainted, exactly
--     as if the player clicked it with the mouse. ForeverPad calls no protected function itself;
--   * bindings may only change out of combat: the layer is dropped when combat starts
--     (PLAYER_REGEN_DISABLED, still before the lockdown) and comes back after it. In combat the
--     player's own layout always applies.

local _, ns = ...

local L = ns.L

local Context = {}
ns.Context = Context

local KEY = {
	CROSS = "PAD1", CIRCLE = "PAD2", SQUARE = "PAD3", TRIANGLE = "PAD4",
	OPTIONS = "PADFORWARD", UP = "PADDUP", DOWN = "PADDDOWN",
}
Context.KEY = KEY

-- Order = order in the settings panel.
Context.GROUPS = { "close", "popup", "merchant", "quest", "loot", "mail", "bank", "trainer" }

local REFRESH_INTERVAL = 0.1

local owner
local proxies, funcButtons = {}, {}
local bound = {} -- key -> signature of what is bound now
local highlight, hintFrame
local nav = { list = {}, index = 1, signature = "" }

------------------------------------------------------------------------
-- Settings (account wide): ForeverPadDB.context = { enabled, hints, off = { [group] = true } }
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
	return s
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

local function UseList(list, defaultIndex)
	local sig = tostring(#list) .. ":" .. tostring(list[1]) .. ":" .. tostring(list[#list])
	if sig ~= nav.signature then
		nav.signature = sig
		nav.index = defaultIndex or 1
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

CONTEXTS.loot = function(c)
	if not Shown("LootFrame") then
		return
	end
	c.Claim(KEY.CROSS, { kind = "func", fn = LootAll, label = L.CTX_LOOT_ALL })
	c.Hint(KEY.CROSS, L.CTX_LOOT_ALL, "LootFrame")
end

CONTEXTS.merchant = function(c)
	if not Shown("MerchantFrame") then
		return
	end
	local focus = Context.MouseFocus()
	if Context.IsMerchantItem(focus) and Visible(focus) then
		c.Claim(KEY.CROSS, Click(focus, L.CTX_BUY, "RightButton"))
	elseif Context.IsBagItem(focus) and Visible(focus) then
		c.Claim(KEY.SQUARE, Click(focus, L.CTX_SELL, "RightButton"))
	end
	c.Hint(KEY.CROSS, L.CTX_BUY_HINT, "MerchantFrame")
	c.Hint(KEY.SQUARE, L.CTX_SELL_HINT)
	if Usable("MerchantRepairAllButton") then
		c.Claim(KEY.TRIANGLE, Click(MerchantRepairAllButton, L.CTX_REPAIR))
		c.Hint(KEY.TRIANGLE, L.CTX_REPAIR)
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
	c.Claim(KEY.CROSS, Click(target, L.CTX_SELECT))
	if #list > 1 then
		c.Claim(KEY.UP, { kind = "func", fn = function() Context.Navigate(-1) end, label = L.CTX_CHOOSE, sig = "nav-up" })
		c.Claim(KEY.DOWN, { kind = "func", fn = function() Context.Navigate(1) end, label = L.CTX_CHOOSE, sig = "nav-down" })
		c.Hint(KEY.UP, L.CTX_CHOOSE, anchor)
	end
	c.Hint(KEY.CROSS, L.CTX_SELECT, anchor)
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
local ORDER = { "popup", "loot", "merchant", "bank", "mail", "trainer", "quest", "close" }

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

local function AfterClick()
	-- a chosen quest reward moves the selection to the Complete button
	local target = nav.list[nav.index]
	if target and rawget(target, "type") == "choice" and nav.index < #nav.list then
		nav.index = #nav.list
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0, Context.Refresh)
	end
end

local function Proxy(key)
	local p = proxies[key]
	if not p then
		p = CreateFrame("Button", "ForeverPadContext" .. key, UIParent, "SecureActionButtonTemplate")
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
		b = CreateFrame("Button", "ForeverPadContextFn" .. key, UIParent)
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
		highlight = CreateFrame("Frame", "ForeverPadContextHighlight", UIParent)
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

local HINT_ORDER = { KEY.UP, KEY.CROSS, KEY.SQUARE, KEY.TRIANGLE, KEY.OPTIONS, KEY.CIRCLE }

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
		hintFrame = CreateFrame("Frame", "ForeverPadContextHints", UIParent)
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
		hintFrame:SetPoint("TOP", c.anchor, "BOTTOM", 0, -4)
		hintFrame.anchor = c.anchor
	end
	hintFrame:Show()
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
		owner = owner or CreateFrame("Frame", "ForeverPadContextOwner")
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
	if hintFrame then
		hintFrame:Hide()
	end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	Context.Refresh()
end)

------------------------------------------------------------------------
-- /fpad context
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
	elseif CONTEXTS[a] and (b == "on" or b == "off") then
		s.off[a] = (b == "off") or nil
	else
		local list = {}
		for _, group in ipairs(Context.GROUPS) do
			list[#list + 1] = string.format("%s=%s", group, s.off[group] and "off" or "on")
		end
		ns.Printf("Context controls %s, hints %s. Groups: %s", s.enabled and "ON" or "OFF", s.hints and "on" or "off", table.concat(list, ", "))
		ns.Print("/fpad context on | off | hints on|off | <group> on|off")
		return
	end
	Context.Refresh()
	if ns.ContextPanel then
		ns.ContextPanel.Refresh()
	end
	ns.Print(L.CTX_SAVED)
end)
