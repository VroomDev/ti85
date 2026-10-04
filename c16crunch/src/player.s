;; Player / monsters / bullet on playfield[512]

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

.import read_input
.import input_bits
.import map_get_cell
.import map_set_cell
.import map_set_xy
.import playfield
.import player_at
.importzp cell
.import score
.import health
.import coinsleft
.import fast_rand
.import play_coin
.import play_kill
.import play_hurt
.import play_audio_frame
.import wait_vrefresh
.import blit_playfield
.import update_hud

.segment "BSS"
pdir:           .res 1
bulletdir:      .res 1
move_cd:        .res 1
pxy:            .res 2
bxy:            .res 2
blt_left:       .res 1
blt_cd:         .res 1
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
scan_pg:        .res 1

.segment "ZEROPAGE"
scan:           .res 2

.segment "CODE"

init_sprites:
        lda #0
        sta bulletdir
        sta blt_left
        sta blt_cd
        sta spot
        sta spot+1
        sta game_over_flag
        sta next_level_flag
        sta hurt_dur
        lda #DIR_RIGHT
        sta pdir
        lda #0
        sta move_cd
        lda player_at
        sta pxy
        lda player_at+1
        sta pxy+1
        jsr load_pxy
        lda #CHAR_PLAYER
        jsr map_set_cell
        rts

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
        lda pxy
        sta cell
        lda pxy+1
        sta cell+1
        rts

load_bxy:
        lda bxy
        sta cell
        lda bxy+1
        sta cell+1
        rts

load_spot:
        lda spot
        sta cell
        lda spot+1
        sta cell+1
        rts

save_pxy:
        lda cell
        sta pxy
        lda cell+1
        sta pxy+1
        rts

save_bxy:
        lda cell
        sta bxy
        lda cell+1
        sta bxy+1
        rts

update_player:
        lda hurt_dur
        beq @ready
        dec hurt_dur
@ready: jsr read_input
        lda input_bits
        and #IN_FIRE
        beq @nof
        jsr do_fire
@nof:   lda input_bits
        and #(IN_UP|IN_DOWN|IN_LEFT|IN_RIGHT)
        bne @has
        lda #0
        sta move_cd
        rts
@has:   lda input_bits
        and #IN_UP
        beq @1
        lda #DIR_UP
        bne @set
@1:     lda input_bits
        and #IN_DOWN
        beq @2
        lda #DIR_DOWN
        bne @set
@2:     lda input_bits
        and #IN_LEFT
        beq @3
        lda #DIR_LEFT
        bne @set
@3:     lda #DIR_RIGHT
@set:   sta pdir
        lda input_bits
        and #IN_FIRE
        bne @aim
        lda move_cd
        beq @go
        dec move_cd
        rts
@aim:   rts
@go:    lda #MOVE_DELAY
        sta move_cd
        jsr load_pxy
        lda #CHAR_EMPTY
        jsr map_set_cell
        lda pdir
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
        lda bulletdir
        bne @ret
        lda pdir
        sta bulletdir
        lda #BULLET_RANGE
        sta blt_left
        lda #0
        sta blt_cd
        lda pxy
        sta bxy
        lda pxy+1
        sta bxy+1
@ret:   rts

update_monsters:
        lda #0
        sta mi                  ; steps
@loop:  lda mi
        cmp #SPOT_STEPS
        bcc @raster
        jmp @out
@raster:
        lda TED_RASTERLO
        cmp #RASTER_OFF_EARLY
        beq @leave
        cmp #RASTER_OFF
        bne @step
@leave: jmp @out
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
@out:   rts

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

update_bullet:
        lda bulletdir
        bne @go
        rts
@go:    lda blt_cd
        beq @step
        dec blt_cd
        rts
@step:  lda #BULLET_DELAY
        sta blt_cd
        lda blt_left
        bne @fly
        jmp stop_bullet
@fly:   lda bxy
        cmp pxy
        bne @er
        lda bxy+1
        cmp pxy+1
        beq @skip
@er:    lda #CHAR_EMPTY
        ldx bxy
        ldy bxy+1
        jsr map_set_xy
@skip:  jsr load_bxy
        lda bulletdir
        jsr add_dir
        jsr map_get_cell
        sta hitxyval
        cmp #CHAR_EMPTY
        bne @hit
        jsr save_bxy
        lda #CHAR_BULLET
        jsr map_set_cell
        dec blt_left
        jsr load_pxy
        lda #CHAR_PLAYER
        jsr map_set_cell
        rts
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
        lda bxy
        cmp pxy
        bne @er
        lda bxy+1
        cmp pxy+1
        beq @clr
@er:    lda #CHAR_EMPTY
        ldx bxy
        ldy bxy+1
        jsr map_set_xy
@clr:   lda #0
        sta bulletdir
        jsr load_pxy
        lda #CHAR_PLAYER
        jsr map_set_cell
        rts

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

;; diff = (spot - pxy) & 1023. Close on that ring is left or right.
type1_dir:
        sec
        lda spot
        sbc pxy
        sta tx
        lda spot+1
        sbc pxy+1
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
