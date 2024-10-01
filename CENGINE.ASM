;;Chris Busch

;;(c)1995

;;;;
;;;headers
#include "ti-85.h"
#define  jp   DONT_USE

#include "cmacros.asm"

;-------------------------
; Title
;-------------------------
.org    0
.db     "CENGINE v5.0 ",0
;;       ^^^^^^^^^^^^^<-dont change that length!!
;-------------------------
; Program start
;-------------------------

main:
   halt    ;;;;;;;<- must be first opcode of program!
   ld      hl,(PROGRAM_ADDR)  ;checksum begin
   ld      b,9
   xor     a
chksum:
   add     a,(hl)
   inc     hl
   djnz    chksum
   cp      143   ;"CENGINE v"
   jr      z,skipshow
;dimagain:
;   CALL_(  dimout)
;   jr      dimagain
;   .db $3A         ;;dummy
skipshow:
   ld      b,6
   ld      hl,(PROGRAM_ADDR)
   ld      de,myname
   add     hl,de
   xor     a
;chksum2:
;   add     a,(hl)
;   inc     hl
;   djnz    chksum2
;   cp      120  ;"cbusch"
;   jr      nz,dimagain          ;;checksum end!

   ld      a,0
   ld      (level),a
   CALL_(  checkhiscore);
   CALL_(  intro);
   ld      hl,(picptr)      ;;make sure picptr!=0 && levelptr!=0
   ld      de,0
   call    CP_HL_DE
   jr      nz,datanot0
   ld      hl,(levelptr)
   call    CP_HL_DE
   jr      nz,datanot0
   ld      hl,$0000
   ld      de,cantfind     ;;print cant data find message
   CALL_(  putstr)
   CALL_(  wait4enter);
   ret  ;;quit program!
datanot0:
   CALL_( showpurpose) ;;aug 1996
;;   CALL_(  findlevel);
donewlevel:
startlevel:
   ;;CALL_(  dissolve) ;;;;;ROM_CALL(CLEARLCD)
   ld      hl,VIDEO_MEM
   ld      (hl),0
   ld      de,VIDEO_MEM+1
   ld      bc,scrwidth
   ldir
   ld      b,128                                ;{ scroll up really fast
scrollclrloop:                                  ; clearing screen
   push    bc                                   ;
   halt                                         ;
   ld      de,VIDEO_MEM + 1024                  ;
   ld      hl,VIDEO_MEM + 1024 - scrwidth       ;
   ld      bc,1024 - scrwidth                   ;
   lddr                                         ;
   pop     bc                                   ;
   djnz    scrollclrloop                        ;}
   CALL_(  initlevel)
   CALL_(  stripe)             ;;show stripe
   ld      a,(health)
   inc     a
   ld      (health),a
   CALL_(  dechealth)
   CALL_(  incscore)
   ld      a,0                 ;;{clear play mode flags!
   ld      (playmode),a        ;;}
   ld      a,(level)           ;;{
   inc     a                   ;;   level++
   ld      (level),a           ;;}
   ld      ix,bullet           ;;initbullet{
   ld      d,bulletid          ;;
   ld      bc,0                ;;
   ld      hl,0
   CALL_(initspr)              ;;}
   ;;initspr(IX=sprite*,d=idtype,e=empty,bc=extra bytes,hl=videostart)
   ld      ix,player
   ld      d,playerid
   ld      e,0
   ld      bc,0
   ld      hl,0
   CALL_(  initspr)  ;;;;;;;initplayer
   ld      ix,monster1        ;{  --|--  ;kill all the monsters
   ld      de,sprsize         ;     |
   ld      b,monsternum       ;     |
clrmonsters:                  ;     |
   ld      (ix+sprmonsth),0   ;     |
   add     ix,de              ;     |
   djnz    clrmonsters        ;}  --|--
gameloop:
   CALL_(  display)           ;
   halt
   CALL_(  moveplayer)        ;
   CALL_(  blockfall)
   ld      a,(frame)          ;increment frame counter{
   inc     a
   ld      (frame),a
   bit     0,a
   jr      z,Nomovebullet
   CALL_(  movebullet)
Nomovebullet:
   ld      a,(delay)          ;increment delay counter{
   inc     a                  ;
   ld      (delay),a          ;
   and     3
   cp      3                  ;
   jr      nz,gameloop        ;}
   ld      a,(delay)
   and     7
   cp      7
   jr      nz,gameloop
   CALL_(  movemonster)       ;
   ld      a,(playmode)         ;{new level yet?? ie found scroll
   bit     hasscrollbit,a       ;
   jr      z,skipnewlevel
   ld      hl,$0503
   ld      de,newlevel
   CALL_(  putstr)
   CALL_(wait4enter);
   JUMP_(donewlevel)          ;}
skipnewlevel:
   ld      a,(health)           ;if(health!='0')  {
   cp      '0'                  ;   continue game
   jr      nz,gameloop          ;}
   ld      hl,$0603       ;;col,row
   ld      de,gameover
   CALL_(  putstr)
   CALL_(  wait4enter);
   JUMP_(  main)                ;}health=='0' so startover
quit:
   ROM_CALL(CLEARLCD)
   ld       hl,$0001       ;;col,row
   ld       de,byebye
   CALL_(   putstr)
   CALL_(   checkhiscore)
   CALL_(   puthiscore)
   CALL_(   getyourname)
   CALL_(   wait4enter);
   ;;fill graph screen with exit message
   ld       bc,1024        ;
   ld       DE,GRAPH_MEM   ;
   ld       HL,VIDEO_MEM   ;
   ldir                    ;;;end fill graph screen
   ret
;;;;;;;;;;;;end of main

