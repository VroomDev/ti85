/*
 * Shared VIC-20 engine (cc65), included by vic20scrolls and vic20caves.
 * One translation unit per game: these statics and functions are compiled
 * into that game, not linked as a separate library.
 *
 * The including main.c must already have included charset.h and level.h,
 * and defined VIEW_W, VIEW_H, HELP_TEXT, HELP_LEN, COPYRIGHT, mapIndex,
 * and liveLevel. Game-specific tileFlags and rules stay in that main.c.
 */

#ifndef ENGINE_H
#define ENGINE_H

#include <vic20.h>
#include <conio.h>
#include <peekpoke.h>

#ifndef VIEW_W
#error define VIEW_W before including engine.h
#endif
#ifndef VIEW_H
#error define VIEW_H before including engine.h
#endif
#ifndef HELP_TEXT
#error define HELP_TEXT before including engine.h
#endif
#ifndef HELP_LEN
#error define HELP_LEN before including engine.h
#endif

#define SCREEN       0x1000u
#define COLOR        0x9400u
#define COLS         22
#define ROWS         23
#define STORY_ROW    1
#define AUTHOR_ROW   2
#define VIEW_ROW     4
//((ROWS-VIEW_H)/2)
#define VIEW_COL     ((COLS-VIEW_W)/2)
#define VIEW_CEN_COL (VIEW_W / 2)
#define VIEW_CEN_ROW (VIEW_H / 2)
#define VIEW_CEN     ((unsigned int)(VIEW_CEN_ROW) * 32u + (unsigned int)(VIEW_CEN_COL))
#define HUD_ROW      ((VIEW_ROW + VIEW_H) + 1)
#define HISCORE_ROW  (HUD_ROW + 2)
#define HUD_LEN      15
#define HISCORE_LEN  7
#define HUD_COL      ((COLS - HUD_LEN) / 2)
#define HISCORE_COL  ((COLS - HISCORE_LEN) / 2)
#define HELP_ROW     (ROWS - 1)
#define HELP_COL     ((COLS - HELP_LEN) / 2)
#define MAP_CELLS    1024u
#define MAP_WRAP     1023u
#define JUMP_LEN     3
#define HEART_ROM    83
#define HEART_CODE   95
/* cannot exceed 255 and must be below 480 due to double hops */
#define SPOT_STEPS   100
#define SPOT_STRIDE  239

#define RASTER_OFF_EARLY   123
#define RASTER_OFF   126

#define VIC_COLS     0x9002u
#define CURSOR_FLAG  0xCCu

#define CHARSET     5120u

#define LSTX         0xC5u
#ifndef NDX
#define NDX          0xC6u  /* Kernal: keyboard buffer count */
#endif
#define SHFLAG       0x028Du  /* Kernal: bit 0 Shift, 1 CBM, 2 Ctrl */
#define SHIFT        0x01u
#define CBM          0x02u
#define KEY_NONE     64
#define GETKEY()     (PEEK(LSTX))

#define TIME         0xA2u
#define GETJIFFY()   (PEEK(TIME))

#define KEY_P        13
#define KEY_RETURN   15
#define KEY_COMMA    29
#define KEY_M        36
#define KEY_PERIOD   37
#define KEY_S        41

#define KEY_Q        48
#define KEY_W        9
#define JOY_PA       0x9111u
#define JOY_PB       0x9120u
#define JOY_DDRB     0x9122u
#define JOY_UP       0x04u
#define JOY_DOWN     0x08u
#define JOY_LEFT     0x10u
#define JOY_BTN      0x20u
#define JOY_RIGHT    0x80u

#define VIC_BASS     0x900Au
#define VIC_ALTO     0x900Bu
#define VIC_SOPRANO  0x900Cu
#define VIC_NOISE    0x900Du
#define VIC_VOLUME   0x900Eu

/* tileFlags[id] (in the game): bit0 solid, bit1 shootable, bit2 game-specific.
   Originally noerasebit, killablebit, and fallingbit in the z80 code. */
#define TF_SOLID     1
#define TF_SHOOTABLE 2

#define WAIT_FRAMES  30
#define CELL_ID_FILTER 0x0Fu

#define UPDELTA ((unsigned int)-32)
#define RIGHTDELTA ((unsigned int)1)
#define DOWNDELTA ((unsigned int)32)
#define LEFTDELTA ((unsigned int)-1)

