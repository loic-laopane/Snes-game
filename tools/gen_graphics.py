#!/usr/bin/env python3
"""Generates src/graphics_data.asm (SNES 4bpp tiles, palettes, tilemap)
for the platformer. Pure stdlib, no dependencies. Re-run after editing
the pixel-art strings below to regenerate the .asm data file."""

import os

OUT = os.path.join(os.path.dirname(__file__), "..", "src", "graphics_data.asm")

# ---------------------------------------------------------------------------
# Helpers: 8x8 tile pixel art is written as 8 strings of 8 chars, '.' = index 0
# (transparent). 16x16 sprite frames are 16 strings of 16 chars, split into
# four 8x8 quadrants at encode time (top-left, top-right, bottom-left, bottom-right)
# because that's how SNES hardware composes "large" OBJ tiles: given a base
# tile number N, it draws N, N+1, N+16, N+17 as TL, TR, BL, BR.
# ---------------------------------------------------------------------------

def rows_to_nibbles(rows, width):
    for r in rows:
        assert len(r) == width, f"row length {len(r)} != {width}: {r!r}"
    grid = []
    for r in rows:
        grid.append([0 if c == '.' else int(c, 16) for c in r])
    return grid


def tile8_to_bytes(grid8):
    """grid8: 8x8 list of ints (0-15). Returns 32 bytes, SNES 4bpp planar."""
    assert len(grid8) == 8
    out = bytearray(32)
    # First 16 bytes: bitplanes 0/1, one row at a time.
    for row in range(8):
        bp0 = bp1 = bp2 = bp3 = 0
        for col in range(8):
            v = grid8[row][col]
            bit = 7 - col
            if v & 1: bp0 |= (1 << bit)
            if v & 2: bp1 |= (1 << bit)
            if v & 4: bp2 |= (1 << bit)
            if v & 8: bp3 |= (1 << bit)
        out[row * 2 + 0] = bp0
        out[row * 2 + 1] = bp1
        out[16 + row * 2 + 0] = bp2
        out[16 + row * 2 + 1] = bp3
    return bytes(out)


def quad(grid16, qx, qy):
    return [grid16[qy * 8 + r][qx * 8:qx * 8 + 8] for r in range(8)]


def sprite16_to_tiles(rows):
    """16x16 sprite -> 4 8x8 tiles in hw composition order TL,TR,BL,BR."""
    grid = rows_to_nibbles(rows, 16)
    tl = tile8_to_bytes(quad(grid, 0, 0))
    tr = tile8_to_bytes(quad(grid, 1, 0))
    bl = tile8_to_bytes(quad(grid, 0, 1))
    br = tile8_to_bytes(quad(grid, 1, 1))
    return tl + tr + bl + br


def tile8x8(rows):
    grid = rows_to_nibbles(rows, 8)
    return tile8_to_bytes(grid)


def rgb15(r, g, b):
    return (r & 31) | ((g & 31) << 5) | ((b & 31) << 10)


def emit_bytes(f, label, data, per_line=16):
    f.write(f"{label}:\n")
    for i in range(0, len(data), per_line):
        chunk = data[i:i + per_line]
        f.write("\t!byte " + ",".join(f"${b:02x}" for b in chunk) + "\n")
    f.write(f"{label}_end:\n")


def emit_words(f, label, words, per_line=8):
    f.write(f"{label}:\n")
    for i in range(0, len(words), per_line):
        chunk = words[i:i + per_line]
        f.write("\t!word " + ",".join(f"${w:04x}" for w in chunk) + "\n")
    f.write(f"{label}_end:\n")


# ---------------------------------------------------------------------------
# BACKGROUND TILES (4bpp, palette row 0). Index 0 = transparent (backdrop).
#   1 = grass green      2 = dirt outline (dark brown)
#   3 = dirt mid brown   4 = dirt tan (light)
#   5 = stone outline (dark grey)  6 = stone mid grey   7 = stone highlight
# ---------------------------------------------------------------------------

TILE_BLANK = tile8x8(["........"] * 8)

TILE_GROUND = tile8x8([
    "11111111",
    "22222222",
    "23333332",
    "23434332",
    "23343432",
    "23434332",
    "23334332",
    "22222222",
])

TILE_PLATFORM = tile8x8([
    "77777777",
    "76666667",
    "56666665",
    "56676665",
    "56666665",
    "56667665",
    "56666665",
    "55555555",
])

bg_chr = TILE_BLANK + TILE_GROUND + TILE_PLATFORM  # tile 0,1,2

