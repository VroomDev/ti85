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
        adc #1
        sta pxyl+1
        lda player_at+1
        adc #0
        sta pxyh+1
@put:   jsr load_pxy
        lda #CHAR_PLAYER
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

;; Stamp CHAR_PLAYER on every active player cell.
restamp_players:
        lda pxyl
        sta cell
        lda pxyh
        sta cell+1
        lda #CHAR_PLAYER
        jsr map_set_cell
        lda two_player
        beq @out
        lda pxyl+1
        sta cell
        lda pxyh+1
        sta cell+1
        lda #CHAR_PLAYER
        jsr map_set_cell
@out:   rts

;; C=1 if cell matches any live player position.
cell_is_player:
        lda cell
        cmp pxyl
        bne @p2
        lda cell+1
        cmp pxyh
        beq @yes
@p2:    lda two_player
        beq @no
        lda cell
        cmp pxyl+1
        bne @no
        lda cell+1
        cmp pxyh+1
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
        lda #CHAR_EMPTY
        jsr map_set_cell
        ldx cur_pl
        lda pdir,x
        jsr add_dir
        jsr map_get_cell
        sta hitxyval
        cmp #CHAR_EMPTY
        beq @step
        cmp #CHAR_BLOOD
        bne @blk
@step:  jsr save_pxy
        jmp @redraw
@blk:   cmp #CHAR_COIN
        bne @redraw
        jsr save_pxy
        jsr inc_score
        lda #CHAR_EMPTY
        jsr map_set_cell
        dec coinsleft
        bne @redraw
        jsr bonus_alive
        lda #1
        sta next_level_flag
@redraw:
        jsr load_pxy
        lda #CHAR_PLAYER
        jsr map_set_cell
        rts

do_fire:
        ldx cur_pl
        lda bulletdir,x
        bne @ret
        lda pdir,x
        sta bulletdir,x
        lda #BULLET_RANGE
        sta blt_left,x
        lda #0
        sta blt_cd,x
        lda pxyl,x
        sta bxyl,x
        lda pxyh,x
        sta bxyh,x
@ret:   rts

;; Upper RAM ($2A00+)
.segment "CODEHI"

;; Last coin: +2 for each remaining monster, across all 512 cells.
bonus_alive:
        lda #<playfield
        sta scan
        lda #>playfield
        sta scan+1
        lda #2
        sta scan_pg
        ldy #0
@lp:    lda (scan),y
        cmp #CHAR_MONSTER1
        beq @hit
        jsr is_wander
        bcc @n
@hit:   lda #CHAR_EMPTY
        sta (scan),y
        tya
        pha
        lda scan
        pha
        lda scan+1
        pha
        jsr inc_score
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
        cmp #CHAR_MONSTER1
        beq @t1
        jmp @adv
@t0:    sta nleft
        sec
        sbc #CHAR_WANDER_U-1
        jmp @go
@t1:    sta nleft
        jsr type1_dir
@go:    sta tdir
        jsr load_spot
        lda tdir
        jsr add_dir
        jsr map_get_cell
        sta hitxyval
        cmp #CHAR_EMPTY
        bne @block
        lda #CHAR_EMPTY
        ldx spot
        ldy spot+1
        jsr map_set_xy
        lda nleft
        jsr map_set_cell
        jmp @adv
@block: lda hitxyval
        cmp #CHAR_PLAYER
        beq @hurt
        lda nleft
        jsr is_wander
        bcs @turn
        jsr rand_dir
        sta tdir
        jsr load_spot
        lda tdir
        jsr add_dir
        jsr map_get_cell
        sta hitxyval
        cmp #CHAR_EMPTY
        bne @chit
        lda #CHAR_EMPTY
        ldx spot
        ldy spot+1
        jsr map_set_xy
        lda #CHAR_MONSTER1
        jsr map_set_cell
        jmp @adv
@chit:  cmp #CHAR_PLAYER
        beq @hurt
        jmp @adv
@turn:  jsr rand_dir
        clc
        adc #CHAR_WANDER_U-1
        ldx spot
        ldy spot+1
        jsr map_set_xy
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
        jsr is_wander
        bcs @kill
        cmp #CHAR_MONSTER1
        beq @kill
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

damage_at_hit:
        lda hitxyval
        jsr is_wander
        bcc @kill
        lda #CHAR_MONSTER1
        jmp map_set_cell
@kill:  jsr play_kill
        lda #CHAR_BLOOD
        jmp map_set_cell

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

;; fast_rand >> 2 → facing 1..4
rand_dir:
        jsr fast_rand
        lsr a
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

;; coinsleft <= level → chase; else random. Chase closes on nearest player.
type1_dir:
        lda coinsleft
        cmp level
        beq @who                 ; equal → chase
        bcc @who                 ; coinsleft < level → chase
        jmp rand_dir             ; coinsleft > level → random
@who:   ldx #0
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

;; C=1 if A is wander $67–$6A (A preserved)
is_wander:
        cmp #CHAR_WANDER_R+1
        bcs @no
        cmp #CHAR_WANDER_U
        rts
@no:    clc
        rts
