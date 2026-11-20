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
.export rng16
.export fast_rand
.export rand16

.import map_set
.import map_get
.import map_set_cell
.import map_get_cell
.import cell_rc
.import playfield
.import cell
.import two_player

MAZE_FRAME      = 7

;; (frm),y needs a ZP pointer.
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
whitener:       .res 1          ; ++ then XOR into fast_rand return
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
ring_org:       .res 2

.segment "CODE"

;; Advance lfsr (never store 0). Return (lfsr ^ (++whitener)).
fast_rand:
        lda lfsr
        lsr a
        bcc @keep
        eor #$fa
@keep:  sta lfsr
        inc whitener
        eor whitener
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
        sei                     ; map ptrs live in ZP; keep IRQ off while building
.if SEED_LEVEL_RAND
        lda level
        cmp #99
        bcs @walls
        jsr seed_byte
        sta lfsr
@walls:
.endif
        jsr fill_walls
        jsr carve
.if SEED_LEVEL_RAND
        jsr seed_byte
        sta rng16
        lda #0
        sta rng16+1
.endif
        jsr rand16
        lda #240
        sta player_at
        lda #0
        sta player_at+1
        lda two_player
        beq @ring
        ;; Clear P2 2×2 spawn (TL = 240 + P2_SPAWN_OFF)
        lda #240+P2_SPAWN_OFF
        sta cell
        lda #0
        sta cell+1
        jsr clear_player_foot
@ring:  jsr place_ring
        lda level
        cmp #20
        bcc @capped
        lda #20
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
@done:  jsr open_coop_start
        jsr plant_hedge
        jsr count_coins
        cli
        rts
fill_walls:
        lda #<playfield
        sta frm
        lda #>playfield
        sta frm+1
        ldx #2
        ldy #0
        lda #CHAR_EMPTY
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
        lda #MAZE_R0+2          ; row 3 (lattice +1,+1 from old start)
        ldy #MAZE_C0+2          ; col 3
        jmp enter_rc

;; A = row, Y = col. Lays a 2×2 wall brick, shuffles, pushes, continues.
enter_rc:
        sta rtmp
        sty ctmp
        ldx ctmp
        ldy rtmp
        jsr brick_2x2
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
        ;; Neighbor 2×2 must fit: rows 3..11, cols 3..27 (step-4 lattice)
        lda nr
        cmp #MAZE_R0+2
        bcc @next
        cmp #MAZE_R0+MAZE_H-3
        bcs @next
        lda nc
        cmp #MAZE_C0+2
        bcc @next
        cmp #MAZE_C0+MAZE_W-3
        bcs @next
        jsr empty_2x2
        bcs @next
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
        jsr brick_2x2
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

;; X=col Y=row — write CHAR_BRICK on the 2×2 block. Uses mul_lo/mul_hi.
brick_2x2:
        stx mul_lo
        sty mul_hi
        lda #CHAR_BRICK
        jsr map_set
        ldx mul_lo
        inx
        ldy mul_hi
        lda #CHAR_BRICK
        jsr map_set
        ldx mul_lo
        ldy mul_hi
        iny
        lda #CHAR_BRICK
        jsr map_set
        ldx mul_lo
        inx
        ldy mul_hi
        iny
        lda #CHAR_BRICK
        jmp map_set

;; nr/nc = top-left. C=0 if all four cells are empty. Preserves rtmp/ctmp.
empty_2x2:
        ldx nc
        ldy nr
        jsr map_get
        cmp #CHAR_EMPTY
        bne @no
        ldx nc
        inx
        ldy nr
        jsr map_get
        cmp #CHAR_EMPTY
        bne @no
        ldx nc
        ldy nr
        iny
        jsr map_get
        cmp #CHAR_EMPTY
        bne @no
        ldx nc
        inx
        ldy nr
        iny
        jsr map_get
        cmp #CHAR_EMPTY
        bne @no
        clc
        rts
@no:    sec
        rts

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
        lsr a                    ; j3 = (r >> 1) & 3
        and #3
        tay
        ldx dirs+3
        lda dirs,y
        sta dirs+3
        txa
        sta dirs,y
        lda rndb
        lsr a                    ; j2 = (r >> 3) & 3; 3 → 2
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
        lsr a                    ; j1 = (r >> 5) & 1
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
;; Placement helpers in upper RAM.
.segment "CODEHI"

