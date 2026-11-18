# CharacterControlPad

**Play World of Warcraft: Forever with a PlayStation 5 DualSense controller while keeping the original Blizzard UI.**

CharacterControlPad maps controller buttons and button combos to your normal Blizzard action bars. Your bars,
their layout and the Edit Mode stay exactly as you set them up. The keyboard and mouse keep working
at the same time.

> Status: **beta (0.13.x)**. Built for WoW: Forever 1.60.1 (interface 16001). Feedback welcome.

## Features

- **Your own layout.** Hover an action bar button and press a button or combo on the controller to
  bind it. Or open the settings window: it shows a picture of the controller with the action of every
  button, and you click a button to change it.
- **Modifier layers.** Hold L1 / R1 (configurable, up to three modifiers) for 4 or 8 layers of actions,
  for example Cross, L1+Cross, R1+Cross and L1+R1+Cross. A short tap on a modifier can have its own action.
- **Game and UI commands.** Jump, autorun, interact, targeting, map, bags, quest log and more.
- **Context controls for windows.** While a window is open, a few buttons do what fits it, and they
  go back to your own bindings when it closes:
  - **Circle** closes windows.
  - **Merchant:** Cross buys and Square sells the item under the cursor, Triangle repairs, Options
    sells junk.
  - **NPC dialogs and quests:** the D-pad chooses and Cross accepts, continues or completes.
  - **Dialogs** (ready check, dungeon queue, invitations): Cross accepts, Circle declines.
  - **Loot:** the D-pad chooses an item, Cross takes it, Square takes everything.
  - **Other windows:** Cross opens all mail and learns at a trainer. At the bank, Square moves the
    item under the cursor.

  A hint line under the window shows the buttons. Each part can be switched off on the **Windows**
  tab of the settings window.
- **Profiles.** Each character remembers its own profile. You can create, copy, rename and delete profiles,
  and start a new one empty or from a template.
- **First-run wizard.** Pick your modifiers, then choose between an empty layout and a template.
- **Safe by design.** CharacterControlPad only sets key bindings, never casts anything itself. It follows Blizzard's
  secure rules: nothing changes in combat (changes wait until combat ends). Your own key bindings and
  settings are never overwritten. Modifiers use temporary settings that are not saved to your config.
- **Works with bar addons.** Buttons of Bartender4, Dominos, ElvUI and similar addons can be bound by
  hovering them. Conflicts with other controller addons (for example ConsolePort) are detected and reported.
- **English and Czech.** Czech is chosen automatically when the Czech translation addon WowfCZ is enabled.

## Requirements

- WoW: Forever with **controller support enabled** in the game options.
- CharacterControlPad is made for **the character on the controller and windows with the mouse**. It keeps
  the game's automatic gamepad cursor off (the stick stays on the character, R1 / R2 stay modifiers);
  switch it back with `/ccp cursor on` or on the Settings tab.
- CharacterControlPad works in the **mouse & keyboard interface**. When you switch the game to Blizzard's own
  gamepad interface, CharacterControlPad pauses itself, because that interface has its own fixed controls.
- The DualSense is recognised natively. Steam Input is not needed.

## Installation

