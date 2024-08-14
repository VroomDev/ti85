
;;#include "ti-85.h"


scanline  = 0; TEXT_MEM ;8
xbytes = 0
xcoord = 0


;;struct imagedata {
;;  byte xsize
;;  byte ysize
;;  byte data[]


;;;;;;putimage( b=y,c=x, hl -> imagedata)
putimage:
    ld  a,c  \    ld  (xcoord),a  ;;save xcoord
    push hl
     ld  e,b    ;;e=ycoord
     ld  d,0
     sla e  \    rl  d
     sla e  \    rl  d
     sla e  \    rl  d
     sla e  \    rl  d  ;;video spot: de*=16
     ld  a,c  ;;c=xcoord
     srl a  \    srl a \     srl a  ;;a=xcoord / 8
     ld  h,0
     ld  l,a
     add hl,de  ;;hl->graphics port offset
     ld  de,VIDEO_MEM
     add hl,de   ;;hl->graphics
     ex  de,hl   ;;de->graphics
    pop hl     ;;; hl->image , de->graphics area
    ld  a,(hl)
    ld  (xbytes),a
    inc hl
    ld  b,(hl)   ;b=ylines
    inc hl    ;;now hl->image
load_scanline:
    push bc
     push de  ;de->graphics
      ;;;assume hl->image
      ld   de,scanline
      ld   b,0 \    ld   a,(xbytes) \   ld   c,a ;;bc = byte count
      ldir  ;;; copy row into scanline
      ex   de,hl  \   ld   (hl),0 \  ex   de,hl ;;last byte in scanline is zero
     pop  de  ;de->graphics
;;;;shifting:
     push hl  ;;hl->image
      ld  hl,scanline
      ld  a,(xcoord)
      and 111b
      jr  z,noshiftneeded
      ld  b,a  ;;loop upto 7 times
      or  a  ;; clear carry bit
shift_loop:
      rr (hl)  ;hl->scanline
      inc hl
      djnz shift_loop
noshiftneeded:
;;;;;output:
     ld   hl,scanline
     ;;;assume de->video spot
     ld  a,(xbytes)
     inc a
     ld  b,a  ;;loop xbytes width
output_loop:
     ld a,(de)
     xor (hl)
     ld  (hl),a
     inc hl
     inc de
     djnz output_loop
;;;increment
     ld  bc,16  ;screen width
     ex de,hl \     add hl,bc \  ex de,hl  ;;add graphics+=16
     pop hl ;;hl->image,de->graphics
     pop bc
     djnz load_scanline
     ret
;;;;;;;;;;;;;end putimage







.END

;;;;;;;;;;;