#define LEFTDIR      0
#define RIGHTDIR     1
#define UPDIR        2
#define DOWNDIR      3

static char* PRESS_KEY="Press key!";

static unsigned char playfield[1024];
static unsigned int viewxy;
static unsigned int spotxy;
static unsigned int playerxy;
static unsigned int blockspot;
static unsigned int monsterCount;
static unsigned int score;      /* packed 4-digit BCD, $0000–$9999 */
static unsigned int hiscore;    /* packed BCD; unsigned compare is valid */
static unsigned int rng16;
static unsigned int bulletxy;
static unsigned char jumpptr;
static unsigned char charBank;
static unsigned char charsetReady;
static unsigned char lives;
static unsigned char facing;
static unsigned char hasKey;
static unsigned char sfxDur;
static unsigned char hurtDur;
static unsigned char bulletDir;
static unsigned char bulletRange;
static unsigned char firstMap;
static unsigned char pendingLevel;
static unsigned char quitRun;
static unsigned char rng;
static unsigned char frame;

static const unsigned int dirDelta[4] = {
    LEFTDELTA,RIGHTDELTA,UPDELTA,DOWNDELTA
};

static unsigned char tileColors[16] = {
    COLOR_BLACK, COLOR_YELLOW, COLOR_WHITE, COLOR_BLUE,     /* . X/P s f */
    COLOR_RED, COLOR_YELLOW, COLOR_PURPLE, COLOR_RED,      /* S k M m */
    COLOR_CYAN, COLOR_WHITE, COLOR_GREEN, COLOR_WHITE,      /* F B t b */
    COLOR_RED, COLOR_YELLOW, COLOR_WHITE, COLOR_BLACK       /* D c W (15) */
};

/* addScore is defined below, after drawHud. The rest are the game's. */
static void addScore(unsigned char n);
static void shootCell(unsigned int dest, unsigned char hit);
static void movePlayer(void);
static void moveMonsters(void);
static void gameStep(void);
static void restoreStoryLine(void);

/* static unsigned char mapToTile(unsigned char cell)
 * {
 *     return (unsigned char)(TILE_BASE + (charBank << 4) + (cell & 0x0Fu));
 * }
 */
#define mapToTile(cell) ((unsigned char)(TILE_BASE + (charBank << 4) + ((cell) & CELL_ID_FILTER)))

/* static unsigned char tileColor(unsigned char cell)
 * {
 *     cell = (unsigned char)(cell & 0x0Fu);
 *     if (cell == TILE_PLAYER && hurtDur) {
 *         return COLOR_PURPLE;
 *     }
 *     return tileColors[cell];
 * }
 */
#define tileColor(cell) (tileColors[(unsigned char)((cell) & CELL_ID_FILTER)])

/* static unsigned char randDir(void)
 * {
 *     return (unsigned char)((rand8()>>2) & 3u);
 * }
 */
#define randDir() ((unsigned char)((rand8()) & 3u))

/* static unsigned char destBlank(unsigned int dest)
 * {
 *     return (unsigned char)((playfield[dest] & 0x0Fu) == TILE_BLANK);
 * }
 */
#define destBlank(dest) ((unsigned char)((playfield[dest] & CELL_ID_FILTER) == TILE_BLANK))

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
    const unsigned char *src = (const unsigned char *)0x8800u;

    if (charsetReady) {
        return;
    }

    for (i = 0; i < 1024u; ++i) {
        dst[i] = src[i];
    }
    copyTiles(&tile_bank0[0][0], CHARSET + 0x60u * 8u);
    copyTiles(&tile_bank1[0][0], CHARSET + 0x70u * 8u);

    {
        const unsigned char *heartSrc = (const unsigned char *)(0x8000u + (unsigned int)HEART_ROM * 8u);
        unsigned char *heartDst = (unsigned char *)(CHARSET + (unsigned int)HEART_CODE * 8u);
        for (i = 0; i < 8u; ++i) {
            heartDst[i] = heartSrc[i];
        }
    }

    POKE(0x9005u, (unsigned char)((PEEK(0x9005u) & 0xF0u) | 13u));
    charsetReady = 1;
}

static unsigned char mapIndexOf(void)
{
    return (unsigned char)(mapIndex % LEVEL_COUNT);
}

