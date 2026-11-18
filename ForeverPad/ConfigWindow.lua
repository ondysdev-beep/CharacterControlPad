-- ForeverPad - configuration window (part 1: overview + editing through the action picker)
--
--  ┌ ForeverPad ──────────────────────────────────────────────┐
--  │ Profile: Default   Status: active   Modifiers: L1=SHIFT… │
--  │ [No modifier] [L1] [R1] [L1+R1]                          │
--  │ Cross     [icon] Lightning Bolt (Main bar #1)  [Change][X]│
--  │ ...                                                      │
--  │ hint                                         [Disable]   │
--  └──────────────────────────────────────────────────────────┘
--
-- The window only edits the active profile and calls Engine.Apply(); it never touches
-- Blizzard frames. Editing is locked in combat (bindings cannot change there).

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Config = {}
ns.Config = Config

local WIDTH, HEIGHT = 640, 640
local ROWS_TOP = 96
local ROW_HEIGHT = 24
local MAX_ROWS = 20
local MAX_LAYERS = 8
local TAB_WIDTH = 74

local frame
local rows, tabs = {}, {}
local layers = {}
local currentLayer = 1

------------------------------------------------------------------------
-- Shared widget helpers (also used by ActionPicker.lua)
------------------------------------------------------------------------

function ns.CreatePanelFrame(name, width, height)
	local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BasicFrameTemplateWithInset")
	if not ok or not f then
		f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32,
				insets = { left = 8, right = 8, top = 8, bottom = 8 },
			})
		end
	end
	f:SetSize(width, height)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.title:SetPoint("TOP", f, "TOP", 0, -5)
	f:Hide()
	table.insert(UISpecialFrames, name) -- Esc closes it
	return f
end

-- Side panels (action picker, modifiers, profiles) open next to the config window, one at a time.
ns.sidePanels = {}

function ns.RegisterSidePanel(panel)
	table.insert(ns.sidePanels, panel)
end

function ns.HideSidePanels(except)
	for _, p in ipairs(ns.sidePanels) do
		if p ~= except and p:IsShown() then
			p:Hide()
		end
	end
end

function ns.OpenSidePanel(panel)
	ns.HideSidePanels(panel)
	panel:ClearAllPoints()
	local config = ns.Config and ns.Config.frame
	if config and config:IsShown() then
		panel:SetPoint("TOPLEFT", config, "TOPRIGHT", 4, 0)
	else
		panel:SetPoint("CENTER")
	end
	panel:Show()
end

function ns.CreateButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height or 22)
	b:SetText(text)
	return b
end

function ns.ShowActionTooltip(owner, slot, footer)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	local shown = false
	if slot then
		local okHas, has = pcall(HasAction, slot)
		if okHas and has == true then
			shown = pcall(GameTooltip.SetAction, GameTooltip, slot)
		end
	end
	if not shown then
		GameTooltip:SetText(L.EMPTY_SLOT, 0.7, 0.7, 0.7)
	end
	if footer then
		GameTooltip:AddLine(footer, 0.6, 0.6, 0.6)
	end
	GameTooltip:Show()
end

