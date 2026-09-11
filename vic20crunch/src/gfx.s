;; Graphics: charset fill-then-point; VBlank wait; full 16×8 blit

.include "game.inc"

.export init_graphics
.export wait_vrefresh
.export blit_playfield
.export clear_screen
.export draw_hud

.import playfield

.segment "ZEROPAGE"
src:    .res 2
dst:    .res 2
col:    .res 2
row:    .res 1

.segment "CODE"

init_graphics:
        lda #1
        sta CURS_FLAG
        ;; $900F: bg bits 7–4, reverse bit 3, border bits 2–0.
        ;; Reverse on: bitmap 1 = color RAM, 0 = black paper (playfield empty).
        ;; Border black; chrome is reverse-space ($A0) + COL_BLUE.
        lda #$08
        sta VIC_COLOR
        ;; do not touch $9002 — stock 22 cols, bit 7 set → screen $1E00

        ;; Copy ROM $00–$3F into $1800–$19FF. $1A00 is CODE2 (chars $40–$5F unused).
        lda #<CHARSET
        sta dst
        lda #>CHARSET
        sta dst+1
        lda #<$8000
        sta src
        lda #>$8000
        sta src+1
        ldx #2                  ; 2 × 256 = chars $00–$3F
pg:     ldy #0
cp:             lda (src),y
        sta (dst),y
        iny
        bne cp
        inc src+1
        inc dst+1
        dex
        bne pg

        lda #0
        tax
:       sta CHARSET,x           ; blank $00
        inx
        cpx #8
        bne :-

        ;; PETSCII 113 (● $51) → $1B; heart $53 → $1C
        ldx #0
:       lda $8288,x             ; $8000 + $51*8
        sta CHARSET+$1B*8,x
        lda $8298,x             ; $8000 + $53*8
        sta CHARSET+$1C*8,x
        inx
        cpx #8
        bne :-

        lda #VIC_CR5_GAME
        sta VIC_CR5
        rts

;; Wait until raster hits line 0, then leave it (one frame cadence)
wait_vrefresh:
:       lda VIC_HLINE
        bne :-
:       lda VIC_HLINE
        beq :-
        rts

clear_screen:
        ldx #0
:       lda #$A0                ; reverse space = solid block
        sta SCREEN,x
        sta SCREEN+$100,x
        lda #COL_BLUE
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        inx
        bne :-
        rts

draw_hud:
        ldx #4
:       ldy hud_off,x
        lda hud_ch,x
        sta SCREEN+HUD_ORIGIN+HUD_PAD,y
        lda #COL_WHITE
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD,y
        dex
        bpl :-
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+2
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+3
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+4
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+5
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+8
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+12
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+13
        lda #COL_RED
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD+7
        rts

;; Copy playfield[128] → centered screen + color (call in VBlank only)
blit_playfield:
        lda #<playfield
        sta src
        lda #>playfield
        sta src+1
        lda #<(SCREEN + PF_ORIGIN)
        sta dst
        lda #>(SCREEN + PF_ORIGIN)
        sta dst+1
        lda #<(COLOR_RAM + PF_ORIGIN)
        sta col
        lda #>(COLOR_RAM + PF_ORIGIN)
        sta col+1
        lda #PF_ROWS
        sta row
rrow:
        ldy #0
rcol:
        lda (src),y
        cmp #CHAR_WANDER_U
        bcc @draw
        cmp #CHAR_WANDER_R+1
        bcs @draw
        lda #CHAR_MONSTER       ; same pic; facing is playfield-only
@draw:  sta (dst),y
        tax
        jsr color_of
        and #7                  ; hi-res FG only; bit 3 = multi-color
        sta (col),y
        iny
        cpy #PF_COLS
        bne rcol
        clc
        lda src
        adc #PF_COLS
        sta src
        bcc :+
        inc src+1
:
        clc
        lda dst
        adc #COLS
        sta dst
        bcc :+
        inc dst+1
:
        clc
        lda col
        adc #COLS
        sta col
        bcc :+
        inc col+1
:
        dec row
        bne rrow
        rts

;; A=char → A=color
color_of:
        cmp #CHAR_COIN
        bne :+
        lda #COL_YELLOW
        rts
:
        cmp #CHAR_TREE
        bcc black
        sec
        sbc #CHAR_TREE
        cmp #7
        bcs black
        tax
        lda colors,x
        rts
black:  lda #COL_BLACK
        rts

.segment "RODATA"

hud_ch: .byte $13, $3A, CHAR_HEART, $0C, $3A   ; S : ♥ L :
hud_off:.byte 0, 1, 7, 11, 12

colors: .byte COL_GREEN, COL_WHITE, COL_CYAN
        .byte COL_RED, COL_PURPLE, COL_YELLOW, COL_RED

.segment "TILES"

;; CRUNCH.ASM tiles at $1B00 = char $60. Bitmap 1 = foreground (color RAM).
tiles:
        ; tree $60
        .byte %00011100
        .byte %00101010
        .byte %01010101
        .byte %00101010
        .byte %00011100
        .byte %00011000
        .byte %00111100
        .byte %00000000
        ; brick $61
        .byte %11111111
        .byte %00110000
        .byte %00110000
        .byte %11111111
        .byte %11111111
        .byte %10000001
        .byte %10000001
        .byte %11111111
        ; player $62
        .byte %00111100
        .byte %01011010
        .byte %00100100
        .byte %00011001
        .byte %11111111
        .byte %10011000
        .byte %00100100
        .byte %01100110
        ; monster $63
        .byte %01000010
        .byte %01111110
        .byte %01011010
        .byte %00111100
        .byte %00011000
        .byte %11111111
        .byte %00011000
        .byte %01100110
        ; monster1 $64
        .byte %01000010
        .byte %00111100
        .byte %01011010
        .byte %00100100
        .byte %10011001
        .byte %11111111
        .byte %00011000
        .byte %11100111
        ; bullet $65
        .byte %00001000
        .byte %00010000
        .byte %00011000
        .byte %00101100
        .byte %00111100
        .byte %00011000
        .byte %00000000
        .byte %00000000
        ; blood $66
        .byte %00000000
        .byte %00010000
        .byte %00001010
        .byte %00100000
        .byte %00000100
        .byte %01000010
        .byte %00010100
        .byte %00000000
