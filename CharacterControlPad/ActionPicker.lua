-- CharacterControlPad - action picker
-- Opened from the configuration window for one combo. Three tabs (spec 4.4):
--   Action bars   - 8 Blizzard bars x 12 buttons with their current icons (hidden bars included)
--   Game commands - jump, autorun, interact, targeting ...
--   UI commands   - map, bags, quest log, character ...
-- Selecting an entry stores it in the active profile through Config.SetBinding().

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Picker = {}
ns.Picker = Picker

local WIDTH, HEIGHT = 530, 420
local ICON, GAP, BAR_ROW = 30, 2, 36
local CONTENT_TOP = -66

local frame
local panels, tabButtons = {}, {}
local editingKey, currentAction
local activeTab = 1

local TABS = {
	{ id = "bars", label = function() return L.TAB_BARS end },
	{ id = "game", label = function() return L.TAB_GAME end },
	{ id = "ui", label = function() return L.TAB_UI end },
}

local function Select(action)
	if editingKey then
		ns.Config.SetBinding(editingKey, action)
	end
	frame:Hide()
end

local function IsBarShown(bar)
	local f = bar.frame and _G[bar.frame]
	if type(f) ~= "table" or type(f.IsShown) ~= "function" then
		return false
	end
	local ok, shown = pcall(f.IsShown, f)
	return ok and shown == true
end

------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------

local function NewPanel()
	local panel = CreateFrame("Frame", nil, frame)
	panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, CONTENT_TOP)
	panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 48)
	panel:Hide()
	return panel
end

