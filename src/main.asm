; ============================================================================
; "Coin Dash" - a tiny original SNES platformer.
; ACME assembler, 65816, LoROM, 32KB.
; ============================================================================

!cpu 65816

; ----------------------------------------------------------------------------
; Hardware register constants
; ----------------------------------------------------------------------------
INIDISP  = $2100
OBSEL    = $2101
OAMADDL  = $2102
OAMADDH  = $2103
OAMDATA  = $2104
BGMODE   = $2105
BG1SC    = $2107
BG12NBA  = $210B
VMAIN    = $2115
VMADDL   = $2116
VMDATA   = $2118
VMDATAH  = $2119
CGADD    = $2121
CGDATA   = $2122
TM       = $212C
NMITIMEN = $4200
JOY1L    = $4218
MDMAEN   = $420B
DMAP0    = $4300
BBAD0    = $4301
A1T0L    = $4302
A1B0     = $4304
DAS0L    = $4305
RDNMI    = $4210

; Joypad bits as read from a 16-bit load of JOY1L/JOY1H ($4218/$4219):
; low byte (from $4218) = A,X,L,R,0,0,0,0 (bit7..bit0)
; high byte (from $4219) = B,Y,Select,Start,Up,Down,Left,Right (bit7..bit0),
; landing at bit15..bit8 of the 16-bit word. Empirically verified via the
; libretro test harness (tools/libretro_test.py).
PAD_B      = %1000000000000000
PAD_Y      = %0100000000000000
PAD_SELECT = %0010000000000000
PAD_START  = %0001000000000000
PAD_UP     = %0000100000000000
PAD_DOWN   = %0000010000000000
PAD_LEFT   = %0000001000000000
PAD_RIGHT  = %0000000100000000
PAD_A      = %0000000010000000
PAD_X      = %0000000001000000

; ----------------------------------------------------------------------------
; WRAM variable map (pure address equates -- NOT emitted into the ROM image).
; ----------------------------------------------------------------------------
frame_ready  = $0010        ; byte
pad_now      = $0011        ; word
pad_prev     = $0013        ; word
player_x     = $0015        ; word, 8.8 fixed point
player_y     = $0017        ; word, 8.8 fixed point
player_vx    = $0019        ; word, 8.8 fixed point, signed
player_vy    = $001b        ; word, 8.8 fixed point, signed
on_ground    = $001d        ; byte
face_left    = $001e        ; byte
anim_timer   = $001f        ; byte
anim_frame   = $0020        ; byte
game_state   = $0021        ; byte (0=playing, 1=win)
win_timer    = $0022        ; word
coin_active0 = $0024        ; byte
coin_active1 = $0025        ; byte
coin_active2 = $0026        ; byte

; scratch temporaries (short-lived, reused by different routines)
scr0 = $0000                ; word
scr1 = $0002                ; word
scr2 = $0004                ; word
scr3 = $0006                ; word
box_x = $0008               ; word - x of the "other" box in an AABB test
box_y = $000a                ; word - y of the "other" box in an AABB test

; OAM shadow buffer (128 sprites * 4 bytes = 512, + 32-byte high table = 544)
oam_shadow = $0300
OAM_SIZE   = 544

; ----------------------------------------------------------------------------
; Level constants (pixel space). MUST match tools/gen_graphics.py tilemap!
; ----------------------------------------------------------------------------
GROUND_Y     = 208         ; top of the ground surface, in pixels
SPR_H        = 16
SPR_W        = 16
SCREEN_W     = 256

PLAYER_START_X = 16
PLAYER_START_Y = (GROUND_Y - SPR_H)

; platform rectangles: x_left, x_right(exclusive), y_top
PLAT0_X0 = 40  : PLAT0_X1 = 72  : PLAT0_Y = 168
PLAT1_X0 = 104 : PLAT1_X1 = 144 : PLAT1_Y = 136
PLAT2_X0 = 176 : PLAT2_X1 = 208 : PLAT2_Y = 168

COIN0_X = 52  : COIN0_Y = 152
COIN1_X = 116 : COIN1_Y = 120
COIN2_X = 188 : COIN2_Y = 152

