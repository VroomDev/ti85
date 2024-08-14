;;Chris Busch

;;(c)1995

;;;;
;;;headers
#include "ti-85.h"
#define  jp   DONT_USE
;;;;;;
;;macro section
;;;;;;
sprxyoffhl    = 0
sprxyoffh     = 1  ;sprite video memory location
sprxyoffl     = 0  ;sprite video memory location
sprpicoffhl   = 2
sprpicoffh    = 3  ;sprite picture info
sprpicoffl    = 2  ;sprite picture info
sprextra1     = 4
sprmonsth     = 4  ;valid for monsters ONLY, health
sprextra2     = 5
sprmondir     = 5  ;valid only for monsters!
sprsize      = 6

hibyte       = 1
lobyte       = 0

playerid      =00111100b;
monsterid     =01000010b;
wallid        =00000001b;
bulletid      =00001000b;
treeid        =00011100b;
brickid       =11111111b;
coinid        =00111000b;

scrwidth   =16
sprlength  =8
levelsize  =16*8
leveland   =111b   ;;and ing for number of level maps


;;;;;;
;;text memory
;;;;;;
;;sprite definition
;;struct sprite {
;;    void* vidmem  //16bits
;;    void* pic     //16bits
;;    byte,byte
;;}

monsternum        =21
player          =$80DF
monster1        =player+sprsize
bullet          =monster1+(sprsize*monsternum)
randvar         =bullet+sprsize
score           =randvar+1
oldxy           =score+1
frame           =oldxy+2
loop            =frame+2
hitxy           =loop+1
hitxyval        =hitxy+2
health          =hitxyval+1
pdir            =health+2
odir            =pdir+1
bulletdir       =odir+1
monsterst       =bulletdir+1
monsterleft     =monsterst+2
level           =monsterleft+1
playerst        =level+1
hiscore         =playerst+2
lastvar         =hiscore+1
;;;;;;;;;;;;total=~49
endoftext       =$8186
#if ( lastvar >= endoftext)
      ; generate an invalid statement to cause an error
      ;  when we go over the 4K boundary.
      !!! text area bounds exceeded.
#endif




;----------------------------------------------------------------------------
; Title
;----------------------------------------------------------------------------
.org    0
.db     "Crunch v2.4",0

;----------------------------------------------------------------------------
; Program start
;----------------------------------------------------------------------------

main:
   CALL_(  checkhiscore);
   CALL_(  intro);
startlevel:
   ROM_CALL(CLEARLCD)
   CALL_(  loadlevel)
   ld      a,(health)
   inc     a
   ld      (health),a
   CALL_(  dechealth)
   CALL_(  incscore)
   ld      a,(level)           ;;if(level<monsternum+1) {
   inc     a                   ;;
   cp      monsternum+1        ;;   level++
   jr      z,initsprites       ;;
   ld      (level),a           ;;}
initsprites:
   ld      a,0              ;;added dec 19,95 tuesday night
   ld      (bulletdir),a    ;;
   ld      ix,bullet           ;;initbullet{
   ld      de,bulletpic        ;;
   ld      bc,0                ;;
   ld      hl,VIDEO_MEM
   CALL_(initspr)              ;;}
   ld      hl,(playerst)
   ld      ix,player           ;;initplayer{
   ld      de,playerpic        ;;
   ld      bc,0                ;;
   CALL_(initspr)              ;;}
   ld      ix,monster1         ;;initmonsters{
   ld      a,(level)
   ld      (monsterleft),a
initloop:
   ld      bc,$0101                 ;;monster health,initial direction
   ld      de,monsterpic
   bit     0,a
   jr      nz,nopic1
   ld      bc,$0202                 ;;monster health,initial direction
   ld      b,a
   ld      de,monsterpic1
nopic1:
   ld      hl,(monsterst)
   CALL_(initspr)
   ld      bc,sprsize
   add     ix,bc
   dec     a
   cp      0                   ;;//assume a=monstnum left
   jr      nz,initloop         ;;}end init monsters
   CALL_(  drawplayer)
gameloop:
   CALL_(  moveplayer)
   ;;;;;;;;;;;;;;;;;do frame stuff
   ld      hl,(frame)   ;;inc(frame)
   inc     hl           ;
   ld      (frame),hl   ;;
   ld      a,h          ;if(frame==0x700) {
   cp      7            ;
   jr      nz,gameloop  ;
   ld      a,l          ;   goto gameloop;
   cp      0            ;   //if not true then do monsters
   jr      nz,gameloop  ;}
   ld      hl,0         ;{frame=0
   ld      (frame),hl   ;}
   CALL_(  movemonster);
   CALL_(  movebullet);
   JUMP_(gameloop)
