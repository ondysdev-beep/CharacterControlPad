-- CharacterControlPad - settings window
--
--  ┌ CharacterControlPad 0.11.0 ─────────────────────────────────────────────── ✕ ┐
--  │ [Controller] [Windows] [Settings]                 [Profile: Default] │
--  │ Layer: [No modifier] [L1] [R1] [L1+R1]                               │
--  │ L2  [i] Spell        ╭──────────────╮        R2  [i] Spell           │
--  │ L1  [i] (tap)        │  controller  │        R1  [i] (tap)           │
--  │ ↑   [i] Jump         │   picture    │        △   [i] Fireball        │
--  │ ...                  ╰──────────────╯        ...                     │
--  │                      [ Bind on bars ]                                │
--  │ status line                                            [Disable]     │
--  └──────────────────────────────────────────────────────────────────────┘
--
-- Pages: Controller (this file), Windows (ContextPanel.Build), Settings (ModifierPanel.Build + profile,
-- language, setup). The window only edits the active profile and calls Engine.Apply(); it never
-- touches Blizzard frames. Editing is locked in combat (bindings cannot change there).

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Config = {}
ns.Config = Config

local WIDTH, HEIGHT = 860, 520
local PAGE_TOP, PAGE_BOTTOM = -66, 56
local PAGE_W = WIDTH - 32
local MAX_LAYERS = 8

local MEDIA = "Interface\\AddOns\\CharacterControlPad\\Media\\"
ns.MEDIA = MEDIA

-- Controller page geometry
local SLOT_W, SLOT_H, SLOT_STEP = 262, 36, 38
local SLOTS_TOP = -50
local ART_W = 512 -- canvas size of Media/Controller.tga (tools/make-art.js)
local IMAGE_W, IMAGE_H = 300, 150
local IMAGE_SCALE = IMAGE_W / ART_W
local GOLD = { 1, 0.82, 0 }

-- Buttons around the picture: column, row, glyph cell in Media/Glyphs.tga, marker position on the
-- 512x256 controller canvas. Left column = left half of the controller, right column = right half.
local LAYOUT = {
	{ key = "PADLTRIGGER", side = "left", row = 1, x = 165, y = 21 },
	{ key = "PADLSHOULDER", side = "left", row = 2, x = 165, y = 38 },
	{ key = "PADDUP", side = "left", row = 3, glyph = 5, x = 150, y = 82 },
	{ key = "PADDLEFT", side = "left", row = 4, glyph = 7, x = 132, y = 100 },
	{ key = "PADDRIGHT", side = "left", row = 5, glyph = 8, x = 168, y = 100 },
	{ key = "PADDDOWN", side = "left", row = 6, glyph = 6, x = 150, y = 118 },
	{ key = "PADLSTICK", side = "left", row = 7, x = 205, y = 150 },
	{ key = "PADSOCIAL", side = "left", row = 8, x = 190, y = 60 },
	{ key = "PADBACK", side = "left", row = 9, x = 256, y = 80 },
	{ key = "PADRTRIGGER", side = "right", row = 1, x = 347, y = 21 },
	{ key = "PADRSHOULDER", side = "right", row = 2, x = 347, y = 38 },
	{ key = "PAD4", side = "right", row = 3, glyph = 4, x = 362, y = 74 },
	{ key = "PAD2", side = "right", row = 4, glyph = 2, x = 388, y = 100 },
	{ key = "PAD3", side = "right", row = 5, glyph = 3, x = 336, y = 100 },
	{ key = "PAD1", side = "right", row = 6, glyph = 1, x = 362, y = 126 },
	{ key = "PADRSTICK", side = "right", row = 7, x = 307, y = 150 },
	{ key = "PADFORWARD", side = "right", row = 8, x = 322, y = 60 },
	{ key = "PAD5", side = "right", row = 9, x = 256, y = 160 },
}
Config.LAYOUT = LAYOUT

local frame
local pages, pageTabs = {}, {}
local currentPage = "controller"
local slots, markers, layerButtons = {}, {}, {}
local layers = {}
local currentLayer = 1
local heldPrefix = ""

