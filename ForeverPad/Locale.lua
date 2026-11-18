-- ForeverPad - localization (English + Czech)
--
-- Language: ForeverPadDB.language = "auto" (default) | "enUS" | "csCZ"
--   auto -> Czech when the Czech translation addon WowfCZ is enabled, otherwise English.
-- The default WoW font lacks Czech glyphs (WowfCZ ships its own font), so in Czech the addon's
-- own windows use the bundled Noto Sans (SIL OFL, Fonts/OFL.txt) through private font objects.
-- Blizzard font objects and the shared GameTooltip are never modified.
-- Slash command help and /fpad debug output stay English.

local _, ns = ...

local FONT_PATH = "Interface\\AddOns\\ForeverPad\\Fonts\\NotoSans-Regular.ttf"
ns.FONT_PATH = FONT_PATH

local enUS = {
	TITLE = "ForeverPad",
	CHANGE = "Change",
	NOT_ASSIGNED = "- not assigned -",
	TAP = "(tap)",
	EMPTY_SLOT = "empty slot",
	COMMAND = "command",
	LAYER_BASE = "No modifier",
	STATUS_LINE = "Profile: |cffffff00%s|r    Status: %s    Modifiers: %s",
	STATUS_ACTIVE = "|cff00ff00active|r",
	STATUS_PAUSED = "|cffff8800paused (Blizzard gamepad UI)|r",
	STATUS_DISABLED = "|cffff4444disabled|r",
	STATUS_COMBAT = "|cffff8800in combat - editing locked|r",
	MODIFIERS_NONE = "none",
	ENABLE = "Enable",
	DISABLE = "Disable",
	HINT = "Changes apply immediately. Hold a modifier on the controller to use its layer.",
	ERRORS = "|cffff4444%d binding(s) could not be applied - type /fpad list for details.|r",
	COMBAT_LOCKED = "Bindings cannot be changed in combat.",
	PICKER_TITLE = "Assign: %s",
	TAB_BARS = "Action bars",
	TAB_GAME = "Game commands",
	TAB_UI = "UI commands",
	CLEAR = "Clear",
	CANCEL = "Cancel",
	HIDDEN = "(hidden)",
	NOT_AVAILABLE = "Not available in this client.",
	BAR_SLOT = "%s #%d - action slot %d",
	TAP_NOTE = "Modifier button: fires only on a short tap.",
	BUTTON_NOT_FOUND = "button not found",

	-- compatibility
	COMPAT_CONFLICT = "|cffff4444%s is loaded - it also binds controller buttons. Use only one of the two addons.|r",
	COMPAT_BARS = "|cffff8800%s detected - if it replaces the Blizzard bars, use 'Bind on bars' and hover its buttons.|r",

	-- quick bind mode
	QB_BUTTON = "Bind on bars",
	QB_TITLE = "ForeverPad - quick bind",
	QB_HELP = "Hover an action button (Blizzard bars or another bar addon) and press a button or combo on the controller.\nRight-click a Blizzard bar button to remove its combos. Esc or Done to finish.",
	QB_DONE = "Done",
	QB_HOVER_FIRST = "|cffff8800Hover an action bar button with the mouse first.|r",
	QB_ASSIGNED = "|cff00ff00%s|r -> %s",
	QB_MOVED = "  (was: %s)",
	QB_CLEARED = "Removed from %s: %s",
	QB_NOTHING = "Nothing assigned to %s.",
	QB_TOOLTIP = "Press a controller button or combo to assign it here.",
	QB_TOOLTIP_CLEAR = "Right-click: remove all combos from this button.",
	QB_ASSIGNED_HERE = "Assigned: %s",
	QB_MOD_ON_MOD = "|cffff8800A modifier cannot be combined with another modifier.|r",

	-- modifiers panel
	MODS_BUTTON = "Modifiers",
	MODS_TITLE = "Modifier buttons",
	MODS_HELP = "Holding a modifier switches the controller to another layer of actions.\nEach button can be only one modifier.",
	MODS_LAYERS = "Layers: |cffffff00%d|r",
	MODS_TAP = "A modifier tapped shorter than %s ms triggers its own (tap) action.",
	MODS_REMOVED = "|cffff8800These bindings can no longer be reached and will be removed:|r %s",
	MODS_NOTHING_REMOVED = "No existing binding is affected.",
	APPLY = "Apply",

	-- profiles panel
	PROFILES_BUTTON = "Profiles",
	PROFILES_TITLE = "Profiles",
	PROFILES_ACTIVE = "This character uses: |cffffff00%s|r",
	PROFILES_LIST = "Click a profile to use it on this character:",
	PROFILES_USED_BY = "%s  |cff888888(%d char.)|r",
	PROFILES_NAME = "Name for new / renamed profile:",
	PROFILES_NEW_EMPTY = "New empty",
	PROFILES_NEW_TEMPLATE = "New from template",
	PROFILES_COPY = "Copy active",
	PROFILES_RENAME = "Rename active",
	PROFILES_RESET = "Reset active",
	PROFILES_DELETE = "Delete active",
	PROFILES_RESET_EMPTY = "Clear all bindings",
	PROFILES_CONFIRM = "Click again to confirm",
	PROFILES_NEED_NAME = "|cffff8800Type a name first.|r",
	PROFILES_DONE = "|cff00ff00Done.|r",
	PROFILES_MORE = "... and %d more (use /fpad profile use <name>)",

	-- setup wizard
	SETUP_BUTTON = "Setup wizard",
	SETUP_TITLE = "ForeverPad - first setup",
	SETUP_SKIP = "Skip",
	SETUP_STEP1 = "Step 1 of 2: which buttons should be modifiers?\nHolding a modifier switches to another layer of actions (L1+Cross, R1+Cross ...).",
	SETUP_MODS_L1R1 = "L1 + R1  (recommended)",
	SETUP_MODS_L2R2 = "L2 + R2",
	SETUP_MODS_THREE = "L1 + R1 + L2  (8 layers)",
	SETUP_MODS_NONE = "No modifiers",
	SETUP_STEP2 = "Step 2 of 2: how do you want to start?",
	SETUP_EMPTY = "Empty - I will assign everything myself",
	SETUP_TEMPLATE = "Template - start from a ready layout",
	SETUP_REPLACES = "|cff888888This sets profile '%s' for this character.|r",
	SETUP_DONE = "All set. Assign actions now: hover an action bar button and press a controller combo.",
	SETUP_START_BIND = "Start quick bind",
	SETUP_OPEN_CONFIG = "Open settings",
	SETUP_CLOSE = "Close",

	-- language
	LANG_BUTTON = "Čeština",
	LANG_TOOLTIP = "Switch the language to Czech (reloads the UI).",
	LANG_SET = "Language set to %s. Type /reload to apply.",

	-- engine chat messages
	ENGINE_ACTIVE = "Profile '%s' active: %d bindings%s. Modifiers: %s%s",
	ENGINE_ERRORS_SUFFIX = ", |cffff0000%d errors|r",
	ENGINE_INACTIVE = "Bindings %s. Profile '%s', interface style %s.%s",
	ENGINE_BIND_ERROR = "|cffff0000Binding %s not applied:|r %s",
	ENGINE_CONFLICT = "|cffff0000%s is overridden by another addon:|r %s",
	ENGINE_COMBAT_PENDING = "In combat - binding changes will be applied when combat ends.",
	STATE_DISABLED = "disabled",
	STATE_PAUSED = "paused (Blizzard gamepad UI)",
	LOGIN_HINT = "  |cff888888/fpad = settings|r",

	-- context controls (Context.lua, ContextPanel.lua)
	CTX_BUTTON = "Windows",
	CTX_TITLE = "Context controls",
	CTX_HELP = "While a game window is open, some buttons get a meaning that fits it. Your own bindings are not changed: when the window closes, the buttons work as before. Combos with modifiers (L1, R1 ...) are never affected.",
	CTX_ENABLED = "Enable context controls",
	CTX_HINTS = "Show button hints under the window",
	CTX_NOTE = "In combat the context controls are off and your own bindings apply (a Blizzard rule: bindings cannot change in combat).",
	CTX_SAVED = "Context controls updated.",
	CTX_GROUP_CLOSE = "Close windows",
	CTX_GROUP_POPUP = "Dialogs",
	CTX_GROUP_MERCHANT = "Merchant",
	CTX_GROUP_QUEST = "NPC dialog and quests",
	CTX_GROUP_LOOT = "Loot",
	CTX_GROUP_MAIL = "Mail",
	CTX_GROUP_BANK = "Bank",
	CTX_GROUP_TRAINER = "Trainer",
	CTX_DESC_CLOSE = "Circle closes open windows (bags, map, character ...), like Esc.",
	CTX_DESC_POPUP = "Confirmations, ready check, dungeon queue, invitations: Cross accepts, Circle declines.",
	CTX_DESC_MERCHANT = "Cross buys the item under the cursor, Square sells it from your bags, Triangle repairs all, Options sells junk.",
	CTX_DESC_QUEST = "D-pad Up / Down chooses an option, Cross accepts, continues or completes.",
	CTX_DESC_LOOT = "Cross loots everything.",
	CTX_DESC_MAIL = "Cross opens all mail.",
	CTX_DESC_BANK = "Square moves the item under the cursor between your bags and the bank.",
	CTX_DESC_TRAINER = "Cross learns the selected skill.",
	CTX_ACCEPT = "Accept",
	CTX_DECLINE = "Decline",
	CTX_CLOSE = "Close",
	CTX_LOOT_ALL = "Loot all",
	CTX_BUY = "Buy",
	CTX_BUY_HINT = "Buy (item under cursor)",
	CTX_SELL = "Sell",
	CTX_SELL_HINT = "Sell (item under cursor)",
	CTX_REPAIR = "Repair all",
	CTX_SELL_JUNK = "Sell junk",
	CTX_MOVE = "Move",
	CTX_MOVE_HINT = "Move item (under cursor)",
	CTX_OPEN_ALL = "Open all",
	CTX_TRAIN = "Learn",
	CTX_SELECT = "Confirm",
	CTX_CHOOSE = "Choose",
	CTX_DPAD = "D-pad",
	CLOSE = "Close",
}

