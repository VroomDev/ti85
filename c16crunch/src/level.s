;; 32×16 maze. 8-bit LFSR shuffles the carve. 16-bit LFSR picks cells.

.include "game.inc"

.export load_level
.export player_sx
.export player_sy
.export level
.export score
.export health
.export hiscore
.export coinsleft
.export lfsr
.export fast_rand

.import map_set
.import map_get
.import playfield

MAZE_FRAME      = 7
TRY_RAND        = 32

.segment "ZEROPAGE"
frm:    .res 2

.segment "BSS"
level:          .res 1
score:          .res 2
health:         .res 1
hiscore:        .res 2
coinsleft:      .res 1
player_sx:      .res 1
player_sy:      .res 1
lfsr:           .res 1
rng16:          .res 2

maze_sp:        .res 1
maze_stk:       .res MAZE_ROOMS * MAZE_FRAME

dirs:           .res 4
rndb:           .res 1
rtmp:           .res 1
ctmp:           .res 1
nr:             .res 1
nc:             .res 1
dir:            .res 1
midrow:         .res 1
gen_n:          .res 1
try_n:          .res 1
pages:          .res 1
idx:            .res 2
cell_c:         .res 1
cell_r:         .res 1
tcol:           .res 1
trow:           .res 1
bunch:          .res 1
mul_lo:         .res 1
mul_hi:         .res 1
fidx:           .res 1

.segment "CODE"

;; A = new lfsr. Period 255, so a non-zero seed never becomes 0.
fast_rand:
        lda lfsr
        lsr a
        bcc @keep
        eor #$b8
@keep:  sta lfsr
        rts

rand16:
        lsr rng16+1
        ror rng16
        bcc @keep
        lda rng16
        eor #$08
        sta rng16
        lda rng16+1
        eor #$d0
        sta rng16+1
@keep:  rts

;; Level, or 255 when the level is 0. High byte of rng16 stays 0.
seed_byte:
        lda level
        bne @ok
        lda #$ff
@ok:    rts

;; A = 1-based level (already stored by the caller).
load_level:
        jsr seed_byte
        sta lfsr
        jsr fill_walls
        jsr carve

        jsr seed_byte
        sta rng16
        lda #0
        sta rng16+1
        sta coinsleft

        lda #$ff
        sta player_sx
        sta player_sy
        jsr find_empty
        bcc @have
        ldx #1
        ldy #1
@have:  stx player_sx
        sty player_sy
        jsr place_ring

        lda level
        sta gen_n
        beq @done
@batch: jsr place_wander
        jsr place_chase
        jsr place_coins
        jsr place_trees
        dec gen_n
        bne @batch
@done:  rts

fill_walls:
        lda #<playfield
        sta frm
        lda #>playfield
        sta frm+1
        ldx #2
        ldy #0
        lda #CHAR_BRICK
@pg:    sta (frm),y
        iny
        bne @pg
        inc frm+1
        dex
        bne @pg
        rts

;; -----------------------------------------------------------------------
;; Depth-first carve. Software stack, same order as the C recursion.

carve:
        lda #0
        sta maze_sp
        lda #1
        ldy #1
        jmp enter_rc

;; A = row, Y = col. Marks the cell, shuffles, pushes, continues.
enter_rc:
        sta rtmp
        sty ctmp
        lda #CHAR_EMPTY
        ldx ctmp
        ldy rtmp
        jsr map_set
        jsr make_dirs
        lda maze_sp
        cmp #MAZE_ROOMS
        bcs carve_loop
        inc maze_sp
        jsr frame_ptr
        ldy #0
        lda rtmp
        sta (frm),y
        iny
        lda ctmp
        sta (frm),y
        iny
        lda #0
        sta (frm),y
        ldx #0
@cp:    iny
        lda dirs,x
        sta (frm),y
        inx
        cpx #4
        bne @cp
        jmp carve_loop

carve_loop:
        lda maze_sp
        bne @go
        rts
@go:    jsr frame_ptr
        ldy #2
        lda (frm),y
        cmp #4
        bcc @try
        dec maze_sp
        jmp carve_loop
@try:   clc
        adc #3
        tay
        lda (frm),y
        sta dir
        ldy #0
        lda (frm),y
        sta rtmp
        iny
        lda (frm),y
        sta ctmp
        ldx dir
        lda rtmp
        clc
        adc dr_tab,x
        sta nr
        lda ctmp
        clc
        adc dc_tab,x
        sta nc
        lda nr
        beq @next
        cmp #15
        bcs @next
        lda nc
        beq @next
        cmp #31
        bcs @next
        ldx nc
        ldy nr
        jsr map_get
        cmp #CHAR_BRICK
        bne @next
        ldx dir
        lda rtmp
        clc
        adc mid_dr,x
        sta midrow
        lda ctmp
        clc
        adc mid_dc,x
        tax
        ldy midrow
        lda #CHAR_EMPTY
        jsr map_set
        jsr frame_ptr
        ldy #2
        lda (frm),y
        clc
        adc #1
        sta (frm),y
        lda nr
        ldy nc
        jmp enter_rc
