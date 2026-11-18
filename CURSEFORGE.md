# CharacterControlPad

**Play World of Warcraft: Forever with a PlayStation 5 DualSense controller and keep the original Blizzard UI.**

CharacterControlPad maps controller buttons and button combos to your normal Blizzard action bars. Your bars, their layout and Edit Mode stay exactly as you set them up, and the keyboard and mouse keep working at the same time. You play your character with the controller and handle windows with the mouse.

> **Status: beta.** Built for WoW: Forever 1.60.1 (interface 16001). Feedback and bug reports are very welcome.

---

## Features

### Your own layout
- **Settings window with a picture of the controller.** Every button is shown around the picture with the icon and name of its action and where that action lives (for example "Main bar #1"). Click a button to choose its action and right-click to remove it.
- **Quick bind.** Hover any action bar button with the mouse and press a button or combo on the controller. That's it.
- **Modifier layers.** Hold L1 or R1 to reach another layer of actions, for example Cross, L1+Cross, R1+Cross and L1+R1+Cross. Up to three modifiers (L1, R1, L2, R2, L3, R3) give 4 or 8 layers. A short tap on a modifier can have its own action.
- **Live layer preview.** Hold a modifier while the settings window is open and the window shows that layer.
- **Game and UI commands.** Jump, autorun, interact, target next / previous enemy, target friend, assist, sit, game menu, world map, bags, quest log, character, spellbook, social, and any other Blizzard key binding command.

### Context controls for game windows
While a window is open, a few buttons temporarily do what fits it. When the window closes, they go back to your own bindings. Combos with modifiers are never affected.

| Window | Buttons |
|---|---|
| Any window (bags, map, character, merchant ...) | **Circle** closes it, like Esc |
| Merchant | **Cross** buys and **Square** sells the item under the cursor, **Triangle** repairs all, **Options** sells junk |
| NPC dialogs and quests | **D-pad** chooses an option (highlighted), **Cross** accepts, continues or completes. After picking a reward, Cross completes the quest |
| Loot | **D-pad** chooses an item, **Cross** takes it, **Square** takes everything |
| Dialogs (confirmations, ready check, dungeon queue, invitations) | **Cross** accepts, **Circle** declines |
| Mail | **Cross** opens all mail |
| Bank | **Square** moves the item under the cursor |
| Trainer | **Cross** learns the selected skill |

A hint line under the window shows which buttons do what. Every window type can be switched off on the **Windows** tab.

### Controller stays on your character
The game normally switches to its own gamepad cursor when a window opens. The left stick then moves the cursor and R1 / R2 click, which breaks movement and modifier combos. CharacterControlPad keeps that automatic cursor off, so the stick stays on your character and R1 / R2 stay modifiers. If the cursor still gets turned on, moving a stick or jumping always turns it off, and a short hint on screen tells you so. This setting is temporary and can be switched back with one click.

### Profiles and setup
- **Profiles.** Each character remembers its own profile. You can create, copy, rename and delete profiles and start a new one empty or from a template.
- **First-run wizard.** Pick your modifiers, then choose an empty layout or a ready-made template.

### Safe by design
- CharacterControlPad only sets key bindings. It never casts anything itself and follows Blizzard's secure rules.
- Nothing changes in combat. Changes wait until combat ends, and the context controls are off in combat.
- Your own key bindings and game settings are never overwritten. Modifiers and the cursor setting use temporary settings that are not saved to your game config. Disable CharacterControlPad and everything is back as it was.

### Works with other addons
- Buttons of **Bartender4, Dominos, ElvUI** and similar bar addons can be bound by hovering them in quick bind mode.
- Conflicts with other controller addons (for example **ConsolePort**) are detected and reported.

### Languages
English and Czech. Czech is chosen automatically when the Czech translation addon WowfCZ is enabled.

---

## Requirements

- **WoW: Forever** with **controller support enabled** in the game options.
- The game's **mouse & keyboard interface**. If you switch the game to Blizzard's own gamepad interface, CharacterControlPad pauses itself, because that interface has its own fixed controls.
- A **PS5 DualSense** controller (USB or Bluetooth). It is recognised by the game natively and Steam Input is not needed. Other controllers are untested.

---

## Getting started

1. Install the addon and log in. The setup wizard opens: choose your modifiers (L1 + R1 is recommended) and an empty layout or the template.
2. Click **Start quick bind**. Hover an action bar button and press a button or combo on the controller. Press Esc when you are done.
3. Type **/ccp** at any time to open the settings window. You can also open it from the addon menu next to the minimap.
   - **Controller** tab: the picture of the controller. Click a button to change its action. The buttons at the top switch between layers (No modifier, L1, R1, L1+R1).
   - **Windows** tab: the context controls for game windows.
   - **Settings** tab: modifiers, profile, language, gamepad cursor and the setup wizard.

**Tip:** a combo bound to an empty action bar slot does nothing. The settings window shows such buttons as "empty slot", so put a spell on that slot or pick another one.

---

## Commands

| Command | What it does |
|---|---|
| `/ccp` | open the settings window |
| `/ccp bind` | quick bind mode |
| `/ccp list` | print the current mapping |
| `/ccp map L1+Cross bar 1 5` | map a combo to a bar button (bars 1-8, buttons 1-12) |
| `/ccp map Touchpad cmd TOGGLEWORLDMAP` | map a combo to a game / UI command |
| `/ccp unmap L1+Cross` | remove a combo |
| `/ccp mod shift L1` | set modifier buttons (shift / ctrl / alt) |
| `/ccp profile ...` | profiles: use, new, template, copy, rename, delete, reset |
| `/ccp context` | context controls for windows (`on`, `off`, `hints on/off`, `merchant off` ...) |
| `/ccp cursor on/off` | `off` (default): the game never switches to its gamepad cursor |
| `/ccp on` / `/ccp off` | enable / disable CharacterControlPad |
| `/ccp lang en/cs/auto` | language |
| `/ccp setup` | run the setup wizard again |
| `/ccp help` | all commands |
| `/ccp debug` | diagnostic tools for bug reports |

---

## Known limitations

- Controller support in WoW: Forever is itself still new. A game patch may change how it behaves.
- Typing in chat still needs a keyboard.
- Bindings cannot be changed during combat. This is a Blizzard rule.
- Windows are meant to be used with the mouse. CharacterControlPad does not replace the mouse cursor with the controller.

---

## Bug reports

Please describe what you pressed, what you expected and what happened. Screenshots help. For technical details, type `/ccp debug audit`, then `/reload`, and attach the file
`World of Warcraft\_forever_\WTF\Account\<account>\SavedVariables\CharacterControlPad.lua`.
Type `/ccp debug off` when you are done.

---

## Credits and license

- CharacterControlPad © 2026 **Zap Bee**, released under the **MIT License**.
- Bundled font **Noto Sans** © The Noto Project Authors, **SIL Open Font License 1.1**. It is used only for the Czech interface.

*CharacterControlPad is a fan-made addon and is not affiliated with or endorsed by Blizzard Entertainment or Sony Interactive Entertainment. World of Warcraft is a trademark of Blizzard Entertainment. PlayStation and DualSense are trademarks of Sony Interactive Entertainment.*
