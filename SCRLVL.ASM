
#include "ti-85.h"

#include "smacros.asm"

;;offsets
titlesub  =5
mainsub   =14

;;;;;;;;;;title
.org 0
.db  "         LVL",0  ;;<- file name will be placed in there!
;;;;;;;;;;;main
main:
   ld  hl,(PROGRAM_ADDR)       ; {
   ld  de,picdata              ;
   add hl,de                   ;
   ld  (picptr),hl             ; }load picptr
   ld  hl,(PROGRAM_ADDR)       ; }
   ld  de,lvldata              ;
   add hl,de                   ;
   ld  (levelptr),hl           ; }load levelptr

   ld   a,'Z'                    ; {
   ld   (levelnumand),a        ; }load lvland .db 1
   ld   a,'X'                    ; {
   ld   (passarg),a            ; }load passargs

savedhiscore:
   ld   hl,0                   ; { load saved hiscore (its 0 here)
   ld   (hiscore),hl           ; } hiscore=savehiscore


   ROM_CALL(CLEARLCD)          ;
   ld  hl,$0002                ;
   ld  de,comment              ;
   CALL_(putstr)               ;
wait:                          ;
   call GET_KEY                ;
   cp   0                      ;
   jr   z,wait                 ;
   CALL_(findengine)           ;
checkhiscore:                  ;
   ld      ix,(PROGRAM_ADDR)   ;
   ld      de,savedhiscore+1   ;
   add     ix,de               ;
   ld      l,(ix+0)  ;;load lo byte
   ld      h,(ix+1)  ;;load hi byte
   ld      de,(hiscore)           ;checkfor new hiscore{
   call    CP_HL_DE
   ret     nc  ;;no new hiscore
   ;;;;;;;;;;hope ix -> savedhiscore
   ;;;;;;;;;;hope hl = hiscore
   ld      (ix+0),e           ;set lo byte
   ld      (ix+1),d           ;set hi byte

   ld      a,(firstname)      ;;{is the first name not 0
   or      a                  ;;
   jr      z,nonewname        ;;}
   ld      hl,(PROGRAM_ADDR)  ;
   ld      de,yourname        ;
   add     hl,de              ;hl->yourname
   ld      de,firstname       ;de->firstname
   ex      de,hl
   ld      bc,3               ;
   ldir                       ;copy the 3 bytes
nonewname:                    ;
   ld      hl,ZS_BITS         ;;{
   set     0,(hl)             ;;}perform checksum again
   ret
;;;;;;;;end main

VARNLEN =$8083
VARNAME =$8084
FINDVAR =$2715

;;findlevel1()
findengine:
   ld   de,lvlname
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   ld   a,(hl)
   inc  a
   inc  a
   ld   b,a
   ld   de,VARNLEN
findlevel1:
   ld   a,(hl)
   ld   (de),a
   inc  de
   inc  hl
   djnz findlevel1  ;;name should be copied.
   rst  10h
   jr   c,notfound
   ;;;;;;;;;;;;;;;;;;;;de->string data
   ld   hl,(PROGRAM_ADDR)
   push hl
   ld   hl,titlesub
   add  hl,de         ;hl->SENGINE title
   ld   (PROGRAM_ADDR),hl
   ld   de,mainsub
   add  hl,de         ;hl->SENGINE program
   ld   a,(hl)        ;;;;;;;;!!!!!!!!!!!!
   cp   76h           ;;;;;;;halt instruction???
   jr   z,itshalt
   pop  hl
   ld   (PROGRAM_ADDR),hl
   jr   notfound
itshalt:
   ;;;;;;;;;;PROGRAM_ADDR==SENGINE_ADDR!!
   CALL_( mainsub)
   pop  hl
   ld   (PROGRAM_ADDR),hl
   ret
notfound:
   ld   hl,$0006
   ld   de,needstr
   CALL_(putstr)
   ld   hl,$0007
   ld   de,lvlname+1
   CALL_(putstr)
wait2:
   call GET_KEY
   cp   0
   jr   z,wait2
   ret
;;end findlevel

;;putstr(l=row,h=col,DE=string)
;;;;;;;;ld      HL,$0003
putstr:
   ld      (CURSOR_ROW),HL
   ld      HL,(PROGRAM_ADDR)
   add     HL,DE
   ROM_CALL(D_ZT_STR)
   ret

;;printnum(hl=number,b=col,c=row)
printnum:
   ld      (CURSOR_ROW),bc
   ROM_CALL(D_HL_DECI)
   ret
;;end printnum


needstr   .db   "NEEDS:",0
lvlname   .db 7,"SENGINE",0
;;;;;;123456789012345678901
comment:
.db  "  Official  levels!  "   ;;<-- comment line!
.db  "Scrolls LVL - C Busch"   ;;<-- comment line
.db  "  Top player is "
yourname: .db "you. "
.db  "SLVL4.0(C)1996 CBusch",0
;;;;savehiscore .dw 0   ;;saved hiscore
;;;;lvland .db 1
picdata:
;#include "pics.asm"
lvldata:
;#include "level1.asm"
.END

;;end of program


;;;;;;;;;old load levelnumand
  ; ;ld  hl,(PROGRAM_ADDR)       ; {
  ; ;ld  de,lvland               ;
  ; ;add hl,de                   ;
  ; ;ld  a,(hl)                  ;
  ; ;ld  (levelnumand),a         ; }load levelnumand

;;;;;;;;;;;;;;;;old load hiscore code
  ;; ld   hl,(PROGRAM_ADDR)      ; {
  ;; ld   de,savehiscore         ;
  ;; add  hl,de                  ;
  ;; ld   e,(hl)                 ;
  ;; inc  hl                     ;
  ;; ld   d,(hl)                 ;
  ;; ld   (hiscore),de           ; }load old hiscore
