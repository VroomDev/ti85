/** CENGINE tile ids, flags, and one tint per graphic. */

export const NOERASE = 0x80;
export const KILLABLE = 0x40;
export const FALLING = 0x20;
export const TYPEAND = 0xe0;
export const IDAND = 0x1f;

export const blankid = 0;
export const playerid = 1 | NOERASE;
export const monster1id = 2 | NOERASE | KILLABLE;
export const monster2id = 3 | NOERASE | KILLABLE;
export const monsters = 4;
export const coinid = 4 | FALLING;
export const scrollid = 5 | NOERASE;
export const fireid = 6 | NOERASE;
export const bombid = 7 | KILLABLE | FALLING;
export const animators = 8;
export const bulletid = 8 | NOERASE;
export const bloodid = 9 | FALLING;
export const treeid = 10 | NOERASE | KILLABLE | FALLING;
export const brickid = 11 | NOERASE;
export const wallid = 11 | NOERASE | KILLABLE;
export const fwallid = 11 | NOERASE | FALLING;
export const doorid = 12 | NOERASE | FALLING;
export const keyid = 13 | NOERASE;

export const LEVEL_W = 32;
export const LEVEL_H = 32;
export const LEVEL_SIZE = 1024;
export const SPR = 8;
export const DISP_W = 13;
export const DISP_H = 8;
export const SCR_W = 16;
export const FB_W = 128;
export const FB_H = 64;
export const BRICK_BASE = 11;
export const JUMP_LEN = 3;
export const BULLET_RANGE = 4;
export const MONSTER_MAX = 20;
export const FIRST_LVL_MONST = 5;
export const SECOND_LVL_MONST = 10;

export const K_NOKEY = 0;
export const K_DOWN = 1;
export const K_LEFT = 2;
export const K_RIGHT = 3;
export const K_UP = 4;

export const DIR_DELTA = {
  [K_DOWN]: LEVEL_W,
  [K_LEFT]: -1,
  [K_RIGHT]: 1,
  [K_UP]: -LEVEL_W,
};

/** Map letter → engine byte. X/P are spawn markers, not tiles. */
export const CHAR_TILE = {
  ".": blankid,
  c: coinid,
  s: scrollid,
  f: fireid,
  F: bombid,
  B: bulletid,
  S: bloodid,
  t: treeid,
  b: brickid,
  W: wallid,
  D: doorid,
  k: keyid,
  M: monster1id,
  m: monster2id,
  z: brickid,
};

/** Which #pic letter feeds each picture slot 0..13 */
export const PIC_LETTER = {
  0: ".",
  1: "P",
  2: "M",
  3: "m",
  4: "c",
  5: "s",
  6: "f",
  7: "F",
  8: "B",
  9: "S",
  10: "t",
  11: "b",
  12: "D",
  13: "k",
};

/** Single color per graphic (enhancement). Wall uses brick bits, cooler tint. */
export const GRAPHIC_COLOR = {
  0: "#000000",
  1: "#E8C48A", // player
  2: "#9B6BB8", // patrol
  3: "#C44536", // seeker
  4: "#E4B61A", // coin
  5: "#F3E5B5", // scroll
  6: "#E07020", // lava
  7: "#6A737A", // bomb
  8: "#DDE4EA", // bullet / cloud
  9: "#7A1212", // stain
  10: "#2F9E4F", // tree
  11: "#A35A32", // brick (default for id 11)
  12: "#6B4228", // door
  13: "#F0D65A", // key
};

export const WALL_COLOR = "#7A8490";
export const PLAYER_COLOR = GRAPHIC_COLOR[1];
export const BG = "#101218";
export const HUD_BG = "#08090c";
export const HUD_FG = "#c8d0b4";
export const STRIPE = "#3a4030";

export function tileId(v) {
  return v & IDAND;
}

export function picIndex(v) {
  return v & IDAND;
}

export function colorForTile(v) {
  const id = tileId(v);
  if (id === BRICK_BASE && v === wallid) return WALL_COLOR;
  if (id === BRICK_BASE && v === fwallid) return "#8A7060";
  return GRAPHIC_COLOR[id] || "#ffffff";
}

export function wrapMap(off) {
  return off & 1023;
}
