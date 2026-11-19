-- CharacterControlPad - context controls panel (the "Windows" page of the settings window)
-- Switches the context layer (Context.lua) on/off as a whole, per window group, and its hint line.
-- Settings are account wide (CharacterControlPadDB.context) and take effect immediately (out of combat).

local _, ns = ...

local L = ns.L
local Context = ns.Context

local Panel = {}
ns.ContextPanel = Panel

local COLUMN = 414
local frame
local checks = {} -- id -> CheckButton ("enabled", "hints", or a group)

local function CreateCheck(parent, label, desc, x, y)
	local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
	if not ok or not cb then
		cb = CreateFrame("CheckButton", nil, parent)
	end
	cb:SetSize(26, 26)
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

	cb.label = parent:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormal")
	cb.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 30, y - 5)
	cb.label:SetText(label)

	if desc then
		cb.desc = parent:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
		cb.desc:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 30, y - 22)
		cb.desc:SetWidth(COLUMN - 50)
		cb.desc:SetJustifyH("LEFT")
		cb.desc:SetText(desc)
	end
	return cb
end

function Panel.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local s = Context.Settings()
	checks.enabled:SetChecked(s.enabled)
	checks.hints:SetChecked(s.hints)
	for _, b in ipairs(frame.confirmButtons) do
		ns.SetFlatSelected(b, b.key == s.confirm)
	end
	for _, group in ipairs(Context.GROUPS) do
		checks[group]:SetChecked(not s.off[group])
		if s.enabled then
			checks[group]:Enable()
		else
			checks[group]:Disable()
		end
	end
end

local function Changed()
	Context.Refresh()
	Panel.Refresh()
end

function Panel.Build(parent)
	frame = CreateFrame("Frame", "CharacterControlPadContextPanel", parent)
	frame:SetAllPoints(parent)

	frame.heading = ns.CreateHeading(frame, L.CTX_TITLE, 0, 0)
	local help = ns.CreateText(frame, "GameFontHighlightSmall", 0, -26, 2 * COLUMN - 10)
	help:SetText(L.CTX_HELP)

	checks.enabled = CreateCheck(frame, L.CTX_ENABLED, nil, 0, -64)
	checks.enabled:SetScript("OnClick", function(self)
		Context.Settings().enabled = self:GetChecked() and true or false
		Changed()
	end)

	checks.hints = CreateCheck(frame, L.CTX_HINTS, nil, COLUMN, -64)
	checks.hints:SetScript("OnClick", function(self)
		Context.Settings().hints = self:GetChecked() and true or false
		Changed()
	end)

	-- confirm button (use the selected item, take loot, confirm a quest option, place ...)
	local confirmLabel = ns.CreateText(frame, "GameFontNormal", 0, -100)
	confirmLabel:SetText(L.CTX_CONFIRM_LABEL)
	frame.confirmButtons = {}
	for i, key in ipairs(Context.CONFIRM_KEYS) do
		local b = ns.CreateFlatButton(frame, ns.buttonByKey[key].label, 110, 24)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 170 + (i - 1) * 114, -94)
		b.key = key
		b:SetScript("OnClick", function(self)
			Context.Settings().confirm = self.key
			Changed()
		end)
		frame.confirmButtons[i] = b
	end

	local divider = frame:CreateTexture(nil, "ARTWORK")
	divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -126)
	divider:SetSize(2 * COLUMN - 10, 1)
	divider:SetColorTexture(1, 1, 1, 0.1)

	for i, group in ipairs(Context.GROUPS) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local cb = CreateCheck(frame, Context.GroupLabel(group), L["CTX_DESC_" .. group:upper()], col * COLUMN, -132 - row * 48)
		cb:SetScript("OnClick", function(self)
			Context.Settings().off[group] = (not self:GetChecked()) or nil
			Changed()
		end)
		checks[group] = cb
	end

	local note = ns.CreateText(frame, "GameFontDisableSmall", 0, -378, 2 * COLUMN - 10)
	note:SetText(L.CTX_NOTE)

	frame:SetScript("OnShow", Panel.Refresh)
	return frame
end

function Panel.Open()
	if ns.Config then
		ns.Config.Open("windows")
	end
end
