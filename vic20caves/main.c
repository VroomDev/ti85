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

// COMMODORE VIC20 22 columns by 23 rows

#define VIEW_W       13
#define VIEW_H       8
#define HELP_TEXT    "Joy or Shift C= M,."
#define HELP_LEN     19

#define TF_FALLING   4

static char* COPYRIGHT="Caves (c)1996 C Busch";
static unsigned int mapIndex;
static unsigned int liveLevel;

#define CAVES 1
#include "../vic20engine/engine.h"

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
        putTileRandomly(TILE_BOMB);
    }else if(hit==TILE_TREE || TILE_WALL){
        playBash();
    }
}

static unsigned char randHorizDir(void)
{
    return (unsigned char)((rand8() & 1u) ? LEFTDIR : RIGHTDIR);
}

static void moveMonsters(void)
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
static char aimOnlyMode=0;

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

    if(shooting && !downHeld && !leftHeld && !rightHeld && !jumpHeld) aimOnlyMode=1;
    if(!shooting) aimOnlyMode=0;

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
            putTileRandomly(TILE_BOMB);
        }
    }


    hl = 0;
    if((alternate & 1) != 0){
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
                if (below == TILE_BULLET && !aimOnlyMode && downHeld) {
                    jumpptr = 20;
                    playBounce();
                }
                if (jumpHeld && !aimOnlyMode) {
                    jumpptr = JUMP_LEN;
                    hl = UPDELTA;
                }
            }
        }
    }
    if (downHeld) {
        if (!aimOnlyMode) {
            hl = DOWNDELTA;
        }
        facing = DOWNDIR;
    }else if (jumpHeld) {
        facing = UPDIR;
    }

    if (rightHeld && !aimOnlyMode) {
        facing = RIGHTDIR;
        dest = (playerxy + hl + RIGHTDELTA) & MAP_WRAP;
        combinedId = cellId(dest);
        if (combinedId != TILE_BRICK && combinedId != TILE_WALL &&
            combinedId != TILE_TREE) {
            hl += RIGHTDELTA;
        }
    } else if (rightHeld) {
        facing = RIGHTDIR;
    } else if (leftHeld && !aimOnlyMode) {
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

    if (shooting && !bulletRange) {
        bulletxy = playerxy;
        bulletDir = facing;
        bulletRange = 4;
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

    syncView();
}
