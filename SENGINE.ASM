;;Chris Busch

;;(c)1995

;;;;
;;;headers
#include "ti-85.h"
#define  jp   DONT_USE

#include "smacros.asm"

;-------------------------
; Title
;-------------------------
.org    0
.db     "SENGINE v4.1a",0
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
   cp      'S'+'E'+'N'+'G'+'I'+'N'+'E'+' '+'v' ;;143   ;"CENGINE v"
   jr      z,skipshow
dimagain:
   CALL_(  dimout)
   jr      dimagain
   .db $3A         ;;dummy
skipshow:
   ld      b,6
   ld      hl,(PROGRAM_ADDR)
   ld      de,myname
   add     hl,de
   xor     a
chksum2:
   add     a,(hl)
   inc     hl
   djnz    chksum2
   cp      120  ;"cbusch"
   jr      nz,dimagain          ;;checksum end!

   xor     a ;;;;;;;;;ld      a,0
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
   CALL_(  showpurpose)
;;   CALL_(  findlevel);
donewlevel:
startlevel:
   CALL_(  dissolve) ;;;;;ROM_CALL(CLEARLCD)
   CALL_(  initlevel)
   CALL_(  stripe)             ;;show stripe
   ld      a,(health)
   inc     a
   ld      (health),a
   CALL_(  dechealth)
   CALL_(  incscore)
   xor     a  ;;;ld      a,0                 ;;{clear play mode flags!
   ld      (playmode),a        ;;}
   ld      hl,level   ;;;ld      a,(level)           ;;{
   inc     (hl)       ;; inc     a                   ;;   level++
                      ;;;ld      (level),a           ;;}
   ld      ix,bullet           ;;initbullet{
   ld      d,bulletid          ;;
   ld      bc,0                ;;
   ld      hl,0
   CALL_(initspr)              ;;}
   ;;initspr(IX=sprite*,d=idtype,e=empty,bc=extra bytes,hl=videostart)
   ld      ix,player           ;;{initplayer
   ld      d,playerid          ;;
   ld      e,0                 ;;
   ld      bc,0                ;;
   ld      hl,0                ;;
   CALL_(  initspr)            ;;};;;;;initplayer
   ld      ix,monster1        ;{  --|--  ;kill all the monsters
   ld      de,sprsize         ;     |
   ld      b,monsternum       ;     |
clrmonsters:                  ;     |
   ld      (ix+sprmonsth),0   ;     |
   add     ix,de              ;     |
   djnz    clrmonsters        ;}  --|--
gameloop:               ;;;;;;;;;;;Start of gameplay
   CALL_(  display)           ;
   CALL_(  moveplayer)
   ld      hl,frame          ;increment frame counter{
   inc     (hl)                  ;
   ld      a,(hl) ;;(hl)=(frame)
   and     1
   CALL_Z(  movebullet)
   ld      a,(frame)
   and     3       ;;was 1   cp      3
   jr      nz,gameloop        ;}
   ld      a,(frame)
   and     7       ;;;cp      7
   jr      nz,gameloop
   CALL_(  movemonster)       ;
   ld      a,(passarg)          ;; if the PASSARG_RTREE bit is zero then
   bit     PArtreebit,a      ;;    grow a random tree
   CALL_Z(  rndtree)            ;; endif    //aug 1996
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
   CALL_(   dissolve)
   ld       hl,$0001       ;;col,row
   ld       de,byebye
   CALL_(   putstr)
   CALL_(   checkhiscore)
   CALL_(   puthiscorem)
   CALL_(   getyourname)
   CALL_(   wait4enter);
   ;;fill graph screen with exit message
   ld       bc,1024        ;
   ld       DE,GRAPH_MEM   ;
   ld       HL,VIDEO_MEM   ;
   ldir                    ;;;end fill graph screen
   ret

;-------------------------
; functions
;-------------------------

.db 36h ;dummy

#include "actor.asm"
#include "rand.asm"
#include "smisc.asm"

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
   ;;CALL_(  wait4enter)
   ld      hl,$FFFF
   ld      (score),hl
   ld      a,'4'                 ;;init health
   ld      (health),a
   ret
;;;;;;;;end intro


purposestr .db  "You must find this",0


;;;;;showpurpose()
;;;;;alters randvar and loop
showpurpose:
   ;ld      hl,loop
   ;ld      (hl),00100000b
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
puthiscorem:
   ld      hl,$0D06               ;was 07
   ld      (CURSOR_ROW),hl        ;
   ld      hl,(hiscore)           ;
   ROM_CALL(D_HL_DECI)            ;
   ld      hl,$0306               ;was $0307
   ld      de,hiscorestr          ;
   CALL_(  putstr)                ;//end drawing hiscore
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

.db 3Ah ;;dummy

;;;;;;;;;;;;;;;;
;;void stopbullet()
;;destroys a,ix
stopbullet:
   xor     a   ;;;ld      a,0
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
   pop    ix