static void unpackMap(unsigned char idx)
{
    unsigned int i, n;
    const unsigned char *src = packedLevels[idx];

    n = 0;
    for (i = 0; i < 512u; ++i) {
        unsigned char b = src[i];
        playfield[n++] = (unsigned char)(b & 0x0Fu);
        playfield[n++] = (unsigned char)(b >> 4);
    }
}

static void drawView(void)
{
    unsigned char row, col;
    unsigned char cell;
    unsigned int offset;
    unsigned int i;

    if(hurtDur){ //JUST SWAP THE COLORS
        tileColors[TILE_PLAYER]=COLOR_PURPLE;
    }else{
        tileColors[TILE_PLAYER]=COLOR_YELLOW;
    }

    //KEEP THIS AREA FAST!
    offset = (unsigned int)(VIEW_ROW) * COLS + VIEW_COL;
    for (row = 0; row < VIEW_H; ++row) {
        i = (viewxy + ((unsigned int)row << 5)) & MAP_WRAP;
        for (col = 0; col < VIEW_W; ++col) {
            cell = playfield[i];
            POKE(SCREEN + offset + col, mapToTile(cell));
            POKE(COLOR + offset + col, tileColor(cell));
            i = (i + 1u) & MAP_WRAP;
        }
        offset += COLS;
    }
}

static void syncView(void)
{
    viewxy = (playerxy - VIEW_CEN) & MAP_WRAP;
}

static unsigned char rand8(void){
    //rng = (unsigned char)(rng * 17u + 1u);
    //use linear feedback shift register instead
    rng=(rng>>1) ^ ((rng & 1)? 0xB4u : 0u);
    return rng;
}

#ifndef CRC
#define CRC 0
#endif

/* Code shown for a level: CRC, then one rand8 per mapIndex step. */
static unsigned char levelCode(unsigned char index)
{
    unsigned char n;

    rng = CRC;
    for (n = 0; n < index && n < LEVEL_COUNT; ++n) {
        rand8();
    }
    return rng;
}

/* cgetc reads the Kernal buffer, not $C5. Holding S fills that buffer. */
static char readPetscii(void)
{
    while (GETKEY() != KEY_NONE) {
    }
    POKE(NDX, 0);
    return cgetc();
}

static unsigned char hexNibble(char ch)
{
    unsigned char c = (unsigned char)ch;

    if (c >=  0x30 && c <= 0x39) { //digits
        return (unsigned char)(c -  0x30);
    }
    if (c >= 0x41 && c <= 0x41+('F'-'A')) { //UPPERCASE
        return (unsigned char)(c - 0x41 + 10);
    }
    if (c >= 0xC1 && c <= 0xc1+('f'-'a')) { //lowerCASE
        return (unsigned char)(c - 0xC1 + 10);
    }
    return 0;
}

/* RAM charset is the $8800 set: cputc of ASCII a-z draws uppercase A-Z. */
static char upperGlyph(char ch)
{
    if ((unsigned char)ch >= 0xC1u && (unsigned char)ch <= 0xDAu) {
        return (char)((unsigned char)ch - 0xC1u + 'A');
    }
    if (ch >= 'A' && ch <= 'Z') {
        return (char)(ch - 'A' + 'a');
    }
    return ch;
}

static void putHex(unsigned char n)
{
    unsigned char d;

    d = (unsigned char)(n >> 4);
    cputc(d < 10 ? (char)('0' + d) : upperGlyph((char)('A' + (d - 10))));
    d = (unsigned char)(n & 0x0Fu);
    cputc(d < 10 ? (char)('0' + d) : upperGlyph((char)('A' + (d - 10))));
}

static void drawNewLevelMsg(void)
{
    gotoxy(0, HUD_ROW);
    cputs("New Level! SCODE:");
    putHex(levelCode(mapIndex % LEVEL_COUNT));
}

static unsigned int rand16(void)
{
    //rng16 = (unsigned int)(rng16 * 17u + 1u);
    //use linear feedback shift register instead
    rng16=(rng16>>1) ^ ((rng16 & 1)? 0xD008u : 0u);
    return rng16;
}

static void simpleWaitFrames(unsigned char fc){
    while(fc--){
        while(VIC.rasterline!=50){
            rand16();
            rand8();
        }
        while(VIC.rasterline!=49){
        }
    }
}


