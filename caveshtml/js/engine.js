import {
  blankid,
  bloodid,
  bombid,
  brickid,
  BRICK_BASE,
  bulletid,
  BULLET_RANGE,
  coinid,
  DIR_DELTA,
  doorid,
  FALLING,
  fireid,
  FIRST_LVL_MONST,
  JUMP_LEN,
  K_DOWN,
  K_LEFT,
  K_NOKEY,
  K_RIGHT,
  K_UP,
  keyid,
  KILLABLE,
  LEVEL_SIZE,
  LEVEL_W,
  MONSTER_MAX,
  monster1id,
  monster2id,
  monsters,
  NOERASE,
  playerid,
  scrollid,
  SECOND_LVL_MONST,
  tileId,
  wrapMap,
} from "./tiles.js";

const PLAY_KEY = 1;
const PLAY_SCROLL = 0;
const PLAY_ISPLAYER = 2;

function sprite() {
  return { xy: 0, id: 0, mv: 0, hp: 0, dir: K_NOKEY };
}

export function createEngine(pack) {
  const map = new Uint8Array(LEVEL_SIZE);
  const player = sprite();
  const bullet = sprite();
  const monstersA = Array.from({ length: MONSTER_MAX }, sprite);
  let frame = 0;
  let delay = 0;
  let jumpptr = 0;
  let pdir = K_RIGHT;
  let playmode = 0;
  let health = 9; // ASCII '0'.. ; stored as 0-9 digit value
  let score = 0;
  let hiscore = Number(localStorage.getItem("caveshtml.castle.hiscore") || 0);
  let levelIdx = 0; // initlevel index before CENGINE's post-increment
  let liveLevel = 0; // CENGINE `level` after increment (1-based for monster counts)
  let spawn = 0;
  let blockspot = 0;
  let overlay = null; // { kind, text }
  let paused = false;
  let showMap = false;
  let flash = 0;
  let newHiscore = false;
  let sfx = [];

  function emitSfx(name) {
    sfx.push(name);
  }

  function drainSfx() {
    const out = sfx;
    sfx = [];
    return out;
  }

  function randInt(n) {
    return Math.floor(Math.random() * n);
  }

  function randDir4() {
    return randInt(4) + 1;
  }

  function rand100() {
    return randInt(100);
  }

  function at(off) {
    return map[wrapMap(off)];
  }

  function setAt(off, v) {
    map[wrapMap(off)] = v;
  }

  function wrapLevel(idx) {
    const n = pack.levels.length;
    if (!n) return 0;
    return ((idx % n) + n) % n;
  }

  function loadLevel(idx) {
    const src = pack.levels[wrapLevel(idx)];
    if (!src) return;
    map.set(src.tiles);
    spawn = src.spawn;
    player.xy = spawn;
    player.id = playerid;
    player.hp = 1;
    map[spawn] = playerid;
    bullet.dir = K_NOKEY;
    bullet.hp = 0;
    bullet.xy = 0;
    for (const m of monstersA) m.hp = 0;
    jumpptr = 0;
    pdir = K_RIGHT;
    playmode = 0;
    overlay = null;
    flash = 0;
  }

  function startPack() {
    score = 0;
    health = 9;
    levelIdx = 0;
    liveLevel = 0;
    newHiscore = false;
    startLevel();
  }

  function startLevel() {
    loadLevel(levelIdx);
    incScore();
    liveLevel = levelIdx + 1;
    const cap = monsterCap();
    for (let i = 0; i < cap; i++) initMonster(monstersA[i], 1 - (i & 1));
  }

  function beginFirstLevel() {
    score = 0xffff;
    health = 9;
    levelIdx = 0;
    startLevel();
    // incScore from FFFF → 0
  }

  function decHealth() {
    if (health > 0) health -= 1;
    flash = 8;
    emitSfx("hurt");
  }

  function incScore() {
    score = (score + 1) & 0xffff;
    if ((score & 31) === 31) {
      health = Math.min(9, health + 1);
    }
    if (score > hiscore) {
      hiscore = score;
      newHiscore = true;
      localStorage.setItem("caveshtml.castle.hiscore", String(hiscore));
    }
  }

  function checkSpot(ix, delta) {
    return at(ix.xy + delta);
  }

  function beneath(ix) {
    return checkSpot(ix, LEVEL_W);
  }

  function moveSpr(ix, dir) {
    const de = DIR_DELTA[dir];
    if (de == null) {
      lastHit = blankid;
      lastHitXy = ix.xy;
      return blankid;
    }
    const dest = wrapMap(ix.xy + de);
    lastHitXy = dest;
    lastHit = map[dest];
    const isPlayer = (playmode & (1 << PLAY_ISPLAYER)) !== 0;
    if (lastHit & NOERASE) return lastHit;
    if (!isPlayer && lastHit === coinid) return lastHit;
    const old = ix.xy;
    ix.xy = dest;
    map[dest] = ix.id;
    map[old] = blankid;
    return lastHit;
  }

  function eraseHit(hitxy) {
    setAt(hitxy, blankid);
  }

  function putBlood(hitxy) {
    setAt(hitxy, bloodid);
  }

  function fireBullet() {
    if (bullet.dir !== K_NOKEY) return;
    let d = pdir - 1;
    d = (d & 3) + 1;
    bullet.dir = d;
    bullet.hp = BULLET_RANGE;
    bullet.xy = player.xy;
    bullet.id = bulletid;
    emitSfx("fire");
  }

  function stopBullet() {
    bullet.dir = K_NOKEY;
    setAt(bullet.xy, blankid);
  }

  function moveBullet() {
    if (bullet.dir === K_NOKEY) {
      setAt(player.xy, playerid);
      return;
    }
    const hit = moveSpr(bullet, bullet.dir);
    const hitxy = lastHitXy;
    if (hit === bombid) incScore();
    if (hit & KILLABLE) {
      if (tileId(hit) < monsters) incScore();
      for (const m of monstersA) {
        if (m.hp === 0) continue;
        if (m.xy !== hitxy) continue;
        m.hp -= 1;
        if (m.hp === 0) putBlood(m.xy);
      }
      putBlood(hitxy);
    }
    if (hit !== blankid) stopBullet();
    bullet.hp -= 1;
    if (bullet.hp === 0) stopBullet();
    setAt(player.xy, playerid);
  }

  function dirTowardPlayer(m) {
    let dx = (player.xy & 31) - (m.xy & 31);
    let dy = (player.xy >> 5) - (m.xy >> 5);
    if (dx > 16) dx -= 32;
    else if (dx < -16) dx += 32;
    if (dy > 16) dy -= 32;
    else if (dy < -16) dy += 32;
    const horiz = dx > 0 ? K_RIGHT : dx < 0 ? K_LEFT : 0;
    const vert = dy > 0 ? K_DOWN : dy < 0 ? K_UP : 0;
    if (horiz && vert) return Math.random() < 0.5 ? horiz : vert;
    if (horiz) return horiz;
    if (vert) return vert;
    return randDir4();
  }

  function pickSeekerDir(m) {
    if (rand100() > 20 * liveLevel) return randDir4();
    return dirTowardPlayer(m);
  }

  function putBomb(dirA, xy) {
    let d = (dirA - 1) & 3;
    let de = 1;
    if (d === K_UP - 1) de = -1;
    else if (d === K_DOWN - 1) de = 1;
    else if (d === K_LEFT - 1) de = -1;
    else de = 1;
    const dest = wrapMap(xy + de);
    if (map[dest] === blankid) map[dest] = bombid;
  }

  function spawnSpots() {
    const px = player.xy & 31;
    const py = player.xy >> 5;
    const spots = [];
    for (let i = 0; i < LEVEL_SIZE; i++) {
      if (map[i] !== blankid) continue;
      let dx = Math.abs((i & 31) - px);
      let dy = Math.abs((i >> 5) - py);
      if (dx > 16) dx = 32 - dx;
      if (dy > 16) dy = 32 - dy;
      if (Math.max(dx, dy) < 2) continue;
      spots.push(i);
    }
    return spots;
  }

  function initMonster(m, forceKind) {
    const spots = spawnSpots();
    if (!spots.length) return;
    const start = spots[randInt(spots.length)];
    // forceKind (0 patrol / 1 seeker) when filling the level cap so both show.
    let seeker;
    if (forceKind === 0 || forceKind === 1) seeker = forceKind === 1;
    else seeker = Math.random() < 0.5;
    const id = seeker ? monster2id : monster1id;
    m.xy = start;
    m.id = id;
    m.mv = seeker ? 1 : 0;
    m.hp = 1;
    m.dir = K_DOWN;
    map[start] = id;
  }

  function monsterCap() {
    if (liveLevel === 1) return FIRST_LVL_MONST;
    if (liveLevel === 2) return SECOND_LVL_MONST;
    return MONSTER_MAX;
  }

  function moveMonsters() {
    const cap = monsterCap();
    for (let i = 0; i < cap; i++) {
      const m = monstersA[i];
      if (m.hp === 0) initMonster(m);
      if (m.hp === 0) continue;
      const seeker = (m.mv & 1) !== 0;
      if (seeker) {
        m.dir = pickSeekerDir(m);
      } else if (beneath(m) === blankid) {
        m.dir = K_DOWN;
      }
      const hit = moveSpr(m, m.dir);
      if (!seeker) {
        if (randInt(64) === 0) putBomb(randDir4(), m.xy);
        if (hit !== blankid) m.dir = randDir4();
      }
      if (hit === playerid) {
        decHealth();
        continue;
      }
      if (hit === fireid) {
        putBlood(m.xy);
        m.hp = 0;
      }
    }
  }

  function blockFall() {
    for (let n = 0; n < 32; n++) {
      blockspot = wrapMap(blockspot - 1);
      const c = map[blockspot];
      if (!(c & FALLING)) continue;
      const below = wrapMap(blockspot + LEVEL_W);
      if (map[below] !== blankid) continue;
      map[below] = c;
      map[blockspot] = blankid;
    }
  }

  function onPlayerHit(hit) {
    if (hit === coinid) {
      incScore();
      incScore();
      incScore();
      return;
    }
    if (hit === fireid) {
      decHealth();
      setAt(player.xy, bloodid);
      player.xy = spawn;
      return;
    }
    if (hit === bombid) {
      decHealth();
      return;
    }
    if (hit === keyid) {
      if (playmode & (1 << PLAY_KEY)) return;
      playmode |= 1 << PLAY_KEY;
      eraseHit(wrapMap(player.xy)); // original erases hitxy which is dest; player didn't move
      return;
    }
    if (hit === doorid) {
      if (!(playmode & (1 << PLAY_KEY))) return;
      playmode &= ~(1 << PLAY_KEY);
      eraseHit(wrapMap(/* hit cell */ 0));
      return;
    }
    if (hit === scrollid) {
      playmode |= 1 << PLAY_SCROLL;
      eraseHit(0);
      incScore();
      return;
    }
    if (tileId(hit) === BRICK_BASE && jumpptr) jumpptr -= 1;
  }

  /**
   * Player collision uses hitxy from failed or successful move.
   * We keep lastHit / lastHitXy from moveSpr.
   */
  let lastHit = blankid;
  let lastHitXy = 0;

  function moveSprTrack(ix, dir) {
    const de = DIR_DELTA[dir];
    if (de == null) {
      lastHit = blankid;
      lastHitXy = ix.xy;
      return blankid;
    }
    const dest = wrapMap(ix.xy + de);
    lastHitXy = dest;
    lastHit = map[dest];
    const isPlayer = (playmode & (1 << PLAY_ISPLAYER)) !== 0;
    if (lastHit & NOERASE) return lastHit;
    if (!isPlayer && lastHit === coinid) return lastHit;
    const old = ix.xy;
    ix.xy = dest;
    map[dest] = ix.id;
    map[old] = blankid;
    return lastHit;
  }

  function tryPlayerMove(input) {
    if (frame & 1) return;

    if (input.shoot()) fireBullet();

    let hl = 0;
    if (frame & 2) {
      if (jumpptr !== 0) {
        jumpptr -= 1;
        hl = -LEVEL_W;
      } else {
        const under = beneath(player);
        if (under === blankid || under === fireid) {
          hl = LEVEL_W;
        } else {
          if (under === bulletid && !input.shoot() && input.down()) {
            jumpptr = 20;
            emitSfx("chirp");
          }
          if (input.alpha() || (input.up() && !input.shoot())) {
            jumpptr = JUMP_LEN - 1;
            hl = -LEVEL_W;
          }
        }
      }
    }

    if (input.down()) {
      if (!input.shoot()) hl = LEVEL_W;
      pdir = K_DOWN;
    }
    if (input.up()) pdir = K_UP;

    if (input.right() && !input.shoot()) {
      pdir = K_RIGHT;
      const combined = wrapMap(player.xy + hl + 1);
      if (tileId(map[combined]) !== BRICK_BASE) hl += 1;
    } else if (input.right()) pdir = K_RIGHT;

    if (input.left() && !input.shoot()) {
      pdir = K_LEFT;
      const combined = wrapMap(player.xy + hl - 1);
      if (tileId(map[combined]) !== BRICK_BASE) hl -= 1;
    } else if (input.left()) pdir = K_LEFT;

    playmode |= 1 << PLAY_ISPLAYER;
    lastHitXy = wrapMap(player.xy + hl);
    lastHit = map[lastHitXy];
    if (hl !== 0 && !(lastHit & NOERASE)) {
      const old = player.xy;
      player.xy = lastHitXy;
      map[lastHitXy] = playerid;
      map[old] = blankid;
    }
    playmode &= ~(1 << PLAY_ISPLAYER);

    const hit = lastHit;
    if (hit === coinid) {
      incScore();
      incScore();
      incScore();
      emitSfx("coin");
      return;
    }
    if (hit === fireid) {
      decHealth();
      setAt(player.xy, bloodid);
      player.xy = spawn;
      return;
    }
    if (hit === bombid) {
      decHealth();
      return;
    }
    if (hit === keyid) {
      if (playmode & (1 << PLAY_KEY)) return;
      playmode |= 1 << PLAY_KEY;
      setAt(lastHitXy, blankid);
      emitSfx("coin");
      return;
    }
    if (hit === doorid) {
      if (!(playmode & (1 << PLAY_KEY))) return;
      playmode &= ~(1 << PLAY_KEY);
      setAt(lastHitXy, blankid);
      emitSfx("coin");
      return;
    }
    if (hit === scrollid) {
      setAt(lastHitXy, blankid);
      incScore();
      emitSfx("newlevel");
      levelIdx = wrapLevel(levelIdx + 1);
      startLevel();
      overlay = { kind: "newlevel", text: "New Level!" };
      return;
    }
    if (tileId(hit) === BRICK_BASE && jumpptr) jumpptr -= 1;
  }

  function tick(input) {
    if (overlay) return { overlay, paused, showMap, flash };
    if (paused) return { overlay, paused, showMap, flash };

    tryPlayerMove(input);
    blockFall();
    frame = (frame + 1) & 255;
    if ((frame & 1) === 0) moveBullet();
    delay = (delay + 1) & 255;
    if ((delay & 3) === 3 && (delay & 7) === 7) moveMonsters();

    if (health <= 0 && (!overlay || overlay.kind !== "gameover")) {
      overlay = { kind: "gameover", text: "Game Over!" };
      emitSfx("gameover");
    }
    if (flash > 0) flash -= 1;
    return { overlay, paused, showMap, flash, sfx: drainSfx() };
  }

  function advanceAfterScroll() {
    overlay = null;
    levelIdx = wrapLevel(levelIdx + 1);
    startLevel();
  }

  function cameraOrigin() {
    return wrapMap(player.xy - LEVEL_W * 4 - 6);
  }

  return {
    beginFirstLevel,
    startPack: beginFirstLevel,
    tick,
    map,
    player,
    bullet,
    monsters: monstersA,
    cameraOrigin,
    get frame() {
      return frame;
    },
    get health() {
      return health;
    },
    get score() {
      return score;
    },
    get hiscore() {
      return hiscore;
    },
    get hasKey() {
      return (playmode & (1 << PLAY_KEY)) !== 0;
    },
    get hasScroll() {
      return (playmode & (1 << PLAY_SCROLL)) !== 0;
    },
    get liveLevel() {
      return liveLevel;
    },
    get overlay() {
      return overlay;
    },
    get paused() {
      return paused;
    },
    setPaused(v) {
      paused = v;
    },
    setShowMap(v) {
      showMap = v;
    },
    get showMap() {
      return showMap;
    },
    get flash() {
      return flash;
    },
    get spawn() {
      return spawn;
    },
    get pdir() {
      return pdir;
    },
    advanceAfterScroll,
    clearOverlay() {
      overlay = null;
    },
    rand: () => randInt(256),
    drainSfx,
  };
}
