; TexaNoid version 1.0
;
; Copyright (C) 1995 Magnus Hagander <e95_mha@e.kth.se>
; ALL RIGHTS RESERVED
;
; No modifications of this code is allowed except for
; STRICTLY PERSONAL usage. This means that you can use
; the changed code in your own calculator, but you may
; NOT transfer it to another persons calculator.
; Also, the COPYRIGHT NOTICE MAY NOT BE CHANGED in any
; way.
; If you have made a change that works, or have a suggestion
; of something I should do, just mail me. Don't release
; your own game. Mail me, and I'll fix it up and give
; you the appropriate credit.
; 
; The reason the source to this program is released, is
; for you people out there to LEARN how to program in
; assembly language on the TI-85. I myself don't have
; as much time to develop games and programs any longer,
; so I hereby share some of my knowledge with you.
; In return for that, I REQUIRE that you follow the
; rules stated above. This is STILL MY work, and I
; demand the right to be identified as its author.
; If you cannot agree to this, you are not allowed
; to use this source code.
;
; TexaNoid requires ZShell 4.0 or later, which can be
; found at ftp.rbk.sollentuna.se in /pub/TI-Calc/ti-85/zshell.
; Also, check out the ZShell homepage at 
; http://www.kuai.se/~piett/zshell/
; And don't forget te ZShell fan-page at
; http://www.rbk.sollentuna.se/~mha/zshellfan/
;
;
;
; Sollentuna, Stockholm, Sweden   1995-12-11
; Magnus Hagander <e95_mha@e.kth.se>, <mha@rbk.sollentuna.se>


#INCLUDE "TI-85.H"

TempByte = $80DF                ;Just temporary storage
StringPlace = $80DE             ;Used when writing decimal numbers
;This will fill until 80E5
PaddlePos = $80E5               ;The position of the _CENTER_ of the paddle
SCORE = $80E6  ;Also fills $80E7
LEVEL = $80E8  ;Also fills $80E9
Ball_X = $80EA                  ;The ball's current X position
Ball_Y = $80EB                  ;The ball's current Y position
Y_Direction = $80EC             ;1=Upwards, 2=Downwards
X_Speed = $80ED                 ;The speed in x direction, "number of y's before X changes"
X_Direction = $80EE             ;1=Left, 2=Right
X_TillNext = $80EF              ;Number of y's left...
LIVES = $80F0                   ;Number of lives left
LevelPointer = $80F1
LevelTemp = $80F2   ;80F2,F3,F4,F5,F6,F7,F8,F9,FA,FB
NumHits = $80FC                 ;Number of bricks removed
TotalBricks = $80FD
TempWord = $8102   ;$8103 too
TempByte2 = $8104
TempByte3 = $8105
TempByte4 = $8106
TempByte5 = $8107
RunDirectly = $8108
.org 0
.db "TexaNoid 1.0",0
ProgStart:
   ROM_CALL(CLEARLCD)
   ld   a,3
   ld   (LIVES),a
   ld   a,1
   ld   (levelpointer),a
   ld   hl,1
   ld   (level),hl
;First thing to do, check if we have a saved level
   ld   hl,(PROGRAM_ADDR)
   ld   de,LevelIsSaved
   add  hl,de
   ld   a,(hl)
   or   0
   jr   z,DoTitleScreen
   CALL_(LoadLevel)
   ld   a,1
   ld   (RunDirectly),a
   JUMP_(ReallyGoForIt)         ;Don't decrease level pointer

;Title screen
DoTitleScreen:
   sub  a
   ld   (RunDirectly),a
   ld   hl,$0228                ;X=40,Y=2
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)       ;"TexaNoid x.x"
   ROM_CALL(D_ZM_STR)
   ld   hl,$0A19                ;X=25, Y=10
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,TitleStr1
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   de,$1223                ;X=35, Y=18
   ld   ($8333),de
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,TitleStr2
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT TitleStr2 comes RIGHT AFTER TitleStr1
   ld   de,$1E0F                ;X=15, Y=30
   ld   ($8333),de
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,LevelStr
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT LevelStr comes RIGHT AFTER TitleStr2
   ld   a,55
   ld   ($8333),a
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,LivesStr
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT LivesStr comes RIGHT AFTER LevelStr
   ld   a,90
   ld   ($8333),a
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,HighScoreStr
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT HighScoreStr comes RIGHT AFTER LivesStr
   ld   hl,$260F                ;X=15, Y=38
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,LevelPrompt
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   a,55                ;Prev: 80
   ld   ($8333),a
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,LivesPrompt
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT LivesPrompt comes RIGHT AFTER LevelPrompt
   ld   a,97
   ld   ($8333),a
   .db  $21                     ;ld hl,nnnn
