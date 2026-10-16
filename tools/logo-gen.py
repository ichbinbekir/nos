r"""nos fastfetch logosunu (NOS tüpü) üretir. İmaj build'inin parçası değil; logoyu
değiştirmek için elle çalıştırılır.

Mavi gövde, turuncu etiket, üzerinde beyaz NOS harfleri (N daha uzun) ve N'nin sağ
üstünden çıkıp O ile S'nin üstünden sağa uzanan ok; üstte koyu tutamak ve krom vana.
Sahibinin seçimi: "c" versiyonu, açık mavi renk takımı.

Renkler (fastfetch $1..$5; system_files/etc/xdg/fastfetch/config.jsonc ile aynı olmalı):
  $1 gövde (açık mavi)   $2 harfler ve ok (beyaz)   $3 etiket (turuncu)
  $4 tutamak (koyu gri)   $5 vana (krom / açık gri)

Çalıştır: python tools/logo-gen.py             bütün versiyonların renkli önizlemesi
          python tools/logo-gen.py --plain     renksiz
          python tools/logo-gen.py --install   seçilen versiyonu imaja yazar
                                               (system_files/usr/share/nos/fastfetch-logo.txt)
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
INSTALL_PATH = os.path.join(HERE, "..", "system_files", "usr", "share", "nos", "fastfetch-logo.txt")
SELECTED = "c"

CX = 14.0  # gövde ortası
R = 12.5  # gövde yarı genişliği
DOME = 5.0  # omuz yüksekliği (satır)
BODY = 15.0  # düz gövde yüksekliği (satır)
LABEL_TOP, LABEL_ROWS = 2, 8  # etiket: düz gövdenin 2. satırından başlayıp 8 satır

# Vana: (metin, renk) parçaları; ortası CX'e hizalı
VALVE = [
    [("           .-\"\"\"-.", "$4")],
    [("          ( (   ) )", "$4")],
    [("           '-...-'", "$4")],
    [("             |=|", "$5"), ("_", "$5")],
    [("             | |[_]", "$5")],
    [("           __|_|__", "$5")],
]

FONT = {
    # N, O ve S'den bir satır uzun (gerçek NOS logosundaki gibi)
    "N": ["X..X", "XX.X", "XX.X", "X.XX", "X.XX", "X..X"],
    "O": ["XXX", "X.X", "X.X", "X.X", "XXX"],
    "S": ["XXX", "X..", "XXX", "..X", "XXX"],
}
PX = 2  # bir yazı pikseli = 2 sütun
GAP = 1


def inside(x, y):
    """y: gövdenin tepesinden itibaren satır."""
    if 0 <= y < DOME:
        t = (DOME - y) / DOME
        hw = max(2.0, R * math.sqrt(max(0.0, 1 - t * t)))
    elif DOME <= y < DOME + BODY:
        hw = R
    elif DOME + BODY <= y < DOME + BODY + 1:
        t = y - (DOME + BODY)
        hw = R * math.sqrt(max(0.0, 1 - t * t))
    else:
        return False
    return abs(x - CX) <= hw


SUB_X, SUB_Y = 4, 6


def cov(col, row):
    n = 0
    for i in range(SUB_X):
        for j in range(SUB_Y):
            n += inside(col + (i + 0.5) / SUB_X, row + (j + 0.5) / SUB_Y)
    return n / (SUB_X * SUB_Y)


def edge_char(col, row, c):
    gx = cov(col + 1, row) - cov(col - 1, row)
    gy = cov(col, row + 1) - cov(col, row - 1)
    ang = math.degrees(math.atan2(gy * 2.0, gx))
    a = abs(ang)
    if 70 <= a <= 110:
        return ("." if c < 0.5 else "_") if ang > 0 else ("'" if c < 0.5 else "`")
    if a < 25 or a > 155:
        return ":"
    return "/" if (gx > 0) == (gy > 0) else "\\"


def render(body_in, body_edge, label_ch, letter_ch, arrow):
    rows = int(DOME + BODY + 1)
    width = int(CX + R + 2)
    grid = [[(" ", None) for _ in range(width)] for _ in range(rows)]

    # Gövde
    for row in range(rows):
        for col in range(width):
            c = cov(col, row)
            if c < 0.15:
                continue
            if c > 0.85:
                near = any(not inside(col + 0.5 + dx, row + 0.5 + dy)
                           for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)))
                grid[row][col] = (body_edge if near else body_in, "$1")
            else:
                grid[row][col] = (edge_char(col, row, c), "$1")

    # Etiket (turuncu dikdörtgen), kenar sütunları gövde rengiyle kalır
    top = int(DOME) + LABEL_TOP
    left, right = int(CX - R) + 1, int(CX + R) - 1
    for row in range(top, top + LABEL_ROWS):
        for col in range(left, right + 1):
            grid[row][col] = (label_ch, "$3")

    # Harfler alttan hizalı: N 6 satır (etiketin 2. satırından), O ve S 5 satır.
    text_w = sum(len(FONT[ch][0]) * PX for ch in "NOS") + GAP * 2
    x0 = int(round(CX - text_w / 2))
    bottom = top + 6  # harflerin son satırı
    x = x0
    n_right = None
    for ch in "NOS":
        glyph = FONT[ch]
        y0 = bottom - len(glyph) + 1
        for gy, line in enumerate(glyph):
            for gx, p in enumerate(line):
                if p == "X":
                    for k in range(PX):
                        grid[y0 + gy][x + gx * PX + k] = (letter_ch, "$2")
        x += len(glyph[0]) * PX + GAP
        if ch == "N":
            n_right = x - GAP  # N'nin sağ kenarından sonraki sütun
    x_end = x - GAP  # S'nin bitişi

    # Ok: N'nin sağ üst köşesinden çıkıp O ve S'nin üstünden sağa uzanır
    if arrow:
        ay = bottom - len(FONT["N"]) + 1  # N'nin en üst satırı
        for col in range(n_right, x_end):
            grid[ay][col] = ("=", "$2")
        grid[ay][x_end] = (">", "$2")

    # Satırlara çevir
    lines = []
    for valve_line in VALVE:
        lines.append("".join(color + text for text, color in valve_line))
    for row in grid:
        out, cur = [], None
        for ch, color in row:
            if color and color != cur and ch != " ":
                out.append(color)
                cur = color
            out.append(ch)
        lines.append("".join(out).rstrip())
    return lines


VARIANTS = {
    "a": ("Gövde o/s, etiket :, harfler #", ("o", "s", ":", "#", True)),
    "b": ("Gövde +/o (Arch gibi), etiket %, harfler @", ("+", "o", "%", "@", True)),
    "c": ("Gövde c, etiket ;, harfler M (Ubuntu gibi)", ("c", "c", ";", "M", True)),
}

PALETTES = [
    ("mavi / turuncu", {"$1": "34", "$2": "97", "$3": "38;5;208", "$4": "90", "$5": "37"}),
    ("açık mavi / turuncu", {"$1": "94", "$2": "97", "$3": "38;5;208", "$4": "90", "$5": "37"}),
]


def strip(s):
    for k in ("$1", "$2", "$3", "$4", "$5"):
        s = s.replace(k, "")
    return s


def main():
    if os.name == "nt":
        os.system("")
    sys.stdout.reconfigure(encoding="utf-8")
    plain = "--plain" in sys.argv
    if "--install" in sys.argv:
        lines = render(*VARIANTS[SELECTED][1])
        with open(INSTALL_PATH, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        print(f"Yazıldı: {os.path.normpath(INSTALL_PATH)}")
        return
    for key, (title, args) in VARIANTS.items():
        lines = render(*args)
        for pname, colors in (PALETTES[:1] if plain else PALETTES):
            print(f"\n=== Logo {key}: {title} ({pname})\n")
            for l in lines:
                if plain:
                    print("  " + strip(l))
                else:
                    for k, v in colors.items():
                        l = l.replace(k, f"\x1b[{v}m")
                    print("  " + l + "\x1b[0m")


if __name__ == "__main__":
    main()
