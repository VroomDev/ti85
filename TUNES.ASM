;;Chris Busch
;;WARNING!  Not responsible for any damage this may cause!!!!!!!

;;You may need to get a mini adapter for your headphones.  This can be
;;found at your local electronics store.

;;I have tested it by plugging it into my stereo and that works too.

;;How to run demo:
;;Start zshell, insert headphones, start TUNES.
;;Press GRAPH to play graph data, or press any other key to hear the
;;built in song.

#include "ti-85.h"

.org 0
.db "Tunes v2.0 by CBusch",0

main:
   halt
   call GET_KEY
   cp  0
   jr  z,main

   ld  hl,song
   ld  de,(PROGRAM_ADDR)
   add hl,de   ;hl -> song data

   cp  K_F1
   jr  nz,skipgraph
   ld  hl,GRAPH_MEM  ;hl->graphics
skipgraph:
   CALL_(playsong)
quit:
   ret

#include "tuneslib.asm"

.db "(C) 1996 by Chris Busch"


lowoctive =5
hioctive  =4
                  ;; duration,freq
cnote    = $2870  ;;=112,40
dnote    = $2579  ;; 121,37
enote    = $2284  ;; 132,34
fnote    = $1E96  ;; 150,30
restnote = $0075  ;;  75,0


song:
  .db LegatoOn
  .db hioctive
  .dw enote,dnote,cnote,dnote
  .dw enote,enote,enote
  .dw dnote,dnote,dnote
  .dw enote
  .dw fnote, fnote
;;;  .db restnote
  .dw enote,dnote,cnote,dnote
  .dw enote,enote,enote
  .dw enote
  .dw dnote,dnote
  .dw enote
  .dw dnote,  cnote
  .db StopNote

.END
;;;;