HighScore: .dw 10               ;Self-modifying code, this is standard HS
   CALL_(HL_DECIMAL_MENU)
   ld   hl,$2E0F                ;X=15, Y=46
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,PreviewStr
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   a,95
   ld   ($8333),a
;   ld   hl,(PROGRAM_ADDR)
;   ld   de,ByString
;   add  hl,de
   ROM_CALL(D_ZM_STR)           ;ASSUMES THAT ByString comes RIGHT AFTER PreviewStr
   ld   hl,$3955                ;X=85, Y=57
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,EnterStr
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   hl,$FDB0
   ld   b,16
Title_Line:
   ld   (hl),255
   inc  hl
   djnz Title_Line
UpdateInfoScreen:
   ld   hl,$1E50          ;X=80, Y=39
   ld   ($8333),hl
   ld   a,(lives)
   add  a,'0'
   ROM_CALL(M_CHARPUT)    ;Skriv ut det aktuella livsantalet(?!)
   ld   a,40
   ld   ($8333),a
;   ld   a,30
;   ld   ($8334),a
   ld   a,(LevelPointer)
;   add  a,'0'
;   ROM_CALL(M_CHARPUT)
    CALL_(A_DECIMAL_MENU)

;Here we go - a little "preview" of the selected level...
   ld   hl,leveltable-10            ;Pointer to level information
   ld   de,(PROGRAM_ADDR)
   add  hl,de
   ld   a,(levelpointer)
   ld   b,a
   ld   de,10               ;Each level is 10 bytes...
Title_LevelAdd:
   add  hl,de
   djnz Title_LevelAdd      ;Add to point to next level...
   ;HL now points to level, so it's just go on all systems :-)
;   ld   de,$FC00+16*45+3
   ld   de,$FF52
   ld   b,5
Title_LevelDisplay:
   ld   a,b
   ld   (tempbyte),a
   ldi                      ;Load (DE) with (HL); DE++; HL++; BC--
   ldi                      ;Load (DE) with (HL) again...
   ld   b,14
TItle_LevelLoop1:           ;Stega fram ytterligare 15 steg, till n„sta rad
   inc  de
   djnz Title_LevelLoop1
   ld   a,(tempbyte)
   ld   b,a
   djnz Title_LevelDisplay
TitleKeyLoop:
   CALL Get_Key
   cp   $37
   ret  z                       ;Exit key
   cp   $9
   jr   z,GoForIt               ;Enter, allts† bara att k”ra
   cp   $0A                     ;+
   jr   nz,TitleKeyloop1        ;Inte upp...
   ld   a,(LIVES)
   inc  a
   cp   10
   jr   nz,Up_Ok                ;Mindre „n 10, allts† OK
   ld   a,9                     ;Kan ej bli >9
Up_Ok:
   ld   (LIVES),a
   jr   UpdateInfoScreen        ;Uppdatera med denna info...
TitleKeyLoop1:
   cp   $0B                     ;-
   jr   nz,TitleKeyLoop2
   ld   a,(LIVES)
   dec  a
   jr   nz,Down_Ok              ;>0, allts† OK
   ld   a,1
Down_Ok:
   ld   (LIVES),a
   jr   UpdateInfoScreen
TitleKeyloop2:
   cp   $4                     ;Up
   jr   nz,TitleKeyloop3
   ld   a,(LEVELPOINTER)
   inc  a
   cp   NUMLEVELSINTABLE+1      ;Are we past max?
   jr   nz,Lvl_Up_Ok
   ld   a,NUMLEVELSINTABLE       ;Detta „r maxlevel...
Lvl_Up_ok:
   ld   (LEVELPOINTER),a
   JUMP_(UpdateInfoScreen)
TitleKeyLoop3:
   cp   $1                      ;Down
   jr   nz,TitleKeyLoop         ;Not any of the keys looking for
   ld   a,(LEVELPOINTER)
   dec  a
   jr   nz,Lvl_Down_ok
   ld   a,1
Lvl_Down_ok:
   ld   (LEVELPOINTER),a
   JUMP_(UpdateInfoScreen)

GoForIt:
   ld   hl,levelpointer
   dec  (hl)

ReallyGoForIt:                    ;The user really wanted to play..
   ld   hl,ZS_BITS
   set  0,(hl)              ;Tell ZShell to update me....

   ROM_CALL(CLEARLCD)

;Start the game
   ld   a,4                 ;Set memory page 4 (GFX)
   out  (5),a
   ld   a,(RunDirectly)
   or   0
   jr   z,NormalGo
   CALL_(Do_Draw_Field)    ;Only done when loaded a field
   jr   AnywayGo
NormalGo:                  ;Run only if in save mode
   CALL_(InitiateVars)     ;Only initiate if not in save mode
   CALL_(Draw_Field)
