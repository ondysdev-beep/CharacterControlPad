# Changelog

## 0.10.0 - 2026-11-18
- Context controls: while a game window is open, some buttons temporarily do what fits the window.
  Circle closes windows. At a merchant, Cross buys and Square sells the item under the cursor,
  Triangle repairs and Options sells junk. In NPC dialogs and quests, the D-pad chooses and Cross
  confirms. In dialogs, Cross accepts and Circle declines. Cross also loots everything, opens all
  mail and learns at a trainer, and Square moves items at the bank.
- Your own bindings are not changed, combos with modifiers are never affected, and the context
  controls are always off in combat.
- New **Windows** panel and `/fpad context`: switch the context controls on/off as a whole, per
  window, and the button hints shown under the window.

## 0.9.1 - 2026-11-18
- Release packaging: author and license (MIT) in the TOC, addon category and icon, entry in the
  minimap addon compartment, LICENSE, README, `npm run package` builds the release ZIP.

## 0.9.0 - 2026-11-18
- English and Czech interface. Czech is chosen automatically when WowfCZ is enabled. Switch with the
  button in the window or `/fpad lang`.
- Bundled Noto Sans font (SIL OFL) for Czech characters. Blizzard fonts and the game tooltip are not changed.

## 0.8.0 - 2026-11-18
- Buttons of other bar addons (Bartender4, Dominos, ElvUI ...) can be bound by hovering them in quick
  bind mode (`click` actions, also `/fpad map <combo> click <Button>`).
- Detection of combos taken over by another addon. ConsolePort is reported as a conflict, and bar addons
  get a hint.

## 0.7.0 - 2026-11-18
- Diagnostics moved under `/fpad debug`. Nothing is logged or saved unless debug mode is on.
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