------------------------------------------------------------------------
-- Shared widget helpers (also used by the other panels)
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
	f.title = f:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlight")
	f.title:SetPoint("TOP", f, "TOP", 0, -5)
	f:Hide()
	table.insert(UISpecialFrames, name) -- Esc closes it
	return f
end

-- Dialogs (action picker, profiles) open over the settings window, one at a time.
ns.sidePanels = {}

function ns.RegisterSidePanel(panel)
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
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
		panel:SetPoint("CENTER", config, "CENTER", 0, 0)
	else
		panel:SetPoint("CENTER")
	end
	panel:Show()
end

function ns.CreateButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, height or 22)
	if ns.HasCustomFonts() then
		b:SetNormalFontObject(ns.Font("GameFontNormal"))
		b:SetHighlightFontObject(ns.Font("GameFontHighlight"))
		b:SetDisabledFontObject(ns.Font("GameFontDisable"))
	end
	b:SetText(text)
	return b
end

-- Flat button used for page tabs and layer switches: dark background, gold text, a gold bar when selected.
function ns.CreateFlatButton(parent, text, width, height)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height or 24)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(b)
	b.bg:SetColorTexture(1, 1, 1, 0.06)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.bar:SetHeight(2)
	b.bar:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	b.bar:Hide()
	b.label = b:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormal")
	b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
	b:SetFontString(b.label)
	b:SetText(text)
	b:SetScript("OnEnter", function(self)
		if not self.selected then
			self.bg:SetColorTexture(1, 1, 1, 0.12)
		end
	end)
	b:SetScript("OnLeave", function(self)
		ns.SetFlatSelected(self, self.selected)
	end)
	return b
end

function ns.SetFlatSelected(b, selected)
	b.selected = selected and true or false
	if selected then
		b.bg:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.18)
		b.bar:Show()
		b.label:SetTextColor(1, 1, 1)
	else
		b.bg:SetColorTexture(1, 1, 1, 0.06)
		b.bar:Hide()
		b.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	end
end