AnywayGo:                  ;Run this not depending on which mode it is
   CALL_(Draw_Paddle)
   CALL_(Draw_Ball)
   CALL_(Wait_Enter)
   jr   KeyLoop1

Paddle_Left:                ;Move paddle left
   ld   a,(Paddlepos)
   cp   8                   ;Are we at maximum left?
   jr   z,AfterKeyCheck     ;Yes, so don't move
   dec  a
   dec  a
   jr   Paddle_Update
Paddle_Right:
   ld   a,(Paddlepos)
   cp   120                 ;Are we at maximum right?
   jr   z,AfterKeyCheck     ;Yes, so don't move
   inc  a
   inc  a
Paddle_Update:
   ld   (tempbyte4),a       ;Store away...
   CALL_(Remove_Paddle)
   ld   a,(tempbyte4)
   ld   (PaddlePos),a
   CALL_(Draw_Paddle)
   jr   AfterKeyCheck

KeyLoop1:
   CALL GET_KEY             ;Get a key...
   cp   $37                 ;Is this exit key?
   JUMP_Z(HighScoreCheck)   ;Check for highscore on leave
   cp   $2                  ;Is this the left key?
   jr   z,Paddle_Left       ;If so, move paddle left...
   cp   $3                  ;Is this the right key?
   jr   z,Paddle_Right      ;If so, move paddle right...
   cp   $36                 ;Is this the 2nd key?
   CALL_Z(Wait_Enter)       ;Enter pause mode :-)
   cp   $38                 ;Is this the MORE key?
   jr   nz,AfterKeyCheck    ;Nope, so do some moving
   CALL_(SaveLevel)         ;Store away the level
   ld   hl,ZS_BITS
   SET  1,(hl)              ;Tell ZShell to warp out...
   ret

AfterKeyCheck:              ;Get here after keys are checked
   ;Now we move the ball...
   CALL_(Remove_Ball)       ;Remove the old ball
   ld   a,(Y_Direction)     ;Check Y direction
   cp   1
   jr   z,Ball_Up
Ball_Down:
   ld   a,(Ball_Y)
   cp   12                  ;Are we passing the paddle?    ---  CHANGE WHEN CHANGING PADDLE THICKNESS
   jr   nz,Ball_Down1
   ;Now check if it hit the paddle...
   ld   a,(Ball_X)
   ld   b,a                 ;X-position to check
   ld   c,9                 ;Check for first nice little line   --- CHANGE WHEN CHANGING PADDLE THICKNESS
   CALL_(Get_Point)         ;Returns ACC=1 if point there, otherwise ACC=0
   or   0
   JUMP_Z(Crash)            ;No point there, meaning outside pad
NoCrash:
   ld   a,1
   ld   (Y_Direction),a     ;Point the other way. Later, also handle X-change
   ld   a,(ball_x)
   ld   c,a
   ld   a,(paddlepos)
   sub  7
   ld   b,7
NoCrash1:
   cp   c
   jr   z,NoCrash_Left
   inc  a
   djnz NoCrash1
   ld   a,(PADDLEPOS)
   ld   b,a
   ld   a,(BALL_X)
   inc  a
   sub  b
   srl  a
   ld   b,a
   ld   a,2
   jr   NoCrash_Move
NoCrash_Left:
   ld   a,(BALL_X)
   ld   b,a
   ld   a,(PADDLEPOS)
   sub  b                       ;a=paddlepos-ballx
   srl  a
   ld   b,a
   ld   a,1
NoCrash_Move:
   ld   (X_Direction),a
   ld   a,4
   sub  b
   ld   (X_Speed),a
   jr   Ball_ProcessX       ;Perform check of how we do it with X-positions
Ball_Down1:
   dec  a                   ;Point one pixel further down
   ld   (Ball_Y),a
   jr   Ball_ProcessX
Ball_Up:
   ld   a,(Ball_Y)
   cp   60
   jr   nz,Ball_Up1
   ld   a,2
   ld   (Y_Direction),a     ;Now it's moving the other way :-)
   jr   Ball_Redraw
Ball_Up1:
   inc  a
   ld   (Ball_Y),a
Ball_ProcessX:
   ld   a,(X_TillNext)
   dec  a
   ld   (X_TillNext),a
   or   0                   ;If this is zero, time to move X
   jr   nz,Ball_Redraw      ;Nothing to do with X direction...
   ld   a,(X_Speed)
   ld   (X_TillNext),a      ;Point for another loop
   ld   a,(X_Direction)     ;Load X direction...
   cp   1
   jr   z,Ball_Left         ;Ok. the ball is heading left
