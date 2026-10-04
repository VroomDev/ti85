;; Crunch C16 — main

.include "game.inc"

.import init_graphics
.import wait_vrefresh
.import blit_playfield
.import clear_screen
.import draw_hud
.import load_level
.import init_sprites
.import update_player
.import update_monsters
.import update_bullet
.import silence_vic
.import play_audio_frame
.import read_input
.import input_bits
.import key_held
.import level
.import score
.import health
.import hiscore
.import lfsr
.import game_over_flag
.import next_level_flag
.import inc_score

.segment "CODE"

.export main
.export update_hud
.proc main
        jsr init_graphics
        cli
        jsr silence_vic

        lda #0
        sta hiscore
        sta hiscore+1
        lda #$ac
        sta lfsr

intro:
        lda #1
        sta level
        jsr load_level_cur
        jsr clear_screen
        jsr draw_title
        jsr draw_hiscore
        jsr wait_vrefresh
        jsr blit_playfield
        jsr wait_fire_or_key

start_game:
        jsr silence_vic
        lda #$99
        sta score
        sta score+1
        lda #5
        sta health
        lda #1
        sta level

startlevel:
        jsr load_level_cur
        jsr inc_score
        jsr init_sprites
        jsr start_chrome
        jsr wait_vrefresh
        jsr blit_playfield

gameloop:
        jsr update_player
        jsr update_monsters
        jsr update_bullet

        jsr wait_vrefresh
        jsr blit_playfield
        jsr update_hud
        jsr play_audio_frame

        lda game_over_flag
        bne do_gameover
        lda next_level_flag
        bne do_next
        jmp gameloop

do_next:
        jsr silence_vic
        jsr draw_newlevel
        lda #39
        jsr wait_vblanks
        jsr bump_level
        jmp startlevel

do_gameover:
        jsr check_hiscore
        jsr draw_gameover
        lda #60
        jsr wait_jiffies
        jsr silence_vic
        jsr wait_fire_or_key
        jmp intro
.endproc

load_level_cur:
        lda level
        jmp load_level

bump_level:
        lda level
        cmp #LEVEL_CAP
        bcs @stay
        inc level
@stay:  rts

check_hiscore:
        lda score+1
        cmp hiscore+1
        bcc @done
        bne @set
        lda score
        cmp hiscore
        bcc @done
@set:   lda score
        sta hiscore
        lda score+1
        sta hiscore+1
@done:  rts

wait_fire_or_key:
@wait:  jsr read_input
        lda input_bits
        and #IN_FIRE
        bne @rel
        lda key_held
        beq @wait
@rel:   jsr read_input
        lda input_bits
        and #IN_FIRE
        bne @rel
        lda key_held
        bne @rel
        rts

update_hud:
        lda #<(SCREEN+HUD_ORIGIN)
        sta $fb
        lda #>(SCREEN+HUD_ORIGIN)
        sta $fc
        ldy #HUD_PAD+2
        lda score+1
        jsr put_bcd
        ldy #HUD_PAD+4
        lda score
        jsr put_bcd
        ldy #HUD_PAD+8
        lda health
        ora #$30
        sta ($fb),y
        lda level
        jsr bin_to_dec
        ldy #HUD_PAD+12
        lda tens
        ora #$30
        sta ($fb),y
        iny
        lda ones
        ora #$30
        sta ($fb),y
        rts

put_bcd:
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        ora #$30
        sta ($fb),y
        iny
        pla
        and #$0f
        ora #$30
        sta ($fb),y
        rts

.segment "BSS"
tens:   .res 1
ones:   .res 1

.segment "CODE"

draw_title:
        ldx #0
@a:     lda title1,x
        beq @b
        sta SCREEN+17,x
        lda #COL_WHITE
        sta COLOR_RAM+17,x
        inx
        bne @a
@b:     ldx #0
@c:     lda title2,x
        beq @d
        sta SCREEN+COLS+10,x
        lda #COL_WHITE
        sta COLOR_RAM+COLS+10,x
        inx
        bne @c
@d:     rts

draw_gameover:
        ldx #0
@g:     lda gameover,x
        beq @out
        sta SCREEN+GO_ORIGIN,x
        lda #COL_PURPLE
        sta COLOR_RAM+GO_ORIGIN,x
        inx
        bne @g
@out:   rts

draw_newlevel:
        ldx #0
@n:     lda newlevel,x
        beq @out
        sta SCREEN+NL_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+NL_ORIGIN,x
        inx
        bne @n
@out:   rts

bin_to_dec:
        ldx #$ff
        sec
@d:     inx
        sbc #10
        bcs @d
        adc #10
        sta ones
        stx tens
        rts

wait_vblanks:
        sta ones
@w:     jsr wait_vrefresh
        dec ones
        bne @w
        rts

wait_jiffies:
        sta ones
@outer: lda JIFFY_LO
@spin:  cmp JIFFY_LO
        beq @spin
        dec ones
        bne @outer
        rts

.macpack cbm
title1:
        scrcode "crunch"
        .byte 0
title2:
        scrcode "(c)1996 chris busch"
        .byte 0
gameover:
        scrcode "done"
        .byte 0
newlevel:
        scrcode "next"
        .byte 0

start_chrome:
        jsr clear_over
        jsr draw_hiscore
        jsr draw_hud
        jmp update_hud

clear_over:
        ldx #3
        lda #32
@c:     sta SCREEN+GO_ORIGIN,x
        dex
        bpl @c
        rts

draw_hiscore:
        ldx #HI_LEN-1
        lda #32
@c:     sta SCREEN+HI_ORIGIN,x
        dex
        bpl @c
        lda hiscore
        ora hiscore+1
        beq @out
        lda #$08
        sta SCREEN+HI_ORIGIN
        lda #$09
        sta SCREEN+HI_ORIGIN+1
        lda #$3a
        sta SCREEN+HI_ORIGIN+2
        lda #<(SCREEN+HI_ORIGIN)
        sta $fb
        lda #>(SCREEN+HI_ORIGIN)
        sta $fc
        ldy #3
        lda hiscore+1
        jsr put_bcd
        ldy #5
        lda hiscore
        jsr put_bcd
        ldx #HI_LEN-1
        lda #COL_WHITE
@col:   sta COLOR_RAM+HI_ORIGIN,x
        dex
        bpl @col
@out:   rts
