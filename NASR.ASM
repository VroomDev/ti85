#include "ti-85.h"

TempLine       =$80df  ;;TEXT_MEM
PicCoor        =$80e7
offset         =$80e9
NASR_Status    =$80ea


NASRWARP:
        ld a,4     ;;;
        out (5),a  ;;;
        push    bc
        ex      de,hl
        ROM_CALL(FIND_PIXEL)
        ld      bc,$fc00
        add     hl,bc
        ld      (PicCoor),hl
        ex      de,hl
        ld      b,$ff
Patch:
        rla
        inc     b
        jr      nc,Patch
        ld      a,(hl)
        ld      c,a
        inc     hl
        ld      a,(hl)
        ld      (offset),a
        ld      a,b
        ld      e,c
        cp      (hl)
        jr      c,DS1
        inc     e
DS1:
        inc     hl
        ld      a,(hl)
        ld      d,a
        inc     hl
YLoop:
        push    bc
        push    de
        ld      b,8
        ex      de,hl
        ld      hl,TempLine
InitTempLineLoop:
        ld      (hl),$ff
        inc     hl
        djnz    InitTempLineLoop
        ex      de,hl
	ld	a,(NASR_Status)
	cp	0
	jr	z,NASRErase
NASRDraw:
        ld      b,0
        ld      de,TempLine
        ldir
	jr	NASRDrawFin
NASRErase:
	ld	b,c
	ld	hl,TempLine
LoadEmpty:
	ld	(hl),0
	inc	hl
	djnz	LoadEmpty
NASRDrawFin:
        pop     de
        pop     bc
        push    hl
        push    bc
        push    de
        ld      d,b
        ld      a,b
        cp      0
        jr      z,skipshift
SpriLoop1:
        ld      a,b
        ld      HL,TempLine
        ld      b,e
        scf
SpriLoop2:
        rr      (HL)
        inc     HL
        djnz    SpriLoop2
        ld      b,a
        djnz    SpriLoop1
        ld      b,d
skipshift:
        ld      a,$ff           ;fill accumulator
        inc     b
mask1:
        srl     a               ;make the mask
        djnz    mask1           ;something like
        scf                     ;00001111 ->
        rl      a
        ld      hl,(PicCoor)    ;implement the mask
        or      (hl)            ;this preserve the 0 bits
        ld      hl,TempLine   ;become xxxx1111
        and     (hl)            ;when anded, become
        ld      (hl),a          ;xxxxyyyy
        ld      b,d             ;retrieve b
        ld      a,(offset)
        dec     a
        sub     b
        jr      nc,skip
        sub     248
skip:
        ld      b,a
        inc     b
        ld      a,$ff
mask2:
        sla     a
        djnz    mask2
        scf
        rr      a
        dec     e
        ld      hl,(PicCoor)
        ld      d,0
        add     hl,de
        or      (hl)
        ld      hl,TempLine
        add     hl,de
        and     (hl)
        ld      (hl),a
        inc     e
        ld      c,e
        ld      hl,(PicCoor)
        ld      de,16
        push    hl
        add     hl,de
        ld      (PicCoor),hl
        pop     hl
        ld      de,TempLine
        ex      de,hl
        ld      b,0
        ldir
        pop     de
        pop     bc
        pop     hl
        dec     d
        JUMP_NZ( YLoop)
        pop     bc
        ret

.END
;;;;;;;;;;;;