BG_PAL = [
    rgb15(15, 22, 31),  # 0 backdrop/sky (also used as screen backdrop color)
    rgb15(6, 24, 6),    # 1 grass green
    rgb15(10, 6, 2),    # 2 dirt outline
    rgb15(18, 11, 4),   # 3 dirt mid
    rgb15(24, 17, 8),   # 4 dirt light
    rgb15(10, 10, 12),  # 5 stone outline
    rgb15(18, 18, 20),  # 6 stone mid
    rgb15(26, 26, 28),  # 7 stone highlight
] + [0] * 8  # 8-15 unused

# ---------------------------------------------------------------------------
# LEVEL TILEMAP: 32 columns x 28 rows. Ground = rows 26-27 (tile 1).
# Platforms (tile 2): must match the pixel tables in main.asm!
#   P0: cols 5..8   row 21   (x 40..71,  y_top 168)
#   P1: cols 13..17 row 17   (x 104..143 y_top 136)
#   P2: cols 22..25 row 21   (x 176..207 y_top 168)
# ---------------------------------------------------------------------------

COLS, ROWS = 32, 28
tilemap = [[0] * COLS for _ in range(ROWS)]
for c in range(COLS):
    tilemap[26][c] = 1
    tilemap[27][c] = 1

def add_platform(col_start, col_count, row):
    for c in range(col_start, col_start + col_count):
        tilemap[row][c] = 2

add_platform(5, 4, 21)
add_platform(13, 5, 17)
add_platform(22, 4, 21)

tilemap_words = []
for row in range(ROWS):
    for c in range(COLS):
        tilemap_words.append(tilemap[row][c])
# pad to a full 32x32 map (SNES tilemap block granularity)
for _ in range((32 - ROWS) * COLS):
    tilemap_words.append(0)

# ---------------------------------------------------------------------------
# SPRITES. Laid out on a 16-tile-wide OBJ sheet so 16x16 composition
# (base, base+1, base+16, base+17) lines up. Rows 0-1 hold player+flag
# 16x16 frames (2 tile columns each); row 2 holds the 8x8 coin frames.
# ---------------------------------------------------------------------------

T = '.'
PLAYER_IDLE = [
    "....2222........",
    "...211112.......",
    "...213312.......",
    "...211112.......",
    "....2222........",
    "...244444422....",
    "..2444444444422",
    "..2444444444422".ljust(16, '.'),
    "..24444444422...",
    "....22..22......",
    "....25..52......",
    "....25..52......",
    "....25..52......",
    "....25..52......",
    "...222..222.....",
    "...222..222.....",
]
PLAYER_IDLE = [r.ljust(16, '.')[:16] for r in PLAYER_IDLE]

PLAYER_WALK1 = [
    "....2222........",
    "...211112.......",
    "...213312.......",
    "...211112.......",
    "....2222........",
    "...244444422....",
    "..2444444444422",
    "..2444444444422".ljust(16, '.'),
    "..24444444422...",
    "...222..222.....",
    "..2225..5222....",
    "..222....5222...",
    "..222.....222...",
    ".................",
    ".................",
    ".................",
]
PLAYER_WALK1 = [r.ljust(16, '.')[:16] for r in PLAYER_WALK1]

PLAYER_WALK2 = [
    "....2222........",
    "...211112.......",
    "...213312.......",
    "...211112.......",
    "....2222........",
    "...244444422....",
    "..2444444444422",
    "..2444444444422".ljust(16, '.'),
    "..24444444422...",
    ".....222..222...",
    "....2225..5222..",
    "...222....5222..",
    "..222.....222...",
    ".................",
    ".................",
    ".................",
]
PLAYER_WALK2 = [r.ljust(16, '.')[:16] for r in PLAYER_WALK2]

PLAYER_JUMP = [
    "....2222........",
    "...211112.......",
    "...213312.......",
    "...211112.......",
    "....2222........",
    "...244444422....",
    "..2444444444422",
    "..2444444444422".ljust(16, '.'),
    "..24444444422...",
    "...2255..5522...",
    "...225......522.",
    "................",
    "................",
    "................",
    "................",
    "................",
]
PLAYER_JUMP = [r.ljust(16, '.')[:16] for r in PLAYER_JUMP]

FLAG = [
    "..1.............",
    "..1.222222......",
    "..1.233332......",
    "..1.233332......",
    "..1.222222......",
    "..1.............",
    "..1.............",
    "..1.............",
    "..1.............",
    "..1.............",
    "..1.............",
    "..1.............",
    "..1.............",
    ".111.............",
    ".111.............",
    ".111.............",
]
FLAG = [r.ljust(16, '.')[:16] for r in FLAG]

