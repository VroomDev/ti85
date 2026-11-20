;; Player / monsters / bullet on playfield[512]
;; Per-player state is indexed by cur_pl (set from X on entry).

.include "game.inc"

.export init_sprites
.export update_player
.export update_monsters
.export update_bullet
.export pdir
.export bulletdir
.export game_over_flag
.export next_level_flag
.export inc_score
.export hurt_dur

.import input_bits
.import map_get_cell
.import map_set_cell
.import map_set_xy
.import playfield
.import player_at
.import cell
.import score
.import health
.import coinsleft
.import level
.import fast_rand
.import play_coin
.import play_kill
.import play_hurt
.import play_audio_frame
.import wait_vrefresh
.import blit_playfield
.import update_hud
.import two_player
.import frame

.segment "BSS"
;; Per-player (.res 2), indexed by cur_pl
pdir:           .res 2
bulletdir:      .res 2
move_cd:        .res 2
blt_left:       .res 2
blt_cd:         .res 2
pxyl:           .res 2
pxyh:           .res 2
bxyl:           .res 2
bxyh:           .res 2
fire_alt:       .res 2           ; 0/1: which leading-edge cell to fire from
cur_pl:         .res 1
;; Shared
hitxyval:       .res 1
hurt_dur:       .res 1
game_over_flag: .res 1
next_level_flag:.res 1
spot:           .res 2
mi:             .res 1
nleft:          .res 1
tdir:           .res 1
tx:             .res 1
ty:             .res 1
tdist:          .res 1
tslot:          .res 1
scan_pg:        .res 1
save_lo:        .res 1
save_hi:        .res 1
coin_hit:       .res 1
edge_lo:        .res 1
edge_hi:        .res 1
mon_coin:       .res 1          ; 1 = this edge cell may be a coin

;; (scan),y needs a ZP pointer.
.segment "ZEROPAGE"
scan:           .res 2

.segment "CODE"

init_sprites:
        lda #0
        sta spot
        sta spot+1
        sta game_over_flag
        sta next_level_flag
        sta hurt_dur
        sta bulletdir+1
        sta blt_left+1
        sta blt_cd+1
        sta move_cd+1
        ldx #0
        jsr init_one
        lda two_player
        beq @done
        ldx #1
        jsr init_one
@done:  rts

;; X = player slot
init_one:
        stx cur_pl
        lda #0
        sta bulletdir,x
        sta blt_left,x
        sta blt_cd,x
        sta move_cd,x
        sta fire_alt,x
        lda #DIR_RIGHT
        sta pdir,x
        cpx #0
        bne @p2
        lda player_at
        sta pxyl
        lda player_at+1
        sta pxyh
        jmp @put
@p2:    lda player_at
        clc
        adc #P2_SPAWN_OFF
        sta pxyl+1
        lda player_at+1
        adc #0
        sta pxyh+1
@put:   jsr load_pxy
        jmp stamp_player_2x2

;; cell = TL. Stamp player 2×2.
stamp_player_2x2:
        lda cell
        sta edge_lo
        lda cell+1
        sta edge_hi
        lda #CHAR_PLAYER
        jsr map_set_cell
        lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        sta cell+1
        lda #CHAR_PLAYER_TR
        jsr map_set_cell
        lda edge_lo
        clc
        adc #<PF_COLS
        sta cell
        lda edge_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_PLAYER_BL
        jsr map_set_cell
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_PLAYER_BR
        jmp map_set_cell

;; cell = TL. Clear 2×2.
clear_player_2x2:
        lda cell
        sta edge_lo
        lda cell+1
        sta edge_hi
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        sta cell+1
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda edge_lo
        clc
        adc #<PF_COLS
        sta cell
        lda edge_hi
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

inc_score:
        sed
        clc
        lda score
        adc #1
        sta score
        lda score+1
        adc #0
        sta score+1
        cld
        lda score
        cmp #$49
        beq @life
        cmp #$99
        bne @chirp
@life:  lda health
        cmp #9
        bcs @chirp
        inc health
@chirp: jmp play_coin

