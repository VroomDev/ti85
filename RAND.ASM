;;;;;rand.asm
#ifndef RAND_ASM
#define RAND_ASM
;;Chris Busch (cbusch@d.umn.edu)
;;If you use this code in a program that you will distribute the .asm file,
;;please dont strip these comments.
;;A=rand()
;;Generates a 7 bit random number
;;If you want a good 2 bit random number (0-3) have the following 3 lines 
;;after the CALL_( rand) or included in the function if you wish.
;;Basically, the middle/upper bits are the most random.
;    srl   a       ;;
;    srl   a       ;;
;    and   $03     ;; get a good random 3 bit number
;Note: Destroys B.  Returns A as random number.
#ifndef XOR_RAND
rand:
    ld    a,(randvar)
    ld    b,a
    ld    a,0
    add   a,b
    sla   b
    sla   b
    add   a,b
    sla   b
    sla   b
    add   a,b
    inc   a
    ld    (randvar),a
    ;srl   a
    ret
;;end rand
#endif

;;Chris Busch (cbusch@d.umn.edu)
;;If you want a faster random function, but not one as good use this one.
;;rand returns 7 bit poor random number, but FAST!
;;A=rand(){
;;  randvar = (randvar ^ 220)+1;
;;  return randvar>>1; //use only 6 middle bits
;;}
;;Note, if you wish to use this rand #define XOR_RAND before the 
;;#include "rand.asm".
#ifdef  XOR_RAND
rand:
   ld    a,(randvar)     ;randvar must be textarea var
   xor   220d
   inc   a
   ld    (randvar),a
   srl   a
   ret
;;end rand
#endif

#endif
;;;;;end rand.asm