static void waitFireOrKey(void)
{
    simpleWaitFrames(5);
    for (;;) {
        rand8();
        rand16();
        if (GETKEY() != KEY_NONE || (PEEK(JOY_PA) & JOY_BTN) == 0 ||
            (PEEK(SHFLAG) & SHIFT)) {
            return;
        }
    }
}

static unsigned int rand512(void)
{
    return rand16() &  511u;
}

static void silenceVic(void)
{
    POKE(VIC_BASS, 0);
    POKE(VIC_ALTO, 0);
    POKE(VIC_SOPRANO, 0);
    POKE(VIC_NOISE, 0);
    POKE(VIC_VOLUME, 0);
    sfxDur = 0;
}

static void playAudioFrame(void)
{
    if (sfxDur) {
        --sfxDur;
        if (!sfxDur) {
            silenceVic();
        }
    }
    if (hurtDur) {
        --hurtDur;
    }
}

static void playChirp(void)
{
    POKE(VIC_SOPRANO, 240);
    POKE(VIC_VOLUME, 0x0f);
    sfxDur = 1;
}

static void playCoin(void)
{
    POKE(VIC_SOPRANO, 240);
    POKE(VIC_ALTO, 240);
    POKE(VIC_BASS,0);
    POKE(VIC_NOISE,0);
    POKE(VIC_VOLUME, 0x0f);
    sfxDur = 1;
}

static void playKill(void)
{
    sfxDur = 2;
    POKE(VIC_BASS, 130);
    POKE(VIC_ALTO, 148);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_NOISE, 220);
    POKE(VIC_VOLUME, 10);
}

static void playBash(void)
{
    sfxDur = 2;
    POKE(VIC_NOISE, 150);
    POKE(VIC_VOLUME, 5);
}

static void playBounce(void)
{
    sfxDur = 2;
    POKE(VIC_BASS, 170);
    POKE(VIC_ALTO, 190);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_NOISE, 0);
    POKE(VIC_VOLUME, 10);
}


static void playBounce2(void)
{
    sfxDur = 1;
    POKE(VIC_BASS, 170);
    POKE(VIC_ALTO, 190);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_NOISE, 0);
    POKE(VIC_VOLUME, 10);
}

static void playHurt(void)
{
    POKE(VIC_BASS, 140);
    POKE(VIC_ALTO, 155);
    POKE(VIC_NOISE, 200);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_VOLUME, 15);
    sfxDur = 2;
}

#define CBCD

static unsigned int incBcd(unsigned int n)
{
#ifdef CBCD
    // C way for bcd:
    n += 1u;
    if ((n & 0x000Fu) == 0x000Au) {
        n += 0x0006u;
    }
    if ((n & 0x00F0u) == 0x00A0u) {
        n += 0x0060u;
    }
    if ((n & 0x0F00u) == 0x0A00u) {
        n += 0x0600u;
    }
    if ((n & 0xF000u) == 0xA000u) {
        n += 0x6000u;
    }
#else
    //this uses 59 bytes of code instead of 83 bytes
    /* Packed 4-digit BCD: SED ADC #1 on the 16-bit value. */
    asm("sed");
    asm("clc");
    asm("ldy #%o", n);
    asm("lda (c_sp),y");
    asm("adc #1");
    asm("sta (c_sp),y");
    asm("iny");
    asm("lda (c_sp),y");
    asm("adc #0");
    asm("sta (c_sp),y");
    asm("cld");
#endif
    return n;
}

static unsigned char cellId(unsigned int xy)
{
    return (unsigned char)(playfield[xy] & CELL_ID_FILTER);
}

static void putTileRandomly(unsigned char tile)
{
    unsigned int xy;

    xy = (playerxy + 256u + rand512()) & MAP_WRAP;
    if (cellId(xy) != TILE_BLANK) {
        return;
    }
    playfield[xy] = tile;
}

static void splatMonster(unsigned int xy)
{
    if (playfield[xy]) {
        if (monsterCount) {
            --monsterCount;
        }
    }
    playfield[xy] = TILE_BLOOD;
    addScore(1);
}

static void cheatScroll(void)
{
    unsigned int dest = (playerxy + RIGHTDELTA) & MAP_WRAP;
    unsigned char hit = cellId(dest);

    if ((hit == TILE_PATROL || hit == TILE_SEEKER) && monsterCount) {
        --monsterCount;
    }
    playfield[dest] = TILE_SCROLL;
}

