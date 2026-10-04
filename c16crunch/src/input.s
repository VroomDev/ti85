;; TED matrix. Keyboard via $FD30, joystick 1 via $FF08. Active low.
;; Column $EF holds I, J, K, and M. L is $DF. Space is $7F.

.include "game.inc"

.export read_input
.export input_bits
.export key_held

.segment "BSS"
input_bits:     .res 1
key_held:       .res 1

.segment "CODE"

;; A = column select → A = row bits (joystick latch held off)
kbd_col:
        sta KBD_LATCH
        lda #$ff
        sta TED_KBD
        lda TED_KBD
        rts

read_input:
        lda #0
        sta input_bits
        sta key_held
        sei

        ;; Joystick 1: keyboard latch off, select bit 2
        lda #$ff
        sta KBD_LATCH
        lda #$fb
        sta TED_KBD
        lda TED_KBD
        tax
        and #$01
        bne @jd
        lda #IN_UP
        sta input_bits
@jd:    txa
        and #$02
        bne @jl
        lda input_bits
        ora #IN_DOWN
        sta input_bits
@jl:    txa
        and #$04
        bne @jr
        lda input_bits
        ora #IN_LEFT
        sta input_bits
@jr:    txa
        and #$08
        bne @jf
        lda input_bits
        ora #IN_RIGHT
        sta input_bits
@jf:    txa
        and #$40
        bne @keys
        lda input_bits
        ora #IN_FIRE
        sta input_bits

@keys:  lda #$ef                ; I up, J left, M down, K fire
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
        bne @any
        lda input_bits
        ora #IN_FIRE
        sta input_bits

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
