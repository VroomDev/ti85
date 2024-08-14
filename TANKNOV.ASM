;;Chris Busch
;;(c)1996

;;;;
;;;headers
#include "ti-85.h"
#define  jp   DONT_USE
;;;;;;;;;;;;Chris Busch
;;;;;;----------------------------------
;;macro section
;;;;;;----------------------------------

#define DEBUG16(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0000 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF
#define DEBUG16a(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0001 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF
#define DEBUG16b(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0002 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF

hibyte       = 1
lobyte       = 0

;;;;;;--------------------------------
;;text memory
;;;;;;--------------------------------
;;sprite definition
;;struct sprite {
;;       pointer actortype
;;       byte x,y
;;       byte dx,dy
;;       byte health
;;};;size 7
spractor       = 0
spractorh      = 1
spractorl      = 0
sprx          = 2
spry          = 3
sprdx         = 4
sprdy         = 5
sprhealth     = 6
sprsize       = 7
;;struct actor {
;;       byte typeid
;;       data picturedata
;;}
actorid       = 0
actorsizex    = 1
actorxbytes   = 2
actorsizey    = 3
actorpic      = 1
;;
;;     .db     PLAYER_MOVE   ;;typeid
;;     .db     24 ;;xsize
;;     .db     3,5  ;;xbytes,ylines
;;;


monsternum    = 10
;;;;;;;;;;;;;;;;;;;;;;;;;;text memory variables
TempLine       =$80df  ;;TEXT_MEM
PicCoor        =$80e7
offset         =$80e9
NASR_Status    =$80ea
newx           =NASR_Status+1
newy           =newx + 1
hitptr         =newy + 1
hitval         =hitptr + 2
asizex         =hitval + 1
asizey         =asizex + 1
bsizex         =asizey + 1
bsizey         =bsizex + 1
monsters       =bsizey + 1
endofmonsters        =monsters + (sprsize * monsternum)
playbits       =endofmonsters + 0
driftdx        =playbits + 1
driftdy        =driftdx + 1
videoselect    =driftdy + 1
tankdir        =videoselect + 2
lastvar        =tankdir + 1
;;;;;;;;;;;;
endoftext       =$8186
#if ( lastvar >= endoftext)
      ; generate an invalid statement to cause an error
      ;  when we go over the text boundary.
	  !!! text area bounds exceeded.
#endif

;;;;;;playbits bits
repaintbit = 0    ;;set repaint

;;;;;;;tank direction bits
northbit  = 1
eastbit   = 2
southbit  = 3
westbit   = 4
;;;;;;;;
playerstep = 2


;;;;;;;;;;;;;;;;;text mem 2 variables:
xbytes          =TEXT_MEM2
xcoord          =xbytes+1
scanline        =xcoord+1
lastvar2       =scanline+12
;;;;scanline      = VIDEO_MEM ;;;;;;;;+ (16*100)
;;;;;;;;;;;;;;
endoftext2       =TEXT_MEM2 + 160
#if ( lastvar2 >= endoftext2)
      ; generate an invalid statement to cause an error
      ;  when we go over the text boundary.
	  !$! text2 area bounds exceeded.
#endif


;-------------------------
; Title
;-------------------------
.org    0
.db     "Tank by CGB (c)1996",0
;;;;;;;;;;;main()
 ;;;;;;;;;;;load video select
    ld   hl,(HEAP_END)
    ld   de,-1026 ;;-1024 plus some
    add  hl,de
    ld   l,0
    ld   a,h
    and  11111100b
    ld   h,a
    ld  (videoselect),hl
    ld   de,(HEAP_BEGIN)
    inc  de
    inc  de
    call CP_HL_DE
    jr   nc,videoselectisok
    ;;putstr(l=row,h=col,DE=string)
    ld   de,lowrammsg
    ld   hl,$0000
    CALL_( putstr)
waitforanykey:
    call GET_KEY
    or   a
    jr   z,waitforanykey
    ld   hl,VIDEO_MEM
    ld   (videoselect),hl
videoselectisok:
 ;;;;;;;;;;;done loading video select
;;;;;;;init monsters
    ld      b,monsternum
    ld      hl,(PROGRAM_ADDR)
    ld      de,actorhouse
    add     hl,de
    ex      de,hl     ;;de->actorhello
    ld      hl,monsters
