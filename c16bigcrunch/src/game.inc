;; Constants — SPEC.md

.include "c16.inc"

CHAR_EMPTY      = $00
CHAR_COIN       = $1B           ; two bitmaps, filled circle
CHAR_HEART      = $1C
CHAR_TREE       = $60
CHAR_BRICK      = $61
CHAR_PLAYER     = $62           ; TL (anchor)
CHAR_PLAYER_TR  = $63
CHAR_PLAYER_BL  = $64
CHAR_PLAYER_BR  = $65
CHAR_MONSTER    = $66           ; wander TL glyph (blit alias)
CHAR_WANDER_TR  = $67
CHAR_WANDER_BL  = $68
CHAR_WANDER_BR  = $69
CHAR_MONSTER1   = $6A           ; chase TL
CHAR_CHASE_TR   = $6B
CHAR_CHASE_BL   = $6C
CHAR_CHASE_BR   = $6D
CHAR_BULLET     = $6E
CHAR_BLOOD      = $6F
CHAR_WANDER_U   = $70           ; map facing; blit → CHAR_MONSTER
CHAR_WANDER_D   = $71
CHAR_WANDER_L   = $72
CHAR_WANDER_R   = $73
CHAR_CHASE_U    = $74           ; chase TL facing; blit → CHAR_MONSTER1
CHAR_CHASE_D    = $75
CHAR_CHASE_L    = $76
CHAR_CHASE_R    = $77
;; 1×1 monsters. Glyphs are the original 8×8 art at $78/$79.
CHAR_LITTLE     = $78           ; wander blit target
CHAR_LITTLE1    = $79           ; chase
CHAR_LITTLE_U   = $7A
CHAR_LITTLE_D   = $7B
CHAR_LITTLE_L   = $7C
CHAR_LITTLE_R   = $7D

TILE_COUNT      = 16            ; $60..$6F installed bitmaps
TILE_BYTES      = TILE_COUNT * 8

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

MAZE_ROOMS      = 21            ; 3 × 7 room cells on the step-4 lattice
LEVEL_CAP       = 99

SEED_LEVEL_RAND = 0             ; 1 = load_level reseeds both LFSRs from level

;; Uncomment so a big monster's lower half may step behind a coin.
;; FEET_BEHIND_COINS = 1

;; P2 TL is three columns right of P1: one empty column between the 2×2s.
P2_SPAWN_OFF    = 3
