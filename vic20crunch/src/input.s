;; Keyboard via kernal $C5 only — do not take over $9122 (IEC hang).

.include "game.inc"

.export read_input
.export input_bits

VIA1_PRA        = $9111
VIA2_PRB        = $9120
VIA2_DDRB       = $9122

C5_I            = 12
C5_J            = 20
C5_L            = 21
C5_SPACE        = 32
C5_M            = 36
C5_K            = 44
C5_Q            = 48

.segment "BSS"
input_bits:     .res 1

.segment "CODE"

read_input:
        lda #0
        sta input_bits

        sei                     ; jiffy SCNKEY must not smash $9122/$9120
        lda VIA2_DDRB
        pha
        and #$7f
        sta VIA2_DDRB
        lda VIA1_PRA
        tax
        and #%00001100
        beq restore_ddrb
        txa
        and #%00000100
        bne :+
        lda input_bits
        ora #IN_UP
        sta input_bits
:
        txa
        and #%00001000
        bne :+
        lda input_bits
        ora #IN_DOWN
        sta input_bits
:
        txa
        and #%00010000
        bne :+
        lda input_bits
        ora #IN_LEFT
        sta input_bits
:
        txa
        and #%00100000
        bne :+
        lda input_bits
        ora #IN_FIRE
        sta input_bits
:
        lda VIA2_PRB
        and #%10000000
        bne :+
        lda input_bits
        ora #IN_RIGHT
        sta input_bits
:
restore_ddrb:
        pla
        sta VIA2_DDRB           ; restore so SCNKEY does not ghost SPACE→Q
        jsr $FF9F
        lda $C5
        cli
        cmp #$40
        beq @out
        cmp #C5_I
        bne :+
        lda input_bits
        ora #IN_UP
        sta input_bits
        rts
:
        cmp #C5_J
        bne :+
        lda input_bits
        ora #IN_LEFT
        sta input_bits
        rts
:
        cmp #C5_L
        bne :+
        lda input_bits
        ora #IN_RIGHT
        sta input_bits
        rts
:
        cmp #C5_M
        bne :+
        lda input_bits
        ora #IN_DOWN
        sta input_bits
        rts
:
        cmp #C5_K
        beq @fire
        cmp #C5_SPACE
        beq @fire
        cmp #C5_Q
        bne @out
        lda input_bits
        ora #IN_QUIT
        sta input_bits
        rts
@fire:  lda input_bits
        ora #IN_FIRE
        sta input_bits
@out:   rts
