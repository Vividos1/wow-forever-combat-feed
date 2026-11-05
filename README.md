# Forever Combat Feed

A compact combat-only scrolling damage feed addon for **World of Warcraft: Forever**, developed by **OldBeardedGaming**.

**Stable version:** v0.5.0 (tested in-game)

## Features

- Automatic combat-only display and adjustable hide timer
- Left-aligned scrolling damage feed with selectable newest-first/newest-last order
- Configurable colors, font size, transparency, and spell icons
- Movable, resizable, and lockable feed window
- Movable options panel and draggable minimap button
- Optional floating combat text suppression
- Optional defeated-target summaries and encounter statistics

## Install

The public installation archive is being prepared for GitHub distribution. Once `ForeverCombatFeed-v0.5.0.zip` appears in this repository:

1. Download the **named addon ZIP** (not GitHub's general repository ZIP).
2. Extract it into your WoW Forever `Interface/AddOns` directory.
3. Ensure the folder is named `ForeverCombatFeed` and directly contains `ForeverCombatFeed.toc`, `Core.lua`, and `Options.lua`.
4. Enable the addon and use `/reload` in game.

## Slash commands

`/fcf` — options; `/fcf test` — sample feed; `/fcf move` — move and resize; `/fcf lock` — lock window.

## API limitations

WoW Forever's combat API does not reliably identify every damage source or spell. The addon may show `Unknown attacker` for additional enemies in multi-target fights. Damage summaries may reflect an entire encounter.


