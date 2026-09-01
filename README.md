# Syvalion - Taito H System

An FPGA implementation of Taito's *Syvalion* (1988) for MiSTer.

## The game

You pilot a mechanical dragon through maze-like corridors, steering with a
trackball and burning everything in front of you. The dragon's head follows the
ball directly and the long body trails behind it, so the controls feel less like
a spaceship and more like handling an animal — the body coils, whips round
corners and gets in its own way.

Designed by Fukio "MTJ" Mitsuji, better known for *Bubble Bobble* and *Rainbow
Islands*, and the first game on Taito's H System board.

<img width="503" height="379" alt="image" src="https://github.com/user-attachments/assets/a7d5a4cb-efbb-4d05-aa9c-a610b25ab369" />
<img width="509" height="383" alt="image" src="https://github.com/user-attachments/assets/17f034cb-701b-4cb4-84c9-3a808e5881dc" />



## System

The Taito H System is built around a single large custom video chip doing both
tilemaps and sprites, with two more Taito customs for I/O and the sound mailbox.

| Part | Detail |
|---|---|
| Main CPU | 68000 @ 12 MHz |
| Sound CPU | Z80 @ 4 MHz  |
| Sound | YM2610 @ 8 MHz — FM, SSG, ADPCM-A and ADPCM-B |
| Video | Taito TC0080VCO — tilemaps, sprites, sprite zoom |
| I/O | Taito TC0040IOC — switches, DIPs, trackball counters |
| Sound mailbox | Taito TC0140SYT |
| Board oscillators | 20.000, 8.000 and 24.000 MHz |
| Display | 512 × 400 active in a 640 × 448 frame, 25.00 kHz / 55.80 Hz |

The horizontal rate is worth noting: **25 kHz is a medium-resolution signal**,
not the 15 kHz of most arcade boards of the period.

## Installing

Requires **MAME 0.289** `syvalion.zip` in the mame folder.

Both ROM sets are supported and each has its own MRA:

| MRA | Set | Notes |
|---|---|---|
| `Syvalion.mra` | `syvalion` | Syvalion (Japan) — the parent set |
| `Syvalion (World, prototype).mra` | `syvalionp` | needs `syvalionp.zip` |

The two sets wire the trackball differently — the prototype swaps the axes and
drops a reversal. The core works out which one it has from a checksum of the
loaded ROM and configures itself, so there is nothing to select and no way to
get it wrong.

## Controls

**A mouse is the faithful control.** The cabinet had a trackball, and a mouse is
the same instrument: the dragon's head goes where you push, at the speed you
push it. Left and right mouse buttons both fire.

A gamepad works and is fully playable, but the D-pad gives one fixed speed in
each direction where the trackball gave you all of them.

| Input | Action |
|---|---|
| Mouse | Steer |
| Mouse button (either) | Fire |
| D-pad | Steer, fixed speed |
| A | Fire |
| Start | Start |
| Select | Coin |

## Options

**Aspect Ratio** — Original or Full Screen. The board drove a 4:3 monitor.

**Scandoubler Fx** — None, CRT 25 %, CRT 50 %, CRT 75 %.

There is no HQ2x entry. It is an interpolating filter meant for low-resolution
pixel art, and at 512 × 400 it has little to work with beyond softening the
image.

**DIP Switches** — both of the board's switch banks, on their own menu page:
Service Mode, Demo Sounds, Flip Screen, Cabinet, Coin A and Coin B on bank A;
Difficulty, Bonus Life and Lives on bank B. The defaults match the board's.

The board's "Graphics ROM Addressing Mode" switch is not exposed. It selects
between two pinouts for the graphics ROMs and has no effect on the game.

## Status

Video, sprites with zoom, both ADPCM engines, sound and the trackball all run on
hardware.

One thing is known to be incomplete, and are listed here rather than left to
be discovered:

- **Flip Screen is not verified.** No emulator implements it correctly for this
  board family, so there is currently nothing to check it against.

## Credits

Original game by **Taito**, 1988.

This core builds on the work of others:

- **fx68k** — 68000, by Jorge Cwik
- **tv80** — Z80, by Guy Hutchison
- **JT10 / JT12** — YM2610, by Jose Tejada (jotego)
- The **MiSTer** project and its framework

---

## Licence

Licensed under the GPL v3. See the licence files accompanying the sources.

**No ROM content is distributed with this repository.** You supply your own.

---

This core was developed with the assistance of AI.