FLAG_X = 232 : FLAG_Y = (GROUND_Y - SPR_H)

; Physics tuning (8.8 fixed point; 256 units = 1 pixel)
GRAVITY      = 24
MAX_FALL     = 1536
JUMP_VEL     = -1400
RUN_SPEED    = 384

; Sprite tile base numbers (top-left tile of each 16x16 OBJ frame; see
; tools/gen_graphics.py for the sheet layout)
TILE_IDLE  = 0
TILE_WALK2 = 4
TILE_JUMP  = 6
TILE_FLAG  = 8
TILE_COIN1 = 32

; ============================================================================
* = $8000
Start:
    !zone
    sei
    clc
    xce                 ; switch to native 65816 mode
    rep #$30            ; 16-bit A/X/Y
    !al : !rl
    ldx #$1fff
    txs                 ; set up stack
    sep #$20            ; 8-bit A
    !as
    phk
    plb                 ; data bank = program bank (0)

    lda #$8f
    sta INIDISP          ; forced blank
    stz NMITIMEN          ; disable NMI/joypad-auto-read during setup

    jsr ClearOam
    jsr LoadGraphics
    jsr InitGameState

    lda #$01
    sta BGMODE           ; mode 1: BG1/BG2 4bpp, BG3 2bpp
    lda #$04
    sta BG1SC            ; BG1 tilemap at VRAM word $0400, 32x32
    lda #$01
    sta BG12NBA          ; BG1 tile data at VRAM word $1000
    lda #$00
    sta OBSEL            ; sprite tiles at VRAM word $0000, sizes 8x8/16x16
    lda #%00010001
    sta TM               ; enable BG1 + OBJ on main screen

    jsr BuildOam
    jsr PushOam

    lda #$0f
    sta INIDISP          ; screen on, full brightness
    lda #$81
    sta NMITIMEN          ; enable NMI + auto joypad read

MainLoop:
    !zone
-   lda frame_ready
    beq -
    stz frame_ready

    jsr ReadPad
    lda game_state
    bne +
    jsr UpdatePhysics
    jsr CheckCoins
    jsr CheckFlag
    bra ++
+   jsr UpdateWin
++  jsr BuildOam

    bra MainLoop

; ----------------------------------------------------------------------------
NMI:
    !zone
    php
    rep #$30
    !al : !rl
    lda RDNMI            ; ack NMI

    jsr PushOam

    lda #1
    sta frame_ready
    plp
    rti

; DMA the OAM shadow buffer (544 bytes) to real OAM. Safe to call during
; forced blank too (used once from Start for debug/bring-up).
PushOam:
    !zone
    php
    rep #$30
    !al : !rl
    sep #$20
    !as
    lda #$00
    sta OAMADDL
    sta OAMADDH
    lda #$00
    sta DMAP0
    lda #$04
    sta BBAD0             ; destination = OAMDATA ($2104)
    rep #$20
    !al
    lda #oam_shadow
    sta A1T0L
    sep #$20
    !as
    lda #$00
    sta A1B0              ; source bank = 0
    rep #$20
    !al
    lda #OAM_SIZE
    sta DAS0L
    sep #$20
    !as
    lda #$01
    sta MDMAEN
    plp
    rts

COP_IRQ_ABORT:
    !zone
    rti

; ----------------------------------------------------------------------------
ClearOam:
    !zone
    php
    rep #$30
    !al : !rl
    ldx #$0000
.loop1:
    lda #$00f0            ; X=$00, Y=$f0 (hidden, below the visible area)
    sta oam_shadow,x
    lda #$0000            ; tile=0, attr=0
    sta oam_shadow+2,x
    txa
    clc
    adc #4
    tax
    cpx #512
    bne .loop1
    ldx #0
.loop2:
    lda #$0000
    sta oam_shadow+512,x
    inx
    inx
    cpx #32
    bne .loop2
    plp
    rts