------------------------------------------------------------------------
-- Layers (one per combination of the profile's modifiers)
------------------------------------------------------------------------

local buttonOrder = {}
for i, b in ipairs(ns.BUTTONS) do
	buttonOrder[b.key] = i
end

local function ModifierButtons(profile)
	local list = {}
	for _, m in ipairs(ns.MODIFIERS) do -- canonical order ALT, CTRL, SHIFT
		local key = profile.modifiers[m.id]
		if key and key ~= "none" and ns.buttonByKey[key] then
			list[#list + 1] = { id = m.id, button = ns.buttonByKey[key] }
		end
	end
	return list
end

local function IsModifierButton(profile, key)
	for _, m in ipairs(ns.MODIFIERS) do
		if profile.modifiers[m.id] == key then
			return true
		end
	end
	return false
end

local function BuildLayers(profile)
	local mods = ModifierButtons(profile)
	local result = {}
	for mask = 0, 2 ^ #mods - 1 do
		local prefix, parts = "", {}
		for i, m in ipairs(mods) do
			if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
				prefix = prefix .. m.id .. "-"
				parts[#parts + 1] = m.button
			end
		end
		table.sort(parts, function(a, b)
			return buttonOrder[a.key] < buttonOrder[b.key]
		end)
		local labels = {}
		for _, b in ipairs(parts) do
			labels[#labels + 1] = b.label
		end
		result[#result + 1] = {
			prefix = prefix,
			count = #parts,
			label = #parts == 0 and L.LAYER_BASE or table.concat(labels, "+"),
		}
	end
	table.sort(result, function(a, b)
		if a.count ~= b.count then
			return a.count < b.count
		end
		return a.label < b.label
	end)
	return result
end

local function ModifierSummary(profile)
	local parts = {}
	for _, m in ipairs(ModifierButtons(profile)) do
		parts[#parts + 1] = m.button.label .. "=" .. m.id
	end
	return #parts > 0 and table.concat(parts, ", ") or L.MODIFIERS_NONE
end

------------------------------------------------------------------------
-- Action display
------------------------------------------------------------------------

-- Returns text, icon, slot for a profile action.
function Config.ActionInfo(action)
	if type(action) ~= "table" then
		return nil
	end
	if action.type == "bar" then
		local bar = ns.BARS[tonumber(action.bar) or 0]
		local slot = Engine.SlotForBarButton(action.bar, action.button)
		local where = string.format("%s #%s", bar and bar.label or "?", tostring(action.button))
		local content = slot and Engine.DescribeSlot(slot) or "?"
		if content == "empty" then
			content = "|cff888888" .. L.EMPTY_SLOT .. "|r"
		end
		local icon
		if slot then
			local ok, tex = pcall(GetActionTexture, slot)
			icon = ok and tex or nil
		end
		return string.format("%s  |cff888888(%s)|r", tostring(content), where), icon, slot
	elseif action.type == "command" then
		return string.format("%s  |cff888888(%s)|r", ns.commandLabel[action.command] or tostring(action.command), L.COMMAND)
	elseif action.type == "click" then
		local name = tostring(action.button)
		local frame = _G[name]
		if type(frame) ~= "table" then
			return string.format("|cffff8800%s|r  |cff888888(%s)|r", L.BUTTON_NOT_FOUND, name)
		end
		local slot = Engine.SlotForFrame(frame)
		local content, icon = name, nil
		if slot then
			content = Engine.DescribeSlot(slot)
			if content == "empty" then
				content = "|cff888888" .. L.EMPTY_SLOT .. "|r"
			end
			local ok, tex = pcall(GetActionTexture, slot)
			icon = ok and tex or nil
		end
		return string.format("%s  |cff888888(%s)|r", tostring(content), name), icon, slot
	end
	return "?"
end

------------------------------------------------------------------------
-- Editing
------------------------------------------------------------------------

function Config.SetBinding(key, action)
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	Profiles.Active().bindings[key] = action
	Engine.Apply("config window")
	Config.Refresh()
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

local function CreateRow(index)
	local row = CreateFrame("Frame", nil, frame)
	row:SetSize(WIDTH - 32, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(ROWS_TOP + (index - 1) * ROW_HEIGHT))
	row:EnableMouse(true)

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetWidth(120)
	row.label:SetJustifyH("LEFT")

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(20, 20)
	row.icon:SetPoint("LEFT", row, "LEFT", 124, 0)

	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.text:SetPoint("LEFT", row, "LEFT", 150, 0)
	row.text:SetWidth(330)
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)

	row.change = ns.CreateButton(row, L.CHANGE, 80)
	row.change:SetPoint("LEFT", row, "LEFT", 486, 0)
	row.change:SetScript("OnClick", function()
		ns.Picker.Open(row.bindingKey)
	end)

	row.clear = ns.CreateButton(row, "X", 26)
	row.clear:SetPoint("LEFT", row.change, "RIGHT", 4, 0)
	row.clear:SetScript("OnClick", function()
		Config.SetBinding(row.bindingKey, nil)
	end)

	row:SetScript("OnEnter", function(self)
		if self.slot then
			ns.ShowActionTooltip(self, self.slot)
		elseif self.isTap then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.TAP_NOTE)
			GameTooltip:Show()
		end
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return row
end

local function CreateTab(index)
	local tab = ns.CreateButton(frame, "", TAB_WIDTH, 22)
	if index == 1 then
		tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -60)
	else
		tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 2, 0)
	end
	tab:SetScript("OnClick", function()
		currentLayer = index
		Config.Refresh()
	end)
	return tab
end

local function Create()
	frame = ns.CreatePanelFrame("ForeverPadConfigFrame", WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame.title:SetText(L.TITLE .. "  " .. ns.VERSION)

	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -36)
	frame.status:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	frame.status:SetJustifyH("LEFT")

	for i = 1, MAX_LAYERS do
		tabs[i] = CreateTab(i)
	end
	for i = 1, MAX_ROWS do
		rows[i] = CreateRow(i)
	end

	frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 60)
	frame.hint:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	frame.hint:SetJustifyH("LEFT")
	frame.hint:SetText(L.HINT)

	frame.compat = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.compat:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 78)
	frame.compat:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	frame.compat:SetJustifyH("LEFT")

	frame.errors = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.errors:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 42)
	frame.errors:SetJustifyH("LEFT")

	frame.toggle = ns.CreateButton(frame, L.DISABLE, 96)
	frame.toggle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
	frame.toggle:SetScript("OnClick", function()
		if InCombatLockdown() then
			ns.Print(L.COMBAT_LOCKED)
			return
		end
		ns.db.enabled = not ns.db.enabled
		Engine.Apply(ns.db.enabled and "enabled" or "disabled")
		Config.Refresh()
	end)

	frame.quickBind = ns.CreateButton(frame, L.QB_BUTTON, 120)
	frame.quickBind:SetPoint("RIGHT", frame.toggle, "LEFT", -6, 0)
	frame.quickBind:SetScript("OnClick", function()
		if ns.QuickBind then
			ns.QuickBind.Start()
		end
	end)

	frame.profilesButton = ns.CreateButton(frame, L.PROFILES_BUTTON, 90)
	frame.profilesButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 12)
	frame.profilesButton:SetScript("OnClick", function()
		if ns.ProfilesPanel then
			ns.ProfilesPanel.Open()
		end
	end)

	frame.modifiersButton = ns.CreateButton(frame, L.MODS_BUTTON, 90)
	frame.modifiersButton:SetPoint("LEFT", frame.profilesButton, "RIGHT", 4, 0)
	frame.modifiersButton:SetScript("OnClick", function()
		if ns.ModifierPanel then
			ns.ModifierPanel.Open()
		end
	end)

	frame.setupButton = ns.CreateButton(frame, L.SETUP_BUTTON, 104)
	frame.setupButton:SetPoint("LEFT", frame.modifiersButton, "RIGHT", 4, 0)
	frame.setupButton:SetScript("OnClick", function()
		if ns.Wizard then
			frame:Hide()
			ns.Wizard.Open()
		end
	end)

	frame:SetScript("OnShow", function()
		Config.Refresh()
	end)
	frame:SetScript("OnHide", function()
		ns.HideSidePanels()
	end)
	Config.frame = frame
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------

