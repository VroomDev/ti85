;From CliffLian@aol.comSun Dec 17 23:33:56 1995
;Date: Sun, 17 Dec 1995 17:58:33 -0500
;From: CliffLian@aol.com
;Reply to: list-zshell@kuai.se
;To: list-zshell@kuai.se
;Subject: LZ: Contrast changer


#include "ti-85.h"

cont	=$80DF

.org 0
.db "contrast changer",0

	ld a,(CONTRAST)
	ld (cont),a
ky:
	call GET_KEY
	cp (K_EXIT)
	ret z
	cp (K_UP)
	jr z,up
	cp (K_DOWN)
	jr z,down
	jr ky
up:
	ld a,(cont)
	cp $1F
	jr z,ky
	inc a
	jr change
down:	
	ld a,(cont)
	cp 0
	jr z,ky
	dec a
change:
	ld (cont),a
	ld (CONTRAST),a
	out (2),a
	ld hl,$1000
	ld (CURSOR_ROW),hl
	ld hl,(cont)
	ROM_CALL(D_HL_DECI)
	jr ky
.end

