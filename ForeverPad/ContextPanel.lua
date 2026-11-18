-- ForeverPad - context controls panel
-- Switches the context layer (Context.lua) on/off as a whole, per window group, and its hint line.
-- Settings are account wide (ForeverPadDB.context) and take effect immediately (out of combat).

local _, ns = ...

local L = ns.L
local Context = ns.Context

local Panel = {}
ns.ContextPanel = Panel

local WIDTH, HEIGHT = 470, 480
local frame
local checks = {} -- id -> CheckButton ("enabled", "hints", or a group)

local function CreateCheck(parent, label, desc, y)
	local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
	if not ok or not cb then
		cb = CreateFrame("CheckButton", nil, parent)
	end
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)

	cb.label = parent:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormal")
	cb.label:SetPoint("TOPLEFT", parent, "TOPLEFT", 42, y - 4)
	cb.label:SetText(label)

	if desc then
		cb.desc = parent:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
		cb.desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 42, y - 20)
		cb.desc:SetPoint("RIGHT", parent, "RIGHT", -14, 0)
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

local function Create()
	frame = ns.CreatePanelFrame("ForeverPadContextPanel", WIDTH, HEIGHT)
	ns.RegisterSidePanel(frame)
	frame.title:SetText(L.CTX_TITLE)

	local help = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)
	help:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	help:SetJustifyH("LEFT")
	help:SetText(L.CTX_HELP)

	checks.enabled = CreateCheck(frame, L.CTX_ENABLED, nil, -72)
	checks.enabled:SetScript("OnClick", function(self)
		Context.Settings().enabled = self:GetChecked() and true or false
		Changed()
	end)

	checks.hints = CreateCheck(frame, L.CTX_HINTS, nil, -98)
	checks.hints:SetScript("OnClick", function(self)
		Context.Settings().hints = self:GetChecked() and true or false
		Changed()
	end)

	for i, group in ipairs(Context.GROUPS) do
		local cb = CreateCheck(frame, Context.GroupLabel(group), L["CTX_DESC_" .. group:upper()], -132 - (i - 1) * 36)
		cb:SetScript("OnClick", function(self)
			Context.Settings().off[group] = (not self:GetChecked()) or nil
			Changed()
		end)
		checks[group] = cb
	end

	local note = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontDisableSmall")
	note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 44)
	note:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	note:SetJustifyH("LEFT")
	note:SetText(L.CTX_NOTE)

	local close = ns.CreateButton(frame, L.CLOSE, 100)
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame:SetScript("OnShow", Panel.Refresh)
end

function Panel.Open()
	if not frame then
		Create()
	end
	ns.OpenSidePanel(frame)
	Panel.Refresh()
end
