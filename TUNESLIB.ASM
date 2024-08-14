;;Chris Busch
;;cbusch@d.umn.edu  (address will be stale after may 96)
;;tuneslib.asm     copyright (c)1996
;;version 1.0
;;Allows ti-85 zshell programs to play songs or sound effects.
;;To use playsong(hl->song) just do #include "tuneslib.asm" in your zshell
;;program.  There is no reason to change anything in this file.
;;This code is freeware, the only restrictions are if you use this code,
;;please send me a copy of your game (so I can play it too!) and give
;;me credit where credit is do in your .doc file.

#ifndef TUNESLIB_ASM
#define TUNESLIB_ASM

;;how to call playsong:
;;   ld de,(PROGRAM_ADDR)
;;   ld hl,yoursong
;;   add hl,de
;;   CALL_(playsong)

;;If you wish to have a different key to exit the playsong function, do:
;;#define EXITBIT the_port1_bit_of_the_key_you_want

;;The format of songs are:

;; playmode, octive, duration,frequency,  duration,frequency ...
;;None of the above numbers are true.

;;valid playmodes are:
#define LegatoOn  00000000b
#define LegatoOff 00000001b
;;Legato On means there is a slight pause between notes.

;;Octive:  This number specifies the innermost delay.  It can be
;;use to raise or lower the whole pitch of the song.  Lower number
;;higher pitch.

;;Duration: This number specifies the duration of the note.  Its the
;;outer most loop.
;;Use a duration of zero to indicate the end of the song.

;;Frequency:  This is not the true frequency.  The lower the number the
;;higher the frequency.  Use a frequency of 0 to indicate a rest.

;;To have your notes be the same length, make sure that duration*frequency
;;is a constant number (or close to it).

;;WARNING!  Not responsible for any damage this may cause!!!!!!!
#define StopNote 0

#ifndef EXITBIT
EXITBIT    =6
#endif
LEGATOBIT  =0  ;;if bit true then no delay between notes

;;void playsong(hl->song)
;;where data= playbits, delay, count,freqd, count,freqd...
;;used:  a,b=looper, c=currentport,d=delay,e=playbits,hl->data
playsong:
    di
playnokey:     ;;dont want any keys pressed when start
      xor     a
      out     (1),a
      in      a,(1)
      cp      255 ;;;bit     EXITBIT,a   ;;is the exit keypressed??
      jr      nz,playnokey
    ld   a,$C0
    ld   c,a
    out  (7),a
    ld   e,(hl)  ;;play bits
    inc  hl
    ld   d,(hl)  ;;load the delay
playloop:
    inc  hl
    ld   a,(hl)  ;;get the count
    ld   b,a
    cp   0
    jr   z,doneplay
    inc  hl
    ;;;test for legato
    bit  LEGATOBIT,e
    jr   nz,skiplegato
    push bc    ;;legato
    ld   b,0
legatoloop:
    nop  \ nop
    djnz legatoloop
    pop  bc    ;;legato
skiplegato:
countloop:
    ld  a,(hl)   ;;get the freq delay
    cp  0
    jr  z,thenREST  ;;if the freqd is 0 then rest the speaker
    ;TOGGLE sound
    ld   a,c
    xor  00111100b  ;toggles those bits on and off
    out  (7),a
    ld   c,a
thenREST:
    push bc
     ld  b,(hl)
freqdloop:
     push  bc
      ld  b,d    ;;load the delay
delayloop:
      xor     a
      out     (1),a
      in      a,(1)
      cp      255 ;;;bit     EXITBIT,a   ;;is the exit keypressed??
      jr      z,noquitplay
     pop  bc
    pop  bc
    jr  doneplay
noquitplay:
      djnz delayloop
     pop   bc
     djnz freqdloop
    pop   bc
    djnz countloop
    jr   playloop
doneplay:
    ld  a,$C0
    out (7),a    ;output 1 1 ;;make sure this is the last to be outputted!
    ei
    ret

#endif ;;TUNESLIB_ASM
;;end of file