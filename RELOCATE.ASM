
#include "ti-85.h"

.org 0

main:
           scf  ;;clear carry flag to load
           ccf  ;;complement it so its now clear
          CALL_(loadlink) ;;must be done first
;;          ...
          ld      hl,$101
          ld      (CURSOR_ROW),hl
rel0:    ld      hl,HelloMsg     ; perhaps this also happens to be $101
          ; (normally we'd need to add PROGRAM_ADDR here)
          ROM_CALL(D_ZM_STR)
rel1:    call    myfuncfoo  ;cbusch added this
rel2:    jp      quitmyprog
;;          ...

HelloMsg:
   .db "hi",0
myfuncfoo:
quitmyprog:
           scf   ;;set carry flag to unload
           CALL_(loadlink) ;;must be last!!!
           ret

 ;;this function will locate your program
loadlink:
      ld  ix,relocatetable
      ld  bc,(PROGRAM_ADDR)
      add ix,bc
      jr  c,relocatelp
      ld  a,b ;;  need to make bc negative to fix back
      neg
      ld  b,a
      ld  a,c
      neg
      ld  c,a
      inc bc
relocatelp:
      ld  l,(ix+0)
      ld  h,(ix+1)
      ld  de,$FFFF
      call CP_HL_DE
      ret z ;;exit function if address is $FFFF ie end of table
      add hl,bc   ;;bc is program_addr
      ld  (ix+0),l
      ld  (ix+1),h
      inc ix
      inc ix
      jr relocatelp
;;end of relocate


relocatetable:
   .dw  rel0+1   ;the plus one for the opcode size
   .dw  rel1+1   ;could be more than one...
   .dw  rel2+1
   .dw  $FFFF    ;;end of table marker

.END

