-- ForeverPad - profiles panel
-- List of profiles (click = use on this character), name box and actions:
-- new empty, new from template, copy active, rename active, clear all bindings, delete active.
-- Destructive actions (clear, delete) need a second click to confirm.

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Panel = {}
ns.ProfilesPanel = Panel

local WIDTH, HEIGHT = 380, 500
local MAX_LIST = 10

local frame
local listButtons = {}
local actionButtons = {}
local confirming -- button awaiting a second click

local function Trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function SetMessage(text)
	frame.message:SetText(text or "")
end

local function ResetConfirm()
	if confirming then
		confirming:SetText(confirming.baseText)
		confirming = nil
	end
end

local function AfterChange(ok, err)
	if not ok then
		SetMessage("|cffff4444" .. tostring(err) .. "|r")
		Panel.Refresh()
		return
	end
	Engine.Apply("profiles panel")
	if ns.Config then
		ns.Config.Refresh()
	end
	SetMessage(L.PROFILES_DONE)
	Panel.Refresh()
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------

function Panel.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local active = Profiles.ActiveName()
	frame.active:SetText(string.format(L.PROFILES_ACTIVE, active))
	local names = Profiles.List()
	for i = 1, MAX_LIST do
		local b, name = listButtons[i], names[i]
		if name then
			b.profileName = name
			b:SetText(string.format(L.PROFILES_USED_BY, name, Profiles.CountCharacters(name)))
			if name == active then
				b:LockHighlight()
			else
				b:UnlockHighlight()
			end
			b:Show()
		else
			b:Hide()
		end
	end
	if #names > MAX_LIST then
		frame.more:SetText(string.format(L.PROFILES_MORE, #names - MAX_LIST))
	else
		frame.more:SetText("")
	end
	local locked = InCombatLockdown()
	for _, b in ipairs(actionButtons) do
		if locked then
			b:Disable()
		else
			b:Enable()
		end
	end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

local function NameOrWarn()
	local name = Trim(frame.nameBox:GetText())
	if name == "" then
		SetMessage(L.PROFILES_NEED_NAME)
		return nil
	end
	return name
end

local function CreateAndUse(source)
	local name = NameOrWarn()
	if not name then
		return
	end
	local ok, err = Profiles.Create(name, source)
	if ok then
		ok, err = Profiles.Use(name)
		frame.nameBox:SetText("")
	end
	AfterChange(ok, err)
end

local ACTIONS = {
	{ text = function() return L.PROFILES_NEW_EMPTY end, run = function() CreateAndUse("empty") end },
	{ text = function() return L.PROFILES_NEW_TEMPLATE end, run = function() CreateAndUse("template") end },
	{ text = function() return L.PROFILES_COPY end, run = function() CreateAndUse(Profiles.ActiveName()) end },
	{
		text = function() return L.PROFILES_RENAME end,
		run = function()
			local name = NameOrWarn()
			if name then
				local ok, err = Profiles.Rename(Profiles.ActiveName(), name)
				if ok then
					frame.nameBox:SetText("")
				end
				AfterChange(ok, err)
			end
		end,
	},
	{
		text = function() return L.PROFILES_RESET_EMPTY end,
		confirm = true,
		run = function()
			Profiles.Active().bindings = {}
			AfterChange(true)
		end,
	},
	{
		text = function() return L.PROFILES_DELETE end,
		confirm = true,
		run = function()
			AfterChange(Profiles.Delete(Profiles.ActiveName()))
		end,
	},
}

local function RunAction(button, action)
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if action.confirm and confirming ~= button then
		ResetConfirm()
		confirming = button
		button:SetText(L.PROFILES_CONFIRM)
		return
	end
	ResetConfirm()
	action.run()
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------

local function Create()
	frame = ns.CreatePanelFrame("ForeverPadProfilesPanel", WIDTH, HEIGHT)
	ns.RegisterSidePanel(frame)
	frame.title:SetText(L.PROFILES_TITLE)
	frame:HookScript("OnHide", ResetConfirm)

	frame.active = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlight")
	frame.active:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)

	local listLabel = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormalSmall")
	listLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -54)
	listLabel:SetText(L.PROFILES_LIST)

	for i = 1, MAX_LIST do
		local b = ns.CreateButton(frame, "", WIDTH - 32, 22)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -70 - (i - 1) * 24)
		b:SetScript("OnClick", function(self)
			if InCombatLockdown() then
				ns.Print(L.COMBAT_LOCKED)
				return
			end
			ResetConfirm()
			AfterChange(Profiles.Use(self.profileName))
		end)
		listButtons[i] = b
	end

	frame.more = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontDisableSmall")
	frame.more:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -312)

	local nameLabel = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormalSmall")
	nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -330)
	nameLabel:SetText(L.PROFILES_NAME)

	frame.nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
	frame.nameBox:SetSize(WIDTH - 40, 20)
	frame.nameBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -346)
	frame.nameBox:SetAutoFocus(false)
	if ns.HasCustomFonts() then
		frame.nameBox:SetFontObject(ns.Font("ChatFontNormal"))
	end
	frame.nameBox:SetMaxLetters(32)
	frame.nameBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	frame.nameBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)

	local half = (WIDTH - 36) / 2
	for i, action in ipairs(ACTIONS) do
		local b = ns.CreateButton(frame, action.text(), half, 22)
		b.baseText = action.text()
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + col * (half + 4), -378 - row * 26)
		b:SetScript("OnClick", function(self)
			RunAction(self, action)
		end)
		actionButtons[#actionButtons + 1] = b
	end

	frame.message = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	frame.message:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
	frame.message:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
	frame.message:SetJustifyH("LEFT")
end

function Panel.Open()
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if not frame then
		Create()
	end
	SetMessage("")
	ResetConfirm()
	ns.OpenSidePanel(frame)
	Panel.Refresh()
end
