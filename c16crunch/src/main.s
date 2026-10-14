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
.import key_1
.import key_2
.import joy1_fire
.import joy2_fire
.import key_c
.import key_b
.import key_p
.import level
.import score
.import health
.import hiscore
.import lfsr
.import game_over_flag
.import next_level_flag
.import inc_score
.import VERSION

.segment "CODE"

.export main
.export update_hud
.export two_player
.proc main
        jsr init_graphics
        cli
        jsr silence_vic

        lda #0
        sta hiscore
        sta hiscore+1
        sta two_player
        lda #1
        sta show_ver
        lda #$ac
        sta lfsr

intro:
        lda #1
        sta level
        jsr load_level_cur
        jsr clear_screen
        jsr draw_title
        jsr draw_hiscore
        lda show_ver
        beq @no_ver
        jsr draw_version
        lda #0
        sta show_ver
@no_ver:
        jsr draw_start_prompt
        jsr wait_vrefresh
        jsr blit_playfield
        jsr wait_fire_or_key

start_game:
        jsr silence_vic
        lda #$99
        sta score
        sta score+1
        lda #7
        sta health
        lda #0
        sta cheat_on
        sta b_was
        lda #1 ;THIS IS THE INITIAL LEVEL
        sta level

startlevel:
        jsr load_level_cur
        jsr inc_score
        jsr init_sprites
        jsr start_chrome
        jsr wait_vrefresh
        jsr blit_playfield

gameloop:
        jsr read_input
        ldx #0
        jsr update_player
        jsr update_bullet
        lda two_player
        beq @mons
        ldx #1
        jsr update_player
        jsr update_bullet
@mons:  jsr update_monsters
        jsr blit_playfield
        jsr update_hud
        jsr poll_code
        jsr poll_pause
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

;; 1 or joy1 fire → 1P. 2 or joy2 fire → 2P. Then wait for release.
wait_fire_or_key:
@wait:  jsr read_input
        lda key_2
        ora joy2_fire
        bne @two
        lda key_1
        ora joy1_fire
        beq @wait
        lda #0
        sta two_player
        beq @rel
@two:   lda #1
        sta two_player
@rel:   jsr read_input
        lda joy1_fire
        ora joy2_fire
        ora key_1
        ora key_2
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
cheat_on: .res 1
b_was:    .res 1
show_ver: .res 1
two_player: .res 1

.segment "CODE"

draw_title:
        ldx #0
@a:     lda title1,x
        beq @b
        sta SCREEN+15,x
        lda #COL_WHITE
        sta COLOR_RAM+15,x
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
        jmp draw_start_prompt

draw_start_prompt:
        ldx #0
@g:     lda startmsg,x
        beq @out
        sta SCREEN+START_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+START_ORIGIN,x
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

;; C latches the cheat and shows "?" on the bottom row.
;; B, once that latch is set, zeros the score and takes the next-level path.
poll_code:
        lda key_c
        beq @draw
        lda #1
        sta cheat_on
@draw:  lda cheat_on
        beq @edge
        lda #$3f
        sta SCREEN+CHEAT_MARK
        lda #COL_WHITE
        sta COLOR_RAM+CHEAT_MARK
@edge:  lda key_b
        cmp b_was
        beq @keep
        sta b_was
        cmp #1
        bne @keep
        lda cheat_on
        beq @keep
        lda #0
        sta score
        sta score+1
        lda #1
        sta next_level_flag
        jsr update_hud
@keep:  rts

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
        scrcode "c16 crunch"
        .byte 0
title2:
        scrcode "(c)1996 chris busch"
        .byte 0
startmsg:
        scrcode "press 1 or 2 to start game"
        .byte 0
newlevel:
        scrcode "next"
        .byte 0

start_chrome:
        jsr clear_start_prompt
        jsr clear_version
        jsr draw_hiscore
        jsr draw_hud
        jmp update_hud

;; First intro only. StartLevel wipes these nine cells before the score line.
draw_version:
        ldx #0
@v:     lda VERSION,x
        beq @out
        sta SCREEN+VER_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+VER_ORIGIN,x
        inx
        bne @v
@out:   rts

clear_version:
        ldx #VER_LEN-1
@c:     lda #$a0
        sta SCREEN+VER_ORIGIN,x
        lda #COL_BLUE
        sta COLOR_RAM+VER_ORIGIN,x
        dex
        bpl @c
        rts

clear_start_prompt:
        ldx #START_LEN-1
        lda #32
@c:     sta SCREEN+START_ORIGIN,x
        dex
        bpl @c
        rts

draw_hiscore:
        ldx #HI_LEN-1
        lda #32
@c:     sta SCREEN+HI_ORIGIN,x
        dex
        bpl @c
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
        rts

;; Upper RAM ($2A00+).
.segment "CODEHI"

;; P freezes the game. Wait for release, then P again to resume.
poll_pause:
        lda key_p
        beq @out
        jsr silence_vic
        jsr wait_vrefresh
        jsr draw_pause
@held:  jsr read_input
        lda key_p
        bne @held
@wait:  jsr read_input
        lda key_p
        beq @wait
@rel:   jsr read_input
        lda key_p
        bne @rel
        jsr wait_vrefresh
        jsr blit_playfield
@out:   rts

draw_pause:
        ldx #0
@p:     lda paused,x
        beq @done
        sta SCREEN+PAUSE_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+PAUSE_ORIGIN,x
        inx
        bne @p
@done:  rts

paused:
        scrcode "pause"
        .byte 0