static void pokeBcd4(unsigned int base, unsigned int n)
{
    unsigned char d;

    d = (unsigned char)(n >> 12);
    POKE(SCREEN + base + 0, (unsigned char)(48u + d));
    POKE(COLOR + base + 0, COLOR_WHITE);
    d = (unsigned char)((n >> 8) & 0x0Fu);
    POKE(SCREEN + base + 1, (unsigned char)(48u + d));
    POKE(COLOR + base + 1, COLOR_WHITE);
    d = (unsigned char)((n >> 4) & 0x0Fu);
    POKE(SCREEN + base + 2, (unsigned char)(48u + d));
    POKE(COLOR + base + 2, COLOR_WHITE);
    d = (unsigned char)(n & 0x0Fu);
    POKE(SCREEN + base + 3, (unsigned char)(48u + d));
    POKE(COLOR + base + 3, COLOR_WHITE);
}

static void drawHud(void)
{
    unsigned int base;

    cclearxy(0, HUD_ROW, COLS);
    base = (unsigned int)HUD_ROW * COLS + HUD_COL;
    POKE(SCREEN + base + 0, 83);
    POKE(COLOR + base + 0, COLOR_YELLOW);
    POKE(SCREEN + base + 1, 58);
    POKE(COLOR + base + 1, COLOR_YELLOW);
    pokeBcd4(base + 2, score);

    POKE(SCREEN + base + 7, HEART_CODE);
    POKE(COLOR + base + 7, COLOR_RED);
    POKE(SCREEN + base + 8, 58);
    POKE(COLOR + base + 8, COLOR_YELLOW);
    POKE(SCREEN + base + 9, (unsigned char)(48u + lives));
    POKE(COLOR + base + 9, COLOR_WHITE);

    POKE(SCREEN + base + 11, 76);
    POKE(COLOR + base + 11, COLOR_YELLOW);
    POKE(SCREEN + base + 12, 58);
    POKE(COLOR + base + 12, COLOR_YELLOW);
    POKE(SCREEN + base + 13, (unsigned char)liveLevel>LEVEL_COUNT ? 30 : (48u + (unsigned char)(liveLevel)));
    POKE(COLOR + base + 13, COLOR_WHITE);

    if (hasKey) {
        POKE(SCREEN + base + 14, mapToTile(TILE_KEY));
        POKE(COLOR + base + 14, tileColor(TILE_KEY));
    }

    cclearxy(0, HISCORE_ROW, COLS);
    base = (unsigned int)HISCORE_ROW * COLS + HISCORE_COL;
    POKE(SCREEN + base + 0, 72);
    POKE(COLOR + base + 0, COLOR_YELLOW);
    POKE(SCREEN + base + 1, 73);
    POKE(COLOR + base + 1, COLOR_YELLOW);
    POKE(SCREEN + base + 2, 58);
    POKE(COLOR + base + 2, COLOR_YELLOW);
    pokeBcd4(base + 3, hiscore);
}

static void addScore(unsigned char n)
{
    while (n) {
        --n;
        if (score != 0x9999u) {
            score = incBcd(score);
            if (lives < 9 && ((score & 0x00FFu) == 0x0050u || (score & 0x00FFu) == 0x0099u)) {
                ++lives;
            }
        }
    }
    drawHud();
}

static void hurtPlayer(void)
{
    if (hurtDur) {
        return;
    }
    if (lives) {
        --lives;
        drawHud();
    }
    hurtDur = 10;
    playHurt();
}

static void startLevel(void)
{
    unsigned char idx = mapIndexOf();

    unpackMap(idx);
    playerxy = playerStart[idx];
    playfield[playerxy] = TILE_PLAYER;
    monsterCount = 0;
    bulletRange = 0;
    jumpptr = 0;
    hasKey = 0;
    facing = UPDIR;
    liveLevel = mapIndex + 1u;
    syncView();
    if (!firstMap) {
        addScore(1);
    } else {
        drawHud();
    }
    firstMap = 0;
    for (idx = 0; idx<32 && idx <= liveLevel; ++idx) {
        putTileRandomly(TILE_BOMB); /* PLEASE KEEP */
        #ifdef SCROLLS
        putTileRandomly(TILE_TREE); /* PLEASE KEEP */
        #endif
    }
}