function ns.CreateHeading(parent, text, x, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormalLarge")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

function ns.CreateText(parent, font, x, y, width)
	local fs = parent:CreateFontString(nil, "OVERLAY", ns.Font(font))
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then
		fs:SetWidth(width)
	end
	fs:SetJustifyH("LEFT")
	return fs
end

-- Private tooltip: the shared GameTooltip is never re-fonted or otherwise touched by CharacterControlPad.
function ns.GetTooltip()
	if not ns.tooltip then
		local ok, tt = pcall(CreateFrame, "GameTooltip", "CharacterControlPadTooltip", UIParent, "GameTooltipTemplate")
		ns.tooltip = (ok and tt) or GameTooltip
	end
	return ns.tooltip
end

function ns.ShowTooltip()
	local tt = ns.GetTooltip()
	tt:Show()
	if tt ~= GameTooltip and ns.HasCustomFonts() then
		local n = tt:NumLines()
		local name = tt:GetName()
		if type(n) == "number" and type(name) == "string" then
			for i = 1, n do
				for _, side in ipairs({ "Left", "Right" }) do
					local fs = _G[name .. "Text" .. side .. i]
					if fs and fs.GetFont and fs.SetFont then
						-- keep size, flags and colours; swap only the font file
						local _, size, flags = fs:GetFont()
						pcall(fs.SetFont, fs, ns.FONT_PATH, size or 12, flags or "")
					end
				end
			end
			tt:Show() -- re-layout with the new fonts
		end
	end
end

function ns.ShowActionTooltip(owner, slot, footer)
	ns.GetTooltip():SetOwner(owner, "ANCHOR_RIGHT")
	local shown = false
	if slot then
		local okHas, has = pcall(HasAction, slot)
		if okHas and has == true then
			shown = pcall(ns.GetTooltip().SetAction, ns.GetTooltip(), slot)
		end
	end
	if not shown then
		ns.GetTooltip():SetText(L.EMPTY_SLOT, 0.7, 0.7, 0.7)
	end
	if footer then
		ns.GetTooltip():AddLine(footer, 0.6, 0.6, 0.6)
	end
	ns.ShowTooltip()
end

function ns.ShowTextTooltip(owner, title, ...)
	local tt = ns.GetTooltip()
	tt:SetOwner(owner, "ANCHOR_RIGHT")
	tt:SetText(title)
	for i = 1, select("#", ...) do
		local line = select(i, ...)
		if line then
			tt:AddLine(line, 0.8, 0.8, 0.8, true)
		end
	end
	ns.ShowTooltip()
end

function ns.HideTooltip()
	ns.GetTooltip():Hide()
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

-- modifier id (SHIFT ...) if the button is a modifier in this profile
local function ModifierOf(profile, key)
	for _, m in ipairs(ns.MODIFIERS) do
		if profile.modifiers[m.id] == key then
			return m.id
		end
	end
	return nil
end

function Config.BuildLayers(profile)
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

-- Binding prefix of the modifiers held right now (controller modifiers are emulated keyboard modifiers).
local MOD_TEST = { ALT = "IsAltKeyDown", CTRL = "IsControlKeyDown", SHIFT = "IsShiftKeyDown" }

local function HeldPrefix(profile)
	local prefix = ""
	for _, m in ipairs(ns.MODIFIERS) do
		local key = profile.modifiers[m.id]
		local test = _G[MOD_TEST[m.id]]
		if key and key ~= "none" and type(test) == "function" then
			local ok, down = pcall(test)
			if ok and down then
				prefix = prefix .. m.id .. "-"
			end
		end
	end
	return prefix
end

------------------------------------------------------------------------
-- Action display
------------------------------------------------------------------------

local function SlotContent(slot)
	local content = Engine.DescribeSlot(slot)
	if content == "empty" then
		return nil
	end
	return content
end

local function SlotIcon(slot)
	if not slot then
		return nil
	end
	local ok, tex = pcall(GetActionTexture, slot)
	return ok and tex or nil
end

-- Parts of a profile action for display: name (nil = empty slot), where, icon, slot, missing.
function Config.ActionParts(action)
	if type(action) ~= "table" then
		return nil
	end
	if action.type == "bar" then
		local bar = ns.BARS[tonumber(action.bar) or 0]
		local slot = Engine.SlotForBarButton(action.bar, action.button)
		return {
			name = slot and SlotContent(slot),
			where = string.format("%s #%s", bar and bar.label or "?", tostring(action.button)),
			icon = SlotIcon(slot),
			slot = slot,
		}
	elseif action.type == "command" then
		return { name = ns.commandLabel[action.command] or tostring(action.command), where = L.COMMAND, command = true }
	elseif action.type == "click" then
		local name = tostring(action.button)
		local target = _G[name]
		if type(target) ~= "table" then
			return { name = L.BUTTON_NOT_FOUND, where = name, missing = true }
		end
		local slot = Engine.SlotForFrame(target)
		return { name = slot and SlotContent(slot) or (slot == nil and name or nil), where = name, icon = SlotIcon(slot), slot = slot }
	end
	return { name = "?", where = "" }
end

-- One-line description (chat messages, quick bind banner): text, icon, slot.
function Config.ActionInfo(action)
	local p = Config.ActionParts(action)
	if not p then
		return nil
	end
	if p.missing then
		return string.format("|cffff8800%s|r  |cff888888(%s)|r", p.name, p.where), nil, nil
	end
	local name = p.name or ("|cff888888" .. L.EMPTY_SLOT .. "|r")
	return string.format("%s  |cff888888(%s)|r", tostring(name), p.where), p.icon, p.slot
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

local function EditSlot(slot, mouseButton)
	if not slot.bindingKey then
		return
	end
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if mouseButton == "RightButton" then
		Config.SetBinding(slot.bindingKey, nil)
	else
		ns.Picker.Open(slot.bindingKey)
	end
end

------------------------------------------------------------------------
-- Controller page
------------------------------------------------------------------------

local function ShowMarker(slot, on)
	local marker = slot and slot.marker
	if not marker then
		return
	end
	if on then
		marker.glow:Show()
		slot.hover:Show()
	else
		marker.glow:Hide()
		slot.hover:Hide()
	end
end

local function SlotEnter(slot)
	ShowMarker(slot, true)
	local footer = slot.bindingKey and L.SLOT_CLICK or nil
	if slot.slot then
		ns.ShowActionTooltip(slot, slot.slot, footer)
	elseif slot.tooltipTitle then
		ns.ShowTextTooltip(slot, slot.tooltipTitle, slot.tooltipText, footer)
	end
end

local function SlotLeave(slot)
	ShowMarker(slot, false)
	ns.HideTooltip()
end

local function CreateSlot(page, info)
	local b = ns.buttonByKey[info.key]
	local s = CreateFrame("Button", nil, page)
	s:SetSize(SLOT_W, SLOT_H)
	local x = info.side == "left" and 0 or (PAGE_W - SLOT_W)
	s:SetPoint("TOPLEFT", page, "TOPLEFT", x, SLOTS_TOP - (info.row - 1) * SLOT_STEP)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	s.button = b

	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetAllPoints(s)
	s.bg:SetColorTexture(0, 0, 0, 0.35)
	s.hover = s:CreateTexture(nil, "BORDER")
	s.hover:SetAllPoints(s)
	s.hover:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12)
	s.hover:Hide()

	if info.glyph then
		s.glyph = s:CreateTexture(nil, "ARTWORK")
		s.glyph:SetSize(28, 28)
		s.glyph:SetPoint("LEFT", s, "LEFT", 14, 0)
		s.glyph:SetTexture(MEDIA .. "Glyphs")
		s.glyph:SetTexCoord((info.glyph - 1) / 8, info.glyph / 8, 0, 1)
	else
		s.pill = s:CreateTexture(nil, "ARTWORK")
		s.pill:SetSize(52, 22)
		s.pill:SetPoint("LEFT", s, "LEFT", 2, 0)
		s.pill:SetColorTexture(0.14, 0.16, 0.19, 1)
		s.pillText = s:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
		s.pillText:SetPoint("CENTER", s.pill, "CENTER", 0, 0)
		s.pillText:SetText(b.label)
	end

	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.icon:SetSize(30, 30)
	s.icon:SetPoint("LEFT", s, "LEFT", 60, 0)
	s.iconBg = s:CreateTexture(nil, "BORDER")
	s.iconBg:SetSize(30, 30)
	s.iconBg:SetPoint("LEFT", s, "LEFT", 60, 0)
	s.iconBg:SetColorTexture(1, 1, 1, 0.05)

	s.text = s:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlight")
	s.text:SetPoint("TOPLEFT", s, "TOPLEFT", 98, -4)
	s.text:SetWidth(SLOT_W - 104)
	s.text:SetJustifyH("LEFT")
	s.text:SetWordWrap(false)

	s.sub = s:CreateFontString(nil, "OVERLAY", ns.Font"GameFontDisableSmall")
	s.sub:SetPoint("BOTTOMLEFT", s, "BOTTOMLEFT", 98, 4)
	s.sub:SetWidth(SLOT_W - 104)
	s.sub:SetJustifyH("LEFT")
	s.sub:SetWordWrap(false)

	s:SetScript("OnClick", EditSlot)
	s:SetScript("OnEnter", SlotEnter)
	s:SetScript("OnLeave", SlotLeave)
	return s
