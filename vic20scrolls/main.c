/*
* VIC-20 +32K Scrolls (cc65).
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

#define VIEW_W       11
#define VIEW_H       11
#define HELP_TEXT    "Joy or Shift ijlm"
#define HELP_LEN     19

#define NDX          0xC6u  /* Kernal: keyboard buffer count */
#define KEY_I        12
#define KEY_J        20
#define KEY_L        21

#define TF_SMOOSH    4

static char* COPYRIGHT="Scrolls(c)1996 CBusch";
static unsigned char mapIndex;
static unsigned char liveLevel;

#define SCROLLS 1

#include "../vic20engine/engine.h"

static const unsigned char tileFlags[16] = {
    0 | TF_SMOOSH,                          /* blank */
    TF_SOLID,                               /* player (map X start, P humans) */
    TF_SOLID,                               /* scroll */
    TF_SOLID ,                              /* lava */
               TF_SHOOTABLE | TF_SMOOSH,    /* stain */
    TF_SOLID,                               /* key */
    TF_SOLID | TF_SHOOTABLE | TF_SMOOSH,    /* patrol (map tile falls) */
    TF_SOLID | TF_SHOOTABLE | TF_SMOOSH,    /* seeker */
    TF_SHOOTABLE |            TF_SMOOSH,    /* bomb */
    0,                                       /* cloud / bullet pic (B) */
    TF_SOLID | TF_SHOOTABLE | TF_SMOOSH,    /* falling wall (t) */
    TF_SOLID,                               /* brick */
    TF_SOLID,                               /* door */
    0,                                      /* coin */
    TF_SOLID | TF_SHOOTABLE,                /* wall */
    0                                       /* unused slot 15 */
};

static void playEmptyClick(void)
{
    POKE(VIC_SOPRANO, 0);
    POKE(VIC_ALTO, 0);
    POKE(VIC_BASS, 0);
    POKE(VIC_NOISE, 240);       // High-frequency noise spike
    POKE(VIC_VOLUME, 0x0F);
    sfxDur = 1;                 // Keep duration at 1 frame for a tight snap
}

static void playClick2(void)
{
    POKE(VIC_BASS, 200);
    POKE(VIC_ALTO, 0);
    POKE(VIC_NOISE, 0);
    POKE(VIC_SOPRANO,0);
    POKE(VIC_VOLUME, 6);
    sfxDur = 1;
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
    if( hit == TILE_PATROL){
        playfield[dest]=TILE_SEEKER; //MONSTER GETS MAD
        return;
    }else if (hit == TILE_SEEKER) {
        splatMonster(dest);
        playKill();
        return;
    }
    playfield[dest] = TILE_BLOOD;
    if (hit == TILE_BOMB) {
        addScore(1);
        playKill();
        putTileRandomly(TILE_TREE);
    }else if(hit==TILE_TREE || TILE_WALL){
        playBash();
    }
}

static void moveMonsters(void) //FLAT
{
    unsigned char steps;
    unsigned char id;
    unsigned char dir;
    unsigned char packed;
    unsigned int dest;

    steps=0;
    while (steps<SPOT_STEPS
        && VIC.rasterline != RASTER_OFF_EARLY
        && VIC.rasterline != RASTER_OFF
    ) {
        steps++;
        spotxy = (spotxy + SPOT_STRIDE) & MAP_WRAP;
        id = (unsigned char)(playfield[spotxy] & CELL_ID_FILTER);

        if (id == TILE_PATROL || id == TILE_SEEKER) {
            if (id == TILE_PATROL) {
                dir = (unsigned char)((playfield[spotxy] >> 4) & 3u);
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            } else { //seeker
                dir = seekerDir(spotxy);
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            }
            if(cellId(dest)!=TILE_BLANK && cellId(dest)!=TILE_PLAYER){ //COLLISION
                dir = randDir(); //pick a new dir
                dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            }
            packed = (unsigned char)(id | (dir << 4));
            if (cellId(dest) == TILE_PLAYER) {
                hurtPlayer();
                playfield[spotxy] = packed;
            }else if(cellId(dest) == TILE_TREE){
                playfield[dest] = TILE_BOMB;
                playfield[spotxy] = packed;
            } else if (tryMove(spotxy, dest, packed)) {
            } else {
                playfield[spotxy] = packed; //remember the dir
            }
        } else if( id==TILE_BOMB ){
            dir=randDir();
            dest = (spotxy + dirDelta[dir]) & MAP_WRAP;
            tryMove(spotxy, dest, id);
        }
        // else if ( tileFlags[id] & TF_FALLING) {
        //     dest = (spotxy + DOWNDELTA) & MAP_WRAP;
        //     tryMove(spotxy, dest, id);
        // }
    }
    #ifdef DEBUG
    debugShow(steps);
    #endif
}

static char fireHolds=0;

