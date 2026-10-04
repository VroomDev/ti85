;; TED SFX — coin tone, kill noise, hurt tone

.include "game.inc"

.export silence_vic
.export play_audio_frame
.export play_coin
.export play_kill
.export play_hurt
.exportzp sfx_dur

;; $FF11: bits 0–3 volume (max 8), bit 4 voice 1, bit 6 voice 2 noise
SND_QUIET       = $00
SND_TONE        = $18           ; volume 8 + voice 1
SND_NOISE       = $48           ; volume 8 + voice 2 noise

.segment "ZEROPAGE"
sfx_dur:        .res 1

.segment "CODE"

silence_vic:
        lda #SND_QUIET
        sta TED_SND
        sta TED_V1LO
        sta TED_V2LO
        lda TED_V1HI
        and #$fc                ; voice 1 freq bits 8–9 off; keep unused bits
        sta TED_V1HI
        lda #0
        sta sfx_dur
        rts

play_coin:
        lda #SND_TONE
        sta TED_SND
        lda #$c0
        sta TED_V1LO
        lda TED_V1HI
        and #$fc
        sta TED_V1HI
        lda #4
        sta sfx_dur
        rts

play_kill:
        lda #SND_NOISE
        sta TED_SND
        lda #$80
        sta TED_V2LO
        lda #10
        sta sfx_dur
        rts

play_hurt:
        lda #SND_TONE
        sta TED_SND
        lda #$18
        sta TED_V1LO
        lda TED_V1HI
        and #$fc
        sta TED_V1HI
        lda #5
        sta sfx_dur
        rts

play_audio_frame:
        lda sfx_dur
        beq @out
        dec sfx_dur
        bne @out
        jmp silence_vic
@out:   rts
