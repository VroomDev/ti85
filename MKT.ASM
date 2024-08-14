; -------------- Multi Key Test ----------------
;   (c) PASCAL BOURON , bouron@ens-cachan.fr
; ----------------------------------------------
;
; For several games, ( 2 players game , game
; with 8 directions move, or fire with movement)
; you must test if two (or plus) key is pressed
; So I have do this small example for show how
; you can do that. I test also if a byte is
; receive in the link port ( If you want do
; a game with 4 players (2 TI))
;
; I test exit,F1,F2,F3,F4,F5
;
; To quit press exit or send a $00 in the link port
;
;
; If you have questions or suggestions e-mail me.
;
#INCLUDE "TI-85.H"
;-------------------------------------------
; Program data stored in text memory (80DF)
;-------------------------------------------
x        =$80DF
error_nb =$80E0
bit      =$80E1
counter  =$80E2
last     =$80E3
;---------------------------------------------
; Program Title
;---------------------------------------------

.org 0
.db " Multi-Key Test by BP",0


  ROM_CALL(CLEARLCD)
  ld    de,(PROGRAM_ADDR)
  ld    hl,Titre
  add   hl,de
  ROM_CALL(D_ZT_STR)
;
key_loop1:
  call GET_KEY            ; Classic call ...
  or    a                 ; set flag
  jr    z, key_loop1
        DI
  cp    $37               ; Exit pressed ?
  jr    nz,no_key

;-======================-
;        Exit
;-======================-
exit:
        EI
  RET
;------------------------


no_key:
        ROM_CALL(CLEARLCD)
wait_key:
  CALL_(Read_byte)
  ld a,(error_nb)
  cp   1
  jr z,next2
  ld   a,(x)

;----------------------------------------------------
; You can do some actions with the value
; of the received byte .
; Here , if it's a $00 : exit
;
; Put your different test here :
;       cp   value
;       jr   z, routine
  cp   0
  jr   z, exit
;
;
;
;
;
;
;---------------------------------------------------
next2:
  ld   hl,$0000
  ld   (CURSOR_ROW),hl
  ld   a,$BF              ; $BF = 1011 1111b
  out (1),a
  in a,(1)                ;
  cp $ff                  ; A key is pressed  ?
  jr z,no_key             ;

;Bit 6
        in a,(1)
  bit 6,a                 ; bit 6 => EXIT
  jr  z,exit

       ld  b,a
       ld  a,(last)
       cp  b
       jr z,wait_key
       ROM_CALL(CLEARLCD)
       ld a,b
       ld (last),a

;Bit 7
  in a,(1)
  bit 7,a                 ; bit 7 => MORE
  CALL_Z(kp_more)



;Bit 5
  in a,(1)
  bit 5,a                 ; bit 5 => 2NDE
  CALL_Z(kp_2nd)

;Bit 4
  in a,(1)
  bit 4,a                 ; bit 4 => F1
  CALL_Z(kp_f1)

;Bit 3
  in a,(1)
  bit 3,a                 ; bit 3 => F2
  CALL_Z(kp_f2)

;Bit 2
  in a,(1)
  bit 2,a                 ; bit 2 => F3
  CALL_Z(kp_f3)

;Bit 1
  in a,(1)
  bit 1,a                 ; bit 1 => F4
  CALL_Z(kp_f4)

;Bit 0
  in a,(1)
  bit 0,a                 ; bit 0 => F5
  CALL_Z(kp_f5)

; -------------- end of the tests --------
bit_end:
  JUMP_(wait_key)


;-==============================================-
;                   ACTIONS
;-==============================================-
kp_more :
        ld    a,0
  ld   (CURSOR_ROW),a
        ld    a,0
  ld   (CURSOR_COL),a
  ld    de,(PROGRAM_ADDR)
  ld    hl,data
  add   hl,de
  ROM_CALL(D_ZT_STR)
  ret
kp_2nd :
        ld    a,1
  ld   (CURSOR_ROW),a
        ld    a,0
  ld   (CURSOR_COL),a
        ld    hl,8
  ld    de,(PROGRAM_ADDR)
        add   hl,de
  ld    de,data
  add   hl,de
  ROM_CALL(D_ZT_STR)
  ret
