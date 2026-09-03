import { CHAR_TILE, LEVEL_H, LEVEL_W, PIC_LETTER } from "./tiles.js";

function mapCharClass() {
  const chars = new Set(["X", "P", ...Object.keys(CHAR_TILE)]);
  return [...chars]
    .sort()
    .map((c) => (/[\\^\-\]]/.test(c) ? `\\${c}` : c))
    .join("");
}

const MAP_CHARS = new RegExp(`^[${mapCharClass()}]{32}`);

function emptyPic() {
  return new Uint8Array(8);
}

function parseBits(line) {
  const bits = line.trim().slice(0, 8);
  if (!/^[01]{8}$/.test(bits)) return null;
  let b = 0;
  for (let i = 0; i < 8; i++) if (bits[i] === "1") b |= 1 << (7 - i);
  return b;
}

/**
 * Parse a CENGINE .LVL pack: header, 32×32 maps, #X0/#X1 8×8 pics.
 */
export function parseLvl(text) {
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  const meta = { title: "Caves", story: "", author: "", hiscorePrompt: "", zshell: "", levelCount: 0 };
  const maps = [];
  let current = [];
  const pics = { 0: {}, 1: {} };

  const headerKV = {
    $T: "zshell",
    $S: "story",
    $A: "author",
    $P: "hiscorePrompt",
  };

  let seenMap = false;
  let picMode = null; // { ch, bank, rows }

  function flushMap() {
    if (current.length === LEVEL_H) {
      maps.push(current);
    }
    current = [];
  }

  for (let raw of lines) {
    const trimmed = raw.trim();

    if (picMode) {
      const byte = parseBits(trimmed.split(";")[0]);
      if (byte == null && trimmed.startsWith("#")) {
        picMode = null;
      } else if (byte != null) {
        picMode.rows.push(byte);
        if (picMode.rows.length === 8) {
          pics[picMode.bank][picMode.ch] = Uint8Array.from(picMode.rows);
          picMode = null;
        }
        continue;
      } else if (!trimmed || trimmed.startsWith(";")) {
        continue;
      } else {
        picMode = null;
      }
    }

    const picHead = trimmed.match(/^#(.)([01])\b/);
    if (picHead) {
      flushMap();
      seenMap = true;
      picMode = { ch: picHead[1], bank: Number(picHead[2]), rows: [] };
      continue;
    }

    const kv = trimmed.match(/^(\$[TASP])\s*=\s*"([^"]*)"/);
    if (kv) {
      meta[headerKV[kv[1]]] = kv[2];
      continue;
    }

    if (!seenMap && !meta.titleLocked) {
      if (trimmed && !trimmed.startsWith(";") && !trimmed.startsWith("$") && !/^\d+\s*;/.test(trimmed)) {
        meta.title = trimmed;
        meta.titleLocked = true;
      }
    }
    const nlev = trimmed.match(/^(\d+)\s*;\s*number of levels/i);
    if (nlev) meta.levelCount = Number(nlev[1]);

    const body = raw.split(";")[0];
    const mapLine = body.match(MAP_CHARS);
    if (mapLine) {
      seenMap = true;
      current.push(mapLine[0].slice(0, LEVEL_W));
      if (current.length === LEVEL_H) flushMap();
    } else if (current.length && current.length < LEVEL_H && !trimmed) {
      /* keep collecting */
    } else if (current.length && current.length < LEVEL_H) {
      flushMap();
    }
  }
  flushMap();

  if (!meta.levelCount) meta.levelCount = maps.length;
  meta.levelMask = Math.max(0, (1 << Math.ceil(Math.log2(Math.max(1, meta.levelCount)))) - 1);
  if (meta.levelCount === 4) meta.levelMask = 3;

  const banks = [buildBank(pics[0]), buildBank(pics[1], pics[0])];

  const levels = maps.map((rows) => compileMap(rows));
  return { meta, levels, banks };
}

function buildBank(defined, fallback) {
  const bank = [];
  for (let id = 0; id < 14; id++) {
    const ch = PIC_LETTER[id];
    const pic = defined[ch] || (fallback && fallback[ch]) || emptyPic();
    bank.push(pic);
  }
  return bank;
}

function compileMap(rows) {
  const tiles = new Uint8Array(LEVEL_W * LEVEL_H);
  const spawns = [];
  for (let y = 0; y < LEVEL_H; y++) {
    const row = rows[y] || ".".repeat(LEVEL_W);
    for (let x = 0; x < LEVEL_W; x++) {
      const ch = row[x] || ".";
      const off = y * LEVEL_W + x;
      if (ch === "X" || ch === "P") {
        tiles[off] = 0;
        spawns.push(off);
      } else {
        tiles[off] = CHAR_TILE[ch] ?? 0;
      }
    }
  }
  return { tiles, spawn: spawns[0] ?? 0, rows };
}