# sanity: all rows exactly 16 chars
for name, art in [("idle", PLAYER_IDLE), ("walk1", PLAYER_WALK1),
                   ("walk2", PLAYER_WALK2), ("jump", PLAYER_JUMP), ("flag", FLAG)]:
    for r in art:
        assert len(r) == 16, f"{name} row bad len {len(r)}: {r!r}"

COIN1 = [
    "..1111..",
    ".133311.",
    "13333331",
    "13323331",
    "13333331",
    "13333331",
    ".133311.",
    "..1111..",
]
COIN2 = [
    "..1111..",
    ".133311.",
    "13333331",
    "13333231",
    "13333331",
    "13333331",
    ".133311.",
    "..1111..",
]

spr_row0 = (sprite16_to_tiles(PLAYER_IDLE) + sprite16_to_tiles(PLAYER_WALK1) +
            sprite16_to_tiles(PLAYER_WALK2) + sprite16_to_tiles(PLAYER_JUMP) +
            sprite16_to_tiles(FLAG))
# spr_row0 currently holds, in order: TL,TR of idle,walk1,walk2,jump,flag (row0 tiles 0-9)
# followed by BL,BR of each (which hardware expects at +16). Reorder properly below.

def sprite16_split(rows):
    grid = rows_to_nibbles(rows, 16)
    tl = tile8_to_bytes(quad(grid, 0, 0))
    tr = tile8_to_bytes(quad(grid, 1, 0))
    bl = tile8_to_bytes(quad(grid, 0, 1))
    br = tile8_to_bytes(quad(grid, 1, 1))
    return tl, tr, bl, br

frames = [PLAYER_IDLE, PLAYER_WALK1, PLAYER_WALK2, PLAYER_JUMP, FLAG]
row0_tiles = []  # 16 tile slots (cols 0-15)
row1_tiles = []
for art in frames:
    tl, tr, bl, br = sprite16_split(art)
    row0_tiles.append(tl)
    row0_tiles.append(tr)
    row1_tiles.append(bl)
    row1_tiles.append(br)
while len(row0_tiles) < 16:
    row0_tiles.append(TILE_BLANK)
while len(row1_tiles) < 16:
    row1_tiles.append(TILE_BLANK)

row2_tiles = [tile8x8(COIN1), tile8x8(COIN2)] + [TILE_BLANK] * 14

spr_chr = b"".join(row0_tiles) + b"".join(row1_tiles) + b"".join(row2_tiles)

# Base tile numbers (top-left tile index) for each 16x16 frame, useful as
# constants when writing OAM entries in main.asm:
#   idle=0 walk1=2 walk2=4 jump=6 flag=8   (row of 16 -> BL/BR at +16 automatically)
#   coin frame1 = 32 (row2 tile0), coin frame2 = 33

PAL_PLAYER = [
    0,                    # 0 transparent
    rgb15(22, 22, 24),    # 1 light grey shell
    rgb15(8, 8, 10),      # 2 dark outline
    rgb15(4, 24, 28),     # 3 cyan visor
    rgb15(6, 12, 26),     # 4 blue chest
    rgb15(4, 6, 16),      # 5 dark blue legs
] + [0] * 10

PAL_COIN = [
    0,
    rgb15(31, 26, 4),     # 1 gold
    rgb15(16, 12, 2),     # 2 outline
    rgb15(31, 31, 20),    # 3 highlight
] + [0] * 12

PAL_FLAG = [
    0,
    rgb15(16, 10, 4),     # 1 pole brown
    rgb15(28, 4, 4),      # 2 flag red
    rgb15(14, 2, 2),      # 3 flag outline
] + [0] * 12

with open(OUT, "w") as f:
    f.write("; Auto-generated by tools/gen_graphics.py -- do not edit by hand.\n\n")
    emit_bytes(f, "bg_tiles_chr", bg_chr)
    f.write("\n")
    emit_words(f, "bg_palette", BG_PAL)
    f.write("\n")
    emit_words(f, "bg_tilemap", tilemap_words)
    f.write("\n")
    emit_bytes(f, "spr_tiles_chr", spr_chr)
    f.write("\n")
    emit_words(f, "pal_player", PAL_PLAYER)
    f.write("\n")
    emit_words(f, "pal_coin", PAL_COIN)
    f.write("\n")
    emit_words(f, "pal_flag", PAL_FLAG)
    f.write("\n")

print(f"wrote {OUT}")
print(f"bg_chr {len(bg_chr)} bytes, spr_chr {len(spr_chr)} bytes, tilemap {len(tilemap_words)*2} bytes")