local csCZ = {
	CHANGE = "Změnit",
	NOT_ASSIGNED = "- nepřiřazeno -",
	TAP = "(ťuknutí)",
	EMPTY_SLOT = "prázdný slot",
	COMMAND = "příkaz",
	LAYER_BASE = "Bez modifikátoru",
	STATUS_LINE = "Profil: |cffffff00%s|r    Stav: %s    Modifikátory: %s",
	STATUS_ACTIVE = "|cff00ff00aktivní|r",
	STATUS_PAUSED = "|cffff8800pozastaveno (Blizzard UI pro ovladač)|r",
	STATUS_DISABLED = "|cffff4444vypnuto|r",
	STATUS_COMBAT = "|cffff8800v boji - úpravy jsou zamčené|r",
	MODIFIERS_NONE = "žádné",
	ENABLE = "Zapnout",
	DISABLE = "Vypnout",
	HINT = "Změny platí okamžitě. Držením modifikátoru na ovladači přepneš na jeho vrstvu.",
	ERRORS = "|cffff4444Nepodařilo se použít %d bind(ů) - podrobnosti vypíše /fpad list.|r",
	COMBAT_LOCKED = "V boji nelze bindy měnit.",
	PICKER_TITLE = "Přiřadit: %s",
	TAB_BARS = "Action bary",
	TAB_GAME = "Herní příkazy",
	TAB_UI = "Okna rozhraní",
	CLEAR = "Smazat",
	CANCEL = "Zrušit",
	HIDDEN = "(skrytý)",
	NOT_AVAILABLE = "V tomto klientu není k dispozici.",
	BAR_SLOT = "%s #%d - slot %d",
	TAP_NOTE = "Tlačítko modifikátoru: spustí se jen krátkým ťuknutím.",
	BUTTON_NOT_FOUND = "tlačítko nenalezeno",

	COMPAT_CONFLICT = "|cffff4444Je načtený %s - také binduje tlačítka ovladače. Používej jen jeden z těch dvou addonů.|r",
	COMPAT_BARS = "|cffff8800Nalezen %s - pokud nahrazuje Blizzard bary, použij 'Přiřadit na barech' a najeď na jeho tlačítka.|r",

	QB_BUTTON = "Přiřadit na barech",
	QB_TITLE = "ForeverPad - rychlé přiřazení",
	QB_HELP = "Najeď myší na akční tlačítko (Blizzard bary nebo jiný bar addon) a zmáčkni tlačítko nebo kombinaci na ovladači.\nPravé tlačítko myši na Blizzard tlačítku smaže jeho kombinace. Esc nebo Hotovo režim ukončí.",
	QB_DONE = "Hotovo",
	QB_HOVER_FIRST = "|cffff8800Nejdřív najeď myší na akční tlačítko.|r",
	QB_MOVED = "  (předtím: %s)",
	QB_CLEARED = "Odebráno z %s: %s",
	QB_NOTHING = "Na %s není nic přiřazeno.",
	QB_TOOLTIP = "Zmáčkni tlačítko nebo kombinaci na ovladači a přiřadí se sem.",
	QB_TOOLTIP_CLEAR = "Pravé tlačítko myši: odebrat z tohoto tlačítka všechny kombinace.",
	QB_ASSIGNED_HERE = "Přiřazeno: %s",
	QB_MOD_ON_MOD = "|cffff8800Modifikátor nejde kombinovat s jiným modifikátorem.|r",

	MODS_BUTTON = "Modifikátory",
	MODS_TITLE = "Tlačítka modifikátorů",
	MODS_HELP = "Držením modifikátoru přepneš ovladač na jinou vrstvu akcí.\nKaždé tlačítko může být jen jeden modifikátor.",
	MODS_LAYERS = "Vrstvy: |cffffff00%d|r",
	MODS_TAP = "Modifikátor ťuknutý kratší dobu než %s ms spustí svou vlastní akci (ťuknutí).",
	MODS_REMOVED = "|cffff8800Na tyto bindy už ovladač nedosáhne, budou odstraněny:|r %s",
	MODS_NOTHING_REMOVED = "Žádný existující bind se nezmění.",
	APPLY = "Použít",

	PROFILES_BUTTON = "Profily",
	PROFILES_TITLE = "Profily",
	PROFILES_ACTIVE = "Tato postava používá: |cffffff00%s|r",
	PROFILES_LIST = "Kliknutím profil přiřadíš této postavě:",
	PROFILES_USED_BY = "%s  |cff888888(%d post.)|r",
	PROFILES_NAME = "Název nového / přejmenovaného profilu:",
	PROFILES_NEW_EMPTY = "Nový prázdný",
	PROFILES_NEW_TEMPLATE = "Nový ze šablony",
	PROFILES_COPY = "Kopírovat aktivní",
	PROFILES_RENAME = "Přejmenovat aktivní",
	PROFILES_RESET = "Resetovat aktivní",
	PROFILES_DELETE = "Smazat aktivní",
	PROFILES_RESET_EMPTY = "Smazat všechny bindy",
	PROFILES_CONFIRM = "Klikni znovu pro potvrzení",
	PROFILES_NEED_NAME = "|cffff8800Nejdřív napiš název.|r",
	PROFILES_DONE = "|cff00ff00Hotovo.|r",
	PROFILES_MORE = "... a dalších %d (/fpad profile use <název>)",

	SETUP_BUTTON = "Průvodce",
	SETUP_TITLE = "ForeverPad - první nastavení",
	SETUP_SKIP = "Přeskočit",
	SETUP_STEP1 = "Krok 1 ze 2: která tlačítka mají být modifikátory?\nDržením modifikátoru přepneš na jinou vrstvu akcí (L1+Křížek, R1+Křížek ...).",
	SETUP_MODS_L1R1 = "L1 + R1  (doporučeno)",
	SETUP_MODS_THREE = "L1 + R1 + L2  (8 vrstev)",
	SETUP_MODS_NONE = "Bez modifikátorů",
	SETUP_STEP2 = "Krok 2 ze 2: jak chceš začít?",
	SETUP_EMPTY = "Prázdné - všechno si přiřadím sám",
	SETUP_TEMPLATE = "Šablona - začít s hotovým rozložením",
	SETUP_REPLACES = "|cff888888Nastaví profil '%s' pro tuto postavu.|r",
	SETUP_DONE = "Hotovo. Teď přiřaď akce: najeď myší na tlačítko action baru a zmáčkni kombinaci na ovladači.",
	SETUP_START_BIND = "Spustit rychlé přiřazení",
	SETUP_OPEN_CONFIG = "Otevřít nastavení",
	SETUP_CLOSE = "Zavřít",

	LANG_BUTTON = "English",
	LANG_TOOLTIP = "Přepnout jazyk na angličtinu (znovu načte rozhraní).",
	LANG_SET = "Jazyk nastaven na %s. Pro použití napiš /reload.",

	ENGINE_ACTIVE = "Profil '%s' aktivní: %d bindů%s. Modifikátory: %s%s",
	ENGINE_ERRORS_SUFFIX = ", |cffff0000%d chyb|r",
	ENGINE_INACTIVE = "Bindy %s. Profil '%s', režim rozhraní %s.%s",
	ENGINE_BIND_ERROR = "|cffff0000Bind %s nebyl použit:|r %s",
	ENGINE_CONFLICT = "|cffff0000%s přebil jiný addon:|r %s",
	ENGINE_COMBAT_PENDING = "V boji - změny bindů se použijí po skončení boje.",
	STATE_DISABLED = "vypnuté",
	STATE_PAUSED = "pozastavené (Blizzard UI pro ovladač)",
	LOGIN_HINT = "  |cff888888/fpad = nastavení|r",

	CTX_BUTTON = "Okna",
	CTX_TITLE = "Kontextové ovládání",
	CTX_HELP = "Když je otevřené herní okno, některá tlačítka dostanou význam, který se k němu hodí. Tvoje bindy se nemění: po zavření okna tlačítka fungují jako dřív. Kombinací s modifikátory (L1, R1 ...) se to nikdy netýká.",
	CTX_ENABLED = "Zapnout kontextové ovládání",
	CTX_HINTS = "Zobrazit nápovědu tlačítek pod oknem",
	CTX_NOTE = "V boji je kontextové ovládání vypnuté a platí tvoje bindy (pravidlo Blizzardu: v boji nelze bindy měnit).",
	CTX_SAVED = "Kontextové ovládání upraveno.",
	CTX_GROUP_CLOSE = "Zavírání oken",
	CTX_GROUP_POPUP = "Potvrzovací okna",
	CTX_GROUP_MERCHANT = "Obchodník",
	CTX_GROUP_QUEST = "Rozhovor s NPC a questy",
	CTX_GROUP_LOOT = "Kořist",
	CTX_GROUP_MAIL = "Pošta",
	CTX_GROUP_BANK = "Banka",
	CTX_GROUP_TRAINER = "Trenér",
	CTX_DESC_CLOSE = "Kolečko zavře otevřená okna (batohy, mapu, postavu ...), stejně jako Esc.",
	CTX_DESC_POPUP = "Potvrzení, ready check, fronta do dungeonu, pozvánky: Křížek potvrdí, Kolečko odmítne.",
	CTX_DESC_MERCHANT = "Křížek koupí předmět pod kurzorem, Čtverec ho prodá z batohu, Trojúhelník opraví vše, Options prodá odpad.",
	CTX_DESC_QUEST = "D-pad nahoru / dolů vybírá možnost, Křížek přijme, pokračuje nebo dokončí.",
	CTX_DESC_LOOT = "Křížek sebere všechno.",
	CTX_DESC_MAIL = "Křížek otevře všechnu poštu.",
	CTX_DESC_BANK = "Čtverec přesune předmět pod kurzorem mezi batohem a bankou.",
	CTX_DESC_TRAINER = "Křížek naučí vybranou dovednost.",
	CTX_ACCEPT = "Potvrdit",
	CTX_DECLINE = "Odmítnout",
	CTX_CLOSE = "Zavřít",
	CTX_LOOT_ALL = "Sebrat vše",
	CTX_BUY = "Koupit",
	CTX_BUY_HINT = "Koupit (předmět pod kurzorem)",
	CTX_SELL = "Prodat",
	CTX_SELL_HINT = "Prodat (předmět pod kurzorem)",
	CTX_REPAIR = "Opravit vše",
	CTX_SELL_JUNK = "Prodat odpad",
	CTX_MOVE = "Přesunout",
	CTX_MOVE_HINT = "Přesunout (předmět pod kurzorem)",
	CTX_OPEN_ALL = "Otevřít vše",
	CTX_TRAIN = "Naučit",
	CTX_SELECT = "Potvrdit",
	CTX_CHOOSE = "Vybrat",
	CTX_DPAD = "D-pad",
	CLOSE = "Zavřít",

	-- data labels (Data.lua), applied by ApplyDataLocale
	BTN_CROSS = "Křížek", BTN_CIRCLE = "Kolečko", BTN_SQUARE = "Čtverec", BTN_TRIANGLE = "Trojúhelník",
	BTN_DPAD_UP = "D-pad nahoru", BTN_DPAD_DOWN = "D-pad dolů", BTN_DPAD_LEFT = "D-pad vlevo", BTN_DPAD_RIGHT = "D-pad vpravo",
	BAR_1 = "Hlavní bar", BAR_2 = "Spodní levý bar", BAR_3 = "Spodní pravý bar",
	BAR_4 = "Pravý bar 1", BAR_5 = "Pravý bar 2", BAR_6 = "Bar 6", BAR_7 = "Bar 7", BAR_8 = "Bar 8",
	CMD_JUMP = "Skok", CMD_TOGGLEAUTORUN = "Automatický běh", CMD_INTERACTTARGET = "Interakce",
	CMD_TARGETNEARESTENEMY = "Další nepřítel", CMD_TARGETPREVIOUSENEMY = "Předchozí nepřítel",
	CMD_TARGETNEARESTFRIEND = "Další spojenec", CMD_TARGETSELF = "Zaměřit sebe", CMD_ASSISTTARGET = "Asistovat cíli",
	CMD_SITORSTAND = "Sednout / vstát", CMD_TOGGLEGAMEMENU = "Herní menu", CMD_TOGGLEWORLDMAP = "Mapa světa",
	CMD_OPENALLBAGS = "Batohy", CMD_TOGGLEQUESTLOG = "Deník úkolů", CMD_TOGGLECHARACTER0 = "Postava",
	CMD_TOGGLESPELLBOOK = "Kniha kouzel", CMD_TOGGLESOCIAL = "Přátelé",
}