Ball_Right:                 ;Ok. The ball is heading right
   ld   a,(Ball_X)          ;Retreive old position
   cp   125                 ;Maximum X position
   jr   nz,Ball_Right1      ;Just move it...
   ld   a,1
   ld   (X_Direction),a     ;Turn around (jump of edge of display)
   jr   Ball_Redraw         ;Redraw without moving
Ball_Right1:                ;Just move..
   inc  a                   ;Move the ball one pixel...
   ld   (Ball_X),a          ;
   jr   Ball_Redraw         ;Finished with right-move
Ball_Left:                  ;Move the ball left
   ld   a,(Ball_X)          ;Retreive old position
   cp   3                   ;Minimum X position
   jr   nz,Ball_Left1       ;Just move it
   ld   a,2
   ld   (X_Direction),a     ;Turn around (bounce off edge of display)
   jr   Ball_redraw         ;Redraw without moving
Ball_Left1:
   dec  a
   ld   (Ball_X),a
Ball_Redraw:
   ld   a,(BALL_X)
   ld   b,a
   ld   a,(BALL_Y)
   ld   c,a                 ;Check if anything at this point...
   CALL_(Get_Point)
   or   0                   ;Check if nothing there
   jr   nz,HitSomething     ;Nothing there, go on...
   dec  c
   CALL_(Get_Point)
   or   0
   jr   nz,HitSomething
   inc  c
   dec  b
   CALL_(Get_Point)
   or   0
   jr   nz,HitSomething
   inc  b
   inc  b
   CALL_(Get_Point)
   or   0
   jr   nz,HitSomething
   dec  b
   inc  c
   CALL_(get_Point)
   or   0
   jr   nz,HitSomething
   JUMP_(Ball_DoRedraw)

HitSomething:
   ;First we do the bounce-check...
   ld   (tempbyte3),bc
   dec  c                   ;Check if the position above is "to bounce"
   CALL_(Get_Point)
   or   0
   jr   z,Bounce_UpDown     ;Nothing above, so bounce up/down
   inc  c
   inc  c                   ;Check if the position below is "to bounce"
   CALL_(Get_Point)
   or   0
   jr   z,Bounce_UpDown     ;Nothing below, so bounce up/down
   ld   a,(X_Direction)
   cp   1
   jr   nz,Bounce_LeftRight1
   ld   a,2
   ld   (X_Direction),a
   jr   Bounce_Finished
Bounce_LeftRight1:
   ld   a,1
   ld   (X_Direction),a
   jr   Bounce_Finished
Bounce_UpDown:
   ld   a,(Y_Direction)
   cp   1
   jr   nz,Bounce_UpDown1
   ld   a,2
   ld   (tempbyte5),a
   jr   Bounce_Finished
Bounce_UpDown1:
   ld   a,1
   ld   (tempbyte5),a
Bounce_Finished:
   ld   bc,(tempbyte3)
   ;Ok. We hit something black. Now what to do about it??
   srl  b                   ;Divide X-pos by 8, to point correctly
   srl  b
   srl  b                   ;Now we have the true offset in b
   ld   a,63
   sub  c
   ld   c,a                 ;Convert to start at the other end...
   ld   a,b                 ;Store away in ACC
   and  31                  ;Mask...
   ld   (tempByte),a        ;Store the mask away :-)
   ld   b,5                 ;Check for 5 rows...
   ld   a,1                 ;Start by checking row 5
Check1:
   cp   c                   ;Are we @ the first row?
   jr   z,FirstRow
   inc  a
   cp   c
   jr   z,SecondRow
   inc  a
   cp   c
   jr   z,ThirdRow
   inc  a
   cp   c
   jr   z,FourthRow
   add  a,3                   ;Now pointing to next round...
   djnz Check1
   JUMP_(Ball_DoRedraw)       ;Error condition...
FourthRow:
   dec  c
ThirdRow:
   dec  c
SecondRow:
   dec  c
FirstRow:
   ld   d,0
   ld   e,b
   ld   hl,(SCORE)
   add  hl,de
   ld   (SCORE),hl
   ld   hl,$FC00
   ld   b,c                 ;Rows...
   ld   de,16               ;One row advance
Check3:
   add  hl,de
   djnz check3

   ld   d,0
   ld   a,(tempbyte)
   ld   e,a                 ;Now DE contains the row offset
   add  hl,de               ;HL now points to first place...
   ld   de,16               ;One row forward
   sub  a                   ;Place a zero
   ld   b,5                 ;Clear 4 rows...
Check2:
   ld   (hl),a
   add  hl,de               ;Point to next line
   djnz Check2              ;remove it all
   ld   a,(TotalBricks)
   ld   c,a
   ld   a,(NumHits)
   inc  a
   ld   (NumHits),a
   cp   c                 ;Check for end-of-level
   jr   z,Level_Finished
   ld   a,(tempbyte5)
   ld   (Y_Direction),a
   CALL_(Update_Score)
   jr   Ball_DoRedraw
