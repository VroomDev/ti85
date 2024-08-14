;;Chris Busch

;;(c)1995

;;;;
;;;headers
#include "ti-85.h"
#define  jp   DONT_USE
;;;;;;----------------------------------
;;macro section
;;;;;;----------------------------------

#define DEBUG16(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0000 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF
#define DEBUG16a(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0001 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF
#define DEBUG16b(REG) push AF \ push BC \ push DE \ push HL \ push IX \ push IY \ push REG \ pop hl \ ld bc,$0002 \ call $8C0F \ .dw printnum \ pop IY \ pop IX \ pop HL \ pop DE \ pop  BC \ pop  AF

sprxyoffhl    = 0
sprxyoffh     = 1  ;sprite video memory location
sprxyoffl     = 0  ;sprite video memory location
spridtype     = 2  ;sprite picture info
sprempty      = 3  ;non used...
sprmonstmv    = 3  ;valid for monster ONLY, tells how to move
sprmonsth     = 4  ;valid for monsters ONLY, health
sprmondir     = 5  ;valid only for monsters!
sprextra1     = 4
sprextra2     = 5
sprsize      = 6

hibyte       = 1
lobyte       = 0

brange       = 4 ;;bullet range

typeand      = 11100000b
idand        = 00011111b

noerasebit     = 7
noeraseand     = 10000000b
killablebit    = 6
killableand    = 01000000b

;;;;;;ids
blankid      =0
playerid     =1 | noeraseand
monster1id   =2 | noeraseand | killableand
monster2id   =3 | noeraseand | killableand
monsters     =4  ;<= a bullet will not put blood on it unless monster
coinid       =4
scrollid     =5 | noeraseand
fireid       =6 | noeraseand | killableand
bombid       =7              | killableand
animators    =8       ;;must be less than animators to animate!!
bulletid     =8 | noeraseand
bloodid      =9
treeid       =10 | noeraseand | killableand
brickid      =11 | noeraseand
doorid       =12 | noeraseand
keyid        =13 | noeraseand

;;;monster move types
seekbit     =0   ;;else patroller

scrwidth   =16
dispwidth  =13
border     =3
sprlength  =8
scrhite    =8
scrsize    =scrwidth*scrhite
levelwidth =32
levelhite  =32
levelsize  =(levelwidth*levelhite)/2
leveland   =levelsize-1
;;levelnumand =1

;;;;;;--------------------------------
;;text memory
;;;;;;--------------------------------
;;sprite definition
;;struct sprite {
;;    void* vidmem  //16bits
;;    void* pic     //16bits
;;    byte,byte
;;}

monsternum        =16

player          =TEXT_MEM       ;$80DF
monster1        =player+sprsize
bullet          =monster1+(sprsize*monsternum)
randvar         =bullet+sprsize
score           =randvar+1
oldxy           =score+2
frame           =oldxy+2
delay           =frame+1
loop            =delay+1   ;loop used by movebullet,movemonster,refresh
hitxy           =loop+2
hitxyval        =hitxy+2
health          =hitxyval+1
pdir            =health+2
level           =pdir+1
hiscore         =level+1
playmode        =hiscore+2
levelptr        =playmode+1
levelnumand     =levelptr+2
lastvar         =levelnumand+1
;;;;;;;;;;;;total=??
endoftext       =$8186
#if ( lastvar >= endoftext)
      ; generate an invalid statement to cause an error
      ;  when we go over the text boundary.
	  !!! text area bounds exceeded.
#endif

;playmode bits
haskeybit    =1
hasscrollbit =0


;-------------------------
; Title
;-------------------------
.org    0
.db     "Scrolls v1.0",0

;-------------------------
; Program start
;-------------------------

main:
   ld      a,0
   ld      (level),a
   CALL_(  checkhiscore);
   CALL_(  intro);
   CALL_(  findlevel);
donewlevel:
startlevel:
   CALL_(  dissolve) ;;;;;ROM_CALL(CLEARLCD)
   CALL_(  initlevel)
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
   CALL_(  stripe)
