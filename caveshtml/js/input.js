/** Keyboard + virtual pad → CENGINE-style simultaneous buttons. */

export function createInput() {
  const down = new Set();
  let escapeTaps = 0;
  let escapeAt = 0;

  function keyOf(e) {
    return e.code || e.key;
  }

  const onDown = (e) => {
    down.add(keyOf(e));
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space", "Escape"].includes(e.code)) {
      e.preventDefault();
    }
  };
  const onUp = (e) => down.delete(keyOf(e));
  const onBlur = () => down.clear();

  window.addEventListener("keydown", onDown);
  window.addEventListener("keyup", onUp);
  window.addEventListener("blur", onBlur);

  function held(codes) {
    return codes.some((c) => down.has(c));
  }

  return {
    left: () => held(["ArrowLeft"]),
    right: () => held(["ArrowRight"]),
    up: () => held(["ArrowUp"]),
    down: () => held(["ArrowDown"]),
    jump: () => held(["ArrowUp", "Space"]),
    alpha: () => held(["Space"]),
    shoot: () => held(["KeyX", "KeyZ", "ControlLeft", "ControlRight"]),
    pause: () => held(["KeyP", "F1"]),
    map: () => held(["KeyM"]),
    dropScroll: () => held(["Digit1", "Numpad1"]),
    any: () => down.size > 0,
    letter() {
      for (let i = 0; i < 26; i++) {
        const code = "Key" + String.fromCharCode(65 + i);
        if (down.has(code)) return String.fromCharCode(65 + i);
      }
      return null;
    },
    /** Virtual pad / overlay: hold the same codes keyboard uses. */
    press(code) {
      down.add(code);
    },
    release(code) {
      down.delete(code);
    },
    clear() {
      down.clear();
    },
    _escape: () => held(["Escape"]),
    consumeEscapeTwice() {
      if (!held(["Escape"])) return false;
      const now = performance.now();
      if (now - escapeAt > 900) escapeTaps = 0;
      escapeAt = now;
      return false;
    },
    noteEscape() {
      const now = performance.now();
      if (now - escapeAt > 900) escapeTaps = 0;
      escapeTaps += 1;
      escapeAt = now;
      return escapeTaps >= 2;
    },
    resetEscape() {
      escapeTaps = 0;
    },
    destroy() {
      window.removeEventListener("keydown", onDown);
      window.removeEventListener("keyup", onUp);
      window.removeEventListener("blur", onBlur);
    },
  };
}

/** Map pad button names → one or more keyboard codes (diagonals hold two). */
export const PAD_CODES = {
  left: ["ArrowLeft"],
  right: ["ArrowRight"],
  up: ["ArrowUp"],
  down: ["ArrowDown"],
  upleft: ["ArrowUp", "ArrowLeft"],
  upright: ["ArrowUp", "ArrowRight"],
  downleft: ["ArrowDown", "ArrowLeft"],
  downright: ["ArrowDown", "ArrowRight"],
  fire: ["KeyX"],
  pause: ["KeyP"],
  map: ["KeyM"],
  quit: ["Escape"],
  tap: ["__tap"],
};

/** 8-way ring from pad center; index 0 = right, then clockwise (screen y-down). */
const DPAD_OCTANTS = [
  "right",
  "downright",
  "down",
  "downleft",
  "left",
  "upleft",
  "up",
  "upright",
];

/**
 * Wire #pad: continuous D-pad tracking (slide to change direction) +
 * discrete Fire / meta buttons. Visibility is CSS: coarse + portrait.
 */
