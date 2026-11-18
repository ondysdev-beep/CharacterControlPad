-- ForeverPad - compatibility with other addons
-- * ConsolePort binds controller buttons too -> reported as a conflict.
-- * Bar addons (Bartender4, Dominos, ElvUI) may replace the Blizzard bars -> hint: their buttons can be
--   bound in quick bind mode (hover them), stored as "click" actions (SetOverrideBindingClick).
-- Generic protection independent of this list: after every apply the engine checks with
-- GetBindingAction whether another addon took over a combo (state.conflicts).

local _, ns = ...

local L = ns.L

local Compat = {}
ns.Compat = Compat

local KNOWN = {
	{ addon = "ConsolePort", kind = "conflict" },
	{ addon = "Bartender4", kind = "bars" },
	{ addon = "Dominos", kind = "bars" },
	{ addon = "ElvUI", kind = "bars" },
}

local detected = {}

local function IsLoaded(name)
	local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	if type(fn) ~= "function" then
		return false
	end
	local ok, loaded = pcall(fn, name)
	return ok and loaded and true or false
end

function Compat.Detect()
	wipe(detected)
	for _, k in ipairs(KNOWN) do
		if IsLoaded(k.addon) then
			detected[#detected + 1] = k
		end
	end
	return detected
end

function Compat.Messages()
	local out = {}
	for _, k in ipairs(detected) do
		out[#out + 1] = string.format(k.kind == "conflict" and L.COMPAT_CONFLICT or L.COMPAT_BARS, k.addon)
	end
	return out
end

function Compat.Summary()
	return table.concat(Compat.Messages(), "\n")
end

ns.On("PLAYER_LOGIN", function()
	Compat.Detect()
	for _, msg in ipairs(Compat.Messages()) do
		ns.Print(msg)
	end
end)