ns.LOCALES = { enUS = enUS, csCZ = csCZ }
ns.LANGUAGE_NAMES = { enUS = "English", csCZ = "Čeština" }

local current = enUS
ns.language = "enUS"

-- L.KEY -> current language, English fallback, then the key itself.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return current[key] or enUS[key] or key
	end,
})

------------------------------------------------------------------------
-- Fonts
------------------------------------------------------------------------

local FONT_BASES = {
	"GameFontNormal", "GameFontHighlight", "GameFontDisable",
	"GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall", "ChatFontNormal",
}
local customFonts = {}

-- Font object name to use for the addon's own font strings ("GameFontNormal" -> private copy in Czech).
function ns.Font(base)
	return customFonts[base] or base
end

function ns.HasCustomFonts()
	return next(customFonts) ~= nil
end

local function CreateCustomFonts()
	if type(CreateFont) ~= "function" then
		return
	end
	for _, base in ipairs(FONT_BASES) do
		local blizzard = _G[base]
		if type(blizzard) == "table" and type(blizzard.GetFont) == "function" then
			local name = "ForeverPad_" .. base
			local ok, created = pcall(function()
				local f = CreateFont(name)
				f:CopyFontObject(blizzard)
				local _, size, flags = blizzard:GetFont()
				return f:SetFont(FONT_PATH, size or 12, flags or "")
			end)
			-- SetFont returns false when the file cannot be loaded: keep the Blizzard font then.
			if ok and created ~= false then
				customFonts[base] = name
			end
		end
	end
