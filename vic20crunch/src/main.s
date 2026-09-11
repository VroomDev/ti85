;; Crunch VIC-20 — main (SPEC.md + CRUNCH.ASM)

.include "game.inc"

.import init_graphics
.import wait_vrefresh
.import blit_playfield
.import clear_screen
.import draw_hud
.import load_level
.import init_sprites
.import try_spawn
.import update_player
.import update_monsters
.import update_bullet
.import silence_vic
.import play_audio_frame
.import read_input
.import input_bits
.import level
.import score
.import health
.import hiscore
.import game_over_flag
.import next_level_flag
.import randvar
.import inc_score

.segment "CODE"

.export main
.export update_hud
.proc main
        jsr init_graphics
        cli                     ; kernal IRQ → jiffy $A0–$A2
        jsr silence_vic

        lda #0
        sta hiscore
        sta hiscore+1
        sta randvar

        ;; --- intro (level 1 backdrop, title, song, wait key) ---
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
        lda #$99                ; BCD 9999 + StartLevel inc → 0000
        sta score
        sta score+1
        lda #5                  ; health digit '5' → we use numeric 5
        sta health
        lda #1
        sta level

        ;; --- startlevel ---
startlevel:
        jsr load_level_cur
        jsr inc_score           ; CRUNCH startlevel: score $FF→0 first time
        jsr init_sprites
        jsr start_chrome
        jsr wait_vrefresh
        jsr blit_playfield

gameloop:
        jsr update_player
        jsr try_spawn
        jsr update_monsters
        jsr update_bullet

@vb:    jsr wait_vrefresh
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
        jsr bump_level_cap
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

;; if level < monsternum+1 (22), level++
bump_level_cap:
        lda level
        clc
        adc #1
        cmp #MONSTER_MAX+1
        beq :+
        sta level
:
        rts

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
@done:
        rts

wait_fire_or_key:
:       jsr read_input
        lda input_bits
        and #IN_FIRE
        bne @up
        lda $C5
        cmp #$40
        beq :-
@up:    jsr read_input
        lda input_bits
        and #IN_FIRE
        bne @up
        lda $C5
        cmp #$40
        bne @up
        rts

update_hud:
        ;; S:dddd ♥n L:dd  at row 16
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

;; A = BCD byte → two screen digits at ($fb),Y
put_bcd:
        pha
        lsr
        lsr
        lsr
        lsr
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
:       lda title,x
        beq :+
        sta SCREEN,x
        lda #COL_WHITE
        sta COLOR_RAM,x
        inx
        bne :-
:
        rts

draw_gameover:
        ldx #0
:       lda gameover,x
        beq :+
        sta SCREEN+GO_ORIGIN,x
        lda #COL_PURPLE
        sta COLOR_RAM+GO_ORIGIN,x
        inx
        bne :-
:
        rts

draw_newlevel:
        ldx #0
:       lda newlevel,x
        beq :+
        sta SCREEN+NL_ORIGIN,x
        lda #COL_WHITE
        sta COLOR_RAM+NL_ORIGIN,x
        inx
        bne :-
:
        rts

.segment "CODE2"

bin_to_dec:
        ldx #$ff
        sec
:       inx
        sbc #10
        bcs :-
        adc #10
        sta ones
        stx tens
        rts

;; A = VBlank count
wait_vblanks:
        sta ones
:       jsr wait_vrefresh
        dec ones
        bne :-
        rts

;; A = jiffy count ($A2; IRQ is on)
wait_jiffies:
        sta ones
:       lda JIFFY_LO
:       cmp JIFFY_LO
        beq :-
        dec ones
        bne :--
        rts

.macpack cbm
;; CRUNCH.ASM title — PETSCII uppercase letters = screen codes $01+
title:
        ;        0123456789012345678901
        scrcode "crunch (c)1996 chris b"
        .byte 0

gameover:
        scrcode "end"
        .byte 0
newlevel:
        scrcode "next"
        .byte 0

.segment "CODE3"

start_chrome:
        jsr clear_over
        jsr draw_hiscore
        jsr draw_hud
        jmp update_hud

clear_over:
        ldx #3
        lda #$A0
:       sta SCREEN+GO_ORIGIN,x
        dex
        bpl :-
        rts

draw_hiscore:
        ldx #HI_LEN-1
        lda #$A0
:       sta SCREEN+HI_ORIGIN,x
        dex
        bpl :-
        lda hiscore
        ora hiscore+1
        beq @out
        lda #$08                ; H
        sta SCREEN+HI_ORIGIN
        lda #$09                ; I
        sta SCREEN+HI_ORIGIN+1
        lda #$3A                ; :
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
:       sta COLOR_RAM+HI_ORIGIN,x
        dex
        bpl :-
@out:   rts
