;;;;Chris Busch

collidecheckand = 10000000b  ;;set if care about collisions
shootableand    = 00000000b  ;;set if it can be shot ** ignore this**
pushableand     = 00100000b  ;;set if it can be pushed



;;pbm converter
;;picture 'flag.pbm'
flagtype  =7 | shootableand
actorflag:
   .db flagtype   ;type
   .db 9,2,14 ;xsize,xbytes,ylines
   .db 00011111b, 10000000b
   .db 00010101b, 10000000b
   .db 00011111b, 10000000b
   .db 00011010b, 10000000b
   .db 00011111b, 10000000b
   .db 00010000b, 00000000b
   .db 00010000b, 00000000b
   .db 00010000b, 00000000b
   .db 00010000b, 00000000b
   .db 00010000b, 00000000b
   .db 00010000b, 00000000b
   .db 00111000b, 00000000b
   .db 01010100b, 00000000b
   .db 10101010b, 00000000b
;;end 'flag.pbm'
;;picture 'man.pbm'
mantype  =1 | collidecheckand | shootableand
actorman:
   .db mantype   ;type
   .db 5,1,8 ;xsize,xbytes,ylines
   .db 01110000b
   .db 01110000b
   .db 00100000b
   .db 11111000b
   .db 00100000b
   .db 01110000b
   .db 01010000b
   .db 11011000b
;;end 'man.pbm'
;;picture 'house.pbm'
housetype  =2 | shootableand
actorhouse:
   .db housetype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000011b, 11000000b
   .db 00000111b, 11100000b
   .db 00001110b, 01110000b
   .db 00011100b, 00111000b
   .db 00111000b, 00011100b
   .db 01110000b, 00001110b
   .db 11100000b, 00000111b
   .db 11000000b, 00000011b
   .db 01011110b, 11110010b
   .db 01010010b, 10010010b
   .db 01010010b, 10010010b
   .db 01011110b, 10010010b
   .db 01000000b, 10010010b
   .db 01000000b, 10010010b
   .db 01111111b, 10011110b
   .db 01111111b, 11111110b
;;end 'house.pbm'
;;picture 'boulder.pbm'
bouldertype  =3 | collidecheckand | pushableand
actorboulder:
   .db bouldertype   ;type
   .db 8,1,8 ;xsize,xbytes,ylines
   .db 01111100b
   .db 11101110b
   .db 10110111b
   .db 11111101b
   .db 10101011b
   .db 11011111b
   .db 01110110b
   .db 00111100b
;;end 'boulder.pbm'
;;picture 'bigman.pbm'
bigmantype  =4  | collidecheckand | shootableand
actorbigman:
   .db bigmantype   ;type
   .db 5,1,10 ;xsize,xbytes,ylines
   .db 01110000b
   .db 11111000b
   .db 01110000b
   .db 01110000b
   .db 00100000b
   .db 11111000b
   .db 00100000b
   .db 01110000b
   .db 01010000b
   .db 11011000b
;;end 'bigman.pbm'
;;picture 'wwall.pbm'
wwalltype  =5
actorwwall:
   .db wwalltype   ;type
   .db 32,4,8 ;xsize,xbytes,ylines
   .db 11111111b, 11111111b, 11111111b, 11111111b
   .db 10000010b, 00010000b, 10000100b, 00100001b
   .db 11111111b, 11111111b, 11111111b, 11111111b
   .db 10010000b, 10000100b, 00100001b, 00001001b
   .db 10010000b, 10000100b, 00100001b, 00001001b
   .db 11111111b, 11111111b, 11111111b, 11111111b
   .db 10000010b, 00010000b, 10000100b, 00100001b
   .db 11111111b, 11111111b, 11111111b, 11111111b
;;end 'wwall.pbm'
;;picture 'twall.pbm'
twalltype  =wwalltype
actortwall:
   .db twalltype   ;type
   .db 8,1,32 ;xsize,xbytes,ylines
   .db 11111111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 11100111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 11100111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 11100111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 11100111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 11100111b
   .db 10100101b
   .db 10100101b
   .db 10111101b
   .db 10100101b
   .db 10100101b
   .db 11111111b
;;end 'twall.pbm'
;;picture 'tankn.pbm'
playerwidth =16
playerhite  =16
tankntype  =6 | collidecheckand
playertype =tankntype
actortankn:
   .db tankntype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000011b, 11000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 11000011b, 11000011b
   .db 11001111b, 11110011b
   .db 11011110b, 01111011b
   .db 11111101b, 10111111b
   .db 11111010b, 01011111b
   .db 11110101b, 10101111b
   .db 11111010b, 01011111b
   .db 11011111b, 11111011b
   .db 11001111b, 11110011b
   .db 11000011b, 11000011b