;-------------------------
; functions
;-------------------------

;.db 31h ;;dummy

#include "rand.asm"
#include "actor.asm"
#include "smisc.asm"

;;void blockfall()
blockfall:
   ld  b,32
loopbf:
   ld  de,GRAPH_MEM
   ld  hl,(blockspot)
   dec hl
   ld  a,h
   and 3
   ld  h,a
   ld  (blockspot),hl
   add hl,de
   ld  c,(hl)     ;;C= fallerID
   bit fallingbit,(hl)
   jr  z,skipfallid  ;;if not skipped then hl->falling block
   ld  de,levelwidth
   ld  hl,(blockspot)
   add hl,de
   ld  a,h \  and 3 \ ld h,a
   ld  de,GRAPH_MEM
   add hl,de
   ld  a,blankid
   cp  (hl)
   jr nz,skipfallid ;;spot below falling block not empty
   ld  (hl),c  ;;draw block
   ld  hl,(blockspot)
   ld  de,GRAPH_MEM
   add hl,de
   ld  (hl),blankid  ;;erase block
skipfallid:
   djnz loopbf
   ret
;;end blockfall



;;;void stripe()
;;;destroys most!
stripe:
   ld  hl,VIDEO_MEM+13
   ld  de,16
   ld  a,00100000b
   ld  b,63
stripe_loop:
   ld  (hl),a
   add hl,de
   djnz  stripe_loop
   ld  de,$006C  ; y,x  x,y= 107,10
   ld  hl,namestr
   CALL_(putmstr);
scorespot =$126C
   ld  de,scorespot  ; y,x  x,y= 107,10
   ld  hl,scorestr
   CALL_(putmstr);
livesspot =$236D
   ld  de,livesspot  ; y,x  x,y= 107,10
   ld  hl,livesstr
   CALL_(putmstr);
   ret
;;;end stripe


;.db 3Ah ;dummy

;;intro to the game
intro:
   ld      a,r
   ld      (randvar),a
   CALL_(  dissolve) ;;ROM_CALL(CLEARLCD)
   ld      hl,0
   ld      hl,$0001
   ld      de,title
   CALL_(  putstr)
   CALL_(  puthiscore)
   ;;;;CALL_(  wait4enter)
   ld      hl,$FFFF
   ld      (score),hl
   ld      a,'9'                 ;;init health
   ld      (health),a
   ret
;;;;;;;;;;;;;;;;;;;;;end intro



purposestr .db  "You must find this",0


;;;;;showpurpose()
;;;;;alters randvar and loop
showpurpose:
s0howpurloop:
   halt
   ld      hl,randvar   ;;seeding random variable
   inc     (hl)
   ld      e,   64 - 28 ;x
   ld      d,   57  ;y was 55
   ld      hl,purposestr
   CALL_(  putmstr) ;;putmstr(e=x,d=y,hl->string);
   ld      bc, picnum*picsize + ( picsize * (playerid & idand ) )
   ld      a,(randvar)
   bit     6,a
   jr      z,skip216
   ld      bc, (playerid & idand) * picsize
skip216:
   ld      ix,(picptr)
   add     ix,bc
   ld      hl,VIDEO_MEM + (scrwidth*sprlength*7) + 3
   CALL_(  drawspr)  ;;one for player
   ld      a,(randvar)  ;;its not random here
   ld      bc, picnum*picsize + ( picsize * (scrollid & idand ) )
   bit     6,a
   jr      z,skip225
   ld      bc, (scrollid & idand) * picsize
skip225:
   ld      ix,(picptr)
   add     ix,bc
   ld      hl,VIDEO_MEM + (scrwidth*sprlength*7) + scrwidth - 4
   CALL_(  drawspr)  ;;one for scroll
   call    GET_KEY
   or      a  ;;is A==0? ;;cp      K_NOKEY
   jr      z,s0howpurloop
   ret
;;end showpurpose





