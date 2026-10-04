;; playfield[512] — collision / world (SPEC.md)

.include "game.inc"

.export playfield
.export map_clear
.export map_set
.export map_get

.segment "PLAYFIELD"
playfield: .res LEVEL_SIZE

.segment "ZEROPAGE"
mapp:   .res 2

.segment "BSS"
map_hi: .res 1

.segment "CODE"

map_clear:
        lda #<playfield
        sta mapp
        lda #>playfield
        sta mapp+1
        ldx #2
        lda #CHAR_EMPTY
        ldy #0
@pg:    sta (mapp),y
        iny
        bne @pg
        inc mapp+1
        dex
        bne @pg
        rts

;; X=col Y=row → mapp = playfield + Y*32 + X
map_addr:
        lda #<playfield
        sta mapp
        lda #>playfield
        sta mapp+1
        lda #0
        sta map_hi
        tya
        asl a
        rol map_hi
        asl a
        rol map_hi
        asl a
        rol map_hi
        asl a
        rol map_hi
        asl a
        rol map_hi
        clc
        adc mapp
        sta mapp
        lda map_hi
        adc mapp+1
        sta mapp+1
        txa
        clc
        adc mapp
        sta mapp
        bcc @ok
        inc mapp+1
@ok:    rts

;; A=char X=col Y=row
map_set:
        pha
        jsr map_addr
        pla
        ldy #0
        sta (mapp),y
        rts

;; X=col Y=row → A=char
map_get:
        jsr map_addr
        ldy #0
        lda (mapp),y
        rts