;;   jr     lookloopend  ;;found a monster dont need to keep looking! need if can hp!=1
nomonstkill:
   ld     de,sprsize
   add    ix,de
   ld     hl,loop      ;;;;;ld     a,(loop)
   dec    (hl)         ;;;;;dec    a
   xor    a            ;;;ld     a,0          ;;;;;ld     (loop),a
   cp     (hl)         ;;;;;cp     0
   JUMP_NZ(lookloop)         ;;end of loop!
   CALL_( putblood)          ;;put blood down,just in case didnt find monsters
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



P_ALPHA =7
P_EXIT  =6
P_2ND   =5
P_F1    =4
P_UP    =3
P_RIGHT =2
P_LEFT  =1
P_DOWN  =0



;;;getKeyPad() returns A=K_*  B=gotten key
getKeyPad:
   xor     a    ;;;ld  a,0             ;;here to end added in aug 96
   out     (1),a
   in      a,(1)
   ld      b,a            ;;b = in keypad port
   xor     a              ;;ld a,k_NOKEY
;;;;;;;;;;;;;;;;key checking starts here!
   bit     P_DOWN,b       ;;check down
   jr      nz,skippdown
   ld      a,K_DOWN
   ld      (pdir),a
skippdown:
   bit     P_UP,b          ;;check up
   jr      nz,skippup
   ld      a,K_UP
   ld      (pdir),a
skippup:
   bit     P_LEFT,b          ;;check left
   jr      nz,skippleft
   ld      a,K_LEFT
   ld      (pdir),a
skippleft:
   bit     P_RIGHT,b        ;;check right
   jr      nz,skippright
   ld      a,K_RIGHT
   ld      (pdir),a
skippright:
   bit     P_ALPHA,b          ;;check alpha
   jr      nz,skippalpha
   ld      a,K_ALPHA
skippalpha:
   bit     P_2ND,b             ;;check 2nd
   jr      nz,skipp2nd
   ld      a,K_SECOND
skipp2nd:
skippf1:      ;;;;;;;;;;;;;;;;;;end keypad code aug 96
   ret
;;;;;;;;;;end getkeypad


;;;;;;;;;docheat()
docheat:
   ld      a,'9'
   ld      (health),a
   CALL_(  dechealth)
   ld      hl,(score)
   srl     l
   srl     h
   dec     hl
   ld      (score),hl
   CALL_(  incscore)
   ret
;;;;;;;;;end docheat



;;;moveplayer
moveplayer:
   ;;;call    GET_KEY
   CALL_(  getKeyPad)
   ;;;;;;;expect A=K_ and b = Padkeys
   bit     P_2ND,b
   jr      z,firebuttonisHit
   bit     P_ALPHA,b
   jr      z,alphaishit
   call    GET_KEY  ;;allow old kind of control to work
firebuttonisHit:
alphaishit:
;gotkey:       ;;;;;;;;;;;;;;;;;;""
;   cp      K_4
;   jr      nz,skip4
;   ld      a,K_1
;skip4:
;   cp      K_2
;   jr      nz,skip2
;   ld      a,K_DOT
;skip2:
;   cp      K_MORE
;   jr      z,SwitchOff
   cp      K_F1
   jr      nz,skippause
   ld      hl,0                      ;;;begin pause code
moreloop:
   inc     hl
   halt
   ld      a,47
   cp      h
   jr      nz,skipoffon
SwitchOff
   ld      hl,0
   di
   ld      a,1
   out     (3),a
   ei
   halt       ;; <after this instruction your calc switches off.
SwitchOn      ;; <The code starts again here..
   ld       a,%1011
   out      (3),a
skipoffon:
   push    hl
   call    GET_KEY
   pop     hl
   cp      K_NOKEY  ;;0
   jr      z,moreloop
   cp      K_MORE
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
   cp      K_COS
   CALL_Z(  docheat)
   ret                   ;;;;;;;;end pause code
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
   ld      hl,playmode
   set     isplayerbit,(hl)
   ld      (pdir),a
   ld      ix,player         ;;//get player
   CALL_(movespr)            ;;//move player
   ld      hl,playmode
   res     isplayerbit,(hl)
   ;;;;;;;;;
   ld      a,(pdir)
;   cp      K_DOWN
;   CALL_Z( scrolldown1) ;;must save af!
;   cp      K_UP
;   CALL_Z( scrollup1)   ;;must save af! ;failed attempt at smooth scroller
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
   ld   ix,(picptr)       ;;keypic
   ld   de,picsize*(keyid & idand)
   add  ix,de
;;;   ld   de,(PROGRAM_ADDR)
;;;   add  ix,de
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
   ld   ix,(picptr)   ;;blankpic  first pic is the blank pic
;;   ld   de,(PROGRAM_ADDR)
;;   add  ix,de
   ld   hl,VIDEO_MEM+894 ;(sprlength*(scrwidth*scrhite-2))
   CALL_(drawspr)
   ret
