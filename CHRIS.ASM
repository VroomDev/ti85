
#include "ti-85.h"
;;;;;;
;;text memory
;;;;;;

coord_x         =$80DF                  ;x : current row
coord_y         =$80E0                  ;y : current col
coord_p         =$80E1                  ;p : previous row
coord_q         =$80E2                  ;q : previous col
dummy_1         =$80E3                  ;local variable
score           =$80E4
row1            =$80E5                  ;checker is stored here
row2            =$80E6                  ;labels from "row2" to
row3            =$80E7                  ;"row8" are not necessary
row4            =$80E8                  ;just to remind that
row5            =$80E9                  ;memory has been reserved.
row6            =$80F0
row7            =$80F1
row8            =$80F2

;----------------------------------------------------------------------------
; Title
;----------------------------------------------------------------------------

.org    0
.db     "CTest 0.0",0

;----------------------------------------------------------------------------
; Program start
;----------------------------------------------------------------------------

   ROM_CALL(CLEARLCD)



   ret               ;end game

   .END