Crash:
   ;Handle the crash...
   ;First of all, flash the screen :)
   ld   b,10
FlashLoop:
   ld   a,0
   out  (2),a
   CALL_(LONG_DELAY)
   ld   a,$1F
   out  (2),a
   CALL_(LONG_DELAY)
   dec  b
   ld   a,b
   or   0
   jr   nz,FlashLoop
   ld   a,(CONTRAST)
   out  (2),a               ;Reset to normal contrast

   ld   hl,$2535        ;X=53,Y=37
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,CrashStr
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   hl,lives
   dec  (hl)
   CALL_(Update_Lives)
   CALL_(Remove_Paddle)
   CALL_(InitiateVars)
   CALL_(Draw_Paddle)
   CALL_(Draw_Ball)
   CALL_(Wait_Enter)
   CALL_(Remove_Ball)
   ld   a,(lives)
   or   0
   JUMP_Z(HighScoreCheck)

Ball_DoRedraw:
   CALL_(Draw_Ball)
   CALL_(Delay)
   JUMP_(KeyLoop1)

Level_Finished:
   sub  a
   ld   (numhits),a
   ld   hl,(score)
   ld   de,50
   add  hl,de
   ld   (score),hl
   CALL_(Update_Score)
   ld   hl,level
   inc  (hl)
   CALL_(Update_Level)
   CALL_(Remove_Paddle)
   CALL_(Remove_Ball)
   CALL_(InitiateVars)
   CALL_(Draw_Paddle)
   CALL_(Draw_Ball)
   CALL_(Draw_Field)
   CALL_(Wait_Enter)
   JUMP_(KeyLoop1)


;----------
;Draw the playing field, as initiated
;----------
Draw_Field:                 ;Draw the playing-field
   ld   hl,leveltable-10       ;Pointer to level information
   ld   de,(PROGRAM_ADDR)
   add  hl,de
   ld   c,0
   ld   a,(levelpointer)
   inc  a
   cp   NumLevelsInTable+1
   jr   nz,LevelContinue
   ld   a,1                 ;Running on first level...
LevelContinue:
   ld   (levelpointer),a
   ld   b,a
   ld   de,10               ;Each level is 10 bytes
LevelAdd:
   add  hl,de
   djnz LevelAdd            ;Add to point to next level...

   ld   de,leveltemp        ;Store over data here...
   ld   bc,10               ;Copy 10 bytes
   ldir                     ; (HL)->(DE), inc DE,HL, dec BC, repeat

Do_Draw_Field:              ;Draw the field in LEVELTEMP
   sub  a                   ;a=0
   ld   c,a
   ld   (totalbricks),a
   ld   ix,LevelTemp
   ld   hl,$FC00+16         ;Video memory
   ld   b,5                 ;5 rows...
DFALL:
   ld   a,b
   ld   (tempbyte4),a
   ld   b,2
DFBITS:
   ld   a,b
   ld   (tempbyte),a
   ld   b,8                 ;8 bits in this word..
   ld   a,(IX)
   ld   (tempbyte2),a
   inc  IX
DFBIT:
   ld   a,(tempbyte2)
   rlca                     ;Next bit into acc :-)
   ld   (tempbyte2),a
   jr   nc,DFNoBit
   ld   (tempword),hl       ;Store away :-)
   ld   de,16
   ld   a,b
   ld   (tempbyte3),a
   ld   b,4
   ld   a,126
DFROW:
   ld   (hl),a
   add  hl,de               ;Point to next row..
   djnz DFROW               ;Place all 4 lines..
   ld   a,(tempbyte3)
   ld   b,a
   ld   hl,totalbricks
   inc  (hl)
   ld   hl,(tempword)
DFNoBit:
   inc  hl                  ;Point to next...
   djnz DFBIT               ;Check next bit...
   ld   a,(tempbyte)
   ld   b,a
   djnz DFBITS
   ld   de,80
   add  hl,de               ;Point to next _BLOCK_
   ld   a,(tempbyte4)
   ld   b,a
   djnz DFALL



;Now place score information etc
   ld   hl,$3A02           ;X=2, Y=58
   ld   ($8333),hl
   ld   de,ScoreStr
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   hl,$3A52            ;X=82, Y=58
   ld   ($8333),hl
   ld   de,LevelStr
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   hl,$3A32            ;X=50, Y=58
   ld   ($8333),hl
   ld   de,LivesStr
   ld   hl,(PROGRAM_ADDR)
   add  hl,de
   ROM_CALL(D_ZM_STR)
   CALL_(Update_Level)
   CALL_(Update_Score)
   CALL_(Update_Lives)
;Place the vertical line
   ld   hl,$FC00+912
   ld   b,16
   ld   a,255
