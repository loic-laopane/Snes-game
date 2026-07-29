# Snes-game — Coin Dash

A tiny original platformer for the **Super Nintendo (SNES)**, written from
scratch in 65816 assembly. It assembles into a real `.sfc` ROM you can run on
any SNES emulator (Snes9x, bsnes, RetroArch/Recalbox, etc.) or on real
hardware via a flashcart.

The pre-built ROM is at [`rom/coindash.sfc`](rom/coindash.sfc) — just copy it
to your emulator or Recalbox `roms/snes/` folder and play.

## The game

Walk, jump across three floating platforms, collect the 3 coins, and reach
the flag at the far end of the level.

**Controls**
- D-Pad Left/Right: move
- A or X: jump

## Project layout

```
src/main.asm            65816 source (header, PPU/DMA setup, game logic)
src/graphics_data.asm   generated tile/palette/tilemap data (see below)
tools/gen_graphics.py   generates src/graphics_data.asm from the pixel art
tools/fix_checksum.py   patches the SNES header checksum after assembling
tools/libretro_test.py  headless test harness (loads a libretro core
                        directly and dumps a frame to PNG — used during
                        development to verify rendering/input/physics
                        without a display)
rom/coindash.sfc        pre-built ROM, ready to play
```

## Building from source

Requires [ACME](https://sourceforge.net/projects/acme-crossass/) (a 6502/65816
cross-assembler) and Python 3:

```
# Debian/Ubuntu
sudo apt-get install acme python3

make            # regenerates rom/coindash.sfc from src/main.asm
make graphics   # regenerate src/graphics_data.asm from tools/gen_graphics.py
                # (only needed if you edit the pixel art in that script)
```

`make run` will launch it in RetroArch with the Snes9x core if you have both
installed.

## Technical notes

- LoROM mapping, 32KB ROM, no SRAM.
- Mode 1 background (BG1, 4bpp) for the level tiles, OBJ layer for the
  player/coins/flag sprites (8x8 and 16x16 mixed sizes).
- Player physics use 8.8 fixed-point coordinates; platform/ground collision
  is a simple "land on top" AABB check against a small hand-placed table of
  platform rectangles (see the constants at the top of `src/main.asm`).
- Double-buffered OAM: game logic builds a shadow copy in WRAM each frame,
  and the NMI handler DMAs it to real OAM during vblank.
