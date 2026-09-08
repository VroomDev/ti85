;; playfield[128] — collision / world (SPEC.md)

.include "game.inc"

.export playfield
.export map_clear
.export map_set
.export map_get

.segment "PLAYFIELD"
playfield: .res LEVEL_SIZE

.segment "CODE"

map_clear:
        ldx #0
        lda #CHAR_EMPTY
:       sta playfield,x
        inx
        cpx #LEVEL_SIZE
        bne :-
        rts

;; A=char X=col Y=row
map_set:
        pha
        tya
        asl a
        asl a
        asl a
        asl a
        sta tmp
        txa
        clc
        adc tmp
        tax
        pla
        sta playfield,x
        rts

map_get:
        tya
        asl a
        asl a
        asl a
        asl a
        sta tmp
        txa
        clc
        adc tmp
        tax
        lda playfield,x
        rts

.segment "BSS"
tmp:    .res 1