place_ring:
        lda player_at
        sta ring_org
        lda player_at+1
        sta ring_org+1
        jsr place_ring_org
        lda two_player
        beq @out
        lda player_at
        clc
        adc #P2_SPAWN_OFF
        sta ring_org
        lda player_at+1
        adc #0
        sta ring_org+1
        jsr place_ring_org
@out:   rts

;; Coins on empty 8-neighbors of each cell of the 2×2 at ring_org (TL).
place_ring_org:
        lda ring_org
        sta mul_lo
        lda ring_org+1
        sta mul_hi
        jsr place_ring_one
        lda mul_lo
        clc
        adc #1
        sta ring_org
        lda mul_hi
        adc #0
        sta ring_org+1
        jsr place_ring_one
        lda mul_lo
        clc
        adc #<PF_COLS
        sta ring_org
        lda mul_hi
        adc #>PF_COLS
        sta ring_org+1
        jsr place_ring_one
        lda ring_org
        clc
        adc #1
        sta ring_org
        lda ring_org+1
        adc #0
        sta ring_org+1
        ;; fall through
place_ring_one:
        lda ring_org
        sta cell
        lda ring_org+1
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
        lda ring_org
        clc
        adc ring_lo,x
        sta cell
        lda ring_org+1
        adc ring_hi,x
        sta cell+1
        jsr is_spawn_cell
        bcs @pop
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

;; C=1 if cell is any quadrant of P1 or (2P) P2 spawn footprint,
;; or inside the 2P 7×4 start box.
is_spawn_cell:
        jsr in_coop_box
        bcs @yes
        lda #0
        sta dirs                 ; 0 = P1 TL base in player_at
        jsr spawn_foot_has
        bcs @yes
        lda two_player
        beq @no
        lda #P2_SPAWN_OFF
        sta dirs
        jsr spawn_foot_has
        bcs @yes
@no:    clc
        rts
@yes:   sec
        rts

;; 2P only. C=1 if cell is in the 7×4 box whose top-left is one row
;; above and one column left of P1. That box is:
;;   OOOOOOO
;;   O     O
;;   O     O
;;   OOOOOOO
;; Players occupy the XX holes; the middle column stays empty.
in_coop_box:
        lda two_player
        beq @no
        lda cell
        sec
        sbc player_at
        sta nr
        lda cell+1
        sbc player_at+1
        and #1
        sta nc
        lda nr
        clc
        adc #<(PF_COLS+1)
        sta nr
        lda nc
        adc #>(PF_COLS+1)
        and #1
        bne @no
        lda nr
        cmp #<(PF_COLS*3+7)
        bcs @no
        and #PF_COLS-1
        cmp #7
        bcs @no
        sec
        rts
@no:    clc
        rts

;; After placement, force the 2P start pattern. O = coin, interior = empty.
open_coop_start:
        lda two_player
        bne @go
        rts
@go:    lda player_at
        sec
        sbc #<(PF_COLS+1)
        sta mul_lo
        lda player_at+1
        sbc #>(PF_COLS+1)
        and #((LEVEL_SIZE-1) >> 8)
        sta mul_hi
        lda #0
        sta rtmp
@row:   lda #0
        sta ctmp
        lda mul_lo
        sta cell
        lda mul_hi
        sta cell+1
@col:   lda rtmp
        beq @coin
        cmp #3
        beq @coin
        lda ctmp
        beq @coin
        cmp #6
        beq @coin
        lda #CHAR_EMPTY
        beq @set
@coin:  lda #CHAR_COIN
@set:   jsr map_set_cell
        inc cell
        bne @hi
        inc cell+1
@hi:    inc ctmp
        lda ctmp
        cmp #7
        bne @col
        lda mul_lo
        clc
        adc #<PF_COLS
        sta mul_lo
        lda mul_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta mul_hi
        inc rtmp
        lda rtmp
        cmp #4
        bne @row
        rts

;; dirs = column offset from player_at for TL. C=1 if cell in that 2×2.
spawn_foot_has:
        lda player_at
        clc
        adc dirs
        sta mul_lo
        lda player_at+1
        adc #0
        sta mul_hi
        lda cell
        cmp mul_lo
        bne @tr
        lda cell+1
        cmp mul_hi
        beq @yes
@tr:    lda mul_lo
        clc
        adc #1
        sta nr
        lda mul_hi
        adc #0
        sta nc
        lda cell
        cmp nr
        bne @bl
        lda cell+1
        cmp nc
        beq @yes
