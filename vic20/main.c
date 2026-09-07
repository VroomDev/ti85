/*
 * VIC-20 +32K map viewer (cc65).
 * 12x8 viewport on a wrapping 32x32 level from vic20.lvl.
 *
 * Screen $1000, color $9400, charset $1C00. VICE: xvic -memory all
 */

#include <vic20.h>
#include <conio.h>
#include <peekpoke.h>
#include "charset.h"

#define SCREEN       0x1000u
#define COLOR        0x9400u
#define COLS         22
#define VIEW_W       12
#define VIEW_H       8
#define MAP_SIZE     32
#define MAP_MASK     31

#define VIC_COLS     0x9002u
#define CURSOR_FLAG  0xCCu

#define CHARSET     0x1800u
#define VIC_CR5_RAM 0x46u   /* Screen at $1000 (0x40), Chars at $1800 (0x06) */

/* Kernal LSTX: current key held, 64 if none. */
#define LSTX         0xC5u
#define KEY_NONE     64
#define GETKEY()     (PEEK(LSTX))

/* Kernal TIME LSB ($A2): jiffy count 0–255 (NTSC 60/s, PAL 50/s). */
#define TIME         0xA2u
#define GETJIFFY()   (PEEK(TIME))

#define KEY_I        12
#define KEY_J        20
#define KEY_L        21
#define KEY_M        36
#define KEY_1        0
#define KEY_2        56

/* Concatenated 32x32 rows from vic20.lvl (1024 bytes + NUL). */
static const unsigned char level[] =
    "cccccccccccccccccccccccccccccccc"
    "...........ccccc................"
    "...........ccccc................"
    ".F.........ccccc................"
    "...........cBBBc.............F.."
    "...........BBBBB......SS........"
    "............BBB......BSSB......."
    "......................BB........"
    "................................"
    "................................"
    "........BBB....................."
    "......BBBBBB...................."
    "........BBB.F..................."
    "...........................m...."
    "..............bm.b..m....b.sb..."
    ".......WWW....bbbbbbb....bbbb..."
    "...WWWWWWWW......bc...bbbM......"
    "......WWWWWW.X...bcc.....D......"
    "WWWWW.WWWWWWWWbfbbcc....bbbfbWWW"
    "WWWW..WWWWWWWWWfWbbbbbbbbbWfWWWW"
    "WWWWW.WWWWWWWWWWWWWWWWWWWWWWWWWW"
    "WWWWW.....WWWWWWWWWWWWWWWWWWWWWW"
    "WWWWWWWW.m......WWWWWWWWWWWWWWWW"
    "WWWWWWWWWWWWWWc.......m..WWWWWWW"
    "WWWWcccccccWWWWWWFWWWWW.F...WWWW"
    "WWWccccccccccccWWWWWWWWWW..kWWWW"
    "WWWffffffffffffWWWWWWWcWWWWWWWWW"
    "WWWWWWWWWWWWWWWWWWcWWWWWWWWWWWWW"
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWcWWW"
    "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
    "................................"
    "................................";

static unsigned char view_x;
static unsigned char view_y;
static unsigned char charBank;     /* 0 → codes $60–$6F, 1 → $70–$7F */
static unsigned char charsetReady;

static void copyTiles(const unsigned char *src, unsigned int dest)
{
    unsigned char i, r;
    unsigned char *dst = (unsigned char *)dest;

    for (i = 0; i < TILE_COUNT; ++i) {
        for (r = 0; r < 8; ++r) {
            dst[(unsigned int)i * 8 + r] = src[(unsigned int)i * 8 + r];
        }
    }
}

/* Install bank 0 at $1F00 (codes $60–$6F) or use bank 1 at $1F80 ($70–$7F). */
void setCharBank(unsigned char bank)
{
    charBank = bank & 1;
}


