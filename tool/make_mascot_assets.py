"""Menyiapkan aset maskot dan ikon aplikasi AURA dari gambar asli berlatar putih.

Masalahnya: robot AURA didominasi warna putih, jadi "hapus semua piksel putih"
akan melubangi badannya. Hasil pengukuran pada gambar asli:

  - latar putih murni sempurna (setiap kanal bernilai tepat 255),
  - plastik robot di dekat tepi bernilai 244-251.

Karena itu latar disapu dari tepi gambar ke dalam, *hanya* melewati piksel
bernilai tepat 255. Tepi plastik yang sedikit lebih gelap menjadi dinding
penahan. Penyapuan dilakukan pada resolusi asli: memperbesar lebih dulu akan
mengaburkan tepi dan menciptakan "jembatan" putih ke dalam badan robot.

Pakai: python -I tool/make_mascot_assets.py
"""

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "aura_mascot_original.png"
ASSETS = ROOT / "assets" / "images"
DESIGN = ROOT / "design"

UPSCALE = 2
# Kumpulan putih tertutup yang lebih besar dari ini adalah celah latar
# (misalnya di antara lengan dan badan), bukan kilau cahaya pada plastik.
ENCLOSED_BACKGROUND_MIN_AREA = 500

BRAND_TOP = (42, 92, 235)     # biru terang beranda anak
BRAND_BOTTOM = (11, 18, 92)   # biru malam


# --- Pemisahan latar --------------------------------------------------------

def white_components(pure_white):
    """Memberi label setiap kumpulan piksel putih murni yang bersambung."""
    h, w = pure_white.shape
    labels = np.zeros((h, w), dtype=np.int32)
    sizes, touches_edge = {}, {}
    current = 0
    for y0 in range(h):
        for x0 in range(w):
            if not pure_white[y0, x0] or labels[y0, x0]:
                continue
            current += 1
            labels[y0, x0] = current
            queue = deque([(y0, x0)])
            size, edge = 0, False
            while queue:
                y, x = queue.popleft()
                size += 1
                if y in (0, h - 1) or x in (0, w - 1):
                    edge = True
                for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                    if 0 <= ny < h and 0 <= nx < w and pure_white[ny, nx] and not labels[ny, nx]:
                        labels[ny, nx] = current
                        queue.append((ny, nx))
            sizes[current] = size
            touches_edge[current] = edge
    return labels, sizes, touches_edge


