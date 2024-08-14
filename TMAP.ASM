;;;Chris Busch
;;;;;;tmap.asm

#define setplayer(x,y)  .dw actortankn \ .db x,y, 0,0, 8
#define sethouse(x,y)   .dw actorhouse \ .db x,y, 0,0, 5
#define setflag(x,y)    .dw actorflag  \ .db x,y, 0,0, 5
#define setboulder(x,y) .dw actorboulder  \ .db x,y, 0,0, 31
#define setman(x,y)     .dw actorman      \ .db x,y, 1,1, 1
#define setbigman(x,y)  .dw actorbigman   \ .db x,y,-1,-1, 3
#define settwall(x,y)   .dw actortwall    \ .db x,y, 0,0, 63
#define setwwall(x,y)   .dw actorwwall    \ .db x,y, 0,0, 63


level1count  = 10
level1size   = level1count * sprsize
level1map:
   setplayer(  10, 10)  ;1
   sethouse(   50, 10)  ;2
   setflag(    90, 10)  ;3
   setboulder(130, 10)  ;4
   setman(    170, 10)  ;5
   sethouse(  210, 10)  ;6
   setbigman(  10, 50)  ;7
   settwall(   50, 50)  ;8
   setwwall(  100,100)  ;9
   setboulder( 80, 75)  ;10
;;;;end level1map














;;;;;;;;;end tmap.asm
