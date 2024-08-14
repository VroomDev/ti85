;;;;;Chris Busch



;;inline int
;;nooverlap(int ax1,int ay1,int ax2,int ay2,int bx1,int by1,int bx2,int by2)
;;{	return (ax1 >= bx2 || bx1 >= ax2 || ay1 >= by2 || by1 >= ay2 ); }
;;;
;;;;;;;;;nooverlap(ix-> (ax1,ay1,ax2,ay2),iy->(bx1,by1,bx2,by2) )
;;;;;;;;;;;
;x1 = 0
;y1 = 1
;x2 = 2
;y2 = 4
;overlap1:   ;;returns  nc=nooverlap  c=overlap
;    ld   a,(ix+x1)
;    cp   (iy+x2)
;    ret  nc  ;nooverlap
;    ld   a,(iy+x1)
;    cp   (ix+x2)
;    ret  nc  ;nooverlap
;    ld   a,(ix+y1)
;    cp   (iy+y2)
;    ret  nc  ;nooverlap
;   ld   a,(iy+y1)
;    cp   (ix+y2)
;    ret  ;;;;;nc=nooverlap c=overlap
;;;;;;;;end overlap

;;;;;;;nooverlap2
;;inline int
;;nooverlap2(int ax1,int ay1,int ax2,int ay2,int bx1,int by1,int bx2,int by2)
;;{	return (ax1 >= bx2 || bx1 >= ax2 || ay1 >= by2 || by1 >= ay2 ); }
;;{   return (bx2 <= ax1 || ax2 <= bx1 || by2 <= ay1 || ay2 <= by1 ); }
;;;
;;;;;;;;;nooverlap(hl=( l=ax1, h=ay1),de=( e=bx1, d=by1), c=genpur)
;;;;;;;;need to have [ab]size[xy] loaded
overlap:  ;;no overlap = c or z;;overlap = nz and nc
   ld a,(bsizex) \  ld c,e \ add a,c \ cp l \ ret c \ ret z
   ld a,(asizex) \  ld c,l \ add a,c \ cp e \ ret c \ ret z
   ld a,(bsizey) \  ld c,d \ add a,c \ cp h \ ret c \ ret z
   ld a,(asizey) \  ld c,h \ add a,c \ cp d ;;;;; ret c \ ret z
   ret
;;;;;;;end overlap

;;;;;;;;;;;;;;;;;;;;;iscollision(ix -> current monster)
;;;;;out: hitval, hitptr
iscollision:
   xor a \   ld  (hitval),a  ;;hitval=0
   ld   h,(ix+spractorh)
   ld   l,(ix+spractorl)
;;   ld   a,(driftdx)
;;   or   a
;;   jr   nz,gottacollide
;;   ld   a,(driftdy)
;;   or   a
;;   jr   nz,gottacollide
   ld   a,collidecheckand
   and  (hl)   ;;hl->sprite type
   ret  z   ;;dont check for collisions unless the collidecheck bit is set
;;gottacollide:
   inc  hl ;;(hl)=xsize
   ld   a,(hl)
   ld   (asizex),a
   inc  hl \ inc hl
   ld   a,(hl) ;;a=ylines
   ld   (asizey),a
   ld  b,monsternum
   push iy
   di ;;disable interrupts
   ld  iy,monsters
iscollisionloop:
   push  bc
      push  ix \  pop  hl ;;hl=ix
      push  iy \  pop  de ;;de=iy
      call  CP_HL_DE
      jr    z,contiscollisionloop
      ld   h,(iy+spractorh)           ;{load bsizexy with proper values
      ld   l,(iy+spractorl)           ;
      inc  hl ;;(hl)=xsize            ;
      ld   a,(hl)                     ;
      ld   (bsizex),a                 ;
      inc  hl \ inc hl  ;;hl->ylines  ;
      ld   a,(hl) ;;a=ylines          ;
      ld   (bsizey),a                 ;}
      ld    a,(newx)  \   ld    l,a   ;{call overlap function
      ld    a,(newy)  \   ld    h,a   ;
      ld    e,(iy+sprx)               ;
      ld    d,(iy+spry)               ;
      CALL_(overlap)                  ;}
      jr    c,contiscollisionloop
      jr    z,contiscollisionloop
      ;;;;;;;collided
      ld    (hitptr),iy
      ld    h,(iy+spractorh)
      ld    l,(iy+spractorl)
      ld    a,(hl)
      ld    (hitval),a
   pop   bc ;;preserve stack
      jr    jumpout
