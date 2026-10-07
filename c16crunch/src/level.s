;; 30×14 maze centered in the 32×16 playfield. 8-bit LFSR shuffles the carve. 16-bit LFSR picks cells.

;; One-cell margin. The maze edge itself is not carved.
MAZE_R0         = 1
MAZE_C0         = 1
MAZE_H          = 14
MAZE_W          = 30

.include "game.inc"

.export load_level
.export player_at
.export level
.export score
.export health
.export hiscore
.export coinsleft
.export lfsr
.export fast_rand

.import map_set
.import map_get
.import map_set_cell
.import map_get_cell
.import cell_rc
.import playfield
.importzp cell

MAZE_FRAME      = 7

.segment "ZEROPAGE"
frm:    .res 2

.segment "BSS"
level:          .res 1
score:          .res 2
health:         .res 1
hiscore:        .res 2
coinsleft:      .res 1
player_at:      .res 2
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
        lda level
        cmp #99
        bcs @walls
        jsr seed_byte
        sta lfsr
@walls: jsr fill_walls
        jsr carve
        jsr seed_byte
        sta rng16
        lda #0
        sta rng16+1
        jsr rand16
        lda #240
        sta player_at
        lda #0
        sta player_at+1
        jsr place_ring
        lda level
        cmp #25
        bcc @capped
        lda #25
@capped:
        sta gen_n
        beq @done
@batch: jsr place_wander
        jsr place_wander
        jsr place_chase
        jsr place_chase
        jsr place_coins
        jsr place_coins
        jsr place_trees
        jsr place_trees
        jsr place_trees
        jsr place_trees
        dec gen_n
        bne @batch
        jsr place_space
        jsr place_ring
@done:  jsr plant_hedge
        jmp count_coins
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

;; Tree on every edge cell. A bullet clears a tree, which opens a hole.
plant_hedge:
        lda #<playfield
        sta frm
        lda #>playfield
        sta frm+1
        ldx #PF_ROWS
@row:   lda #CHAR_TREE
        ldy #0
        sta (frm),y
        ldy #PF_COLS-1
        sta (frm),y
        cpx #PF_ROWS
        beq @fill
        cpx #1
        bne @adv
@fill:  ldy #PF_COLS-2
@span:  sta (frm),y
        dey
        bne @span
@adv:   clc
        lda frm
        adc #PF_COLS
        sta frm
        bcc @nx
        inc frm+1
@nx:    dex
        bne @row
        rts

;; -----------------------------------------------------------------------
;; Depth-first carve. Software stack, same order as the C recursion.

carve:
        lda #0
        sta maze_sp
        lda #MAZE_R0+1
        ldy #MAZE_C0+1
        jmp enter_rc

;; A = row, Y = col. Opens the cell, shuffles, pushes, continues.
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
        cmp #MAZE_R0+1
        bcc @next
        cmp #MAZE_R0+MAZE_H-1
        bcs @next
        lda nc
        cmp #MAZE_C0+1
        bcc @next
        cmp #MAZE_C0+MAZE_W-1
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
;; Placement. One rand16() & 511, then up to 16 steps of SPOT_STRIDE.

find_empty:
        jsr rand16
        jsr idx_from_rng
        jsr consider
        bcc @yes
        lda #16
        sta try_n
@step:  lda idx
        clc
        adc #SPOT_STRIDE
        sta idx
        lda idx+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta idx+1
        jsr consider
        bcc @yes
        dec try_n
        bne @step
        sec
        rts
@yes:   clc
        rts

idx_from_rng:
        lda rng16
        sta idx
        lda rng16+1
        and #1
        sta idx+1
        rts

consider:
        lda idx
        cmp player_at
        bne @get
        lda idx+1
        cmp player_at+1
        beq @no
@get:   lda idx
        sta cell
        lda idx+1
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @no
        clc
        rts
@no:    sec
        rts

place_ring:
        lda player_at
        sta cell
        lda player_at+1
        sta cell+1
        jsr cell_rc
        stx ctmp
        sty rtmp
        ldx #0
@n:     lda ctmp
        clc
        adc ring_dc,x
        cmp #PF_COLS
        bcs @adv
        lda rtmp
        clc
        adc ring_dr,x
        cmp #PF_ROWS
        bcs @adv
        txa
        pha
        lda player_at
        clc
        adc ring_lo,x
        sta cell
        lda player_at+1
        adc ring_hi,x
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @pop
        lda #CHAR_COIN
        jsr map_set_cell
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
        jsr put_idx
@no:    rts

place_chase:
        jsr find_empty
        bcs @no
        lda #CHAR_MONSTER1
        jsr put_idx
@no:    rts

place_coins:
        lda #3
        sta bunch