;; A = direction. cell becomes (cell + delta) & 511.
;; Up/down use PF_COLS. Left/right use 1.
add_dir:
        cmp #DIR_UP
        bne @down
        lda #<(-PF_COLS)
        ldx #>(-PF_COLS)
        jmp @add
@down:  cmp #DIR_DOWN
        bne @left
        lda #<PF_COLS
        ldx #0
        jmp @add
@left:  cmp #DIR_LEFT
        bne @right
        lda #<(-1)
        ldx #>(-1)
        jmp @add
@right: lda #<1
        ldx #0
@add:   clc
        adc cell
        sta cell
        txa
        adc cell+1
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        rts

load_pxy:
        ldx cur_pl
        lda pxyl,x
        sta cell
        lda pxyh,x
        sta cell+1
        rts

load_bxy:
        ldx cur_pl
        lda bxyl,x
        sta cell
        lda bxyh,x
        sta cell+1
        rts

load_spot:
        lda spot
        sta cell
        lda spot+1
        sta cell+1
        rts

save_pxy:
        ldx cur_pl
        lda cell
        sta pxyl,x
        lda cell+1
        sta pxyh,x
        rts

save_bxy:
        ldx cur_pl
        lda cell
        sta bxyl,x
        lda cell+1
        sta bxyh,x
        rts

.segment "CODEHI"

;; Stamp full 2×2 for every active player.
restamp_players:
        lda pxyl
        sta cell
        lda pxyh
        sta cell+1
        jsr stamp_player_2x2
        lda two_player
        beq @out
        lda pxyl+1
        sta cell
        lda pxyh+1
        sta cell+1
        jsr stamp_player_2x2
@out:   rts

;; C=1 if cell is any quadrant of any live player.
cell_is_player:
        ldx #0
        jsr foot_has_cell
        bcs @yes
        lda two_player
        beq @no
        ldx #1
        jsr foot_has_cell
        bcs @yes
@no:    clc
        rts
@yes:   sec
        rts

;; X = player slot. C=1 if cell is in that 2×2 footprint.
foot_has_cell:
        lda cell
        cmp pxyl,x
        bne @tr
        lda cell+1
        cmp pxyh,x
        beq @yes
@tr:    lda pxyl,x
        clc
        adc #1
        sta edge_lo
        lda pxyh,x
        adc #0
        sta edge_hi
        lda cell
        cmp edge_lo
        bne @bl
        lda cell+1
        cmp edge_hi
        beq @yes
@bl:    lda pxyl,x
        clc
        adc #<PF_COLS
        sta edge_lo
        lda pxyh,x
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
        lda cell
        cmp edge_lo
        bne @br
        lda cell+1
        cmp edge_hi
        beq @yes
@br:    lda edge_lo
        clc
        adc #1
        sta edge_lo
        lda edge_hi
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
        lda cell
        cmp edge_lo
        bne @no
        lda cell+1
        cmp edge_hi
        bne @no
@yes:   sec
        rts
@no:    clc
        rts

;; C=1 if bxy[cur_pl] matches any player (do not erase).
bxy_on_player:
        ldx cur_pl
        lda bxyl,x
        sta cell
        lda bxyh,x
        sta cell+1
        jmp cell_is_player

;; X = player slot on entry
update_player:
        stx cur_pl
        cpx #0
        bne @ready
        lda hurt_dur
        beq @ready
        dec hurt_dur
@ready: ldx cur_pl
        lda input_bits,x
        and #IN_FIRE
        beq @nof
        jsr do_fire
@nof:   ldx cur_pl
        lda input_bits,x
        and #(IN_UP|IN_DOWN|IN_LEFT|IN_RIGHT)
        bne @has
        lda #0
        sta move_cd,x
        rts
@has:   lda input_bits,x
        and #IN_UP
        beq @1
        lda #DIR_UP
        bne @set
@1:     lda input_bits,x
        and #IN_DOWN
        beq @2
        lda #DIR_DOWN
        bne @set
@2:     lda input_bits,x
        and #IN_LEFT
        beq @3
        lda #DIR_LEFT
        bne @set
