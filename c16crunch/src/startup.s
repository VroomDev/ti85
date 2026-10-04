;; Entry at $100D — do not return to BASIC

.include "game.inc"

.import main

.segment "CODE"
        sei
        cld
        ldx #$ff
        txs
        jsr main
hang:   jmp hang
