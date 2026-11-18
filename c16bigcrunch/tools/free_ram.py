"""Print bytes from the end of BSS to $4000."""
import re
import sys
from pathlib import Path

text = Path("build/crunch.map").read_text(encoding="utf-8", errors="replace")
m = re.search(r"^BSS\s+([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)", text, re.M)
if not m:
    print("Free RAM: see build/crunch.map")
    sys.exit(0)
start = int(m.group(1), 16)
size = int(m.group(3), 16)
end = start + size
free = 0x4000 - end
print(f"Free RAM: {free} bytes (${end:04X} to $4000)")
