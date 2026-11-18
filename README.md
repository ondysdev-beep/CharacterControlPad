# ForeverPad

**Play World of Warcraft: Forever with a PlayStation 5 DualSense controller while keeping the original Blizzard UI.**

ForeverPad maps controller buttons and button combos to your normal Blizzard action bars. Your bars,
their layout and the Edit Mode stay exactly as you set them up. The keyboard and mouse keep working
at the same time.

> Status: **beta (0.9.x)**. Built for WoW: Forever 1.60.1 (interface 16001). Feedback welcome.

## Features

- **Your own layout.** Hover an action bar button and press a button or combo on the controller to
  bind it. You can also use the settings window.
- **Modifier layers.** Hold L1 / R1 (configurable, up to three modifiers) for 4 or 8 layers of actions,
  for example Cross, L1+Cross, R1+Cross and L1+R1+Cross. A short tap on a modifier can have its own action.
- **Game and UI commands.** Jump, autorun, interact, targeting, map, bags, quest log and more.
- **Profiles.** Each character remembers its own profile. You can create, copy, rename and delete profiles,
  and start a new one empty or from a template.
- **First-run wizard.** Pick your modifiers, then choose between an empty layout and a template.
- **Safe by design.** ForeverPad only sets key bindings, never casts anything itself. It follows Blizzard's
  secure rules: nothing changes in combat (changes wait until combat ends). Your own key bindings and
  settings are never overwritten. Modifiers use temporary settings that are not saved to your config.
- **Works with bar addons.** Buttons of Bartender4, Dominos, ElvUI and similar addons can be bound by
  hovering them. Conflicts with other controller addons (for example ConsolePort) are detected and reported.
- **English and Czech.** Czech is chosen automatically when the Czech translation addon WowfCZ is enabled.

## Requirements

- WoW: Forever with **controller support enabled** in the game options.
- ForeverPad works in the **mouse & keyboard interface**. When you switch the game to Blizzard's own
  gamepad interface, ForeverPad pauses itself, because that interface has its own fixed controls.
- The DualSense is recognised natively. Steam Input is not needed.

## Installation

Copy the `ForeverPad` folder to
`World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

## Quick start

1. Log in. The setup wizard opens: choose your modifiers and an empty layout or a template.
2. Click **Start quick bind**. Hover an action bar button with the mouse and press a button or combo on the
   controller. Right-click a button to remove its combos. Press Esc when you are done.
3. Type **/fpad** at any time to open the settings window. It is also in the addon menu next to the minimap.

## Commands

| Command | What it does |
|---|---|
| `/fpad` | open the settings window |
| `/fpad bind` | quick bind mode |
| `/fpad list` | print the current mapping |
| `/fpad map L1+Cross bar 1 5` | map a combo to a bar button (bars 1-8, buttons 1-12) |
| `/fpad map Touchpad cmd TOGGLEWORLDMAP` | map a combo to a game/UI command |
| `/fpad unmap L1+Cross` | remove a combo |
| `/fpad mod shift L1` | set modifier buttons (shift / ctrl / alt) |
| `/fpad profile ...` | profiles: use, new, template, copy, rename, delete, reset |
| `/fpad on` / `/fpad off` | enable / disable ForeverPad |
| `/fpad lang en \| cs \| auto` | language |
| `/fpad setup` | run the setup wizard again |
| `/fpad help` | all commands |
| `/fpad debug` | diagnostic tools (for troubleshooting and bug reports) |

## Known limitations

- Controller support in WoW: Forever is itself still in beta. A game patch may change how it behaves.
  If something stops working after a patch, `/fpad debug audit` and `/fpad debug identify` help to find out why.
- Chat typing still needs a keyboard.
- Bindings cannot be changed during combat (a Blizzard rule).

## Credits and license

- ForeverPad (c) 2026 **Zap Bee**, released under the **MIT License** (see `LICENSE`).
- Bundled font **Noto Sans** (c) The Noto Project Authors, **SIL Open Font License 1.1**
  (see `ForeverPad/Fonts/OFL.txt`). It is used only for the Czech interface.

---

## Česky

**ForeverPad** umožní hrát WoW: Forever na ovladači PS5 DualSense a zachová původní Blizzard rozhraní.
Tlačítka a kombinace ovladače si namapuješ na své běžné action bary. Klávesnice a myš fungují dál.

- **Instalace:** složku `ForeverPad` zkopíruj do `World of Warcraft\_forever_\Interface\AddOns\` a restartuj hru.
- **První spuštění:** průvodce se zeptá na modifikátory (doporučeno L1 + R1) a na to, jestli chceš prázdné
  rozložení, nebo šablonu.
- **Přiřazení:** v režimu **Přiřadit na barech** najeď myší na tlačítko baru a zmáčkni kombinaci na ovladači.
- **Nastavení:** příkaz `/fpad`.
- **Čeština** se zapne sama, když máš zapnutý překlad WowfCZ. Ručně ji přepneš tlačítkem v okně nebo `/fpad lang cs`.
- ForeverPad funguje v rozhraní pro myš a klávesnici. V Blizzard režimu pro ovladač se sám pozastaví.