end

local function CreateMarker(image, info, slot)
	local m = CreateFrame("Button", nil, image)
	m:SetSize(26, 26)
	m:SetPoint("CENTER", image, "TOPLEFT", info.x * IMAGE_SCALE, -info.y * IMAGE_SCALE)
	m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	m.glow = m:CreateTexture(nil, "OVERLAY")
	m.glow:SetSize(34, 34)
	m.glow:SetPoint("CENTER", m, "CENTER", 0, 0)
	m.glow:SetTexture(MEDIA .. "Glow")
	m.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
	m.glow:SetBlendMode("ADD")
	m.glow:Hide()
	m.slotFrame = slot
	slot.marker = m
	m:SetScript("OnClick", function(self, mouseButton)
		EditSlot(self.slotFrame, mouseButton)
	end)
	m:SetScript("OnEnter", function(self)
		SlotEnter(self.slotFrame)
	end)
	m:SetScript("OnLeave", function(self)
		SlotLeave(self.slotFrame)
	end)
	return m
end

local function BuildControllerPage(page)
	page.layerLabel = ns.CreateText(page, "GameFontNormal", 0, -8)
	page.layerLabel:SetText(L.LAYER_LABEL)
	for i = 1, MAX_LAYERS do
		local b = ns.CreateFlatButton(page, "", i == 1 and 140 or 80, 24)
		b:SetPoint("TOPLEFT", page, "TOPLEFT", 70 + (i == 1 and 0 or 144 + (i - 2) * 84), -2)
		b.index = i
		b:SetScript("OnClick", function(self)
			currentLayer = self.index
			Config.Refresh()
		end)
		layerButtons[i] = b
	end

	local image = CreateFrame("Frame", nil, page)
	image:SetSize(IMAGE_W, IMAGE_H)
	image:SetPoint("TOP", page, "TOP", 0, SLOTS_TOP - 4)
	image.tex = image:CreateTexture(nil, "ARTWORK")
	image.tex:SetAllPoints(image)
	image.tex:SetTexture(MEDIA .. "Controller")
	page.image = image

	for i, info in ipairs(LAYOUT) do
		slots[i] = CreateSlot(page, info)
		markers[i] = CreateMarker(image, info, slots[i])
	end

	page.help = page:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	page.help:SetPoint("TOP", image, "BOTTOM", 0, -8)
	page.help:SetWidth(IMAGE_W - 10)
	page.help:SetJustifyH("CENTER")
	page.help:SetText(L.CONTROLLER_HELP)

	frame.quickBind = ns.CreateButton(page, L.QB_BUTTON, 230, 30)
	frame.quickBind:SetPoint("TOP", page, "TOP", 0, SLOTS_TOP - IMAGE_H - 62)
	frame.quickBind:SetScript("OnClick", function()
		if ns.QuickBind then
			ns.QuickBind.Start()
		end
	end)

	page.qbHelp = page:CreateFontString(nil, "OVERLAY", ns.Font"GameFontDisableSmall")
	page.qbHelp:SetPoint("TOP", frame.quickBind, "BOTTOM", 0, -6)
	page.qbHelp:SetWidth(IMAGE_W - 10)
	page.qbHelp:SetJustifyH("CENTER")
	page.qbHelp:SetText(L.QB_SHORT_HELP)

	page.holdHint = page:CreateFontString(nil, "OVERLAY", ns.Font"GameFontDisableSmall")
	page.holdHint:SetPoint("TOP", page.qbHelp, "BOTTOM", 0, -10)
	page.holdHint:SetWidth(IMAGE_W - 10)
	page.holdHint:SetJustifyH("CENTER")
	page.holdHint:SetText(L.LAYER_HOLD_HINT)

	-- Holding a modifier on the controller (or keyboard) shows its layer while held.
	page.elapsed = 0
	page:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + (elapsed or 0)
		if self.elapsed < 0.05 then
			return
		end
		self.elapsed = 0
		local held = HeldPrefix(Profiles.Active())
		if held ~= heldPrefix then
			heldPrefix = held
			Config.RefreshController()
		end
	end)

	frame.slots = slots
	frame.markers = markers
	frame.layerButtons = layerButtons