kp_f1 :
        ld  l,$10
        jr  kp_f
kp_f2 :
        ld  l,$14
        jr  kp_f
kp_f3 :
        ld  l,$18
        jr  kp_f
kp_f4 :
        ld  l,$1C
        jr  kp_f
kp_f5 :
        ld  l,$20
kp_f:
        ld  a,l
        sub $10
        rr  a
        rr  a
        and $7
        add a,3
  ld   (CURSOR_ROW),a
        ld    a,0
  ld   (CURSOR_COL),a
        ld  h,0
  ld    de,(PROGRAM_ADDR)
        add   hl,de
  ld    de,data
  add   hl,de
  ROM_CALL(D_ZT_STR)
  ret

data:
.db     "MORE   ",0
.db     "2 nde  ",0
.db     "F1 ",0
.db     "F2 ",0
.db     "F3 ",0
.db     "F4 ",0
.db     "F5 ",0

;-===========================================-
;            Read_byte
;-===========================================-
; INPUT   : no
; OUTPUT  :(x)          =Read byte value
;          (error_nb)   =# of the error
; MODIFIED:(bit)
;          (counter)

Read_byte:
    push af
    push bc
    push de
    push hl
    ld    a,1       ; for the OR
    ld    (bit),a
    ld    a,0       ; byte receive
    ld    (x),a
    ld    a,8       ; counter
    ld (counter),a
    ld    a,$C0
    out   (7),a
rb_Loop_wait_1st_bit:
    jr rb_Loop_wait_bit
rb_Loop_wait_bit2:
    ld a,b
    ld (counter),a
rb_Loop_wait_bit:
    ld      d,$10   ; timer
rb_w_Start:
    in    a,(7)
    and 3
    cp  3
    jr    nz,rb_get_bit
    CALL_(rb_delay)
    dec   d                 ;d=0 => erreur
    jr    nz,rb_w_Start     ;Attend le un bit
    ld    a,1
    jr    rb_error
rb_Loop_tmp:
    jr rb_Loop_wait_bit2
rb_get_bit:
    cp    2
    jr    z,rb_receive_zero
    ld    a,(bit)
    ld    e,a
    ld    a,(x)
    or    e
    ld    (x),a
    ld    a,$D4
    out   (7),a
    ld      d,$10
rb_wait_Stop1:
    in    a,(7)
    and 2
    cp  2
    jr    z,rb_suite_receive
    CALL_(rb_delay)
    dec   d
    jr    nz,rb_wait_Stop1
              ; If error ...
    ld    a,2
rb_error:
    ld (error_nb),a
    ld    a,$C0
    out   (7),a
    jr rb_fin

rb_receive_zero:
    ld    a,$E8
    out   (7),a
    ld      d,$10
rb_wait_Stop0:
    in    a,(7)
    and 1
    cp  1
    jr    z,rb_suite_receive
    CALL_(rb_delay)
    dec   d
    jr    nz,rb_wait_Stop0
          ; If error ...
    ld a,3
    jr rb_error

rb_suite_receive:
    ld a,$c0
    out   (7),a
    ld    a,(bit)
    add   a,a
    ld    (bit),a
    ld a,(counter)
    ld b,a
    djnz    rb_Loop_tmp
    ld      a,$FF                   ; No error
    ld      (error_nb),a
rb_fin:
    pop hl
    pop de
    pop bc
    pop af
    ret


;
;   DELAY
;
rb_delay:
  push af
  push bc
       ld bc, $80
rb_delayLoop:
       dec bc
       ld a, b
       or c
       jr nz, rb_delayLoop
  pop bc
  pop af
  ret


Titre:
.db    "                     "
.db    "    Multi Key Test   "
.db    " (c) Pascal Bouron   "
.db    "                     "
.db    " Press a key,then :  "
.db    "Try F1 F2 F3 F4 F5   "
.db    "    2nd and more.",0

.END

