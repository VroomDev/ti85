# VIC-20 Scrolls

I wrote **Scrolls** for the TI-85 graphing calculator in the late 1990s. This is my port of that game to a Commodore VIC-20 with 32K RAM.

The original system was **SENGINE** plus **LVL** packs: each pack carried the story, maps, and pictures, and the engine played them. I thought the source was lost, then found it on old floppy disks. This folder is that same game on the VIC, still driven by those LVL packs from [`../slvl/`](../slvl/).

## The game

You hunt the **scroll** of wisdom in a wrapping 32×32 world. You have a sling shot. Monsters hurt you on contact; fire burns. Grab a **key** to open one **door**. Shoot trees and walls — some walls hide secret passages.

Each scroll loads the next map in the pack and the quest continues. Extra lives at scores 50, 150, 250, … (max 9). You can carry only one key at a time.

Different packs tell different stories. PocMan, Jovian Lunacy, Spectre, Robot World, and others all use the same rules with their own maps and tiles.

## This port

The engine is C (cc65) on a **VIC-20 +32K**. Screen is the stock 22×23 layout with a 12×8 scrolling window. Custom tiles come from the pack’s pictures. Joystick and keyboard both work.

On a real machine you need 32K expansion. In VICE:

```text
xvic -memory all -autostart prg/POCMAN.prg
```

Built programs live in [`prg/`](prg/). A pack list with blurbs is [`prg/index.html`](prg/index.html).

## Controls

It is best to use the joystick. If you want to use the keyboard: **I/J/L/M** walk and **Shift** is fire (the VIC only reports one letter key at a time). Press fire or any key on the title to start.

Joystick works best as it allows for full control.

| Key / stick | Action |
|-------------|--------|
| **I** / up | Walk up |
| **J** / left | Walk left |
| **L** / right | Walk right |
| **M** / down | Walk down |
| **Shift** / fire | Shoot (facing stays; a short hold then you can walk while firing) |
| **P** | Pause; press P again to continue |
| **Q** | End the run; another run starts |

After a scroll, the next map loads on its own. After game over, a new run begins.

## Update history


## PRG files

Each `.prg` is one LVL pack compiled into a loadable VIC-20 program (`SYS 8192` after load). `build.bat` writes `prg/POCMAN.prg` from `../slvl/POCMAN.LVL`. `build-all.bat` builds every pack from `../slvl/*.LVL`.

| File | Pack |
|------|------|
| [ALIENS.prg](prg/ALIENS.prg) | Aliens v1.0 by MM |
| [BLANK.prg](prg/BLANK.prg) | Blank LVL |
| [EXAMPLE.prg](prg/EXAMPLE.prg) | Example LVL |
| [PIRATES.prg](prg/PIRATES.prg) | Pirates for Scrolls |
| [POCMAN.prg](prg/POCMAN.prg) | PocMan — Save your friend! |
| [RMAZE.prg](prg/RMAZE.prg) | RMaze — Can you solve the mazes? |
| [ROBOTW.prg](prg/ROBOTW.prg) | Robot World — Gotta get an A! |
| [SIMPLE.prg](prg/SIMPLE.prg) | Simple LVL |
| [SLEVEL.prg](prg/SLEVEL.prg) | Scroll Searching |
| [SPACE.prg](prg/SPACE.prg) | Jovian Lunacy |
| [SPECTRE.prg](prg/SPECTRE.prg) | Spectre (Larry Futhey) |
| [TBMAZE.prg](prg/TBMAZE.prg) | RazorTB's Mazelvls |
| [TBMIND.prg](prg/TBMIND.prg) | Mind levels |
| [THIEF.prg](prg/THIEF.prg) | Thief's Treasure (Rob Linwood) |
| [TOMB.prg](prg/TOMB.prg) | Tomb Archaeologist |
| [TUT.prg](prg/TUT.prg) | King Tut |
| [WILD.prg](prg/WILD.prg) | Wild World |

## Cool Gaming tricks

The game was too easy simply holding fire all the time.  Now you run out of ammo.

Original Scrolls © 1996 Chris Busch.
