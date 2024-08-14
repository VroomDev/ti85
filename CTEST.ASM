;;Chris Busch

#include "ti-85.h"

;;;;;;
;;text memory
;;;;;;

xspot           =$80DF                  ;x : current row
yspot           =$80E0                  ;y : current col
coordp          =$80E1                  ;p : previous row
coordq          =$80E2                  ;q : previous col
dummy1          =$80E3                  ;local variable
score           =$80E4
row1            =$80E5                  ;checker is stored here
oldxy           =$80E6                  ;labels from "row2" to
oldxy_          =$80E7                  ;"row8" are not necessary
pix             =$80E8                  ;just to remind that
pix_            =$80E9                  ;memory has been reserved.
sprxy           =$80F0
sprxy_          =$80F1                  ;what_ shows reservation only
randvar         =$80F2

;----------------------------------------------------------------------------
; Title
;----------------------------------------------------------------------------
.org    0
.db     "Crunch v0.1"

;----------------------------------------------------------------------------
; macro section
;----------------------------------------------------------------------------

;;;;;#include "gamemacs.h"

;----------------------------------------------------------------------------
; Program start
;----------------------------------------------------------------------------

main:
   ROM_CALL(CLEARLCD)

   set     3,(IY+5)               ;white on black.
   ld      HL,$0003
   ld      (CURSOR_ROW),HL
   ld      HL,$0000
   ld      (CURSOR_COL),HL
   ld      HL,(PROGRAM_ADDR)
   ld      DE,Title
   add     HL,DE
   ROM_CALL(D_ZT_STR)
   res     3,(IY+5)               ;black on white.

wait4enter:
   call    GET_KEY
   ;;add rand seeder
   ld      a,(randvar)
   add     a,13
   ld      (randvar),a
   cp      K_ENTER
   jr      nz, wait4enter

   ;;;;;;;;;;;;initsprite
   ld      hl,VIDEO_MEM
   ld      (sprxy),hl         ;sprxy=videomem
   ld      (oldxy),hl         ;oldxy=sprxy
   ld      HL,(PROGRAM_ADDR)
   ld      DE,picture
   add     HL,DE
   ld      (pix),hl           ;pix=picture

drawloop:
;   ld      hl,(oldxy)
;   push    hl
;   CALL_(erasespr)
;   ld      hl,(sprxy)
;   push    hl
;   ld      hl,(pix)
;   push    hl
;   CALL_(drawspr)

    ld      ix,(oldxy)
    CALL_(erasespr)
    ld      hl,(sprxy)
    ld      ix,(pix)
    CALL_(drawspr)

gameloop:
   ;;;;;;start keyboard handling
   call    GET_KEY
   cp      K_NOKEY
   jr      z, nokey
   cp      K_EXIT
   jr      z, quit
   ;;;;;;probably movement
   ;;;;;;do premovement stuff here
   ld      hl,(sprxy)   ;oldxy=sprxy
   ld      (oldxy),hl
   ;;;;;;check  movement
movement:  ;;;;;;;;; ASSUME a=getkey
   cp      K_UP
   jr      z, keyup
   cp      K_DOWN
   jr      z, keydown
   cp      K_LEFT
   jr      z, keyleft
   cp      K_RIGHT
   jr      z, keyright
   cp      K_SECOND
   jr      z, keyrandom
nokey:
   jr      gameloop
keyup:
   ;;hlydec(sprxy)
   ld   hl,(sprxy)     ;hl=sprxy
   ld   bc,$FF80
   add  hl,bc          ;hl-=16*8
   ld   a,h            ;if( h<$FC ) {
   cp   $FC            ;   goto gameloop
   jr   C,gameloop     ;}
   ld   (sprxy),hl     ;sprxy=hl
   jr   drawloop
keydown:
   ;;hlyinc(sprxy)
   ld hl,(sprxy)       ;hl=sprxy
   ld   bc,16*8
   add  hl,bc          ;hl+=16*8
   ld   a,h            ;if( h<$FC ) {
   cp   $FC            ;   goto gameloop
   jr   C,gameloop     ;}
   ld   (sprxy),hl     ;sprxy=hl
   jr   drawloop
keyleft:
   ;;hlxdec(sprxy)
   ld   hl,(sprxy)     ;hl=sprxy
   ld   a,l            ;if( l&0xF==0) {
   and  $0F            ;
   cp   0              ;    goto gameloop
   jr   z,gameloop     ;}
   dec  hl             ;hl--
   ld   (sprxy),hl     ;sprxy=hl
   jr      drawloop
keyright:
   ;;hlxinc(sprxy)
   ld   hl,(sprxy)     ;hl=sprxy
   ld   a,l            ;if( l&0x0F==0x0F) {
   and  $0F            ;
   cp   $0F            ;    goto gameloop
   jr   z,gameloop     ;}
   inc  hl             ;hl--
   ld   (sprxy),hl     ;sprxy=hl
   jr   drawloop
quit:
   ret               ;end game
keyrandom:
   CALL_(rand)
   and     $03
   inc     a
   jr      movement
;;;;;;;;;functions

#include "rand.asm"

#define putline(offset)    ld      a,(IX+offset)
#defcont   \ ld      (hl),a
#defcont   \ add     hl,bc
;;drawspr
;;draw(XY,picture)
;;calling:  push XY \ push picture \ call putsprite
;;destroys: bc,ix,hl,a
drawspr:
 ;  pop     bc          ;save (sp)
;   pop     ix          ;IX=start address for bitmap
;   pop     hl          ;hl=start address for pixel puts
;   push    bc          ;restore (sp)
   ld      bc,16         ;bc=16
   putline(0)
   putline(1)
   putline(2)
   putline(3)
   putline(4)
   putline(5)
   putline(6)
   putline(7)
   ret
;;end drawspr

;;erasespr
;;erasespr(XY)
;;calling:  push XY \ call erasespr
;;destroys: bc,ix
erasespr:
;   pop     bc          ;save (sp)
;   pop     ix          ;IX=start address for pixel puts
;   push    bc          ;restore (sp)
   ld      (ix+16*0),0
   ld      (ix+16*1),0
   ld      (ix+16*2),0
   ld      (ix+16*3),0
   ld      (ix+16*4),0
   ld      (ix+16*5),0
   ld      (ix+16*6),0
   ld      (ix+16*7),0
   ret
;;end erasesprite


;----------------------------------------------------------------------------
; data section
;----------------------------------------------------------------------------


;;sprite definition
;;struct sprite {
;;    void* vidmem
;;    void*
;;}
sprvidmem = 0  ;sprite video memory location
sprpic    = 2  ;sprite picture info
sprsize   = 10



Title:   .db     "     Crunch v0.0     "
         .db     "(C)1995   Chris Busch"
         .db     "     <hit enter>     ",0
picture: .db     $FF,$C3,$c3,$db,$db,$c3,$c3,$FF


   .END
