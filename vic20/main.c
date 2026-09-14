/*
 * VIC-20 +32K map viewer (cc65).
 * 12x8 viewport on a wrapping 1024-cell playfield from vic20.lvl.
 *
 * Screen $1000, color $9400, charset $1400 (POKE 36869,205). VICE: xvic -memory all
 */

#include <vic20.h>
#include <conio.h>
#include <peekpoke.h>
#include "charset.h"
#include "level.h"

#define SCREEN       0x1000u
#define COLOR        0x9400u
#define COLS         22
#define VIEW_W       12
#define VIEW_H       8
#define VIEW_COL     5           /* centered in 22 columns */
#define VIEW_ROW     2           /* 1-based row 3 */
#define VIEW_CEN_COL (VIEW_W / 2)
#define VIEW_CEN_ROW (VIEW_H / 2)
#define VIEW_CEN     ((unsigned int)(VIEW_CEN_ROW) * 32u + (unsigned int)(VIEW_CEN_COL))
#define HUD_ROW      (VIEW_ROW + VIEW_H)
#define HUD_COL      (VIEW_COL - 2)
#define MAP_CELLS    1024u
#define MAP_WRAP     1023u
#define JUMP_LEN     5
#define HEART_ROM    83          /* heart slot in uppercase/graphics ROM */
#define HEART_CODE   95          /* unused mixed-case slot in RAM charset */

#define VIC_COLS     0x9002u
#define CURSOR_FLAG  0xCCu

#define CHARSET     5120u   /* $1400 — +8K RAM chargen */

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

#define JOY_PA       0x9111u
#define JOY_PB       0x9120u
#define JOY_UP       0x04u
#define JOY_DOWN     0x08u
#define JOY_LEFT     0x10u
#define JOY_RIGHT    0x80u

#define UPDIR        0
#define RIGHTDIR     1
#define DOWNDIR      2
#define LEFTDIR      3

#define SPOT_STEPS   100
#define SPOT_STRIDE  13

#define TF_NOERASE   1
#define TF_KILLABLE  2
#define TF_FALLING   4

/* bits 0–3 tile, bits 4–5 last dir */
static unsigned char playfield[1024];
static unsigned int viewxy;
static unsigned int playerxy;
static unsigned int spotxy;
static unsigned char jumpptr;
static unsigned char rng;
static unsigned char charBank;     /* 0 → codes $60–$6F, 1 → $70–$7F */
static unsigned char charsetReady;
static unsigned int score;
static unsigned char hearts;
static unsigned char levelNum;

/* UPDIR RIGHTDIR DOWNDIR LEFTDIR — 16-bit add, wrap with & 1023 */
static const unsigned int dirDelta[4] = {
    (unsigned int)-32, 1u, 32u, (unsigned int)-1
};

static const unsigned char tileFlags[16] = {
    0,                                      /* blank */
    TF_NOERASE,                             /* player */
    TF_NOERASE,                             /* scroll */
    TF_NOERASE,                             /* fire */
    TF_FALLING,                             /* blood */
    0,                                      /* key */
    TF_NOERASE | TF_KILLABLE | TF_FALLING,  /* patrol */
    TF_NOERASE | TF_KILLABLE,               /* seeker */
    TF_KILLABLE | TF_FALLING,               /* bomb */
    0,                                      /* bullet */
    TF_NOERASE | TF_KILLABLE | TF_FALLING,  /* tree */
    0,                                      /* brick */
    TF_FALLING,                             /* door */
    TF_FALLING,                             /* coin */
    0,                                      /* wall */
    0                                       /* X */
};

static const unsigned char tileColors[16] = {
    COLOR_BLUE, COLOR_WHITE, COLOR_BLUE, COLOR_CYAN,    /* . P s f */
    COLOR_YELLOW, COLOR_YELLOW, COLOR_RED, COLOR_RED,   /* S k M m */
    COLOR_PURPLE, COLOR_RED, COLOR_BLUE, COLOR_PURPLE,  /* F B t b */
    COLOR_YELLOW, COLOR_GREEN, COLOR_BLUE, COLOR_YELLOW /* D c W X */
};

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

static void initCharset(void)
{
    unsigned int i;
    unsigned char *dst = (unsigned char *)CHARSET;
    /* $8800 = mixed-case ROM (what cputs lowercase switched in). */
    const unsigned char *src = (const unsigned char *)0x8800u;

    if (charsetReady) {
        return;
    }

    for (i = 0; i < 1024u; ++i) {
        dst[i] = src[i];
    }
    copyTiles(&tile_bank0[0][0], CHARSET + 0x60u * 8u);
    copyTiles(&tile_bank1[0][0], CHARSET + 0x70u * 8u);

    /* Heart from uppercase/graphics ROM ($8000) into screen code 83. */
    {
        const unsigned char *heartSrc = (const unsigned char *)(0x8000u + (unsigned int)HEART_ROM * 8u);
        unsigned char *heartDst = (unsigned char *)(CHARSET + (unsigned int)HEART_CODE * 8u);
        for (i = 0; i < 8u; ++i) {
            heartDst[i] = heartSrc[i];
        }
    }

    /* Keep screen nibble; 13 = RAM chargen at CPU $1400 / VIC $3400. */
    POKE(0x9005u, (unsigned char)((PEEK(0x9005u) & 0xF0u) | 13u));
    charsetReady = 1;
}