;;;;;;;;;;;;;;;put hi score
puthiscore:
   ld      hl,(hiscore)            ;drawhiscore(){
   ld      de,0
   call    CP_HL_DE
   ret     z
   ld      hl,$0D06               ;
   ld      (CURSOR_ROW),hl        ;
   ld      hl,(hiscore)           ;
   ROM_CALL(D_HL_DECI)            ;
   ld      hl,$0306               ;
   ld      de,hiscorestr          ;
   CALL_(  putstr)                ;//end drawing hiscore
   ret
;;end puthiscore





;;firebullet
;;void firebullet()
;;destroys a,hl  (a=0 afterward)
firebullet:
   ld     a,(bullet+sprmondir)            ;if(bullet still going) {
   cp     K_NOKEY                  ;    return
   jr     nz,endfireb              ;}
   ld     a,(pdir)                 ;set bullet dir
   dec    a
   and    3
   inc    a
   ld     (bullet+sprmondir),a
   ld     a,brange ;bullet range
   ld     (bullet+sprmonsth),a      ;set bullet range
   ld     hl,(player+sprxyoffhl)   ;set bullet start location
   ld     (bullet+sprxyoffhl),hl
endfireb:
   ld     a,K_GRAPH
   ret
;;end firebullet


;;.db 35h ;;dummy

;;;;;;;;;;;;;;;;
;;void stopbullet()
;;destroys a,ix
stopbullet:
   ld      a,0
   ld      (bullet+sprmondir),a      ;bulletdir=0
   ld      hl,GRAPH_MEM
   ld      de,(bullet+sprxyoffhl)
   add     hl,de
   ld      a,blankid
   ld      (hl),blankid
   ret
;;;;;;;;end stopbullet

;;;;;;putblood
putblood:                        ;placing bloodpic here
   ld  hl,GRAPH_MEM
   ld  de,(hitxy)
   add hl,de
   ld  a,bloodid
   ld  (hl),a
   ret
;;end putblood



;;;;;;;;movebullet
movebullet:
   ld      a,(bullet+sprmondir)     ;;if(bulletdir==0) {
   cp      0                 ;;   goto gameloop
   JUMP_Z( exitmbullet2)     ;;}//a=bulletdirection
   ld      ix,bullet         ;;//get bullet
   CALL_( movespr)           ;;//move bullet
   ld     a,(hitxyval)       ;;if(hitxyval != 0) {
   bit    killablebit,a
   JUMP_Z(lookloopend)
;;;;;;;;;;;;;;;;;;;;;;;;find monster to kill!
;;   and    idand              ;;use this monster check if monster hp>1
;;   cp     monsters           ;;if(hitxyval > monsters) {
;;   CALL_NC( putblood);        ;;  putblood }
   and    idand
   cp     monsters           ;;if(hitxyval < monsters) {
   CALL_C(incscore);
   ld     ix,monster1        ;;;;;;;loop
   ld     a,monsternum
   ld     (loop),a
lookloop:
   ld     a,(ix+sprmonsth)
   cp     0
   jr     z,nomonstkill
   ld     h,(ix+sprxyoffh)
   ld     l,(ix+sprxyoffl)
   ld     de,(hitxy)
   ld     a,h
   cp     d
   jr     nz,nomonstkill
   ld     a,l
   cp     e
   jr     nz,nomonstkill
   dec     (ix+sprmonsth)           ;monsterhealth--
   push   ix
   ld     a,(ix+sprmonsth)
   cp     0 ;;is the monster dead?
   CALL_Z( putblood)
   ;;CALL_( incscore);
   pop    ix
nomonstkill:
   ld     de,sprsize
   add    ix,de
   ld     a,(loop)
   dec    a
   ld     (loop),a
   cp     0
   JUMP_NZ(lookloop)          ;;end search for monster loop
   CALL_( putblood)    ;;if you couldnt find live monster put blood there anywaz
lookloopend:
   ld     a,(hitxyval)       ;;if(hitxyval != 0) {
   cp     0                  ;;    stopbullet();
   CALL_NZ(stopbullet)       ;;}
exitmbullet:
   ld      a,(bullet+sprmonsth)
   dec     a
   ld      (bullet+sprmonsth),a
   cp      0
   CALL_Z( stopbullet)
exitmbullet2:
   ld      hl,GRAPH_MEM           ;{draw player
   ld      de,(player+sprxyoffhl) ;
   add     hl,de                  ;
   ld      a,playerid             ;
   ld      (hl),a                 ;}
   ret
;;end movebullet

;;.db "c",12,"g",26,"b",73

;;void putbomb( A = direction, hl= xyspot)
putbomb:
   ;;ld     a,(pdir)
   dec    a
   and    3
   ;;ld     hl,(player+sprxyoffhl)
   cp     K_UP-1
   jr     nz,notup
   ld     de,-1  ;;-levelwidth  ;up
   jr     dobomb
notup:
   cp     K_DOWN-1
   jr     nz,notdown
   ld     de,1   ;;levelwidth  ;down
   jr     dobomb
notdown:
   cp     K_LEFT-1
   jr     nz,notleft
   ld     de,-1       ;left
   jr     dobomb
notleft:  ;must right since that is left over
   ld     de,1        ;right
dobomb:
   add    hl,de        ;;hl=map offset
   ld     a,h
   and    3
   ld     h,a          ;;hl=true 1024 map offset
   ld     de,GRAPH_MEM
   add    hl,de        ;
   ld     a,(hl)       ;if( map spot is blank) {
   cp     blankid      ;
   ret    nz           ;   place bomb!
   ld     a,bombid     ;
   ld     (hl),a       ;}
   ret                 ;
;;end putbomb

;;handlef1 function
handlef1:
   ld      hl,0
nokeyyet:
   inc     hl
   halt
   ld      a,47 ;wait for 47*256 clock ticks for 60.16 seconds
   cp      h
   jr      nz,skipoffon
SwitchOff:
   ld      hl,0
   di
   ld      a,1
   out     (3),a
   ei
   halt       ;; <after this instruction your calc switches off.
SwitchOn:     ;; <The code starts again here..
   ld       a,%1011
   out      (3),a
skipoffon:
   push    hl
   call    GET_KEY
   pop     hl
   cp      K_NOKEY  ;;0
   jr      z,nokeyyet
   cp      K_MORE      ;;if press more then shut off immediately
   jr      z,SwitchOff
   cp      K_GRAPH
   jr      nz,nograph
   CALL_(showmap)
   jr      skipoffon
nograph:
   cp      K_STAT
   jr      nz,nostatscan
   CALL_(tourMap)
   jr skipoffon
nostatscan:
   cp      K_PLUS
   jr      nz,noplus
   ld      a,(playmode) ;plus key pressed so found scroll
   set     hasscrollbit,a
   ld      (playmode),a
   ret
noplus:
   cp      K_RAISE
   jr      nz,noraise
   ld      a,120          ;highjump flying
   ld      (jumpptr),a
   ld      hl,(score)
   sra     h ;proper div
   rr      l ;
   dec     hl
   ld      (score),hl
   CALL_(  incscore)
   ret
noraise:
   cp       K_COS
   jr      nz,nocos      ;;;;CHEAT!
    ld      a,'9'  ;give health
    ld      (health),a
    CALL_(dechealth)
    ld      hl,(score)
    sra     h ;proper div
    rr      l ;
    ;srl     l
    ;srl     h
    dec     hl
    ld      (score),hl
    CALL_(  incscore)
nocos:
   ret
;;end of handlef1


jumplen   =3       ;was 3

P_ALPHA =7
P_EXIT  =6
P_2ND   =5
P_F1    =4
P_UP    =3
P_RIGHT =2
P_LEFT  =1
P_DOWN  =0

;;.db 0DCh  ;;dummy

;;;moveplayer proc
moveplayer:
   ;;halt
   ld      a,(frame)
   bit     0,a
   ret     nz    ;;;only move player every other frame
   ;;call    GET_KEY
;   ld      b,50
;loopabit:
   ld      a,0
   out     (1),a
   in      a,(1)
;   cp      255
;   jr      nz,stoploopabit  ;a key has been pressed!
;   djnz    loopabit  ;;this loop will hopefully make respond better
;stoploopabit:
   bit     P_F1,a
   ;;cp      K_MORE
   ;;jr      nz,skippause
   JUMP_Z(handlef1)
;skippause:
   ;;cp      K_SECOND
   bit     P_2ND,a
   ;jr      nz,skipfire
   CALL_Z(  firebullet)
   ;;ret    ;;;;;;;;jr      skipplayer
;skipfire:
   ;;cp      K_EXIT
   in      a,(1)
   bit     P_EXIT,a
   jr      nz,noexit
   call    GET_KEY
   CALL_(wait4enter)
   cp      K_EXIT
   ret     nz  ;;;;;;;;;   jr      nz,noexit
   pop     hl ;;DITCH return address, so the quit quits
   JUMP_(  quit)
noexit:
   ld      hl,0
   ld      a,(frame)
   bit     1,a
   jr      z,skipjmpchk     ;;hopefully wont fall as fast...

   ld      a,(jumpptr)                   ;
   cp      0                             ;
   jr      nz,injump                     ;if in jump goto injump

   ld      ix,player
   CALL_(  beneath)                      ;
   ld      hl,levelwidth
   cp      blankid                             ;
   jr      z,isfalling                   ;
   cp      fireid
   jr      z,isfalling
   cp      bulletid         ;;if land on a bullet then jumps really high
   jr      nz,notbullid
   in      a,(1)
   bit     P_DOWN,a
   jr      nz,notbullid      ;;jumps really high only if pushes down.
   ld      a,20          ;highjump
   ld      (jumpptr),a
notbullid:
   ;;cp      K_UP                        ;
   ld      hl,0                          ;put 0 into hl, why??
   in      a,(1)                         ;Read keyboard
   bit     P_ALPHA,a                     ;is alpha pressed?
   jr      z,beginnewjump                ;if alpha then begin new jump
   bit     P_2ND,a
   jr      z,nogoup                      ;if 2nd is pressed don't jump w/up
   bit     P_UP,a                        ;if up then begin new jump
   jr      z,beginnewjump
   jr      nogoup
beginnewjump:
   ld      a,jumplen                     ;a=jumplen
   jr      injump2                       ;goto injump2, start new jump
injump:                                  ;
   ld      a,(jumpptr)                   ;preexisting jump in action
injump2:
   dec     a                             ;gravity
   ld      (jumpptr),a                   ;jumptr value=a
   ld      hl,-levelwidth                ;go downward
skipjmpchk:
isfalling:
nogoup:
   in      a,(1)
   bit     P_DOWN,a
   jr      nz,nogodown
   ld      a,K_DOWN
   ld      (pdir),a
   ld      hl,levelwidth
nogodown:
   in      a,(1)
   bit     P_UP,a
   jr      nz,noaimup
   ld      a,K_UP
   ld      (pdir),a
noaimup:
   ;;cp      K_RIGHT
   in      a,(1)
   bit     P_RIGHT,a
   jr      nz,nogright
   push    af          ; make sure that P_2ND is not also pushed
   ld      a,K_RIGHT    
   ld      (pdir),a
   pop     af          ; make sure that P_2ND is not also pushed
   bit     P_2ND, a    ; make sure that P_2ND is not also pushed
   jr      z,nogright  ; make sure that P_2ND is not also pushed
   ld      de,1
   push    hl  ;oldhl
   add     hl,de   ;;move right
   push    hl  ;newhl
   ld      ix,player
   ex      de,hl
   CALL_(  checkspot)  ;;hl-> xyspot
   pop     hl  ;newhl
   pop     de  ;oldhl
   and     idand
   cp      brickid & idand
   jr      nz,nogright
   ex      de,hl   ;;hl is old hl
nogright:
   ;;cp      K_LEFT
   in      a,(1)
   bit     P_LEFT,a
   jr      nz,nogoleft
   push    af     ;make sure that p2nd is not pressed as well
   ld      a,K_LEFT
   ld      (pdir),a
   pop     af          ; make sure that P_2ND is not also pushed
   bit     P_2ND, a    ; make sure that P_2ND is not also pushed
   jr      z,nogoleft  ; make sure that P_2ND is not also pushed
   ld      de,-1
   push    hl  ;oldhl
   add     hl,de   ;;move right
   push    hl  ;newhl
   ld      ix,player
   ex      de,hl
   CALL_(  checkspot)  ;;hl->xyspot
   pop     hl  ;newhl
   pop     de  ;oldhl
   and     idand
   cp      brickid & idand
   jr      nz,nogoleft
   ex      de,hl   ;;hl is old hl
nogoleft:
   ex      de,hl         ;;de is now dxdy
   ld      ix,player         ;;//get player ;;de must be dx/dy
   ld      hl,playmode
   set     isplayerbit,(hl)
   CALL_(domove)            ;;//move player
   ld      hl,playmode
   res     isplayerbit,(hl)
   ld      a,(hitxyval)
   cp      coinid            ;;coin here?
   jr      nz,skipcoin
   ;;ld      a,20              ;;TEST!
   ;;ld      (jumpptr),a       ;;TEST!
   CALL_(  incscore);
   CALL_(  incscore);
   CALL_(  incscore);
   ret
skipcoin:
   cp      fireid            ;;fire or bomb here?
   jr      nz,skipfire1
   CALL_(  dimout);
   CALL_(  dechealth);
   ld      hl,(player+sprxyoffhl)
   ld      de,GRAPH_MEM
   add     hl,de
   ld      a,bloodid
   ld      (hl),a
   ld      hl,0
   ld      (player+sprxyoffhl),hl  ;;if fire then send to restart level
   ret
skipfire1:
   cp      bombid
   jr      nz,skipbomb1
   CALL_(  dimout);
   CALL_(  dechealth);
   ret
skipbomb1:
   cp      keyid
   jr      nz,skipkey
   ld      a,(playmode)
   bit     haskeybit,a
   ret     nz
   set     haskeybit,a
   ld      (playmode),a
   CALL_(  erasehitxy)
   ld   ix,(picptr)       ;;keypic
   ld   de,picsize*(keyid & idand)
   add  ix,de
;;;   ld   de,(PROGRAM_ADDR)
;;;   add  ix,de
   ld   hl,VIDEO_MEM+894   ;(sprlength*(scrwidth*scrhite-2))
   CALL_(drawspr) ;picked up key so draw key
   ret
skipkey:
   cp      doorid
   jr      nz,skipdoor
   ld      a,(playmode)
   bit     haskeybit,a
   ret     z
   res     haskeybit,a
   ld      (playmode),a
   CALL_(  erasehitxy)
   ld   ix,(picptr)   ;;blankpic  first pic is the blank pic
;;   ld   de,(PROGRAM_ADDR)
;;   add  ix,de
   ld   hl,VIDEO_MEM+894 ;(sprlength*(scrwidth*scrhite-2))
   CALL_(drawspr)
   ret
skipdoor:
   cp      scrollid
   jr      nz,skipscrollid
   ld      a,(playmode)
   set     hasscrollbit,a
   ld      (playmode),a
   CALL_(  erasehitxy)
   CALL_(incscore)
   ret
skipscrollid:
   and     idand
   cp      brickid & idand
   ret     nz       ;;if didnt hit anything then quit!
   ld      hl,jumpptr      ;;hit something so stop the jump!
   xor     a
   cp      (hl)  ;;jumpptr==0??    ;;after experimentation, this code is kinda dumb...
   ret     z
   dec      (hl)          ;;jumpptr--
skipplayer:
   ret
;;;;;;;;;end moveplayer


;;;void erasehitxy()
;;;destroys: hl,de,a
erasehitxy:
   ld      hl,(hitxy)
   ld      de,GRAPH_MEM
   add     hl,de
   ld      a,blankid
   ld      (hl),blankid
   ret
;;;end erasehitxy


;;;incscore()
;;increments and prints score
;;destroys: a,hl
incscore:
   ld      hl,(score)
   inc     hl
   ld      (score),hl
   ld      a,l
   and     31   ;;;;;score needed for extra life
   cp      31
   jr      nz,incscore_skxtra
   ld      a,(health)
   add     a,2
   ld      (health),a
   CALL_(  dechealth)
incscore_skxtra:
   ld      hl,(score)
   ld      de,scorespot+$080E ;;$1078 ;;78
   CALL_(  putnumber)
   ret
;;;;end incscore

;;;;;;;put number on screen
;;putnumber(e=x,d=y,hl=number)
putnumber:
   ld   b,4   ;number of digits
ConvLoop:
   ld      (CURSOR_X),de
   call    UNPACK_HL
   add     a,'0'
   push    de
   ROM_CALL(M_CHARPUT)
   pop     de
   dec     e \    dec     e \   dec     e \   dec     e
   djnz ConvLoop
   ret
;;;end putnumber

warning   .db "no disassembly!"

;;putmstr(e=x,d=y,hl->string);
;;destroys bc
putmstr:
   ld      bc,(PROGRAM_ADDR)
   add     hl,bc
   ld      (CURSOR_X),de
   ROM_CALL(D_ZM_STR)
   ret
;;end putmstr


;;;;void initmonster(ix->sprite)
initmonster:
   CALL_( rand )
   ld      l,a  ; rand(256)
   ld      a,r
   and     1
   ld      h,a  ; hl=rand(512)
   ld      bc, 256
   add    hl,bc  ; 
   ld      de,(player+sprxyoffhl)
   add    hl,de  ;(hl+=playeroffset)
   ld     a,h
   and    3
   ld     h,a   ;hl%=1024
   ;DEBUG16(hl)
   ld      de,GRAPH_MEM               ;
   ex      de,hl ;so now hl=GRAPHMEM de=START
   add     hl,de
   ld      a,(hl)                     ;if( map location != blankid) {
   cp      blankid                    ;   return
   ret     nz                         ;}
   ex      de,hl                      ;swap(hl,de) so hl=random(1024)
   ld      d,monster1id               ;
   CALL_(  rand)                      ;
   srl     a
   ld      e,a          ;;first bit is used to determine patrol or not
   bit     0,a          ;;first bit to determine monster picture
   jr      z,skipm2id                 ;
   ld      d,monster2id               ;
skipm2id:                             ;
   ld      b,1                        ;
   ld      c,$01                      ;monster initial direction
   CALL_(initspr)                     ;
   ret                                ;
;;end initmonster



;;A=doseek() ;returns dir 1-4, down=1,left=2,right=3,up=4
doseek:
   CALL_( rand) 
   srl  a
   srl  a
   and  3   ;25% of time do random move
   jr nz,notberand
   ld   a,r
   and  3
   inc  a
   ret
notberand:
   ld   de,(player+sprxyoffhl)
   ld   h,(ix+sprxyoffh)
   ld   l,(ix+sprxyoffl)
   or a       ;compare hl,de; clear f
   sbc hl,de  ;set f bits
   ld   a,h
   and 3  ;mod 1024
   ld  h,a
   or a       ;compare hl,de; clear f
   ld  de,16
   sbc hl,de  ;set f bits
   add hl,de
   jr   nc,notgoleft
   ld a,K_LEFT
   ret
notgoleft:
   or a       ;compare hl,de; clear f
   ld  de,1024-16
   sbc hl,de  ;set f bits
   add hl,de
   jr   c,notgoright
   ld a,K_RIGHT
   ret
notgoright:
   or a       ;compare hl,de; clear f
   ld  de,512
   sbc hl,de  ;set f bits
   add hl,de
   jr   nc,notgoup
   ld a,K_UP
   ret
notgoup:
   ld a,K_DOWN
   ret
;;end doseek


;;;A=beneath(ix->monster)  or A=checkspot(ix->monster,de=offset)
;;destroys: hl,de,a
beneath:
   ld      de,levelwidth        ;
checkspot: ;;; de->offset to check
   ld      h,(ix+sprxyoffh)     ;
   ld      l,(ix+sprxyoffl)     ;
   add     hl,de                ;
checkthis: ;;; A=checkthis(hl= xyspot)
   ld      a,h                  ;
   and     3                    ;
   ld      h,a                  ;
   ld      de,GRAPH_MEM         ;
   add     hl,de                ;
   ld      a,(hl)               ;
   ret
;;;;;end beneath


;;;movemonster
;;;;;;;;;;;begin monster movement
movemonster:
   ;ld      a,monsternum  ;;(level)    ;set up monster loop
   ;ld      (loop),a
   ld      ix,monster1   ;ix must be protected!
   ld      (loop),ix
monstloop:
   ld      a,(ix+sprmonsth)     ;if monster not alive {
   cp      0                    ;   attempt to make alive
   CALL_Z( initmonster)         ;}
   ld      a,(ix+sprmonsth)     ;if monster not alive {
   cp      0                    ;   goto skipallhits
   JUMP_Z( skipallhits)         ;}
   ld      a,(ix+sprmonstmv)    ;if(monster is seeker) {
   bit     seekbit,a
   ld      a,(ix+sprmondir)
   push    ix
   jr      z,noseek
   CALL_( doseek )            ;do seek stuff!}
   jr      nofalling
noseek:
   push    af
   CALL_(  beneath)  ;;assumes IX -> monster
   cp      0
   jr      nz,notfall
   pop     af                   ;
   ld      a,K_DOWN             ;
   ld      (ix+sprmondir),a     ;
   jr      nofalling
notfall:                   ;}end check beneath monster
   pop     af
nofalling:
   CALL_(movespr)               ;movespr(ix)
   pop     ix                   ;
   ld      a,(ix+sprmonstmv)    ;if(monster is not seeker)
   bit     seekbit,a            ;{
   ld      a,(ix+sprmondir)     ;  skip all patroller stuff
   jr      nz,skipredir         ;}

   ld      a,r                  ;if(random R )
   and     7                   ;
   cp      7                   ;
   jr      nz,notrap            ;  then put bomb down!
   ld      h,(ix+sprxyoffh)
   ld      l,(ix+sprxyoffl)
   ld      a,r                  ;
   push    ix
   CALL_(  putbomb)             ;
   pop     ix
notrap:                         ;}
   ld      a,(hitxyval)
   cp      0                    ;if(monster hit anything) {
   jr      z,skipredir          ; get a new dir
   CALL_(rand)                  ; get a random direction
   srl     a
   srl     a                    ;
   srl     a                    ;
   and     $03                  ;
   inc     a                    ;
   ld      (ix+sprmondir),a     ;
skipredir:                      ;}
   ld      a,(hitxyval)         ;if(hitxyval==playerid) {
   cp      playerid             ;    dechealth();
   jr      nz,skipdech
   ld      de,GRAPH_MEM
   ld      h,(ix+sprxyoffh)
   ld      l,(ix+sprxyoffl)
   add     hl,de
   ld      a,bloodid
   ld      (hl),a
   ld      a,0
   ld      (ix+sprmonsth),a     ;kill monster!!
   push    ix
   CALL_(  dimout)
   CALL_(  dechealth)         ;}
   pop     ix
   jr      skipallhits
skipdech:
   ;ld      a,(hitxyval)
   ;cp      treeid
   ;jr      nz,skiptreehit
   ;ld      hl,GRAPH_MEM
   ;ld      de,(hitxy)
   ;add     hl,de
   ;ld      a,fireid
   ;ld      (hl),a
;skiptreehit:
   ld      a,(hitxyval)
   cp      fireid
   jr      nz,skipallhits
   ld      de,GRAPH_MEM
   ld      h,(ix+sprxyoffh)
   ld      l,(ix+sprxyoffl)
   add     hl,de
   ld      a,bloodid
   ld      (hl),a
   ld      a,0
   ld      (ix+sprmonsth),a     ;kill monster!!
skipallhits:                        ;
   ld      bc,sprsize           ;
   add     ix,bc                ; monsterpointer++
   ld      hl,(loop)
   ;DEBUG16b(hl)
   add     hl,bc
   ;DEBUG16(ix)
   ;DEBUG16a(hl)
   ld      (loop),hl
   push    ix
   pop     de
   call    CP_HL_DE
   jr      z,skipcheck
   CALL_(dimout)
   ret
skipcheck:
   ld      hl,(loop)
   ld      de,bullet
   call    CP_HL_DE
   JUMP_NZ(monstloop)
   ;ld      a,(loop)             ;loop--;
   ;dec     a                    ;
   ;ld      (loop),a             ; if(loop!=0) continue looping
   ;cp      0                    ;;assume a=monstnum left
   ;JUMP_NZ(monstloop)           ;;}end move monsters
   ret
