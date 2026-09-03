/**
 * TI-85 TunesLib 1.0 (Crunch) → Web Audio.
 * Song bytes match CRUNCH.ASM: playmode, octave, then duration,freq pairs.
 * Duration 0 ends. Freq 0 is a rest (Z80 djnz with B=0 still waits 256).
 */

export const LEGATO_OFF = 1; // bit 0 set → no pause between notes

/** ~T-states of TUNESLIB delayloop (xor/out/in/cp/jr/djnz). TI-85 ~6 MHz. */
const CPU_HZ = 6_000_000;
const T_INNER = 62;
const T_LEGATO = 256 * 12;

const SONGS = {
  // intro (loops on title in Crunch)
  intro: [
    0, 2, 33, 180, 57, 105, 65, 91, 57, 105, 46, 129, 57, 105, 40, 148, 57, 105,
    33, 180, 57, 105, 65, 91, 57, 105, 46, 129, 57, 105, 40, 148, 57, 105, 33,
    180, 57, 105, 65, 91, 57, 105, 46, 129, 57, 105, 40, 148, 57, 105, 75, 79,
    57, 105, 29, 205, 57, 105, 25, 232, 25, 232, 32, 232, 250, 0, 0,
  ],
  newlevel: [0, 2, 12, 45, 15, 13, 35, 100, 99, 2, 0],
  // LegatoOn, octave 5, .dw notes (LE: duration, freq), then 70 rest, stop
  quit: [0, 5, 132, 34, 112, 40, 132, 34, 150, 30, 121, 37, 70, 0, 0],
  gameover: [0, 4, 34, 129, 34, 129, 34, 129, 39, 113, 30, 148, 30, 148, 66, 30, 148, 0],
  fire: [1, 5, 12, 23, 6, 79, 4, 200, 0],
  coin: [1, 2, 23, 43, 34, 23, 17, 34, 0],
  hurt: [1, 3, 8, 10, 10, 200, 8, 10, 0],
};

function z80Times(b) {
  return b === 0 ? 256 : b;
}

function parseNotes(bytes) {
  const playmode = bytes[0] | 0;
  const octave = bytes[1] | 0;
  const notes = [];
  for (let i = 2; i < bytes.length; ) {
    const duration = bytes[i++];
    if (!duration) break;
    const freq = i < bytes.length ? bytes[i++] : 0;
    notes.push({ duration, freq });
  }
  return { playmode, octave, notes };
}

function renderSong(sampleRate, bytes) {
  const { playmode, octave, notes } = parseNotes(bytes);
  const samples = [];
  let speaker = 1;
  const octaveWait = z80Times(octave);

  function pushCycles(level, cycles) {
    const n = Math.max(1, Math.min(48000, Math.round((cycles * T_INNER * sampleRate) / CPU_HZ) || 1));
    const start = samples.length;
    samples.length = start + n;
    samples.fill(level, start, start + n);
  }

  function legatoPause() {
    if (playmode & LEGATO_OFF) return;
    const n = Math.max(1, Math.round((T_LEGATO * sampleRate) / CPU_HZ));
    for (let s = 0; s < n; s++) samples.push(0);
  }

  for (const note of notes) {
    legatoPause();
    const freqWait = z80Times(note.freq);
    const silent = note.freq === 0;
    for (let c = 0; c < note.duration; c++) {
      if (!silent) {
        speaker = -speaker;
      }
      pushCycles(silent ? 0 : speaker, freqWait * octaveWait);
    }
  }
  if (!samples.length) samples.push(0);
  return Float32Array.from(samples);
}

export function createTunes() {
  let ctx = null;
  let master = null;
  let current = null;
  let loopName = null;
  const cache = new Map();
  const queue = [];

  function ensure() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.09;
    master.connect(ctx.destination);
    return ctx;
  }

  function bufferFor(name) {
    const ac = ensure();
    if (!ac) return null;
    if (cache.has(name)) return cache.get(name);
    const bytes = SONGS[name];
    if (!bytes) return null;
    const pcm = renderSong(ac.sampleRate, bytes);
    const buf = ac.createBuffer(1, pcm.length, ac.sampleRate);
    buf.getChannelData(0).set(pcm);
    cache.set(name, buf);
    return buf;
  }

  function stop(clearQueue = true) {
    loopName = null;
    if (clearQueue) queue.length = 0;
    if (current) {
      try {
        current.onended = null;
        current.stop();
      } catch {
        /* already stopped */
      }
      current = null;
    }
  }

  function begin(name, loop) {
    const ac = ensure();
    if (!ac) return;
    const buf = bufferFor(name);
    if (!buf) return;
    if (ac.state === "suspended") ac.resume();
    const src = ac.createBufferSource();
    src.buffer = buf;
    src.connect(master);
    src.onended = () => {
      if (current === src) current = null;
      if (loopName === name) {
        begin(name, true);
        return;
      }
      if (queue.length) {
        const next = queue.shift();
        begin(next.name, next.loop);
      }
    };
    current = src;
    loopName = loop ? name : null;
    src.start();
  }

  function play(name, opts = {}) {
    const ac = ensure();
    if (!ac) return;
    if (ac.state === "suspended") ac.resume();
    if (opts.wait && current) {
      queue.push({ name, loop: Boolean(opts.loop) });
      return;
    }
    if (opts.loop) {
      stop();
      begin(name, true);
      return;
    }
    if (opts.cut) {
      stop(false);
      begin(name, false);
      return;
    }
    if (current) {
      queue.push({ name, loop: false });
      return;
    }
    begin(name, false);
  }

  return {
    songs: SONGS,
    unlock() {
      const ac = ensure();
      if (ac && ac.state === "suspended") ac.resume();
    },
    play,
    stop,
    get enabled() {
      return Boolean(ctx);
    },
  };
}