; ----------------------------------------------------------------------------
LoadGraphics:
    !zone
    php
    sep #$20
    !as
    rep #$10
    !rl

    ; --- CGRAM: background palette (colors 0-15) ---
    lda #$00
    sta CGADD
    ldx #$0000
.bgpal:
    lda bg_palette,x
    sta CGDATA
    lda bg_palette+1,x
    sta CGDATA
    inx
    inx
    cpx #32
    bne .bgpal

    ; --- CGRAM: sprite palettes (rows 0,1,2 at CGRAM index 128,144,160) ---
    lda #128
    sta CGADD
    ldx #$0000
.plpal:
    lda pal_player,x
    sta CGDATA
    lda pal_player+1,x
    sta CGDATA
    inx
    inx
    cpx #32
    bne .plpal

    lda #144
    sta CGADD
    ldx #$0000
.coinpal:
    lda pal_coin,x
    sta CGDATA
    lda pal_coin+1,x
    sta CGDATA
    inx
    inx
    cpx #32
    bne .coinpal

    lda #160
    sta CGADD
    ldx #$0000
.flagpal:
    lda pal_flag,x
    sta CGDATA
    lda pal_flag+1,x
    sta CGDATA
    inx
    inx
    cpx #32
    bne .flagpal

    ; --- VRAM: BG1 tile data at word address $1000 ---
    lda #$80
    sta VMAIN
    rep #$20
    !al
    lda #$1000
    sta VMADDL
    sep #$20
    !as
    ldx #$0000
.bgchr:
    lda bg_tiles_chr,x
    sta VMDATA
    lda bg_tiles_chr+1,x
    sta VMDATAH
    inx
    inx
    cpx #96
    bne .bgchr

    ; --- VRAM: BG1 tilemap at word address $0400 ---
    rep #$20
    !al
    lda #$0400
    sta VMADDL
    ldx #$0000
.map:
    lda bg_tilemap,x
    sta VMDATA
    inx
    inx
    cpx #2048
    bne .map

    ; --- VRAM: sprite tile data at word address $0000 ---
    lda #$0000
    sta VMADDL
    sep #$20
    !as
    ldx #$0000
.sprchr:
    lda spr_tiles_chr,x
    sta VMDATA
    lda spr_tiles_chr+1,x
    sta VMDATAH
    inx
    inx
    cpx #1536
    bne .sprchr

    plp
    rts

; ----------------------------------------------------------------------------
InitGameState:
    !zone
    php
    rep #$20
    !al
    lda #(PLAYER_START_X*256)
    sta player_x
    lda #(PLAYER_START_Y*256)
    sta player_y
    lda #0
    sta player_vx
    sta player_vy
    sta win_timer
    sep #$20
    !as
    stz on_ground
    stz face_left
    stz anim_timer
    stz anim_frame
    stz game_state
    lda #1
    sta coin_active0
    sta coin_active1
    sta coin_active2
    plp
    rts

; ----------------------------------------------------------------------------
ReadPad:
    !zone
    php
    rep #$20
    !al
    lda pad_now
    sta pad_prev
    lda JOY1L
    sta pad_now
    plp
    rts

; ----------------------------------------------------------------------------
UpdatePhysics:
    !zone
    php
    rep #$30
    !al : !rl

    ; --- horizontal ---
    lda #0
    sta player_vx
    lda pad_now
    bit #PAD_LEFT
    beq .chkright
    lda #-RUN_SPEED
    sta player_vx
    sep #$20
    !as
    lda #1
    sta face_left
    rep #$20
    !al
    bra .horizdone
.chkright:
    bit #PAD_RIGHT
    beq .horizdone
    lda #RUN_SPEED
    sta player_vx
    sep #$20
    !as
    stz face_left
    rep #$20
    !al
.horizdone:

    lda player_x
    clc
    adc player_vx
    sta player_x

    ; Clamp direction depends on which way we moved: checking the sign of
    ; the resulting 16-bit fixed-point value doesn't work here because
    ; legitimate on-screen X values (up to 240*256=$F000) already look
    ; "negative" as a signed 16-bit number.
    lda player_vx
    bmi .movingleft
    lda player_x
    cmp #((SCREEN_W-SPR_W)*256)
    bcc .inrange
    lda #((SCREEN_W-SPR_W)*256)
    sta player_x
    bra .inrange
