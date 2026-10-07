;; TED graphics: copy ROM charset, then point $FF13 at RAM. Blit only in VBlank.

.include "game.inc"

.export init_graphics
.export wait_vrefresh
.export blit_playfield
.export clear_screen
.export draw_hud

.import playfield
.import hurt_dur

;; (src),y / (dst),y / (col),y need ZP pointers — 6502 has no (abs),y.
.segment "ZEROPAGE"
src:    .res 2
dst:    .res 2
col:    .res 2

.segment "BSS"
row:    .res 1
frame:  .res 1

.segment "CODE"

init_graphics:
        lda #$00
        sta TED_BG
        sta TED_BORDER
        lda #25
        sta CURS_Y
        lda #0
        sta CURS_X
        lda #$03
        sta TED_CURSHI
        lda #$e9                ; position 1001, past the 1000-cell screen
        sta TED_CURSLO

        sta TED_ROMSEL          ; ROM in so $D000 is the character generator

        lda #<CHARSET
        sta dst
        lda #>CHARSET
        sta dst+1
        lda #$00
        sta src
        lda #$d0
        sta src+1
        ldx #8                  ; 2KB, chars $00–$FF
@pg:    ldy #0
@cp:    lda (src),y
        sta (dst),y
        iny
        bne @cp
        inc src+1
        inc dst+1
        dex
        bne @pg

        lda #0
        tax
@bl:    sta CHARSET,x           ; empty tile stays black paper
        inx
        cpx #8
        bne @bl

        ldx #0
@gl:    lda coin,x              ; editable filled circle
        sta CHARSET+$1B*8,x
        lda $D000+$53*8,x       ; heart
        sta CHARSET+$1C*8,x
        inx
        cpx #8
        bne @gl

        lda #<tiles
        sta src
        lda #>tiles
        sta src+1
        lda #<(CHARSET+$60*8)
        sta dst
        lda #>(CHARSET+$60*8)
        sta dst+1
        ldy #55
@tl:    lda (src),y
        sta (dst),y
        dey
        bpl @tl

        lda TED_CTRL
        and #$fb                ; bit 2 clear: charset from RAM
        sta TED_CTRL
        lda TED_CHAR
        and #$03
        ora #CHAR_BASE_RAM      ; $2000
        sta TED_CHAR
        rts

;; One frame: leave raster 0, then catch the next line 0.
wait_vrefresh:
        lda #$03
        sta TED_CURSHI
        lda #$e9
        sta TED_CURSLO
@leave: lda TED_RASTERHI
        and #$01
        ora TED_RASTERLO
        beq @leave
@zero:  lda TED_RASTERHI
        and #$01
        bne @zero
        lda TED_RASTERLO
        bne @zero
        rts

;; 1000 cells. Do not run into the program at $1000.
clear_screen:
        lda #<SCREEN
        sta dst
        lda #>SCREEN
        sta dst+1
        lda #<COLOR_RAM
        sta col
        lda #>COLOR_RAM
        sta col+1
        lda #3
        sta row
        ldy #0
@pg:    lda #$a0
        sta (dst),y
        lda #COL_BLUE
        sta (col),y
        iny
        bne @pg
        inc dst+1
        inc col+1
        dec row
        bne @pg
        ldy #0
@tail:  lda #$a0
        sta (dst),y
        lda #COL_BLUE
        sta (col),y
        iny
        cpy #232                ; 1000 - 768
        bne @tail
        rts

draw_hud:
        ldx #4
@h:     ldy hud_off,x
        lda hud_ch,x
        sta SCREEN+HUD_ORIGIN+HUD_PAD,y
        lda #COL_WHITE
        sta COLOR_RAM+HUD_ORIGIN+HUD_PAD,y
        dex
        bpl @h
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

;; 32×16. Color is inline so this finishes inside the blank.
;; Each tile $60–$66 has two bitmaps. frame & 64 picks the set.
blit_playfield:
        inc frame
        lda frame
        and #32
        bne @frm1
        lda #<tiles
        sta src
        lda #>tiles
        sta src+1
        jmp @inst
@frm1:  lda #<tiles1
        sta src
        lda #>tiles1
        sta src+1