end

-- index of the layer to display (the held one wins while a modifier is held)
local function DisplayedLayer()
	if heldPrefix ~= "" then
		for i, layer in ipairs(layers) do
			if layer.prefix == heldPrefix then
				return i
			end
		end
	end
	return currentLayer
end

local function FillSlot(s, profile, layer, locked)
	local b = s.button
	local mod = ModifierOf(profile, b.key)
	s.tooltipTitle, s.tooltipText, s.slot = nil, nil, nil
	if mod and layer.prefix ~= "" then
		-- the modifier itself is held in this layer
		s.bindingKey = nil
		s.isTap = false
		s.heldModifier = true
		s.text:SetText("|cff888888" .. L.SLOT_HELD .. "|r")
		s.sub:SetText(string.format(L.SLOT_HELD_SUB, mod))
		s.icon:Hide()
		s.tooltipTitle = b.label
		s.tooltipText = L.SLOT_HELD_TIP
		s:Disable()
		return
	end
	s.heldModifier = false
	local key = layer.prefix .. b.key
	local action = profile.bindings[key]
	s.bindingKey = key
	s.isTap = mod ~= nil
	local p = Config.ActionParts(action)
	local tap = s.isTap and (L.TAP .. " ") or ""
	if not p then
		s.text:SetText("|cff666666" .. L.NOT_ASSIGNED .. "|r")
		s.sub:SetText(tap)
		s.icon:Hide()
		s.tooltipTitle = Engine.KeyToCombo(key, profile)
		s.tooltipText = s.isTap and L.TAP_NOTE or L.NOT_ASSIGNED
	else
		if p.missing then
			s.text:SetText("|cffff8800" .. p.name .. "|r")
		elseif p.command then
			s.text:SetText("|cff99ccff" .. p.name .. "|r")
		elseif p.name then
			s.text:SetText(p.name)
		else
			s.text:SetText("|cff888888" .. L.EMPTY_SLOT .. "|r")
		end
		s.sub:SetText(tap .. p.where)
		if p.icon then
			pcall(s.icon.SetTexture, s.icon, p.icon)
			s.icon:Show()
		else
			s.icon:Hide()
		end
		s.slot = p.slot
		s.tooltipTitle = p.name or L.EMPTY_SLOT
		s.tooltipText = s.isTap and L.TAP_NOTE or p.where
	end
	if locked then
		s:Disable()
	else
		s:Enable()
	end
