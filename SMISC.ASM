;;Chris Busch

;;shared code between caves and scrolls engines

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


;;;;;;;;;;showmap
;;;;uses what is in graph memory to make a single pixel per byte
;;;;map in the upper left hand corner of display screen
showmap:
    ld  DE,GRAPH_MEM+(10*32)+13 ;source
    ld  HL,VIDEO_MEM ;dest
    ld b,32 ;rows
process_rows:
    push bc             ;push rows
    ld b,4              ;cols 4*8=32 columns
process_cols:
    push bc             ;push columns
    ld c,0
    ld b,8              ;process 8 bytes at a time
process_byte:
    ld a,(de)           ;examine a map byte
    inc de
    push hl
    ld hl,GRAPH_MEM+(32*32)
    call CP_HL_DE
    jr nz,nomodulo
    ld de,GRAPH_MEM     ;modulo arond
nomodulo:
    pop hl
    rl c                ;rotate left thru carry into c
    res 0,c             ;if 0 char or killableand then need to have 0 pixel
    or a
    jr z,skip_setpix  ;it is zero leave it off
    and killableand
    or a
    jr nz,skip_setpix   ;it is killable so leave it off
    set 0,c
skip_setpix:
    djnz process_byte   ;dec b until 0
    ld a,c
    ld (hl),a           ;store 8 pixels
    inc hl              ;adv dest
    pop bc              ;cols
    djnz process_cols
    ld bc,12
    add hl,bc           ;newline of pixels
    pop bc              ;pop rows
    djnz process_rows
    ret ;end of function

;;;;;;;showmap2
;;;;;;;will rename to tourmap
;;;;;;;will have this do getkey and use cursor keys
;;;;;;;this shows the map to the user
tourMap:
      ld      hl,(player+sprxyoffhl)
      ld      de,-(levelwidth*4)-(dispwidth/2)
      add     hl,de    ;;;hl->map data offset
showmapmore:
      ld      a,h
      and     3
      ld      h,a
      push hl
      CALL_(refresh)
      halt
      ;DEBUG16(hl)
      call GET_KEY
      pop hl
      cp K_UP
      jr nz,notupkey
      ld bc,-32
      add hl,bc
      jr showmapmore
notupkey:
      cp K_DOWN
      jr nz,notdownkey
      ld bc,32
      add hl,bc
      jr showmapmore
notdownkey:
      cp K_LEFT
      jr nz,notleftkey
      dec hl
      jr showmapmore
notleftkey:
      cp K_RIGHT
      jr nz,notrightkey
      inc hl
      jr showmapmore
notrightkey:
      cp K_CLEAR
      ret z
      cp K_EXIT
      ret z
      jr showmapmore
      ;;end of function


;;end of code