@inst:  lda #<(CHARSET+$60*8)
        sta dst
        lda #>(CHARSET+$60*8)
        sta dst+1
        ldy #55
@cp:    lda (src),y
        sta (dst),y
        dey
        bpl @cp
        clc
        lda src
        adc #56                 ; coin follows the seven tiles
        sta src
        bcc @cok
        inc src+1
@cok:   ldy #0
@cn:    lda (src),y
        sta CHARSET+$1B*8,y
        iny
        cpy #8
        bne @cn
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
@row:   ldy #0
@col:   lda (src),y
        cmp #CHAR_WANDER_U
        bcc @maybe1
        cmp #CHAR_WANDER_R+1
        bcs @draw
        lda #CHAR_MONSTER
        ldx #COL_RED
        bne @got
@maybe1:
        cmp #CHAR_MONSTER1
        bne @draw
        ldx #COL_PURPLE
@got:   sta (dst),y
        txa
        jmp @put
@draw:  sta (dst),y
        cmp #CHAR_PLAYER
        bne @coin
        ldx hurt_dur
        beq @coin
        lda #COL_PURPLE
        bne @put
@coin:  cmp #CHAR_COIN
        bne @tree
        lda #COL_YELLOW
        bne @put
@tree:  cmp #CHAR_TREE
        bcc @black
        cmp #CHAR_BLOOD+1
        bcs @black
        sec
        sbc #CHAR_TREE
        tax
        lda colors,x
        bne @put
@black: lda #COL_BLACK
@put:   sta (col),y
        iny
        cpy #PF_COLS
        bne @col
        clc
        lda src
        adc #PF_COLS
        sta src
        bcc @s1
        inc src+1
@s1:    clc
        lda dst
        adc #COLS
        sta dst
        bcc @s2
        inc dst+1
@s2:    clc
        lda col
        adc #COLS
        sta col
        bcc @s3
        inc col+1
@s3:    dec row
        bne @row
        rts

.segment "RODATA"

hud_ch: .byte $13, $3A, CHAR_HEART, $0C, $3A   ; S : ♥ L :
hud_off:.byte 0, 1, 7, 11, 12

colors: .byte COL_GREEN, COL_WHITE, COL_CYAN
        .byte COL_RED, COL_PURPLE, COL_YELLOW, COL_RED

;; Bitmap 1 = foreground. TED paper is $FF15.
tiles:
        ; tree $60
        .byte %00011100        ; ___XXX__
        .byte %00101010        ; __X_X_X_
        .byte %01010101        ; _X_X_X_X
        .byte %00101010        ; __X_X_X_
        .byte %00011100        ; ___XXX__
        .byte %00011000        ; ___XX___
        .byte %00111100        ; __XXXX__
        .byte %00000000        ; ________
        ; brick $61
        .byte %11111111        ; XXXXXXXX
        .byte %00110000        ; __XX____
        .byte %00110000        ; __XX____
        .byte %11111111        ; XXXXXXXX
        .byte %11111111        ; XXXXXXXX
        .byte %10000001        ; X______X
        .byte %10000001        ; X______X
        .byte %11111111        ; XXXXXXXX
        ; player $62
        .byte %00111100        ; __XXXX__
        .byte %01111110        ; _XXXXXX_
        .byte %00111100        ; __XXXX__
        .byte %00011001        ; ___XX__X
        .byte %11111111        ; XXXXXXXX
        .byte %10011000        ; X__XX___
        .byte %00100100        ; __X__X__
        .byte %01100110        ; _XX__XX_
        ; monster $63
        .byte %01000010        ; _X____X_
        .byte %01111110        ; _XXXXXX_
        .byte %01011010        ; _X_XX_X_
        .byte %00111100        ; __XXXX__
        .byte %00011000        ; ___XX___
        .byte %11111111        ; XXXXXXXX
        .byte %00011000        ; ___XX___
        .byte %01100110        ; _XX__XX_
        ; monster1 $64
        .byte %01000010        ; _X____X_
        .byte %00111100        ; __XXXX__
        .byte %01011010        ; _X_XX_X_
        .byte %00100100        ; __X__X__
        .byte %00011001        ; ___XX__X
        .byte %11111111        ; XXXXXXXX
        .byte %00011000        ; ___XX___
        .byte %11100111        ; XXX__XXX
        ; bullet $65
        .byte %00000000        ; ________
        .byte %00000000        ; ________
        .byte %00011000        ; ___XX___
        .byte %00101100        ; __X_XX__
        .byte %00111100        ; __XXXX__
        .byte %00011000        ; ___XX___
        .byte %00000000        ; ________
        .byte %00000000        ; ________
        ; blood $66
        .byte %00000000        ; ________
        .byte %00010000        ; ___X____
        .byte %00001010        ; ____X_X_
        .byte %00100000        ; __X_____
        .byte %00000100        ; _____X__
        .byte %01000010        ; _X____X_
        .byte %00010100        ; ___X_X__
        .byte %00000000        ; ________
