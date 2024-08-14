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
viewx        =playbits + 1
viewy        =viewx + 1
videoselect    =viewy + 1
tankdir        =videoselect + 2
frame          =tankdir + 1
lastvar        =frame + 2
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
.db     "Tank v0.0 by CGB (c)1996",0
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
    CALL_( initmonsters)
gameloop:
    ld   hl,(frame)  \ inc hl \ ld (frame),hl
    CALL_(moveplayer)
    CALL_(setdrift)
 ;;;;;erase draw screen
    ld   hl,(videoselect)
    ld   (hl),0
    ld   de,(videoselect) ;;;VIDEO_MEM+1
    inc  de
    ld   bc,1023 
    ldir
 ;;;;;;;;;draw background
    CALL_(drawbackground)
 ;;;;;;;;;done erase graph screen
    CALL_(movemonsters)
 ;;;;;copy graph screen
    ld   hl,(videoselect)
    ld   de,VIDEO_MEM
    ld   bc,1024  ;;DEBUG!  should be 1024
    ldir
 ;;;;;;;;;end copy graph screen
    ;;halt
    jr gameloop
;;;;;;;;;;;end main

#include "tsprite.asm"

;;;;;;;;;;;initmonsters() loads the monster array
initmonsters:
     ld  bc,level1size  
     ld  hl,(PROGRAM_ADDR)  
     ld  de,level1map
     add hl,de   ;;hl=source
     ld  de,monsters  ;;dest
     ldir
     ld  ix,monsters
     ld  b,level1count
initmonstloop:
     ld  hl,(PROGRAM_ADDR)
     ld  d,(ix+spractorh)
     ld  e,(ix+spractorl)
     add hl,de            ;;fix references for type
     ld  (ix+spractorh),h
     ld  (ix+spractorl),l
     ld   de,sprsize
     add  ix,de
     djnz initmonstloop
     ret
;;;;;;;;end initmonsters




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
    ld   ix,monsters + (sprsize * monsternum) - sprsize
moveloop:
    push bc
    ld   a,(ix+sprx)   ;;find newx and newy
    ld   c,(ix+sprdx)
    add  a,c
    ld   (newx),a
    ld   a,(ix+spry)
    ld   c,(ix+sprdy)
    add  a,c
    ld   (newy),a
;;;;;do collision here
    push  ix
    CALL_(iscollision)
    pop   ix
    ld    a,(hitval)
    or    a
    jr    z,didhitnothing
    ;;;;;;;;;;;;;;;;;;insert hit code here
    CALL_( hitsomething)
    jr    dodrawing
didhitnothing:
    CALL_( hitnothing)
;;;;;;;;;;;;;do drawing
dodrawing:
    CALL_( movespr)
;;;;;;;;increment for next sprite
    ld      bc,-sprsize
    add     ix,bc
    pop     bc
    djnz    moveloop
    ret
;;;;;;;;;;;;;end movemonsters

;;;;;hitnothing(ix->cursprite) ;;preserves ix
hitnothing:
    ld      h,(ix+spractorh)
    ld      l,(ix+spractorl)
    ld      a,mantype
    cp      (hl)
    jr      nz,notmantype
    ld      a,(ix+sprdx)
    or      a
    ret     nz
    ld      a,r
    and     3
    dec     a
    ld      (ix+sprdx),a
    ld      a,(ix+sprdy)
    or      a
    ret     nz
    ld      a,r
    and     3
    dec     a
    ld      (ix+sprdy),a
    ret
notmantype:
    ld      a,bigmantype
    cp      (hl)
    jr      nz,notbigmantype
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
    ret
;;;;;;;;;end seeker move
notbigmantype:
    ld      a,pushableand
    and     (hl)
    ret     z
    ld      a,(ix+sprdx)
    or      a
    jr      z,dxis0
    bit     7,a
    jr      nz,dxitspos
    dec     a \  dec     a
dxitspos:
    inc     a
    ld      (ix+sprdx),a
dxis0: ;;;;;;dy's turn
    ld      a,(ix+sprdy)
    or      a
    jr      z,dyis0
    bit     7,a
    jr      nz,dyitspos
    dec     a \  dec     a
dyitspos:
    inc     a
    ld      (ix+sprdy),a
dyis0:
    ret
;;;;;;;end hitnothing


;;;;;hitsomething(ix->cursprite) ;; preserves ix
hitsomething:
    ;;if you hit something use old position
    ld    a,(ix+sprx)
    ld    (newx),a
    ld    a,(ix+spry)
    ld    (newy),a
    ;;;;;;;calculate new movement
    ld      h,(ix+spractorh)
    ld      l,(ix+spractorl)
    ld      a,playertype
    cp      (hl)
    jr      nz,itsnotplayer
    CALL_(  playerhit)
    ret
itsnotplayer:
    ld      a,pushableand  ;;hl->type
    and     (hl)
    jr      z,wasnotpushable
    ld      a,(ix+sprdx) \    neg \     ld      (ix+sprdx),a  ;;dx=-dx
    ld      a,(ix+sprdy) \    neg \     ld      (ix+sprdy),a  ;;dy=-dy
wasnotpushable:
    ld      a,mantype     ;;patrol move
    cp      (hl)
    jr      nz,skipmantype
;;;;;;;patrol move:
patrolmove:
    ld      a,r
    and     3
    dec     a
    ld      (ix+sprdx),a
    ld      a,(ix+sprdy)
    ld      a,r
    and     3
    dec     a
    ld      (ix+sprdy),a
    ret
;;;;;;;;end patrol move
skipmantype:
    ld       a,bigmantype
    cp       (hl)
    jr       z,patrolmove
    ret
