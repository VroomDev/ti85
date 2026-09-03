import {
  BG,
  blankid,
  DISP_H,
  DISP_W,
  FB_H,
  FB_W,
  HUD_BG,
  HUD_FG,
  SPR,
  STRIPE,
  animators,
  colorForTile,
  keyid,
  playerid,
  tileId,
  wrapMap,
} from "./tiles.js";

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function blitPic(data, px, py, pic, color, bg) {
  const [r, g, b] = hexToRgb(color);
  const [br, bgc, bb] = hexToRgb(bg);
  for (let row = 0; row < SPR; row++) {
    const bits = pic[row];
    for (let col = 0; col < SPR; col++) {
      const on = bits & (1 << (7 - col));
      const x = px + col;
      const y = py + row;
      if (x < 0 || y < 0 || x >= FB_W || y >= FB_H) continue;
      const i = (y * FB_W + x) * 4;
      if (on) {
        data[i] = r;
        data[i + 1] = g;
        data[i + 2] = b;
        data[i + 3] = 255;
      } else {
        data[i] = br;
        data[i + 1] = bgc;
        data[i + 2] = bb;
        data[i + 3] = 255;
      }
    }
  }
}

function fillRect(data, x, y, w, h, hex) {
  const [r, g, b] = hexToRgb(hex);
  for (let yy = y; yy < y + h; yy++) {
    for (let xx = x; xx < x + w; xx++) {
      if (xx < 0 || yy < 0 || xx >= FB_W || yy >= FB_H) continue;
      const i = (yy * FB_W + xx) * 4;
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = 255;
    }
  }
}

const FONT = {
  0: ["111", "101", "101", "101", "111"],
  1: ["010", "110", "010", "010", "111"],
  2: ["111", "001", "111", "100", "111"],
  3: ["111", "001", "111", "001", "111"],
  4: ["101", "101", "111", "001", "001"],
  5: ["111", "100", "111", "001", "111"],
  6: ["111", "100", "111", "101", "111"],
  7: ["111", "001", "001", "001", "001"],
  8: ["111", "101", "111", "101", "111"],
  9: ["111", "101", "111", "001", "111"],
  S: ["111", "100", "111", "001", "111"],
  C: ["111", "100", "100", "100", "111"],
  R: ["110", "101", "110", "101", "101"],
  L: ["100", "100", "100", "100", "111"],
  V: ["101", "101", "101", "101", "010"],
  K: ["101", "101", "110", "101", "101"],
  " ": ["000", "000", "000", "000", "000"],
};

function drawChar(data, x, y, ch, color) {
  const g = FONT[ch];
  if (!g) return;
  const [r, gch, b] = hexToRgb(color);
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 3; col++) {
      if (g[row][col] !== "1") continue;
      const xx = x + col;
      const yy = y + row;
      const i = (yy * FB_W + xx) * 4;
      data[i] = r;
      data[i + 1] = gch;
      data[i + 2] = b;
      data[i + 3] = 255;
    }
  }
}

function drawText(data, x, y, str, color) {
  let xx = x;
  for (const ch of str) {
    drawChar(data, xx, y, ch, color);
    xx += 4;
  }
}

export function createRenderer(canvas, pack) {
  const ctx = canvas.getContext("2d");
  const img = ctx.createImageData(FB_W, FB_H);
  const { banks } = pack;

  function picFor(tile, frame) {
    const id = tileId(tile);
    const bank = id < animators && frame & 32 ? 1 : 0;
    const pics = banks[bank] || banks[0];
    return (pics && pics[id]) || banks[0][0];
  }

  function draw(engine) {
    const data = img.data;
    fillRect(data, 0, 0, FB_W, FB_H, BG);
    fillRect(data, DISP_W * SPR, 0, FB_W - DISP_W * SPR, FB_H, HUD_BG);

    if (engine.showMap) {
      drawMini(data, engine);
    } else {
      let origin = engine.cameraOrigin();
      for (let ty = 0; ty < DISP_H; ty++) {
        for (let tx = 0; tx < DISP_W; tx++) {
          const off = wrapMap(origin + ty * 32 + tx);
          const tile = engine.map[off];
          const pic = picFor(tile, engine.frame);
          blitPic(data, tx * SPR, ty * SPR, pic, colorForTile(tile), BG);
        }
      }
    }

    for (let y = 0; y < FB_H; y++) {
      const i = (y * FB_W + DISP_W * SPR) * 4;
      const [r, g, b] = hexToRgb(STRIPE);
      data[i] = r;
      data[i + 1] = g;
      data[i + 2] = b;
      data[i + 3] = 255;
    }

    const hx = DISP_W * SPR + 3;
    drawText(data, hx, 4, "SC", HUD_FG);
    drawText(data, hx, 11, String(engine.score).padStart(4, "0").slice(-4), HUD_FG);
    drawText(data, hx, 22, "LV", HUD_FG);
    drawText(data, hx, 29, String(engine.health), HUD_FG);
    drawText(data, hx, 40, "L" + String(engine.liveLevel), HUD_FG);
    if (engine.hasKey) {
      const pic = picFor(keyid, engine.frame);
      blitPic(data, hx, 50, pic, colorForTile(keyid), HUD_BG);
    }

    if (engine.flash) {
      for (let i = 0; i < data.length; i += 4) {
        data[i] = Math.min(255, data[i] + 40);
      }
    }

    ctx.putImageData(img, 0, 0);
  }

  function drawMini(data, engine) {
    const origin = wrapMap(engine.player.xy - 32 * 16 - 16);
    for (let y = 0; y < 32; y++) {
      for (let x = 0; x < 32; x++) {
        const tile = engine.map[wrapMap(origin + y * 32 + x)];
        const px = 4 + x * 3;
        const py = 4 + y * 1;
        const solid = tile && !(tile & 0x40);
        const col = solid ? colorForTile(tile) : "#1a1e24";
        fillRect(data, px, py, 2, 1, col);
      }
    }
    const [px, py] = [engine.player.xy & 31, engine.player.xy >> 5];
    fillRect(data, 4 + px * 3, 4 + py, 2, 1, colorForTile(playerid));
  }

  return { draw };
}
