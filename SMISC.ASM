;;Chris Busch



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
   ld      hl,modebits            ;;aug 1996
   set     newhiscorebit,(hl)     ;;
   ld      hl,(score)
   ld      (hiscore),hl           ;
   ret
;;;;;end checkhiscore

;;end of code