gameloop:
   CALL_(  display)           ;
   CALL_(  moveplayer)        ;
   ld      a,(frame)          ;increment frame counter{
   inc     a                  ;
   ld      (frame),a          ;}
   ld      a,(delay)          ;increment delay counter{
   inc     a                  ;
   ld      (delay),a          ;
   and     3
   cp      3                  ;
   jr      nz,gameloop        ;}
   CALL_(  movebullet)
   ld      hl,GRAPH_MEM           ;{draw player
   ld      de,(player+sprxyoffhl) ;
   add     hl,de                  ;
   ld      a,playerid             ;
   ld      (hl),a                 ;}
   ld      a,(delay)
   and     7
   cp      7
   jr      nz,gameloop
   CALL_(  movemonster)       ;
   CALL_(  rndtree)
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
   ld       hl,$0002       ;;col,row
   ld       de,byebye
   CALL_(   putstr)
   CALL_(   puthiscore)
   CALL_(   wait4enter);
   ret

;-------------------------
; functions
;-------------------------

#include "rand.asm"
#include "actor.asm"

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
   ld  de,$0068  ; y,x  x,y= 107,10
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


;;;;;;;void dimout()
dimout:
    ld  a,$1F ;;;(CONTRAST)
dimmer:
    out (2),a
    nop
    halt
    nop
	dec  a
    cp   0
	jr   nz,dimmer
    ld   a,(CONTRAST)
    out  (2),a
	ret
;;end dimout


;;intro to the game
intro:
   ld      a,r
   ld      (randvar),a
   CALL_(  dissolve) ;;ROM_CALL(CLEARLCD)
   ld      hl,0
   ld      hl,$0002
   ld      de,title
   CALL_(  putstr)
   CALL_(  puthiscore)
   CALL_(  wait4enter)
   ld      hl,$FFFF
   ld      (score),hl
   ld      a,'7'                 ;;init health
   ld      (health),a
ret

