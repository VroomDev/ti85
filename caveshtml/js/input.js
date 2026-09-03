/** Keyboard → CENGINE-style simultaneous buttons. */

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
    any: () => down.size > 0,
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
