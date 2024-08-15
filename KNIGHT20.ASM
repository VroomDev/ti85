;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Knight 2.0 by Stephane JANTZEN - january 1995
;; Edited and corrected by Dan EBLE - january 1995
;;
;;
;; The aim of this game is to fill a chess board with
;; a knight.
;;
;; The first program I've written for TI-85, even
;; before having a graph-link. Of course, as any first
;; program, it is neither clean nor optimized. But
;; as it is not a very interesting game ....
;;
;; Feel free to do whatever you want with this file,
;; except putting your name in and recompiling it :)
;;
;; Stephane.Jantzen@scinfo.u-nancy.fr
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


#include "ti-85.h"

;----------------------------------------------------------------------------
; Text memory
;----------------------------------------------------------------------------

coord_x         =$80DF                  ;x : current row
coord_y         =$80E0                  ;y : current col
coord_p         =$80E1                  ;p : previous row
coord_q         =$80E2                  ;q : previous col
dummy_1         =$80E3                  ;local variable
score           =$80E4
row1            =$80E5                  ;checker is stored here
row2            =$80E6                  ;labels from "row2" to
row3            =$80E7                  ;"row8" are not necessary
row4            =$80E8                  ;just to remind that
row5            =$80E9                  ;memory has been reserved.
row6            =$80F0
row7            =$80F1
row8            =$80F2

;----------------------------------------------------------------------------
; Title
;----------------------------------------------------------------------------

.org    0
.db     "Knight v2.0",0

;----------------------------------------------------------------------------
; Program start
;----------------------------------------------------------------------------

 ld      A,$01                  ;the starting point is the
 ld      (score),A              ;first box of first line.
 rrca
 ld      (row1),A

;title is displayed.

 ROM_CALL(CLEARLCD)
 set     3,(IY+5)               ;white on black.
 ld      HL,$0003
 ld      (CURSOR_ROW),HL
 ld      HL,(PROGRAM_ADDR)
 push    HL                     ;* save PRORGAM_ADDR for later
 ld      DE,Title
 add     HL,DE
 ROM_CALL(D_ZT_STR)
 res     3,(IY+5)               ;black on white.

EnterLoop:
 call GET_KEY
 cp 9
 jr nz, EnterLoop

;screen is initialised.

 ROM_CALL(CLEARLCD)
 ld      HL,$1000
 ld      (CURSOR_ROW),HL
 pop     HL                     ;* recall PROGRAM_ADDR
 push    HL                     ;* save PRORGAM_ADDR for later
 ld      DE,Braces
 add     HL,DE
 push    HL                     ;* save -> Braces
 ROM_CALL(D_ZT_STR)
 ld      HL,$1003
 ld      (CURSOR_ROW),HL
 pop hl                         ;* restore -> Braces
 ROM_CALL(D_ZT_STR)
 ld      HL,$1102
 ld      (CURSOR_ROW),HL
 pop hl                         ;* recall PROGRAM_ADDR
 push hl                        ;* save PRORGAM_ADDR for later
 ld      DE,Last
 add     HL,DE
 ROM_CALL(D_ZT_STR)
 ld      HL,$1105
 ld      (CURSOR_ROW),HL
 pop hl                         ;* recall PROGRAM_ADDR
 ld      DE,Ok
 add     HL,DE
 ROM_CALL(D_ZT_STR)

;initialisation of field:

 ld      HL,$0000               ;two loops are embedded
 ld b, 8

InitBoard:
 ld     (CURSOR_ROW),HL         ;* using HL here is a byte shorter than BC
 ld a, 'o'
 ROM_CALL(TR_CHARPUT)           ;* Don't bother with a string; just do this
 inc     H
 inc     H
 ld a, h
 cp 16
 jr c, InitBoard
 ld      H,0
 inc     L
 djnz InitBoard

GameLoop:                       ;beginning of the game
 ld HL,(coord_x)
 sla h                          ;the position of player
 ld (CURSOR_ROW),HL             ;is displayed.
 ld a, '+'
 ROM_CALL(TX_CHARPUT)
 ld      HL,$1100
 ld      (CURSOR_ROW),HL
 ld      A,(coord_x)            ;current x is displayed
 add a, '0'
 ROM_CALL(TR_CHARPUT)
 ld      HL,$1300
 ld      (CURSOR_ROW),HL
 ld      A,(coord_y)            ;current y is displayed
 add a, '0'
 ROM_CALL(TR_CHARPUT)
 ld      HL,$1103
 ld      (CURSOR_ROW),HL
 ld      A,(coord_p)            ;previous x is displayed
 add a, '0'
 ROM_CALL(TR_CHARPUT)
 ld      HL,$1303
 ld      (CURSOR_ROW),HL
 ld      A,(coord_q)            ;previous y is displayed
 add a, '0'
 ROM_CALL(TR_CHARPUT)
 ld      HL,$0F06
 ld      (CURSOR_ROW),HL
 ld hl, (score)
 ld h, 0
 ROM_CALL(D_HL_DECI)            ; display score

