;; VIC-I SFX — coin chirp, kill noise, hurt bass

.include "game.inc"

.export silence_vic
.export play_audio_frame
.export play_coin
.export play_kill
.export play_hurt
.export sfx_dur

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
        lda #240
        sta VIC_SOPRANO
        ;lda #228
        sta VIC_ALTO
        lda #4
        sta sfx_dur
        rts

play_kill:
        lda #10
        sta VIC_VOLUME
        sta sfx_dur
        lda #220
        ;lda #130
        sta VIC_BASS
        ;lda #148
        ;sta VIC_ALTO
        ;lda #220
        sta VIC_NOISE
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
        lda #140
        sta VIC_BASS
        ;lda #155
        sta VIC_ALTO
        ;lda #200
        sta VIC_NOISE
        lda #15
        sta VIC_VOLUME
        lda #30
        sta sfx_dur
        rts
