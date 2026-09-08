;; Level load — maps from CRUNCH.ASM (packed 0–5)

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
.export score_tick
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
score_tick:     .res 1          ; binary count for +2 health every 32
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

;; CRUNCH.ASM maps, two cells per byte (hi nibble first)
maps:
        .byte $31,$00,$00,$13,$31,$01,$11,$33,$31,$11,$11,$11,$01,$11,$00,$03
        .byte $00,$00,$00,$00,$01,$33,$01,$00,$00,$00,$22,$22,$22,$22,$22,$10
        .byte $10,$00,$50,$00,$00,$03,$42,$00,$11,$00,$22,$22,$22,$22,$22,$00
        .byte $11,$10,$00,$00,$00,$00,$00,$01,$11,$11,$00,$00,$03,$13,$00,$11
        .byte $12,$00,$00,$22,$22,$01,$13,$11,$32,$22,$22,$20,$42,$11,$33,$31
        .byte $00,$00,$20,$30,$02,$30,$00,$00,$02,$05,$20,$22,$22,$00,$11,$10
        .byte $02,$00,$20,$22,$11,$00,$13,$30,$02,$00,$00,$32,$10,$00,$01,$00
        .byte $02,$22,$22,$22,$00,$10,$00,$01,$00,$00,$00,$00,$00,$11,$33,$11
        .byte $31,$00,$00,$13,$01,$01,$11,$04,$01,$11,$11,$10,$01,$11,$00,$00
        .byte $00,$00,$00,$00,$22,$22,$00,$11,$00,$03,$10,$00,$20,$52,$00,$03
        .byte $10,$00,$00,$30,$20,$22,$03,$00,$00,$00,$00,$00,$10,$00,$00,$01
        .byte $03,$01,$00,$00,$00,$00,$03,$00,$00,$00,$00,$10,$01,$01,$00,$00
        .byte $01,$00,$00,$11,$11,$01,$30,$01,$01,$11,$11,$10,$31,$11,$00,$00
        .byte $00,$00,$00,$00,$01,$33,$01,$10,$00,$22,$20,$01,$10,$00,$01,$30
        .byte $10,$24,$30,$00,$50,$30,$13,$00,$00,$22,$20,$00,$11,$10,$00,$00
        .byte $00,$00,$00,$10,$01,$00,$00,$01,$30,$01,$00,$00,$00,$01,$30,$11
        .byte $31,$00,$00,$11,$11,$01,$11,$03,$30,$11,$11,$01,$01,$11,$10,$00
        .byte $01,$01,$00,$00,$00,$00,$00,$10,$01,$00,$00,$00,$22,$22,$23,$02
        .byte $01,$01,$01,$00,$20,$00,$20,$02,$01,$01,$02,$22,$24,$20,$22,$22
        .byte $01,$00,$00,$00,$00,$25,$00,$32,$00,$01,$02,$22,$22,$22,$22,$22
        .byte $11,$00,$00,$11,$11,$01,$11,$03,$11,$11,$11,$10,$00,$10,$00,$01
        .byte $12,$22,$22,$00,$20,$00,$00,$00,$00,$00,$42,$00,$22,$01,$10,$00
        .byte $32,$02,$22,$20,$02,$00,$30,$00,$32,$02,$00,$02,$52,$00,$00,$00
        .byte $32,$00,$02,$00,$02,$10,$00,$01,$32,$22,$22,$22,$22,$00,$00,$11
        .byte $11,$00,$00,$11,$11,$01,$10,$33,$11,$11,$11,$11,$11,$11,$00,$00
        .byte $00,$00,$00,$10,$02,$22,$20,$11,$02,$20,$20,$00,$02,$00,$20,$33
        .byte $02,$00,$20,$01,$02,$50,$20,$00,$02,$40,$20,$00,$02,$00,$00,$03
        .byte $32,$22,$20,$00,$02,$22,$20,$00,$10,$00,$00,$10,$00,$00,$00,$01
        .byte $01,$00,$00,$11,$00,$01,$11,$03,$00,$11,$11,$11,$11,$10,$00,$00
        .byte $10,$30,$01,$00,$00,$00,$00,$00,$00,$43,$01,$01,$11,$00,$50,$01
        .byte $02,$02,$01,$00,$00,$00,$00,$00,$02,$02,$01,$00,$11,$00,$01,$03
        .byte $02,$22,$00,$00,$11,$00,$01,$33,$00,$00,$00,$10,$11,$00,$01,$13
