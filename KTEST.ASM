

#include "ti-85.h"

.org 0
.db "ktest",0

premain:
   ld b,250
main:
   push bc
   ld a,00000000b
   out (1),a
   in a,(1)
   ld      hl,$0300
   ld      (CURSOR_ROW),hl
   ld      l,a
   ld      h,0
   ROM_CALL(D_HL_DECI)
   halt
   pop bc
   djnz main
quit:
   call GET_KEY
   cp K_EXIT
   jr nz,quit
   ret

.END
;;;