def shift(a, dy, dx, fill=False):
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    ys = slice(max(dy, 0), h + min(dy, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = a[yd, xd]
    return out


NEIGHBOURS = [(dy, dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx]


def erode(mask, steps):
    for _ in range(steps):
        result = mask.copy()
        for dy, dx in NEIGHBOURS:
            result &= shift(mask, dy, dx, fill=False)
        mask = result
    return mask


def spread_colours(rgb, known, steps):
    """Merambatkan warna piksel dalam ke piksel tepi di sekitarnya."""
    colours = np.where(known[..., None], rgb, 0.0)
    known = known.copy()
    for _ in range(steps):
        total = np.zeros_like(colours)
        count = np.zeros(known.shape, dtype=np.float64)
        for dy, dx in NEIGHBOURS:
            k = shift(known, dy, dx, fill=False)
            total += np.where(k[..., None], shift(colours, dy, dx, fill=0.0), 0.0)
            count += k
        fresh = (~known) & (count > 0)
        colours[fresh] = total[fresh] / count[fresh][:, None]
        known |= fresh
    return colours


def cut_out(original):
    rgb = np.asarray(original, dtype=np.float64)
    pure_white = np.all(rgb >= 255, axis=2)

    labels, sizes, touches_edge = white_components(pure_white)
    enclosed = sorted(
        (s for i, s in sizes.items() if not touches_edge[i]), reverse=True
    )
    background_ids = [
        i for i in sizes
        if touches_edge[i] or sizes[i] >= ENCLOSED_BACKGROUND_MIN_AREA
    ]
    background = np.isin(labels, background_ids)
    foreground = ~background

    # Tepi antialias adalah campuran warna robot dan putih:
    #   P = a * C + (1 - a) * 255
    # Warna asli C ditaksir dari piksel dalam di sebelahnya, lalu a dihitung.
    interior = erode(foreground, 2)
    band = foreground & ~interior
    estimate = spread_colours(rgb, interior, steps=4)

    distance_true = 255.0 - estimate
    distance_seen = 255.0 - rgb
    informative = distance_true > 35  # kanal yang cukup berbeda dari putih
    weight = np.where(informative, distance_true, 0.0).sum(axis=2)
    seen = np.where(informative, distance_seen, 0.0).sum(axis=2)
    alpha_band = np.where(weight > 0, np.clip(seen / np.maximum(weight, 1), 0, 1), 1.0)

    alpha = np.where(foreground, 1.0, 0.0)
    alpha = np.where(band, alpha_band, alpha)
    colour = np.where((band & (alpha_band < 0.98))[..., None], estimate, rgb)

    rgba = np.dstack([np.clip(colour, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA"), background, enclosed


# --- Turunan aset ------------------------------------------------------------

def upscale(img, factor):
    # Diperbesar dalam bentuk premultiplied agar tepi tidak menghitam.
    size = (img.width * factor, img.height * factor)
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def trim(img, margin):
    left, top, right, bottom = img.getchannel("A").getbbox()
    return img.crop((
        max(0, left - margin),
        max(0, top - margin),
        min(img.width, right + margin),
        min(img.height, bottom + margin),
    ))


def gradient(size, top, bottom):
    h = size[1]
    t = np.linspace(0, 1, h)[:, None]
    row = np.array(top) * (1 - t) + np.array(bottom) * t
    data = np.repeat(row[:, None, :], size[0], axis=1).astype(np.uint8)
    return Image.fromarray(data, "RGB").convert("RGBA")


def glow(size, centre, radius, colour, strength):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt((xx - centre[0]) ** 2 + (yy - centre[1]) ** 2) / radius
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    layer = np.zeros((h, w, 4), dtype=np.uint8)
    layer[..., :3] = colour
    layer[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def bust(full):
    """Kepala maskot, dipotong di leher: tetap terbaca di ukuran ikon kecil.

    Leher dicari sebagai baris tersempit di antara kepala dan bahu (terukur
    di sekitar 50% tinggi), supaya potongannya jatuh di tempat yang alami
    dan tidak menyisakan irisan bahu yang datar.
    """
    a = np.asarray(full.getchannel("A")) > 20
    widths = a.sum(axis=1)
    h = len(widths)
    lo, hi = int(h * 0.42), int(h * 0.56)
    neck = lo + int(np.argmin(widths[lo:hi]))
    return trim(full.crop((0, 0, full.width, neck + 6)), margin=0)


def place_in_circle(canvas_size, figure, radius):
    """Menempatkan figure dengan titik beratnya di tengah kanvas, diskalakan
    sehingga piksel terjauhnya tepat berada di dalam lingkaran `radius`."""
    a = np.asarray(figure.getchannel("A")) > 20
    ys, xs = np.nonzero(a)
    cx, cy = xs.mean(), ys.mean()
    reach = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2).max()
    scale = radius / reach
    fig = figure.resize(
        (round(figure.width * scale), round(figure.height * scale)), Image.LANCZOS
    )
    layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = round(canvas_size[0] / 2 - cx * scale)
    y = round(canvas_size[1] / 2 - cy * scale)
    layer.alpha_composite(fig, (x, y))
    return layer


def place(canvas_size, figure, fill, anchor_y=0.5):
    """Menskalakan figure agar muat dalam `fill` bagian kanvas, lalu memusatkan."""
    cw, ch = canvas_size
    scale = min(cw * fill / figure.width, ch * fill / figure.height)
    fig = figure.resize(
        (round(figure.width * scale), round(figure.height * scale)), Image.LANCZOS
    )
    layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (cw - fig.width) // 2
    y = round((ch - fig.height) * anchor_y)
    layer.alpha_composite(fig, (x, y))
    return layer


def main():
    original = Image.open(SOURCE).convert("RGB")
    cutout, background, enclosed = cut_out(original)

    print(f"gambar asli              : {original.size}")
    print(f"latar terhapus           : {background.mean():.1%}")
    print(f"putih tertutup terbesar  : {enclosed[:6]} piksel")
    print(f"  (>= {ENCLOSED_BACKGROUND_MIN_AREA} dianggap celah latar, sisanya kilau plastik)")

    full = trim(upscale(cutout, UPSCALE), margin=8)
    ASSETS.mkdir(parents=True, exist_ok=True)
    full.save(ASSETS / "aura_mascot.png", optimize=True)

    head = bust(full)
    head.save(ASSETS / "aura_mascot_head.png", optimize=True)

    # Ikon aplikasi --------------------------------------------------------
    icon_size = (1024, 1024)
    backdrop = gradient(icon_size, BRAND_TOP, BRAND_BOTTOM)
    backdrop.alpha_composite(glow(icon_size, (512, 470), 560, (90, 200, 255), 0.45))
    backdrop.alpha_composite(glow(icon_size, (512, 1150), 520, (238, 30, 45), 0.55))
    backdrop.convert("RGB").save(DESIGN / "app_icon_background.png")

    # Ikon biasa (web, Windows, Android lama): kepala mengisi kotak.
    legacy = backdrop.copy()
    legacy.alpha_composite(place_in_circle(icon_size, head, radius=440))
    legacy.convert("RGB").save(DESIGN / "app_icon.png")

    # Ikon adaptif Android: launcher hanya menampilkan 72 dari 108 dp di
    # tengah (66,7%), dan bentuk topengnya berbeda-beda tiap merek HP.
    # Isinya harus muat di lingkaran aman itu, dengan sedikit ruang napas.
    safe_radius = icon_size[0] * (72 / 108) / 2
    place_in_circle(icon_size, head, radius=safe_radius * 0.9).save(
        DESIGN / "app_icon_foreground.png"
    )

    # Pratinjau pemeriksaan visual -------------------------------------------
    for name, colour in (("magenta", (255, 0, 200)), ("biru", (24, 54, 200))):
        canvas = Image.new("RGBA", full.size, colour + (255,))
        canvas.alpha_composite(full)
        canvas.convert("RGB").save(DESIGN / f"preview_cutout_{name}.png")

    # Simulasi persis seperti launcher: hanya lingkaran 66,7% di tengah yang
    # terlihat. Ditampilkan berdampingan pada tiga ukuran, termasuk 48 px
    # (ukuran ikon sebenarnya di layar beranda HP berkerapatan sedang).
    adaptive = backdrop.copy()
    adaptive.alpha_composite(Image.open(DESIGN / "app_icon_foreground.png"))
    r = safe_radius
    box = (round(512 - r), round(512 - r), round(512 + r), round(512 + r))
    visible = adaptive.crop(box)
    side = visible.width
    yy, xx = np.mgrid[0:side, 0:side]
    circle = ((xx - side / 2) ** 2 + (yy - side / 2) ** 2) <= (side / 2) ** 2
    data = np.asarray(visible).copy()
    data[~circle] = (255, 255, 255, 255)
    visible = Image.fromarray(data, "RGBA").convert("RGB")
    sheet = Image.new("RGB", (256 + 128 + 48 + 80, 276), (255, 255, 255))
    x = 20
    for size in (256, 128, 48):
        sheet.paste(visible.resize((size, size), Image.LANCZOS), (x, 10))
        x += size + 20
    sheet.save(DESIGN / "preview_icon_circle.png")

    print(f"maskot penuh             : {full.size}")
    print(f"kepala (avatar & ikon)   : {head.size}")
    print("tersimpan                : assets/images/aura_mascot.png, aura_mascot_head.png")
    print("                           design/app_icon*.png")


if __name__ == "__main__":
    main()
