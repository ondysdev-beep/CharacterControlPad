-- CharacterControlPad - quick bind mode ("hover a bar button, press a combo")
--
-- While active:
--   * a transparent overlay covers every *visible* Blizzard action button (anchored to it, so any
--     layout / scale / Edit Mode position works). Overlays swallow mouse clicks -> nothing is cast;
--   * a capture frame receives controller presses with input propagation OFF, so presses do not
--     reach the game either (verified mechanism: OnGamePadButtonDown + emulated modifier state);
--   * pressing a button/combo assigns it to the hovered bar button in the active profile;
--   * right-click on an overlay removes all combos pointing to that bar button.
-- Ends with Esc / Done / entering combat. Out of combat only (propagation is combat-restricted).
-- Blizzard frames are never modified; overlays are separate frames parented to UIParent.

local _, ns = ...

local L = ns.L
local Engine = ns.Engine
local Profiles = ns.Profiles

local QB = {}
ns.QuickBind = QB

local active = false
local overlays = {}      -- [bar * 100 + button] = overlay
local hovered
local capture, banner
local reopenConfig = false

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function IsVisible(f)
	if type(f) ~= "table" or type(f.IsVisible) ~= "function" then
		return false
	end
	local ok, visible = pcall(f.IsVisible, f)
	return ok and visible == true
end

local function BarButtonLabel(barIndex, n)
	local bar = ns.BARS[barIndex]
	return string.format("%s #%d", bar and bar.label or "?", n)
end

-- bar:button -> list of combo keys that point at it
local function ReverseMap(profile)
	local map = {}
	for key, action in pairs(profile.bindings) do
		local bar, button = type(action) == "table" and tonumber(action.bar), type(action) == "table" and tonumber(action.button)
		if bar and button and action.type == "bar" then
			local id = bar * 100 + button
			map[id] = map[id] or {}
			table.insert(map[id], key)
		end
	end
	for _, keys in pairs(map) do
		table.sort(keys, function(a, b)
			return #a < #b or (#a == #b and a < b)
		end)
	end
	return map
end

local function SetResult(text)
	if banner then
		banner.result:SetText(text or "")
	end
end

------------------------------------------------------------------------
-- Overlays
------------------------------------------------------------------------

local function ShowOverlayTooltip(self)
	local profile = Profiles.Active()
	local slot = Engine.SlotForBarButton(self.bar, self.button)
	ns.ShowActionTooltip(self, slot, BarButtonLabel(self.bar, self.button))
	local keys = ReverseMap(profile)[self.bar * 100 + self.button]
	if keys then
		local combos = {}
		for _, key in ipairs(keys) do
			combos[#combos + 1] = Engine.KeyToCombo(key, profile)
		end
		ns.GetTooltip():AddLine(string.format(L.QB_ASSIGNED_HERE, table.concat(combos, ", ")), 0.3, 0.8, 1)
	end
	ns.GetTooltip():AddLine(L.QB_TOOLTIP, 1, 0.82, 0)
	ns.GetTooltip():AddLine(L.QB_TOOLTIP_CLEAR, 0.7, 0.7, 0.7)
	ns.ShowTooltip()
end

local function GetOverlay(barIndex, n)
	local id = barIndex * 100 + n
	local o = overlays[id]
	if o then
		return o
	end
	o = CreateFrame("Button", nil, UIParent)
	o:SetFrameStrata("HIGH")
	o:RegisterForClicks("AnyUp")
	o.bg = o:CreateTexture(nil, "BACKGROUND")
	o.bg:SetAllPoints()
	o.hl = o:CreateTexture(nil, "HIGHLIGHT")
	o.hl:SetAllPoints()
	o.hl:SetColorTexture(1, 0.82, 0, 0.35)
	o.label = o:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	o.label:SetPoint("CENTER", o, "CENTER", 0, 0)
	o.bar, o.button = barIndex, n
	o:SetScript("OnEnter", function(self)
		hovered = self
		ShowOverlayTooltip(self)
	end)
	o:SetScript("OnLeave", function(self)
		if hovered == self then
			hovered = nil
		end
		ns.GetTooltip():Hide()
	end)
	o:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			QB.ClearBarButton(self.bar, self.button)
		end
	end)
	o:Hide()
	overlays[id] = o
	return o
end

