# Forever Combat Feed

A compact, combat-only scrolling damage feed addon for World of Warcraft: Forever.

**Author:** OldBeardedGaming  
**Stable version:** v0.5.0

## Install

1. Download `ForeverCombatFeed-v0.5.0.zip` from the `downloads` folder.
2. Extract the archive, preserving the `ForeverCombatFeed` folder.
3. Place that folder into your WoW Forever `Interface/AddOns` directory.
4. Enable the addon at character selection and type `/reload` in game.

Do **not** install GitHub's automatic *Download ZIP* of the entire repository; use the named addon ZIP in `downloads`.

## Features

- Appears automatically in combat, with adjustable hide delay
- Compact scrollable, movable, resizable combat window
- Numbers on the left, ability names on the right, optional spell icons
- Configurable font, colors, opacity, scroll direction, and lock state
- Movable settings window, minimap button, and AddOns options entry
- Optional suppression of Blizzard floating combat text
- Optional post-combat summary with XP and available encounter totals

## Limitations

Some attacker and ability names are inferred due to WoW Forever addon API restrictions. In multi-target fights, incoming damage may show `Unknown attacker`; totals may reflect an entire encounter rather than an individual enemy.

## Commands

`/fcf` opens settings; `/fcf test` previews sample entries; `/fcf move` previews movement and resize; `/fcf lock` locks the window.

## Release

The v0.5.0 package was tested by its author in WoW Forever and is the frozen stable baseline while CurseForge review is pending. Report issues through GitHub Issues.

