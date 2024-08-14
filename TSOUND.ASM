;;Chris Busch
;;ti85 tone generator
;;You may use this code for whatever purpose, its public domain.

;;WARNING!  Not responsible for any damage this may cause!!!!!!!

;;How to run:
;;Press custom, ZShell, then sound.
;;Plug in small walkman headphones and you should hear a tone.  Press
;;keys on the ti85 calc keypad to generate different tones.
;;Press EXIT when done.  Promptly remove headphones.
;;Now you may exit ZShell.

;;I have tested it by plugging it into my stereo and that works too.

#include "ti-85.h"

.org 0
.db "sound",0

premain:
   ld  d,10
main:
   ld  b,$FC  ;0 0
   ld  a,r
   and 1
   cp  1
   jr  z,nkeepr
   ld  b,$EB
nkeepr:
   ld  c,7
   out (c),b         ;output 0 0
   ld b,d            ;loop d times
loop0:
   push bc
   ld b,25           ; inner delay loop of 50 nop's
inner0:
   nop
   djnz inner0
   pop  bc
   djnz loop0
   call GET_KEY
   ld  b,$C0
   ld  c,7
   out (c),b         ;output 1 1 ;;make sure this is the last to be outputted!
   cp K_EXIT
   jr z,quit         ;quit sound generator
   cp 0
   jr z,skipd
   sla a             ;let d be the new "tone"
   sla a
   ld d,a
skipd:
   ld b,d            ;loop d times
loop:
   push bc
   ld b,25           ; inner delay loop of 50 nop's
inner:
   nop
   djnz inner
   pop  bc
   djnz loop
   jr main
quit:
   ret

.END
;;;;