DF3:
   ld   (hl),a
   inc  hl
   DJNZ DF3
   ret

;------
;Update the score information
;------
Update_Score:               ;Update the score information
   ld   hl,$3A1A            ;X=26, Y=58
   ld   ($8333),hl
   ld   hl,(SCORE)
   CALL_(HL_Decimal_Menu)
   ret

;----
; Update the level information
;----
Update_Level:
   ld   hl,$3A69            ;X=105, Y=58
   ld   ($8333),hl
   ld   hl,(LEVEL)
   CALL_(HL_Decimal_Menu)
   ret

;----
; Update the lives information
;----
Update_Lives:
   ld   hl,$3A49        ;X=73, Y=58
   ld   ($8333),hl
   ld   a,(lives)
   add  a,'0'
   ROM_CALL(M_CHARPUT)
   ret
;----
;Draw/Remove the ball from it's current posision
;----
;OBS!!!! OBSERVERA F™LJDEN MED Point_on!!!
Draw_Ball:
   ld   a,1
   jr   Do_Ball
Remove_Ball:
   ld   a,2
Do_Ball:
   ld   (tempbyte3),a
   ld   a,(BALL_Y)
   ld   c,a
   ld   a,(BALL_X)
   ld   b,a
   CALL_(Do_Point)
   inc  b
   CALL_(Do_Point)
   dec  b
   dec  c
   CALL_(Do_Point)
   inc  c
   inc  c
   CALL_(Do_Point)
   dec  c
   dec  b
   CALL_(Do_Point)
   ret
Do_Point:
   ld   a,(tempbyte3)
   cp   1
;   jr   z,DPO1
;   CALL_(Point_Off)
;   ret
;DPO1:
;   CALL_(Point_on)
;   ret
    jr   nz,Point_Off
;    jr   Point_on
;OBS!OBS!OBS! OVANSTENDE F™RUTSŽTTER ATT DESSA TV KOMMER I F™LJD!!!

Point_on:   ;OBS!OBS! Observera f”ljaden med Draw_ball

    push bc
    ROM_CALL(FIND_PIXEL)  ;HL=byte offset in video buffer, A=2^(bit to change)
    ld de, $FC00
	add hl, de
	or (hl)
	ld (hl),a
	pop bc
	ret

Point_off:
    push bc
    ROM_CALL(FIND_PIXEL)
    ld   de,$FC00
    add  hl,de
    xor  255
    and  (hl)
    ld   (hl),a
    pop  bc
    ret
;----
; Draw/Remove the paddle from it's current posision
;----
Draw_Paddle:
   ld   a,1
   jr   Do_Paddle
Remove_Paddle:
   ld   a,2
Do_Paddle:
   ld   (tempbyte3),a
   ld   c,10                ;Y-pos
   ld   a,(Paddlepos)
   sub  7
   ld   b,a
   ld   a,2    ;Make it 2 pixels high
DP2:
   ld   (tempbyte2),a   ;Store away
   ld   a,14   ;Make 14 pixels long
DP1:
   ld   (tempbyte),a
   ld   a,(TempByte3)
   cp   1
   jr   nz,DP4
   CALL_(Point_on)
   jr   DP5
DP4:
   CALL_(Point_off)
DP5:
   ld   a,(tempbyte)
   inc  b      ;Increment X position
   dec  a
   jr   nz,DP1 ;Loop...
   ld   a,b
   sub  14          ;Point back to begining
   ld   b,a
   ld   a,(tempbyte2)
   dec  c
   dec  a
   jr   nz,DP2  ;Loop...
   ret



HighScoreCheck:
   ld   hl,(PROGRAM_ADDR)
   ld   de,HighScore
   add  hl,de
   call LD_HL_MHL               ;HL=(HL), A=L, HL contains old highscore
   ld   de,(SCORE)
   ld   (tempbyte2),de          ;Store away, so it can be used to replace old highscore
   call cp_hl_de                ;Let the ROM to the comparing
   ret  nc                      ;If below or equal, warp away
ThisIsHighscore:                ;ALL RIGHT!
   ROM_CALL(CLEARLCD)           ;Get ready...
   ld   hl,$0501                ;X,Y
   ld   ($800C),hl              ;Text cursor
   ld   hl,(PROGRAM_ADDR)
   ld   de,HighScoreStr
   add  hl,de
   ROM_CALL(D_ZT_STR)
   ld   hl,$1525
   ld   ($8333),hl
   ld   hl,(PROGRAM_ADDR)
   ld   de,InitialsPrompt
   add  hl,de
   ROM_CALL(D_ZM_STR)
   ld   hl,$0805
   ld   ($800C),hl          ;Text cursor position
   ld   hl,(PROGRAM_ADDR)
   ld   de,ScoreHolder
   add  hl,de
   ld   b,3
   ld   c,0
