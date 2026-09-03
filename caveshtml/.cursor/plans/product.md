# Product

## One sentence

Play original Caves levels in a browser, with CENGINE behavior, without a TI-85, ROM, or web server.

## Players

- You (author / people who remember the calc game)
- Anyone who wants the recovered levels playable (open one HTML file)

## In scope (draft)

- First playable: **Castle** (`CASTLE.LVL`, 4 maps) → built `castle.html`
- Split CSS/JS sources; Python build embeds pack as `LVL_DATA` into a standalone HTML
- Side-scroll, jump, shoot, keys/doors, monsters, fire, coins, artifact/scroll win
- Score, health, lives, hi-score
- Multiple levels per pack; later: one built HTML per `.LVL`

## Out of scope (until decided)

- Porting Scrolls / Crunch
- Recreating the missing C++ level compiler as a full editor
- Exact Z80 cycle timing / ZShell host
- Shipping as a calculator app
- Requiring a web server to play

## Notes

- Enhancement vs 1995 LCD: one solid tint per sprite, dark playfield, integer scale.
- Keyboard only.
