;; Stock 16KB Commodore 16 / TED. Screen $0C00, color $0800, charset RAM $2000.

SCREEN      = $0C00
COLOR_RAM   = $0800
CHARSET     = $2000

TED_KBD         = $FF08
KBD_LATCH       = $FD30
TED_V1LO        = $FF0E
TED_V2LO        = $FF0F
TED_V1HI        = $FF10
TED_SND         = $FF11
TED_CTRL        = $FF12
TED_CHAR        = $FF13
TED_BG          = $FF15
TED_BORDER      = $FF19
TED_CURSHI      = $FF0C
TED_CURSLO      = $FF0D
TED_RASTERHI    = $FF1C
TED_RASTERLO    = $FF1D
TED_ROMSEL      = $FF3E

;; $FF13 bits 7–2 = charset A15–A10. $2000 → bit 5. Bit 2 of $FF12 clear = RAM charset.
CHAR_BASE_RAM   = $20

COLS        = 40
ROWS        = 25
PF_COLS     = 32
PF_ROWS     = 16
PF_X0       = 4
PF_Y0       = 4
PF_ORIGIN   = PF_Y0 * COLS + PF_X0
HUD_ROW     = 21
HUD_PAD     = 5             ; column of "S:"
HUD_ORIGIN  = HUD_ROW * COLS
;; "vYYYYMMDD" (9) centered on the HUD row. First intro only.
VER_LEN     = 9
VER_ORIGIN  = HUD_ORIGIN + (COLS - VER_LEN) / 2
;; "next" (4) centered on the 40×25 screen
NL_ORIGIN   = 12 * COLS + 18
;; "pause" (5) centered on the 40×25 screen
PAUSE_ORIGIN = 12 * COLS + 17
;; "done" centered on the last row
GO_ORIGIN   = 24 * COLS + 18
;; Cheat "?" at column 0 of the last row
CHEAT_MARK  = 24 * COLS
;; "HI:dddd" on the HUD row, after the level
HI_ORIGIN   = HUD_ORIGIN + 28
HI_LEN      = 7

SPOT_STEPS        = 200
SPOT_STRIDE       = 183
RASTER_OFF_EARLY  = 123
RASTER_OFF        = 126

;; Plus/4 jiffy is $A3–$A5, $A5 least significant
JIFFY       = $A3
JIFFY_MID   = $A4
JIFFY_LO    = $A5

;; Editor cursor row. Parked off the 25-row screen.
CURS_Y      = $CD
CURS_X      = $CA