@3:     lda #DIR_RIGHT
@set:   ldx cur_pl
        sta pdir,x
        lda input_bits,x
        and #IN_FIRE
        bne @aim
        lda move_cd,x
        beq @go
        dec move_cd,x
        rts
@aim:   rts
@go:    lda #MOVE_DELAY
        sta move_cd,x
        jsr load_pxy
        lda cell
        sta save_lo
        lda cell+1
        sta save_hi
        jsr clear_player_2x2
        jsr load_pxy
        ldx cur_pl
        lda pdir,x
        sta tdir
        jsr add_dir
        lda cell
        sta tx
        lda cell+1
        sta ty
        jsr player_try_edge
        bcc @ok
        lda save_lo
        sta cell
        lda save_hi
        sta cell+1
        jsr save_pxy
        jmp @redraw
@ok:    lda tx
        sta cell
        lda ty
        sta cell+1
        jsr save_pxy
        jsr player_take_coins
@redraw:
        jsr load_pxy
        jmp stamp_player_2x2

;; cell = proposed NEW TL (after add_dir). Check the two leading-edge cells.
player_try_edge:
        lda #0
        sta coin_hit
        lda tdir
        cmp #DIR_UP
        bne @dn
        ;; top row of new footprint
        lda cell
        sta edge_lo
        lda cell+1
        sta edge_hi
        jsr check_walk_cell
        bcc @up2
        rts
@up2:   lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        sta cell+1
        jmp check_walk_cell
@dn:    cmp #DIR_DOWN
        bne @lr
        ;; bottom row
        lda cell
        clc
        adc #<PF_COLS
        sta edge_lo
        lda cell+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
        lda edge_lo
        sta cell
        lda edge_hi
        sta cell+1
        jsr check_walk_cell
        bcc @dn2
        rts
@dn2:   lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp check_walk_cell
@lr:    cmp #DIR_LEFT
        bne @rt
        ;; left column (cell already new TL)
        lda cell
        sta edge_lo
        lda cell+1
        sta edge_hi
        jmp @vert
@rt:    ;; right column
        lda cell
        clc
        adc #1
        sta edge_lo
        lda cell+1
        adc #0
        sta edge_hi
@vert:  lda edge_lo
        sta cell
        lda edge_hi
        sta cell+1
        jsr check_walk_cell
        bcc @v2
        rts
@v2:    lda edge_lo
        clc
        adc #<PF_COLS
        sta cell
        lda edge_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp check_walk_cell

;; C=0 empty/blood/coin; C=1 blocked. coin sets coin_hit.
check_walk_cell:
        jsr map_get_cell
        cmp #CHAR_EMPTY
        beq @ok
        cmp #CHAR_BLOOD
        beq @ok
        cmp #CHAR_COIN
        bne @blk
        lda #1
        sta coin_hit
@ok:    clc
        rts
@blk:   sec
        rts

;; After a successful step, clear coins under the 2×2 footprint.
player_take_coins:
        lda coin_hit
        beq @out
        jsr load_pxy
        lda cell
        sta edge_lo
        lda cell+1
        sta edge_hi
        jsr take_coin_here
        lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        sta cell+1
        jsr take_coin_here
        lda edge_lo
        clc
        adc #<PF_COLS
        sta cell
        lda edge_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jsr take_coin_here
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jsr take_coin_here
@out:   rts

take_coin_here:
        jsr map_get_cell
        cmp #CHAR_COIN
        bne @ret
        lda #CHAR_EMPTY
        jsr map_set_cell
        jsr inc_score
        dec coinsleft
        bne @ret
        jsr bonus_alive
        lda #1
        sta next_level_flag
@ret:   rts

do_fire:
        ldx cur_pl
        lda bulletdir,x
        beq @go
        rts
@go:    lda pdir,x
        sta bulletdir,x
        lda #BULLET_RANGE
        sta blt_left,x
        lda #0
        sta blt_cd,x
        lda pxyl,x
        sta bxyl,x
        lda pxyh,x
        sta bxyh,x
        ;; Leading edge has two cells; fire_alt picks which, then flips.
        lda pdir,x
        cmp #DIR_UP
        beq @up
        cmp #DIR_DOWN
        beq @down
        cmp #DIR_LEFT
        beq @left
        ;; RIGHT: TR or BR
        inc bxyl,x
        bne @r2
        inc bxyh,x
