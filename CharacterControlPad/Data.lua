-- CharacterControlPad - static data
-- DualSense buttons (confirmed in game with /ccp debug identify),
-- Blizzard action bars (CONFIRMED in Blizzard_ActionBar/Shared/MultiActionBars.xml, forever branch),
-- command catalog and the default profile.

local _, ns = ...

------------------------------------------------------------------------
-- DualSense buttons: internal id, client binding key, display label
------------------------------------------------------------------------

-- short = compact label for overlays on action buttons (ASCII only, default fonts lack PS glyphs)
ns.BUTTONS = {
	{ id = "CROSS", key = "PAD1", label = "Cross", short = "X" },
	{ id = "CIRCLE", key = "PAD2", label = "Circle", short = "O" },
	{ id = "SQUARE", key = "PAD3", label = "Square", short = "Sq" },
	{ id = "TRIANGLE", key = "PAD4", label = "Triangle", short = "Tri" },
	{ id = "L1", key = "PADLSHOULDER", label = "L1", short = "L1" },
	{ id = "R1", key = "PADRSHOULDER", label = "R1", short = "R1" },
	{ id = "L2", key = "PADLTRIGGER", label = "L2", short = "L2" },
	{ id = "R2", key = "PADRTRIGGER", label = "R2", short = "R2" },
	{ id = "L3", key = "PADLSTICK", label = "L3", short = "L3" },
	{ id = "R3", key = "PADRSTICK", label = "R3", short = "R3" },
	{ id = "DPAD_UP", key = "PADDUP", label = "D-pad Up", short = "Up" },
	{ id = "DPAD_DOWN", key = "PADDDOWN", label = "D-pad Down", short = "Down" },
	{ id = "DPAD_LEFT", key = "PADDLEFT", label = "D-pad Left", short = "Left" },
	{ id = "DPAD_RIGHT", key = "PADDRIGHT", label = "D-pad Right", short = "Right" },
	{ id = "CREATE", key = "PADSOCIAL", label = "Create", short = "Crt" },
	{ id = "OPTIONS", key = "PADFORWARD", label = "Options", short = "Opt" },
	{ id = "PS", key = "PADSYSTEM", label = "PS", short = "PS", configurable = false }, -- system button, not offered
	{ id = "TOUCHPAD", key = "PADBACK", label = "Touchpad", short = "Pad" },
	{ id = "MUTE", key = "PAD5", label = "Mute", short = "Mute" },
}

ns.buttonById = {}
ns.buttonByKey = {}
for _, b in ipairs(ns.BUTTONS) do
	ns.buttonById[b.id] = b
	ns.buttonByKey[b.key] = b
end

-- Extra spellings accepted in slash commands (compared after lowercasing and stripping non-alphanumerics).
local BUTTON_ALIASES = {
	x = "CROSS", o = "CIRCLE",
	up = "DPAD_UP", down = "DPAD_DOWN", left = "DPAD_LEFT", right = "DPAD_RIGHT",
	dup = "DPAD_UP", ddown = "DPAD_DOWN", dleft = "DPAD_LEFT", dright = "DPAD_RIGHT",
	share = "CREATE", start = "OPTIONS", menu = "OPTIONS", pad = "TOUCHPAD", tp = "TOUCHPAD",
}

local function Normalize(text)
	return (tostring(text or ""):lower():gsub("[^%w]", ""))
end

function ns.FindButton(text)
	local n = Normalize(text)
	if n == "" then
		return nil
	end
	if BUTTON_ALIASES[n] then
		return ns.buttonById[BUTTON_ALIASES[n]]
	end
	for _, b in ipairs(ns.BUTTONS) do
		if Normalize(b.id) == n or Normalize(b.label) == n or Normalize(b.key) == n then
			return b
		end
	end
	return nil
end

------------------------------------------------------------------------
-- Modifiers: emulated by the client via GamePadEmulate* CVars
------------------------------------------------------------------------

-- Canonical WoW order inside binding strings: ALT-CTRL-SHIFT-
ns.MODIFIERS = {
	{ id = "ALT", cvar = "GamePadEmulateAlt" },
	{ id = "CTRL", cvar = "GamePadEmulateCtrl" },
	{ id = "SHIFT", cvar = "GamePadEmulateShift" },
}

------------------------------------------------------------------------
-- Blizzard action bars -> binding command prefix
------------------------------------------------------------------------

ns.BARS = {
	{ prefix = "ACTIONBUTTON", label = "Main bar", frame = "MainActionBar", buttonPrefix = "ActionButton" },
	{ prefix = "MULTIACTIONBAR1BUTTON", label = "Bottom left bar", frame = "MultiBarBottomLeft", buttonPrefix = "MultiBarBottomLeftButton", page = 6 },
	{ prefix = "MULTIACTIONBAR2BUTTON", label = "Bottom right bar", frame = "MultiBarBottomRight", buttonPrefix = "MultiBarBottomRightButton", page = 5 },
	{ prefix = "MULTIACTIONBAR3BUTTON", label = "Right bar 1", frame = "MultiBarRight", buttonPrefix = "MultiBarRightButton", page = 3 },
	{ prefix = "MULTIACTIONBAR4BUTTON", label = "Right bar 2", frame = "MultiBarLeft", buttonPrefix = "MultiBarLeftButton", page = 4 },
	{ prefix = "MULTIACTIONBAR5BUTTON", label = "Bar 6", frame = "MultiBar5", buttonPrefix = "MultiBar5Button", page = 13 },
	{ prefix = "MULTIACTIONBAR6BUTTON", label = "Bar 7", frame = "MultiBar6", buttonPrefix = "MultiBar6Button", page = 14 },
	{ prefix = "MULTIACTIONBAR7BUTTON", label = "Bar 8", frame = "MultiBar7", buttonPrefix = "MultiBar7Button", page = 15 },
}
ns.BAR_BUTTONS = 12