end

function Config.RefreshController()
	if not frame or not frame:IsShown() or not pages.controller then
		return
	end
	local profile = Profiles.Active()
	local locked = InCombatLockdown()
	layers = Config.BuildLayers(profile)
	if currentLayer > #layers then
		currentLayer = 1
	end
	local shownIndex = DisplayedLayer()
	local layer = layers[shownIndex]
	for i = 1, MAX_LAYERS do
		local b, data = layerButtons[i], layers[i]
		if data then
			b:SetText(data.label)
			ns.SetFlatSelected(b, i == shownIndex)
			b:Show()
		else
			b:Hide()
		end
	end
	for _, s in ipairs(slots) do
		FillSlot(s, profile, layer, locked)
	end
	if locked then
		frame.quickBind:Disable()
	else
		frame.quickBind:Enable()
	end
end

------------------------------------------------------------------------
-- Settings page (modifiers + profile, language, setup)
------------------------------------------------------------------------

local function BuildSettingsPage(page)
	local left = CreateFrame("Frame", nil, page)
	left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	left:SetSize(530, 400)
	if ns.ModifierPanel then
		ns.ModifierPanel.Build(left)
	end

	local x, w = 570, PAGE_W - 570
	local divider = page:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", page, "TOPLEFT", 548, 0)
	divider:SetSize(1, 380)
	divider:SetColorTexture(1, 1, 1, 0.1)

	ns.CreateHeading(page, L.SETTINGS_PROFILE, x, 0)
	page.profileText = ns.CreateText(page, "GameFontHighlight", x, -26, w)
	page.manageProfiles = ns.CreateButton(page, L.SETTINGS_MANAGE_PROFILES, 190, 24)
	page.manageProfiles:SetPoint("TOPLEFT", page, "TOPLEFT", x, -48)
	page.manageProfiles:SetScript("OnClick", function()
		if ns.ProfilesPanel then
			ns.ProfilesPanel.Open()
		end
	end)

	ns.CreateHeading(page, L.SETTINGS_LANGUAGE, x, -100)
	frame.language = ns.CreateButton(page, L.LANG_BUTTON, 140, 24)
	frame.language:SetPoint("TOPLEFT", page, "TOPLEFT", x, -126)
	frame.language:SetScript("OnClick", function()
		ns.SetLanguageSetting(ns.language == "csCZ" and "enUS" or "csCZ", true)
	end)
	local langNote = ns.CreateText(page, "GameFontDisableSmall", x, -156, w)
	langNote:SetText(L.LANG_TOOLTIP)

	ns.CreateHeading(page, L.SETTINGS_SETUP, x, -196)
	frame.setupButton = ns.CreateButton(page, L.SETUP_BUTTON, 190, 24)
	frame.setupButton:SetPoint("TOPLEFT", page, "TOPLEFT", x, -222)
	frame.setupButton:SetScript("OnClick", function()
		if ns.Wizard then
			frame:Hide()
			ns.Wizard.Open()
		end
	end)
	local setupNote = ns.CreateText(page, "GameFontDisableSmall", x, -252, w)
	setupNote:SetText(L.SETTINGS_SETUP_NOTE)

	ns.CreateHeading(page, L.CURSOR_HEADING, x, -284)
	local okCheck, check = pcall(CreateFrame, "CheckButton", nil, page, "UICheckButtonTemplate")
	if not okCheck or not check then
		check = CreateFrame("CheckButton", nil, page)
	end
	check:SetSize(26, 26)
	check:SetPoint("TOPLEFT", page, "TOPLEFT", x - 4, -306)
	check.label = ns.CreateText(page, "GameFontNormal", x + 26, -311, w - 26)
	check.label:SetText(L.CURSOR_KEEP_OFF)
	check:SetScript("OnClick", function(self)
		if InCombatLockdown() then
			self:SetChecked(Engine.KeepCursorOff())
			ns.Print(L.COMBAT_LOCKED)
			return
		end
		ns.db.keepCursorOff = self:GetChecked() and true or false
		Engine.Apply("cursor setting")
		Config.Refresh()
	end)
	check:SetScript("OnEnter", function(self)
		ns.ShowTextTooltip(self, L.CURSOR_KEEP_OFF, L.CURSOR_KEEP_OFF_DESC)
	end)
	check:SetScript("OnLeave", ns.HideTooltip)
	frame.cursorCheck = check
	page.cursorNote = ns.CreateText(page, "GameFontHighlightSmall", x, -336, w)

	function page:Refresh()
		self.profileText:SetText(string.format(L.PROFILES_ACTIVE, Profiles.ActiveName()))
		local keepOff = Engine.KeepCursorOff()
		frame.cursorCheck:SetChecked(keepOff)
		if keepOff then
			self.cursorNote:SetText(L.CURSOR_KEEP_OFF_DESC)
		else
			self.cursorNote:SetText(Config.CursorWarning() or L.CURSOR_ON_NOTE)
		end
		local locked = InCombatLockdown()
		for _, b in ipairs({ self.manageProfiles, frame.language, frame.setupButton, frame.cursorCheck }) do
			if locked then
				b:Disable()
			else
				b:Enable()
			end
		end
		if ns.ModifierPanel then
			ns.ModifierPanel.Refresh()
		end
	end
