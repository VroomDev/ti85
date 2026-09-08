;; VIC-I SFX — coin chirp, kill noise, hurt bass

.include "game.inc"

.export silence_vic
.export play_audio_frame
.export play_coin
.export play_kill
.export play_hurt

VIC_BASS        = $900A
VIC_ALTO        = $900B
VIC_SOPRANO     = $900C
VIC_VOLUME      = $900E

.segment "ZEROPAGE"
sfx_dur:        .res 1

.segment "CODE"

silence_vic:
        lda #0
        sta VIC_BASS
        sta VIC_ALTO
        sta VIC_SOPRANO
        sta VIC_NOISE
        sta VIC_VOLUME
        sta sfx_dur
        rts


.segment "SFXCODE"

play_coin:
        lda #$0f
        sta VIC_VOLUME
        lda #$e8
        sta VIC_SOPRANO
        lda #2
        sta sfx_dur
        rts

play_kill:
        lda #0
        sta VIC_SOPRANO
        lda #$0f
        sta VIC_VOLUME
        lda #$8a
        sta VIC_NOISE
        lda #4
        sta sfx_dur
        rts

play_audio_frame:
        lda sfx_dur
        beq :+
        dec sfx_dur
        bne :+
        jmp silence_vic
:
        rts

.segment "CODE2"

play_hurt:
        lda #0
        sta VIC_SOPRANO
        sta VIC_NOISE
        lda #$0f
        sta VIC_VOLUME
        lda #$86
        sta VIC_BASS
        lda #3
        sta sfx_dur
        rts