static void startRun(void)
{
    score = 0;
    lives = 5;
    mapIndex = 0;
    firstMap = 1;
    jumpptr = 0;
    pendingLevel = 0;
    quitRun = 0;
    hurtDur = 0;
    restoreStoryLine();
    startLevel();
    gotoxy(6, 10);
    cputs(PRESS_KEY);
    waitFireOrKey();
    drawNewLevelMsg();
}

static void spawnMonster(void)
{
    unsigned int xy;
    unsigned char id;
    unsigned char packed;

    if (monsterCount >= (liveLevel << 2)+1) { //L1: 5, L2:9 L3: 13 etc... 
        return;
    }
    id = (unsigned char)((monsterCount & 3u) ? TILE_PATROL : TILE_SEEKER);
    xy = (playerxy + 256u + ( rand512())) & MAP_WRAP;
    if (cellId(xy) != TILE_BLANK) {
        return;
    }
    packed = (unsigned char)(id | (DOWNDIR << 4) );
    playfield[xy] = packed;
    ++monsterCount;
    #ifdef SCROLLS
    putTileRandomly(TILE_TREE);
    #endif
}

static void drawHelpLine(void)
{
    cclearxy(0, HELP_ROW, COLS);
    gotoxy(HELP_COL, HELP_ROW);
    cputs(HELP_TEXT);
}

static void restoreStoryLine(void)
{
    cclearxy(0, STORY_ROW, COLS);
    gotoxy(0, STORY_ROW);
    cputs(STORY_TITLE);
    cclearxy(0, AUTHOR_ROW, COLS);
    gotoxy(0, AUTHOR_ROW);
    cputs(STORY_AUTHOR);
}

static void pauseRun(void)
{
    silenceVic();
    gotoxy(8, HUD_ROW + 1);
    cputs("Paused");
    while (GETKEY() == KEY_P) {
    }
    while (GETKEY() != KEY_P) {
    }
    while (GETKEY() == KEY_P) {
    }
    cclearxy(0, HUD_ROW + 1, COLS);
    if (pendingLevel) {
        drawNewLevelMsg();
    }
}

static void moveBullet(void)
{
    unsigned int dest;
    unsigned char hit;

    if (!bulletRange) {
        return;
    }

    dest = (bulletxy + dirDelta[bulletDir]) & MAP_WRAP;
    if (bulletxy != playerxy && cellId(bulletxy) == TILE_BULLET) {
        playfield[bulletxy] = 0; //erase bullet
    }

    hit = cellId(dest);
    --bulletRange;
    if( hit==TILE_PLAYER) {
        //ignore running into player
    }else if (hit != TILE_BLANK) {
        shootCell(dest, hit);
        bulletRange = 0;
    } else if (bulletRange) {
        playfield[dest] = TILE_BULLET;
        bulletxy = dest;
    }

    playfield[playerxy] = TILE_PLAYER;
}