;;;;;;;;;;;;;;;put hi score
puthiscore:
   ld      hl,(hiscore)            ;drawhiscore(){
   ld      de,0
   call    CP_HL_DE
   ret     z
   ld      hl,$0D07               ;
   ld      (CURSOR_ROW),hl        ;
   ld      hl,(hiscore)           ;
   ROM_CALL(D_HL_DECI)            ;
   ld      hl,$0307               ;
   ld      de,hiscorestr          ;
   CALL_(  putstr)                ;//end drawing hiscore
   ret


;;putstr(l=row,h=col,DE=string)
;;;;;;;;ld      HL,$0003
putstr:
   ld      (CURSOR_ROW),HL
   ld      HL,(PROGRAM_ADDR)
   add     HL,DE
   ROM_CALL(D_ZT_STR)
   ret

;;checks for high score
checkhiscore:
   ld      hl,(hiscore)           ;checkfor new hiscore{
   ld      de,(score)
   call    CP_HL_DE
   ret     nc
   ld      hl,(score)
   ld      (hiscore),hl           ;
   ret


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
   and    idand
   cp     monsters           ;;if(hitxyval > monsters) {
   CALL_NC( putblood);        ;;  putblood }
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
   CALL_( incscore);
   pop    ix
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
exitmbullet:
   ld      a,(bullet+sprmonsth)
   dec     a
   ld      (bullet+sprmonsth),a
   cp      0
   CALL_Z( stopbullet)
exitmbullet2:
   ret
;;end movebullet


;;void putbomb()
putbomb:
   ld     a,(pdir)
   dec    a
   and    3
   ld     hl,(player+sprxyoffhl)
   cp     K_UP-1
   jr     nz,notup
   ld     de,-levelwidth  ;up
   jr     dobomb
notup:
   cp     K_DOWN-1
   jr     nz,notdown
   ld     de,levelwidth  ;down
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


;;;moveplayer
moveplayer:
   call    GET_KEY
   cp      K_MORE
   jr      nz,skippause
   CALL_(wait4enter)
   ret
skippause:
   cp      K_SECOND
   jr      nz,skipfire
   CALL_(  firebullet)
   ret    ;;;;;;;;jr      skipplayer
skipfire:
   cp      K_ALPHA ;;place bomb
   jr      nz,skipalpha
   CALL_(  putbomb)
   ret
skipalpha:
   cp      K_COS
   jr      nz,nocos      ;;;;CHEAT!
   ld      a,'3'
   ld      (health),a
   CALL_(  dechealth)
   ld      hl,(score)
   srl     l
   srl     h
   dec     hl
   ld      (score),hl
   CALL_(  incscore)
   ret     ;jr      skipplayer
nocos:
   cp      K_EXIT
   jr      nz,noexit
   CALL_(  wait4enter)
   cp      K_EXIT
   jr      nz,noexit
   pop     hl ;;DITCH return address
   JUMP_(  quit)
noexit:
   cp      K_NOKEY
   ret     z  ;;;;jr      z,skipplayer
   ld      (pdir),a
   ld      ix,player         ;;//get player
   CALL_(movespr)            ;;//move player
   ld      a,(hitxyval)
   cp      coinid            ;;coin here?
   jr      nz,skipcoin
   CALL_(  incscore);
   CALL_(  incscore);
   CALL_(  incscore);
   ret
skipcoin:
   cp      fireid            ;;fire or bomb here?
   jr      z,dofire
   cp      bombid
   jr      nz,skipfire1
dofire:
   CALL_(  dimout);
   CALL_(  dechealth);
   ret
skipfire1:
   cp      keyid
   jr      nz,skipkey
   ld      a,(playmode)
   bit     haskeybit,a
   ret     nz
   set     haskeybit,a
   ld      (playmode),a
   CALL_(  erasehitxy)
   ld   ix,keypic
   ld   de,(PROGRAM_ADDR)
   add  ix,de
   ld   hl,VIDEO_MEM+894   ;(sprlength*(scrwidth*scrhite-2))
   CALL_(drawspr)
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
   ld   ix,blankpic
   ld   de,(PROGRAM_ADDR)
   add  ix,de
   ld   hl,VIDEO_MEM+894 ;(sprlength*(scrwidth*scrhite-2))
   CALL_(drawspr)
   ret
skipdoor:
   cp      scrollid
   ret     nz
   ld      a,(playmode)
   set     hasscrollbit,a
   ld      (playmode),a
   CALL_(  erasehitxy)
   CALL_(incscore)
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
   and     63
   cp      63
   jr      nz,incscore_skxtra
   ld      a,(health)
   add     a,2
   ld      (health),a
   CALL_(  dechealth)
incscore_skxtra:
   ld      hl,(score)
   ld      de,scorespot+$080D ;;$1078 ;;78
   CALL_(  putnumber)
   ret
;;;;end incscore

;;;;;;;put number on screen
;;putnumber(e=x,d=y,hl=number)
putnumber:
   ld   b,3
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

;;putmstr(e=x,d=y,hl->string);
;;destroys bc
putmstr:
   ld      bc,(PROGRAM_ADDR)
   add     hl,bc
   ld      (CURSOR_X),de
   ROM_CALL(D_ZM_STR)
   ret
;;end putmstr

;;;;plants a rnd tree
;;void rndtree()
;;saves nothing
rndtree:
   CALL_(rand)
   bit 6,a                  ;if bit 6 set then
   ret z                    ;    return
   srl a
   srl a
   ld  e,a
   and 3
   ld  d,a
   CALL_(rand)
   add a,e
   ld  e,a
   ld  hl,GRAPH_MEM
   add hl,de
   ld  a,(hl)
   cp  blankid
   ret nz
   ld  (hl),treeid
   ret
;end rndtree

;;;;void initmonster(ix->sprite)
initmonster:
   CALL_(  rand)                      ;
   and     3                          ;
   ld      d,a                        ;
   CALL_(  rand)                      ;
   ld      e,a                        ;de= random(1024)
   ld      hl,GRAPH_MEM               ;
   add     hl,de                      ;
   ld      a,(hl)                     ;if( map location != blankid) {
   cp      blankid                    ;   return
   ret     nz                         ;}
   ex      de,hl                      ;swap(hl,de) so hl=random(1024)
   ld      d,monster1id               ;
   CALL_(  rand)                      ;
   srl     a
   ld      e,a          ;;first bit is used to determine patrol or not
   bit     1,a          ;;second bit to determine monster picture
   jr      z,skipm2id                 ;
   ld      d,monster2id               ;
skipm2id:                             ;
   srl     a                          ;
   and     $03                   ;health=one to 4 hp
   inc     a                          ;
   ld      b,a                        ;
   ld      c,$01                 ;;monster initial direction
   CALL_(initspr)                     ;
   ret                                ;
;;end initmonster

;;A=doseek() ;returns dir 1-4
doseek:
   ld   de,(player+sprxyoffhl)
   ld   h,(ix+sprxyoffh)
   ld   l,(iy+sprxyoffl)
   call CP_HL_DE
   CALL_( rand)
   srl  a
   srl  a
   jr   c,lessthan
   ;hl greater than de, monster is past! so want up left 4,2
   and  10b
   or   01b
   inc  a
   ret
lessthan: ;hl<de want 1,3
   and  10b
   or   01b
   ret
;;end doseek

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
   CALL_NZ( doseek )            ;do seek stuff!}
   CALL_(movespr)               ;movespr(ix)
   pop     ix                   ;
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
   push    ix
   CALL_(  dimout)
   CALL_(  dechealth)         ;}
   pop     ix
   jr      skipallhits
