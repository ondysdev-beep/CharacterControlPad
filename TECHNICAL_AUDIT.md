# ForeverPad – Technický audit (Fáze 0)

**Datum:** 2026-11-18
**Stav:** Fáze 0–4 jsou ověřené ve hře (kapitoly 9 a 10). Fáze 5 a konfigurátor (v0.3–0.9.1) jsou hotové a otestované mimo hru (170+ testů, `npm test`). Čeká se na souhrnný test ve hře (kapitola 11).

Značení podle zadání:

- **CONFIRMED:** ověřeno v konkrétním klientovi (soubory instalace na tomto PC).
- **NOT CONFIRMED:** zatím neověřeno ve hře. U každé položky je uvedeno, z čeho vychází.
- **UNSUPPORTED:** klient nebo API danou věc nepodporuje.
- **BLOCKED:** existuje konkrétní technická překážka.

Silný, ale nepřímý důkaz je zdrojový kód Blizzard UI z větve `forever` repozitáře `Gethe/wow-ui-source`. Jde o extrakt kódu rozhraní, které běží ve Forever klientu. Tyto položky jsou vedené jako NOT CONFIRMED se zdrojem *[src]*, dokud je nepotvrdí diagnostika ve hře.

---

## 1. Shrnutí – co z auditu plyne

1. **WoW: Forever je moderní klient.** Je postavený na Midnight 12.1.5, ne na Classicu. Interface `16001`, game type `camelot`/`forever`. Platí v něm všechna omezení addonů z Midnightu (secret values, chráněné funkce, combat lockdown).
2. **Klient má vlastní podporu ovladače a dva režimy UI:**
   - `Mkb`: klasické Blizzard UI pro myš a klávesnici.
   - `Gamepad`: vlastní HUD pro ovladač s vlastními action bary.

   Mezi nimi se přepíná událostí `INPUT_DEVICE_INTERFACE_TRANSITION`.
3. **Režim `Gamepad` nepoužívá běžné action bary.** Jeho bary mají vlastní úložiště slotů (`C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()`) a zapíná zvláštní binding kontext `GamepadModeInGameCore`. Podle dostupných informací jsou v něm bindingy tlačítek pevné. *[src + web]*
4. **ForeverPad má proto smysl jako vrstva bindingů v režimu `Mkb`.** Původní Blizzard UI a bary zůstanou, ovladač se na ně jen namapuje. To přesně odpovídá vizi ze zadání a nativní režim Blizzardu tuhle potřebu nepokrývá.
5. **Akce musí vykonávat binding systém, ne Lua kód addonu.** Addon smí jen mimo boj nastavit override bindingy, například `SHIFT-PAD1 → ACTIONBUTTON5`. Stisk pak obslouží klient. Modifikátory řeší CVary `GamePadEmulateShift/Ctrl/Alt`. Tok „event → Lua → spuštění akce“ ze zadání (kap. 11) **není možný**, protože `UseAction` je chráněná funkce.
6. **Klíčová otevřená otázka:** posílá klient v režimu `Mkb` stisky ovladače do běžných bindingů (`PAD1`, `SHIFT-PAD1`, …), nebo jen v režimu `Gamepad`? Na tom stojí celý projekt. v0.1 potvrdila, že v Mkb nejsou žádné `PAD*` bindingy a emulované modifikátory fungují. Definitivně odpoví proof of concept v kapitole 10.
7. **ConsolePort už pro Forever existuje** (verze 3.3.0, interim release). Viz kapitola 6.

---

## 2. Prostředí – CONFIRMED (soubory na disku)

