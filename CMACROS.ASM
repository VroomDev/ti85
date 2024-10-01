;;Chris Busch
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
fallingbit     = 5
fallingand     = 00100000b

;;;;;;ids
blankid      =0
playerid     =1 | noeraseand
monster1id   =2 | noeraseand | killableand
monster2id   =3 | noeraseand | killableand
monsters     =4  ;<= a bullet will not put blood on it unless monster
coinid       =4                             | fallingand
scrollid     =5 | noeraseand
fireid       =6 | noeraseand
bombid       =7              | killableand  | fallingand
animators    =8       ;;must be less than animators to animate!!
bulletid     =8 | noeraseand
bloodid      =9                             | fallingand
treeid       =10 | noeraseand | killableand | fallingand
brickid      =11 | noeraseand
wallid       =11 | noeraseand | killableand
fwallid      =11 | noeraseand               | fallingand
doorid       =12 | noeraseand               | fallingand
keyid        =13 | noeraseand


;;;monster move types
seekbit     =0   ;;else patroller
picnum     =14
picsize    =8
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

monsternum        =20  ;16

levelptr        =TEXT_MEM
levelnumand     =levelptr+2
picptr          =levelnumand+1
passarg         =picptr+2   ;;passarg is there in case I may want to pass args??
player          =passarg+1
monster1        =player+sprsize
firstlvlmonst   =monster1+(sprsize*5)    ;5 
secondlvlmonst  =monster1+(sprsize*10)   ;10
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
jumpptr         =playmode+1
blockspot       =jumpptr+1
modebits        =blockspot+2
lastvar         =modebits+1
;;;;;;;;;;;;total=??
endoftext       =$8186
#if ( lastvar >= endoftext)
      ; generate an invalid statement to cause an error
      ;  when we go over the text boundary.
	  !!! text area bounds exceeded.
#endif


;;;;;;;;;;;;;text memory 2
firstname       =TEXT_MEM2
midname         =firstname+1
lastname        =midname+1
zero            =lastname+1
lastvar2        =zero+1

endoftext2       =TEXT_MEM2 + 160
#if ( lastvar2 >= endoftext2)
      ; generate an invalid statement to cause an error
      ;  when we go over the text boundary.
	  !!! text2 area bounds exceeded.
#endif
;;;;;;;;;;;end text memory 2


;;;;;;modebits:
newhiscorebit =3        ;;used to indicate a new hi score

;playmode bits
isplayerbit  =2          ;;used only in domove kinda a HACK!
haskeybit    =1
hasscrollbit =0