@r2:    lda fire_alt,x
        beq @flip
        jmp @plusrow
@up:    lda fire_alt,x
        beq @flip                ; TL
        jmp @plus1               ; TR
@down:  jsr @addrow
        lda fire_alt,x
        beq @flip                ; BL
        jmp @plus1               ; BR
@left:  lda fire_alt,x
        beq @flip                ; TL
        ;; BL
@plusrow:
        jsr @addrow
        jmp @flip
@plus1: inc bxyl,x
        bne @flip
        inc bxyh,x
@flip:  lda fire_alt,x
        eor #1
        sta fire_alt,x
        rts
@addrow:
        lda bxyl,x
        clc
        adc #<PF_COLS
        sta bxyl,x
        lda bxyh,x
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta bxyh,x
        rts

;; Last coin: +2 per remaining monster. Big: TL only, clear the 2×2.
;; Little: clear that one cell.
bonus_alive:
        lda #<playfield
        sta scan
        lda #>playfield
        sta scan+1
        lda #2
        sta scan_pg
        ldy #0
@lp:    lda (scan),y
        jsr is_little
        bcs @one
        jsr is_chase_tl
        bcs @hit
        jsr is_wander
        bcc @n
@hit:   tya
        pha
        lda scan
        pha
        lda scan+1
        pha
        ;; cell index = (scan - playfield) + y
        lda scan
        sec
        sbc #<playfield
        sta spot
        lda scan+1
        sbc #>playfield
        sta spot+1
        tya
        clc
        adc spot
        sta spot
        lda spot+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta spot+1
        jsr clear_monster_2x2
        jmp @pay
@one:   lda #CHAR_EMPTY
        sta (scan),y
        tya
        pha
        lda scan
        pha
        lda scan+1
        pha
@pay:   jsr inc_score
        jsr bonus_wait
        jsr inc_score
        jsr bonus_wait
        pla
        sta scan+1
        pla
        sta scan
        pla
        tay
@n:     iny
        bne @lp
        inc scan+1
        dec scan_pg
        bne @lp
        rts

update_monsters:
        lda #0
        sta mi                  ; steps
@loop:  lda mi
        cmp #SPOT_STEPS
        bcc @raster
        rts
@raster:
        lda TED_RASTERLO
        cmp #RASTER_OFF_EARLY
        beq @leave
        cmp #RASTER_OFF
        bne @step
@leave: rts
@step:  inc mi
        jsr load_spot
        jsr map_get_cell
        jsr is_wander
        bcs @t0
        jsr is_chase_tl
        bcs @t1
        jsr is_little
        bcs @lit
        jmp @adv
@lit:   jsr step_little
        jmp @adv
@t0:    sta nleft
        sec
        sbc #CHAR_WANDER_U-1
        jmp @go
@t1:    sta nleft
        ;; if (frame&7) { aggressive? seek : patrol } else random
        lda frame
        and #7
        beq @rand
        lda coinsleft
        cmp level
        beq @agg
        bcc @agg
        ;; Patrol: walk stored facing (like wander).
        lda nleft
        cmp #CHAR_MONSTER1
        bne @pface
        lda #CHAR_CHASE_U
        sta nleft
@pface: sec
        sbc #CHAR_CHASE_U-1
        jmp @go
@agg:   jsr type1_dir
        jmp @go
@rand:  jsr rand_dir
        sta tdir
        clc
        adc #CHAR_CHASE_U-1
        sta nleft
        lda tdir
@go:    sta tdir
        jsr monster_try_edge
        beq @move
        cmp #2
        beq @hurt
        ;; blocked
        lda nleft
        jsr is_wander
        bcs @turn
        ;; Chase: idle turns in place; aggressive retries one random step.
        lda coinsleft
        cmp level
        beq @cretry
        bcc @cretry
        jsr rand_dir
        clc
        adc #CHAR_CHASE_U-1
        sta nleft
        jsr stamp_monster_2x2
        jmp @adv
