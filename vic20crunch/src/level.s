;; Level load — maps packed from reference/CRUNCH.ASM at build

.include "game.inc"

.export load_level
.export player_sx
.export player_sy
.export monster_sx
.export monster_sy
.export level
.export score
.export health
.export hiscore
.export coinsleft
.export randvar

.import map_clear
.import playfield

;; packed map codes
MP_EMPTY        = 0
MP_TREE         = 1
MP_BRICK        = 2
MP_COIN         = 3
MP_PLAYER       = 4
MP_MONSTER      = 5

.segment "BSS"
level:          .res 1
score:          .res 2          ; BCD, low byte first (0000–9999)
health:         .res 1
hiscore:        .res 2
coinsleft:      .res 1
randvar:        .res 1
player_sx:      .res 1
player_sy:      .res 1
monster_sx:     .res 1
monster_sy:     .res 1
load_x:         .res 1
load_y:         .res 1

.segment "ZEROPAGE"
map_ptr:        .res 2

.segment "BSS"
pair:           .res 1
nibble:         .res 1

.segment "CODE"

;; A = 1-based level. Map is ((A-1) & 7). Packs at $1C00.
load_level:
        sec
        sbc #1
        and #LEVEL_AND
        sta map_ptr
        lda #0
        sta map_ptr+1
        ldx #6
:       asl map_ptr
        rol map_ptr+1
        dex
        bne :-
        clc
        lda map_ptr
        adc #<maps
        sta map_ptr
        lda map_ptr+1
        adc #>maps
        sta map_ptr+1

        jsr map_clear
        lda #0
        sta coinsleft
        sta load_x
        sta load_y
        sta nibble
        lda #8
        sta player_sx
        lda #4
        sta player_sy
        sta monster_sx
        sta monster_sy

cell:
        lda nibble
        bne lo_nib
        ldy #0
        lda (map_ptr),y
        sta pair
        inc map_ptr
        bne :+
        inc map_ptr+1
:
        lsr a
        lsr a
        lsr a
        lsr a
        ldx #1
        stx nibble
        jmp got
lo_nib:
        lda pair
        and #$0f
        ldx #0
        stx nibble
got:
        tax
        lda xlat,x
        cmp #CHAR_PLAYER
        bne chk_mon
        ldx load_x
        ldy load_y
        stx player_sx
        sty player_sy
        lda #CHAR_EMPTY
        jmp store
chk_mon:
        cmp #CHAR_MONSTER
        bne store
        ldx load_x
        ldy load_y
        stx monster_sx
        sty monster_sy
        lda #CHAR_EMPTY
store:
        cmp #CHAR_COIN
        bne :+
        inc coinsleft
:
        pha
        lda load_y
        asl a
        asl a
        asl a
        asl a
        clc
        adc load_x
        tax
        pla
        sta playfield,x

        inc load_x
        lda load_x
        cmp #PF_COLS
        bne cell
        lda #0
        sta load_x
        inc load_y
        lda load_y
        cmp #PF_ROWS
        beq :+
        jmp cell
:       rts

.segment "RODATA"

xlat:   .byte CHAR_EMPTY, CHAR_TREE, CHAR_BRICK, CHAR_COIN
        .byte CHAR_PLAYER, CHAR_MONSTER

.segment "MAPS"

.include "maps.inc"