export function bindPad(root, input) {
  if (!root) return () => {};

  const heldByPointer = new Map();
  const dpad = root.querySelector(".pad-dpad");
  const OCTANT = Math.PI / 4;
  const HYSTERESIS = OCTANT * 0.3;

  function otherPointersHold(code, exceptId) {
    for (const [id, rec] of heldByPointer) {
      if (id !== exceptId && rec.codes.includes(code)) return true;
    }
    return false;
  }

  function applyCodes(pointerId, codes, activeEl) {
    const prev = heldByPointer.get(pointerId);
    const next = codes || [];
    if (prev) {
      for (const code of prev.codes) {
        if (!next.includes(code) && !otherPointersHold(code, pointerId)) {
          input.release(code);
        }
      }
      if (prev.activeEl && prev.activeEl !== activeEl) {
        prev.activeEl.classList.remove("is-down");
      }
    }
    for (const code of next) input.press(code);
    if (activeEl) activeEl.classList.add("is-down");
    heldByPointer.set(pointerId, {
      codes: next,
      activeEl: activeEl || null,
      kind: prev ? prev.kind : "btn",
    });
  }

  function clearPointer(pointerId) {
    const rec = heldByPointer.get(pointerId);
    if (!rec) return;
    heldByPointer.delete(pointerId);
    if (rec.activeEl) rec.activeEl.classList.remove("is-down");
    for (const code of rec.codes) {
      if (!otherPointersHold(code, pointerId)) input.release(code);
    }
  }

  function normAngle(a) {
    while (a > Math.PI) a -= Math.PI * 2;
    while (a < -Math.PI) a += Math.PI * 2;
    return a;
  }

  /**
   * Angle-based 8-way from the pad center (not a 3×3 grid).
   * Grid cells made “diagonal” presses often register as pure left/right
   * (no Up) so jump flickered on/off.
   */
  function sectorAt(clientX, clientY, prevName) {
    if (!dpad) return null;
    const r = dpad.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) return prevName || null;
    const dx = clientX - (r.left + r.width / 2);
    const dy = clientY - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy);
    const dead = Math.min(r.width, r.height) * 0.14;
    if (dist < dead) return prevName || null;

    let t = Math.atan2(dy, dx); // 0 = right, π/2 = down
    if (t < 0) t += Math.PI * 2;

    const prevIdx = prevName ? DPAD_OCTANTS.indexOf(prevName) : -1;
    if (prevIdx >= 0) {
      const center = prevIdx * OCTANT;
      const d = normAngle(t - center);
      if (Math.abs(d) <= OCTANT / 2 + HYSTERESIS) return prevName;
    }

    const idx = Math.round(t / OCTANT) % 8;
    return DPAD_OCTANTS[idx];
  }

  function syncDpadPointer(e) {
    const rec = heldByPointer.get(e.pointerId);
    if (!rec || rec.kind !== "dpad") return;
    const name = sectorAt(e.clientX, e.clientY, rec.sector || null);
    if (!name) {
      applyCodes(e.pointerId, [], null);
      heldByPointer.set(e.pointerId, {
        ...heldByPointer.get(e.pointerId),
        kind: "dpad",
        sector: null,
      });
      return;
    }
    const codes = PAD_CODES[name] || [];
    const activeEl = dpad.querySelector(`[data-btn="${name}"]`);
    applyCodes(e.pointerId, codes, activeEl);
    heldByPointer.set(e.pointerId, {
      ...heldByPointer.get(e.pointerId),
      kind: "dpad",
      sector: name,
    });
  }

  function onDpadDown(e) {
    if (e.button != null && e.button !== 0) return;
    e.preventDefault();
    dpad.setPointerCapture?.(e.pointerId);
    heldByPointer.set(e.pointerId, { codes: [], activeEl: null, kind: "dpad", sector: null });
    syncDpadPointer(e);
  }

  function onDpadMove(e) {
    if (!heldByPointer.has(e.pointerId)) return;
    const rec = heldByPointer.get(e.pointerId);
    if (!rec || rec.kind !== "dpad") return;
    e.preventDefault();
    syncDpadPointer(e);
  }

  function onBtnDown(e) {
    if (e.button != null && e.button !== 0) return;
    if (e.target.closest(".pad-dpad")) return;
    const btn = e.target.closest("[data-btn]");
    if (!btn || !root.contains(btn)) return;
    const name = btn.getAttribute("data-btn");
    const codes = PAD_CODES[name];
    if (!codes) return;
    e.preventDefault();
    btn.setPointerCapture?.(e.pointerId);
    heldByPointer.set(e.pointerId, { codes: [], activeEl: null, kind: "btn" });
    applyCodes(e.pointerId, codes, btn);
    heldByPointer.set(e.pointerId, {
      ...heldByPointer.get(e.pointerId),
      kind: "btn",
    });
  }

  function onUp(e) {
    clearPointer(e.pointerId);
  }

  if (dpad) {
    dpad.addEventListener("pointerdown", onDpadDown);
    dpad.addEventListener("pointermove", onDpadMove);
    dpad.addEventListener("pointerup", onUp);
    dpad.addEventListener("pointercancel", onUp);
    dpad.addEventListener("lostpointercapture", onUp);
  }

  root.addEventListener("pointerdown", onBtnDown);
  root.addEventListener("pointerup", onUp);
  root.addEventListener("pointercancel", onUp);
  root.addEventListener("lostpointercapture", onUp);

  return () => {
    if (dpad) {
      dpad.removeEventListener("pointerdown", onDpadDown);
      dpad.removeEventListener("pointermove", onDpadMove);
      dpad.removeEventListener("pointerup", onUp);
      dpad.removeEventListener("pointercancel", onUp);
      dpad.removeEventListener("lostpointercapture", onUp);
    }
    root.removeEventListener("pointerdown", onBtnDown);
    root.removeEventListener("pointerup", onUp);
    root.removeEventListener("pointercancel", onUp);
    root.removeEventListener("lostpointercapture", onUp);
    for (const id of [...heldByPointer.keys()]) clearPointer(id);
  };
}