end

-- Warning when the game's gamepad cursor may take over modifier buttons (nil = no problem).
function Config.CursorWarning()
	if Engine.KeepCursorOff() then
		return nil
	end
	local profile = Profiles.Active()
	local names = {}
	for _, c in ipairs(Engine.CursorConflicts(profile)) do
		local b = ns.buttonByKey[c.key]
		names[#names + 1] = b and b.label or c.key
	end
	if #names == 0 then
		return nil
	end
	return string.format(L.CURSOR_CONFLICT, table.concat(names, ", "))
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------

local PAGES = {
	{ id = "controller", label = function() return L.PAGE_CONTROLLER end },
	{ id = "windows", label = function() return L.CTX_BUTTON end },
	{ id = "settings", label = function() return L.PAGE_SETTINGS end },
}

function Config.ShowPage(id)
	if not pages[id] then
		id = "controller"
	end
	currentPage = id
	for _, p in ipairs(PAGES) do
		local page = pages[p.id]
		if p.id == id then
			page:Show()
		else
			page:Hide()
		end
		ns.SetFlatSelected(pageTabs[p.id], p.id == id)
	end
	if id == "settings" and ns.ModifierPanel then
		ns.ModifierPanel.Reset()
	end
	Config.Refresh()
end

local function NewPage()
	local page = CreateFrame("Frame", nil, frame)
	page:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, PAGE_TOP)
	page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, PAGE_BOTTOM)
	page:Hide()
	return page
end

