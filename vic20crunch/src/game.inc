;; Constants — SPEC.md + CRUNCH.ASM

.include "vic.inc"

CHAR_EMPTY      = $00
CHAR_COIN       = $1B           ; PETSCII 113 (●), ROM $51 copied over [
CHAR_HEART      = $1C           ; ROM ♥ copied over £
CHAR_TREE       = $60
CHAR_BRICK      = $61
CHAR_PLAYER     = $62
CHAR_MONSTER    = $63           ; wander pic (blit alias)
CHAR_MONSTER1   = $64
CHAR_BULLET     = $65
CHAR_BLOOD      = $66
CHAR_WANDER_U   = $67           ; type 0 facing: up / down / left / right
CHAR_WANDER_D   = $68
CHAR_WANDER_L   = $69
CHAR_WANDER_R   = $6A

COL_BLACK       = 0
COL_WHITE       = 1
COL_RED         = 2
COL_CYAN        = 3
COL_PURPLE      = 4
COL_GREEN       = 5
COL_BLUE        = 6
COL_YELLOW      = 7

;; Facing (matches TI movespr dir style 1..4)
DIR_UP          = 1
DIR_DOWN        = 2
DIR_LEFT        = 3
DIR_RIGHT       = 4

IN_UP           = %00000001
IN_DOWN         = %00000010
IN_LEFT         = %00000100
IN_RIGHT        = %00001000
IN_FIRE         = %00010000

LEVEL_SIZE      = 16 * 8
LEVEL_AND       = 7
MONSTER_MAX     = 21

;; Z80 was $0700 tight loops; NTSC VBlank playtest → 12 frames (~5 Hz)
FRAME_GATE      = 12

MOVE_DELAY      = 4
BULLET_RANGE    = 4
BULLET_DELAY    = 4
