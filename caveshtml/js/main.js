import { parseLvl } from "./lvl.js";
import { createEngine } from "./engine.js";
import { createRenderer } from "./render.js";
import { createInput, bindPad, PAD_CODES } from "./input.js";
import { createTunes } from "./tunes.js";

const canvas = document.getElementById("game");
const overlayEl = document.getElementById("overlay");
const storyEl = document.getElementById("story");
const helpEl = document.getElementById("help");
const padEl = document.getElementById("pad");

let mode = "title";
let pack;
let engine;
let renderer;
const input = createInput();
bindPad(padEl, input);
const tunes = createTunes();
let pauseHeld = false;
let mapHeld = false;
let escHeld = false;
let needRelease = false;
let acc = 0;
let last = 0;
// One tick ≈ one CENGINE gameloop (`display` + `halt` + moves).
// TI-85: halt + 13×8 blit ≈ 20 Hz; +15% from playtest → 23 Hz.
const ENGINE_HZ = 23;
const TICK_MS = 1000 / ENGINE_HZ;
const ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

let fetchedLvlStem = "";

async function loadPackText() {
  if (typeof LVL_DATA === "string" && LVL_DATA.length) return LVL_DATA;
  // Multi-file edit only (needs HTTP). Playable path: python build.py → open the built HTML
  const path = "levels/CASTLE.LVL";
  fetchedLvlStem = path.split("/").pop().replace(/\.lvl$/i, "");
  const res = await fetch(path);
  if (!res.ok) {
    throw new Error("No LVL_DATA. Run: python build.py levels/CASTLE.LVL — then open built/castle.html");
  }
  return res.text();
}

async function load() {
  pack = parseLvl(await loadPackText());
  pack.meta.packId = detectPackId();
  renderer = createRenderer(canvas, pack);
  storyEl.textContent = [pack.meta.story, pack.meta.author].join("\n");
  helpEl.textContent =
    "Arrows move · Space jump · X shoot · P pause · M map · Esc twice to title · sound from Crunch";
  showTitle();
  needRelease = true;
  requestAnimationFrame(loop);
}

function playSfx(name) {
  const cut = name === "fire" || name === "coin" || name === "chirp";
  tunes.play(name, { cut });
}

function packIdFromName(name) {
  const id = String(name || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "");
  return id || "pack";
}

function detectPackId() {
  if (typeof LVL_NAME === "string" && LVL_NAME.trim()) return packIdFromName(LVL_NAME);
  if (fetchedLvlStem) return packIdFromName(fetchedLvlStem);
  return "pack";
}

function scoreKey() {
  return `caveshtml.${pack.meta.packId}.hiscore`;
}

function initialsKey() {
  return `caveshtml.${pack.meta.packId}.initials`;
}

const DEFAULT_INITIALS = "___";

function loadInitials() {
  const s = localStorage.getItem(initialsKey());
  if (s && /^[A-Z_]{3}$/.test(s)) return s;
  return DEFAULT_INITIALS;
}

function saveInitials(s) {
  localStorage.setItem(initialsKey(), s.padEnd(3, "_").slice(0, 3).replace(/[^A-Z_]/g, "_"));
}

let titleMusicOn = false;
let nameBuf = DEFAULT_INITIALS.split("");
let nameIdx = 0;
let initialsOpen = false;

function showTitle(withMusic) {
  mode = "title";
  initialsOpen = false;
  titleMusicOn = false;
  if (withMusic) {
    tunes.play("intro", { wait: true });
    titleMusicOn = true;
  }
  overlayEl.hidden = false;
  overlayEl.innerHTML = `
    <h1>Caves</h1>
    <p class="lvl-line">${escapeHtml(pack.meta.story)}</p>
    <p class="lvl-line">${escapeHtml(pack.meta.author)}</p>
    <p class="lvl-line">${escapeHtml(pack.meta.hiscorePrompt)}${hiscoreSuffix()}</p>
    <p class="hint">Find the scroll. One key at a time.</p>
    <p class="hint">Arrows move · Space/Up jump · X shoot · P pause · M map</p>
    <p class="hint">Sound from Crunch / TunesLib</p>
    <p class="start">Press any key</p>
  `;
}

function hiscoreSuffix() {
  const n = engine ? engine.hiscore : Number(localStorage.getItem(scoreKey()) || 0);
  return loadInitials() + (n ? " Score:"+String(n) : "");
}

