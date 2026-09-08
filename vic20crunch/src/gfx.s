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
        ;; $900F: bg bits 7–4, reverse bit 3, border bits 2–0. All 0 = black, no reverse.
        lda #0
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
        eor #$ff                ; 1 = ink (glyph color), 0 = $900F black
        sta (dst),y
        iny
        bne cp
        inc src+1
        inc dst+1
        dex
        bne pg

        lda #0
        tax
:       sta CHARSET,x           ; blank $00 (0 bits = $900F black)
        inx
        cpx #8
        bne :-

        ;; Heart $53 → $1C (ROM $40–$5F was not copied)
        ldx #0
:       lda $8298,x             ; $8000 + $53*8
        eor #$ff
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
:       lda #$20
        sta SCREEN,x
        sta SCREEN+$100,x
        lda #COL_WHITE
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        inx
        bne :-
        rts

draw_hud:
        ldx #0
:       lda hud,x
        beq :+
        sta SCREEN+HUD_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+HUD_ORIGIN,x
        inx
        bne :-
:               lda #COL_RED
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
        sta (dst),y
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
        cmp #CHAR_TREE
        bcc black
        sec
        sbc #CHAR_TREE
        cmp #8
        bcs black
        tax
        lda colors,x
        rts
black:  lda #COL_BLACK
        rts

.segment "RODATA"

hud:    .byte $20,$20,$20
        .byte $13,$3A,$20,$20,$20,$20,$20,CHAR_HEART,$20,$20
        .byte $0C,$3A,$20,$20,$00                         ;    S:____ ♥_ L:__

colors: .byte COL_GREEN, COL_WHITE, COL_YELLOW, COL_CYAN
        .byte COL_RED, COL_PURPLE, COL_YELLOW, COL_RED

.segment "TILES"

;; CRUNCH.ASM tiles at $1B00 = char $60.
;; VIC RAM 1=ink: invert the Z80 bitmaps (they displayed as color-paper / black-ink).
tiles:
        .byte %11100011,%11010101,%10101010,%11010101,%11100011,%11100111,%11000011,%11111111
        .byte %00000000,%11001111,%11001111,%00000000,%00000000,%01111110,%01111110,%00000000
        .byte %11000111,%10111011,%01111101,%01111101,%10111011,%11000111,%11111111,%11111111
        .byte %11000011,%10100101,%11011011,%11100110,%00000000,%01100111,%11011011,%10011001
        .byte %10111101,%10000001,%10100101,%11000011,%11100111,%00000000,%11100111,%10011001
        .byte %10111101,%11000011,%10100101,%11011011,%01100110,%00000000,%11100111,%00011000
        .byte %11110111,%11101111,%11100111,%11010011,%11000011,%11100111,%11111111,%11111111
        .byte %11111111,%11101111,%11110101,%11011111,%11111011,%10111101,%11101011,%11111111
