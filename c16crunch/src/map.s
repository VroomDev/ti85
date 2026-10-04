;; playfield[512] — collision / world (SPEC.md)

.include "game.inc"

.export playfield
.export map_clear
.export map_set
.export map_get
.export map_set_cell
.export map_get_cell
.export map_set_xy
.export cell_rc
.exportzp cell

.segment "PLAYFIELD"
playfield: .res LEVEL_SIZE

.segment "ZEROPAGE"
mapp:   .res 2
cell:   .res 2

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

;; cell = index 0..511. High bit above that is dropped.
map_at:
        lda cell
        clc
        adc #<playfield
        sta mapp
        lda cell+1
        and #((LEVEL_SIZE-1) >> 8)
        adc #>playfield
        sta mapp+1
        rts

;; A=char
map_set_cell:
        pha
        jsr map_at
        pla
        ldy #0
        sta (mapp),y
        rts

map_get_cell:
        jsr map_at
        ldy #0
        lda (mapp),y
        rts

;; A=char, X=index low, Y=index high
map_set_xy:
        pha
        txa
        clc
        adc #<playfield
        sta mapp
        tya
        and #((LEVEL_SIZE-1) >> 8)
        adc #>playfield
        sta mapp+1
        pla
        ldy #0
        sta (mapp),y
        rts

;; cell → X=column, Y=row
cell_rc:
        lda cell
        and #(PF_COLS-1)
        pha
        lda cell+1
        and #((LEVEL_SIZE-1) >> 8)
        asl a
        asl a
        asl a
        sta map_hi
        lda cell
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        ora map_hi
        tay
        pla
        tax
        rts
