# Changelog

## 0.15.0 - 2026-11-19
- Buying with the controller: at a merchant, the D-pad moves a gold frame over the goods and the
  confirm button buys one piece (like a right-click). The tooltip shows the item and its price.
  At the end of a page, D-pad Up / Down turns to the previous / next page. Works on the buyback
  tab too.
- Touchpad click switches between buying (goods) and selling (your bags, the confirm button sells
  the selected item). The hint line under the merchant shows the current mode.
- The item under the mouse or the touchpad always wins: the confirm button buys hovered goods and
  sells a hovered bag item.

## 0.14.1 - 2026-11-19
- First release on CurseForge as a full Release (0.14.0 was a beta). Same features as 0.14.0.

## 0.14.0 - 2026-11-19
- Bags with the controller: while a bag is open, the D-pad moves a gold frame over your items (as
  they lie on screen) and the confirm button uses the selected item like a right-click (scrolls,
  food, gear, containers). The item's tooltip is shown. An item hovered with the mouse or the
  touchpad becomes the selection. At a merchant Square sells the selected item, at the bank it
  moves it.
- Placing things on the ground (campfire, ground-targeted spells and items): move the circle with
  the touchpad or the mouse, the confirm button places it, Circle cancels.
- Choose the confirm button (Cross, Square or Triangle) on the Windows tab or with
  `/ccp context confirm square`. It is used for bags, loot, quests and NPC dialogs and placing.
- Automatic releases: a version tag on GitHub uploads the addon to CurseForge as a WoW: Forever file.

## 0.13.0 - 2026-11-18
- Renamed from ForeverPad to **CharacterControlPad** (CCP), because another addon called ForeverPad
  already exists. New folder `CharacterControlPad`, new command **`/ccp`** (also `/charactercontrolpad`).
- Upgrading: delete the old `ForeverPad` folder. To keep your profiles, rename the saved file
  `WTF\Account\<account>\SavedVariables\ForeverPad.lua` to `CharacterControlPad.lua` while the game
  is closed. The addon takes the old data over automatically.
- The older entries below were released as ForeverPad. They now use the new name.

## 0.12.0 - 2026-11-18
- Loot window: choose what to take. The D-pad Up / Down chooses an item (gold frame), Cross takes
  it and the selection moves to the next item, Square takes everything, Circle closes the window.

## 0.11.2 - 2026-11-18
- Safety net for the gamepad cursor: moving a stick or jumping always turns the game's gamepad
  cursor off and gives the controller back to the character (temporary setting, also when the
  player had switched it off in the game options).
- When the gamepad cursor is on and the mouse has not moved for 2.5 seconds, a short hint at the
  top of the screen tells you how to get back (move the left stick or jump).

## 0.11.1 - 2026-11-18
- Fix: controls stopped working after opening the game menu or a window, and R1 / R2 combos did
  not work while a window was open. The game switched to its own gamepad cursor (the left stick
  moves the cursor, R1 / R2 click). CharacterControlPad now keeps that automatic cursor off while it is
  active, so windows are used with the mouse and the controller stays on the character. This is a
  temporary setting: your game settings are not changed.
- Option **Don't switch to the gamepad cursor** on the Settings tab and `/ccp cursor on|off`.
  With the cursor allowed, the window warns when a modifier is also a cursor click button.

## 0.11.0 - 2026-11-18
- New settings window, simpler and clearer, with three tabs: **Controller**, **Windows** and **Settings**.
- **Controller** tab: a picture of the controller with every button around it, showing the icon and
  name of its action and where the action lives. Click a button in the list or on the picture to
  choose an action; right-click removes it. Hovering a button lights it up on the picture.
- Layer switch at the top. While you hold a modifier (L1, R1 ...) the window shows that layer.
- **Settings** tab: modifiers, profile, language and setup wizard in one place. The profile button
  is in the top right corner.
- Choosing an action and managing profiles open as a dialog over the window.
- Your profiles and bindings are kept as they are.

## 0.10.0 - 2026-11-18
- Context controls: while a game window is open, some buttons temporarily do what fits the window.
  Circle closes windows. At a merchant, Cross buys and Square sells the item under the cursor,
  Triangle repairs and Options sells junk. In NPC dialogs and quests, the D-pad chooses and Cross
  confirms. In dialogs, Cross accepts and Circle declines. Cross also loots everything, opens all
  mail and learns at a trainer, and Square moves items at the bank.
- Your own bindings are not changed, combos with modifiers are never affected, and the context
  controls are always off in combat.
- New **Windows** panel and `/ccp context`: switch the context controls on/off as a whole, per
  window, and the button hints shown under the window.

## 0.9.1 - 2026-11-18
- Release packaging: author and license (MIT) in the TOC, addon category and icon, entry in the
  minimap addon compartment, LICENSE, README, `npm run package` builds the release ZIP.

## 0.9.0 - 2026-11-18
- English and Czech interface. Czech is chosen automatically when WowfCZ is enabled. Switch with the
  button in the window or `/ccp lang`.
- Bundled Noto Sans font (SIL OFL) for Czech characters. Blizzard fonts and the game tooltip are not changed.

## 0.8.0 - 2026-11-18
- Buttons of other bar addons (Bartender4, Dominos, ElvUI ...) can be bound by hovering them in quick
  bind mode (`click` actions, also `/ccp map <combo> click <Button>`).
- Detection of combos taken over by another addon. ConsolePort is reported as a conflict, and bar addons
  get a hint.

## 0.7.0 - 2026-11-18
- Diagnostics moved under `/ccp debug`. Nothing is logged or saved unless debug mode is on.
  Old diagnostic data is removed. Only one chat line at login.

## 0.6.0 - 2026-11-18
- Modifier panel (Shift / Ctrl / Alt on L1, R1, L2, R2, L3, R3), with a preview of the layers and of
  the bindings that would become unreachable.
- Profiles panel: new empty, new from template, copy, rename, clear and delete (with confirmation).
- First-run setup wizard.

## 0.5.0 - 2026-11-18
- Quick bind mode: hover an action bar button and press a controller combo.

## 0.4.0 - 2026-11-18
- Settings window with modifier layers and an action picker (action bars, game commands, UI commands).

## 0.3.0 - 2026-11-18
- Binding engine with profiles in SavedVariables, modifiers via temporary CVars, combat-safe apply,
  and a pause in Blizzard's gamepad interface.

## 0.1.0 - 0.2.1 - 2026-11-18
- Technical audit of the WoW: Forever client, input diagnostics and a proof of concept.
  Controller bindings were verified in game, in and out of combat.