function escapeHtml(s) {
  return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

function startGame() {
  tunes.unlock();
  engine = createEngine(pack);
  engine.startPack();
  mode = "play";
  overlayEl.hidden = true;
  needRelease = true;
  tunes.play("intro", { cut: true });
}

function loop(now) {
  requestAnimationFrame(loop);
  const t = typeof now === "number" ? now : performance.now();
  if (!last) last = t;
  const dt = Math.min(TICK_MS * 2, Math.max(0, t - last));
  last = t;
  acc += dt;
  try {
    while (acc >= TICK_MS) {
      acc -= TICK_MS;
      step();
    }
    if (engine && mode !== "title") renderer.draw(engine);
  } catch (err) {
    console.error(err);
  }
}

function initialsDisplay() {
  return nameBuf
    .map((ch, i) => (i === nameIdx ? `[${ch}]` : ch))
    .join("");
}

function renderInitialsOverlay() {
  overlayEl.innerHTML = `<h2>Game Over!</h2><p>Score ${engine.score}</p><p class="hint">Enter initials:</p><p class="lvl-line">${escapeHtml(initialsDisplay())}</p><p class="hint">↑↓ letter · ←→ slot · Fire enter</p>`;
}

function cycleLetter(dir) {
  let ch = nameBuf[nameIdx];
  if (ch === "_" || !ALPHA.includes(ch)) {
    nameBuf[nameIdx] = dir > 0 ? "A" : "Z";
    return;
  }
  const i = ALPHA.indexOf(ch);
  nameBuf[nameIdx] = ALPHA[(i + dir + 26) % 26];
}

function finishInitials() {
  const out = nameBuf.map((c) => (c === "_" ? "A" : c)).join("");
  saveInitials(out);
  engine.clearNewHiscore();
  showTitle(true);
  needRelease = true;
}

function stepInitials() {
  renderInitialsOverlay();

  const ch = input.letter();
  if (ch && nameIdx < 3) {
    nameBuf[nameIdx] = ch;
    nameIdx = Math.min(3, nameIdx + 1);
    needRelease = true;
    renderInitialsOverlay();
    if (nameIdx >= 3) finishInitials();
    return;
  }

  if (input.up()) {
    cycleLetter(1);
    needRelease = true;
    renderInitialsOverlay();
    return;
  }
  if (input.down()) {
    cycleLetter(-1);
    needRelease = true;
    renderInitialsOverlay();
    return;
  }
  if (input.left()) {
    nameIdx = (nameIdx + 2) % 3;
    needRelease = true;
    renderInitialsOverlay();
    return;
  }
  if (input.right()) {
    nameIdx = (nameIdx + 1) % 3;
    needRelease = true;
    renderInitialsOverlay();
    return;
  }
  if (input.shoot()) {
    finishInitials();
  }
}

function step() {
  if (needRelease) {
    if (!input.any()) needRelease = false;
    return;
  }

  if (mode === "title") {
    if (input.any()) {
      tunes.unlock();
      startGame();
    }
    return;
  }

  const pause = input.pause();
  if (pause && !pauseHeld) engine.setPaused(!engine.paused);
  pauseHeld = pause;

  const mapKey = input.map();
  if (mapKey && !mapHeld) engine.setShowMap(!engine.showMap);
  mapHeld = mapKey;

  const esc = pressedEscape();
  if (esc && !escHeld) {
    if (input.noteEscape()) {
      engine.setPaused(false);
      tunes.play("quit");
      showTitle(true);
      needRelease = true;
      escHeld = true;
      return;
    }
  }
  if (!esc) escHeld = false;

  if (engine.overlay) {
    overlayEl.hidden = false;
    if (engine.overlay.kind === "newlevel") {
      overlayEl.innerHTML = `<h2>New Level!</h2><p class="start">Press any key</p>`;
      if (input.any()) {
        engine.clearOverlay();
        needRelease = true;
      }
    } else if (engine.overlay.kind === "gameover") {
      if (engine.newHiscore) {
        if (!initialsOpen) {
          nameBuf = DEFAULT_INITIALS.split("");
          nameIdx = 0;
          initialsOpen = true;
          needRelease = true;
        }
        stepInitials();
      } else {
        overlayEl.innerHTML = `<h2>Game Over!</h2><p>Score ${engine.score}</p><p class="start">Press any key</p>`;
        if (input.any()) {
          showTitle(true);
          needRelease = true;
        }
      }
    }
    return;
  }

  if (engine.paused) {
    overlayEl.hidden = false;
    overlayEl.innerHTML = `<h2>Paused</h2><p class="hint">P to resume</p>`;
    return;
  }

  overlayEl.hidden = true;
  const result = engine.tick(input);
  if (result && result.sfx) {
    for (const name of result.sfx) playSfx(name);
  }
}

function pressedEscape() {
  return input._escape ? input._escape() : false;
}

/** Tap the overlay to dismiss title / banners (phone with no pad press yet). */
overlayEl.addEventListener("pointerdown", (e) => {
  if (overlayEl.hidden) return;
  if (e.target.closest("button")) return;
  e.preventDefault();
  input.press(PAD_CODES.tap);
  const release = (ev) => {
    if (ev.pointerId !== e.pointerId) return;
    input.release(PAD_CODES.tap);
    window.removeEventListener("pointerup", release);
    window.removeEventListener("pointercancel", release);
  };
  window.addEventListener("pointerup", release);
  window.addEventListener("pointercancel", release);
});

load().catch((err) => {
  overlayEl.hidden = false;
  overlayEl.innerHTML = `<h2>Could not load Castle</h2><p>${escapeHtml(err.message)}</p>`;
});
