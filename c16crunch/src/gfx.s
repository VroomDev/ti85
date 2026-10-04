;; TED graphics: copy ROM charset, then point $FF13 at RAM. Blit only in VBlank.

.include "game.inc"

.export init_graphics
.export wait_vrefresh
.export blit_playfield
.export clear_screen
.export draw_hud

.import playfield
.import hurt_dur

.segment "ZEROPAGE"
src:    .res 2
dst:    .res 2
col:    .res 2
row:    .res 1

.segment "BSS"
anim:   .res 1

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
@gl:    lda $D000+$51*8,x       ; PETSCII 113 ●
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
;; Monster glyphs $63/$64 swap each blit. Color stays with the type.
blit_playfield:
        lda anim
        eor #1
        sta anim
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
        ldx #COL_RED
        bne @flip
@maybe1:
        cmp #CHAR_MONSTER1
        bne @draw
        ldx #COL_PURPLE
@flip:  lda anim
        beq @g0
        lda #CHAR_MONSTER1
        bne @got
@g0:    lda #CHAR_MONSTER
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
