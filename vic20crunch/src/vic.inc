;; Unexpanded VIC-20 — see SPEC.md
;;
;; $1001 stub / code … $1800 font $00–$3F … $1A00 CODE2 … $1B00 tiles … $1C00 maps … $1E00 screen
;; Color $9600. Leave $9002 bit 7 set.

SCREEN      = $1E00
COLOR_RAM   = $9600
CHARSET     = $1800

VIC         = $9000
VIC_CR2     = VIC+$2
VIC_HLINE   = VIC+$4
VIC_CR5     = VIC+$5
VIC_COLOR   = VIC+$F

;; screen $1E00 + charset $1800 (stock bit7 of $9002 stays set)
VIC_CR5_GAME = $FE

COLS        = 22
ROWS        = 23
PF_COLS     = 16
PF_ROWS     = 8
PF_X0       = 3
PF_Y0       = 7
PF_ORIGIN   = PF_Y0 * COLS + PF_X0
HUD_ROW     = 16
HUD_PAD     = 3                 ; S: line indent
HUD_ORIGIN  = HUD_ROW * COLS
;; "next" (4 chars) centered
NL_ORIGIN   = 11 * COLS + 9
;; "over" centered on second-to-last row
GO_ORIGIN   = 21 * COLS + 9
;; "HI:dddd" on 3rd line, indent 5
HI_ORIGIN   = 2 * COLS + 5
HI_LEN      = 7
SPOT_STEPS  = 16
SPOT_STRIDE = 11

CURS_FLAG   = $CC
JIFFY       = $A0
JIFFY_MID   = $A1
JIFFY_LO    = $A2
