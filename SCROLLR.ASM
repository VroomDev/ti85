;Actually, I made one just a few hours ago, but it scrolls the pixels sideways. Scrolling up or
;down is EASY (just use ldir och lddr) but a horizontal scroll is much harder, so I made one...
;AND IT'S PRETTY FAST!!!!! RR (HL) and RL (HL) is just made for this routine...

;Here's the code: I hope someone (perhaps myself) will use it to make Super Mario Bros or
;something...

;Pressing left will scroll the screen one pixel to the left (surprising huh?) and pressing
;right... :) The pixel wrap around the screen also... that makes the program somewhat bigger.


; SCROLL-ROUTINE
;
; Made by Jimmy Mardell <mja@algonet.se>
;

#INCLUDE ti-85.h

.org 0
.db "Scroll",0

 ROM_CALL(CLEARLCD)

; Filling the screen with garbage

  ld de,$FC00
  ld hl,GRAPH_MEM
  ld bc,1024
  ldir

WaitKey:
 ld a,(KEY_1)
 cp K_LEFT
 jr z,ScrollLeft
 cp K_RIGHT
 jr z,ScrollRight
 cp K_EXIT
 jr nz,WaitKey
 call GET_KEY    ; Clearing buffer
 ret

ScrollLeft:
 ld hl,$FFFF
 ld b,64
LNewRow:
 ld d,h
 ld e,l
 push bc
 xor a
 ld b,16
LNewX:
 rl (hl)
 dec hl
 djnz LNewX
 ex de,hl
 adc a,(hl)
 ld (hl),a
 ex de,hl
 pop bc
 djnz LNewRow
 jr WaitKey

ScrollRight:
 ld hl,$FC00
 ld b,64
RNewRow:
 ld d,h
 ld e,l
 push bc
 xor a
 ld b,16
RNewX:
 rr (hl)
 inc hl
 djnz RNewX
 ex de,hl
 adc a,a
 rrca
 add a,(hl)
 ld (hl),a
 ex de,hl
 pop bc
 djnz RNewRow
 jr WaitKey

.end

;--
;Real name: Jimmy Mardell
;Email:     <mja@algonet.se>
;IRC-name:  Yarin
;Home-page: *BLUSH* Doesn't exist yet...
;
;"The truth you here is not always the truth you think you here" - Robert Jordan
;
;"I'm the operator with my pocket calculator" - Kraftwerk
;