@next:  jsr frame_ptr
        ldy #2
        lda (frm),y
        clc
        adc #1
        sta (frm),y
        jmp carve_loop

;; maze_sp is the count. Point frm at frame (maze_sp-1).
frame_ptr:
        lda maze_sp
        sec
        sbc #1
        sta fidx
        lda #0
        sta mul_hi
        lda fidx
        asl a
        rol mul_hi
        asl a
        rol mul_hi
        asl a
        rol mul_hi
        sec
        sbc fidx
        bcs @nb
        dec mul_hi
@nb:    clc
        adc #<maze_stk
        sta frm
        lda mul_hi
        adc #>maze_stk
        sta frm+1
        rts

;; dirs = {0,1,2,3} then one biased Fisher-Yates step from fast_rand.
make_dirs:
        lda #0
        sta dirs
        lda #1
        sta dirs+1
        lda #2
        sta dirs+2
        lda #3
        sta dirs+3
        jsr fast_rand
        sta rndb
        and #3
        tay
        ldx dirs+3
        lda dirs,y
        sta dirs+3
        txa
        sta dirs,y
        lda rndb
        lsr a
        lsr a
        and #3
        cmp #3
        bne @j2
        lda #2
@j2:    tay
        ldx dirs+2
        lda dirs,y
        sta dirs+2
        txa
        sta dirs,y
        lda rndb
        lsr a
        lsr a
        lsr a
        lsr a
        and #1
        tay
        ldx dirs+1
        lda dirs,y
        sta dirs+1
        txa
        sta dirs,y
        rts

;; -----------------------------------------------------------------------
;; Placement. rand16() & 511 picks a cell.

find_empty:
        lda #TRY_RAND
        sta try_n
@try:   jsr rand16
        jsr idx_from_rng
        jsr consider
        bcc @yes
        dec try_n
        bne @try
        lda #2
        sta pages
        ldy #0
@scan:  jsr consider
        bcc @yes
        inc idx
        bne @msk
        inc idx+1
@msk:   lda idx+1
        and #1
        sta idx+1
        iny
        bne @scan
        dec pages
        bne @scan
        sec
        rts
@yes:   ldx cell_c
        ldy cell_r
        clc
        rts

idx_from_rng:
        lda rng16
        sta idx
        lda rng16+1
        and #1
        sta idx+1
        rts

idx_xy:
        lda idx
        and #31
        sta cell_c
        lda idx+1
        and #1
        asl a
        asl a
        asl a
        sta cell_r
        lda idx
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        ora cell_r
        sta cell_r
        rts

consider:
        jsr idx_xy
        ldx cell_c
        ldy cell_r
        cpx player_sx
        bne @get
        cpy player_sy
        beq @no
@get:   jsr map_get
        cmp #CHAR_EMPTY
        bne @no
        clc
        rts
@no:    sec
        rts

place_ring:
        ldx #0
@n:     lda player_sx
        clc
        adc ring_dc,x
        cmp #PF_COLS
        bcs @adv
        sta tcol
        lda player_sy
        clc
        adc ring_dr,x
        cmp #PF_ROWS
        bcs @adv
        sta trow
        txa
        pha
        ldx tcol
        ldy trow
        jsr map_get
        cmp #CHAR_EMPTY
        bne @pop
        lda #CHAR_COIN
        ldx tcol
        ldy trow
        jsr map_set
        inc coinsleft
@pop:   pla
        tax
@adv:   inx
        cpx #8
        bne @n
        rts

place_wander:
        jsr find_empty
        bcs @no
        lda rng16+1
        lsr a                    ; drop bit 8; bits 9–10 → facing
        and #3
        clc
        adc #CHAR_WANDER_U
        jsr map_set
@no:    rts

place_chase:
        jsr find_empty
        bcs @no
        lda #CHAR_MONSTER1
        jsr map_set
@no:    rts

place_coins:
        lda #3
        sta bunch
@c:     jsr find_empty
        bcs @no
        lda #CHAR_COIN
        jsr map_set
        inc coinsleft
        dec bunch
        bne @c
@no:    rts

place_trees:
        lda #3
        sta bunch
@t:     jsr find_empty
        bcs @no
        lda #CHAR_TREE
        jsr map_set
        dec bunch
        bne @t
@no:    rts

.segment "RODATA"

dr_tab: .byte $fe, $02, $00, $00
dc_tab: .byte $00, $00, $fe, $02
mid_dr: .byte $ff, $01, $00, $00
mid_dc: .byte $00, $00, $ff, $01

ring_dr:.byte $ff, $ff, $ff, $00, $00, $01, $01, $01
ring_dc:.byte $ff, $00, $01, $ff, $01, $ff, $00, $01