local function BuildBarPanel()
	local panel = NewPanel()
	panel.cells, panel.labels = {}, {}
	for barIndex, bar in ipairs(ns.BARS) do
		local y = -((barIndex - 1) * BAR_ROW)
		local label = panel:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormalSmall")
		label:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y - 9)
		label:SetWidth(110)
		label:SetJustifyH("LEFT")
		panel.labels[barIndex] = label

		for n = 1, ns.BAR_BUTTONS do
			local cell = CreateFrame("Button", nil, panel)
			cell:SetSize(ICON, ICON)
			cell:SetPoint("TOPLEFT", panel, "TOPLEFT", 114 + (n - 1) * (ICON + GAP), y)
			cell.bg = cell:CreateTexture(nil, "BACKGROUND")
			cell.bg:SetAllPoints()
			cell.bg:SetColorTexture(0, 0, 0, 0.5)
			cell.icon = cell:CreateTexture(nil, "ARTWORK")
			cell.icon:SetAllPoints()
			cell.selected = cell:CreateTexture(nil, "OVERLAY")
			cell.selected:SetAllPoints()
			cell.selected:SetColorTexture(1, 0.82, 0, 0.4)
			cell.selected:Hide()
			cell.num = cell:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
			cell.num:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -1, 1)
			cell.num:SetText(n)
			cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
			cell.bar, cell.button = barIndex, n
			cell:SetScript("OnClick", function(self)
				Select({ type = "bar", bar = self.bar, button = self.button })
			end)
			cell:SetScript("OnEnter", function(self)
				local footer = self.slot and string.format(L.BAR_SLOT, ns.BARS[self.bar].label, self.button, self.slot)
				ns.ShowActionTooltip(self, self.slot, footer)
			end)
			cell:SetScript("OnLeave", function()
				ns.GetTooltip():Hide()
			end)
			panel.cells[#panel.cells + 1] = cell
		end
	end

	function panel:Refresh()
		for barIndex, bar in ipairs(ns.BARS) do
			if IsBarShown(bar) then
				self.labels[barIndex]:SetText(bar.label)
			else
				self.labels[barIndex]:SetText("|cff888888" .. bar.label .. "\n" .. L.HIDDEN .. "|r")
			end
		end
		for _, cell in ipairs(self.cells) do
			local slot = Engine.SlotForBarButton(cell.bar, cell.button)
			cell.slot = slot
			local tex
			if slot then
				local ok, t = pcall(GetActionTexture, slot)
				tex = ok and t or nil
			end
			if tex then
				pcall(cell.icon.SetTexture, cell.icon, tex)
				cell.icon:Show()
			else
				cell.icon:Hide()
			end
			local isCurrent = currentAction and currentAction.type == "bar"
				and tonumber(currentAction.bar) == cell.bar and tonumber(currentAction.button) == cell.button
			if isCurrent then
				cell.selected:Show()
			else
				cell.selected:Hide()
			end
		end
	end
	return panel
end

local function BuildCommandPanel(group)
	local panel = NewPanel()
	panel.buttons = {}
	local i = 0
	for _, c in ipairs(ns.COMMANDS) do
		if c.group == group then
			i = i + 1
			local b = ns.CreateButton(panel, c.label, 236, 24)
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			b:SetPoint("TOPLEFT", panel, "TOPLEFT", col * 246, -row * 30)
			b.command = c.command
			b:SetScript("OnClick", function(self)
				Select({ type = "command", command = self.command })
			end)
			b:SetScript("OnEnter", function(self)
				ns.GetTooltip():SetOwner(self, "ANCHOR_RIGHT")
				ns.GetTooltip():SetText(self.command)
				if not self.valid then
					ns.GetTooltip():AddLine(L.NOT_AVAILABLE, 1, 0.3, 0.3)
				end
				ns.ShowTooltip()
			end)
			b:SetScript("OnLeave", function()
				ns.GetTooltip():Hide()
			end)
			panel.buttons[#panel.buttons + 1] = b
		end
	end

	function panel:Refresh()
		for _, b in ipairs(self.buttons) do
			b.valid = Engine.IsValidCommand(b.command)
			if b.valid then
				b:Enable()
			else
				b:Disable()
			end
			if currentAction and currentAction.type == "command" and currentAction.command == b.command then
				b:LockHighlight()
			else
				b:UnlockHighlight()
			end
		end
	end
	return panel
end

------------------------------------------------------------------------
-- Frame
------------------------------------------------------------------------

local function ShowTab(index)
	activeTab = index
	for i, panel in ipairs(panels) do
		if i == index then
			panel:Refresh()
			panel:Show()
			tabButtons[i]:LockHighlight()
		else
			panel:Hide()
			tabButtons[i]:UnlockHighlight()
		end
	end
end

local function Create()
	frame = ns.CreatePanelFrame("CharacterControlPadActionPicker", WIDTH, HEIGHT)
	ns.RegisterSidePanel(frame)

	for i, tab in ipairs(TABS) do
		local b = ns.CreateButton(frame, tab.label(), 150, 22)
		if i == 1 then
			b:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -32)
		else
			b:SetPoint("LEFT", tabButtons[i - 1], "RIGHT", 4, 0)
		end
		b:SetScript("OnClick", function()
			ShowTab(i)
		end)
		tabButtons[i] = b
	end

	panels[1] = BuildBarPanel()
	panels[2] = BuildCommandPanel("game")
	panels[3] = BuildCommandPanel("ui")

	local clear = ns.CreateButton(frame, L.CLEAR, 100)
	clear:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
	clear:SetScript("OnClick", function()
		Select(nil)
	end)

	local cancel = ns.CreateButton(frame, L.CANCEL, 100)
	cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)
	cancel:SetScript("OnClick", function()
		frame:Hide()
	end)
end

function Picker.Open(key)
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if not frame then
		Create()
	end
	local profile = Profiles.Active()
	editingKey = key
	currentAction = profile.bindings[key]
	frame.title:SetText(string.format(L.PICKER_TITLE, Engine.KeyToCombo(key, profile)))

	local tab = 1
	if currentAction and currentAction.type == "command" then
		for _, c in ipairs(ns.COMMANDS) do
			if c.command == currentAction.command then
				tab = (c.group == "ui") and 3 or 2
			end
		end
	end
	ns.OpenSidePanel(frame)
	ShowTab(tab)
end

function Picker.Hide()
	if frame then
		frame:Hide()
	end
end

function Picker.Refresh()
	if frame and frame:IsShown() and panels[activeTab] then
		panels[activeTab]:Refresh()
	end
end

ns.On("ACTIONBAR_SLOT_CHANGED", Picker.Refresh)
