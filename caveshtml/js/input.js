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

/** Map pad button names → keyboard codes. */
export const PAD_CODES = {
  left: "ArrowLeft",
  right: "ArrowRight",
  up: "ArrowUp",
  down: "ArrowDown",
  fire: "KeyX",
  pause: "KeyP",
  map: "KeyM",
  quit: "Escape",
  tap: "__tap",
};

/**
 * Wire #pad buttons with multi-touch (one pointer per button).
 * Visibility is CSS: coarse pointer + portrait.
 */
export function bindPad(root, input) {
  if (!root) return () => {};

  const heldByPointer = new Map();

  function codeFor(el) {
    const name = el && el.getAttribute("data-btn");
    return name && PAD_CODES[name] ? PAD_CODES[name] : null;
  }

  function onDown(e) {
    const btn = e.target.closest("[data-btn]");
    const code = codeFor(btn);
    if (!code) return;
    e.preventDefault();
    btn.setPointerCapture?.(e.pointerId);
    heldByPointer.set(e.pointerId, { code, btn });
    btn.classList.add("is-down");
    input.press(code);
  }

  function onUp(e) {
    const rec = heldByPointer.get(e.pointerId);
    if (!rec) return;
    heldByPointer.delete(e.pointerId);
    rec.btn.classList.remove("is-down");
    input.release(rec.code);
  }

  root.addEventListener("pointerdown", onDown);
  root.addEventListener("pointerup", onUp);
  root.addEventListener("pointercancel", onUp);
  root.addEventListener("lostpointercapture", onUp);

  return () => {
    root.removeEventListener("pointerdown", onDown);
    root.removeEventListener("pointerup", onUp);
    root.removeEventListener("pointercancel", onUp);
    root.removeEventListener("lostpointercapture", onUp);
    for (const rec of heldByPointer.values()) {
      rec.btn.classList.remove("is-down");
      input.release(rec.code);
    }
    heldByPointer.clear();
  };
}