LetterLoop:
   CALL_(GetLetter)
   ld   (hl),a
   inc  hl
   djnz LetterLoop

   ld   hl,(PROGRAM_ADDR)
   ld   de,HighScore
   add  hl,de
   ex   de,hl
   ld   hl,tempbyte2
   ldi
   ldi
   ret


;----
;Display prompt, and wait for Enter keypress
;----
Wait_Enter:
   ld  hl,$1E2E         ;X=46, Y=30
   ld  ($8333),hl
   ld  hl,(PROGRAM_ADDR)
   ld  de,EnterStr
   add hl,de
   ROM_CALL(D_ZM_STR)
Enter_KeyLoop:
   CALL Get_Key
   cp   $9
   jr   nz,Enter_KeyLoop
   ld   hl,$FC00+480
   ld   b,212
Wait_Enter2:
   ld   (hl),0
   inc  hl
   djnz Wait_Enter2
   ret

; -------
; Change HL to decimal and display as menu style
; -------
HL_DECIMAL_MENU:
   ld   de,StringPlace+4
   ld   b,5
ConvLoop:
   call UNPACK_HL
   add  a,'0'
   ld   (de),a
   dec  de
   djnz ConvLoop
   ld   hl,StringPlace
   ROM_CALL(D_ZM_STR)
   ret

A_Decimal_Menu:
   ld   de,StringPlace+4
   ld   b,5
   ld   l,a
   ld   h,0
ConvLoop2:
   call UNPACK_HL
   add  a,'0'
   ld   (de),a
   dec  de
   djnz ConvLoop2
   ld   hl,StringPlace+3
   ROM_CALL(D_ZM_STR)
   ret

Get_point:      ;Returns ACC=0 if not set, otherwise >0
   push bc
   ROM_CALL(FIND_PIXEL)
   ld   de,$FC00
   add  hl,de
   and  (hl)    ;ACC is ACC AND the memory, meaning 0 if not correct...
   pop  bc
   ret

Long_Delay:
    push af
    push bc
    ld   bc,10000
Long_Delay_Loop:
    dec  bc
    ld   a,b
    or   c
    jr   nz,Long_Delay_Loop
    pop  bc
    pop  af
    ret

Delay:

	push af
	push bc
    ld   bc,$1700
DelayLoop:
	dec bc
	ld a, b
	or c
	jr nz, DelayLoop
	pop bc
	pop af
	ret

InitiateVars:
   ld   a,64
   ld   (PaddlePos),a
   ld   (Ball_X),a
   ld   a,1
   ld   (Y_Direction),a
   ld   (X_Direction),a
   inc  a                   ;A now 2
   ld   (X_TillNext),a
   ld   (X_Speed),a
   ld   a,13
   ld   (Ball_Y),a
   ret


;----------------
; GetLetter
; Get a letter (converted)
;----------------
GetLetter:
   push hl
   push bc
   ld   hl,(PROGRAM_ADDR)
   ld   de,LetterConvertTable-1 ;Point to one before, since we always inc once
   add  hl,de                   ;HL now points right
ConvertLoop:
   push hl
   CALL Get_Key                 ;ACC holds key
   pop  hl
   cp   0
   jr   z,ConvertLoop
   push hl                      ;save away...
   ld   b,a
   ld   c,0
ConversionLoop:
   inc  hl
   djnz ConversionLoop          ;After this, we have the correct offset...
   ld   a,(HL)
   pop  hl
   cp   0
   jr   z,ConvertLoop           ;Invalid key

   ROM_CALL(TX_CHARPUT)         ;Show the char
   pop  bc
   pop  hl
   ret                          ;Value is in acc


;----------------
; LoadLevel
; Load a level from the storage into active vars
;----------------
LoadLevel:
   ld   hl,(PROGRAM_ADDR)
   ld   de,LevelIsSaved
   add  hl,de           ;HL now points into the data structure
   sub  a
   ld   (hl),a          ;Set to nothing in the store
   inc  hl
   ld   de,PaddlePos    ;Load address for start of data block
   ld   bc,13+10        ;We're moving 15 bytes, and 10 bytes of level data
   ldir                 ;Load (DE) with (HL), incr DE,HL; decr BC
   ret                  ;All is now restored...

;---------------
; SaveLevel
; Save a level to from acrive vars into the storage
;---------------
SaveLevel:
   CALL_(Remove_Ball)
   ld   hl,(PROGRAM_ADDR)
   ld   de,LevelIsSaved
   add  hl,de
   ld   a,1             ;Inform ourselves there is data in the store
   ld   (hl),a
   inc  hl
   ld   de,PaddlePos
   ex   de,hl
   ld   bc,13
   ldir                 ;That was the EASY part
			;Now fill (HL) with level data.. How ever you do that..
   ex   de,hl
   ld   IX,$FC00+16     ;Start of vid-ram
   ld   de,80           ;Advancement between rows (5*16 (16 bytes per row))
   ld   b,5             ;Checking 5 rows
   ld   c,0             ;for DJNZ to work