;;end 'tankn.pbm'
;;picture 'tankne.pbm'
tanknetype  = tankntype
actortankne:
   .db tanknetype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000110b, 00000110b
   .db 00001110b, 00000111b
   .db 00011100b, 00001111b
   .db 00111111b, 00011100b
   .db 01111111b, 11111000b
   .db 11111111b, 10110000b
   .db 11011010b, 11010000b
   .db 00011111b, 01110000b
   .db 00001101b, 10111000b
   .db 00001110b, 11111011b
   .db 00001111b, 10111111b
   .db 00000111b, 11111110b
   .db 00000000b, 11111100b
   .db 00000000b, 00111000b
   .db 00000000b, 01110000b
   .db 00000000b, 01100000b
;;end 'tankne.pbm'
;;picture 'tanke.pbm'
tanketype  =tankntype
actortanke:
   .db tanketype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 11111111b, 11000000b
   .db 11111111b, 11000000b
   .db 00011110b, 00000000b
   .db 00111111b, 00000000b
   .db 01110111b, 10000000b
   .db 01101011b, 10000000b
   .db 11110101b, 11000001b
   .db 11101010b, 11111111b
   .db 11101010b, 11111111b
   .db 11110101b, 11000001b
   .db 01101011b, 10000000b
   .db 01110111b, 10000000b
   .db 00111111b, 00000000b
   .db 00011110b, 00000000b
   .db 11111111b, 11000000b
   .db 11111111b, 11000000b
;;end 'tanke.pbm'
;;picture 'tankse.pbm'
tanksetype  =tankntype
actortankse:
   .db tanksetype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000000b, 01100000b
   .db 00000000b, 01110000b
   .db 00000000b, 00111000b
   .db 00000000b, 11111100b
   .db 00000111b, 11111110b
   .db 00001111b, 10111111b
   .db 00001110b, 11111011b
   .db 00001101b, 10111000b
   .db 00011111b, 01110000b
   .db 11011010b, 11010000b
   .db 11111111b, 10110000b
   .db 01111111b, 11111000b
   .db 00111111b, 00011100b
   .db 00011100b, 00001111b
   .db 00001110b, 00000111b
   .db 00000110b, 00000110b
;;end 'tankse.pbm'
;;picture 'tanks.pbm'
tankstype  =tankntype
actortanks:
   .db tankstype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 11000011b, 11000011b
   .db 11001111b, 11110011b
   .db 11011111b, 11111011b
   .db 11111010b, 01011111b
   .db 11110101b, 10101111b
   .db 11111010b, 01011111b
   .db 11111101b, 10111111b
   .db 11011110b, 01111011b
   .db 11001111b, 11110011b
   .db 11000011b, 11000011b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000001b, 10000000b
   .db 00000011b, 11000000b
;;end 'tanks.pbm'
;;picture 'tanksw.pbm'
tankswtype  =tankntype
actortanksw:
   .db tankswtype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000110b, 00000000b
   .db 00001110b, 00000000b
   .db 00011100b, 00000000b
   .db 00111111b, 00000000b
   .db 01111111b, 11100000b
   .db 11111101b, 11110000b
   .db 11011111b, 01110000b
   .db 00011101b, 10110000b
   .db 00001110b, 11111000b
   .db 00001011b, 01011011b
   .db 00001101b, 11111111b
   .db 00011111b, 11111110b
   .db 00111000b, 11111100b
   .db 11110000b, 00111000b
   .db 11100000b, 01110000b
   .db 01100000b, 01100000b
;;end 'tanksw.pbm'
;;picture 'tankw.pbm'
tankwtype  =tankntype
actortankw:
   .db tankwtype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 00000011b, 11111111b
   .db 00000011b, 11111111b
   .db 00000000b, 01111000b
   .db 00000000b, 11111100b
   .db 00000001b, 11101110b
   .db 00000001b, 11010110b
   .db 10000011b, 10101111b
   .db 11111111b, 01010111b
   .db 11111111b, 01010111b
   .db 10000011b, 10101111b
   .db 00000001b, 11010110b
   .db 00000001b, 11101110b
   .db 00000000b, 11111100b
   .db 00000000b, 01111000b
   .db 00000011b, 11111111b
   .db 00000011b, 11111111b
;;end 'tankw.pbm'
;;picture 'tanknw.pbm'
tanknwtype  =tankntype
actortanknw:
   .db tanknwtype   ;type
   .db 16,2,16 ;xsize,xbytes,ylines
   .db 01100000b, 01100000b
   .db 11100000b, 01110000b
   .db 11110000b, 00111000b
   .db 00111000b, 11111100b
   .db 00011111b, 11111110b
   .db 00001101b, 11111111b
   .db 00001011b, 01011011b
   .db 00001110b, 11111000b
   .db 00011101b, 10110000b
   .db 11011111b, 01110000b
   .db 11111101b, 11110000b
   .db 01111111b, 11100000b
   .db 00111111b, 00000000b
   .db 00011100b, 00000000b
   .db 00001110b, 00000000b
   .db 00000110b, 00000000b
;;end 'tanknw.pbm'
;;end pbm converter
