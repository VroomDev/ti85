; This is a simple demonstration of graphics on the TI-85 with ZShell.
; Do what you will with it.
;                                      Dan Eble

#INCLUDE "TI-85.H"

;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; Program data stored in text memory (80DF)
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

Y       =$80DF  ; y position
X       =$80E0  ; x position
DY      =$80E1  ; y velocity
DX      =$80E2  ; x velocity

;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; Program Title
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

.org 0
.db "Projectile",0

	ld a, 4         ; set memory page 4 (graphic routines are here)
	out (5), a

	ROM_CALL(CLEARLCD)

Launch:
	sub a
	ld (Y), a       ; set initial values
	inc a
	ld (X), a
	inc a
	ld (DX), a
	ld a, 11
	ld (DY), a

Fly:
	ld bc, (Y)      ; load ball coordinates into BC
	push bc
	CALL_(Point_on) ; display the square ball
	dec b
	CALL_(Point_on)
	inc c
	CALL_(Point_on)
	inc b
	CALL_(Point_on)
	CALL_(Delay)    ; wait a while
	ld hl, DY
	ld a, (hl)
	dec a           ; decrease y velocity (accelerate toward the ground)
	ld (hl), a
	ld a, (Y)
	add a, (hl)     ; change y position
	bit 7, a        ; if y>=0, don't bounce
	jr z, NoBounce
	ld a, (hl)      ; if y<0, don't bounce
	neg             ; make the downward velocity negative (point it up)
	ld b, a         ; multiply it by 7/8 (don't bounce as high)
	sla a
	add a, b
	sla a
	add a, b
	srl a
	srl a
	srl a
	ld (hl), a
	sub a
NoBounce:
	ld (Y), a
	ld hl, DX       ; change x position
	ld a, (X)
	add a, (hl)
	ld (X), a
	pop bc
	cp 128          ; if x>=128 ... (continued below)
	push af
	CALL_(Point_off)        ; first erase ball
	dec b
	CALL_(Point_off)
	inc c
	CALL_(Point_off)
	inc b
	CALL_(Point_off)
	pop af          ; (continued from above) ... launch ball again
	jr nc, Launch

	call GET_KEY
	cp $37
	ret z   ; return if [EXIT] is pressed
	jr Fly  ; otherwise, keep ball in flight
	
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; Turn on point.  B=x  C=y  ;
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; . (0,63)       . (127,63) ;
;                           ;
;   Screen Layout           ;
;                           ;
; . (0,0)        . (127,0)  ;
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

Point_on:

	push bc
	call $6c9a      ; HL=byte offset in video buffer, A=2^(bit to change)
	ld de, $FC00
	add hl, de
	or (hl)
	ld (hl),a
	pop bc
	ret

;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; Turn off point.  B=x  C=y  ;
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; . (0,63)       . (127,63) ;
;                           ;
;   Screen Layout           ;
;                           ;
; . (0,0)        . (127,0)  ;
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

Point_off:

	push bc
	call $6c9a      ; HL=offset, A=2^bit
	ld de, $FC00
	add hl, de
	xor 255
	and (hl)
	ld (hl),a
	pop bc
	ret

;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴
; Produce delay
;컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴

Delay:

	push af
	push bc
	ld bc, $2000
DelayLoop:
	dec bc
	ld a, b
	or c
	jr nz, DelayLoop
	pop bc
	pop af
	ret

.END

