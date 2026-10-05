"""Write src/version.s with VERSION = vYYYYMMDD for the build date."""
from datetime import date
from pathlib import Path

stamp = date.today().strftime("v%Y%m%d")
root = Path(__file__).resolve().parent.parent
text = (
    ";; Compile date. Written by tools/gen_version.py.\n"
    ".macpack cbm\n"
    "\n"
    '.segment "RODATA"\n'
    "\n"
    ".export VERSION\n"
    "VERSION:\n"
    f'        scrcode "{stamp}"\n'
    "        .byte 0\n"
)
(root / "src" / "version.s").write_text(text, encoding="ascii", newline="\n")
print(f"VERSION {stamp}")