quit:
   ld       hl,$0002       ;;col,row
   ld       de,byebye
   CALL_(   putstr)
   CALL_(   puthiscore)
   CALL_(   wait4enter);
   ret               ;end game

;;;;;;;;;;;;;
;;;;;;;;;functions
;;;;;;;;;;;;;

#include "rand.asm"
#include "sprite.asm"
;;;;;;;;;;;;;;;;
;;void stopbullet()
;;destroys a,ix
stopbullet:
   ld      a,0
   ld      (bulletdir),a      ;bulletdir=0
   ld      ix,(bullet+sprxyoffhl)
   jr      erasespr
   ;;ret ;//use erasespr ret


;;drawplayer
;;void drawplayer()
;;destroys: hl,ix
drawplayer:
   ld      hl,(player+sprxyoffhl)
   ld      ix,(player+sprpicoffhl)
   jr      drawspr
   ;;ret   ;;;use the ret from drawspr


;;firebullet
;;void firebullet()
;;destroys a,hl  (a=0 afterward)
firebullet:
   ld     a,(bulletdir)            ;if(bullet still going) {
   cp     K_NOKEY                  ;    return
   jr     nz,endfireb              ;}
   ld     a,(pdir)                 ;set bullet dir
   dec    a
   and    3
   inc    a
   ld     (bulletdir),a
   ld     hl,(player+sprxyoffhl)   ;set bullet start location
   ld     (bullet+sprxyoffhl),hl
endfireb:
   ld     a,K_GRAPH
   ret



;;;incscore()
;;increments and prints score
;;destroys: a,hl
incscore:
   ld      a,(randvar)
   inc     a
   ld      (randvar),a
   ld      hl,$0300
   ld      (CURSOR_ROW),hl
   ld      a,(score)
   inc     a
   ld      (score),a
   ld      l,a
   ld      h,0
   ROM_CALL(D_HL_DECI)
   ld      a,(score)
   cp      250
   jr      c,byescore
   ld      hl,$0300
   ld      (CURSOR_ROW),hl
   ld      de,wow
   CALL_(  putstr)
   ret
byescore:
   and     31
   cp      31
   ret     nz
   ld      a,(health)
   inc     a
   inc     a
   ld      (health),a
   CALL_(  dechealth)
   ret


;;;dechealth()
;;decrements and prints health
;;destroys hl,a
dechealth:
   ld      a,83
   ld      (CURSOR_X),a
   ld      a,0
   ld      (CURSOR_Y),a
   ld      a,(health)
   dec     a
   ld      (health),a
   ld      hl,health
   ROM_CALL(D_ZM_STR)
   ret

;;Waits for enter to be pressed.
;; void wait4enter()
;;destroys A
wait4enter:
   ROM_CALL(BUSY_ON)
enterwait:
   ld      a,(randvar)        ;seed random counter
   add     a,13
   ld      (randvar),a
   call    GET_KEY
   cp      K_EXIT
   jr      z,leaveexit
   cp      K_ENTER
   jr      nz,enterwait
leaveexit:
   ROM_CALL(BUSY_OFF)
   ret

;;putstr(l=row,h=col,DE=string)
;;;;;;;;ld      HL,$0003
putstr:
   ld      (CURSOR_ROW),HL
   ld      HL,(PROGRAM_ADDR)
   add     HL,DE
   ROM_CALL(D_ZT_STR)
   ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;drawlevel
loadlevel:
   ld      hl,(PROGRAM_ADDR)
   ld      de,level1map
   add     hl,de                ;hl->level1map
   ld      a,(level)            ;for{
   and     leveland             ;
   ld      de,levelsize         ;
levelc0:                        ;
   cp      0                    ;   select level!
   jr      z,levelc1            ;
   dec     a                    ;
   add     hl,de                ;
   jr      levelc0              ;
levelc1:                        ;}
   ld      a,levelsize          ;
   ld      (loop),a             ;loop=levelsize-1
   push    hl                 ;;de->levelmap
   pop     de
   ld      hl,VIDEO_MEM       ;;hl->video
