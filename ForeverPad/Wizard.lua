-- ForeverPad - first-run setup wizard
-- Shown once at login until finished or skipped (ForeverPadDB.setupDone); /fpad setup reopens it.
--   Step 1: modifier preset (L1+R1 recommended, L2+R2, L1+R1+L2, none)
--   Step 2: start empty (player assigns everything) or from the template layout
--   Done:   start quick bind / open settings / close
-- Applies to the active profile of this character.

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local Wizard = {}
ns.Wizard = Wizard

local WIDTH, HEIGHT = 480, 300

local PRESETS = {
	{ label = L.SETUP_MODS_L1R1, mods = { SHIFT = "PADLSHOULDER", CTRL = "PADRSHOULDER", ALT = "none" } },
	{ label = L.SETUP_MODS_L2R2, mods = { SHIFT = "PADLTRIGGER", CTRL = "PADRTRIGGER", ALT = "none" } },
	{ label = L.SETUP_MODS_THREE, mods = { SHIFT = "PADLSHOULDER", CTRL = "PADRSHOULDER", ALT = "PADLTRIGGER" } },
	{ label = L.SETUP_MODS_NONE, mods = { SHIFT = "none", CTRL = "none", ALT = "none" } },
}

local frame
local pages = {}
local chosenMods
local pendingShow = false

local function ShowPage(index)
	for i, page in ipairs(pages) do
		if i == index then
			if page.OnShowPage then
				page:OnShowPage()
			end
			page:Show()
		else
			page:Hide()
		end
	end
	frame.skip:SetShown(index < 3)
end

local function NewPage(text)
	local page = CreateFrame("Frame", nil, frame)
	page:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -30)
	page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 44)
	page.text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	page.text:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -4)
	page.text:SetPoint("RIGHT", page, "RIGHT", 0, 0)
	page.text:SetJustifyH("LEFT")
	page.text:SetText(text)
	page:Hide()
	pages[#pages + 1] = page
	return page
end

local function Finish(source)
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	local profile = Profiles.Active()
	profile.modifiers = ns.DeepCopy(chosenMods)
	if source == "empty" then
		profile.bindings = {}
	else
		profile.bindings = ns.CreateDefaultProfile().bindings
	end
	ns.db.setupDone = true
	Engine.Apply("setup wizard")
	if ns.Config then
		ns.Config.Refresh()
	end
	ShowPage(3)
end

local function Create()
	frame = ns.CreatePanelFrame("ForeverPadSetupWizard", WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame.title:SetText(L.SETUP_TITLE)

	-- Step 1: modifiers
	local p1 = NewPage(L.SETUP_STEP1)
	for i, preset in ipairs(PRESETS) do
		local b = ns.CreateButton(p1, preset.label, 300, 26)
		b:SetPoint("TOP", p1, "TOP", 0, -64 - (i - 1) * 32)
		b:SetScript("OnClick", function()
			chosenMods = preset.mods
			ShowPage(2)
		end)
	end

	-- Step 2: empty or template
	local p2 = NewPage(L.SETUP_STEP2)
	local empty = ns.CreateButton(p2, L.SETUP_EMPTY, 360, 28)
	empty:SetPoint("TOP", p2, "TOP", 0, -40)
	empty:SetScript("OnClick", function()
		Finish("empty")
	end)
	local template = ns.CreateButton(p2, L.SETUP_TEMPLATE, 360, 28)
	template:SetPoint("TOP", empty, "BOTTOM", 0, -8)
	template:SetScript("OnClick", function()
		Finish("template")
	end)
	p2.note = p2:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p2.note:SetPoint("TOP", template, "BOTTOM", 0, -16)
	function p2:OnShowPage()
		self.note:SetText(string.format(L.SETUP_REPLACES, Profiles.ActiveName()))
	end

	-- Done
	local p3 = NewPage(L.SETUP_DONE)
	local bind = ns.CreateButton(p3, L.SETUP_START_BIND, 200, 26)
	bind:SetPoint("TOP", p3, "TOP", 0, -64)
	bind:SetScript("OnClick", function()
		frame:Hide()
		if ns.QuickBind then
			ns.QuickBind.Start()
		end
	end)
	local open = ns.CreateButton(p3, L.SETUP_OPEN_CONFIG, 200, 26)
	open:SetPoint("TOP", bind, "BOTTOM", 0, -6)
	open:SetScript("OnClick", function()
		frame:Hide()
		if ns.Config and not (ns.Config.frame and ns.Config.frame:IsShown()) then
			ns.Config.Toggle()
		end
	end)
	local close = ns.CreateButton(p3, L.SETUP_CLOSE, 200, 26)
	close:SetPoint("TOP", open, "BOTTOM", 0, -6)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.skip = ns.CreateButton(frame, L.SETUP_SKIP, 90)
	frame.skip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 14)
	frame.skip:SetScript("OnClick", function()
		ns.db.setupDone = true
		frame:Hide()
	end)
end

function Wizard.Open()
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if not frame then
		Create()
	end
	chosenMods = PRESETS[1].mods
	ShowPage(1)
	frame:Show()
end

ns.On("PLAYER_LOGIN", function()
	if ns.db.setupDone then
		return
	end
	if InCombatLockdown() then
		pendingShow = true
	else
		Wizard.Open()
	end
end)

ns.On("PLAYER_REGEN_ENABLED", function()
	if pendingShow then
		pendingShow = false
		Wizard.Open()
	end
end)

ns.RegisterCommand("setup", "open the first-run setup wizard", Wizard.Open)