;;end movemonster

;;;;;;;;;end movemonster

;;;dechealth()
;;decrements and prints health
;;destroys hl,a
dechealth:
   ld      hl,livesspot+$0807
   ld      (CURSOR_X),hl
   ld      a,(health)
   cp      '9'+1
   jr      c,noadjhealth
   ld      a,'9'+1
noadjhealth:
   cp      '0'
   jr      z,skipdechealth
   dec     a
skipdechealth:
   ld      (health),a
   ld      hl,health
   ROM_CALL(D_ZM_STR)
   ret
;;end dechealth


;;Waits for enter to be pressed.
;; void wait4enter()
;;destroys A
wait4enter:
   ;;ROM_CALL(BUSY_ON)
enterwait:
   halt
   ld      hl,randvar        ;seed random counter
   inc     (hl)
   call    GET_KEY
   cp      K_NOKEY
   jr      z,enterwait
leaveexit:
   ;;push    af
   ;;ROM_CALL(BUSY_OFF)
   ;;pop     af
   ret
;;end wait4enter


;;printnum(hl=number,b=col,c=row)
printnum:
   ld      (CURSOR_ROW),bc
   ROM_CALL(D_HL_DECI)
   ret
;;end printnum



;;initlevel
;;
initlevel:                     ;;first level is level 0
   ld    a,(levelnumand)
   ld    b,a
   ld    a,(level)             ;;find level!!
   and   b ;;and (levelnumand)
   ld    b,a
   inc   b
   ld    hl,(levelptr)
   ld    de,-levelsize
   add   hl,de
   ld    de,levelsize
