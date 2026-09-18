/*
* VIC-20 +32K Caves (cc65).
* 12x8 viewport on a wrapping 1024-cell playfield from CASTLE.LVL.
* (c) 1996 by Chris Busch All Rights Reserved
* No warranties expressed or implied.
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
#define ROWS         23
#define STORY_ROW    1
#define AUTHOR_ROW   2
#define VIEW_W       12
#define VIEW_H       8
#define VIEW_COL     5
#define VIEW_ROW     4
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
#define HELP_TEXT    "Joy or Shift C= M,."
#define HELP_LEN     19
#define HELP_COL     ((COLS - HELP_LEN) / 2)
#define MAP_CELLS    1024u
#define MAP_WRAP     1023u
#define JUMP_LEN     3
#define HEART_ROM    83
#define HEART_CODE   95
//cannot exceed 255 and must be below 480 due to double hops
#define SPOT_STEPS   100
#define SPOT_STRIDE  239

#define RASTER_OFF_EARLY   123
#define RASTER_OFF   126


#define VIC_COLS     0x9002u
#define CURSOR_FLAG  0xCCu

#define CHARSET     5120u

#define LSTX         0xC5u
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


/* tileFlags[id]: bit0 solid, bit1 shootable, bit2 falling */
// originally called noerasebit, killablebit, and fallingbit in the z80 code
#define TF_SOLID     1
#define TF_SHOOTABLE 2
#define TF_FALLING   4

/* playfield[xy]: bits 0-3 id, 4-5 dir, 6 spawned, 7 unused */
// PLAYFIELD FLAGS: 0-3(TILD ID) 4(direction) 5(direction) 6(spawned) 7(unused)
#define PF_SPAWNED   0x40u
#define WAIT_FRAMES  12


static unsigned char playfield[1024];
static unsigned int viewxy;
static unsigned int spotxy;
static unsigned int playerxy;
static unsigned int blockspot;
static unsigned int monsterCount;
static unsigned int mapIndex;
static unsigned int liveLevel;
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


#define UPDELTA ((unsigned int)-32)
#define RIGHTDELTA ((unsigned int)1)
#define DOWNDELTA ((unsigned int)32)
#define LEFTDELTA ((unsigned int)-1)

#define LEFTDIR      0
#define RIGHTDIR     1
#define UPDIR        2
#define DOWNDIR      3

static const unsigned int dirDelta[4] = {
    LEFTDELTA,RIGHTDELTA,UPDELTA,DOWNDELTA
};

static const unsigned char tileFlags[16] = {
    0,                                      /* blank */
    TF_SOLID,                               /* player (map X) */
    TF_SOLID,                               /* scroll */
    TF_SOLID,                               /* lava */
    TF_FALLING,                             /* stain */
    TF_SOLID,                               /* key */
    TF_SOLID | TF_SHOOTABLE | TF_FALLING,   /* patrol (map tile falls) */
    TF_SOLID | TF_SHOOTABLE,                /* seeker */
    TF_SHOOTABLE | TF_FALLING,              /* bomb */
    TF_SOLID,                               /* cloud / bullet pic */
    TF_SOLID | TF_SHOOTABLE | TF_FALLING,   /* falling wall (t) */
    TF_SOLID,                               /* brick */
    TF_SOLID | TF_FALLING,                  /* door */
    TF_FALLING,                             /* coin */
    TF_SOLID | TF_SHOOTABLE,                /* wall */
    0                                       /* unused slot 15 */
};