static void initPlayfield(void)
{
    unsigned int i, n;

    n = 0;
    for (i = 0; i < 512u; ++i) {
        unsigned char b = packedLevel[i];
        playfield[n++] = (unsigned char)(b & 0x0Fu);
        playfield[n++] = (unsigned char)(b >> 4);
    }
    playfield[playerxy] = TILE_PLAYER;
}

static unsigned char mapToTile(unsigned char cell)
{
    return (unsigned char)(TILE_BASE + (charBank << 4) + (cell & 0x0Fu));
}

static unsigned char tileColor(unsigned char cell)
{
    return tileColors[cell & 0x0Fu];
}

static void waitVrefresh(void)
{
    /* $9004: raster bits 8–1. Line 0 is start of vertical blank. */
    while (VIC.rasterline == 0) {
    }
    while (VIC.rasterline != 0) {
    }
}

static void drawView(void)
{
    unsigned char row, col;
    unsigned char cell;
    unsigned int offset;
    unsigned int i;

    waitVrefresh();

    for (row = 0; row < VIEW_H; ++row) {
        i = (viewxy + ((unsigned int)row << 5)) & MAP_WRAP;
        offset = (unsigned int)(VIEW_ROW + row) * COLS + VIEW_COL;
        for (col = 0; col < VIEW_W; ++col) {
            cell = playfield[i];
            POKE(SCREEN + offset + col, mapToTile(cell));
            POKE(COLOR + offset + col, tileColor(cell));
            i = (i + 1u) & MAP_WRAP;
        }
    }
}

static unsigned char destBlank(unsigned int dest)
{
    return (unsigned char)((playfield[dest] & 0x0Fu) == TILE_BLANK);
}

static unsigned char tryMove(unsigned int src, unsigned int dest, unsigned char packed)
{
    if (!destBlank(dest)) {
        return 0;
    }
    playfield[dest] = packed;
    playfield[src] = 0;
    return 1;
}

static unsigned char tryPlayerStep(unsigned int dest)
{
    if (!tryMove(playerxy, dest, TILE_PLAYER)) {
        return 0;
    }
    playerxy = dest;
    return 1;
}

static void syncView(void)
{
    viewxy = (playerxy - VIEW_CEN) & MAP_WRAP;
}

static unsigned char movePlayer(void)
{
    unsigned char key;
    unsigned char pa;
    unsigned char moved;
    unsigned int start;

    start = playerxy;
    key = GETKEY();
    pa = PEEK(JOY_PA);

    if ((key == KEY_I || (pa & JOY_UP) == 0) &&
        !destBlank((playerxy + dirDelta[DOWNDIR]) & MAP_WRAP)) {
        jumpptr = JUMP_LEN;
    }

    if (jumpptr > 0) {
        tryPlayerStep((playerxy + dirDelta[UPDIR]) & MAP_WRAP);
    } else {
        tryPlayerStep((playerxy + dirDelta[DOWNDIR]) & MAP_WRAP);
    }

    if (key == KEY_J || (pa & JOY_LEFT) == 0) {
        tryPlayerStep((playerxy + dirDelta[LEFTDIR]) & MAP_WRAP);
    }
    if (key == KEY_L || (PEEK(JOY_PB) & JOY_RIGHT) == 0) {
        tryPlayerStep((playerxy + dirDelta[RIGHTDIR]) & MAP_WRAP);
    }

    if (jumpptr > 0) {
        --jumpptr;
    }

    syncView();
    moved = (unsigned char)(playerxy != start);
    return moved;
}

static unsigned char randDir(void)
{
    rng = (unsigned char)(rng * 17u + 1u);
    return (unsigned char)(rng & 3u);
}

static unsigned char seekerDir(unsigned int pos)
{
    unsigned int diff;

    /* CENGINE doseek: 25% wander (rand>>2 & 3 == 0). */
    rng = (unsigned char)(rng * 17u + 1u);
    if ((unsigned char)((rng >> 2) & 3u) == 0) {
        return randDir();
    }

    /* diff = (seeker - player) & 1023; near on the ring is left/right. */
    diff = (pos - playerxy) & MAP_WRAP;
    if (diff < 16u) {
        return LEFTDIR;
    }
    if (diff >= (MAP_CELLS - 16u)) {
        return RIGHTDIR;
    }
    if (diff < 512u) {
        return UPDIR;
    }
    return DOWNDIR;
}