;;;;;;;;;;;;;end hitsomething

;;;;playerhit
playerhit:
    xor   a
    ld    a,(hitval)
    and   pushableand
    ret   z
    push  ix
    ld    ix,(hitptr)
    ld    a,(monsters+sprdx)
    ld    b,a
    add   a,b
    add   a,b
    ld    (ix+sprdx),a
    ld    a,(monsters+sprdy)
    ld    b,a
    add   a,b
    add   a,b
    ld    (ix+sprdy),a
    pop   ix
    ret
;;;;;end playerhit

;;;;;;;;;;;;;movespr(ix->cursprite)  ;;preserves ix
movespr:
drawnewspr:  ;;;ix->sprite
    ld  hl,viewx
    ld  a,(newx) \  ld (ix+sprx),a \  add a,(hl) \  ld  c,a
    ld  hl,viewy
    ld  a,(newy) \  ld (ix+spry),a \  add a,(hl) \  ld  b,a
    ld  h,(ix+spractorh)
    ld  l,(ix+spractorl)
    inc hl
    CALL_(putimg)
    ret
;;;;;;;end movespr

;;;;;;;;;;;;;drawbackground(ix->cursprite)  ;;preserves ix
drawbackground:
    ld  hl,(frame)
    bit 1,l
    ret z
    ld  a,(viewx) \  add a,50 \  ld  c,a
    ld  a,(viewy) \  add a,50 \  ld  b,a
    ld  hl,(PROGRAM_ADDR)
    ld  de,actorhouse
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
setdrift00:
    ld  a,(monsters+sprx)
    add a,-64
    neg
    ld  (viewx),a
    ld  a,(monsters+spry)
    add a,-32
    neg
    ld  (viewy),a
    ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
setdrift:
    ld  a,(monsters+sprdx)
    or  a
    jr  nz,sprdxnot00
    ld  a,(monsters+sprdy)
    or  a
    ret z      ;;;return if both player dx and dy are 0
sprdxnot00:
    ld  a,(monsters+sprx)
    ld  hl,viewx
    add a,(hl)
    srl a \ srl a \ srl a \ srl a
    cp  0
    jr  nz,notleftside  ;;left side next
    ld  hl,viewy  \ ld a,(monsters+sprdy) \ neg \ add a,(hl) \ ld (hl),a
    ld  hl,viewx \ ld a,playerstep \ add a,(hl) \ ld (hl),a
    jr  notrightside
notleftside:
    cp  6
    jr  nz,notrightside ;;right side next
    ld hl,viewy \ ld a,(monsters+sprdy) \    neg \ add a,(hl) \  ld (hl),a
    ld hl,viewx \ ld a,-playerstep \ add a,(hl) \ ld (hl),a
notrightside:  ;;check top and bottom
    ld  a,(monsters+spry)
    ld  hl,viewy
    add a,(hl)
    srl a \ srl a  \ srl a \ srl a 
    cp  0
    jr  nz,nottopside ;;topside next
    ld hl,viewy \ ld a,playerstep  \ add a,(hl) \ ld (hl),a
    ld hl,viewx \ ld a,(monsters+sprdx) \    neg \ add a,(hl) \  ld (hl),a
    ret
nottopside:
    cp  2
    ret nz     ;;bottom side next
    ld hl,viewy \ ld a,-playerstep    \ add a,(hl) \ ld (hl),a
    ld hl,viewx \ ld a,(monsters+sprdx) \    neg  \ add a,(hl) \ ld (hl),a
    ret
;;;;;;;;end drift function

setdrift0:
    ld  a,(monsters+sprdx)
    or  a
    jr  nz,sprdxnot0
    ld  a,(monsters+sprdy)
    or  a
    ret z      ;;;return if both player dx and dy are 0
sprdxnot0:
    ;;;;;;;;set  drift  X
    ld  hl,viewx
    ld  a,(monsters+sprx)
    sub (hl)
    cp  128-border-playerwidth
    jr  c,sprxLTedge
    ld  hl,viewy  \ ld a,(monsters+sprdy) \ neg \ add a,(hl) \ ld (hl),a
    ld  hl,viewx \ ld a,-playerstep \ add a,(hl) \ ld (hl),a
sprxLTedge:
    ld  hl,viewx
    ld  a,(monsters+sprx)
    sub (hl)
    cp  border
    jr  nc,sprxGTedge
    ld hl,viewy \ ld a,(monsters+sprdy) \    neg \ add a,(hl) \  ld (hl),a
    ld hl,viewx \ ld a,playerstep \ add a,(hl) \ ld (hl),a
sprxGTedge:
    ;;;;;;;set drift Y
    ld  hl,viewy
    ld  a,(monsters+spry)
    sub (hl)
    cp  64-border-playerhite
    jr  c,spryLTedge
    ld hl,viewy \ ld a,-playerstep  \ add a,(hl) \ ld (hl),a
    ld hl,viewx \ ld a,(monsters+sprdx) \    neg \ add a,(hl) \  ld (hl),a
spryLTedge:
    ld  hl,viewy
    ld  a,(monsters+spry)
    sub (hl)
    cp  border
    jr  nc,spryGTedge
    ;;ld  (hl),playerstep
    ld hl,viewy \ ld a,playerstep    \ add a,(hl) \ ld (hl),a
    ld hl,viewx \ ld a,(monsters+sprdx) \    neg  \ add a,(hl) \ ld (hl),a
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
#include "tmap.asm"

   .db "Tank by Chris Busch"
   .db "(c) 1996 Do not distribute.",0

.END
;;;;;;;;;;;;;end of file