static unsigned char tileColors[16] = {
    COLOR_BLACK, COLOR_YELLOW, COLOR_WHITE, COLOR_BLUE,     /* . X s f */
    COLOR_RED, COLOR_YELLOW, COLOR_PURPLE, COLOR_RED,      /* S k M m */
    COLOR_CYAN, COLOR_WHITE, COLOR_GREEN, COLOR_WHITE,      /* F B t b */
    COLOR_RED, COLOR_YELLOW, COLOR_WHITE, COLOR_BLACK       /* D c W (15) */
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

// static unsigned char mapToTile(unsigned char cell)
// {
//     return (unsigned char)(TILE_BASE + (charBank << 4) + (cell & 0x0Fu));
// }

#define mapToTile(cell) ((unsigned char)(TILE_BASE + (charBank << 4) + ((cell) & 0x0Fu)))

// static unsigned char tileColor(unsigned char cell)
// {
//     cell = (unsigned char)(cell & 0x0Fu);
//     if (cell == TILE_PLAYER && hurtDur) {
//         return COLOR_PURPLE;
//     }
//     return tileColors[cell];
// }

#define tileColor(cell) (tileColors[(unsigned char)((cell) & 0x0Fu)])

static void waitVrefresh(void)
{
    /* $9004 is raster/2. Spin only while the beam is still on the view;
    * if already past RASTER_OFF, draw immediately. */
    // while (VIC.rasterline < RASTER_OFF) {
    // }
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

    waitVrefresh();
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

static unsigned int rand16(void)
{
    //rng16 = (unsigned int)(rng16 * 17u + 1u);
    //use linear feedback shift register instead
    rng16=(rng16>>1) ^ ((rng16 & 1)? 0xD008u : 0u);
    return rng16;
}

static void waitFireOrKey(void)
{
    while(VIC.rasterline!=50){
        rand16();
    }
    while(VIC.rasterline!=49){
        rand8();
    }
    for (;;) {
        rand8();
        rand16();
        if (GETKEY() != KEY_NONE || (PEEK(JOY_PA) & JOY_BTN) == 0 ||
            (PEEK(SHFLAG) & SHIFT)) {
            return;
        }
    }
}



// static unsigned char randDir(void)
// {
//     return (unsigned char)((rand8()>>2) & 3u);
// }

#define randDir() ((unsigned char)((rand8()) & 3u))

static unsigned char randHorizDir(void)
{
    return (unsigned char)((rand8() & 1u) ? LEFTDIR : RIGHTDIR);
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


static void playHurt(void)
{
    POKE(VIC_BASS, 140);
    POKE(VIC_ALTO, 155);
    POKE(VIC_NOISE, 200);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_VOLUME, 15);
    sfxDur = 2;
}

static void drawHud(void);

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



static void addScore(unsigned char n)
{
    while (n) {
        --n;
        if (score != 0x9999u) {
            score = incBcd(score);
            if ((score & 0x00FFu) == 0x0050u && lives < 9) {
                ++lives;
            }
        }
    }
    drawHud();
}


static unsigned char cellId(unsigned int xy)
{
    return (unsigned char)(playfield[xy] & 0x0Fu);
}

static void splatMonster(unsigned int xy)
{
    if (playfield[xy] & PF_SPAWNED) {
        if (monsterCount) {
            --monsterCount;
        }
    }
    playfield[xy] = TILE_BLOOD;
    addScore(1);
}


static void putBomb(){
    unsigned int xy;
    xy = (playerxy + 256u + ( rand512())) & MAP_WRAP;
    if (cellId(xy) != TILE_BLANK) {
        return;
    }
    playfield[xy] = TILE_BOMB;
}

static void cheatScroll(void)
{
    unsigned int dest = (playerxy + RIGHTDELTA) & MAP_WRAP;
    unsigned char hit = cellId(dest);

    if ((hit == TILE_PATROL || hit == TILE_SEEKER) &&
        (playfield[dest] & PF_SPAWNED) && monsterCount) {
        --monsterCount;
    }
    playfield[dest] = TILE_SCROLL;
}

static void shootCell(unsigned int dest, unsigned char hit)
{
    if (hit == TILE_BLOOD) {
        playfield[dest] = 0;
        return;
    }
    if (!(tileFlags[hit] & TF_SHOOTABLE)) {
        return;
    }
    if (hit == TILE_PATROL || hit == TILE_SEEKER) {
        splatMonster(dest);
        playKill();
        return;
    }
    playfield[dest] = TILE_BLOOD;
    if (hit == TILE_BOMB) {
        addScore(1);
        playKill();
        putBomb();
    }else if(hit==TILE_TREE || TILE_WALL){
        playBash();
    }
}

static void hurtPlayer(void)
{
    if (sfxDur) {
        return;
    }
    if(hurtDur) return;
    if (lives) {
        --lives;
        drawHud();
    }
    hurtDur = 10;
    playHurt();
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
    POKE(SCREEN + base + 13, (unsigned char)(48u + (unsigned char)(liveLevel & 7)));
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

static void drawNewLevelMsg(void)
{
    gotoxy(HUD_COL, HUD_ROW + 1);
    cputs("New Level!");
}

static void pauseRun(void)
{
    silenceVic();
    gotoxy(HUD_COL, HUD_ROW + 1);
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
        putBomb(); /* PLEASE KEEP */
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
    gotoxy(5, 10);
    cputs("Press key!");
    waitFireOrKey();
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
        playfield[bulletxy] = 0;
    }

    hit = cellId(dest);
    --bulletRange;
    if (hit != TILE_BLANK) {
        shootCell(dest, hit);
        bulletRange = 0;
    } else if (bulletRange) {
        playfield[dest] = TILE_BULLET;
        bulletxy = dest;
    }

    playfield[playerxy] = TILE_PLAYER;
}




static void spawnMonster(void)
{
    unsigned int xy;
    unsigned char id;
    unsigned char packed;

    if (monsterCount >= (liveLevel << 2)) {
        return;
    }
    id = (unsigned char)((monsterCount & 1u) ? TILE_PATROL : TILE_SEEKER);
    xy = (playerxy + 256u + ( rand512())) & MAP_WRAP;
    if (cellId(xy) != TILE_BLANK) {
        return;
    }
    packed = (unsigned char)(id | (DOWNDIR << 4) | PF_SPAWNED );
    playfield[xy] = packed;
    ++monsterCount;
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


// static unsigned char destBlank(unsigned int dest)
// {
//     return (unsigned char)((playfield[dest] & 0x0Fu) == TILE_BLANK);
// }

#define destBlank(dest) ((unsigned char)((playfield[dest] & 0x0Fu) == TILE_BLANK))

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

static void moveMonsters(void)
{
    unsigned char steps;
    unsigned char id;
    unsigned char dir;
    unsigned char packed;
    unsigned int dest;

    // /* Beam is still >= 126 after drawView. Wait until it wraps. */
    // while (VIC.rasterline >= RASTER_OFF_EARLY) {
    // }
    // steps = SPOT_STEPS;
    steps=0;
    while (steps<SPOT_STEPS 
        && VIC.rasterline != RASTER_OFF_EARLY
        && VIC.rasterline != RASTER_OFF
    ) {
        steps++;
        spotxy = (spotxy + SPOT_STRIDE) & MAP_WRAP;
        id = (unsigned char)(playfield[spotxy] & 0x0Fu);

        if (id == TILE_PATROL || id == TILE_SEEKER) {
            if (id == TILE_PATROL) {
                dest = (spotxy + DOWNDELTA) & MAP_WRAP;
                if ((tileFlags[id] & TF_FALLING) && destBlank(dest)) {
                    dir = DOWNDIR;
                } else {
                    dir = (unsigned char)((playfield[spotxy] >> 4) & 3u);
                    dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
                }
            } else { //seeker
                dir = seekerDir(spotxy);
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            }
            if(cellId(dest)!=TILE_BLANK && cellId(dest)!=TILE_PLAYER){ //COLLISION
                if( id==TILE_PATROL) dir = dir==LEFTDIR ? RIGHTDIR:LEFTDIR;
                else dir = randDir(); //pick a new dir
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            }
            packed = (unsigned char)(id | (dir << 4));
            if (cellId(dest) == TILE_PLAYER) {
                hurtPlayer();
                playfield[spotxy] = packed;
            } else if (tryMove(spotxy, dest, packed)) {
            } else {
                playfield[spotxy] = packed; //remember the dir
            }
        } else if( id==TILE_BOMB ){
            dest = (spotxy + DOWNDELTA) & MAP_WRAP;
            if(!destBlank(dest)) {
                dir = randHorizDir();
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            }
            tryMove(spotxy, dest, id);
        } else if ( tileFlags[id] & TF_FALLING) {
            dest = (spotxy + DOWNDELTA) & MAP_WRAP;
            tryMove(spotxy, dest, id);
        }
    }
    #ifdef DEBUG
    debugShow(steps);
    #endif
}

static char alternate=0;

static void movePlayer(void){
    unsigned char key;
    unsigned char pa;
    unsigned char pb;
    unsigned char shooting;
    unsigned char jumpHeld;
    unsigned char downHeld;
    unsigned char leftHeld;
    unsigned char rightHeld;
    unsigned char below;
    unsigned char hit;
    unsigned char combinedId;
    unsigned int dest;
    unsigned int hl;
    unsigned int old;

    alternate++;

    key = GETKEY();
    pa = PEEK(JOY_PA);
    pb = PEEK(JOY_PB);
    {
        unsigned char sh = PEEK(SHFLAG);
        shooting = (unsigned char)((pa & JOY_BTN) == 0 || (sh & SHIFT));
        jumpHeld = (unsigned char)((pa & JOY_UP) == 0 || (sh & CBM));
    }
    downHeld = (unsigned char)(key == KEY_COMMA || (pa & JOY_DOWN) == 0);
    leftHeld = (unsigned char)(key == KEY_M || (pa & JOY_LEFT) == 0);
    rightHeld = (unsigned char)(key == KEY_PERIOD || (pb & JOY_RIGHT) == 0);



    /* stompMonsterBeneath */
    if (jumpptr == 0) {
        dest = (playerxy + DOWNDELTA) & MAP_WRAP;
        hit = cellId(dest);
        if (hit == TILE_PATROL || hit == TILE_SEEKER) {
            splatMonster(dest);
            addScore(1);
            playCoin();
        } else if (hit == TILE_BOMB) {
            playfield[dest] = TILE_BLOOD;
            addScore(1);
            playCoin();
            putBomb();
        }
    }

    if (shooting && !bulletRange) {
        bulletxy = playerxy;
        bulletDir = facing;
        bulletRange = 4;
    }

    hl = 0;
    if((alternate & 3) != 0){
        if(jumpptr==1){
            --jumpptr; //float a bit
        }else if (jumpptr != 0) {
            --jumpptr;
            hl = UPDELTA;
        } else {
            below = cellId((playerxy + DOWNDELTA) & MAP_WRAP);
            if (below == TILE_BLANK || below == TILE_FIRE) {
                hl = DOWNDELTA;
            } else {
                if (below == TILE_BULLET && !shooting && downHeld) {
                    jumpptr = 20;
                    playBounce();
                }
                if (jumpHeld && !shooting) {
                    jumpptr = JUMP_LEN;
                    hl = UPDELTA;
                }
            }
        }
    }
    if (downHeld) {
        if (!shooting) {
            hl = DOWNDELTA;
        }
        facing = DOWNDIR;
    }else if (jumpHeld) {
        facing = UPDIR;
    }

    if (rightHeld && !shooting) {
        facing = RIGHTDIR;
        dest = (playerxy + hl + RIGHTDELTA) & MAP_WRAP;
        combinedId = cellId(dest);
        if (combinedId != TILE_BRICK && combinedId != TILE_WALL &&
            combinedId != TILE_TREE) {
            hl += RIGHTDELTA;
        }
    } else if (rightHeld) {
        facing = RIGHTDIR;
    } else if (leftHeld && !shooting) {
        facing = LEFTDIR;
        dest = (playerxy + hl + LEFTDELTA) & MAP_WRAP;
        combinedId = cellId(dest);
        if (combinedId != TILE_BRICK && combinedId != TILE_WALL &&
            combinedId != TILE_TREE) {
            hl += LEFTDELTA;
        }
    } else if (leftHeld) {
        facing = LEFTDIR;
    }
    dest = (playerxy + hl) & MAP_WRAP;
    hit = cellId(dest);
    if (hl != 0 && !(tileFlags[hit] & TF_SOLID)) {
        old = playerxy;
        playerxy = dest;
        playfield[dest] = TILE_PLAYER;
        playfield[old] = 0;
    }

    if (hit == TILE_PATROL || hit == TILE_SEEKER) {
        hurtPlayer();
        syncView();
        return;
    }else if (hit == TILE_COIN) {
        addScore(1);
        playCoin();
        syncView();
        return;
    }else if (hit == TILE_FIRE) {
        hurtPlayer();
        playfield[playerxy] = TILE_BLOOD;
        if (lives) {
            playerxy = playerStart[mapIndexOf()];
            playfield[playerxy] = TILE_PLAYER;
        }
        syncView();
        return;
    }else if (hit == TILE_BOMB) {
        hurtPlayer();
        syncView();
        return;
    } else  if (hit == TILE_KEY && !hasKey) {
        hasKey = 1;
        playfield[dest] = 0;
        playCoin();
        drawHud();
        syncView();
        return;
    } else if (hit == TILE_DOOR && hasKey) {
        hasKey = 0;
        playfield[dest] = 0;
        playCoin();
        drawHud();
        syncView();
        return;
    } else  if (hit == TILE_SCROLL) {
        playfield[dest] = 0;
        addScore(1);
        playCoin();
        ++mapIndex;
        pendingLevel = 1;
        syncView();
        return;
    }
    // if ((hit == TILE_BRICK || hit == TILE_WALL || hit == TILE_TREE) && jumpptr) {
    //     //--jumpptr;
    // }

    syncView();
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
    if (GETKEY() == KEY_S && (PEEK(JOY_PA) & JOY_BTN) == 0 && (PEEK(SHFLAG) & SHIFT)) {
        cheatScroll();
    }
    spawnMonster();
    moveBullet();
    if((++frame) & 1) movePlayer();
    moveMonsters();
}

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
    cputs("Caves (c)1996 C Busch");
    restoreStoryLine();
    initCharset();
    drawHud();
    drawHelpLine();
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
                gotoxy(HUD_COL, HUD_ROW + 1);
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

