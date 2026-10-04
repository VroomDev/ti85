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
.export px
.export py

.import read_input
.import input_bits
.import map_get
.import map_set
.import playfield
.import player_sx
.import player_sy
.import level
.import score
.import health
.import coinsleft
.import fast_rand
.import play_coin
.import play_kill
.import play_hurt
.importzp sfx_dur
.import play_audio_frame
.import wait_vrefresh
.import blit_playfield
.import update_hud

.segment "BSS"
pdir:           .res 1
bulletdir:      .res 1
move_cd:        .res 1
px:             .res 1
py:             .res 1
bx:             .res 1
by:             .res 1
blt_left:       .res 1
blt_cd:         .res 1
hitxyval:       .res 1
hit_x:          .res 1
hit_y:          .res 1
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
        lda #DIR_RIGHT
        sta pdir
        lda #0
        sta move_cd
        lda player_sx
        sta px
        lda player_sy
        sta py
        lda #CHAR_PLAYER
        ldx px
        ldy py
        jsr map_set
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
        cmp #$99
        bne @chirp
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

;; Probe dest for dir A from (tx,ty). C=0 if empty (tx,ty updated).
probe:
        sta tdir
        ldx tx
        ldy ty
        lda tdir
        cmp #DIR_UP
        bne @d
        cpy #0
        beq @wall
        dey
        jmp @cell
@d:     cmp #DIR_DOWN
        bne @l
        cpy #(PF_ROWS-1)
        beq @wall
        iny
        jmp @cell
@l:     cmp #DIR_LEFT
        bne @r
        cpx #0
        beq @wall
        dex
        jmp @cell
@r:     cmp #DIR_RIGHT
        bne @wall
        cpx #(PF_COLS-1)
        beq @wall
        inx
@cell:  stx hit_x
        sty hit_y
        jsr map_get
        sta hitxyval
        cmp #CHAR_EMPTY
        bne @block
        lda hit_x
        sta tx
        lda hit_y
        sta ty
        clc
        rts
@block: sec
        rts
@wall:  lda #1
        sta hitxyval
        sec
        rts

update_player:
        jsr read_input
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
        lda #CHAR_EMPTY
        ldx px
        ldy py
        jsr map_set
        lda px
        sta tx
        lda py
        sta ty
        lda pdir
        jsr probe
        bcc @moved
        lda hitxyval
        cmp #CHAR_COIN
        bne @redraw
        jsr inc_score
        lda #CHAR_EMPTY
        ldx hit_x
        ldy hit_y
        jsr map_set
        dec coinsleft
        bne @redraw
        jsr bonus_alive
        lda #1
        sta next_level_flag
        jmp @redraw
@moved: lda tx
        sta px
        lda ty
        sta py
@redraw:
        lda #CHAR_PLAYER
        ldx px
        ldy py
        jsr map_set
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
        lda px
        sta bx
        lda py
        sta by
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
        jsr spot_xy
        jsr map_get
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
        jsr spot_xy
        jsr type1_dir
@go:    sta tdir
        jsr spot_xy
        lda tdir
        jsr probe
        bcc @ok
        lda hitxyval
        cmp #CHAR_PLAYER
        beq @hurt
        lda nleft
        jsr is_wander
        bcc @adv
        jsr rand_dir
        clc
        adc #CHAR_WANDER_U-1
        sta nleft
        jsr spot_xy
        lda nleft
        ldx tx
        ldy ty
        jsr map_set
        jmp @adv
@hurt:  lda sfx_dur
        bne @adv
        jsr hurt_player
        jmp @adv
@ok:    jsr spot_xy
        lda #CHAR_EMPTY
        jsr map_set
        lda nleft
        ldx hit_x
        ldy hit_y
        jsr map_set
@adv:   lda spot
        clc
        adc #SPOT_STRIDE
        sta spot
        lda spot+1
        adc #0
        and #1                  ; modulo 512
        sta spot+1
        jmp @loop
@out:   rts

hurt_player:
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
@fly:   lda bx
        cmp px
        bne @er
        lda by
        cmp py
        beq @skip
@er:    lda #CHAR_EMPTY
        ldx bx
        ldy by
        jsr map_set
@skip:  lda bx
        sta tx
        lda by
        sta ty
        lda bulletdir
        jsr probe
        bcc @moved
        lda hitxyval
        jsr is_wander
        bcs @kill
        cmp #CHAR_MONSTER1
        beq @kill
        cmp #CHAR_TREE
        beq @blast
        cmp #CHAR_BLOOD
        bne stop_bullet
@blast: lda #CHAR_EMPTY
        ldx hit_x
        ldy hit_y
        jsr map_set
        jmp stop_bullet
@moved: lda tx
        sta bx
        lda ty
        sta by
        lda #CHAR_BULLET
        ldx bx
        ldy by
        jsr map_set
        dec blt_left
        lda #CHAR_PLAYER
        ldx px
        ldy py
        jsr map_set
        rts
@kill:  jsr damage_at_hit
        jmp stop_bullet

stop_bullet:
        lda bx
        cmp px
        bne @er
        lda by
        cmp py
        beq @clr
@er:    lda #CHAR_EMPTY
        ldx bx
        ldy by
        jsr map_set
@clr:   lda #0
        sta bulletdir
        lda #CHAR_PLAYER
        ldx px
        ldy py
        jsr map_set
        rts

damage_at_hit:
        lda hitxyval
        jsr is_wander
        bcc @kill
        lda #CHAR_MONSTER1
        ldx hit_x
        ldy hit_y
        jsr map_set
        rts
@kill:  jsr play_kill
        lda #CHAR_BLOOD
        ldx hit_x
        ldy hit_y
        jsr map_set
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

;; fast_rand >> 2 → facing 1..4
rand_dir:
        jsr fast_rand
        lsr a
        lsr a
        and #3
        clc
        adc #1
        rts

spot_xy:
        lda spot
        and #31
        sta tx
        lda spot+1
        and #1
        asl a
        asl a
        asl a
        sta ty
        lda spot
        lsr a
        lsr a
        lsr a
        lsr a
        lsr a
        ora ty
        sta ty
        ldx tx
        ldy ty
        rts

type1_dir:
        lda coinsleft
        cmp level
        beq @jiffy
        bcs rand_dir
@jiffy: lda JIFFY_LO
        and #16
        bne rand_dir
        jmp chase_player

chase_player:
        lda px
        cmp tx
        bcs @dxpos
        lda tx
        sec
        sbc px
        sta tdir
        ldy #DIR_LEFT
        bne @dy
@dxpos: sbc tx
        sta tdir
        ldy #DIR_RIGHT
@dy:    lda py
        cmp ty
        bcs @dypos
        lda ty
        sec
        sbc py
        cmp tdir
        bcc @horiz
        beq @horiz
        lda #DIR_UP
        rts
@dypos: sbc ty
        cmp tdir
        bcc @horiz
        beq @horiz
        lda #DIR_DOWN
        rts
@horiz: tya
        rts

;; C=1 if A is wander $67–$6A (A preserved)
is_wander:
        cmp #CHAR_WANDER_R+1
        bcs @no
        cmp #CHAR_WANDER_U
        rts
@no:    clc
        rts