looplvl:
;;;;;;;;putobj(treeid,skiptreeid);;;;;;;;;;;
 push hl
 push de
 ld   a,(de)
 ld   b,treeid
 ld   de,treepic
 CALL_(putobj);
 pop  de
 pop  hl
 ;;;;;;;;;;;;;;;;;putobj(brickid,skipbrickid);;;;;;;;;;;;;;;;
 push hl
 push de
 ld   a,(de)
 ld   b,brickid
 ld   de,brickpic
 CALL_(putobj)
 pop  de
 pop  hl
 ;;;;;;;;;;;;;;;;putobj(coinid,coinpic)
 push hl
 push de
 ld   a,(de)
 ld   b,coinid
 ld   de,coinpic
 CALL_(putobj)
 pop  de
 pop  hl
 ;;;;;;;;;;;;;;;;;;playerstart check;;;;;;;;;;
    ld      a,(de)
    cp      playerid
    jr      nz,skippid
    ld      (playerst),hl
skippid:
 ;;;;;;;;;;;;;;;monster start check;;;;;;;;;;;
    ld      a,(de)
    cp      monsterid
    jr      nz,skipmid
    ld      (monsterst),hl
skipmid:
 ;;;;;;;;;;;;continue loop
   inc     de                 ;de->map data
   ld      a,l                ;hl->video
   and     $0F
   cp      $0F
   jr      nz,skipmultadd
   ld      bc,scrwidth*sprlength-scrwidth   ;112
   add     hl,bc
skipmultadd:
   inc     hl
   ld      a,(loop)
   dec     a
   ld      (loop),a
   cp      0
   jr      nz,looplvl
donelvl:
   ret
;;;;;;;;;;end load level

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;putobj
;;;;putobj(a=mapitem,b=desired item,de=desired item pic,hl->videomem)
putobj:
 cp   b
 jr   nz,skiptreeid
 push hl
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   push hl
   pop  ix
 pop hl
 CALL_(drawspr)
skiptreeid:
 ret



;;;;;;;;;;;;;;;put hi score
puthiscore:
   ld      a,(hiscore)            ;drawhiscore(){
   cp      0                      ;
   jr      z,skipdrawhi           ;
   ld      hl,$0D07               ;
   ld      (CURSOR_ROW),hl        ;
   ld      a,(hiscore)            ;
   ld      l,a                    ;
   ld      h,0                    ;
   ROM_CALL(D_HL_DECI)            ;
   ld      hl,$0307               ;
   ld      de,hiscorestr          ;
   CALL_(  putstr)                ;//end drawing hiscore
skipdrawhi:
   ret

;;checks for high score
checkhiscore:
   ld      a,(hiscore)           ;checkfor new hiscore{
   ld      b,a                   ;
   ld      a,(score)             ;
   cp      b                     ;
   jr      c,skiphiscore         ;
   ld      (hiscore),a           ;
skiphiscore:                     ;}//end check for hi score
   ret

;;intro to the game
intro:
   ROM_CALL(CLEARLCD)
   ld      a,2
   ld      (level),a
   CALL_(  loadlevel)
   set     3,(IY+5)               ;white on black.
   ld      hl,$0002
   ld      de,title
   CALL_(  putstr)
   res     3,(IY+5)               ;black on white.
   CALL_(  puthiscore)
   CALL_(  wait4enter)
   ld      a,$FF
   ld      (score),a
   ld      hl,VIDEO_MEM+647 ;;init monster start middleofscr
   ld      (monsterst),hl
   ld      hl,VIDEO_MEM+903 ;;init player start
   ld      (playerst),hl
   ld      a,'5'                 ;;init health
   ld      (health),a
ret

;;;moveplayer
moveplayer:
   call    GET_KEY
   cp      K_SECOND
   jr      nz,skipfire
   CALL_(  firebullet)
   jr      skipplayer
skipfire:
   cp      K_COS
   jr      nz,nocos      ;;;;CHEAT!
   ld      a,'3'
   ld      (health),a
   CALL_(  dechealth)
   ld      a,(score)
   srl     a
   dec     a
   ld      (score),a
   CALL_(  incscore)
   jr      skipplayer
nocos:
   cp      K_EXIT
   jr      nz,noexit
   pop     hl ;;DITCH return address
   JUMP_(  quit)
noexit:
   cp      K_NOKEY
   jr      z,skipplayer
   ld      (pdir),a
   ld      ix,player         ;;//get player
   CALL_(movespr)            ;;//move player
   ld      a,(hitxyval)
   cp      coinid
   jr      nz,skipplayer
   CALL_(  incscore);
   ld      hl,(hitxy)
   push    hl
   pop     ix
   CALL_(  erasespr)
skipplayer:
   ret
;;;;;;;;;end moveplayer

;;;movemonster
;;;;;;;;;;;begin monster movement
movemonster:
   ld      a,(level)    ;set up monster loop
   ld      (loop),a
   ld      ix,monster1
monstloop:
   ld      a,(ix+sprmonsth)     ;if monster not alive {
   cp      0                    ;   goto skipallhits
   JUMP_Z( skipallhits)         ;}
   ld      a,(ix+sprmondir)
   push    ix                   ;
   CALL_(movespr)               ;movespr(ix)
   pop     ix                   ;
   ld      a,(hitxyval)
   cp      0                    ;if(monster hit anything) {
   jr      z,skipredir          ; get a new dir
   CALL_(rand)                  ; get a random direction
   srl     a                    ;
   srl     a                    ;
   and     $03                  ;
   inc     a                    ;
   ld      (ix+sprmondir),a     ;
skipredir:                      ;}
   ld      a,(hitxyval)         ;if(hitxyval==playerid) {
   cp      playerid                    ;    dechealth();
   jr      nz,skipdech
   push    ix
   CALL_(  dechealth)           ;}
   pop     ix
   ld      a,(health)           ;if(health!='0')  {
   cp      '0'                    ;   goto skipallhits
   jr      nz,skipallhits       ;}
   ld       hl,$0603       ;;col,row
   ld       de,gameover
   CALL_(   putstr)
   CALL_(   wait4enter);
   pop      hl   ;;;;;;;DITCH return address!
   JUMP_(  main)                ;}health=='0' so startover