initlevel_l1:
   add   hl,de
   djnz  initlevel_l1
   ;;;ex    de,hl            ;de->levelmap <-NOT so hl->mapdata
   ld    bc,levelsize     ;bc=count of bytes
;;   ld    hl,(PROGRAM_ADDR)
;;   ld    de,levelmap
;;   add   hl,de            ;hl->map data
   ld    de,GRAPH_MEM     ;de->graph mem
initloop1:
   ld    a,(hl)            ;graphmem[loop]=mapdata[loop]
   srl   a \ srl a \ srl a \ srl a
   CALL_(translate)
   ld    (de),a
   ld    a,(hl)
   and   $0F
   CALL_(translate)
   inc   de
   ld    (de),a
   inc   hl
   inc   de
   dec   bc
   ld    a,b
   cp    0
   jr    nz,initloop1
   ld    a,c
   cp    0
   jr    nz,initloop1
   ret
;;end initlevel

;;.db 32h ;;dummy

;;A=translate(A=0..15);
;;saves: all but A
translate:
   push  hl                  ;
   push  de                  ;
   ld    hl,0                ; hl=a
   ld    l,a                 ; de=program start
   ld    de,(PROGRAM_ADDR)   ;
   add   hl,de               ; hl+=de
   ld    de,mapper           ; de=mapper
   add   hl,de               ; hl+=de
   ld    a,(hl)              ; a=*(a+program start+mapper)
   pop   de                  ;
   pop   hl                  ;
   ret