@cretry:
        jsr rand_dir
        sta tdir
        jsr monster_try_edge
        beq @cmove
        cmp #2
        beq @hurt
        jmp @adv
@cmove: lda nleft
        cmp #CHAR_MONSTER1
        bne @move
        lda #CHAR_CHASE_U
        sta nleft
@move:  jsr clear_monster_2x2
        jsr load_spot
        lda tdir
        jsr add_dir
        lda cell
        sta spot
        lda cell+1
        sta spot+1
        lda nleft
        jsr stamp_monster_2x2
        jmp @adv
@turn:  jsr rand_dir
        clc
        adc #CHAR_WANDER_U-1
        sta nleft
        jsr stamp_monster_2x2
        jmp @adv
@hurt:  lda hurt_dur
        bne @adv
        jsr hurt_player
@adv:   lda spot
        clc
        adc #SPOT_STRIDE
        sta spot
        lda spot+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta spot+1
        jmp @loop

;; spot = TL. Clear four cells (safe vs self-overlap).
;; A coin in the footprint stays. It is in front of the monster.
clear_monster_2x2:
        jsr load_spot
        jsr clear_mon_cell
        lda spot
        clc
        adc #1
        sta cell
        lda spot+1
        adc #0
        sta cell+1
        jsr clear_mon_cell
        lda spot
        clc
        adc #<PF_COLS
        sta cell
        lda spot+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jsr clear_mon_cell
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp clear_mon_cell

;; Empty a monster cell. Leave a coin or a player cell alone.
clear_mon_cell:
        jsr map_get_cell
        cmp #CHAR_COIN
        beq @keep
        cmp #CHAR_PLAYER
        bcc @empty
        cmp #CHAR_PLAYER_BR+1
        bcc @keep
@empty: lda #CHAR_EMPTY
        jmp map_set_cell
@keep:  rts

;; A = TL char, spot = TL. Stamp 2×2 body.
stamp_monster_2x2:
        sta nleft
        jsr load_spot
        lda nleft
        jsr map_set_cell
        lda nleft
        jsr is_chase_tl
        bcs @ch
        lda #CHAR_WANDER_TR
        sta edge_lo
        lda #CHAR_WANDER_BL
        sta edge_hi
        lda #CHAR_WANDER_BR
        sta coin_hit
        bne @body
@ch:    lda #CHAR_CHASE_TR
        sta edge_lo
        lda #CHAR_CHASE_BL
        sta edge_hi
        lda #CHAR_CHASE_BR
        sta coin_hit
@body:  lda spot
        clc
        adc #1
        sta cell
        lda spot+1
        adc #0
        sta cell+1
        lda edge_lo
        jsr stamp_body_cell
        lda spot
        clc
        adc #<PF_COLS
        sta cell
        lda spot+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda edge_hi
        jsr stamp_body_cell
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda coin_hit
        jmp stamp_body_cell

;; A = body glyph. Never write over a coin or a player cell.
stamp_body_cell:
        pha
        jsr map_get_cell
        cmp #CHAR_COIN
        beq @keep
        cmp #CHAR_PLAYER
        bcc @write
        cmp #CHAR_PLAYER_BR+1
        bcc @keep
@write: pla
        jmp map_set_cell
@keep:  pla
        rts

;; spot=TL, tdir=dir. A=0 empty edge, 1 blocked, 2 player.
;; Body cells may land on a coin. The TL tracking cell may not.
monster_try_edge:
        jsr mon_head_blocked
        beq @dir
        rts
@dir:
        lda tdir
        cmp #DIR_UP
        bne @dn
        lda spot
        sec
        sbc #<PF_COLS
        sta edge_lo
        lda spot+1
        sbc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
        jmp @horiz
@dn:    cmp #DIR_DOWN
        bne @lr
        lda spot
        clc
        adc #<(PF_COLS*2)
        sta edge_lo
        lda spot+1
        adc #>(PF_COLS*2)
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
@horiz: ;; two cells: edge and edge+1
        lda edge_lo
        sta cell
        lda edge_hi
        sta cell+1
        jsr prime_mon_coin
        jsr check_mon_edge
        beq @hgo
        rts