contiscollisionloop:
      ld   bc,sprsize
      add  iy,bc
   pop  bc
   djnz  iscollisionloop
jumpout:
   pop iy
   ei  ;;enable interrupts
   ret
;;;;;;;;end iscollision








;;;;;;;;needs xbytes,xcoord,scanline
;;;;;;putimage( b=y,c=x, hl -> imagedata)
putimg:
;;    push hl
;;    push bc
;;    ld   h,0
;;    ld   l,b
;;    ld   b,0
;;    ;;DEBUG16(BC)
;;    ;;DEBUG16a(hl)
;;    pop  bc
;;    pop  hl

    ld  d,(hl) ;;d=xsize
    inc hl     ;;now hl->xbytes
    ld  a,(hl)
    ld  (xbytes),a
    ld  e,a    ;;e=xbytes
    inc hl     ;;now hl->ylines

    ;;check x bounds
    bit 7,c  ;;c > 127
    jr  z,Xonscreenhere   ;;;onscreen on x
    ;;check x+xsize
    ld  a,c
    add a,d
    bit 7,a
    ret nz  ;;both x's offscreen
Xonscreenhere:
    ;;check y bounds
    ld  a,11000000b
    and b
    jr  z,Yonscreenhere ;;;onscreen on y
    ;;;check y+ylines
    ld  a,b
    add a,(hl)  ;;(hl)=ylines
    and 11000000b
    ret nz  ;;everything is offscreen so return!
Yonscreenhere:

    ld  a,c  \    ld  (xcoord),a  ;;save xcoord
    push hl
     ld  e,b    ;;e=ycoord
     ld  d,0
     bit 7,e
     jr  z,skiploade255
     ld  d,255
skiploade255:
     sla e  \    rl  d
     sla e  \    rl  d
     sla e  \    rl  d
     sla e  \    rl  d  ;;video spot: de*=16
     ld  a,c  ;;c=xcoord
     sra a  \    sra a \     sra a  ;;a=xcoord / 8
     ld  h,0
     bit 7,a
     jr  z,skipload255
     ld  h,255   ;;sign extend xcoord / 8
skipload255:
     ld  l,a
     add hl,de  ;;hl->graphics port offset
     ld  a,(videoselect+hibyte)
     ld  d,a  ;de,VIDEO_MEM  ;;GRAPH_MEM
     ld  e,0
     add hl,de   ;;hl->graphics
     ;;DEBUG16b(HL)
     ex  de,hl   ;;de->graphics
    pop hl     ;;; hl->image , de->graphics area
    ld  b,(hl)   ;b=ylines   ;;hl -> image.ylines
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
      and 7
      or  a ;;cp to 0
      jr  z,noshiftneeded
      ld  b,a  ;;loop upto 7 times
shiftamt:
      push bc
        push hl
          ld  b,7
          or  a  ;; clear carry bit
shift_loop:
          rr (hl)  ;hl->scanline
          inc hl
          djnz shift_loop
        pop hl
      pop bc
      djnz shiftamt
noshiftneeded:
;;;;;output:
     ld   hl,scanline
     ;;;assume de->graphics
     ld  a,(xbytes)
     inc a
     ld  b,a      ;;,a  ;;loop xbytes width
     ;;DEBUG16b(af)
     ld  a,(xcoord)
     sra a \ sra a \ sra a
     ld  c,a
     push  de
output_loop:
       push hl
       ld hl,videoselect+hibyte
       ld  a,d
       and (hl)
       cp  (hl)
       pop hl
       jr  nz,jumpout_loop

       bit 4,c                       ;{check xcoord to see if over the
       jr  nz,skipwriteout           ;}right edge

       ld a,(de)
       or (hl)    ;;;XOR or OR here!
       ld  (de),a  ;;de->graphics
skipwriteout:
       inc c

       ;;ld  a,e
       ;; and 0Fh
       ;;cp  0Fh
       ;;jr  z,jumpout_loop  ;;near edge!

       inc hl
       inc de
       djnz output_loop
jumpout_loop:
     pop de
;;;increment
     ld  bc,16  ;screen width
     ex de,hl \     add hl,bc \  ex de,hl  ;;add graphics+=16
     pop hl ;;hl->image,de->graphics
     pop bc
     djnz load_scanline
     ret
;;;;;;;;;;;;;end putimage









;;;;;;;;;;;;;end of code