coin:
        ; PETSCII 113 filled circle
        .byte %00000000        ; __XXXX__
        .byte %00111100        ; _XXX_XX_
        .byte %01111110        ; XXXX__XX
        .byte %01111110        ; XXXXX_XX
        .byte %01111110        ; XXXXXXXX
        .byte %01111110        ; XXXXXXXX
        .byte %00111100        ; _XXXXXX_
        .byte %00000000        ; __XXXX__

;; Second pose of each tile, same order as tiles.
tiles1:
        ; tree
        .byte %00111000        ; __XXX___
        .byte %01010100        ; _X_X_X__
        .byte %10101010        ; X_X_X_X_
        .byte %01010100        ; _X_X_X__
        .byte %00111000        ; __XXX___
        .byte %00011000        ; ___XX___
        .byte %00111100        ; __XXXX__
        .byte %00000000        ; ________
        ; brick (same as frame 0)
        .byte %11111111        ; XXXXXXXX
        .byte %00110000        ; __XX____
        .byte %00110000        ; __XX____
        .byte %11111111        ; XXXXXXXX
        .byte %11111111        ; XXXXXXXX
        .byte %10000001        ; X______X
        .byte %10000001        ; X______X
        .byte %11111111        ; XXXXXXXX
        ; player
        .byte %00111100        ; __XXXX__
        .byte %01111110        ; _XXXXXX_
        .byte %00111100        ; __XXXX__
        .byte %10011000        ; X__XX___
        .byte %11111111        ; XXXXXXXX
        .byte %00011001        ; ___XX__X
        .byte %00100100        ; __X__X__
        .byte %11000110        ; XX___XX_
        ; monster
        .byte %00000010        ; ______X_
        .byte %01111110        ; _XXXXXX_
        .byte %01011010        ; _X_XX_X_
        .byte %00111100        ; __XXXX__
        .byte %10011000        ; X__XX___
        .byte %11111111        ; XXXXXXXX
        .byte %00011000        ; ___XX___
        .byte %10011001        ; X__XX__X
        ; monster1
        .byte %01000010        ; _X____X_
        .byte %00111100        ; __XXXX__
        .byte %01011010        ; _X_XX_X_
        .byte %00100100        ; __X__X__
        .byte %10011000        ; X__XX___
        .byte %11111111        ; XXXXXXXX
        .byte %00011000        ; ___XX___
        .byte %01100110        ; _XX__XX_
        ; bullet
        .byte %00000000        ; ________
        .byte %00000000        ; ________
        .byte %00011000        ; ___XX___
        .byte %00101100        ; __X_XX__
        .byte %00111100        ; __XXXX__
        .byte %00011000        ; ___XX___
        .byte %00000000        ; ________
        .byte %00000000        ; ________
        ; blood
        .byte %00000000        ; ________
        .byte %00000100        ; _____X__
        .byte %01010000        ; _X_X____
        .byte %00000010        ; _______X
        .byte %00100000        ; __X_____
        .byte %00000101        ; _____X_X
        .byte %00101000        ; __X_X___
        .byte %00000000        ; ________
coin1:
        ; PETSCII 113 filled circle
        .byte %00000000        ; __XXXX__
        .byte %00111100        ; _XXX_XX_
        .byte %01111010        ; XXXX__XX
        .byte %01111110        ; XXXXX_XX
        .byte %01111110        ; XXXXXXXX
        .byte %01111110        ; XXXXXXXX
        .byte %00111100        ; _XXXXXX_
        .byte %00000000        ; __XXXX__
