;;Chris Busch
;;actor.asm

;;;;;;;;;;;;initsprite
;;
;;initspr(IX=sprite*,d=idtype,e=empty,bc=extra bytes,hl=videostart)
;;calling:
initspr:
   ld      (ix+sprxyoffh),h    ;sprxy=videomem
   ld      (ix+sprxyoffl),l    ;
   ld      (oldxy),hl           ;oldxy=sprxy
   ld      (ix+spridtype),d   ;pix=picture
   ld      (ix+sprempty),e
   ld      (ix+sprextra1),b     ;load "extra bytes"
   ld      (ix+sprextra2),c
   ret
;;end initspr

;;movespr
;;movespr(IX=sprite*,a=direction)
;;calling:
;;destroys: ix,hl,a,de
movespr:
   ;;;;;;get movement vector
   ;;;;;;ASSUME a=desired direction
   cp      K_UP                 ;if(a=up) {
   jr      nz, skipkeyup        ;
   ld      de,-levelwidth       ;   de=-levelwidth
   jr      domove               ;
skipkeyup:                      ;}else if(a=down) {
   cp      K_DOWN               ;
   jr      nz, skipkeydown      ;
   ld      de,levelwidth        ;   de=levelwidth
   jr      domove               ;
skipkeydown:                    ;}else if(a=left) {
   cp      K_LEFT               ;
   jr      nz, skipkeyleft      ;
   ld      de,-1                ;   de= -1
   jr      domove               ;
skipkeyleft:                    ;}else if(a=right) {
   cp      K_RIGHT              ;
   jr      nz, skipkeyright     ;
   ld      de,1                 ;   de= 1
   jr      domove               ;
skipkeyright:                   ;}else{
   ld      a,blankid            ;   hitxyval=blankid
   ld      (hitxyval),a         ;
   ret                          ;   return
domove:                         ;}
   ;ASSUME: de=movement direction
   ld      h,(ix+sprxyoffh)     ;hl=sprxyoff
   ld      l,(ix+sprxyoffl)     ;
   ld      (oldxy),hl           ;oldxy=sprxyoff
   add     hl,de                ;hl=sprxyoff+(de & 0x03FF)
   ld      a,h                  ;
   and     3                    ;
   ld      h,a                  ;
   ex      de,hl                ;de=map data offset
   ld      hl,GRAPH_MEM         ;calculate address into graph map
   add     hl,de                ;hl=graphmem+de
   ld      (hitxy),de           ;hitxy=   where on the map
   ld      a,(hl)               ;
   ld      (hitxyval),a         ;hitxyval=whats on the map
   bit     noerasebit,a         ;is the hitxyval object eraseable?
   jr      nz,skipstore
   ld      a,(playmode)         ;if( its a monster) {
   bit     isplayerbit,a        ;
   jr      nz,skipmonstchk       ;   is  (hl) a coin?
   ld      a,(hl)               ;
   cp      coinid               ;   if so dont allow the move!
   jr      z,skipstore          ;
skipmonstchk:                   ;}
   ;if(eraseable) {             ;
   ld      (ix+sprxyoffh),d     ;    sprxyoff=de
   ld      (ix+sprxyoffl),e     ;    ASSUME: hl=graphmem+de
   ld      a,(ix+spridtype)     ;    (hl)=spridtype
   ld      (hl),a               ;
   ld      hl,GRAPH_MEM         ;    erase previous spot{
   ld      de,(oldxy)           ;
   add     hl,de                ;
   ld      a,blankid            ;
   ld      (hl),a               ;    }
skipstore:                      ;}
   ret                          ;return


;;;needed for drawing pictures
#define putline(offset)    ld      a,(IX+offset)
#defcont   \ ld      (hl),a
#defcont   \ add     hl,bc
;;draw(hl=XY,ix->picture)
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