end

------------------------------------------------------------------------
-- Language selection
------------------------------------------------------------------------

local function CzechAddonEnabled()
	local fn = C_AddOns and C_AddOns.GetAddOnEnableState
	if type(fn) ~= "function" then
		return false
	end
	local ok, state = pcall(fn, "WowfCZ", UnitName and UnitName("player") or nil)
	return ok and type(state) == "number" and state > 0
end

function ns.ResolveLanguage()
	local setting = ns.db and ns.db.language or "auto"
	if ns.LOCALES[setting] then
		return setting
	end
	return CzechAddonEnabled() and "csCZ" or "enUS"
end

local function ApplyDataLocale()
	if current == enUS then
		return
	end
	for _, b in ipairs(ns.BUTTONS or {}) do
		b.label = current["BTN_" .. b.id] or b.label
	end
	for i, bar in ipairs(ns.BARS or {}) do
		bar.label = current["BAR_" .. i] or bar.label
	end
	for _, c in ipairs(ns.COMMANDS or {}) do
		c.label = current["CMD_" .. c.command] or c.label
		if ns.commandLabel then
			ns.commandLabel[c.command] = c.label
		end
	end
end

-- Called once from Core at ADDON_LOADED (SavedVariables available, no UI built yet).
function ns.InitLocale()
	local lang = ns.ResolveLanguage()
	ns.language = lang
	current = ns.LOCALES[lang] or enUS
	if lang ~= "enUS" then
		CreateCustomFonts()
	end
	ApplyDataLocale()
end

function ns.SetLanguageSetting(setting, reload)
	ns.db.language = setting
	local name = ns.LANGUAGE_NAMES[setting] or "auto"
	if reload then
		local fn = (C_UI and C_UI.Reload) or ReloadUI
		if type(fn) == "function" and pcall(fn) then
			return
		end
	end
	ns.Printf(ns.L.LANG_SET, name)
end