KeyLoop:                        ;tests for keyboard input
 call    GET_KEY                ;loops if no key has been
 cp      0                      ;pressed.
 jr      z,KeyLoop
 cp $37                         ; exit
 ret z

 push af                        ;not enough registers !
				;test whether or not the player's box is busy
 ld a,(coord_y)
 ld b, a
 inc b
 ld c, 1

ShiftLoop:
 rrc c
 djnz ShiftLoop
 ld hl, row1
 ld a, (coord_x)
 add a, l
 ld l, a
 ld a, c
 and (hl)
 ld a, 'o'
 jr z, Motion
 ld a, 'x'

Motion:                         ;erases the current pos, refreshes the box.
 ld hl, (coord_x)               ;* hl = player's coordinates
 sla h
 ld (CURSOR_ROW),hl
 ROM_CALL(TR_CHARPUT)
 srl h
 pop af

G_Left:
 cp      $2
 jr      nz,G_Right
 dec     h
 bit     7,h                    ;new x < 0 ?
 jr      z,EndMove
 ld      h,0
 jr      EndMove

G_Right:                          ;GetKey = G_Right ?
 cp      $3
 jr      nz,G_G_Up
 inc     h
 bit     3,h                    ;new x > 7 ?
 jr      z,EndMove
 ld      h,7
 jr      EndMove

G_G_Up:                             ;GetKey = G_G_Up ?
 cp      $4
 jr      nz,G_Down
 dec     L
 bit     7,L                    ;new y < 0 ?
 jr      z,EndMove
 ld      L,0
 jr      EndMove

G_Down:                           ;GetKey = G_Down ?
 cp      $1
 jr      nz,Action
 inc     L
 bit     3,L                    ;new y > 7 ?
 jr      z,EndMove
 ld      L,7

EndMove:
 ld (coord_x), hl
 JUMP_(GameLoop)

Action:                         ;GetKey = 2nd ?
 cp      $36
 JUMP_NZ(GameLoop)              ;compares current pos. with former valid one.
 ld      A,(coord_x)            ;the new box is valid if abs((x-p)(y-q))=2
 ld b, a                        ;and if the current box has not been tested
 ld a, (coord_p)                ;yet.
 sub     B
 jr nc, Act2
 neg

Act2:
 ld      D,A                    ;abs(x-p) is stored in D
 ld      A,(coord_y)
 ld b, a
 ld      a,(coord_q)
 sub     B
 jr nc, Act3
 neg

Act3:
 ld      E,A                    ;abs(y-q) is stored in E
				
 cp      2                      ;abs(y-q) = 2 ?
 jr      nz,Act4
 ld      A,D
 cp      1                      ;abs(x-p) = 1 ?
 jr      z,Act5
 JUMP_(GameLoop)

Act4:
 cp 1                           ;abs(y-q) = 1 ?
 JUMP_NZ(GameLoop)
 ld a, d
 cp 2                           ;abs(x-p)=2 ?
 JUMP_NZ(GameLoop)

Act5:                           ;valid box if untested (same thing as testing
 ld a,(coord_y)                 ;to redraw box.
 ld b, a
 inc b
 ld c, 1

ShiftLoop2:
 rrc c
 djnz ShiftLoop2
 ld hl, row1
 ld a, (coord_x)
 add a, l
 ld l, a
 ld a, c
 and (hl)
 JUMP_NZ(GameLoop)              ;box is not free
 ld a, c
 or (hl)                        ; fill box
 ld (hl), a

 ld      HL,(coord_x)           ;current position ->   (using HL saves space)
 ld      (coord_p),HL           ;valid position

 ld      A,(score)
 inc     A
 ld (score), a
 cp      64
 JUMP_NZ(GameLoop)

 ROM_CALL(CLEARLCD)
 set     3,(IY+5)               ;white on black.
 ld      HL,$0000
 ld      (CURSOR_ROW),HL
 ld      HL,(PROGRAM_ADDR)
 ld      DE,Winner              ;you've won !!!
 add     HL,DE
 ROM_CALL(D_ZT_STR)

EndLoop:
 call    GET_KEY
 cp      0
 jr      z,EndLoop
 ret

;----------------------------------------------------------------------------
; Strings
;----------------------------------------------------------------------------

Title:  .db     "     Knight v2.0     "
	.db     "  S. JANTZEN - 1995  ",0
Braces: .db     "( , )",0
Last:   .db     "Last:",0
Ok:     .db     "Ok:",0
Winner  .db     "     You've won !    ",0

.END