@hgo:   lda #0
        ldy tdir
        cpy #DIR_DOWN
        bne @h2
        lda #1
@h2:    sta mon_coin
        lda edge_lo
        clc
        adc #1
        sta cell
        lda edge_hi
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp check_mon_edge
@lr:    cmp #DIR_LEFT
        bne @rt
        lda spot
        sec
        sbc #1
        sta edge_lo
        lda spot+1
        sbc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
        jmp @vert
@rt:    lda spot
        clc
        adc #2
        sta edge_lo
        lda spot+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta edge_hi
@vert:  lda edge_lo
        sta cell
        lda edge_hi
        sta cell+1
        jsr prime_mon_coin
        jsr check_mon_edge
        bne @ret
        lda #1
        sta mon_coin
        lda edge_lo
        clc
        adc #<PF_COLS
        sta cell
        lda edge_hi
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp check_mon_edge
@ret:   rts

;; First edge cell may be a coin only on the lower half (down → new BL).
prime_mon_coin:
        lda #0
        ldy tdir
        cpy #DIR_DOWN
        bne @set
        lda #1
@set:   sta mon_coin
        rts

;; Z=1 if the new top row will not land on a coin.
;; Down: current BL and BR become the top row. Right: current TR becomes TL.
mon_head_blocked:
        lda tdir
        cmp #DIR_DOWN
        beq @dn
        cmp #DIR_RIGHT
        beq @rt
@open:  lda #0
        rts
@dn:    lda spot
        clc
        adc #<PF_COLS
        sta cell
        lda spot+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jsr map_get_cell
        cmp #CHAR_COIN
        beq @blk
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        jmp @test
@rt:    lda spot
        clc
        adc #1
        sta cell
        lda spot+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
@test:  jsr map_get_cell
        cmp #CHAR_COIN
        bne @open
@blk:   lda #1
        rts

;; A=0 empty (or, if FEET_BEHIND_COINS, an allowed coin), 1 blocked, 2 player.
check_mon_edge:
        jsr map_get_cell
        cmp #CHAR_EMPTY
        beq @ok
        cmp #CHAR_PLAYER
        bcc @coin
        cmp #CHAR_PLAYER_BR+1
        bcc @hurt
@coin:  cmp #CHAR_COIN
        bne @blk
.ifdef FEET_BEHIND_COINS
        lda mon_coin
        bne @ok
.endif
@blk:   lda #1
        rts
@hurt:  lda #2
        rts
@ok:    lda #0
        rts

hurt_player:
        lda #HURT_PERIOD
        sta hurt_dur
        jsr play_hurt
        lda health
        beq @go
        dec health
        lda health
        bne @ret
@go:    lda #1
        sta game_over_flag
@ret:   rts

;; X = player slot on entry (via cur_pl already set by caller, or set here)
update_bullet:
        stx cur_pl
        lda bulletdir,x
        bne @go
        rts
@go:    lda blt_cd,x
        beq @step
        dec blt_cd,x
        rts
@step:  lda #BULLET_DELAY
        sta blt_cd,x
        lda blt_left,x
        bne @fly
        jmp stop_bullet
@fly:   jsr bxy_on_player
        bcs @skip
        ldx cur_pl
        lda bxyl,x
        pha
        lda bxyh,x
        tay
        pla
        tax
        lda #CHAR_EMPTY
        jsr map_set_xy
@skip:  jsr load_bxy
        ldx cur_pl
        lda bulletdir,x
        jsr add_dir
        jsr map_get_cell
        sta hitxyval
        cmp #CHAR_EMPTY
        bne @hit
        jsr save_bxy
        lda #CHAR_BULLET
        jsr map_set_cell
        ldx cur_pl
        dec blt_left,x
        jmp restamp_players
@hit:   lda hitxyval
        jsr is_monster_tile
        bcs @kill
        cmp #CHAR_TREE
        beq @blast
        cmp #CHAR_BLOOD
        bne stop_bullet
@blast: lda #CHAR_EMPTY
        jsr map_set_cell
        jmp stop_bullet
@kill:  jsr damage_at_hit
        jmp stop_bullet

