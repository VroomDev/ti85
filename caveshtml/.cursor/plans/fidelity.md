# Fidelity

What must feel like 1995 Caves vs what the browser may change.

## Must match (draft)

- Tile map size and collisions
- Jump / gravity / high jumper
- One key at a time
- Shoot monsters, bombs, some bricks
- Monsters not born adjacent to the player
- Score → extra health
- Pack story text and level order

## May differ (draft)

- Pixel scale, window chrome, fonts for menus
- Pause without calculator auto-power-off
- Loading `.LVL` text (embedded as `LVL_DATA` in standalone HTML) instead of compiled 85s
- Frame timing: paint at display refresh; simulate at 23 Hz (20 Hz halt/blit guess + 15% playtest)
- One color per graphic (still 1-bit shapes from the `.LVL` pics)
- Spawn / fire-respawn at `X` instead of map offset 0
- Sound: Crunch/TunesLib songs (Caves itself was silent)
- Play by opening a built HTML file (no ZShell, no web server)

## Unsure — move to decisions when you pick

-