.movingleft:
    lda player_x
    cmp #$8000
    bcc .inrange
    lda #0
    sta player_x
.inrange:

    ; --- jump ---
    lda pad_now
    bit #PAD_A
    bne .wantjump
    lda pad_now
    bit #PAD_X
    beq .nojump
.wantjump:
    sep #$20
    !as
    lda on_ground
    beq .skipjump8
    rep #$20
    !al
    lda #JUMP_VEL
    sta player_vy
    sep #$20
    !as
    stz on_ground
    rep #$20
    !al
    bra .nojump
.skipjump8:
    rep #$20
    !al
.nojump:

    ; --- gravity ---
    lda player_vy
    clc
    adc #GRAVITY
    bmi .okfall           ; still negative (rising) -- MAX_FALL clamp doesn't apply
    cmp #MAX_FALL
    bcc .okfall
    lda #MAX_FALL
.okfall:
    sta player_vy

    lda player_y
    clc
    adc player_vy
    sta player_y

    ; --- ground / platform collision (only when falling) ---
    lda player_vy
    bmi .skipland
    jsr LandCheck
.skipland:

    ; --- animation state select ---
    sep #$20
    !as
    lda on_ground
    beq .animjump
    lda player_vx
    ora player_vx+1
    beq .animidle
    inc anim_timer
    lda anim_timer
    cmp #8
    bcc .animdone
    stz anim_timer
    lda anim_frame
    eor #1
    sta anim_frame
    bra .animdone
.animidle:
    stz anim_frame
    bra .animdone
.animjump:
    lda #2
    sta anim_frame
.animdone:

    plp
    rts

; Checks feet position against ground line and the 3 platforms; snaps the
; player onto whichever surface it just crossed (falling only).
LandCheck:
    !zone
    php
    rep #$20
    !al
    lda player_y
    clc
    adc #(SPR_H*256)
    xba
    and #$00ff
    sta scr0              ; feet_y_px

    lda player_x
    xba
    and #$00ff
    sta scr1              ; x0_px
    clc
    adc #SPR_W
    sta scr2               ; x1_px

    lda scr0
    cmp #GROUND_Y
    bcc .tryp0
    jsr SnapGround
    bra .landdone
.tryp0:
    cmp #(PLAT0_Y+4)
    bcs .notp0
    cmp #(PLAT0_Y-4)
    bcc .notp0
    lda scr2
    cmp #PLAT0_X0
    bcc .notp0
    lda scr1
    cmp #PLAT0_X1
    bcs .notp0
    jsr SnapPlat0
    bra .landdone
.notp0:
    lda scr0
    cmp #(PLAT1_Y+4)
    bcs .notp1
    cmp #(PLAT1_Y-4)
    bcc .notp1
    lda scr2
    cmp #PLAT1_X0
    bcc .notp1
    lda scr1
    cmp #PLAT1_X1
    bcs .notp1
    jsr SnapPlat1
    bra .landdone
.notp1:
    lda scr0
    cmp #(PLAT2_Y+4)
    bcs .landdone
    cmp #(PLAT2_Y-4)
    bcc .landdone
    lda scr2
    cmp #PLAT2_X0
    bcc .landdone
    lda scr1
    cmp #PLAT2_X1
    bcs .landdone
    jsr SnapPlat2
.landdone:
    plp
    rts

SnapGround:
    !zone
    lda #((GROUND_Y-SPR_H)*256)
    sta player_y
    lda #0
    sta player_vy
    sep #$20
    !as
    lda #1
    sta on_ground
    rep #$20
    !al
    rts
SnapPlat0:
    !zone
    lda #((PLAT0_Y-SPR_H)*256)
    sta player_y
    lda #0
    sta player_vy
    sep #$20
    !as
    lda #1
    sta on_ground
    rep #$20
    !al
    rts