//#define FIRES_BEFORE_MOVE 4
#define BULLET_RANGE 6
#define MAX_BULLETS (BULLET_RANGE+BULLET_RANGE)

static void movePlayer(void){
    unsigned char key;
    unsigned char pa;
    unsigned char pb;
    unsigned char shooting;
    unsigned char upHeld;
    unsigned char downHeld;
    unsigned char leftHeld;
    unsigned char rightHeld;

    unsigned char hit;

    unsigned int dest;
    unsigned int hl;
    unsigned int old;


    key = GETKEY();
    pa = PEEK(JOY_PA);
    pb = PEEK(JOY_PB);
    {
        unsigned char sh = PEEK(SHFLAG);
        shooting = (unsigned char)((pa & JOY_BTN) == 0 || (sh & SHIFT));
        if(shooting){
            if(fireHolds<MAX_BULLETS) fireHolds++;
        }else if(fireHolds>0){
            fireHolds >>= 2;
        }
    }
    upHeld = (unsigned char)((pa & JOY_UP) == 0 || (key == KEY_I));
    downHeld = (unsigned char)(key == KEY_M || (pa & JOY_DOWN) == 0);
    leftHeld = (unsigned char)(key == KEY_J || (pa & JOY_LEFT) == 0);
    rightHeld = (unsigned char)(key == KEY_L || (pb & JOY_RIGHT) == 0);



    hl = 0;



    if (downHeld) {
        if (!shooting /*|| fireHolds>FIRES_BEFORE_MOVE*/) {
            hl = DOWNDELTA;
        }
        facing = DOWNDIR;
    }else if (upHeld) {
        facing = UPDIR;
        if (!shooting /*|| fireHolds>FIRES_BEFORE_MOVE*/) {
            hl = UPDELTA;
        }
    }

    if (rightHeld) {
        if (!shooting /*|| fireHolds>FIRES_BEFORE_MOVE*/) {
            hl = RIGHTDELTA;
        }
        facing = RIGHTDIR;
    }else if (leftHeld) {
        facing = LEFTDIR;
        if (!shooting /*|| fireHolds>FIRES_BEFORE_MOVE*/) {
            hl = LEFTDELTA;
        }
    }
    dest = (playerxy + hl) & MAP_WRAP;
    hit = cellId(dest);
    if (hl != 0 && !(tileFlags[hit] & TF_SOLID)) {
        old = playerxy;
        playerxy = dest;
        playfield[dest] = TILE_PLAYER;
        playfield[old] = 0;
    }

    if (shooting && !bulletRange) {
        bulletxy = playerxy;
        bulletDir = facing;
        if(fireHolds==BULLET_RANGE + BULLET_RANGE){
            playEmptyClick();
        }else if( (fireHolds>>1)<BULLET_RANGE) {
            bulletRange = BULLET_RANGE-(fireHolds>>1);
        }else{
            if(!sfxDur){
                playClick2();
            }
        }
    }

    if (hit == TILE_PATROL || hit == TILE_SEEKER) {
        hurtPlayer();
        syncView();
        return;
    }else if (hit == TILE_TREE) {
        putTileRandomly(TILE_TREE);
        addScore(1);
        playfield[dest] = TILE_COIN;
        playCoin();
        syncView();
        return;
    }else if (hit == TILE_COIN) { // coin is not solid so it is erased in one step
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
    }else if ( hit==TILE_BULLET && !bulletRange){
        {
            unsigned int bdest;
            unsigned char bhit;
            bdest=(dest+dirDelta[facing]) & MAP_WRAP;
            bhit=cellId(bdest);
            if(tileFlags[bhit] & TF_SMOOSH){
                playfield[dest] = TILE_BLANK;
                playfield[bdest] = TILE_BULLET;
                if(bhit == TILE_SEEKER || bhit==TILE_PATROL || bhit==TILE_TREE || bhit==TILE_BOMB){
                    playCoin();
                    addScore(1);
                    if(bhit == TILE_SEEKER || bhit==TILE_PATROL) {
                        if(monsterCount) --monsterCount;
                        playKill();
                    }
                }
            }else{
                //let's see if we can place it behind the player
                bdest=old;
                bhit=cellId(bdest);
                if(tileFlags[bhit] & TF_SMOOSH){ //NOT DRY
                    playfield[dest] = TILE_BLANK;
                    playfield[bdest] = TILE_BULLET;
                    if(bhit == TILE_SEEKER || bhit==TILE_PATROL || bhit==TILE_TREE || bhit==TILE_BOMB){
                        playCoin();
                        addScore(1);
                        if(bhit == TILE_SEEKER || bhit==TILE_PATROL) {
                            if(monsterCount) --monsterCount;
                            playKill();
                        }
                    }
                }
            }
            playfield[playerxy]=TILE_PLAYER;
        }
    }

    syncView();
}