@c:     jsr find_empty
        bcs @no
        lda #CHAR_COIN
        jsr put_idx
        dec bunch
        bne @c
@no:    rts

place_trees:
        jsr rand16
        jsr idx_from_rng
        jsr brick_at
        bcs @no
        lda #CHAR_TREE
        jsr put_idx
@no:    rts

;; level<<2 hallways, or 60 when level is greater than 60.
place_space:
        lda level
        cmp #16         ; Check if level >= X (value is greater than X)
        bcc @shift
        lda #16        ; Cap value at X
@shift: asl a
        asl a
        sta bunch
        beq @out
@more:  jsr space_one
        dec bunch
        bne @more
@out:   rts             ; Added return instruction to complete routine


;; rand512, then (index + 1) & 511 until a brick with space above or to the left.
;; One full lap (512 steps). No hit: skip this hallway.
;; Space above punches down. Space to the left punches right. Both: punch down.
space_one:
        jsr rand16
        jsr idx_from_rng
        lda #2
        sta pages
        lda #0
        sta try_n
@step:  inc idx
        bne @hi
        inc idx+1
@hi:    lda idx+1
        and #((LEVEL_SIZE-1) >> 8)
        sta idx+1
        jsr brick_at
        bcs @next
        jsr above_empty
        bcc @down
        jsr left_empty
        bcs @next
        lda #1
        bne @hall
@down:  lda #0
@hall:  jmp carve_hall
@next:  inc try_n
        bne @step
        dec pages
        bne @step
        rts

;; A = 0 punch down, A = 1 punch right. idx is the first brick.
;; Bricks become empty until the next empty cell. That cell stays empty.
carve_hall:
        sta dir
        lda #2
        sta pages
        lda #0
        sta try_n
@cell:  jsr brick_at
        bcs @stop
        lda #CHAR_EMPTY
        jsr put_idx
        lda dir
        bne @right
        lda idx
        clc
        adc #<PF_COLS
        sta idx
        lda idx+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta idx+1
        jmp @lim
@right: inc idx
        bne @msk
        inc idx+1
@msk:   lda idx+1
        and #((LEVEL_SIZE-1) >> 8)
        sta idx+1
@lim:   inc try_n
        bne @cell
        dec pages
        bne @cell
@stop:  rts

;; C=0 if the cell above idx is empty.
above_empty:
        lda idx+1
        bne @ok
        lda idx
        cmp #PF_COLS
        bcc @no
@ok:    lda idx
        sec
        sbc #<PF_COLS
        sta cell
        lda idx+1
        sbc #>PF_COLS
        sta cell+1
        jmp cell_empty
@no:    sec
        rts

;; C=0 if the cell left of idx is empty. Stays on this row.
left_empty:
        lda idx
        and #(PF_COLS-1)
        beq @no
        lda idx
        sec
        sbc #1
        sta cell
        lda idx+1
        sbc #0
        sta cell+1
        jmp cell_empty
@no:    sec
        rts

;; C=0 if cell is empty
cell_empty:
        jsr map_get_cell
        cmp #CHAR_EMPTY
        beq @yes
        sec
        rts
@yes:   clc
        rts

brick_at:
        lda idx
        sta cell
        lda idx+1
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_BRICK
        beq @yes
        sec
        rts
@yes:   clc
        rts

;; A = char written at idx
put_idx:
        pha
        lda idx
        sta cell
        lda idx+1
        sta cell+1
        pla
        jmp map_set_cell

;; Upper RAM ($2A00+). After plant_hedge; sets coinsleft from the finished map.
.segment "CODEHI"
count_coins:
        lda #0
        sta coinsleft
        lda #<playfield
        sta frm
        lda #>playfield
        sta frm+1
        ldx #>(LEVEL_SIZE)
        ldy #0
@c:     lda (frm),y
        cmp #CHAR_COIN
        bne @n
        inc coinsleft
@n:     iny
        bne @c
        inc frm+1
        dex
        bne @c
        rts

.segment "RODATA"

dr_tab: .byte $fe, $02, $00, $00
dc_tab: .byte $00, $00, $fe, $02
mid_dr: .byte $ff, $01, $00, $00
mid_dc: .byte $00, $00, $ff, $01

ring_dr:.byte $ff, $ff, $ff, $00, $00, $01, $01, $01
ring_dc:.byte $ff, $00, $01, $ff, $01, $ff, $00, $01
ring_lo:.byte <(-PF_COLS-1), <(-PF_COLS), <(-PF_COLS+1), <(-1), <1
        .byte <(PF_COLS-1), <PF_COLS, <(PF_COLS+1)
ring_hi:.byte >(-PF_COLS-1), >(-PF_COLS), >(-PF_COLS+1), >(-1), >1
        .byte >(PF_COLS-1), >PF_COLS, >(PF_COLS+1)