skipdech:
skipallhits:                        ;
   ld      bc,sprsize           ;
   add     ix,bc                ; monsterpointer++
   ld      a,(loop)             ;loop--;
   dec     a                    ;
   ld      (loop),a             ; if(loop!=0) continue looping
   cp      0                    ;;assume a=monstnum left
   JUMP_NZ(monstloop)           ;;}end move monsters
   ret
;;;;;;;;;end movemonster

;;;;;;;;movebullet
movebullet:
   ld      a,(bulletdir)     ;;if(bulletdir==0) {
   cp      0                 ;;   goto gameloop
   JUMP_Z( exitmbullet)     ;;}//a=bulletdirection
   ld      ix,bullet         ;;//get bullet
   CALL_( movespr)           ;;//move bullet
   ld     a,(hitxyval)       ;;if(hitxyval != 0) {
   cp     monsterid
   JUMP_NZ(lookloopend)
;;;;;;;;;;;;;;;;;;;;;;;;find monster to kill!
;;;;;;;;;;$$$
;   ld      hl,$0301
;   ld      (CURSOR_ROW),hl
;   ld      hl,(hitxy)
;   ROM_CALL(D_HL_DECI)
;;;;;;;;;;end $$$
   CALL_( incscore);
   ld     ix,monster1        ;;;;;;;loop
   ld     a,(level)
   ld     (loop),a
lookloop:
   push   ix
;;;;;;;;;;$$$
;   ld      h,$09
;   ld      a,(loop)
;   ld      l,a
;   ld      (CURSOR_ROW),hl
;   ld      h,(ix+sprxyoffh)
;   ld      l,(ix+sprxyoffl)
;   ROM_CALL(D_HL_DECI)
;;;;;;;;;;end $$$
   pop    ix
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
   ld      a,(ix+sprmonsth)         ;if(monsterhealth>0) {
   cp      0                        ;   goto skipallhits
   jr      nz,nomonstkill           ;}
   push    ix                       ;placing bloodpic here
      ld      HL,(PROGRAM_ADDR)     ;
      ld      DE,bloodpic           ;
      add     HL,DE                 ;
      push    hl                    ;
        ld      h,(ix+sprxyoffh)    ;
        ld      l,(ix+sprxyoffl)    ;
      pop     ix                    ;
      CALL_(  drawspr)              ;
   pop     ix                       ;
   ld      a,(monsterleft)          ;monsterleft--
   dec     a                        ;
   ld      (monsterleft),a          ;if(monster!=0) {
   cp      0                        ;   goto skipallhits
   jr      nz,nomonstkill           ;}
   ld      hl,$0603                 ;{
   ld      de,newlevel              ; print "newlevel!"
   CALL_(  putstr)                  ;}
   CALL_(  wait4enter)              ;wait4enter();
   pop     hl ;DITCH return address!
   JUMP_(  startlevel)              ;goto startlevel
;;;;;;;;;;;;;;;;;;;;;;;;;end find monster
nomonstkill:
   ld     de,sprsize
   add    ix,de
   ld     a,(loop)
   dec    a
   ld     (loop),a
   cp     0
   JUMP_NZ(lookloop)
lookloopend:
   ld     a,(hitxyval)       ;;if(hitxyval != 0) {
   cp     0                  ;;    stopbullet();
   CALL_NZ(stopbullet)       ;;}
   CALL_(drawplayer)
exitmbullet:
   ret
;;end movebullet


;----------------------------------------------------------------------------
; data section
;----------------------------------------------------------------------------

title:   .db     "     Crunch v2.4     "
         .db     "(C)1995   Chris Busch"
         .db     "(2nd=fire arrow=move)"
         .db     "<hit enter  to start>",0
wow      .db     "COOL!",0
gameover: .db    "Game Over!",0
hiscorestr .db   "high score:",0
byebye:   .db    "Crunch by Chris Busch"
          .db    "emailware:To register"
          .db    "send me email thank u"
          .db    "to:  cbusch@d.umn.edu",0

newlevel  .db    "New Level!",0

playerpic: .db     playerid      ;00111100b
           .db     01011010b
           .db     00100100b
           .db     00011001b
           .db     11111111b
           .db     10011000b
           .db     00100100b
           .db     01100110b

monsterpic:  .db  monsterid     ;01000010b
          .db     01111110b
          .db     01011010b
          .db     00111100b
          .db     00011000b
          .db     11111111b
          .db     00011000b
          .db     01100110b

monsterpic1:  .db monsterid     ;01000010b
          .db     00111100b
          .db     01011010b
          .db     00100100b
          .db     10011001b
          .db     11111111b
          .db     00011000b
          .db     11100111b

bulletpic:  .db   bulletid      ;00001000b
          .db     00010000b
          .db     00011000b
          .db     00101100b
          .db     00111100b
          .db     00011000b
          .db     00000000b
          .db     00000000b

bloodpic:  .db    00000000b
          .db     00010000b
          .db     00001010b
          .db     00100000b
          .db     00000100b
          .db     01000010b
          .db     00010100b
          .db     00000000b

treepic:  .db     treeid    ;00011100b
          .db     00101010b
          .db     01010101b
          .db     00101010b
          .db     00011100b
          .db     00011000b
          .db     00111100b
          .db     00000000b

brickpic: .db     brickid    ;11111111b
          .db     00110000b
          .db     00110000b
          .db     11111111b
          .db     11111111b
          .db     10000001b
          .db     10000001b
          .db     11111111b

coinpic:
 .db      coinid ;00111000b
          .db     01000100b
          .db     10000010b
          .db     10000010b
          .db     01000100b
          .db     00111000b
          .db     00000000b
          .db     00000000b

t =treeid
b =brickid
M =monsterid
Y =playerid
c =coinid



level1map: .db   c,t,0,0,0,0,t,c,c,t,0,t,t,t,c,c
           .db   c,t,t,t,t,t,t,t,0,t,t,t,0,0,0,c
           .db   0,0,0,0,0,0,0,0,0,t,c,c,0,t,0,0
           .db   0,0,0,0,b,b,b,b,b,b,b,b,b,b,t,0
           .db   t,0,0,0,M,0,0,0,0,0,0,c,Y,b,0,0
           .db   t,t,0,0,b,b,b,b,b,b,b,b,b,b,0,0
           .db   t,t,t,0,0,0,0,0,0,0,0,0,0,0,0,t
           .db   t,t,t,t,0,0,0,0,0,c,t,c,0,0,t,t

level2map: .db   t,b,0,0,0,0,b,b,b,b,0,t,t,c,t,t
           .db   c,b,b,b,b,b,b,0,Y,b,t,t,c,c,c,t
           .db   0,0,0,0,b,0,c,0,0,b,c,0,0,0,0,0
           .db   0,b,0,M,b,0,b,b,b,b,0,0,t,t,t,0
           .db   0,b,0,0,b,0,b,b,t,t,0,0,t,c,c,0
           .db   0,b,0,0,0,0,c,b,t,0,0,0,0,t,0,0
           .db   0,b,b,b,b,b,b,b,0,0,t,0,0,0,0,t
           .db   0,0,0,0,0,0,0,0,0,0,t,t,c,c,t,t

           ;;;;;;starting level!
level3map: .db   c,t,0,0,0,0,t,c,0,t,0,t,t,t,0,Y
           .db   0,t,t,t,t,t,t,0,0,t,t,t,0,0,0,0
           .db   0,0,0,0,0,0,0,0,b,b,b,b,0,0,t,t
           .db   0,0,0,c,t,0,0,0,b,0,M,b,0,0,0,c
           .db   t,0,0,0,0,0,c,0,b,0,b,b,0,c,0,0
           .db   0,0,0,0,0,0,0,0,t,0,0,0,0,0,0,t
           .db   0,c,0,t,0,0,0,0,0,0,0,0,0,c,0,0
           .db   0,0,0,0,0,0,t,0,0,t,0,t,0,0,0,0

level4map: .db   0,t,0,0,0,0,t,t,t,t,0,t,c,0,0,t
           .db   0,t,t,t,t,t,t,0,c,t,t,t,0,0,0,0
           .db   0,0,0,0,0,0,0,0,0,t,c,c,0,t,t,0
           .db   0,0,b,b,b,0,0,t,t,0,0,0,0,t,c,0
           .db   t,0,b,Y,c,0,0,0,M,0,c,0,t,c,0,0
           .db   0,0,b,b,b,0,0,0,t,t,t,0,0,0,0,0
           .db   0,0,0,0,0,0,t,0,0,t,0,0,0,0,0,t
           .db   c,0,0,t,0,0,0,0,0,0,0,t,c,0,t,t

llevel1map: .db  c,t,0,0,0,0,t,t,t,t,0,t,t,t,0,c
           .db   c,0,t,t,t,t,0,t,0,t,t,t,t,0,0,0
           .db   0,t,0,t,0,0,0,0,0,0,0,0,0,0,t,0
           .db   0,t,0,0,0,0,0,0,b,b,b,b,b,c,0,b
           .db   0,t,0,t,0,t,0,0,b,0,0,0,b,0,0,b
           .db   0,t,0,t,0,b,b,b,b,Y,b,0,b,b,b,b
           .db   0,t,0,0,0,0,0,0,0,0,b,M,0,0,c,b
           .db   0,0,0,t,0,b,b,b,b,b,b,b,b,b,b,b

llevel2map: .db  t,t,0,0,0,0,t,t,t,t,0,t,t,t,0,c
           .db   t,t,t,t,t,t,t,0,0,0,t,0,0,0,0,t
           .db   t,b,b,b,b,b,0,0,b,0,0,0,0,0,0,0
           .db   0,0,0,0,Y,b,0,0,b,b,0,t,t,0,0,0
           .db   c,b,0,b,b,b,b,0,0,b,0,0,c,0,0,0
           .db   c,b,0,b,0,0,0,b,M,b,0,0,0,0,0,0
           .db   c,b,0,0,0,b,0,0,0,b,t,0,0,0,0,t
           .db   c,b,b,b,b,b,b,b,b,b,0,0,0,0,t,t

llevel3map: .db  t,t,0,0,0,0,t,t,t,t,0,t,t,0,c,c
           .db   t,t,t,t,t,t,t,t,t,t,t,t,0,0,0,0
           .db   0,0,0,0,0,0,t,0,0,b,b,b,b,0,t,t
           .db   0,b,b,0,b,0,0,0,0,b,0,0,b,0,c,c
           .db   0,b,0,0,b,0,0,t,0,b,M,0,b,0,0,0
           .db   0,b,Y,0,b,0,0,0,0,b,0,0,0,0,0,c
           .db   c,b,b,b,b,0,0,0,0,b,b,b,b,0,0,0
           .db   t,0,0,0,0,0,t,0,0,0,0,0,0,0,0,t

llevel4map: .db  0,t,0,0,0,0,t,t,0,0,0,t,t,t,0,c
           .db   0,0,t,t,t,t,t,t,t,t,t,0,0,0,0,0
           .db   t,0,c,0,0,t,0,0,0,0,0,0,0,0,0,0
           .db   0,0,Y,c,0,t,0,t,t,t,0,0,M,0,0,t
           .db   0,b,0,b,0,t,0,0,0,0,0,0,0,0,0,0
           .db   0,b,0,b,0,t,0,0,t,t,0,0,0,t,0,c
           .db   0,b,b,b,0,0,0,0,t,t,0,0,0,t,c,c
           .db   0,0,0,0,0,0,t,0,t,t,0,0,0,t,t,c


   .END
