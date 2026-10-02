"""Build the bundled UI font: Noto Sans SC (OFL) static wght=500 subset.

Coverage = ASCII + common punctuation/symbols + GB2312 level-1 hanzi (3755)
+ every non-ASCII character found in project scripts/scenes/data.
Usage: python tools/subset_font.py <NotoSansSC[wght].ttf>
"""
import os, sys, pathlib
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

root = pathlib.Path(__file__).resolve().parent.parent
src = sys.argv[1]
chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("·—–…‘’“”、。，．：；！？（）【】《》〈〉「」『』～¥×÷±°℃←→↑↓↕↶↷▶◀▼▲●○■□★☆♪✓✔✕✖")
for b1 in range(0xB0, 0xD8):
    for b2 in range(0xA1, 0xFF):
        try:
            chars.add(bytes([b1, b2]).decode("gb2312"))
        except UnicodeDecodeError:
            pass
for ext in ("*.gd", "*.tscn", "*.json", "*.tres"):
    for p in root.rglob(ext):
        if ".godot" in p.parts:
            continue
        chars |= set(ch for ch in p.read_text(encoding="utf-8", errors="ignore") if ord(ch) > 0x7F)
font = TTFont(src)
font = instancer.instantiateVariableFont(font, {"wght": 500})
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(opts)
sub.populate(text="".join(sorted(chars)))
sub.subset(font)
cmap = font.getBestCmap()
missing = sorted(ch for ch in chars if ord(ch) not in cmap and ch.isprintable() and ord(ch) > 0x7F)
out = root / "assets" / "fonts" / "ui_font.ttf"
font.save(out)
print("chars requested:", len(chars), "glyphs:", len(font.getGlyphOrder()), "size:", os.path.getsize(out))
print("missing:", "".join(missing))