SnapPlat1:
    !zone
    lda #((PLAT1_Y-SPR_H)*256)
    sta player_y
    lda #0
    sta player_vy
    sep #$20
    !as
    lda #1
    sta on_ground
    rep #$20
    !al
    rts
SnapPlat2:
    !zone
    lda #((PLAT2_Y-SPR_H)*256)
    sta player_y
    lda #0
    sta player_vy
    sep #$20
    !as
    lda #1
    sta on_ground
    rep #$20
    !al
    rts

; ----------------------------------------------------------------------------
; AABB overlap test between the player (16x16) and an 8x8 box at (box_x,box_y).
; Returns carry set if overlapping. 16-bit A/X expected on entry.
CheckOneCoin:
    !zone
    php
    rep #$20
    !al
    lda player_x
    xba
    and #$00ff
    sta scr0               ; player x0
    clc
    adc #SPR_W
    sta scr1                ; player x1
    lda player_y
    xba
    and #$00ff
    sta scr2               ; player y0
    clc
    adc #SPR_H
    sta scr3                ; player y1

    lda box_x
    clc
    adc #8
    cmp scr0
    bcc .noover
    lda scr1
    cmp box_x
    bcc .noover
    lda box_y
    clc
    adc #8
    cmp scr2
    bcc .noover
    lda scr3
    cmp box_y
    bcc .noover
    plp
    sec
    rts
.noover:
    plp
    clc
    rts

CheckCoins:
    !zone
    php
    rep #$20
    !al
    sep #$20
    !as
    lda coin_active0
    beq .c1
    rep #$20
    !al
    lda #COIN0_X
    sta box_x
    lda #COIN0_Y
    sta box_y
    jsr CheckOneCoin
    bcc .c1
    sep #$20
    !as
    stz coin_active0
    rep #$20
    !al
.c1:
    sep #$20
    !as
    lda coin_active1
    beq .c2
    rep #$20
    !al
    lda #COIN1_X
    sta box_x
    lda #COIN1_Y
    sta box_y
    jsr CheckOneCoin
    bcc .c2
    sep #$20
    !as
    stz coin_active1
    rep #$20
    !al
.c2:
    sep #$20
    !as
    lda coin_active2
    beq .c3
    rep #$20
    !al
    lda #COIN2_X
    sta box_x
    lda #COIN2_Y
    sta box_y
    jsr CheckOneCoin
    bcc .c3
    sep #$20
    !as
    stz coin_active2
    rep #$20
    !al
.c3:
    plp
    rts

; ----------------------------------------------------------------------------
CheckFlag:
    !zone
    php
    rep #$20
    !al
    lda #FLAG_X
    sta box_x
    lda #FLAG_Y
    sta box_y
    jsr CheckOneCoin        ; same AABB test works for the flag's box
    bcc .noflag
    sep #$20
    !as
    lda #1
    sta game_state
    rep #$20
    !al
    lda #0
    sta win_timer
.noflag:
    plp
    rts

UpdateWin:
    !zone
    php
    rep #$20
    !al
    lda win_timer
    clc
    adc #1
    sta win_timer
    plp
    rts

; ----------------------------------------------------------------------------
; Build the OAM shadow buffer for this frame: player, 3 coins, flag.
BuildOam:
    !zone
    php
    rep #$20
    !al
    lda player_x
    xba
    and #$00ff
    sta scr0
    lda player_y
    xba
    and #$00ff
    sta scr1

    sep #$20
    !as
    lda scr0
    sta oam_shadow+0        ; player X
    lda scr1
    sta oam_shadow+1        ; player Y

    lda game_state
    bne .winpose
    lda anim_frame
    cmp #2
    beq .jumppose
    cmp #1
    beq .walk2pose
    lda #TILE_IDLE
    bra .havetile
.walk2pose:
    lda #TILE_WALK2
    bra .havetile
.jumppose:
    lda #TILE_JUMP
    bra .havetile
.winpose:
    lda #TILE_IDLE
.havetile:
    sta oam_shadow+2
    lda face_left
    beq .noflip
    lda #%01000000
    bra .attrdone
