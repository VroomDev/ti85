;; Player / monsters / bullet — direct CRUNCH.ASM conversion on playfield[]

.include "game.inc"

.export init_sprites
.export try_spawn
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
.import player_sx
.import player_sy
.import monster_sx
.import monster_sy
.import level
.import score
.import score_tick
.import health
.import coinsleft
.import randvar
.import play_coin
.import play_kill
.import play_hurt

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
spot:           .res 1
mi:             .res 1
nleft:          .res 1
tdir:           .res 1
tx:             .res 1
ty:             .res 1
made:           .res 1

.segment "CODE"

;===========================================================================
init_sprites:
        lda #0
        sta bulletdir
        sta blt_left
        sta blt_cd
        sta spot
        sta game_over_flag
        sta next_level_flag
        sta made
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

;; If spawn empty and made < level, stamp one monster there.
try_spawn:
        lda made
        cmp level
        bcs @ret
        ldx monster_sx
        ldy monster_sy
        jsr map_get
        cmp #CHAR_EMPTY
        bne @ret
        lda made
        and #1
        beq @p1
        lda #CHAR_MONSTER
        bne @put
@p1:    lda #CHAR_MONSTER1
@put:   ldx monster_sx
        ldy monster_sy
        jsr map_set
        inc made
@ret:   rts

;===========================================================================
inc_score:
        inc randvar
        inc score_tick
        lda score_tick
        and #31
        cmp #31
        bne :+
        lda health
        clc
        adc #2
        sta health
:
        sed
        clc
        lda score
        adc #1
        sta score
        lda score+1
        adc #0
        sta score+1
        cld
        rts

;===========================================================================
;; Probe dest for dir A from (tx,ty). Sets hit_*; C=0 if empty (tx,ty updated).
probe:
        sta tdir
        lda tx
        ldx ty
        ;; X=col Y=row for map_get
        tax
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
        jsr map_get             ; X becomes index — do not store it as col
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

;===========================================================================
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

        lda move_cd
        beq @go
        dec move_cd
        rts
@go:    lda #MOVE_DELAY
        sta move_cd

        ;; erase player
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
        ;; blocked — maybe coin (CRUNCH: score + erase, stay put)
        lda hitxyval
        cmp #CHAR_COIN
        bne @redraw
        jsr inc_score
        jsr play_coin
        lda #CHAR_EMPTY
        ldx hit_x
        ldy hit_y
        jsr map_set
        dec coinsleft
        bne @redraw
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

;===========================================================================
update_monsters:
        lda #SPOT_STEPS
        sta mi
um_loop:
        jsr spot_xy
        jsr map_get
        cmp #CHAR_MONSTER
        beq um_t0
        cmp #CHAR_MONSTER1
        beq um_t1
        jmp um_adv
um_t0:  sta nleft
        lda JIFFY_MID
        and #3
        clc
        adc #1
        jmp um_go
um_t1:  sta nleft
        jsr spot_xy
        jsr type1_dir
um_go:  sta tdir
        jsr spot_xy
        lda tdir
        jsr probe
        bcc um_ok
        lda hitxyval
        cmp #CHAR_PLAYER
        beq um_hurt
        ;; type 0 blocked → one random step
        lda nleft
        cmp #CHAR_MONSTER
        bne um_adv
        jsr type0_retry
        bcc um_ok
        lda hitxyval
        cmp #CHAR_PLAYER
        bne um_adv
um_hurt:
        jsr hurt_player
        jmp um_adv
um_ok:  jsr spot_xy
        lda #CHAR_EMPTY
        jsr map_set
        lda nleft
        ldx hit_x
        ldy hit_y
        jsr map_set
um_adv:
        lda spot
        clc
        adc #SPOT_STRIDE
        and #127
        sta spot
        dec mi
        beq :+
        jmp um_loop
:       rts

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

;===========================================================================
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
@fly:   ;; erase if was drawn (skip first cell = player start — bullet starts on player)
        lda bx
        cmp px
        bne @er
        lda by
        cmp py
        beq @skip_er
@er:    lda #CHAR_EMPTY
        ldx bx
        ldy by
        jsr map_set
@skip_er:
        lda bx
        sta tx
        lda by
        sta ty
        lda bulletdir
        jsr probe
        bcc @bmoved
        ;; hit non-empty
        lda hitxyval
        cmp #CHAR_MONSTER
        beq @kill
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
@bmoved:
        lda tx
        sta bx
        lda ty
        sta by
        lda #CHAR_BULLET
        ldx bx
        ldy by
        jsr map_set
        dec blt_left
        ;; CRUNCH drawplayer after bullet move
        lda #CHAR_PLAYER
        ldx px
        ldy py
        jsr map_set
        rts
@kill:  jsr inc_score
        jsr damage_at_hit
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

;; Board-only HP: type 1 → type 0; type 0 → blood
damage_at_hit:
        lda hitxyval
        cmp #CHAR_MONSTER
        bne @kill
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

.segment "CODE2"

;===========================================================================
;; Cheap LFSR-ish rand (seeds from randvar)
rand:
        lda randvar
        asl a
        adc #13
        sta randvar
        rts

;; CRUNCH: rand>>2 &3 +1 → facing 1..4
rand_dir:
        jsr rand
        lsr a
        lsr a
        and #3
        clc
        adc #1
        rts

spot_xy:
        lda spot
        and #15
        sta tx
        tax
        lda spot
        lsr a
        lsr a
        lsr a
        lsr a
        sta ty
        tay
        rts

type1_dir:
        lda coinsleft
        cmp level
        beq @jiffy
        bcs rand_dir            ; coinsleft > level → random
@jiffy: lda JIFFY_LO
        and #16
        bne rand_dir            ; ($A2 & 16) ≠ 0 → random
        jmp chase_player

type0_retry:
        jsr rand_dir
        sta tdir
        jsr spot_xy
        lda tdir
        jmp probe

;; A = cardinal toward player from (tx,ty). Longer axis, horiz on tie.
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
