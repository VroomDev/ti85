import { parseLvl } from "./lvl.js";
import { createEngine } from "./engine.js";
import { createRenderer } from "./render.js";
import { createInput } from "./input.js";
import { createTunes } from "./tunes.js";

const canvas = document.getElementById("game");
const overlayEl = document.getElementById("overlay");
const storyEl = document.getElementById("story");
const helpEl = document.getElementById("help");

let mode = "title";
let pack;
let engine;
let renderer;
const input = createInput();
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

async function loadPackText() {
  if (typeof LVL_DATA === "string" && LVL_DATA.length) return LVL_DATA;
  // Multi-file edit only (needs HTTP). Playable path: python build.py → open castle.html
  const res = await fetch("levels/CASTLE.LVL");
  if (!res.ok) {
    throw new Error("No LVL_DATA. Run: python build.py levels/CASTLE.LVL — then open castle.html");
  }
  return res.text();
}

async function load() {
  pack = parseLvl(await loadPackText());
  renderer = createRenderer(canvas, pack);
  storyEl.textContent = [pack.meta.story, pack.meta.author, pack.meta.hiscorePrompt].join("\n");
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

let titleMusicOn = false;

function showTitle(withMusic) {
  mode = "title";
  titleMusicOn = false;
  if (withMusic) {
    tunes.play("intro", { loop: true, wait: true });
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
    <p class="hint">Sound from Crunch / TunesLib (headphones optional)</p>
    <p class="start">Press any key</p>
  `;
}

function hiscoreSuffix() {
  const n = engine ? engine.hiscore : Number(localStorage.getItem("caveshtml.castle.hiscore") || 0);
  return n ? String(n) : "";
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
  tunes.play("intro");
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
      overlayEl.innerHTML = `<h2>Game Over!</h2><p>Score ${engine.score}</p><p class="start">Press any key</p>`;
      if (input.any()) {
        showTitle(true);
        needRelease = true;
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

load().catch((err) => {
  overlayEl.hidden = false;
  overlayEl.innerHTML = `<h2>Could not load Castle</h2><p>${escapeHtml(err.message)}</p>`;
});
