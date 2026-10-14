;; TED matrix. Keyboard via $FD30, joysticks via $FF08. Active low.
;; Column $EF holds I, J, K, and M. L and P are $DF. Space is $7F.
;; Digits 1 and 2 are $7F bits 0 and 3. Port 1 select is $FB, fire bit $40.
;; Port 2 select is $FD, fire bit $80.
;; input_bits / input_bits2 are contiguous so player code can index them.

.include "game.inc"

.export read_input
.export input_bits
.export input_bits2
.export key_held
.export key_c
.export key_b
.export key_p
.export key_1
.export key_2
.export joy1_fire
.export joy2_fire

.import two_player

.segment "BSS"
input_bits:     .res 1
input_bits2:    .res 1
key_held:       .res 1
key_c:          .res 1
key_b:          .res 1
key_p:          .res 1
key_1:          .res 1
key_2:          .res 1
joy1_fire:      .res 1
joy2_fire:      .res 1
joy_raw:        .res 1
joy_slot:       .res 1

.segment "CODE"

;; A = column select → A = row bits (joystick latch held off)
kbd_col:
        sta KBD_LATCH
        lda #$ff
        sta TED_KBD
        lda TED_KBD
        rts

;; A = $FF08 select. X = fire bit. Directions are bits 0–3.
;; ORs into input_bits[joy_slot].
read_joy:
        ldy #$ff
        sty KBD_LATCH
        sta TED_KBD
        lda TED_KBD
        sta joy_raw
        and #$01
        bne @down
        lda #IN_UP
        jsr @merge
@down:  lda joy_raw
        and #$02
        bne @left
        lda #IN_DOWN
        jsr @merge
@left:  lda joy_raw
        and #$04
        bne @right
        lda #IN_LEFT
        jsr @merge
@right: lda joy_raw
        and #$08
        bne @fire
        lda #IN_RIGHT
        jsr @merge
@fire:  txa
        and joy_raw
        bne @out
        lda #IN_FIRE
@merge: ldy joy_slot
        ora input_bits,y
        sta input_bits,y
@out:   rts

read_input:
        lda #0
        sta input_bits
        sta input_bits2
        sta key_held
        sta key_c
        sta key_b
        sta key_p
        sta key_1
        sta key_2
        sta joy1_fire
        sta joy2_fire
        sei

        lda #0
        sta joy_slot
        lda #$fb                ; port 1, fire bit 6
        ldx #$40
        jsr read_joy
        lda input_bits
        and #IN_FIRE
        beq @j2
        lda #1
        sta joy1_fire

@j2:    lda #1
        sta joy_slot
        lda #$fd                ; port 2, fire bit 7
        ldx #$80
        jsr read_joy
        lda input_bits2
        and #IN_FIRE
        beq @merge
        lda #1
        sta joy2_fire

@merge: lda two_player
        bne @keys
        lda input_bits
        ora input_bits2
        sta input_bits
        lda #0
        sta input_bits2

@keys:  lda #0
        sta joy_slot

        lda #$ef                ; I up, J left, M down, K fire
        jsr kbd_col
        tax
        and #$02
        bne @kj
        lda input_bits
        ora #IN_UP
        sta input_bits
@kj:    txa
        and #$04
        bne @km
        lda input_bits
        ora #IN_LEFT
        sta input_bits
@km:    txa
        and #$10
        bne @kk
        lda input_bits
        ora #IN_DOWN
        sta input_bits
@kk:    txa
        and #$20
        bne @kl
        lda input_bits
        ora #IN_FIRE
        sta input_bits

@kl:    lda #$df                ; L right, P pause
        jsr kbd_col
        tax
        and #$04
        bne @kp
        lda input_bits
        ora #IN_RIGHT
        sta input_bits
@kp:    txa
        and #$02
        bne @sp
        lda #1
        sta key_p

@sp:    lda #$7f                ; 1, 2, Space
        jsr kbd_col
        tax
        and #$01
        bne @k2
        lda #1
        sta key_1
@k2:    txa
        and #$08
        bne @spc
        lda #1
        sta key_2
@spc:   txa
        and #$10
        bne @kc
        lda input_bits
        ora #IN_FIRE
        sta input_bits

@kc:    lda #$fb                ; C
        jsr kbd_col
        and #$10
        bne @kb
        lda #1
        sta key_c
@kb:    lda #$f7                ; B
        jsr kbd_col
        and #$10
        bne @any
        lda #1
        sta key_b

@any:   lda #$00                ; every key, joysticks not selected
        sta KBD_LATCH
        lda #$ff
        sta TED_KBD
        lda TED_KBD
        cmp #$ff
        beq @idle
        lda #1
        sta key_held
@idle:  lda #$ff
        sta KBD_LATCH
        sta TED_KBD
        cli
        rts