insertloop:
    ld      (hl),e  \   inc     hl ;;actor pointer
    ld      (hl),d  \   inc     hl
    ld      a,r     \   ld      (hl),a \ inc  hl   ;;x
    ld      a,r     \   ld      (hl),a \ inc  hl  ;;y
    ld      (hl),0  \   inc hl ;;dx     was 1
    ld      (hl),0  \   inc hl ;;dy     was b
    ld      (hl),5  \   inc hl ;;health
    djnz insertloop
    ld      hl,(PROGRAM_ADDR)
    ld      de,actortankne
    add     hl,de
    ld      (monsters+spractor),hl
    xor     a      ;;;init player
    ld      (monsters+sprdx),a
    ld      (monsters+sprdy),a
    ld      a,40
    ld      (monsters+sprx),a
    ld      a,10
    ld      (monsters+spry),a
;;;;;;;;;;;;;move monsters
    ;;ld      hl,playbits
    ;; set     repaintbit,(hl)
gameloop:
    CALL_(setdrift)
 ;;;;;erase draw screen
    ld   hl,(videoselect)
    ld   (hl),0
    ld   de,(videoselect) ;;;VIDEO_MEM+1
    inc  de
    ld   bc,1023  ;;DEBUG!  should be 1023??
    ldir
 ;;;;;;;;;done erase graph screen
    CALL_(movemonsters)
;    ld      hl,playbits
;    res     repaintbit,(hl)
;    halt
 ;;;;;copy graph screen
    ld   hl,(videoselect)
    ld   de,VIDEO_MEM
    ld   bc,1024  ;;DEBUG!  should be 1024
    ldir
 ;;;;;;;;;end copy graph screen
    halt
    CALL_(moveplayer)
    jr gameloop
;;;;;;;;;;;end main

#include "tsprite.asm"

;;;;;;;;moveplayer
moveplayer:
    xor  a
    ld   (tankdir),a
    ld   hl,monsters+sprdx
    ld   (hl),a
    ld   hl,monsters+sprdy
    ld   (hl),a
    out  (1),a ;;expects a=0
    in   a,(1)
    ld   b,a
    bit  P_EXIT,b
    jr   nz,noexithere
    pop  hl
    ret  ;;;;;;;;;;exit program!!
noexithere:
    bit  P_UP,b
    jr   nz,noupkey
    ld   hl,monsters+sprdy
    ld  (hl),-playerstep
    ld   hl,tankdir
    set  northbit,(hl)
noupkey:
    bit  P_DOWN,b
    jr   nz,nodownkey
    ld   hl,monsters+sprdy
    ld  (hl),playerstep
    ld   hl,tankdir
    set  southbit,(hl)
nodownkey:
    bit  P_RIGHT,b
    jr   nz,norightkey
    ld   hl,monsters+sprdx
    ld  (hl),playerstep
    ld   hl,tankdir
    set  eastbit,(hl)
norightkey:
    bit  P_LEFT,b
    jr   nz,noleftkey
    ld   hl,monsters+sprdx
    ld  (hl),-playerstep
    ld   hl,tankdir
    set  westbit,(hl)
noleftkey:
;;;;;;;;;;figure out tank direction
    ld hl,(PROGRAM_ADDR)
    ld de,postankdirs
    add hl,de
    ld  d,0
    ld  a,(tankdir)
    ld  e,a
    add hl,de  ;;now hl->postankdirs[tankdir]
    ld  e,(hl)
    inc hl
    ld  d,(hl) ;;;de=tankpicture
    ld  hl,0
    call CP_HL_DE
    ret z ;;return if de==0
    ld  hl,(PROGRAM_ADDR)
    add hl,de  ;;now hl->tankpicture
    ld  (monsters+spractor),hl
;;;;;done with player move
    ret
;;;;;;;;;end moveplayer
N =actortankn
S =actortanks
E =actortanke
W =actortankw
NE =actortankne
SE =actortankse
NW =actortanknw
SW =actortanksw

postankdirs: .dw 0,N,E,NE,S,0,SE,E,W,NW,0,N,SW,W,S,0

;;;;;;;;;;;;;;movemonsters
movemonsters:
;;;;;;;;;;;start sprite move
    ld   b,monsternum
    ld   ix,monsters
moveloop:
    push bc
    ld   a,(ix+sprx)   ;;find newx and newy
    ld   c,(ix+sprdx)
    add  a,c
    ld   hl,driftdx
    add  a,(hl)
    ld   (newx),a
    ld   a,(ix+spry)
    ld   c,(ix+sprdy)
    add  a,c
    ld   hl,driftdy
    add  a,(hl)
    ld   (newy),a
;;;;;do collision here
    push  ix
    CALL_(iscollision)
    pop   ix
    ld    a,(hitval)
    or    a
    jr    z,dodrawing
    ;;;;;;;;;;;;;;;;;;insert hit code here
    ld    a,(ix+sprx)
    ld    (newx),a
    ld    a,(ix+spry)
    ld    (newy),a
    ;;;;;;;calculate new movement