static unsigned char moveMonsters(void)
{
    unsigned char steps;
    unsigned char moved;
    unsigned char id;
    unsigned char dir;
    unsigned int dest;
    unsigned int down;

    moved = 0;
    steps = SPOT_STEPS;
    while (steps > 0) {
        --steps;
        spotxy = (spotxy + SPOT_STRIDE) & MAP_WRAP;
        id = (unsigned char)(playfield[spotxy] & 0x0Fu);

        if (id == TILE_PATROL || id == TILE_SEEKER) {
            if (id == TILE_PATROL) {
                down = (spotxy + dirDelta[DOWNDIR]) & MAP_WRAP;
                if ((tileFlags[id] & TF_FALLING) && destBlank(down)) {
                    dir = DOWNDIR;
                } else {
                    dir = (unsigned char)((playfield[spotxy] >> 4) & 3u);
                    dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
                    if (!destBlank(dest)) {
                        dir = randDir();
                    }
                }
            } else { //seeker
                dir = seekerDir(spotxy);
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
                if (!destBlank(dest)) {
                    dir = randDir();
                }
            }
            dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            if (tryMove(spotxy, dest, (unsigned char)(id | (dir << 4)))) {
                moved = 1;
            } else {
                playfield[spotxy] = (unsigned char)(id | (dir << 4));
            }
        } else if (tileFlags[id] & TF_FALLING) {
            dest = (spotxy + dirDelta[DOWNDIR]) & MAP_WRAP;
            if (tryMove(spotxy, dest, id)) {
                moved = 1;
            }
        }
    }
    return moved;
}

static void drawHud(void)
{
    unsigned int base;
    unsigned int n;
    unsigned char d;

    base = (unsigned int)HUD_ROW * COLS + HUD_COL;
    /* S: 0000 ♥:h L:l  (mixed-case screen codes: A=65) */
    POKE(SCREEN + base + 0, 83);              /* S */
    POKE(COLOR + base + 0, COLOR_YELLOW);
    POKE(SCREEN + base + 1, 58);              /* : */
    POKE(COLOR + base + 1, COLOR_YELLOW);

    n = score;
    d = (unsigned char)((n / 1000u) % 10u);
    POKE(SCREEN + base + 3, (unsigned char)(48u + d));
    POKE(COLOR + base + 3, COLOR_WHITE);
    d = (unsigned char)((n / 100u) % 10u);
    POKE(SCREEN + base + 4, (unsigned char)(48u + d));
    POKE(COLOR + base + 4, COLOR_WHITE);
    d = (unsigned char)((n / 10u) % 10u);
    POKE(SCREEN + base + 5, (unsigned char)(48u + d));
    POKE(COLOR + base + 5, COLOR_WHITE);
    d = (unsigned char)(n % 10u);
    POKE(SCREEN + base + 6, (unsigned char)(48u + d));
    POKE(COLOR + base + 6, COLOR_WHITE);

    POKE(SCREEN + base + 8, HEART_CODE);
    POKE(COLOR + base + 8, COLOR_RED);
    POKE(SCREEN + base + 9, 58);
    POKE(COLOR + base + 9, COLOR_YELLOW);
    POKE(SCREEN + base + 10, (unsigned char)(48u + (hearts % 10u)));
    POKE(COLOR + base + 10, COLOR_WHITE);

    POKE(SCREEN + base + 12, 76);             /* L */
    POKE(COLOR + base + 12, COLOR_YELLOW);
    POKE(SCREEN + base + 13, 58);
    POKE(COLOR + base + 13, COLOR_YELLOW);
    POKE(SCREEN + base + 14, (unsigned char)(48u + (levelNum % 10u)));
    POKE(COLOR + base + 14, COLOR_WHITE);
}

static void initVideo(void)
{
    /* Expanded VIC: video matrix at $1000 (clear $9002 bit 7). */
    POKE(VIC_COLS, PEEK(VIC_COLS) & 0x7F);
    POKE(CURSOR_FLAG, 1);

    bgcolor(COLOR_BLACK);
    bordercolor(COLOR_BLACK);
    textcolor(COLOR_CYAN);

    clrscr();
    gotoxy(0, 0);
    cputs("Caves (c)1996 CHRIS B");
    gotoxy(4, 1);
    cputs("Creepy Castle");
    /* cputs lowercase does CHR$(14) and points VIC at $8800 ROM. Install RAM font after that. */
    initCharset();
    drawHud();
}

int main(void)
{
    viewxy = 0;
    playerxy = PLAYER_START;
    jumpptr = 0;
    spotxy = 0;
    rng = 1;
    score = 0;
    hearts = 4;
    levelNum = 1;
    syncView();

    initPlayfield();
    initVideo();

    for (;;) {
        unsigned char jiffy = GETJIFFY();

        movePlayer();
        moveMonsters();
        if (((64u & jiffy) == 0) != charBank) {
            charBank = !charBank;
        }
        drawView();
    }
}