;;end translate



;;;;;resolvescr(bc=potential GRAPH_MEM offset)
;;;;;destroys a
;;;;;returns de->GRAPH_MEM+(bc&1023)
resolvescr:
   ld      de,GRAPH_MEM       ;;de->GRAPH_MEM
   ld      a,b                ;;bc &= 1023 0x03FF
   and     3                  ;;
   ld      b,a                ;;return GRAPH_MEM+(bc&1023)
   ex      de,hl              ;;
   add     hl,bc              ;;
   ex      de,hl              ;;de->GRAPH_MEM+(bc&1023)
   ret

;;;;;;;;;;;;;waits for any key to be pressed.
;; void step()
step:
   push    af
stepagain:
   call    GET_KEY
   cp      0
   jr      z,stepagain
   pop     af
   ret
;;;;;;;end step

display:
   ld      hl,(player+sprxyoffhl)
   ld      de,-(levelwidth*4)-(dispwidth/2)
   add     hl,de    ;;;hl->map data offset
   ld      a,h
   and     3
   ld      h,a
   CALL_(  refresh)
   ret
;;;;end display

;;;;;;;;;;updates the screen
;;;;;;;;refresh(hl->upperleftcorner)
;;;;;;;;destroys all!!
refresh:
   push    hl
   pop     bc                 ;;bc->map data offset!
   ld      a,scrsize
   ld      (loop),a           ;;loop scrsize times
   ld      hl,VIDEO_MEM       ;;hl->video