Copy the `CharacterControlPad` folder to
`World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

**Upgrading from ForeverPad (0.12.0 and older):** the addon was renamed. Delete the old
`ForeverPad` folder from `AddOns`. To keep your profiles, close the game and, in
`World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\`, rename `ForeverPad.lua` to
`CharacterControlPad.lua`. The command is now `/ccp`.

## Quick start

1. Log in. The setup wizard opens: choose your modifiers and an empty layout or a template.
2. Click **Start quick bind**. Hover an action bar button with the mouse and press a button or combo on the
   controller. Right-click a button to remove its combos. Press Esc when you are done.
3. Type **/ccp** at any time to open the settings window. It is also in the addon menu next to the minimap.
   - **Controller** tab: a picture of the controller. Click a button to choose its action, right-click
     to remove it. The buttons at the top switch between layers (No modifier, L1, R1, L1+R1).
   - **Windows** tab: the context controls for game windows.
   - **Settings** tab: modifiers, profile, language and the setup wizard.

## Commands

| Command | What it does |
|---|---|
| `/ccp` | open the settings window |
| `/ccp bind` | quick bind mode |
| `/ccp list` | print the current mapping |
| `/ccp map L1+Cross bar 1 5` | map a combo to a bar button (bars 1-8, buttons 1-12) |
| `/ccp map Touchpad cmd TOGGLEWORLDMAP` | map a combo to a game/UI command |
| `/ccp unmap L1+Cross` | remove a combo |
| `/ccp mod shift L1` | set modifier buttons (shift / ctrl / alt) |
| `/ccp profile ...` | profiles: use, new, template, copy, rename, delete, reset |
| `/ccp context` | context controls for windows (`on`, `off`, `status`, `hints on\|off`, `merchant off` ...) |
| `/ccp cursor on\|off` | `off` (default): the game never switches to its gamepad cursor, windows are used with the mouse |
| `/ccp on` / `/ccp off` | enable / disable CharacterControlPad |
| `/ccp lang en \| cs \| auto` | language |
| `/ccp setup` | run the setup wizard again |
| `/ccp help` | all commands |
| `/ccp debug` | diagnostic tools (for troubleshooting and bug reports) |

## Known limitations

- Controller support in WoW: Forever is itself still in beta. A game patch may change how it behaves.
  If something stops working after a patch, `/ccp debug audit` and `/ccp debug identify` help to find out why.
- Chat typing still needs a keyboard.
- Bindings cannot be changed during combat (a Blizzard rule).

## Credits and license

- CharacterControlPad (c) 2026 **Zap Bee**, released under the **MIT License** (see `LICENSE`).
- Bundled font **Noto Sans** (c) The Noto Project Authors, **SIL Open Font License 1.1**
  (see `CharacterControlPad/Fonts/OFL.txt`). It is used only for the Czech interface.

---

## Česky

**CharacterControlPad** umožní hrát WoW: Forever na ovladači PS5 DualSense a zachová původní Blizzard rozhraní.
Tlačítka a kombinace ovladače si namapuješ na své běžné action bary. Klávesnice a myš fungují dál.

- **Instalace:** složku `CharacterControlPad` zkopíruj do `World of Warcraft\_forever_\Interface\AddOns\` a restartuj hru.
- **Přechod z ForeverPadu (0.12.0 a starší):** addon se přejmenoval. Starou složku `ForeverPad` z `AddOns`
  smaž. Profily si zachováš tak, že při zavřené hře přejmenuješ v
  `World of Warcraft\_forever_\WTF\Account\<účet>\SavedVariables\` soubor `ForeverPad.lua` na
  `CharacterControlPad.lua`. Příkaz je teď `/ccp`.
- **První spuštění:** průvodce se zeptá na modifikátory (doporučeno L1 + R1) a na to, jestli chceš prázdné
  rozložení, nebo šablonu.
- **Přiřazení:** v režimu **Přiřadit na barech** najeď myší na tlačítko baru a zmáčkni kombinaci na ovladači.
- **Nastavení:** příkaz `/ccp`. Okno má tři záložky:
  - **Ovladač:** obrázek ovladače. Klikni na tlačítko a vyber mu akci, pravým tlačítkem myši ji smažeš.
    Nahoře přepínáš vrstvy (Bez modifikátoru, L1, R1, L1+R1).
  - **Okna:** kontextové ovládání herních oken.
  - **Nastavení:** modifikátory, profil, jazyk a průvodce.
- **Kontextové ovládání oken:**
  - **Kolečko** zavře okno.
  - **U obchodníka** Křížek koupí a Čtverec prodá předmět pod kurzorem, Trojúhelník opraví vše a
    Options prodá odpad.
  - **U NPC a questů** D-pad vybírá a Křížek potvrdí.
  - **U kořisti** D-pad vybírá předmět, Křížek ho sebere a Čtverec sebere všechno.
  - **V potvrzovacích oknech** Křížek potvrdí a Kolečko odmítne.
  - Vypnout se dá v záložce **Okna**.
  - V boji je vypnuté a platí tvoje bindy.
- **Čeština** se zapne sama, když máš zapnutý překlad WowfCZ. Ručně ji přepneš tlačítkem v okně nebo `/ccp lang cs`.
- CharacterControlPad funguje v rozhraní pro myš a klávesnici. V Blizzard režimu pro ovladač se sám pozastaví.
- Postava se ovládá ovladačem, okna myší. CharacterControlPad proto vypíná automatický kurzor ovladače, takže
  páčka zůstane na postavě a R1 / R2 fungují jako modifikátory. Vrátit to jde příkazem `/ccp cursor on`
  nebo v záložce Nastavení.