.noflip:
    lda #%00000000
.attrdone:
    sta oam_shadow+3         ; attr: palette 0 (player palette)

    jsr PlaceCoin0
    jsr PlaceCoin1
    jsr PlaceCoin2
    jsr PlaceFlag
    jsr BuildOamHighTable

    plp
    rts

PlaceCoin0:
    !zone
    php
    sep #$20
    !as
    lda coin_active0
    beq .hide
    lda #COIN0_X
    sta oam_shadow+4
    lda #COIN0_Y
    sta oam_shadow+5
    lda #TILE_COIN1
    sta oam_shadow+6
    lda #%00000010           ; palette 1 (coin palette)
    sta oam_shadow+7
    bra .done
.hide:
    lda #$f0
    sta oam_shadow+5
.done:
    plp
    rts

PlaceCoin1:
    !zone
    php
    sep #$20
    !as
    lda coin_active1
    beq .hide
    lda #COIN1_X
    sta oam_shadow+8
    lda #COIN1_Y
    sta oam_shadow+9
    lda #TILE_COIN1
    sta oam_shadow+10
    lda #%00000010
    sta oam_shadow+11
    bra .done
.hide:
    lda #$f0
    sta oam_shadow+9
.done:
    plp
    rts

PlaceCoin2:
    !zone
    php
    sep #$20
    !as
    lda coin_active2
    beq .hide
    lda #COIN2_X
    sta oam_shadow+12
    lda #COIN2_Y
    sta oam_shadow+13
    lda #TILE_COIN1
    sta oam_shadow+14
    lda #%00000010
    sta oam_shadow+15
    bra .done
.hide:
    lda #$f0
    sta oam_shadow+13
.done:
    plp
    rts

PlaceFlag:
    !zone
    php
    sep #$20
    !as
    lda #FLAG_X
    sta oam_shadow+16
    lda #FLAG_Y
    sta oam_shadow+17
    lda #TILE_FLAG
    sta oam_shadow+18
    lda #%00000100            ; palette 2 (flag palette)
    sta oam_shadow+19
    plp
    rts

; Packs the 128-sprite high table (2 bits/sprite: bit0=Xmsb, bit1=size).
; Sprite0(player)=large, sprite4(flag)=large, everything else=small/unused.
BuildOamHighTable:
    !zone
    php
    sep #$20
    !as
    lda #%00000010
    sta oam_shadow+512      ; sprites 0-3: sprite0(player) large
    lda #%00000010
    sta oam_shadow+513      ; sprites 4-7: sprite4(flag) large
    ldx #2
.loop:
    lda #$00
    sta oam_shadow+512,x
    inx
    cpx #32
    bne .loop
    plp
    rts

!src "graphics_data.asm"

; ============================================================================
; Header (LoROM, 32KB -> header at file offset $7FC0 = address $FFC0)
; ============================================================================
* = $ffc0
    !text "COIN DASH            "   ; 21 bytes, space padded
    !byte $20                       ; mapping mode: LoROM, slow
    !byte $00                       ; cartridge type: ROM only
    !byte $05                       ; ROM size: 32KB
    !byte $00                       ; RAM size: none
    !byte $01                       ; country: USA
    !byte $00                       ; developer/license
    !byte $00                       ; version
    !word $0000                     ; checksum complement (fixed later)
    !word $0000                     ; checksum (fixed later)

* = $ffe4
    !word COP_IRQ_ABORT     ; native COP
    !word COP_IRQ_ABORT     ; native BRK
    !word COP_IRQ_ABORT     ; native ABORT
    !word NMI               ; native NMI
    !word Start             ; native RESET (unused)
    !word COP_IRQ_ABORT     ; native IRQ

* = $fff4
    !word COP_IRQ_ABORT     ; emulation COP
    !word $0000             ; unused/reserved
    !word COP_IRQ_ABORT     ; emulation ABORT
    !word NMI               ; emulation NMI
    !word Start             ; emulation RESET (CPU starts here)
    !word COP_IRQ_ABORT     ; emulation IRQ/BRK