------------------------------------------------------------------------
-- Game / UI commands (Blizzard binding command names). Validity is checked at runtime
-- with C_KeyBindings.GetBindingIndex; invalid ones are reported, never bound.
------------------------------------------------------------------------

ns.COMMANDS = {
	{ command = "JUMP", label = "Jump", group = "game" },
	{ command = "TOGGLEAUTORUN", label = "Autorun", group = "game" },
	{ command = "INTERACTTARGET", label = "Interact", group = "game" },
	{ command = "TARGETNEARESTENEMY", label = "Target next enemy", group = "game" },
	{ command = "TARGETPREVIOUSENEMY", label = "Target previous enemy", group = "game" },
	{ command = "TARGETNEARESTFRIEND", label = "Target next friend", group = "game" },
	{ command = "TARGETSELF", label = "Target self", group = "game" },
	{ command = "ASSISTTARGET", label = "Assist target", group = "game" },
	{ command = "SITORSTAND", label = "Sit / stand", group = "game" },
	{ command = "TOGGLEGAMEMENU", label = "Game menu", group = "ui" },
	{ command = "TOGGLEWORLDMAP", label = "World map", group = "ui" },
	{ command = "OPENALLBAGS", label = "Bags", group = "ui" },
	{ command = "TOGGLEQUESTLOG", label = "Quest log", group = "ui" },
	{ command = "TOGGLECHARACTER0", label = "Character", group = "ui" },
	{ command = "TOGGLESPELLBOOK", label = "Spellbook", group = "ui" },
	{ command = "TOGGLESOCIAL", label = "Social", group = "ui" },
}

ns.commandLabel = {}
for _, c in ipairs(ns.COMMANDS) do
	ns.commandLabel[c.command] = c.label
end

------------------------------------------------------------------------
-- Default profile (starting point only; every entry can be changed with /ccp map)
-- L1 = SHIFT, R1 = CTRL (decided 2026-11-18). Keys are client binding strings.
------------------------------------------------------------------------

local function Bar(bar, button)
	return { type = "bar", bar = bar, button = button }
end

local function Cmd(command)
	return { type = "command", command = command }
end

function ns.CreateDefaultProfile()
	return {
		modifiers = { SHIFT = "PADLSHOULDER", CTRL = "PADRSHOULDER", ALT = "none" },
		bindings = {
			-- face buttons: 4 layers x 4 buttons = main bar 1-12 + bottom left bar 1-4
			["PAD1"] = Bar(1, 1), ["PAD2"] = Bar(1, 2), ["PAD3"] = Bar(1, 3), ["PAD4"] = Bar(1, 4),
			["SHIFT-PAD1"] = Bar(1, 5), ["SHIFT-PAD2"] = Bar(1, 6), ["SHIFT-PAD3"] = Bar(1, 7), ["SHIFT-PAD4"] = Bar(1, 8),
			["CTRL-PAD1"] = Bar(1, 9), ["CTRL-PAD2"] = Bar(1, 10), ["CTRL-PAD3"] = Bar(1, 11), ["CTRL-PAD4"] = Bar(1, 12),
			["CTRL-SHIFT-PAD1"] = Bar(2, 1), ["CTRL-SHIFT-PAD2"] = Bar(2, 2),
			["CTRL-SHIFT-PAD3"] = Bar(2, 3), ["CTRL-SHIFT-PAD4"] = Bar(2, 4),
			-- triggers: bottom left bar 5-12
			["PADLTRIGGER"] = Bar(2, 5), ["PADRTRIGGER"] = Bar(2, 6),
			["SHIFT-PADLTRIGGER"] = Bar(2, 7), ["SHIFT-PADRTRIGGER"] = Bar(2, 8),
			["CTRL-PADLTRIGGER"] = Bar(2, 9), ["CTRL-PADRTRIGGER"] = Bar(2, 10),
			["CTRL-SHIFT-PADLTRIGGER"] = Bar(2, 11), ["CTRL-SHIFT-PADRTRIGGER"] = Bar(2, 12),
			-- utility
			["PADDUP"] = Cmd("JUMP"),
			["PADDDOWN"] = Cmd("OPENALLBAGS"),
			["PADDLEFT"] = Cmd("TARGETPREVIOUSENEMY"),
			["PADDRIGHT"] = Cmd("TARGETNEARESTENEMY"),
			["PADLSTICK"] = Cmd("TOGGLEAUTORUN"),
			["PADRSTICK"] = Cmd("INTERACTTARGET"),
			["PADFORWARD"] = Cmd("TOGGLEGAMEMENU"),
			["PADBACK"] = Cmd("TOGGLEWORLDMAP"),
			["PADSOCIAL"] = Cmd("TOGGLECHARACTER0"),
		},
	}
end