;    ld      h,(ix+spractorh)
;    ld      l,(ix+spractorl)
;    ld      a,0  ;;;;;;RAND_MOVE
;    cp      (hl)
;    jr      nz,skipnewmove
;;;;;;;patrol move:
;    ld (ix+sprdx),1
;    ld      a,r
;    bit     3,a
;    jr      z,incthisx
;    ld (ix+sprdx), -1 ;;dec
;incthisx:
;    ld  (ix+sprdy),1
;    ld      a,r
;    bit     3,a
;    jr      z,incthisy
;    ld  (ix+sprdy), -1
;incthisy:
;;;;;;;;end patrol move
skipnewmove:
;;;;;;;;;;;;seeker move
    ld    (ix+sprdx),-1
    ld    a,(monsters+sprx)  ;;get player x
    cp    (ix+sprx)
    jr    c,carrysetonX
    ld    (ix+sprdx),1
carrysetonX:
    ld    (ix+sprdy),-1
    ld    a,(monsters+spry)  ;;get player y
    cp    (ix+spry)
    jr    c,carrysetonY
    ld    (ix+sprdy),1
carrysetonY:
;;;;;;;;;end seeker move
;;;;;;;;;;;;;do drawing
dodrawing:
    CALL_( movespr)
;;;;;;;;increment for next sprite
    ld      bc,sprsize
    add     ix,bc
    pop     bc
    djnz    moveloop
    ret
;;;;;;;;;;;;;end movemonsters


;;;;;;;;;;;;;movespr(ix->cursprite)  ;;preserves ix
movespr:
;;;;;;must repaint if repaint bit is set
;    ld  a,(playbits)
;    bit repaintbit,a
;    jr  nz,drawnewspr
;;;;;;;;;;only draw if different coords
;    ld  a,(newx)
;    cp  (ix+sprx)
;    jr  nz,coorddiff
;    ld  a,(newy)
;    cp  (ix+spry)
;    jr  nz,coorddiff
;    ret
;coorddiff:  ;;;;;;;;newx != x || newy != y
;;;;;;erase old sprite
;    ld  c,(ix+sprx)
;    ld  b,(ix+spry)
;    ld  h,(ix+spractorh)
;    ld  l,(ix+spractorl)
;    inc hl
;    CALL_(putimg)
;;;;;draw new sprite
drawnewspr:  ;;;ix->sprite
    ld  a,(newx) \  ld (ix+sprx),a \    ld  c,a
    ld  a,(newy) \  ld (ix+spry),a \    ld  b,a
    ld  h,(ix+spractorh)
    ld  l,(ix+spractorl)
    inc hl
    CALL_(putimg)
    ret
;;;;;;;end movespr




;;printnum(hl=number,b=col,c=row)
printnum:
   ld      (CURSOR_ROW),bc
   ROM_CALL(D_HL_DECI)
   ret


border =10
;;;;;;;;set drift for scrolling
setdrift:
;;;;;;;zero out drifts
    xor a
    ld  (driftdx),a
    ld  (driftdy),a
    ;;;;;;;;set  drift  X
    ld  hl,driftdx
    ld  a,(monsters+sprx)
    cp  128-border-playerwidth
    jr  c,sprxLTedge
    ld  (hl),- playerstep
sprxLTedge:
    cp  border
    jr  nc,sprxGTedge
    ld  (hl), playerstep
sprxGTedge:
    ;;;;;;;set drift Y
    ld  a,(monsters+spry)
    ld  hl,driftdy
    cp  64-border-playerhite
    jr  c,spryLTedge
    ld  (hl),- playerstep
spryLTedge:
    cp  border
    jr  nc,spryGTedge
    ld  (hl),playerstep
spryGTedge:
    ret
;;;;;;;;;;end setdrift


;;putstr(l=row,h=col,DE=string)
;;;;;;;;ld      HL,$0003
putstr:
   ld      (CURSOR_ROW),HL
   ld      HL,(PROGRAM_ADDR)
   add     HL,DE
   ROM_CALL(D_ZT_STR)
   ret


;;;;;;;;;;;;data:

lowrammsg:
   ;;; "123456789012345678901"
   .db "LOW ON FREE MEMORY!!!"
   .db "This game needs 2000 "
   .db "bytes free to operate"
   .db "without flicker.",0

;;struct imagedata {
;;  byte typeid
;;  byte xsize,xbytes,ylines
;;  byte data[]
#include "tpics.asm"


.END
;;;;;;;;;;;;;end of file