local function Create()
	frame = ns.CreatePanelFrame("CharacterControlPadConfigFrame", WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame.title:SetText(L.TITLE .. "  " .. ns.VERSION)

	-- page tabs + profile button
	for i, p in ipairs(PAGES) do
		local tab = ns.CreateFlatButton(frame, p.label(), 140, 28)
		tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + (i - 1) * 144, -30)
		tab:SetScript("OnClick", function()
			Config.ShowPage(p.id)
		end)
		pageTabs[p.id] = tab
	end
	frame.pageTabs = pageTabs

	frame.profileButton = ns.CreateButton(frame, "", 230, 24)
	frame.profileButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -32)
	frame.profileButton:SetScript("OnClick", function()
		if ns.ProfilesPanel then
			ns.ProfilesPanel.Open()
		end
	end)
	frame.profileButton:SetScript("OnEnter", function(self)
		ns.ShowTextTooltip(self, L.PROFILES_TITLE, L.PROFILE_BUTTON_TIP)
	end)
	frame.profileButton:SetScript("OnLeave", ns.HideTooltip)

	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -59)
	line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -59)
	line:SetHeight(1)
	line:SetColorTexture(1, 1, 1, 0.12)

	pages.controller = NewPage()
	BuildControllerPage(pages.controller)
	pages.windows = NewPage()
	if ns.ContextPanel then
		ns.ContextPanel.Build(pages.windows)
	end
	pages.settings = NewPage()
	BuildSettingsPage(pages.settings)
	frame.pages = pages

	-- footer
	local footerLine = frame:CreateTexture(nil, "ARTWORK")
	footerLine:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 50)
	footerLine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 50)
	footerLine:SetHeight(1)
	footerLine:SetColorTexture(1, 1, 1, 0.12)

	frame.compat = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	frame.compat:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 32)
	frame.compat:SetPoint("RIGHT", frame, "RIGHT", -140, 0)
	frame.compat:SetJustifyH("LEFT")

	frame.status = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
	frame.status:SetJustifyH("LEFT")

	frame.errors = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	frame.errors:SetPoint("LEFT", frame.status, "RIGHT", 16, 0)
	frame.errors:SetJustifyH("LEFT")

	frame.toggle = ns.CreateButton(frame, L.DISABLE, 120, 26)
	frame.toggle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
	frame.toggle:SetScript("OnClick", function()
		if InCombatLockdown() then
			ns.Print(L.COMBAT_LOCKED)
			return
		end
		ns.db.enabled = not ns.db.enabled
		Engine.Apply(ns.db.enabled and "enabled" or "disabled")
		Config.Refresh()
	end)

	frame:SetScript("OnShow", function()
		Config.ShowPage(currentPage)
	end)
	frame:SetScript("OnHide", function()
		heldPrefix = ""
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
	frame.profileButton:SetText(string.format(L.PROFILE_BUTTON, Profiles.ActiveName()))

	local errorCount = 0
	for _, list in ipairs({ s and s.errors, s and s.conflicts }) do
		if type(list) == "table" then
			for _ in pairs(list) do
				errorCount = errorCount + 1
			end
		end
	end
	frame.errors:SetText(errorCount > 0 and string.format(L.ERRORS, errorCount) or "")
	local notes = {}
	local compat = ns.Compat and ns.Compat.Summary() or ""
	if compat ~= "" then
		notes[#notes + 1] = compat
	end
	local cursorWarning = Config.CursorWarning()
	if cursorWarning then
		notes[#notes + 1] = cursorWarning
	end
	frame.compat:SetText(table.concat(notes, "  "))
	frame.toggle:SetText(ns.db.enabled and L.DISABLE or L.ENABLE)
	for _, b in ipairs({ frame.toggle, frame.profileButton }) do
		if locked then
			b:Disable()
		else
			b:Enable()
		end
	end

	if currentPage == "controller" then
		Config.RefreshController()
	elseif currentPage == "settings" then
		pages.settings:Refresh()
	elseif currentPage == "windows" and ns.ContextPanel then
		ns.ContextPanel.Refresh()
	end
end

------------------------------------------------------------------------
-- Open / close
------------------------------------------------------------------------

function Config.Open(page)
	if not frame then
		Create()
	end
	if page then
		currentPage = page
	end
	if frame:IsShown() then
		Config.ShowPage(currentPage)
	else
		frame:Show()
	end
end

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

ns.RegisterCommand("config", "open the configuration window (same as /ccp)", Config.Toggle)

-- Entry in the addon compartment menu next to the minimap (## AddonCompartmentFunc in the TOC).
function CharacterControlPad_OnAddonCompartmentClick()
	Config.Toggle()
end