static void initCharset(void)
{
    unsigned int i;
    unsigned char *dst = (unsigned char *)CHARSET;
    
    // Copy directly from Character ROM at $8000 before changing VIC registers
    const unsigned char *src = (const unsigned char *)0x8000u;

    if (charsetReady) {
        return;
    }

    // 1. Copy character ROM to custom RAM location
    for (i = 0; i < 96u * 8u; ++i) {
        dst[i] = src[i];
    }

    // 2. Copy tile graphics
    copyTiles(&tile_bank0[0][0], CHARSET + 0x60u * 8u);
    copyTiles(&tile_bank1[0][0], CHARSET + 0x70u * 8u);

    // 3. Switch VIC register to use new CHARSET base address ($1800)
    VIC.addr = VIC_CR5_RAM;
    charsetReady = 1;
}

/* Map letters → custom slots $60+ (not A–Z / 0–9). Order matches charset.h. */
static unsigned char mapToTile(unsigned char ch)
{
    unsigned char slot;

    switch (ch) {
    case '.': slot = 0; break;
    case 'P': slot = 1; break;
    case 's': slot = 2; break;
    case 'f': slot = 3; break;
    case 'S': slot = 4; break;
    case 'k': slot = 5; break;
    case 'M': slot = 6; break;
    case 'm': slot = 7; break;
    case 'F': slot = 8; break;
    case 'B': slot = 9; break;
    case 't': slot = 10; break;
    case 'b': slot = 11; break;
    case 'D': slot = 12; break;
    case 'c': slot = 13; break;
    case 'W': slot = 14; break;
    case 'X': slot = 15; break;
    default:  slot = 0; break;
    }
    return (unsigned char)(TILE_BASE + (charBank << 4) + slot);
}

static unsigned char tileColor(unsigned char ch)
{
    switch (ch) {
    case 'W':
        return COLOR_BLUE;
    case 'c':
        return COLOR_GREEN;
    case 'B':
        return COLOR_RED;
    case 'S':
        return COLOR_YELLOW;
    case 'F':
        return COLOR_PURPLE;
    case 'b':
        return COLOR_PURPLE;
    case 'm':
    case 'M':
        return COLOR_RED;
    case 'X':
    case 'D':
    case 'k':
        return COLOR_YELLOW;
    case 'f':
        return COLOR_CYAN;
    default:
        return COLOR_BLUE;
    }
}

static void drawView(void)
{
    unsigned char row, col;
    unsigned char mx, my;
    unsigned char ch;
    unsigned int offset;

    for (row = 0; row < VIEW_H; ++row) {
        my = (unsigned char)((view_y + row) & MAP_MASK);
        offset = (unsigned int)row * COLS;
        for (col = 0; col < VIEW_W; ++col) {
            mx = (unsigned char)((view_x + col) & MAP_MASK);
            ch = level[(unsigned int)my * MAP_SIZE + mx];
            POKE(SCREEN + offset + col, mapToTile(ch));
            POKE(COLOR + offset + col, tileColor(ch));
        }
    }
}

static void initVideo(void)
{
    /* Expanded VIC: video matrix at $1000 (clear $9002 bit 7). */
    POKE(VIC_COLS, PEEK(VIC_COLS) & 0x7F);
    POKE(CURSOR_FLAG, 1);

    bgcolor(COLOR_WHITE);
    bordercolor(COLOR_CYAN);
    textcolor(COLOR_BLUE);

    clrscr();
    gotoxy(0, 9);
    cputs("i/m j/l move  1/2 charset");
}

int main(void)
{
    unsigned char key;

    view_x = 0;
    view_y = 0;

    initVideo();
    drawView();

    for (;;) {
        key = GETKEY();
        switch (key) {
        case KEY_I:
            view_y = (unsigned char)((view_y - 1) & MAP_MASK);
            break;
        case KEY_M:
            view_y = (unsigned char)((view_y + 1) & MAP_MASK);
            break;
        case KEY_J:
            view_x = (unsigned char)((view_x - 1) & MAP_MASK);
            break;
        case KEY_L:
            view_x = (unsigned char)((view_x + 1) & MAP_MASK);
            break;
        case KEY_1:
            initCharset();
            setCharBank(0);
            break;
        case KEY_2:
            initCharset();
            setCharBank(1);
            break;
        default:
            continue;
        }
        drawView();
    }
}
