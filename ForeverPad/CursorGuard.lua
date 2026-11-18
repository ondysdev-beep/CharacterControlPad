-- ForeverPad - gamepad cursor guard
-- Safety net for "the controller suddenly stops controlling the character": when the game's
-- gamepad cursor is on (stick moves the cursor, R1 / R2 click) and the mouse has not moved for a
-- few seconds, a short hint tells the player how to get back. Read-only: addons may not switch the
-- cursor themselves in WoW: Forever, the game turns it off on stick input or a jump
-- (GamePadCursorAutoDisableSticks / AutoDisableJump, kept on by BindingEngine).

local _, ns = ...

local L = ns.L

local Guard = {}
ns.CursorGuard = Guard

local IDLE_SECONDS = 2.5
local INTERVAL = 0.25

local frame = CreateFrame("Frame", "ForeverPadCursorGuard", UIParent)
frame:SetSize(520, 34)
frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
frame:SetFrameStrata("HIGH")
frame.hint = false

-- built on first use: the Czech font objects only exist after ADDON_LOADED
local built = false
local function Build()
	if built then
		return
	end
	built = true
	frame.bg = frame:CreateTexture(nil, "BACKGROUND")
	frame.bg:SetAllPoints(frame)
	frame.bg:SetColorTexture(0, 0, 0, 0.65)
	frame.text = frame:CreateFontString(nil, "OVERLAY", ns.Font"GameFontHighlight")
	frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame.text:SetWidth(500)
end

local elapsed, lastX, lastY, lastMove = 0, nil, nil, 0

local function CursorOn()
	if type(IsGamePadCursorControlEnabled) ~= "function" then
		return false
	end
	local ok, on = pcall(IsGamePadCursorControlEnabled)
	return ok and on == true
end

local function Active()
	local s = ns.db and ns.db.lastApply
	return ns.Engine and ns.Engine.KeepCursorOff() and s and s.status == "active"
end

local function ShowHint(on)
	if on == frame.hint then
		return
	end
	frame.hint = on
	Build()
	if on then
		frame.text:SetText(L.CURSOR_GUARD)
		frame.bg:Show()
		frame.text:Show()
	else
		frame.bg:Hide()
		frame.text:Hide()
	end
end

function Guard.Check()
	local now = GetTime()
	local okPos, x, y = pcall(GetCursorPosition)
	if okPos and (x ~= lastX or y ~= lastY) then
		lastX, lastY, lastMove = x, y, now
	end
	ShowHint(Active() and CursorOn() and (now - lastMove) >= IDLE_SECONDS or false)
end

frame:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + (delta or 0)
	if elapsed < INTERVAL then
		return
	end
	elapsed = 0
	Guard.Check()
end)

Guard.frame = frame