SL_ROW:
   push bc
   push de
   CALL_(GetByte)       ;Get one byte starting at (IX), return in B
   CALL_(GetByte)       ;Get second byte on this row
   pop  de
   add  ix,de           ;Point to next row (that is, block row, not pixel row)
   pop  bc
   djnz SL_ROW          ;Do the rest of the rows
   ret

GetByte:
   ld   d,0             ;Working var
   ld   c,0             ;Looping var 1
   ld   b,8             ;8 bit words, right?
GetByteLoop:
   ld   a,(IX)
   or   0
   scf                  ;Set carry
   jr   nz,BitOn        ;The bit is to be set
   ccf                  ;Turn carry off
BitOn:                  ;Bit is now what it is supposed to be
   rl   d               ;Rotate in this bit
   inc  ix              ;Point to next byte on screen
   djnz GetByteLoop     ;Loop through the 8 bits.
   ld   (hl),d          ;Store away
   inc  hl              ;Point to next part
   ret

TitleStr1: .db "(C) 95 Magnus Hagander",0
TitleStr2: .db "e95_mha@e.kth.se",0
LevelStr: .db "Level:",0
LivesStr: .db "Lives:",0
HighScoreStr: .db "High"
ScoreStr: .db "Score:",0
CrashStr: .db "Crash",0
EnterStr: .db "Press Enter",0
LevelPrompt: .db 6,"/",7,0    ;Pil upp, pil ner
LivesPrompt: .db "+/-",0      ;Knappar att trycka...
InitialsPrompt: .db "Enter initials",0

LevelIsSaved: .db 0           ; Om <>0, s† finns det ett level sparat
Saved_PaddlePos: .db 0        ; (PaddlePos), om sparad
Saved_Score: .dw 0            ; (SCORE), om sparad
Saved_Level: .dw 0            ; (LEVEL), om sparad
Saved_BallStat: .dw 0,0,0     ; (BallX) through (X_TillNext)
Saved_FinalBlock: .db 0,0   ; (LIVES) through (LEVEL_POINTER)
SavedLevelData: .db 0,0,0,0,0,0,0,0,0,0  ;What's left of the level...

PreviewStr: .db "Preview:",0
ByString: .db "by  "
ScoreHolder: .db "MHA"      ;Initials of score-holder
			    ;HAS TO BE FOLLOWED BY A .DB 0!!!!
LetterConvertTable:         ;For converting keys into letters
   .db 0,0,0,0,0,0,0,0,0    ;00-09 - not valid
   .db 'X,'T','O','J','E'   ;0A-0E - valid
   .db 0,0                  ;0F-10 - not valid
   .db ' ','W','S','N','I'  ;11-15 - valid
   .db 'D'                  ;16    - valid
   .db 0,0                  ;17-18 - not valid
   .db 'Z','V','R','M','H','C';19-1E- valid
   .db 0,0                  ;1F-20 - not valid
   .db 'Y','U','Q','L','G','B';21-26 - valid
   .db 0,0,0,0              ;27-2A - not valid
   .db 'P','K','F','A'      ;2B-2E - valid
   .db 0,0,0,0,0,0,0,0,0,0  ;Rest  - not valid

NumLevelsInTable = 13
LevelTable:
	    .db 255,255,0,0,255,255,0,0,255,255       ;Three lines, horizontal
	    .db 231,57,206,115,156,231,57,206,115,156 ;Dashes
	    .db 238,39,68,84,69,38,68,81,78,38        ;"TI-85"
	    .db $07,$E0,$1D,$B8,$37,$EC,$1C,$38,$7,$E0;Smiley
	    .db 132,33,206,115,255,255,206,115,132,33 ;Diamonds
	    .db 138,38,218,41,171,239,138,41,138,41   ;"MHA"
	    .db $14,$28,$3E,$7C,$3E,$7C,$1C,$38,$08,$10 ;Hearts
	    .db 12,48,146,73,109,182,146,73,97,134    ;"sine"
	    .db $87,$E1,$3C,$3C,$70,$0E,$C0,$3,0,0    ;Strange?!?!
	    .db 170,170,85,85,170,170,85,85,170,170   ;Dotted mass
	    .db $3F,$C0,$20,$40,$20,$A0,$20,$40,$78,$A0 ; Hangman
	    .db 170,170,255,255,170,170,170,170,170,170 ; "fence"?
	    .db 0,0,255,255,255,255,255,255,255,255   ;Solid field

.end
