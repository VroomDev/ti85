;;Chris Busch
;;Copyright 1995


;;;;;;;;;;;;initsprite
;;
;;initspr(IX=sprite*,de=picture,bc=extra bytes,hl=videostart)
;;calling:
;;destroys: hl
initspr:
   ld      (ix+sprxyoffh),h    ;sprxy=videomem
   ld      (ix+sprxyoffl),l    ;
   ld      (oldxy),hl           ;oldxy=sprxy
   ld      HL,(PROGRAM_ADDR)
   add     HL,DE
   ld      (ix+sprpicoffh),h   ;pix=picture
   ld      (ix+sprpicoffl),l
   ld      (ix+sprextra1),b     ;load "extra bytes"
   ld      (ix+sprextra2),c
   ret

;;movespr
;;movespr(IX=sprite*,a=direction)
;;calling:
;;destroys: bc,ix,hl,a
movespr:
   ;;;;;;probably movement
   ;;;;;;do premovement stuff here
   ld      h,(ix+sprxyoffh)    ;oldxy=sprxy
   ld      l,(ix+sprxyoffl)
   ld      (oldxy),hl      ;oldxy is shared
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
   cp      K_GRAPH
   jr      z, drawloop
   jr      skipwall
movesprbye:
   ld   a,wallid
skipwall:
   ld   (hitxyval),a
   ret                 ;no movement was selected
keyup:
   ;;hlydec(sprxy)      ;;ASSUME hl=sprxy
   ld   bc,$FF80
   add  hl,bc          ;hl-=scrwidth*sprlength
   ld   a,h            ;if( h<$FC ) {
   cp   $FC            ;   goto gameloop
   jr   C,movesprbye   ;}
   jr   storesprxy
keydown:
   ;;hlyinc(sprxy)
   ld   bc,scrwidth*sprlength
   add  hl,bc          ;hl+=scrwidth*sprlength
   ld   a,h            ;if( h<$FC ) {
   cp   $FC            ;   goto gameloop
   jr   C,movesprbye   ;}
   jr   storesprxy
keyleft:
   ;;hlxdec(sprxy)
   ;;ld   hl,(sprxy)     ;hl=sprxy
   ld   a,l            ;if( l&0xF==0) {
   and  $0F            ;
   cp   0              ;    goto gameloop
   jr   z,movesprbye   ;}
   dec  hl             ;hl--
   jr   storesprxy
keyright:
   ;;hlxinc(sprxy)
   ld   a,l            ;if( l&0x0F==0x0F) {
   and  $0F            ;
   cp   $0F            ;    goto gameloop
   jr   z,movesprbye   ;}
   inc  hl             ;hl--
storesprxy:
   ld   (hitxy),hl
   ld   a,(hl)
   ld   (hitxyval),a
   cp   0
   jr   nz,enddrawspr
   ld   (ix+sprxyoffh),h ;sprxy=hl
   ld   (ix+sprxyoffl),l
;  jr   drawloop
drawloop:
    push    ix
    ld      ix,(oldxy)
    ;;;;;;;;;;;;;;;;;;;;;CALL_(erasespr)
    ld      (ix+scrwidth*0),0
    ld      (ix+scrwidth*1),0
    ld      (ix+scrwidth*2),0
    ld      (ix+scrwidth*3),0
    ld      (ix+scrwidth*4),0
    ld      (ix+scrwidth*5),0
    ld      (ix+scrwidth*6),0
    ld      (ix+scrwidth*7),0
    ;;;;;;;;;;;;;;;;;;;;;assume hl=sprxy
    pop     ix
    ld      b,(ix+sprpicoffh)
    ld      c,(ix+sprpicoffl)
    push    bc
    pop     ix                     ;ix=sprpic
#define putline(offset)    ld      a,(IX+offset)
#defcont   \ ld      (hl),a
#defcont   \ add     hl,bc
;;drawspr
;;draw(hl=XY,ix=picture)
;;calling:  push XY \ push picture \ call putsprite
;;destroys: bc,ix,hl,a
drawspr:    ;;;;;NOTICE!! This function is still valid keep it that way
   ld      bc,scrwidth         ;bc=scrwidth
   putline(0)
   putline(1)
   putline(2)
   putline(3)
   putline(4)
   putline(5)
   putline(6)
   putline(7)
enddrawspr:
   ret
;;end drawspr
;;;;end movespr

;;erasespr
;;erasespr(sprxy)
;;calling:   ld ix,ASDF / call erasespr
;;destroys: ix ;IX=start address for pixel puts
erasespr:
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