| Položka | Hodnota | Zdroj |
|---|---|---|
| Instalace | `C:\Program Files (x86)\World of Warcraft\_forever_\` | adresář |
| Produkt | `wowf` (flavor) | `_forever_\.flavor.info`, `.build.info` |
| Verze klienta | **1.60.1.70938**, region EU, jazyk enUS | `.build.info` |
| Složka addonů | `_forever_\Interface\AddOns\` | adresář (nainstalované addony) |
| Interface v TOC | **16001** | TOC všech nainstalovaných Forever addonů |
| Game type pro TOC | `camelot` (např. `[AllowLoadGameType camelot]`) | `WhatsTraining.toc` |
| Gamepad CVary existují | `GamePadEmulateCtrl`, `GamePadCursorLeftClick/RightClick`, `GamePadTurnWithCamera`, `GamePadOverlapMouseMs`, `GamePadFaceMovementMaxAngleCombat` | `WTF\Config.wtf` |
| **Aktuálně R2 = Ctrl** | `GamePadEmulateCtrl "PADRTRIGGER"` | `WTF\Config.wtf` |
| Konfigurace ovladače | `GamePadConfig_Default.json`, `GamePadConfig_Addons.json` (configVersion 4), `gamecontrollerdb.txt` | `WTF\` |
| Styl ikon tlačítek | `labelStyle: "Shapes"` (PlayStation symboly) | `GamePadConfig_Addons.json` |
| Názvy tlačítek pro bindingy | `PAD1–PAD6`, `PADDUP/DOWN/LEFT/RIGHT`, `PADLSHOULDER/RSHOULDER`, `PADLTRIGGER/RTRIGGER`, `PADLSTICK/RSTICK`, směry páček `PADLSTICKUP…`, `PADPADDLE1–4`, `PADFORWARD`, `PADBACK`, `PADSYSTEM`, `PADSOCIAL` | `GamePadConfig_Default.json` |
| Osy / páčky | `LStick`, `RStick`, `LTrigger`, `RTrigger`, **`Gyro`**, **`Pad`** (touchpad) | `GamePadConfig_Default.json` |

Poznámka: přesné přiřazení fyzických tlačítek DualSense k `PAD1…PADSOCIAL` (např. Cross = `PAD1`?) je **NOT CONFIRMED**. Zjistí ho test A.

---

## 3. API – stav ověření

### 3.1 Gamepad API (`C_GamePad`)

**NOT CONFIRMED** *[src: `GamePadDocumentation.lua`, větev forever]*. Funkce:

`IsEnabled`, `GetActiveDeviceID`, `GetAllDeviceIDs`, `GetCombinedDeviceID`, `GetDeviceMappedState`, `GetDeviceRawState`, `GetPowerLevel`, `ButtonBindingToIndex`, `ButtonIndexToBinding`, `ButtonIndexToConfigName`, `AxisIndexToConfigName`, `StickIndexToConfigName`, `GetConfig`, `GetAllConfigIDs`, `SetLedColor`, `GetLedColor`, `ClearLedColor`, `SetVibration`, `StopVibration`, `GetAllowHoverEventsWithFreeLook`, `SetAllowHoverEventsWithFreeLook`.

Funkce s omezením (`HasRestrictions`): `SetConfig`, `DeleteConfig`, `ApplyConfigs`, `AddSDLMapping`.

Události: `GAME_PAD_CONNECTED`, `GAME_PAD_DISCONNECTED`, `GAME_PAD_ACTIVE_CHANGED`, `GAME_PAD_CONFIGS_CHANGED`, `GAME_PAD_POWER_CHANGED`, `GAME_PAD_ALLOW_HOVER_EVENTS_WITH_FREE_LOOK_CHANGED`.

Frame skripty `OnGamePadButtonDown`, `OnGamePadButtonUp`, `OnGamePadStick` a metody `EnableGamePadButton`, `EnableGamePadStick` jsou **NOT CONFIRMED** (známé z retailu). Diagnostika zaznamená, jestli je klient přijme.

### 3.2 Režimy UI a bindingy

| API | Stav | Zdroj |
|---|---|---|
| `C_InputInterfaceStyle.GetCurrentStyle()` → `Enum.InputDeviceInterfaceType` (`Mkb`, `Gamepad`) | NOT CONFIRMED | [src] `InputInterfaceStyleDocumentation.lua`, `InputUtil.lua` |
| Událost `INPUT_DEVICE_INTERFACE_TRANSITION(new, old)` | NOT CONFIRMED | [src] `InputUtil.lua` |
| `C_KeyBindings.ActivateBindingContext` / `DeactivateBindingContext` | NOT CONFIRMED, **HasRestrictions** (addon je nejspíš nesmí volat) | [src] `KeyBindingsDocumentation.lua` |
| `Enum.BindingContext.GamepadModeInGameCore` (= 9), zapínaný v režimu Gamepad | NOT CONFIRMED | [src] `Blizzard_Gamepad/Core.lua` |
| `C_KeyBindings.IsBindingContextActive`, `GetBindingByKey(action, context)` | NOT CONFIRMED | [src] |
| Událost `MODIFIER_STATE_CHANGED(key, down)` | NOT CONFIRMED | [src] |
| `SetOverrideBinding*`, `ClearOverrideBindings`, `GetBindingAction` | NOT CONFIRMED (standard Mainline API, diagnostika ověří existenci) | – |
| Režim Gamepad při zapnutí přenastaví SoftTarget a Camera CVary (dočasné CVary `C_CVar.SetTempCVar`) a při vypnutí je vrátí | NOT CONFIRMED | [src] `Blizzard_Gamepad/Core.lua` |
| Edit Mode layouty se ukládají zvlášť pro každý režim UI | NOT CONFIRMED | blue post 2026-10-08 (via Warcraft Wiki) |

### 3.3 Action bary

| Položka | Stav | Zdroj |
|---|---|---|
| HUD pro ovladač: 4 bary × 3 sady, 84 slotů, LT/RT/LT+RT vrstvy, přepínání sad LB+RB+D-pad | NOT CONFIRMED | Blizzard článek „Explore WoW: Forever with a Gamepad“ |
| Sloty HUD pro ovladač jsou **oddělené** od standardních slotů (začínají na `C_GamepadUI.GetFirstGamepadActionStorageSlotIndex()`) | NOT CONFIRMED | [src] `Blizzard_GamepadActionBars/ActionBindingUtil.lua` |
| Bindingy v režimu Gamepad jsou pevné, přebindování platí jen pro rozhraní myš a klávesnice | NOT CONFIRMED | třetí strana (timesaver.gg, cituje dev notes z 1. 10.) |
| Standardní bary v režimu Mkb (`MainActionBar`/`MainMenuBar`, `MultiBar*`) a jejich zapínání | NOT CONFIRMED | diagnostika zaznamená, které framy existují a jsou zobrazené |
| `ActionButtonUseKeyDown`, `GetActionBarPage`, `GetBonusBarOffset` | NOT CONFIRMED | diagnostika |

### 3.4 Bezpečnostní omezení (Midnight → Forever)

| Položka | Stav |
|---|---|
| Secret values v boji (zdraví, aury, threat…) | NOT CONFIRMED ve hře; potvrzeno Blizzardem pro Forever (blue post 2026-09-15) |
| `UseAction` / sesílání spellů z Lua addonu | **BLOCKED** (chráněná funkce, standardní pravidlo WoW) |
| Spuštění akce z `OnGamePadButtonDown` handleru addonu | **BLOCKED** (plyne z bodu výše; addon smí jen nastavit binding) |
| Změna bindingů a propagace vstupu v boji | **BLOCKED** v combat lockdown; změny je nutné odložit na `PLAYER_REGEN_ENABLED` |
| `RestrictedEnvironment` (secure snippety) | NOT CONFIRMED; v buildu 70009 opravena chyba „RestrictedEnvironment not loading“ |

---

## 4. Architektonický důsledek pro ForeverPad

```text
DualSense ──► klient WoW (SDL, GamePadConfig) ──► binding systém klienta
                                                  │
     ForeverPad (mimo boj) nastavuje override ────┘
     bindingy: PAD1 → ACTIONBUTTON1,
               SHIFT-PAD1 → ACTIONBUTTON5 …
     (modifikátory = CVary GamePadEmulateShift/Ctrl/Alt)

ForeverPad Lua vstupní události (OnGamePadButtonDown) slouží JEN pro:
  - diagnostiku,
  - režim „stiskni tlačítko, které chceš namapovat“ v konfigurátoru.