looplvl:
   CALL_(    resolvescr);       ;;de->mapdata in graphmem
   ;;;;DEBUG16(BC)
   push bc             ;;;;;;;;SAVE BC!
;;;;;;;;putobj(treeid,skiptreeid);;;;;;;;;;;
;;;;putobj(a=mapitem
   ld  a,(de)                        ;
   sla a                             ;
   sla a                             ;
   sla a           ;a*=8             ;
   push hl                           ;
	 push hl                         ;
       ld   hl,(picptr)  ;;;picbank0              ;
       cp   animators*8              ;if(id < animators) {
       jr   nc,skippicbank           ;
	   ld   bc,(frame)               ;   if(bit 6 of frame != 0) {
       bit  5,c                      ;       use bank 1 of pics
       jr   z,skippicbank            ;
	   ld   hl,(picptr)    ;;;picbank1              ;   }
      ld   de,picnum*picsize
      add  hl,de
skippicbank:                         ;}
      ;; ld   hl,(PROGRAM_ADDR)        ;
	   ;;add  hl,de       ;now hl->puts to  beginning of a picture bank
       ld   d,0                      ;
       ld   e,a                      ;
       add  hl,de                    ;
       push hl                       ;
       pop  ix                       ;ix->points to the picture
     pop hl                          ;
     CALL_(drawspr)                  ;
   pop hl                            ;
skipall:                             ;
;;;;;;;;;;;;continue loop            ;
   pop     bc             ;;;;;;RELOAD BC   bc->map data offset
   ld      a,l                ;hl->video
   and     $0F
   cp      $0C
   jr      nz,skipmultadd
   ld      de,scrwidth*sprlength-scrwidth+border   ;112
   add     hl,de             ;;hl->video+screenwrap
   push    hl                ;;bc+=levelwidth-1 {
     push    bc              ;;  ---
	 pop     hl              ;;   |
     ld      de,levelwidth-scrwidth+border ;;   |
     add     hl,de           ;;   |
     push    hl              ;;   |
     pop     bc              ;;  ---
   pop     hl                ;;}
skipmultadd:
   inc     hl               ;;hl++
   inc     bc               ;;bc++     //bc->map data offset
   ld      a,(loop)
   dec     a
   ld      (loop),a
   cp      0
   JUMP_NZ(looplvl)
donelvl:
   ret
;;;;;;;;;;end load level

;;.db 22h ;dummy

;;;dissolve()
;;;affects: loop!!
dissolve:
   ld   hl,0                ;
   ld   (loop),hl           ;loop=0;
dissolve_loop:              ;do{
   ld   hl,(loop)           ;   *(VIDEO_MEM+loop)=0;
   ld   de,VIDEO_MEM        ;
   add  hl,de               ;
   ld   a,00000000h         ;
   ld   (hl),a              ;
   ld   hl,(loop)           ;
   push hl
   pop  de    ;;hl=de
   add  hl,de               ;   loop( 5 times){
   add  hl,de               ;      loop+=loop;
   add  hl,de
   add  hl,de               ;   }
   ld   de,3
   add  hl,de               ;   loop+=3;
   ld   a,h                 ;
   and  3                   ;   loop &= 0x03FF;
   ld   h,a                 ;
   ld   (loop),hl           ;
   cp   0                   ;}while(loop!=0);
   jr   nz,dissolve_loop    ;
   halt
   ld   a,l                 ;
   cp   0                   ;
   jr   nz,dissolve_loop    ;
   ret                      ;return;
;;;end dissolve


;;;;;;;;;;;;;;;;;getyourname()
getyourname:
    ld   hl,modebits
    bit  newhiscorebit,(hl)
    ret  z       ;;;;;;do nothing if no new hiscore
    ;;putstr(l=row,h=col,DE=string)
    ld   hl,$0107
    ld   de,enteryournamestr
    CALL_( putstr)
    ld   b,3
    ld   de,firstname
outernenterloop:
    push bc
    push de
nameenterloop:
    call GET_KEY
    ld   hl,(PROGRAM_ADDR)
    ld   de,letterconverter
    add  hl,de
    ld   e,a
    ld   d,0
    add  hl,de
    xor  a
    cp   (hl)
    jr   z,nameenterloop  ;;;no valid letter pressed
    pop  de
    ld   a,(hl)      ;;hl->letter
    ld   (de),a      ;;store letter
    inc  de
    push de
    ROM_CALL( TX_CHARPUT)  ;;a=letter
    pop  de
    pop  bc
    djnz  outernenterloop
    ret
;;;;;;;;;end getyourname





;------------------------------------
; data section
;------------------------------------

letterconverter:         ;For converting keys into letters
   .db 0, 0,0,0, 0,0,0 ,0,0,'-'    ;00-09 - not valid
   .db 'X,'T','O','J','E'   ;0A-0E - valid
   .db 0,0                  ;0F-10 - not valid
   .db ' ','W','S','N','I'  ;11-15 - valid
   .db 'D'                  ;16    - valid
   .db 0,0                  ;17-18 - not valid
   .db 'Z','V','R','M','H','C';19-1E- valid
   .db 0,0                  ;1F-20 - not valid
   .db 'Y','U','Q','L','G','B';21-26 - valid
   .db 0,0,0,'='              ;27-2A - not valid
   .db 'P','K','F','A'      ;2B-2E - valid
   .db 0,0,0,0,0,0,0,0,0,0  ;Rest  - not valid

enteryournamestr .db "Enter initials:",0

cantfind  .db  "Do not run directly. ",0
title: .db     "        Caves        "
		 .db     " (C)1996 Chris Busch "
       .db     "2nd=fire   alpha=jump"
		 .db     "arrows=move  f1=pause"
		 .db     "Press a key to start.",0
gameover: .db    "Game Over!",0
hiscorestr: .db  "High Score:",0
byebye:   .db  "Caves  by Chris Busch"
		  .db    "shareware:To register"
		  .db    "send me email thank u"
        .db    "to  "
myname:        .db "cgbusch@yahoo.com",0

newlevel  .db    "New Level!",0

namestr   .db "Caves",0
scorestr  .db "Score",0
livesstr  .db "Lives",0


mapper .db blankid,playerid,fwallid,monster2id
       .db coinid,scrollid,fireid
	    .db bombid,bulletid,bloodid,treeid,brickid,doorid,keyid,wallid

.END