@bl:    lda mul_lo
        clc
        adc #<PF_COLS
        sta nr
        lda mul_hi
        adc #>PF_COLS
        sta nc
        lda cell
        cmp nr
        bne @br
        lda cell+1
        cmp nc
        beq @yes
@br:    lda nr
        clc
        adc #1
        sta nr
        lda nc
        adc #0
        sta nc
        lda cell
        cmp nr
        bne @no
        lda cell+1
        cmp nc
        bne @no
@yes:   sec
        rts
@no:    clc
        rts

;; Clear 2×2 at cell (TL).
clear_player_foot:
        lda cell
        sta mul_lo
        lda cell+1
        sta mul_hi
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda mul_lo
        clc
        adc #1
        sta cell
        lda mul_hi
        adc #0
        sta cell+1
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda mul_lo
        clc
        adc #<PF_COLS
        sta cell
        lda mul_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_EMPTY
        jmp map_set_cell

place_wander:
        jsr find_empty_2x2
        bcs @no
        lda rng16+1
        lsr a                    ; drop bit 8; bits 9–10 → facing
        and #3
        clc
        adc #CHAR_WANDER_U
        jsr stamp_monster_idx
@no:    rts

place_chase:
        jsr find_empty_2x2
        bcs @no
        lda rng16+1
        lsr a
        and #3
        clc
        adc #CHAR_CHASE_U
        jsr stamp_monster_idx
@no:    rts

;; A = TL char; idx is top-left. Stamp full 2×2.
stamp_monster_idx:
        pha
        lda idx
        sta cell
        lda idx+1
        sta cell+1
        pla
        ;; fall through
;; A = TL char; cell = top-left. idx must also be TL.
stamp_monster_cell:
        sta midrow              ; TL char
        jsr map_set_cell
        lda midrow
        cmp #CHAR_MONSTER1
        beq @ch
        cmp #CHAR_CHASE_U
        bcc @w
        cmp #CHAR_CHASE_R+1
        bcc @ch
@w:     lda #CHAR_WANDER_TR
        sta dirs                ; reuse dirs[0..2] as TR/BL/BR
        lda #CHAR_WANDER_BL
        sta dirs+1
        lda #CHAR_WANDER_BR
        sta dirs+2
        bne @body
@ch:    lda #CHAR_CHASE_TR
        sta dirs
        lda #CHAR_CHASE_BL
        sta dirs+1
        lda #CHAR_CHASE_BR
        sta dirs+2
@body:  lda idx
        clc
        adc #1
        sta cell
        lda idx+1
        adc #0
        sta cell+1
        lda dirs
        jsr map_set_cell
        lda idx
        clc
        adc #<PF_COLS
        sta cell
        lda idx+1
        adc #>PF_COLS
        sta cell+1
        lda dirs+1
        jsr map_set_cell
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        sta cell+1
        lda dirs+2
        jmp map_set_cell

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


;; rand512, then (index + 1) & 511 until a brick with a 2-wide opening above or left.
;; Space above punches down (2 cols). Space left punches right (2 rows). Both: down.
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
        jsr brick_pair_h
        bcs @next
        jsr above_empty2
        bcc @down
        jsr left_empty2
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

;; A = 0 punch down (clear idx and idx+1 each step), A = 1 punch right (idx and idx+PF_COLS).
carve_hall:
        sta dir
        lda #2
        sta pages
        lda #0
        sta try_n
@cell:  jsr brick_pair_at
        bcs @stop
        jsr clear_hall_pair
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

;; Clear the 2-cell hall slice at idx (horizontal pair if dir=0, vertical if dir=1).
clear_hall_pair:
        lda #CHAR_EMPTY
        jsr put_idx
        lda dir
        bne @vert
        lda idx
        and #(PF_COLS-1)
        cmp #PF_COLS-1
        beq @out
        lda idx
        clc
        adc #1
        sta cell
        lda idx+1
        adc #0
        sta cell+1
        lda #CHAR_EMPTY
        jmp map_set_cell
@vert:  lda idx
        clc
        adc #<PF_COLS
        sta cell
        lda idx+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_EMPTY
        jmp map_set_cell
@out:   rts

;; C=0 if idx and idx+1 are both brick (and idx not at right edge).
brick_pair_h:
        lda idx
        and #(PF_COLS-1)
        cmp #PF_COLS-1
        beq @no
        jsr brick_at
        bcs @no
        lda idx
        clc
        adc #1
        sta cell
        lda idx+1
        adc #0
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_BRICK
        bne @no
        clc
        rts