stop_bullet:
        jsr bxy_on_player
        bcs @clr
        ldx cur_pl
        lda bxyl,x
        pha
        lda bxyh,x
        tay
        pla
        tax
        lda #CHAR_EMPTY
        jsr map_set_xy
@clr:   ldx cur_pl
        lda #0
        sta bulletdir,x
        jmp restamp_players

;; hitxyval + cell = impact.
;; Little wander → little chase. Little chase → blood.
;; Big 2×2 → four 1×1 monsters in the footprint (coin cells stay).
damage_at_hit:
        lda hitxyval
        jsr is_little
        bcc @big
        cmp #CHAR_LITTLE1
        beq @die
        lda #CHAR_LITTLE1
        jmp map_set_cell
@die:   jsr play_kill
        lda #CHAR_BLOOD
        jmp map_set_cell
@big:   jsr resolve_monster_tl
        jmp split_big

;; spot = TL after resolve. Wander splits into four facings; chase into four chases.
;; mon_coin = 1 for little wanders. A coin or player cell is left alone.
split_big:
        lda hitxyval
        jsr is_wander
        bcs @wand
        jsr play_kill
        lda #0
        beq @kind
@wand:  lda #1
@kind:  sta mon_coin
        jsr clear_monster_2x2
        jsr load_spot
        lda #CHAR_LITTLE_U
        jsr plant_little
        lda spot
        clc
        adc #1
        sta cell
        lda spot+1
        adc #0
        sta cell+1
        lda #CHAR_LITTLE_R
        jsr plant_little
        lda spot
        clc
        adc #<PF_COLS
        sta cell
        lda spot+1
        adc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_LITTLE_D
        jsr plant_little
        lda cell
        clc
        adc #1
        sta cell
        lda cell+1
        adc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta cell+1
        lda #CHAR_LITTLE_L
        jmp plant_little

;; A = little facing to write if this was a wander. Cell must be empty.
plant_little:
        sta nleft
        jsr map_get_cell
        cmp #CHAR_EMPTY
        beq @ok
        rts
@ok:    lda mon_coin
        bne @face
        lda #CHAR_LITTLE1
        jmp map_set_cell
@face:  lda nleft
        jmp map_set_cell

;; A = little tile. spot = its cell. One step, same rules as the 1×1 port.
step_little:
        sta nleft
        cmp #CHAR_LITTLE1
        beq @seek
        sec
        sbc #CHAR_LITTLE_U-1
        jmp @go
@seek:  jsr little_chase_dir
@go:    sta tdir
        jsr load_spot
        lda tdir
        jsr add_dir
        jsr map_get_cell
        cmp #CHAR_EMPTY
        bne @block
@step:  lda #CHAR_EMPTY
        ldx spot
        ldy spot+1
        jsr map_set_xy
        lda nleft
        jmp map_set_cell
@block: cmp #CHAR_PLAYER
        bcc @wall
        cmp #CHAR_PLAYER_BR+1
        bcc @hurt
@wall:  lda nleft
        cmp #CHAR_LITTLE1
        beq @retry
        jsr rand_dir
        clc
        adc #CHAR_LITTLE_U-1
        ldx spot
        ldy spot+1
        jmp map_set_xy
@retry: jsr rand_dir
        sta tdir
        jsr load_spot
        lda tdir
        jsr add_dir
        jsr map_get_cell
        cmp #CHAR_EMPTY
        beq @step
        cmp #CHAR_PLAYER
        bcc @out
        cmp #CHAR_PLAYER_BR+1
        bcs @out
@hurt:  lda hurt_dur
        bne @out
        jmp hurt_player
@out:   rts

;; coinsleft <= level → seek the nearest player, else a random direction.
little_chase_dir:
        lda coinsleft
        cmp level
        beq @seek
        bcc @seek
        jmp rand_dir
@seek:  jmp type1_dir

;; cell = hit cell, hitxyval = tile. Sets spot = TL; updates hitxyval to TL tile.
resolve_monster_tl:
        lda hitxyval
        jsr is_wander
        bcs @atl
        jsr is_chase_tl
        bcs @atl
        cmp #CHAR_WANDER_TR
        beq @tr
        cmp #CHAR_CHASE_TR
        beq @tr
        cmp #CHAR_WANDER_BL
        beq @bl
        cmp #CHAR_CHASE_BL
        beq @bl
        ;; BR