function Config.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local profile = Profiles.Active()
	local locked = InCombatLockdown()
	layers = BuildLayers(profile)
	if currentLayer > #layers then
		currentLayer = 1
	end
	local layer = layers[currentLayer]

	-- status line
	local s = ns.db.lastApply
	local status
	if locked then
		status = L.STATUS_COMBAT
	elseif not ns.db.enabled then
		status = L.STATUS_DISABLED
	elseif s and s.status == "active" then
		status = L.STATUS_ACTIVE
	else
		status = L.STATUS_PAUSED
	end
	frame.status:SetText(string.format(L.STATUS_LINE, Profiles.ActiveName(), status, ModifierSummary(profile)))

	-- layer tabs
	for i = 1, MAX_LAYERS do
		local tab, data = tabs[i], layers[i]
		if data then
			tab:SetText(data.label)
			if i == currentLayer then
				tab:LockHighlight()
			else
				tab:UnlockHighlight()
			end
			tab:Show()
		else
			tab:Hide()
		end
	end

	-- rows
	local n = 0
	for _, b in ipairs(ns.BUTTONS) do
		local isMod = IsModifierButton(profile, b.key)
		if b.configurable ~= false and not (isMod and layer.prefix ~= "") then
			n = n + 1
			local row = rows[n]
			if not row then
				break
			end
			local key = layer.prefix .. b.key
			local action = profile.bindings[key]
			local text, icon, slot = Config.ActionInfo(action)
			row.bindingKey = key
			row.slot = slot
			row.isTap = isMod
			row.label:SetText(isMod and (b.label .. " |cff888888" .. L.TAP .. "|r") or b.label)
			row.text:SetText(text or ("|cff666666" .. L.NOT_ASSIGNED .. "|r"))
			if icon then
				pcall(row.icon.SetTexture, row.icon, icon)
				row.icon:Show()
			else
				row.icon:Hide()
			end
			if locked then
				row.change:Disable()
			else
				row.change:Enable()
			end
			if locked or not action then
				row.clear:Disable()
			else
				row.clear:Enable()
			end
			row:Show()
		end
	end
	for i = n + 1, MAX_ROWS do
		rows[i]:Hide()
	end

	-- footer
	local errorCount = 0
	for _, list in ipairs({ s and s.errors, s and s.conflicts }) do
		if type(list) == "table" then
			for _ in pairs(list) do
				errorCount = errorCount + 1
			end
		end
	end
	frame.errors:SetText(errorCount > 0 and string.format(L.ERRORS, errorCount) or "")
	frame.compat:SetText(ns.Compat and ns.Compat.Summary() or "")
	frame.toggle:SetText(ns.db.enabled and L.DISABLE or L.ENABLE)
	for _, b in ipairs({ frame.toggle, frame.quickBind, frame.profilesButton, frame.modifiersButton, frame.setupButton }) do
		if locked then
			b:Disable()
		else
			b:Enable()
		end
	end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------

function Config.Toggle()
	if not frame then
		Create()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

ns.On("PLAYER_REGEN_DISABLED", function()
	ns.HideSidePanels()
	Config.Refresh()
end)
ns.On("PLAYER_REGEN_ENABLED", Config.Refresh)
ns.On("ACTIONBAR_SLOT_CHANGED", Config.Refresh)
ns.On("ACTIONBAR_PAGE_CHANGED", Config.Refresh)
ns.On("UPDATE_BONUS_ACTIONBAR", Config.Refresh)

ns.RegisterCommand("config", "open the configuration window (same as /fpad)", Config.Toggle)