@no:    sec
        rts

;; C=0 if the pair for current dir is still brick; else C=1 (stop punch).
brick_pair_at:
        lda dir
        bne @v
        jmp brick_pair_h
@v:     jsr brick_at
        bcs @no
        lda idx
        clc
        adc #<PF_COLS
        sta cell
        lda idx+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_BRICK
        bne @no
        clc
        rts
@no:    sec
        rts

;; C=0 if both cells above idx and idx+1 are empty.
above_empty2:
        lda idx+1
        bne @ok
        lda idx
        cmp #PF_COLS
        bcc @no
@ok:    lda idx
        and #(PF_COLS-1)
        cmp #PF_COLS-1
        beq @no
        lda idx
        sec
        sbc #<PF_COLS
        sta cell
        lda idx+1
        sbc #>PF_COLS
        sta cell+1
        jsr cell_empty
        bcs @no
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        sta cell+1
        jmp cell_empty
@no:    sec
        rts

;; C=0 if both cells left of idx and idx+PF_COLS are empty.
left_empty2:
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
        jsr cell_empty
        bcs @no
        lda cell
        clc
        adc #<PF_COLS
        sta cell
        lda cell+1
        adc #>PF_COLS
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

;; One rand16() & 511, then SPOT_STRIDE until a free cell or a full lap (512).
find_empty:
        jsr rand16
        jsr idx_from_rng
        lda #2
        sta pages
        lda #0
        sta try_n
@try:   jsr consider
        bcc @yes
        jsr stride_idx
        inc try_n
        bne @try
        dec pages
        bne @try
        sec
        rts
@yes:   clc
        rts

;; Free 2×2 interior block (for monsters).
find_empty_2x2:
        jsr rand16
        jsr idx_from_rng
        lda #2
        sta pages
        lda #0
        sta try_n
@try:   jsr consider_2x2
        bcc @yes
        jsr stride_idx
        inc try_n
        bne @try
        dec pages
        bne @try
        sec
        rts
@yes:   clc
        rts

stride_idx:
        lda idx
        clc
        adc #SPOT_STRIDE
        sta idx
        lda idx+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta idx+1
        rts

idx_from_rng:
        lda rng16
        sta idx
        lda rng16+1
        and #1
        sta idx+1
        rts

;; Empty, not a spawn cell, and not a hedge edge (plant_hedge would wipe it).
consider:
        lda idx
        sta cell
        lda idx+1
        sta cell+1
        jsr is_spawn_cell
        bcs @no
        jsr cell_rc
        txa
        beq @no
        cpx #PF_COLS-1
        beq @no
        tya
        beq @no
        cpy #PF_ROWS-1
        beq @no
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @no
        clc
        rts
@no:    sec
        rts

;; TL at idx; all four empty, interior, not spawn.
consider_2x2:
        jsr consider
        bcs @no
        jsr cell_rc
        cpx #PF_COLS-2
        bcs @no
        cpy #PF_ROWS-2
        bcs @no
        lda idx
        clc
        adc #1
        sta cell
        lda idx+1
        adc #0
        sta cell+1
        jsr is_spawn_cell
        bcs @no
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @no
        lda idx
        clc
        adc #<PF_COLS
        sta cell
        lda idx+1
        adc #>PF_COLS
        sta cell+1
        jsr is_spawn_cell
        bcs @no
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @no
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        sta cell+1
        jsr is_spawn_cell
        bcs @no
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @no
        clc
        rts
@no:    sec
        rts

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

dr_tab: .byte $fc, $04, $00, $00         ; ±4 room step
dc_tab: .byte $00, $00, $fc, $04
mid_dr: .byte $fe, $02, $00, $00         ; ±2 halfway 2×2
mid_dc: .byte $00, $00, $fe, $02

ring_dr:.byte $ff, $ff, $ff, $00, $00, $01, $01, $01
ring_dc:.byte $ff, $00, $01, $ff, $01, $ff, $00, $01
ring_lo:.byte <(-PF_COLS-1), <(-PF_COLS), <(-PF_COLS+1), <(-1), <1
        .byte <(PF_COLS-1), <PF_COLS, <(PF_COLS+1)
ring_hi:.byte >(-PF_COLS-1), >(-PF_COLS), >(-PF_COLS+1), >(-1), >1
        .byte >(PF_COLS-1), >PF_COLS, >(PF_COLS+1)