skipdoor:
   cp      flipid
   jr      nz,skipflipid
   ld      a,playerid
   CALL_(  puthitxy)
   ld      de,(player+sprxyoffhl)  ;;de=player offset
   ld      hl,(hitxy)              ;;hl=flipid offset
   ld      (player+sprxyoffhl),hl  ;;player=flipid offset
   ld      hl,GRAPH_MEM
   add     hl,de
   ld      (hl),flipid             ;;(hl+de)=flipid
   ret
skipflipid:
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


;;;;;;;;scrollup1
scrollup1:
   push    af
   ld      hl,VIDEO_MEM
   ld      (hl),0
   ld      de,VIDEO_MEM+1
   ld      bc,dispwidth
   ldir
   ld      b,sprlength                          ;{ scroll up really fast
scrollclrloop:                                  ; clearing screen
   push    bc                                   ;
      halt
      halt
      halt
      halt
      ld      de,VIDEO_MEM + 1023 - 3                 ;
      ld      hl,VIDEO_MEM + 1023 - scrwidth - 3      ;
      ld      b,63
scrollinnerloop:
      push    bc
         ld      bc,dispwidth                         ;
         lddr
         ld      bc, -3
         ex      de,hl
         add     hl,bc
         ex      de,hl
         add     hl,bc
      pop     bc                                   ;
      djnz scrollinnerloop
   pop     bc                                   ;
   djnz    scrollclrloop                        ;}
   pop     af
   ret
;;;;;;;;;;;end scrollup1






.db 22h ;dummy

;;;void erasehitxy()
;;;destroys: hl,de,a
erasehitxy:
   ld      a,blankid
puthitxy:  ;;a=item put down
   ld      hl,(hitxy)
   ld      de,GRAPH_MEM
   add     hl,de
   ld      (hl),a
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
   and     127   ;;;;;score needed for extra life
   cp      127
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
   ld      de,(player+sprxyoffhl)
   ld      a,d
   inc     a
   and     3
   ld      d,a
   ld      a,r
   add     a,e
   ;CALL_(  rand)                      ;
   ;and     3                          ;
   ;ld      d,a                        ;
   ;CALL_(  rand)                      ;
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
   ;srl     a                          ;
   ;and     $03                   ;health=one to 4 hp
   ;inc     a                          ;
   ;ld      b,a                        ;
   ld      bc,$0101                 ;;monster initial direction
   CALL_(initspr)                     ;
   ret                                ;
;;end initmonster


;;A=doseek() ;returns dir 1-4
doseek:
   ld   de,(player+sprxyoffhl)
   ld   h,(ix+sprxyoffh)
   ld   l,(iy+sprxyoffl)
   or a       ;compare hl,de; clear f
   sbc hl,de  ;set f bits
   ;;add hl,de
   ;;call CP_HL_DE
   jr   c,lessthan
   ;hl greater than de, monster is past! so want up left 4,2
   CALL_( rand) ;;2024 note: i dont think this works right
   srl  a
   srl  a
   and  10b
   or   01b
   inc  a
   ret
lessthan: ;hl<de want 1,3
   CALL_( rand) ;;2024 note: i dont think this works right
   srl  a
   srl  a
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
   xor     a  ;;ld      a,0
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
   ld      hl,randvar
   inc     (hl)
   call    GET_KEY
   or      A  ;;cp      K_NOKEY
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


.db 0F6h ;dummy

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
;.db "c",12,"g",26,"b",73
;.db 0DEh ;dummy

;;;dissolve()
;;;affects: loop!!
dissolve:
   ld   hl,0                ;
   ld   (loop),hl           ;loop=0;
dissolve_loop:              ;do{
   ld   hl,(loop)           ;   *(VIDEO_MEM+loop)=0;
   ld   de,VIDEO_MEM        ;
   add  hl,de               ;
   xor  a ;;;ld   a,00000000h         ;
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
    ld   de,LetterConvertTable
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

LetterConvertTable:         ;For converting keys into letters
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


cantfind  .db  "Do not run directly. ",0
title: .db     "       Scrolls       "
		 .db     "(C)1996   Chris Busch"
		 .db     "2nd=fire   alpha=bomb"
       .db     "arrows=move  f1=pause"
		 .db     "Press a key to start.",0

enteryournamestr .db "Enter initials:",0
gameover: .db    "Game Over!",0
hiscorestr: .db  "High Score:",0
byebye:   .db    "Scrolls - Chris Busch"
		  .db    "shareware:To register"
		  .db    "send me email thank u"
		  .db    "to   "
myname:           .db "cbusch@d.umn.edu",0

newlevel  .db    "New Level!",0

namestr   .db "Scrolls",0
scorestr  .db "Score",0
livesstr  .db "Lives",0




;;#include "pics.asm"


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
	    .db bombid, flipid
       .db bloodid,treeid,brickid,doorid,keyid,wallid

levelmap:
;;   #include "level1.asm"
;;;   #include "level2.asm"

.END