local function LayoutOverlays()
	for _, o in pairs(overlays) do
		o:Hide()
	end
	if not active then
		return
	end
	local profile = Profiles.Active()
	local map = ReverseMap(profile)
	for barIndex, bar in ipairs(ns.BARS) do
		for n = 1, ns.BAR_BUTTONS do
			local btn = _G[bar.buttonPrefix .. n]
			if IsVisible(btn) then
				local o = GetOverlay(barIndex, n)
				o:ClearAllPoints()
				o:SetAllPoints(btn)
				local keys = map[barIndex * 100 + n]
				if keys then
					local combos = {}
					for i = 1, math.min(#keys, 2) do
						combos[#combos + 1] = Engine.KeyToCombo(keys[i], profile, true)
					end
					if #keys > 2 then
						combos[#combos + 1] = "+" .. (#keys - 2)
					end
					o.bg:SetColorTexture(0, 0.45, 1, 0.4)
					o.label:SetText(table.concat(combos, "\n"))
				else
					o.bg:SetColorTexture(0, 0, 0, 0.45)
					o.label:SetText("")
				end
				o:Show()
			end
		end
	end
	if hovered and hovered:IsShown() then
		ShowOverlayTooltip(hovered)
	end
end

------------------------------------------------------------------------
-- Buttons of other bar addons (no overlay; detected under the mouse cursor)
------------------------------------------------------------------------

local function FrameUnderMouse()
	if type(GetMouseFoci) == "function" then
		local ok, list = pcall(GetMouseFoci)
		if ok and type(list) == "table" then
			return list[1]
		end
	elseif type(GetMouseFocus) == "function" then
		local ok, f = pcall(GetMouseFocus)
		if ok then
			return f
		end
	end
	return nil
end

local function IsActionButtonFrame(frame)
	if Engine.SlotForFrame(frame) then
		return true
	end
	if type(frame.GetAttribute) == "function" then
		local ok, t = pcall(frame.GetAttribute, frame, "type")
		return ok and type(t) == "string" and t ~= ""
	end
	return false
end

-- Name of the action button under the mouse (walking up a few parents), or nil.
function QB.ForeignButtonUnderMouse()
	local frame = FrameUnderMouse()
	for _ = 1, 4 do
		if type(frame) ~= "table" then
			return nil
		end
		local okN, name = pcall(frame.GetName, frame)
		local okT, objectType = pcall(frame.GetObjectType, frame)
		if okN and type(name) == "string" and not name:find("^CharacterControlPad")
			and okT and (objectType == "Button" or objectType == "CheckButton")
			and IsActionButtonFrame(frame) then
			return name
		end
		local okP, parent = pcall(frame.GetParent, frame)
		frame = okP and parent or nil
	end
	return nil
end

------------------------------------------------------------------------
-- Editing
------------------------------------------------------------------------

local function AfterChange()
	Engine.Apply("quick bind")
	LayoutOverlays()
	if ns.Config then
		ns.Config.Refresh()
	end
end

function QB.ClearBarButton(barIndex, n)
	if InCombatLockdown() then
		return
	end
	local profile = Profiles.Active()
	local keys = ReverseMap(profile)[barIndex * 100 + n]
	if not keys then
		SetResult(string.format(L.QB_NOTHING, BarButtonLabel(barIndex, n)))
		return
	end
	local combos = {}
	for _, key in ipairs(keys) do
		combos[#combos + 1] = Engine.KeyToCombo(key, profile)
		profile.bindings[key] = nil
	end
	SetResult(string.format(L.QB_CLEARED, BarButtonLabel(barIndex, n), table.concat(combos, ", ")))
	AfterChange()
end

function QB.OnPadButton(button)
	if not active or InCombatLockdown() then
		return
	end
	local b = ns.buttonByKey[button]
	if not b or b.configurable == false then
		return
	end
	local action
	if hovered then
		action = { type = "bar", bar = hovered.bar, button = hovered.button }
	else
		-- Not over a Blizzard button: maybe over a button of a bar addon (Bartender4, Dominos, ElvUI ...).
		local name = QB.ForeignButtonUnderMouse()
		if name then
			action = { type = "click", button = name }
		end
	end
	if not action then
		SetResult(L.QB_HOVER_FIRST)
		return
	end
	local profile = Profiles.Active()
	-- Emulated modifiers (L1/R1 ...) set the normal modifier state; canonical order ALT-CTRL-SHIFT-.
	local prefix = ""
	if IsAltKeyDown() then prefix = prefix .. "ALT-" end
	if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
	if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
	if prefix ~= "" and Engine.IsModifierButton(profile, button) then
		SetResult(L.QB_MOD_ON_MOD)
		return
	end

	local key = prefix .. button
	local old = profile.bindings[key]
	profile.bindings[key] = action

	local text = string.format(L.QB_ASSIGNED, Engine.KeyToCombo(key, profile), (ns.Config.ActionInfo(action)))
	local sameAsBefore = old and old.type == action.type
		and tostring(old.bar) == tostring(action.bar) and tostring(old.button) == tostring(action.button)
	if old and not sameAsBefore then
		text = text .. string.format(L.QB_MOVED, (ns.Config.ActionInfo(old)))
	end
	SetResult(text)
	AfterChange()
end

------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------

local function EnsureFrames()
	if capture then
		return
	end
	capture = CreateFrame("Frame", "CharacterControlPadQuickBindCapture", UIParent)
	capture:SetSize(1, 1)
	capture:SetPoint("TOPLEFT")
	capture:Hide()
	capture:SetScript("OnGamePadButtonDown", function(_, button)
		QB.OnPadButton(button)
	end)

	banner = ns.CreatePanelFrame("CharacterControlPadQuickBindBanner", 580, 104)
	banner:SetPoint("TOP", UIParent, "TOP", 0, -90)
	banner.title:SetText(L.QB_TITLE)
	banner.help = banner:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlightSmall")
	banner.help:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -30)
	banner.help:SetPoint("RIGHT", banner, "RIGHT", -110, 0)
	banner.help:SetJustifyH("LEFT")
	banner.help:SetText(L.QB_HELP)
	banner.result = banner:CreateFontString(nil, "OVERLAY", ns.Font"GameFontNormal")
	banner.result:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 14, 14)
	banner.result:SetPoint("RIGHT", banner, "RIGHT", -110, 0)
	banner.result:SetJustifyH("LEFT")
	banner.result:SetWordWrap(false)
	local done = ns.CreateButton(banner, L.QB_DONE, 90)
	done:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -14, 12)
	done:SetScript("OnClick", function()
		QB.Stop()
	end)
	banner:SetScript("OnHide", function()
		QB.Stop() -- Esc (UISpecialFrames) hides the banner
	end)
end

------------------------------------------------------------------------
-- Start / stop
------------------------------------------------------------------------

function QB.IsActive()
	return active
end

function QB.Start()
	if active then
		return
	end
	if InCombatLockdown() then
		ns.Print(L.COMBAT_LOCKED)
		return
	end
	if ns.StopListening then
		ns.StopListening()
	end
	if ns.Picker then
		ns.Picker.Hide()
	end
	EnsureFrames()

	local config = ns.Config and ns.Config.frame
	reopenConfig = config and config:IsShown() or false
	if reopenConfig then
		config:Hide()
	end

	pcall(capture.EnableGamePadButton, capture, true)
	pcall(capture.SetPropagateKeyboardInput, capture, false)
	capture:Show()

	active = true
	hovered = nil
	SetResult("")
	banner:Show()
	LayoutOverlays()
end

function QB.Stop()
	if not active then
		return
	end
	active = false
	hovered = nil
	-- Hiding is enough to stop receiving input and is allowed even in combat.
	pcall(capture.EnableGamePadButton, capture, false)
	capture:Hide()
	LayoutOverlays() -- hides all overlays (active = false)
	ns.GetTooltip():Hide()
	if banner:IsShown() then
		banner:Hide()
	end
	if reopenConfig and ns.Config and ns.Config.frame then
		ns.Config.frame:Show()
	end
	reopenConfig = false
end

function QB.Toggle()
	if active then
		QB.Stop()
	else
		QB.Start()
	end
end

ns.On("PLAYER_REGEN_DISABLED", function()
	QB.Stop()
end)

local function RefreshIfActive()
	if active then
		LayoutOverlays()
	end
end
ns.On("ACTIONBAR_SLOT_CHANGED", RefreshIfActive)
ns.On("ACTIONBAR_PAGE_CHANGED", RefreshIfActive)
ns.On("UPDATE_BONUS_ACTIONBAR", RefreshIfActive)

ns.RegisterCommand("bind", "quick bind mode: hover a bar button, press a controller combo", QB.Toggle)
