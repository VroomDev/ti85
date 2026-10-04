;; TED matrix. Keyboard via $FD30, joysticks via $FF08. Active low.
;; Column $EF holds I, J, K, and M. L is $DF. Space is $7F.
;; Port 1 select is $FB, fire bit $40. Port 2 select is $FD, fire bit $80.

.include "game.inc"

.export read_input
.export input_bits
.export key_held
.export key_c
.export key_b

.segment "BSS"
input_bits:     .res 1
key_held:       .res 1
key_c:          .res 1
key_b:          .res 1
joy_raw:        .res 1

.segment "CODE"

;; A = column select → A = row bits (joystick latch held off)
kbd_col:
        sta KBD_LATCH
        lda #$ff
        sta TED_KBD
        lda TED_KBD
        rts

;; A = $FF08 select. X = fire bit. Directions are bits 0–3. ORs into input_bits.
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
@merge: ora input_bits
        sta input_bits
@out:   rts

read_input:
        lda #0
        sta input_bits
        sta key_held
        sta key_c
        sta key_b
        sei

        lda #$fb                ; port 1, fire bit 6
        ldx #$40
        jsr read_joy
        lda #$fd                ; port 2, fire bit 7
        ldx #$80
        jsr read_joy

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

@kl:    lda #$df                ; L right
        jsr kbd_col
        and #$04
        bne @sp
        lda input_bits
        ora #IN_RIGHT
        sta input_bits

@sp:    lda #$7f                ; Space fire
        jsr kbd_col
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
