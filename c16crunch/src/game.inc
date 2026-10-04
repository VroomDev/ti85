;; Constants — SPEC.md

.include "c16.inc"

CHAR_EMPTY      = $00
CHAR_COIN       = $1B           ; PETSCII 113 (●)
CHAR_HEART      = $1C
CHAR_TREE       = $60
CHAR_BRICK      = $61
CHAR_PLAYER     = $62
CHAR_MONSTER    = $63           ; wander pic (blit alias)
CHAR_MONSTER1   = $64
CHAR_BULLET     = $65
CHAR_BLOOD      = $66
CHAR_WANDER_U   = $67
CHAR_WANDER_D   = $68
CHAR_WANDER_L   = $69
CHAR_WANDER_R   = $6A

;; TED color: bits 6–4 luminance, bits 3–0 chroma. Bit 7 is flash.
COL_BLACK       = $00
COL_WHITE       = $71
COL_RED         = $42
COL_CYAN        = $73
COL_PURPLE      = $54
COL_GREEN       = $55
COL_BLUE        = $66
COL_YELLOW      = $77

DIR_UP          = 1
DIR_DOWN        = 2
DIR_LEFT        = 3
DIR_RIGHT       = 4

IN_UP           = %00000001
IN_DOWN         = %00000010
IN_LEFT         = %00000100
IN_RIGHT        = %00001000
IN_FIRE         = %00010000

LEVEL_SIZE      = 32 * 16

MOVE_DELAY      = 1             ; countdown skips one frame → move every other frame
HURT_PERIOD     = 10            ; frames the player cannot be hurt again
BULLET_RANGE    = 4
BULLET_DELAY    = 0             ; step every frame

MAZE_ROOMS      = 105           ; 15 × 7 odd cells
LEVEL_CAP       = 99