static unsigned char seekerDir(unsigned int pos)
{
    unsigned int diff;
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

static unsigned char tryMove(unsigned int src, unsigned int dest, unsigned char packed)
{
    if (!destBlank(dest)) {
        return 0;
    }
    playfield[dest] = packed;
    playfield[src] = 0;
    return 1;
}

//#define DEBUG
#ifdef DEBUG
static void debugShow(unsigned char n)
{
    static unsigned offset=0;
    unsigned char hi = (unsigned char)(n >> 4);
    unsigned char lo = (unsigned char)(n & 0x0Fu);
    unsigned int loc=SCREEN + (ROWS - 1) * COLS;
    unsigned int cloc=COLOR + (ROWS - 1) * COLS;
    loc+=offset;
    cloc+=offset;
    POKE(loc, (unsigned char)(hi < 10u ? (48u + hi) : (1u + hi - 10u)));
    POKE(cloc, COLOR_WHITE+(offset&2));
    POKE(loc + 1u, (unsigned char)(lo < 10u ? (48u + lo) : (1u + lo - 10u)));
    POKE(cloc + 1u, COLOR_WHITE+(offset&2));
    offset=(offset+2) & 15;
}
#endif

static void pumpVideo(void)
{
    unsigned char jiffy = GETJIFFY();

    if (((64u & jiffy) == 0) != charBank) {
        charBank = !charBank;
    }
    drawView();
    if (pendingLevel) {
        drawNewLevelMsg();
    }
}

static void waitFrames(unsigned char n)
{
    while (n) {
        while(VIC.rasterline!=2){}
        while(VIC.rasterline!=1){}
        --n;
        pumpVideo();
        playAudioFrame();
    }
}

static void initVideo(void)
{
    POKE(VIC_COLS, PEEK(VIC_COLS) & 0x7F);
    POKE(CURSOR_FLAG, 1);
    POKE(JOY_DDRB, PEEK(JOY_DDRB) & (unsigned char)~JOY_RIGHT);

    bgcolor(COLOR_BLACK);
    bordercolor(COLOR_BLACK);
    textcolor(COLOR_CYAN);

    clrscr();
    gotoxy(0, 0);
    cputs(COPYRIGHT);
    restoreStoryLine();
    initCharset();
    drawHud();
    drawHelpLine();
}

static void warpLevels(void)
{
    unsigned char ddr;
    unsigned char char1, char2;
    silenceVic();
    /* $9122 bit 7 is an input for joystick right, so the Kernal never
       strobes keyboard column 7 (2, 4, 6, 8, 0). Drive it for this prompt. */
    ddr = PEEK(JOY_DDRB);
    POKE(JOY_DDRB, ddr | JOY_RIGHT);
    gotoxy(0, HUD_ROW);
    cputs("Secret Code: ??    ");
    gotoxy(13, HUD_ROW);
    char1 = readPetscii();
    cputc(upperGlyph(char1));
    char2 = readPetscii();
    cputc(upperGlyph(char2));
    POKE(JOY_DDRB, ddr);
    //char1 becomes the entered code
    if( char1=='x' && char2=='y'){
        cheatScroll();
    }
    char1 = (char)((hexNibble(char1) << 4) | hexNibble(char2));
    if(char1!=0){
        unsigned char level;
        rng = CRC;
        for (level = 0; level < 255u && rng != char1; ++level) {
            rand8();
        }
        if (level<LEVEL_COUNT) {
            gotoxy(0, HUD_ROW);
            mapIndex = level;
            pendingLevel = 1;
            cputs("WARPING TO LEVEL!!!");
            putHex((unsigned char)(mapIndex + 1u));
        } else {
            gotoxy(0, HUD_ROW);
            cputs("Sorry wrong code...");
            putHex(char1);
        }
    }
    simpleWaitFrames(60);
    drawHud();
}

static void gameStep(void)
{
    if (GETKEY() == KEY_Q) {
        quitRun = 1;
        return;
    }
    if (GETKEY() == KEY_P) {
        pauseRun();
        return;
    }
    if (GETKEY() == KEY_W){
        warpLevels();
        return;
    }
    spawnMonster();
    #ifdef SCROLLS
        ++frame;
        if( running==MAX_RUNNING || (frame & 1)){
             movePlayer();
        }
    #else
        if((++frame) & 1) movePlayer();
    #endif
    moveBullet();
    moveMonsters();
}

int main(void)
{
    viewxy = 0;
    playerxy = PLAYER_START;
    jumpptr = 0;
    blockspot = 0;
    rng = rng16 = 1;
    score = 0;
    hiscore = 0;
    lives = 5;
    liveLevel = 1;
    mapIndex = 0;
    facing = DOWNDIR;
    firstMap = 1;
    hurtDur = 0;
    silenceVic();
    unpackMap(0);
    playfield[playerxy] = TILE_PLAYER;
    syncView();

    initVideo();
    gotoxy(6, 4);
    cputs(VERSION);
    gotoxy(COLS/2-4,5);
    cputs("W to Warp");    

    for (;;) {
        startRun();
        for (;;) {
            if (pendingLevel) {
                waitFrames(WAIT_FRAMES);
                startLevel();
                pendingLevel = 0;
                cclearxy(0, HUD_ROW + 1, COLS);
                restoreStoryLine();
            }
            if (!lives) {
                if (score > hiscore) {
                    hiscore = score;
                    drawHud();
                }
                gotoxy(6, HUD_ROW + 1);
                cputs("Game Over!");
                silenceVic();
                waitFrames(WAIT_FRAMES);
                cclearxy(0, HUD_ROW + 1, COLS);
                restoreStoryLine();
                break;
            }
            if (quitRun) {
                silenceVic();
                restoreStoryLine();
                break;
            }
            pumpVideo();
            playAudioFrame();
            gameStep();
        }
    }
}

#endif
