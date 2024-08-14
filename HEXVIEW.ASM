;;;;;;;;;;;;;;;;;;;;;;hexview.asm
;From pgm@cgmsun.physics.utoledo.eduSun Dec 17 23:28:59 1995
;Date: Wed, 13 Dec 95 16:24:16 EST
;From: Philip Montgomery <pgm@cgmsun.physics.utoledo.edu>
;Reply to: list-zshell@kuai.se
;To: list-zshell@kuai.se
;Subject: Re: LZ: hex editor for zshell
;
;Okay, here's some example code for a hex viewer that always you to
;scroll up and down through memory with the up, down, and two other keys
;I forget ...  Oh yeah, + and - jump up and down by 256 bytes at a time.
;Anyway, this was my first Zshell program, put here for educational
;purposes.

;Press [ALPHA] to see the text in the right most column.  Sometimes it
;messes up the screen though.  Use * and / to jump by 0x1000.
;The keys are situated like you were using a text editor.
;So up scrolls up but decrements the addresses.

;;;;;;;;;;;;;;;;;;;
;;;History:
;;;version 0.0: initial release by Philip Montgomery
;;;        0.1: Added star and slash big jumps by $1000 and added "alpha"
;;;             mode.  ZShell 4.0 compatable. - Chris Busch


#include "ti-85.h"
; Copyright 1995, Philip Montgomery
; pgm@cgmsun.physics.utoledo.edu

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;text memory
CmdY	=TEXT_MEM     ;$80DF	; y position
CmdX	=CmdY+1       ;$80E0	; x position
HexPtr	=CmdX+1    ;$80e1
CurPtr	=HexPtr+2  ;$80e3	; ptr to first dump
curmode =CurPtr+2   ;current mode bits
savehl  =curmode+1  ;save hl for char dump
lastvar   =savehl+2


;;bit modes: curmode has the following modes in it.
alphamode =0  ;print the ascii in the right column, set=yes

.org 0
PrintStr:
.db "Hex View v0.1", 0

main:
	ld a, 4
	out (5), a

	ROM_CALL(CLEARLCD)

   ld   a,0
	ld (CURSOR_X),a ;hl
	ld (CURSOR_Y),a ;hl

	ld hl, (HexPtr)
	CALL_(DrawScreen)

NotDone:
	call GET_KEY
	cp $37
	ret z
	cp K_UP		; down
	jr z, DrawDown
	cp K_DOWN		; up
	jr z, DrawUp
	cp K_PLUS
	jr z, JumpDown
	cp K_MINUS
	jr z, JumpUp
   cp K_STAR
   jr z, bigjumpdn
   cp K_SLASH
   jr z, bigjumpup
   cp K_ALPHA
   CALL_Z(setalpha)
	jr NotDone


DrawDown:
	ld hl, -8
DoAdvance:
	ld de, (CurPtr)
	add hl, de
	ld (CurPtr), hl
   ld a,(curmode)
   bit alphamode,a
   jr  z,skipclr
   ROM_CALL(CLEARLCD)
skipclr:
	CALL_(DrawScreen)
	jr NotDone

DrawUp:
	ld hl, 8
	jr DoAdvance

JumpDown:
	ld hl, 0100h
	jr DoAdvance

JumpUp:
	ld hl, - 0100h
	jr DoAdvance

bigjumpdn:
	ld hl, 1000h
	jr DoAdvance

bigjumpup:
	ld hl, - 1000h
	jr DoAdvance


;;;;;;;;drawscreen function
DrawScreen:
	push hl
	sub a
	ld (CURSOR_X), a
	ld (CURSOR_Y), a

	ld hl, (CurPtr)
	ld b, 8
NextRow:
	CALL_(DisplayLine)
	ld a, (CURSOR_Y)
	add a, 7
	ld (CURSOR_Y), a
	sub a
	ld (CURSOR_X), a
	dec b
	jr nz, NextRow

	pop hl
	ret
;;end drawscreen

;;;;;function displayline
DisplayLine:			; hl -> start of dump
	push de
	push bc

	ld a, h
	CALL_(PrintHex)
	ld a, l
	CALL_(PrintHex)		; Print address being decoded

	ld b, 3
NextBlank:
	ld a, ' '
	ROM_CALL(M_CHARPUT)
	dec b
	jr nz, NextBlank
   ld  (savehl),hl      ;added cbusch
	ld b, 8			; Do 8 bytes
NextChar:
	ld a, (hl)
	inc hl
	CALL_(PrintHex)
	dec b
	jr nz, NextChar
   ld  a,(curmode)
   bit alphamode,a
   jr   z,noalphamode
   ld  hl,(savehl)
	ld b, 8			; Do 8 bytes
NextChar0:
	ld a, (hl)
	inc hl
	ROM_CALL(M_CHARPUT)
	dec b
	jr nz, NextChar0
noalphamode:
	pop bc
	pop de
	ret
;;;end display line


;;;;;;;;;;;printhex function
PrintHex:			; de destroyed
	push bc
	push de

	ld b, a
	and $0f0
	rrca
	rrca
	rrca
	rrca

	add a, 30h
	cp $3a
	jr c, hexnumber0
	add a, $7
hexnumber0:
	ROM_CALL(M_CHARPUT)

	ld a, b
	and $0f

	add a, 30h
	cp $3a
	jr c, hexnumber1
	add a, $7
hexnumber1:
	ROM_CALL(M_CHARPUT)
	pop de
	pop bc
	ret
;;;;;;;;;end printhex function

;;;void setalpha()
;;destroys a
setalpha:
   push af
   ROM_CALL(CLEARLCD)
   ld  a,(curmode)
   bit alphamode,a
   set alphamode,a
   jr  z,noclralpha
   res alphamode,a
noclralpha:
   ld  (curmode),a
   CALL_(DrawScreen)
   pop  af
   ret
;;end setalpha

.END
;;;;;;;;;;;;;;;;;;;;;;;end hexview.asm