skipdech:
   ld      a,(hitxyval)
   cp      treeid
   jr      nz,skiptreehit
   ld      hl,GRAPH_MEM
   ld      de,(hitxy)
   add     hl,de
   ld      a,fireid
   ld      (hl),a
skiptreehit:
   ld      a,(hitxyval)
   cp      bombid
   jr      nz,skipallhits
   ld      hl,GRAPH_MEM
   ld      de,(hitxy)
   add     hl,de
   ld      a,bloodid
   ld      (hl),a
   ld      a,0
   ld      (ix+sprmonsth),a     ;kill monster!!
   push     ix
   CALL_(  incscore)
   pop      ix
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
   ld      a,(randvar)        ;seed random counter
   add     a,13
   ld      (randvar),a
   call    GET_KEY
   cp      K_EXIT
   jr      z,leaveexit
   cp      K_ENTER
   jr      nz,enterwait
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
   and   $0F
   CALL_(translate)
   ld    (de),a
   ld    a,(hl)
   srl   a \ srl a \ srl a \ srl a
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
       ld   de,picbank0              ;
       cp   animators*8              ;if(id < animators) {
       jr   nc,skippicbank           ;
	   ld   bc,(frame)               ;   if(bit 6 of frame != 0) {
       bit  5,c                      ;       use bank 1 of pics
       jr   z,skippicbank            ;
	   ld   de,picbank1              ;   }
skippicbank:                         ;}
       ld   hl,(PROGRAM_ADDR)        ;
	   add  hl,de                    ;
       ld   d,0                      ;
       ld   e,a                      ;
       add  hl,de                    ;
       push hl                       ;
       pop  ix                       ;
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

VARNLEN =$8083
VARNAME =$8084
FINDVAR =$2715

;;findlevel1()
findlevel:
   ld   de,lvlname
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   ld   a,(hl)
   inc  a
   inc  a
   ld   b,a
   ld   de,VARNLEN
findlevel1:
   ld   a,(hl)
   ld   (de),a
   inc  de
   inc  hl
   djnz findlevel1  ;;name should be copied.
   ld   a,(ROM_VERS)
   cp   57h ;;3.0A
   jr   nz,notrom3
   call FINDVAR
   jr   didfind
notrom3:
   cp   8Eh  ;;4.0
   jr   nz,notfound
   call FINDVAR+4
didfind:
   jr   c,notfound
   ld   hl,5+108-2  ;;level offset!!
   add  hl,de
   ld   a,(hl)
   ld   (levelnumand),a            ;;set levelnumand
   ld   de,2
   add  hl,de
   ld   (levelptr),hl
   ld   de,-67
   add  hl,de
   ex   de,hl
   ld   hl,$0002
   ld   (CURSOR_ROW),HL
   ex   de,hl
   ROM_CALL(D_ZT_STR)       ;;print comment
   CALL_(wait4enter)
   ret
notfound:
   ld   hl,(PROGRAM_ADDR)
   ld   de,levelmap
   add  hl,de
   ld   (levelptr),hl        ;;use default map
   ret
;;end findlevel

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



;------------------------------------
; data section
;------------------------------------

title:   .db     "    Scrolls v1.0     "
		 .db     "(C)1995   Chris Busch"
		 .db     "(2nd=fire arrow=move)"
		 .db     "<hit enter  to start>",0
gameover: .db    "Game Over!",0
hiscorestr: .db  "high score:",0
byebye:   .db    "Scrolls - Chris Busch"
		  .db    "emailware:To register"
		  .db    "send me email thank u"
		  .db    "to:  cbusch@d.umn.edu",0

newlevel  .db    "New Level!",0

namestr   .db "Scrolls",0
scorestr  .db "Score",0
livesstr  .db "Lives",0
lvlname   .db 6,"SCRLVL",0
cantfind  .db "LVL not found!",0

#include "pics.asm"


t =treeid
b =brickid
F =bulletid
M =monster1id
m =monster2id
y =playerid
c =coinid
s =scrollid
D =doorid
k =keyid
f =fireid
B =bombid


mapper .db blankid,playerid,monster1id,monster2id,coinid,scrollid,fireid
	   .db bombid,bulletid,bloodid,treeid,brickid,doorid,keyid

levelmap:
   #include "level1.asm"
;;;   #include "level2.asm"

.END