```

Dopady na zadání:

- **Modifikátory:** k dispozici jsou nejvýš 3 emulované modifikátory (Shift/Ctrl/Alt), tedy 8 vrstev. Tlačítko, které funguje jako modifikátor, nemůže mít vlastní akci.
- **Double Tap a Toggle v boji** by šly nanejvýš přes secure snippety. ConsolePort je má, ale u sebe je označuje jako „tested but not finished“. Doporučuji je odložit až za MVP.
- **Override bindingy** (`SetOverrideBinding*` s vlastním owner framem) se neukládají do bindingů hráče a po vypnutí addonu zmizí. To splňuje požadavek nepřepisovat nastavení hráče.
- **Struktura projektu** může být výrazně menší než v kapitole 10 zadání: Input/Normalizer vrstva pro vykonávání akcí odpadá.

---

## 5. Známá omezení a rizika

- Podpora ovladače ve Forever je podle Blizzardu ve stavu **beta**. Chování se může měnit s patchi.
- Blizzard uvádí podporu „XInput-compatible“ ovladačů s ikonami Xbox/PlayStation. Klient ale obsahuje SDL mapování (`gamecontrollerdb.txt`, `AddSDLMapping`) a styl ikon „Shapes“. Funkčnost DualSense bez Steam Input je proto pravděpodobná, ale **NOT CONFIRMED**.
- Vlastní nastavení ovladače (Options → Gameplay → Gamepad) může přepínat celé UI do režimu Gamepad. Vztah mezi „ovladač zapnutý“ a „UI v režimu Gamepad“ je **NOT CONFIRMED**. Právě tohle testuje diagnostika.
- Chat a psaní textu stále vyžadují klávesnici (Blizzard).

---

## 6. ConsolePort

- ConsolePort, nejrozšířenější addon pro ovladač, má **Interim release pro WoW: Forever** (PR #231, sloučeno 2. 10. 2026, verze 3.3.0). Všechny moduly deklarují Interface 16001. Menu modul je ve Forever ve výchozím stavu vypnutý, aby se nepral s nativním menu Blizzardu.
- Nový modul `Layers.lua` řeší modifikátory (held, double tap, latched, ordered). Kurzor a další části Forever reworku podle autora ještě nezačaly.
- **Doporučení:** brát ho jako referenci řešení. Kód nepřebírat bez kontroly licence. Před velkou investicí do Binding Engine je dobré si ConsolePort vyzkoušet a ujasnit si, čím se má ForeverPad odlišit (lehkost, původní UI jako výchozí stav, jednoduchý konfigurátor).

---

## 7. Diagnostický addon (Fáze 1 + 2)

Umístění v projektu: `ForeverPad/`

| Soubor | Účel |
|---|---|
| `ForeverPad.toc` | Interface 16001, SavedVariables `ForeverPadDB` |
| `Core.lua` | inicializace, events (zaznamenává, které eventy klient přijal), slash příkazy `/fpad` |
| `Audit.lua` | snímek klienta: build, `WOW_PROJECT_ID`, existence API, CVary (i vyhledané přes `C_Console`), zařízení, existující `PAD*` bindingy se všemi kombinacemi modifikátorů, action bar framy, obsazené sloty |
| `InputDiagnostics.lua` | živé logování stisků, uvolnění, páček, modifikátorů, připojení a odpojení ovladače a přepnutí režimu UI; detekce opakovaného DOWN, UP bez DOWN a tlačítek zaseknutých při odpojení |

Addon **nevykonává žádné akce a nemění žádné bindingy ani CVary**. Jediný zásah je, že v režimu `/fpad listen` zapne příjem vstupu ovladače na vlastním neviditelném framu, s propagací vstupu dál do hry.

Syntaxe všech `.lua` souborů je zkontrolovaná parserem Lua 5.1 (`luaparse`), seznam použitých globálů je zkontrolovaný proti WoW API. Ve hře zatím nic z toho otestované není.

### 7.1 Instalace

Zkopírovat složku `ForeverPad` do:

```
C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverPad\
```

Výsledek: `...\AddOns\ForeverPad\ForeverPad.toc` (ne `...\AddOns\ForeverPad\ForeverPad\...`).

Alternativa pro vývoj: místo kopie vytvořit junction (PowerShell). Změny v projektu se pak hned projeví po `/reload`:

```powershell
New-Item -ItemType Junction -Path "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\ForeverPad" -Target "C:\path\to\ForeverControl\ForeverPad"
```

### 7.2 Příkazy

| Příkaz | Co dělá |
|---|---|
| `/fpad` | nápověda |
| `/fpad status` | režim UI, `C_GamePad.IsEnabled`, aktivní zařízení, stav poslechu |
| `/fpad audit` | nový snímek a souhrn do chatu |
| `/fpad listen` | zapnout nebo vypnout živé logování vstupu (jen mimo boj) |
| `/fpad sticks` | zapnout nebo vypnout výpis hodnot páček během poslechu |
| `/fpad clearlog` | smazat uložený log vstupů |

### 7.3 Testovací postup

Vše dělej **mimo boj**, DualSense připojený (USB nebo Bluetooth), **bez Steam Input** (Steam vypnutý).

**Test A – režim myš a klávesnice (Mkb), původní UI**

1. Spusť hru, na výběru postavy ověř, že je ForeverPad v seznamu AddOns zapnutý.
2. Po přihlášení musí být v chatu `ForeverPad v0.1.0-diag loaded…` a **žádná Lua chyba**.
3. `/fpad audit`: opiš nebo vyfoť 5–6 řádků souhrnu.
4. `/fpad listen` a postupně stiskni: Cross, Circle, Square, Triangle, L1, R1, L2, R2, L3, R3, D-pad ↑ ↓ ← →, Options, Create, PS, Touchpad (klik), Mute.
   Sleduj, zda se objevuje `DOWN …`/`UP …` a jaké názvy (`PAD1`, …) tlačítka mají.
5. Drž **R2** a stiskni Cross. Sleduj, jestli je v řádku `mods=[CTRL-]` (R2 je teď nastavené jako Ctrl).
6. Všimni si, jestli stisky ovladače **dělají něco ve hře** (skok, spell, …). To je klíčová otázka 1.6.
7. `/fpad sticks`, pohni oběma páčkami, pak znovu `/fpad sticks`.
8. Drž Cross a odpoj ovladač (kabel nebo vypnutí). Pak ho znovu připoj.
9. `/fpad listen` (vypnout) a potom `/reload`, aby se data zapsala na disk.

**Test B – režim Gamepad**

1. Esc → Options → Gameplay → Gamepad: zapni podporu ovladače.
2. Sleduj, zda se v chatu objeví `Interface style changed: Mkb -> Gamepad`.
3. `/fpad audit`, potom `/fpad listen`, stiskni pár tlačítek a nakonec `/fpad listen`.
4. Vrať nastavení zpět do režimu myš a klávesnice a dej `/reload`.

### 7.4 Co mi poslat zpět

- Popis toho, co viděl(a) v chatu, hlavně případné Lua chyby a výsledek bodu A6.
- Výsledná data si přečtu sám ze souboru:
  `C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account\<ÚČET>\SavedVariables\ForeverPad.lua`
  Stačí napsat „hotovo“.

---

## 8. Další krok po diagnostice

- **Když stisky v režimu Mkb dorazí do bindingů:** Fáze 3, proof of concept. Mimo boj se nastaví `SetOverrideBinding(owner, true, "PAD1", "ACTIONBUTTON1")` a ověří se funkce mimo boj i v boji, cooldown, změna obsahu slotu a nezměněný bar.
- **Když nedorazí, nebo jen v režimu Gamepad:** BLOCKED. Zdokumentuje se a hledá se nejbližší legální alternativa (např. CVar, který povolí vstup z ovladače bez přepnutí HUD), stejně jako to řeší ConsolePort.

---

## 9. Výsledky diagnostiky v0.1 (2026-11-18, build 1.60.1.70959)

Zdroj: `WTF\Account\…\SavedVariables\ForeverPad.lua`, snímek z 16:48:13 po `/reload` a log vstupů. Podle uživatele se neobjevily žádné Lua chyby.

### 9.1 CONFIRMED

| Oblast | Zjištění |
|---|---|
| Klient | 1.60.1 build **70959** (aktualizován z 70938), Interface 16001, `WOW_PROJECT_ID = WOW_PROJECT_CAMELOT = 18` |
| DualSense nativně | `C_GamePad` vidí **„DualSense Wireless Controller“**, vendor 1356 (Sony), product 3302 (DualSense), napájení „Wired“, styl ikon „Shapes“. Fyzické zařízení má ID 1, kombinované/aktivní ID 5 |
| Gamepad zapnutý | `C_GamePad.IsEnabled() = true`, `GamePadEnable = 1` |
| Režim UI při testu | `Mkb` (0), binding kontext `GamepadModeInGameCore` **neaktivní**, CVar `InputDeviceInterfaceStyle = 0` |
| `C_GamePad` | všech 25 funkcí přesně podle zdrojáku Blizzardu |
| Další namespaces | `C_GamepadUI` (5 funkcí), `C_GamepadTargeting` (`Enable`, `Disable`, `SetFilter`), `C_InputInterfaceStyle.GetCurrentStyle`, `C_KeyBindings` (11 funkcí), `C_EditMode`, `C_CVar` (včetně `SetTempCVar`), `C_ActionBar` |
| **`C_Console`** | **UNSUPPORTED**: ve Forever neexistuje |
| Enumy | `InputDeviceInterfaceType {Mkb=0, Gamepad=1}`, `BindingContext.GamepadModeInGameCore = 9`, `GamePadPowerLevel {Critical=0 … Wired=4, Unknown=5}` |
| Globální API | existují `SetOverrideBinding`, `SetOverrideBindingClick/Spell/Macro/Item`, `ClearOverrideBindings`, `SetBinding*`, `GetBindingAction/Key/Text`, `UseAction`, `GetActionInfo`, `HasAction`, `GetActionBarToggles`, `SetActionBarToggles`, `RegisterStateDriver`, `SecureHandlerWrapScript`, `SecureCmdOptionParse`, `issecretvalue`, `SetGamePadFreeLook`, `SetGamePadCursorControl`, `SetPreferredGamepadInteractTarget`, `InputUtil`, `GamepadActionBarBindingUtil`, `SecureActionButtonMixin` |
| Eventy | registrace prošla u všech: `GAME_PAD_CONNECTED/DISCONNECTED/ACTIVE_CHANGED/CONFIGS_CHANGED/POWER_CHANGED`, `INPUT_DEVICE_INTERFACE_TRANSITION`, `MODIFIER_STATE_CHANGED` |
| Frame skripty | `OnGamePadButtonDown`, `OnGamePadButtonUp`, `OnGamePadStick` jsou přijaté. `EnableGamePadButton`, `EnableGamePadStick` i `SetPropagateKeyboardInput` vrátily OK |
| **Emulované modifikátory** | `GamePadEmulateShift = PADLTRIGGER` (**L2 = Shift**), `GamePadEmulateCtrl = PADRTRIGGER` (**R2 = Ctrl**), `GamePadEmulateAlt = none`. V režimu Mkb se L2/R2 hlásí jako `RSHIFT`/`RCTRL` v `MODIFIER_STATE_CHANGED` a stisk jiného tlačítka nese `SHIFT-`, `CTRL-` nebo `CTRL-SHIFT-`. Kombinace modifikátorů tedy fungují |
| Další gamepad CVary | `GamePadEmulateTapWindowMs = 350` (existuje, význam zatím NOT CONFIRMED), `GamePadCursorAutoEnable = 1`, `GamePadSingleActiveID = 0`, `GamePadCameraYawSpeed = 1.3`, `GamePadCameraPitchSpeed = 1.0`, `GamePadFaceMovementMaxAngle = 0` |
| Neexistující CVary | `GamePadEmulateEsc`, `GamepadUseCompactActionBar` (**UNSUPPORTED** pod těmito názvy) |
| `ActionButtonUseKeyDown` | `1`: akce se spouští při stisku |
| Index tlačítek → binding | `0=PADDUP 1=PADDRIGHT 2=PADDDOWN 3=PADDLEFT 4=PAD1 5=PAD2 6=PAD3 7=PAD4 8=PAD5 9=PAD6 10=PADLSTICK 11=PADRSTICK 12=PADLSHOULDER 13=PADRSHOULDER 14=PADLTRIGGER 15=PADRTRIGGER 16–19=levá páčka ↑→↓← 20–23=pravá páčka ↑→↓← 24–27=PADPADDLE1–4 28=PADFORWARD 29=PADBACK 30=PADSYSTEM 31=PADSOCIAL` |
| Virtuální páčky | `Left`, `Right`, `Movement`, `Camera`, `Gyro`, `Look`, `Pad` (touchpad), `Cursor` |
| Bindingy ovladače | v režimu Mkb **nejsou žádné `PAD*` bindingy** (0 ze 256 kombinací). Ovladač tedy v Mkb sám nic nespouští, pole je volné pro ForeverPad |
| Klávesnice | `ACTIONBUTTON1–3 = 1, 2, 3`, `ACTIONBUTTON4 = SHIFT-E` |
| Sloty | standardní sloty **1–180**, gamepadový HUD od slotu **181** (`GetFirstGamepadActionStorageSlotIndex`). Obsazené sloty se dají číst mimo boj (`spell:915`, `item:3383` …) |
| Action bary | `MainActionBar` existuje a je zobrazený. **`MainMenuBar` ve Forever neexistuje.** `MultiBarBottomLeft/BottomRight/Right/Left`, `MultiBar5–7`, `StanceBar`, `PetActionBar`, `PossessActionBar`, `OverrideActionBar` existují. `GetActionBarToggles()` = `true, true, true, true, false, false, false` (zapnuté 4 přídavné bary) |
| Odpojení ovladače | `GAME_PAD_DISCONNECTED` přijde, při připojení `GAME_PAD_CONNECTED` a `GAME_PAD_POWER_CHANGED` |

### 9.2 Nalezené problémy

| Problém | Stav | Řešení |
|---|---|---|
| **`OnGamePadButtonUp` nikdy nepřijde.** V logu není jediné UP, každý další stisk je „REPEAT_DOWN“ a při odpojení se hlásí všechna tlačítka jako držená | BLOCKED (pro tento způsob čtení) | Pravděpodobná příčina: při `SetPropagateKeyboardInput(true)` dostane uvolnění ten, kdo zpracoval stisk, tedy binding systém, ne náš frame. **Neovlivňuje to vykonávání akcí**, ty jdou přes bindingy. Ve v0.2 se uvolnění detekuje dotazováním `C_GamePad.GetDeviceMappedState()` |
| `MultiBar*:IsShown()` hází chybu | NOT CONFIRMED | v0.2 ukládá text chyby. ForeverPad viditelnost barů stejně nečte ani nemění |
| Gyro posílá trvalý šum (len ≈ 0.2) | info | v0.2 virtuální páčky `Gyro`/`Look` nelogujeme |
| Přepnutí režimu UI se v logu neobjevilo | NOT CONFIRMED | Ve druhé části logu se L2/R2 hlásí jako obyčejná tlačítka bez modifikátoru, což odpovídá režimu Gamepad (ten emulaci modifikátorů nepoužívá). Přepnutí režimu tedy nejspíš znovu načte UI, takže událost proběhne dřív, než se addon načte. v0.2 zapisuje značku `LOGIN` s režimem UI při každém načtení |
| Fyzické přiřazení (Cross = `PAD1`?) | NOT CONFIRMED | tlačítka se mačkala v rychlém sledu. v0.2 má průvodce `/fpad identify` |

---

## 10. Diagnostika v0.2 – identifikace tlačítek a proof of concept (Fáze 3 + 4)

Nové v0.2:

- **Detekce uvolnění** dotazováním stavu ovladače (`UP_POLL` v logu).
- **`/fpad identify`**: průvodce postupně vyzve ke stisku každého tlačítka DualSense a zapíše, jak se hlásí (`PAD1` nebo „emulated RSHIFT“).
- **`/fpad poc`**: volitelný proof of concept. Mimo boj nastaví **dočasné override bindingy**:

  | Ovladač | Binding | Akce |
  |---|---|---|
  | Cross (`PAD1`) | `PAD1` | `ACTIONBUTTON1` |
  | L2 + Cross | `SHIFT-PAD1` | `ACTIONBUTTON2` |
  | R2 + Cross | `CTRL-PAD1` | `ACTIONBUTTON3` |
  | L2 + R2 + Cross | `CTRL-SHIFT-PAD1` | `ACTIONBUTTON4` |

  Bindingy se neukládají, zmizí po `/fpad poc`, `/reload` nebo odhlášení. Addon sám žádnou akci nevolá. Během PoC se loguje `CAST`/`CAST_FAILED` hráče (v boji může být spell ID „secret“) a začátek a konec boje.

  Pro PoC se používají L2/R2, protože tak je ovladač v tvém klientu už nastavený (CVary hráče neměníme). Modifikátory L1/R1 ze zadání by vyžadovaly změnit `GamePadEmulateShift/Ctrl`. To je rozhodnutí pro Binding Engine.

**Testovací postup v0.2** (vše v režimu myš a klávesnice, Steam vypnutý):

1. **Restart hry** (nový soubor v TOC, `/reload` nestačí).
2. `/fpad identify` a mačkej tlačítka podle výzev. Když se po stisku nic neobjeví, napiš `/fpad skip`. Na konci `/fpad listen` (vypnout).
3. Mimo boj `/fpad poc`. Do chatu se vypíše, na co klient bindingy přeložil.
4. Mimo boj zkus Cross, L2+Cross, R2+Cross, L2+R2+Cross a sleduj, jestli se sešlou akce z tlačítek 1–4 hlavního baru.
5. Najdi nepřítele a zopakuj to **v boji**.
6. Zkontroluj, že klávesy 1, 2, 3 a Shift-E dál fungují a že se hlavní bar nezměnil.
7. `/fpad poc` (vypnout) a `/reload`.

### 10.1 Výsledky v0.2 (2026-11-18 17:32–17:36, režim Mkb)

Zdroj: SavedVariables a potvrzení uživatele („sesílají se“, ostatní body testu v pořádku). Uživatel také potvrdil, že ve druhé části testu v0.1 přepínal do režimu Gamepad.

**Fáze 3 a 4 – CONFIRMED.** Nativní vstup DualSense spouští akce z původních Blizzard barů přes override bindingy, mimo boj i v boji, včetně kombinací modifikátorů:

| Kombinace | Binding (klient vyhodnotil) | Zalogovaný spell (= obsah slotu) |
|---|---|---|
| Cross | `PAD1 → ACTIONBUTTON1` | 915 (slot 1) |
| L2 + Cross | `SHIFT-PAD1 → ACTIONBUTTON2` | 8052 (slot 2), v boji úspěšně |
| R2 + Cross | `CTRL-PAD1 → ACTIONBUTTON3` | 8045 (slot 3) |
| L2 + R2 + Cross | `CTRL-SHIFT-PAD1 → ACTIONBUTTON4` | 8056 (slot 4) |

Mimo boj se spelly hlásily jako `CAST_FAILED`, nejspíš kvůli chybějícímu cíli: akce se spustila a hra ji odmítla. V boji prošlo `CAST` 915 (3×) a 8052. Klávesnice a hlavní bar zůstaly beze změny (uživatel). **Spell ID vlastních kouzel nejsou v boji secret.**

**Fyzické přiřazení DualSense – CONFIRMED** (`/fpad identify`):

| DualSense | Binding klíč | | DualSense | Binding klíč |
|---|---|---|---|---|
| Cross | `PAD1` | | D-pad ↑ ↓ ← → | `PADDUP` `PADDDOWN` `PADDLEFT` `PADDRIGHT` |
| Circle | `PAD2` | | L3 / R3 | `PADLSTICK` / `PADRSTICK` |
| Square | `PAD3` | | Create | **`PADSOCIAL`** |
| Triangle | `PAD4` | | Options | `PADFORWARD` |
| L1 / R1 | `PADLSHOULDER` / `PADRSHOULDER` | | PS | `PADSYSTEM` |
| L2 | `PADLTRIGGER` (emulovaný **SHIFT**) | | Touchpad klik | **`PADBACK`** |
| R2 | `PADRTRIGGER` (emulovaný **CTRL**, potvrzeno ve v0.1) | | Mute | **`PAD5`** |

**Další zjištění:**

- **Ťuknutí na modifikátor – CONFIRMED.** Krátký stisk L2 (111 ms, tedy pod `GamePadEmulateTapWindowMs = 350`) vyvolá Shift down/up a **při uvolnění pošle i samotné `PADLTRIGGER`**. Modifikátor tak může mít vlastní akci na ťuknutí a na držení funguje jako modifikátor, což řeší bod 4.3 zadání přímo v klientu. Když `PADLTRIGGER` nemá binding, ťuknutí nic nedělá. Průvodce identifikace kvůli tomu omylem přiřadil ťuknutí L2 ke kroku R2; opraveno ve v0.2.1.
- **Uvolnění tlačítek přes dotazování – CONFIRMED.** Tabulka `GetDeviceMappedState().buttons` je indexovaná od 1 (`buttons[index + 1]`). Zachycená uvolnění trvala 70–250 ms a REPEAT_DOWN se už neobjevil.
- **Přepnutí do režimu Gamepad znovu načte UI.** Událost `INPUT_DEVICE_INTERFACE_TRANSITION` proto addon neuvidí. Režim je potřeba číst při `PLAYER_LOGIN`. V režimu Gamepad se L2/R2 chovají jako obyčejná tlačítka, protože emulace modifikátorů neplatí.
- **`MultiBar*` „ERROR: false“ byla chyba diagnostiky** (`a and b or c` s `b = false`). Bary jsou ve skutečnosti skryté (`IsShown() = false`), i když `GetActionBarToggles()` vrací 4× `true`. Rozpor je NOT CONFIRMED (možná Edit Mode nebo Forever preset; existuje `C_GameRules.IsMultiActionBarVisibilityForced`). ForeverPad viditelnost barů nemění, takže to nebrání vývoji. Opraveno ve v0.2.1.

**Závěr:** technická cesta je ověřená. Pokračuje se Fází 5, tedy obecným Binding Engine se SavedVariables.

---

## 11. Fáze 5 – Binding Engine (v0.3.0)

### 11.1 Rozhodnutí (uživatel, 2026-11-18)

- **Modifikátory: L1 = Shift, R1 = Ctrl** (podle zadání). L2/R2 jsou běžná akční tlačítka.
- **Cíl mapování: tlačítko Blizzard baru** (`ACTIONBUTTONn`, `MULTIACTIONBARxBUTTONn`). Respektuje stránkování a stance/formy, stejně jako klávesnice.

### 11.2 Návrh

| Soubor | Odpovědnost |
|---|---|
| `Data.lua` | tlačítka DualSense (potvrzené), bary → binding příkazy, katalog herních a UI příkazů, výchozí profil |
| `Profiles.lua` | profily v `ForeverPadDB.profiles`, přiřazení postava → profil, vytvoření / kopie / přejmenování / smazání / reset |
| `BindingEngine.lua` | profil → `SetOverrideBinding` (vlastník `ForeverPadBindingOwner`), modifikátory přes `C_CVar.SetTempCVar`, odložení změn v boji, pozastavení v režimu Gamepad |
| `Commands.lua` | slash příkazy (konfigurace do doby, než vznikne grafický konfigurátor) |
| `Audit.lua`, `InputDiagnostics.lua` | diagnostika (`/fpad audit`, `/fpad listen`, `/fpad identify`) |

Bary podle `Blizzard_ActionBar/Shared/MultiActionBars.xml` (větev forever):

| # | Bar | Binding příkaz | Action page |
|---|---|---|---|
| 1 | Main bar (`MainActionBar`) | `ACTIONBUTTON1–12` | stránkovaný |
| 2 | Bottom left (`MultiBarBottomLeft`) | `MULTIACTIONBAR1BUTTON1–12` | 6 (sloty 61–72) |
| 3 | Bottom right (`MultiBarBottomRight`) | `MULTIACTIONBAR2BUTTON1–12` | 5 (49–60) |
| 4 | Right bar 1 (`MultiBarRight`) | `MULTIACTIONBAR3BUTTON1–12` | 3 (25–36) |
| 5 | Right bar 2 (`MultiBarLeft`) | `MULTIACTIONBAR4BUTTON1–12` | 4 (37–48) |
| 6–8 | `MultiBar5–7` | `MULTIACTIONBAR5–7BUTTON1–12` | 13–15 (145–180) |

Výchozí profil:

| Vrstva | Cross / Circle / Square / Triangle | L2 / R2 |
|---|---|---|
| bez modifikátoru | Main bar 1–4 | Bottom left 5 / 6 |
| L1 | Main bar 5–8 | Bottom left 7 / 8 |
| R1 | Main bar 9–12 | Bottom left 9 / 10 |
| L1 + R1 | Bottom left 1–4 | Bottom left 11 / 12 |

Utility tlačítka:

| Tlačítko | Příkaz |
|---|---|
| D-pad ↑ | Jump |
| D-pad ↓ | Bags |
| D-pad ← | Target previous enemy |
| D-pad → | Target next enemy |
| L3 | Autorun |
| R3 | Interact |
| Options | Game menu |
| Touchpad | World map |
| Create | Character |

Každé přiřazení jde změnit. Když modifikovaná kombinace nemá binding, WoW použije binding samotného tlačítka.

**Ověřeno mimo hru:** 36 testů logiky v Lua VM (fengari) se simulovaným WoW API. Pokrývají parsování kombinací, aliasy, odmítnutí neplatných kombinací, mapování a odmapování, neplatné příkazy, modifikátory přes temp CVary (trvalá hodnota zůstává beze změny), kolizi modifikátorů, profily, `on/off`, pozastavení v režimu Gamepad a odložení v boji.

### 11.3 Otevřené body k ověření ve hře (NOT CONFIRMED)

1. `SetTempCVar` na `GamePadEmulateShift/Ctrl` funguje a **nezapíše se do `Config.wtf`**. Po odhlášení zkontroluji soubor.
2. Bindingy na tlačítka **skrytých** barů (`MULTIACTIONBAR*` s `IsShown() = false`) spouštějí akci.
3. Názvy herních a UI příkazů v katalogu existují ve Forever (`/fpad commands` označí neplatné šedě).
4. Ťuknutí na L1/R1 jako samostatná akce (`/fpad map L1 cmd …`).

### 11.4 Příkazy

| Příkaz | Význam |
|---|---|
| `/fpad list` | stav a celé mapování aktivního profilu včetně obsahu slotů |
| `/fpad map L1+Cross bar 1 5` | kombinace → tlačítko baru (bar 1–8, tlačítko 1–12) |
| `/fpad map Touchpad cmd TOGGLEWORLDMAP` | kombinace → herní/UI příkaz |
| `/fpad unmap L1+Cross` | zrušit mapování |
| `/fpad mod shift L1` / `ctrl R1` / `alt none` | přiřazení modifikátorů |
| `/fpad commands` | katalog příkazů a jejich dostupnost |
| `/fpad profile` | `use`, `new`, `copy`, `rename`, `delete`, `reset` |
| `/fpad on` / `/fpad off` | zapnout / vypnout (`off` vrátí i původní modifikátory) |

### 11.5 Konfigurační okno – část 1 (v0.4.0)

- `/fpad` otevře okno (`ConfigWindow.lua`), nápověda je na `/fpad help`.
- **Záložky vrstev** se tvoří z modifikátorů profilu: 2 modifikátory dávají 4 vrstvy, 3 modifikátory 8 vrstev.
- **Řádky:** v každém je tlačítko DualSense, ikona a název akce (čte se z obsahu slotu) a k tomu [Change] / [X]. Modifikátor je v základní vrstvě jako „(tap)“, v ostatních vrstvách se nezobrazuje. PS se nenabízí.
- **Výběr akce** (`ActionPicker.lua`) má tři záložky:
  - Action bars: 8 × 12 ikon, skryté bary jsou označené;
  - Game commands;
  - UI commands (příkazy, které klient nezná, jsou neaktivní).
- **V boji** se úpravy zamknou a okno výběru akce se zavře. Tlačítko Enable/Disable zapíná a vypíná engine.
- Texty jsou v `Locale.lua` (zatím anglicky).
- **Ověřeno mimo hru:** 26 testů UI se simulovanými widgety a 36 testů jádra. **Ve hře zatím neověřeno.**

Další části: rychlé přiřazení na barech, obrazovka modifikátorů a profilů, průvodce prvním spuštěním.

### 11.6 Rychlé přiřazení na barech (v0.5.0)

- Spouští se tlačítkem **Bind on bars** v okně nebo příkazem `/fpad bind` (`QuickBind.lua`).
- **Překryvy:** přes každé *viditelné* Blizzard action tlačítko se položí průhledný překryv ukotvený k tlačítku, takže funguje s libovolným rozložením a měřítkem. Překryv pohltí kliknutí myší, takže se nic nesešle.
- **Zachytávání:** vlastní frame přijímá `OnGamePadButtonDown` s **vypnutou propagací**, takže stisk při přiřazování nedojde do hry. Modifikátory se čtou z emulovaného stavu Shift/Ctrl/Alt, což bylo ověřeno ve Fázi 4.
- **Ovládání:**
  - najet myší na tlačítko baru a zmáčknout kombinaci → uloží se do profilu a hned se aplikuje;
  - překryv ukáže krátký štítek kombinace (`X`, `L1+X`…);
  - pravé tlačítko myši odebere všechny kombinace z daného tlačítka baru;
  - při přesunu kombinace se ukáže, kam mířila dřív.
- **Pravidla:**
  - samotný modifikátor se uloží jako akce na ťuknutí;
  - modifikátor + modifikátor se odmítne;
  - PS se ignoruje;
  - skryté bary nemají překryv (pro ně slouží výběr akce v okně).
- **Ukončení:** Esc, Done nebo vstup do boje. Konfigurační okno se po ukončení znovu otevře. Diagnostický poslech se při spuštění vypne, aby o vstup nesoupeřil.
- **Ověřeno mimo hru:** 26 testů. **Ve hře zatím neověřeno.** Hlavní otázky: jestli s propagací vypnutou dorazí emulovaný Shift/Ctrl (L1/R1) a jestli frame zachytí i stisk pod ťuknutím.

### 11.7 Modifikátory, profily a průvodce (v0.6.0)

Postranní panely se otevírají vedle okna, vždy jen jeden. V boji se zavřou a nejdou otevřít.

**Modifikátory** (`ModifierPanel.lua`, tlačítko *Modifiers*):
- mřížka Shift / Ctrl / Alt × {none, L1, R1, L2, R2, L3, R3}; jedno tlačítko může být jen jeden modifikátor (při kolizi se přesune);
- ukazuje počet vrstev a délku okna pro ťuknutí (`GamePadEmulateTapWindowMs`);
- **před použitím vypíše bindy, které ovladač už nedosáhne** (modifikátor bez tlačítka, modifikátor + modifikátor), a při *Apply* je odstraní;
- vrstvy patří modifikátoru, ne tlačítku: přesun Shiftu z L1 na L2 zachová celou vrstvu „Shift“.

**Profily** (`ProfilesPanel.lua`, tlačítko *Profiles*):
- seznam profilů s počtem postav, kliknutím se profil přiřadí této postavě;
- akce: nový prázdný, nový ze šablony, kopie aktivního, přejmenovat, smazat všechny bindy, smazat profil;
- mazání vyžaduje druhé kliknutí jako potvrzení;
- slash příkazy: `/fpad profile new` vytvoří *prázdný* profil, `template` profil ze šablony.

**Průvodce prvním spuštěním** (`Wizard.lua`):
- při přihlášení se ukazuje, dokud ho hráč nedokončí nebo nepřeskočí (`ForeverPadDB.setupDone`); znovu ho otevře `/fpad setup` nebo tlačítko *Setup wizard*;
- krok 1: modifikátory (L1+R1 doporučeno / L2+R2 / L1+R1+L2 / žádné);
- krok 2: prázdné rozložení, nebo šablona;
- konec: spustit rychlé přiřazení / otevřít nastavení / zavřít.

**Ověřeno mimo hru:** 35 testů panelů a průvodce. Všechny sady dohromady mají 123 testů. **Ve hře zatím neověřeno.**

### 11.8 Úklid diagnostiky (v0.7.0)

- **Diagnostika je jen na vyžádání** pod `/fpad debug …`:
  - nástroje `audit`, `listen`, `identify`, `skip`, `sticks`, `status`, `clearlog`;
  - `/fpad debug` vypíše nástroje, `/fpad debug on` / `off` diagnostiku zapne / vypne.
  - Starší názvy (`/fpad listen`, `/fpad audit` …) v kapitolách 7 a 10 teď platí s předponou `debug`.
- **Debug režim:**
  - zapne ho první spuštěný diagnostický nástroj;
  - jen v něm se ukládá log vstupů a audit a do chatu se hlásí připojení / odpojení ovladače a změna režimu UI;
  - `/fpad debug off` zastaví poslech a diagnostická data smaže.
- **Žádný automatický audit** při přihlášení.
- **Migrace:** při načtení se smažou diagnostická data starších buildů (`audit`, `inputLog`, `identify`, `poc`, `listenSetup`, `inputScriptSupport`, `buttonStateIndexOffset`), pokud není zapnutý debug režim. SavedVariables tak spadnou ze ~50 kB na jednotky kB.
- **Při přihlášení jen jeden řádek v chatu:** stav profilu a „/fpad = settings“. Chyby bindů se vypíšou zvlášť, jen když nějaké jsou.
- `/fpad help` ukazuje jen hráčské příkazy a odkaz na `/fpad debug`.
- **Ověřeno mimo hru:** 14 testů úklidu. Všechny sady dohromady mají 137 testů.

### 11.9 Kompatibilita s jinými addony (v0.8.0)

- **Typ akce `click`:** bind na libovolné pojmenované akční tlačítko přes `SetOverrideBindingClick(owner, false, key, name, "LeftButton")`. Je to obecná podpora bar addonů (Bartender4, Dominos, ElvUI …) bez seznamu jmen jejich tlačítek. Slot a ikona se čtou z `.action`, z atributu `action`, nebo z `._state_action` (LibActionButton).
- **Rychlé přiřazení:** když pod myší není Blizzard tlačítko (žádný překryv), použije se tlačítko pod kurzorem z `GetMouseFoci()`. Vezme se první pojmenovaný Button/CheckButton s akčním slotem nebo secure atributem `type`, nejvýš 4 úrovně rodičů. Vlastní okna ForeverPadu se ignorují.
- **`/fpad map <combo> click <JménoTlačítka>`** pro ruční zadání.
- **Obecná detekce konfliktů:** po každé aplikaci engine porovná `GetBindingAction(key, true)` s očekávaným bindem. Když kombinaci převzal jiný addon (například ConsolePort s prioritním override), hlásí se v chatu, v `/fpad list` i v okně.
- **Známé addony** (`Compat.lua`, `C_AddOns.IsAddOnLoaded`):
  - **ConsolePort** se hlásí jako konflikt („používej jen jeden“);
  - **Bartender4 / Dominos / ElvUI** dostanou nápovědu, jak jejich tlačítka nabindovat přes rychlé přiřazení.
  - Hláška se ukáže při přihlášení (jen když je addon načtený) a trvale v okně.
- **Ověřeno mimo hru:** 16 testů kompatibility. Všechny sady dohromady mají 153 testů.
- **NOT CONFIRMED (ve hře):**
  - jestli tlačítka Forever verzí Bartender4 / Dominos / ElvUI reagují na `CLICK …:LeftButton` binding (u LibActionButton s `ActionButtonUseKeyDown = 1` může být potřeba jiný virtuální button);
  - jestli `GetMouseFoci` ve Forever existuje (je tu i záloha na `GetMouseFocus`).

### 11.10 Jazyk: angličtina + čeština (v0.9.0)

- **Rozhodnutí uživatele:** angličtina výchozí, čeština volitelná.
- **Volba jazyka** (`ForeverPadDB.language`):
  - `auto` (výchozí) = čeština, když je pro postavu zapnutý český překladový addon **WowfCZ** (`C_AddOns.GetAddOnEnableState`), jinak angličtina;
  - ručně tlačítkem v pravém horním rohu okna (přepne a znovu načte UI) nebo `/fpad lang en | cs | auto`.
- **Písmo:**
  - WowfCZ přibaluje vlastní `FRIZQT__.ttf`, takže výchozí písmo hry české znaky nejspíš nemá;
  - ForeverPad proto přibaluje **Noto Sans Regular** (SIL OFL 1.1, `Fonts/OFL.txt`, 621 kB) a v češtině ho používá přes vlastní font objekty (`ForeverPad_GameFont…`), jen ve svých oknech;
  - Blizzard font objekty ani sdílený `GameTooltip` se nemění; ForeverPad má vlastní tooltip `ForeverPadTooltip`;
  - když se písmo nenačte (`SetFont` vrátí false), zůstane písmo hry.
- **Přeloženo:** celé UI, názvy tlačítek DualSense, barů a příkazů a hlášky enginu v chatu. Slash nápověda a `/fpad debug` zůstávají anglicky. Vstup ve slash příkazech funguje dál anglicky (`Cross`, `x` …).
- **Ověřeno mimo hru:** 17 testů jazyka. Všechny sady dohromady mají 170 testů (`npm test`).
- **NOT CONFIRMED (ve hře):**
  - jak Noto Sans vypadá a jestli velikosti sedí;
  - jestli české znaky v **chatu** (hlášky enginu) zobrazí chatové písmo hry.

### 11.11 Balíček k vydání (v0.9.1)

- **Autor:** Zap Bee. **Licence:** MIT (`LICENSE`, kopie `ForeverPad/LICENSE.txt`). Písmo Noto Sans má vlastní licenci SIL OFL 1.1 (`ForeverPad/Fonts/OFL.txt`).
- **TOC:** `Author`, `Category: Action Bars`, `IconTexture`, `X-License` a `AddonCompartmentFunc` (položka v addon menu u minimapy otevře okno).
- **Dokumenty:** `README.md` pro hráče (EN + CZ) a `CHANGELOG.md`.
- **`npm run package`:**
  - zkontroluje, že verze v TOC a v `Core.lua` je stejná a všechny soubory z TOC existují;
  - ověří čistý pracovní strom a spustí `npm test`;
  - přes `git archive` vytvoří `dist/ForeverPad-<verze>.zip` se složkou `ForeverPad/` (jen commitnutý obsah, bez testů a vývojových souborů).
- **Nahrání:** CurseForge / Wago, flavor **WoW Forever**, verze hry **1.60.1**.
- **NOT CONFIRMED (ve hře):** addon compartment a ikona `INV_Misc_Gear_01` ve Forever.
- **Před 1.0.0:** souhrnný test ve hře (kapitoly 11.3 a 11.5–11.10 a testovací plán ze zadání, kap. 13).

---

## 12. Zdroje

- Blizzard: [World of Warcraft: Forever Now Live](https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4)
- Blizzard: [Explore WoW: Forever with a Gamepad](https://news.blizzard.com/en-us/article/24316974/explore-wow-forever-with-a-gamepad)
- Zdrojový kód UI: [Gethe/wow-ui-source, větev `forever`](https://github.com/Gethe/wow-ui-source/tree/forever): `GamePadDocumentation.lua`, `InputInterfaceStyleDocumentation.lua`, `KeyBindingsDocumentation.lua`, `Blizzard_Gamepad/Core.lua`, `Blizzard_GamepadActionBars/ActionBindingUtil.lua`, `Blizzard_SharedXML/InputUtil.lua`
- Warcraft Wiki: [Patch 1.60.1/API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes)
- ConsolePort: [PR #231 – Interim release for WoW: Forever](https://github.com/seblindfors/ConsolePort/pull/231)
- Návody třetích stran (nižší spolehlivost): [Maxroll](https://maxroll.gg/wow-forever/news/wow-forever-gamepad-controls-how-to-set-up-and-use-a-controller), [Timesaver](https://timesaver.gg/blog/wow-forever-controller-gamepad-guide), [WoW Guide](https://wowguide.net/en/guides/wow-forever-controller-gamepad-support), [ForeverMeta – addony](https://forevermeta.me/en/guides/wow-forever-addons-interface), [Kami-labs](https://kami-labs.fr/en/addons-wow-forever/)