@br:    lda cell
        sec
        sbc #<(PF_COLS+1)
        sta spot
        lda cell+1
        sbc #>(PF_COLS+1)
        and #((LEVEL_SIZE-1) >> 8)
        sta spot+1
        jmp @got
@tr:    lda cell
        sec
        sbc #1
        sta spot
        lda cell+1
        sbc #0
        and #((LEVEL_SIZE-1) >> 8)
        sta spot+1
        jmp @got
@bl:    lda cell
        sec
        sbc #<PF_COLS
        sta spot
        lda cell+1
        sbc #>PF_COLS
        and #((LEVEL_SIZE-1) >> 8)
        sta spot+1
        jmp @got
@atl:   lda cell
        sta spot
        lda cell+1
        sta spot+1
@got:   jsr load_spot
        jsr map_get_cell
        sta hitxyval
        rts

;; C=1 if A is any monster map tile (facing, chase TL, or body).
is_monster_tile:
        jsr is_wander
        bcs @yes
        jsr is_chase_tl
        bcs @yes
        cmp #CHAR_WANDER_TR
        bcc @no
        cmp #CHAR_CHASE_BR+1
        bcc @yes
        jmp is_little
@yes:   sec
        rts
@no:    clc
        rts

;; C=1 if A is a 1×1 monster (facing $7A–$7D or chase $79). A preserved.
is_little:
        cmp #CHAR_LITTLE1
        beq @yes
        cmp #CHAR_LITTLE_R+1
        bcs @no
        cmp #CHAR_LITTLE_U
        rts
@yes:   sec
        rts
@no:    clc
        rts

bonus_wait:
        ldy #12
@w:     tya
        pha
        jsr wait_vrefresh
        jsr blit_playfield
        jsr update_hud
        jsr play_audio_frame
        pla
        tay
        dey
        bne @w
        rts

;; (fast_rand >> 1) & 3 + 1 → facing 1..4
rand_dir:
        jsr fast_rand
        lsr a
        and #3
        clc
        adc #1
        rts

;; A = circular distance min(d, 512−d) for d=(spot−player)&511, slot X.
player_dist:
        sec
        lda spot
        sbc pxyl,x
        sta tx
        lda spot+1
        sbc pxyh,x
        and #1
        sta ty
        bne @ge256
        lda tx
        rts
@ge256: lda tx
        eor #$ff
        clc
        adc #1
        bne @ok
        lda #$ff
@ok:    rts

;; Aggressive seek AI only (caller gates idle vs aggressive).
type1_dir:
        ldx #0
        lda two_player
        beq @aim                 ; 1P: always slot 0 (no dist call)
        jsr player_dist
        sta tdist
        ldx #1
        jsr player_dist
        cmp tdist
        bcs @p0
        ldx #1
        bne @aim
@p0:    ldx #0
@aim:   sec
        lda spot
        sbc pxyl,x
        sta tx
        lda spot+1
        sbc pxyh,x
        and #>(1023)
        sta ty
        bne @hi
        lda tx
        cmp #16
        bcs @up
        lda #DIR_LEFT
        rts
@up:    lda #DIR_UP
        rts
@hi:    cmp #>(1024-16)
        bne @down
        lda tx
        cmp #<(1024-16)
        bcc @down
        lda #DIR_RIGHT
        rts
@down:  lda #DIR_DOWN
        rts

;; C=1 if A is wander facing (A preserved)
is_wander:
        cmp #CHAR_WANDER_R+1
        bcs @no
        cmp #CHAR_WANDER_U
        rts
@no:    clc
        rts

;; C=1 if A is chase TL (MONSTER1 or facing $74–$77). A preserved.
is_chase_tl:
        cmp #CHAR_MONSTER1
        beq @yes
        cmp #CHAR_CHASE_R+1
        bcs @no
        cmp #CHAR_CHASE_U
        rts
@yes:   sec
        rts
@no:    clc
        rts
