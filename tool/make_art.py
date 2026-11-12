"""Paints every image in Keeper of the Cove from code (no stock art, no AI
images). Run from the project root:

    python tool/make_art.py

Writes assets/art/*.png. Uses only the palette in docs/DESIGN_LANGUAGE.md plus
physical light (moon, dusk, lamp glow, snow) inside the paintings.
Needs Pillow and numpy. Seeded, so every run paints the same pictures.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'assets', 'art')
os.makedirs(OUT, exist_ok=True)

W, H = 1080, 1920

SEA = (11, 22, 38)
TIDE = (21, 42, 63)
BEAM = (244, 184, 96)
HARBOR = (255, 217, 160)
RUST = (126, 74, 59)
TEXT = (234, 241, 248)
MUTED = (138, 160, 180)


def rng(seed):
    return np.random.default_rng(seed)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgrad(w, h, stops):
    """Vertical gradient through (t, colour) stops, as a float array."""
    ys = np.linspace(0, 1, h)
    img = np.zeros((h, w, 3), dtype=np.float32)
    for c in range(3):
        xs = [s[0] for s in stops]
        vs = [s[1][c] for s in stops]
        img[:, :, c] = np.interp(ys, xs, vs)[:, None]
    return img


def to_img(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def grain(arr, amount, seed):
    """Fine film grain so large fields never band on phone screens."""
    n = rng(seed).normal(0, amount, arr.shape[:2]).astype(np.float32)
    return arr + n[:, :, None]


def soft_noise(w, h, scale, seed, octaves=4):
    """Cheap value noise (bilinear upsampled random grids), 0..1."""
    r = rng(seed)
    acc = np.zeros((h, w), dtype=np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        gw = max(2, int(w / scale * (2 ** o)))
        gh = max(2, int(h / scale * (2 ** o)))
        grid = r.random((gh, gw)).astype(np.float32)
        layer = np.array(Image.fromarray((grid * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC),
                         dtype=np.float32) / 255
        acc += layer * amp
        total += amp
        amp *= 0.5
    return acc / total


def add_glow(img, cx, cy, radius, colour, alpha):
    """Additive radial light falloff (a real light source)."""
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    fall = np.clip(1 - d, 0, 1) ** 2.2 * alpha
    for c in range(3):
        img[:, :, c] += fall * colour[c]
    return img


def stars(img, count, top, bottom, seed, bright=1.0):
    r = rng(seed)
    h, w = img.shape[:2]
    for _ in range(count):
        x = int(r.random() * w)
        y = int(top + r.random() ** 1.6 * (bottom - top))
        b = (0.25 + 0.75 * r.random() ** 3) * 200 * bright
        img[y, x] += b
        if r.random() < 0.08 and 1 <= x < w - 1 and 1 <= y < h - 1:
            img[y - 1:y + 2, x] += b * 0.35
            img[y, x - 1:x + 2] += b * 0.35
    return img


def ripples(img, horizon, seed, colour, strength, density=1.0, moon_x=None):
    """Perspective ripple highlights: thin dashes, denser toward the horizon,
    brighter in the moon's path when one is given."""
    r = rng(seed)
    h, w = img.shape[:2]
    pil = to_img(img).convert('RGBA')
    layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    rows = int(900 * density)
    for _ in range(rows):
        u = r.random() ** 1.7  # 0 = horizon, 1 = foreground
        y = horizon + u * (h - horizon)
        length = 6 + u * 90 * r.random()
        x = r.random() * w
        a = strength * (0.25 + 0.75 * r.random())
        if moon_x is not None:
            path = math.exp(-((x - moon_x) / (120 + u * 260)) ** 2)
            a = a * (0.35 + 1.6 * path)
        thick = 1 if u < 0.5 else 2
        d.line([(x - length / 2, y), (x + length / 2, y)], fill=colour + (int(min(255, a)),), width=thick)
    layer = layer.filter(ImageFilter.GaussianBlur(0.6))
    pil.alpha_composite(layer)
    return np.array(pil.convert('RGB'), dtype=np.float32)


def save(arr_or_img, name):
    img = to_img(arr_or_img) if isinstance(arr_or_img, np.ndarray) else arr_or_img
    path = os.path.join(OUT, name)
    if name.endswith('.jpg'):
        img.convert('RGB').save(path, quality=90, optimize=True, progressive=True)
    else:
        img.save(path, optimize=True)
    print(f'{name:28s} {img.size[0]}x{img.size[1]}  {os.path.getsize(path) // 1024} KB')


# =========================================================== season seas ====
# The night watch looks out from the lamp room: a sliver of sky at the top,
# the open sea below. The renderer draws rocks, harbour and lamp on top.

def season_sea(index):
    horizon = int(H * 0.11)
    if index == 0:  # Still Water: clear, moonlit, glassy
        sky = [(0, (6, 12, 26)), (1, (30, 50, 78))]
        sea = [(0, (30, 50, 76)), (0.35, (15, 30, 50)), (1, SEA)]
        moon_x = W * 0.68
    elif index == 1:  # Fog Season: milky haze, moon smudged
        sky = [(0, (34, 44, 58)), (1, (70, 82, 96))]
        sea = [(0, (58, 70, 84)), (0.4, (28, 40, 54)), (1, (12, 22, 34))]
        moon_x = W * 0.3
    elif index == 2:  # Squall Coast: green-black water, cloud shelf
        sky = [(0, (12, 16, 22)), (0.6, (26, 34, 40)), (1, (44, 56, 60))]
        sea = [(0, (34, 50, 52)), (0.3, (16, 32, 36)), (1, (6, 14, 20))]
        moon_x = None
    else:  # The Long Winter: cold blue-white, aurora, snow
        sky = [(0, (8, 16, 34)), (1, (44, 68, 104))]
        sea = [(0, (48, 72, 102)), (0.35, (22, 40, 66)), (1, (10, 20, 36))]
        moon_x = W * 0.5

    img = np.zeros((H, W, 3), dtype=np.float32)
    img[:horizon] = vgrad(W, horizon, sky)
    img[horizon:] = vgrad(W, H - horizon, sea)

    # Water body texture: slow swells of light and dark.
    swell = soft_noise(W, H - horizon, 240, 10 + index)
    img[horizon:] *= (0.86 + 0.28 * swell)[:, :, None]

    if index == 0:
        img = stars(img, 260, 0, horizon - 4, 100)
        img = add_glow(img, moon_x, horizon * 0.45, 210, (180, 196, 220), 0.55)
        yy, xx = np.ogrid[:H, :W]
        disc = (xx - moon_x) ** 2 + (yy - horizon * 0.45) ** 2 <= 30 ** 2
        img[disc] = (226, 234, 244)
        img = ripples(img, horizon, 200, (205, 220, 238), 120, 1.0, moon_x)
    elif index == 1:
        img = add_glow(img, moon_x, horizon * 0.5, 420, (120, 132, 146), 0.6)
        img = ripples(img, horizon, 201, (170, 184, 198), 60, 0.6, moon_x)
        # Fog bands lying on the water.
        fog = soft_noise(W, H, 320, 33)
        band = np.zeros(H, dtype=np.float32)
        for c, s in ((0.15, 0.08), (0.42, 0.1), (0.7, 0.09)):
            band += np.exp(-((np.linspace(0, 1, H) - c) / s) ** 2)
        haze = (fog * 0.6 + 0.4) * band[:, None] * 70
        img += haze[:, :, None] * np.array([0.82, 0.88, 0.95])
    elif index == 2:
        cloud = soft_noise(W, horizon + 140, 160, 44)
        shelf = np.clip((cloud - 0.45) * 2.4, 0, 1)
        img[:horizon + 140] *= (1 - 0.45 * shelf)[:, :, None]
        img = ripples(img, horizon, 202, (150, 178, 176), 110, 1.4)
        # Whitecaps: short bright crests scattered through the swell.
        r = rng(55)
        pil = to_img(img).convert('RGBA')
        caps = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(caps)
        for _ in range(240):
            u = r.random() ** 1.3
            y = horizon + u * (H - horizon)
            x = r.random() * W
            L = 8 + u * 46
            d.arc([x - L, y - L * 0.25, x + L, y + L * 0.25], 200, 340,
                  fill=(206, 222, 220, int(60 + 120 * r.random())), width=1 + int(u * 2))
        pil.alpha_composite(caps.filter(ImageFilter.GaussianBlur(0.8)))
        img = np.array(pil.convert('RGB'), dtype=np.float32)
        # Slanted rain in the distance.
        rain = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(rain)
        for _ in range(500):
            x = r.random() * W
            y = r.random() * H * 0.6
            d.line([(x, y), (x - 10, y + 34)], fill=(160, 180, 186, 26), width=1)
        pil = to_img(img).convert('RGBA')
        pil.alpha_composite(rain)
        img = np.array(pil.convert('RGB'), dtype=np.float32)
    else:
        img = stars(img, 180, 0, horizon - 4, 103, 0.8)
        # A faint aurora ribbon low in the sky: real light, kept very quiet.
        xs = np.linspace(0, 1, W)
        ribbon_y = horizon * (0.55 + 0.18 * np.sin(xs * 5.2 + 0.6))
        yy = np.arange(horizon)[:, None]
        aur = np.exp(-((yy - ribbon_y[None, :]) / (horizon * 0.16)) ** 2) * (0.5 + 0.5 * np.sin(xs * 13)[None, :] ** 2)
        img[:horizon] += aur[:, :, None] * np.array([40, 92, 78]) * 0.9
        img = add_glow(img, moon_x, horizon * 0.35, 260, (170, 190, 220), 0.5)
        img = ripples(img, horizon, 203, (210, 226, 244), 105, 0.9, moon_x)
        # Drifting snow over everything.
        r = rng(77)
        pil = to_img(img).convert('RGBA')
        snow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(snow)
        for _ in range(700):
            x, y = r.random() * W, r.random() * H
            s = 0.8 + r.random() ** 3 * 3.2
            d.ellipse([x - s, y - s, x + s, y + s], fill=(236, 242, 250, int(70 + 110 * r.random())))
        pil.alpha_composite(snow.filter(ImageFilter.GaussianBlur(0.7)))
        img = np.array(pil.convert('RGB'), dtype=np.float32)

    # Horizon line: a thin edge of light where sky meets sea.
    img[horizon - 1:horizon + 2] += 18
    # Darker foreground near the tower: the lamp's own shadow side.
    vign = np.linspace(0, 1, H) ** 3 * 0.35
    img *= (1 - vign)[:, None, None]
    img = grain(img, 2.2, 900 + index)
    save(img, f'sea_{index}.jpg')


# =========================================================== play sprites ===

def rock(d, x, base, rw, rh, r, shade=1.0):
    """One broad, low, faceted rock: a dark body, a lit upper-left face and a
    wet rim. Rocks in this world are heavy, never spiky."""
    n = 7
    pts = [(x, base)]
    for k in range(1, n):
        t = k / n
        bump = math.sin(math.pi * t) ** 0.55
        pts.append((x + rw * t, base - rh * bump * (0.85 + 0.3 * r.random())))
    pts.append((x + rw, base))
    body = lerp((12, 18, 26), (34, 40, 48), 0.5 * shade)
    d.polygon(pts, fill=body + (255,))
    # Lit facet on the moon side.
    peak = max(range(1, n), key=lambda i: -pts[i][1])
    face = pts[:peak + 1] + [(pts[peak][0] - rw * 0.08, base - rh * 0.25), (x + rw * 0.1, base)]
    d.polygon(face, fill=lerp(body, (52, 62, 74), 0.6 * shade) + (255,))
    d.line(pts[1:peak + 1], fill=lerp(TIDE, MUTED, 0.6) + (int(170 * shade),), width=3)
    if r.random() < 0.3:
        px, py = pts[peak]
        d.line([(px + 6, py + 10), (px + 12, base - 6)], fill=RUST + (140,), width=5)


def rocks_strip():
    """The rock line across the cove mouth, 2x of 760x170 world units."""
    w, h = 1520, 340
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = rng(5)
    base = h * 0.8
    for row, (shade, lift, scale) in enumerate(((0.55, 34, 0.75), (1.0, 0, 1.0))):
        x = -40 + row * 30
        while x < w + 20:
            rw = (110 + r.random() * 150) * scale
            rh = (50 + r.random() * 70) * scale
            rock(d, x, base - lift, rw, rh, r, shade)
            x += rw * (0.62 + r.random() * 0.2)
    foam = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(foam)
    for _ in range(300):
        fx = r.random() * w
        fy = base + 4 + r.random() * 34
        L = 6 + r.random() * 34
        fd.line([(fx - L, fy), (fx + L, fy)], fill=(200, 214, 226, int(70 + 120 * r.random())), width=2)
    img.alpha_composite(foam.filter(ImageFilter.GaussianBlur(1.4)))
    save(img, 'rocks.png')


def harbor():
    """Bottom-left harbour: stone breakwater, two cottages with warm windows,
    moored boats. 2x of 300x420 world units."""
    w, h = 600, 840
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Land mass.
    land = [(0, h * 0.30), (w * 0.35, h * 0.28), (w * 0.62, h * 0.36), (w * 0.72, h * 0.52),
            (w * 0.55, h * 0.62), (w * 0.62, h * 0.78), (w * 0.4, h), (0, h)]
    d.polygon(land, fill=(12, 20, 30, 255))
    d.line(land[:4], fill=lerp(TIDE, MUTED, 0.5) + (140,), width=3)
    # Breakwater arm with a small light at its tip.
    arm = [(w * 0.55, h * 0.62), (w * 0.95, h * 0.56), (w * 0.97, h * 0.6), (w * 0.6, h * 0.68)]
    d.polygon(arm, fill=(26, 34, 44, 255))
    d.line(arm[:2], fill=lerp(TIDE, MUTED, 0.5) + (150,), width=3)
    # Cottages.
    for (cx, cy, cw, ch) in ((w * 0.12, h * 0.2, 120, 92), (w * 0.38, h * 0.22, 100, 80)):
        d.rectangle([cx, cy, cx + cw, cy + ch], fill=(30, 40, 52, 255))
        d.polygon([(cx - 10, cy), (cx + cw / 2, cy - ch * 0.6), (cx + cw + 10, cy)], fill=(22, 30, 40, 255))
        d.line([(cx - 10, cy), (cx + cw / 2, cy - ch * 0.6)], fill=lerp(TIDE, MUTED, 0.5) + (150,), width=3)
        d.rectangle([cx + cw * 0.62, cy - ch * 0.62, cx + cw * 0.76, cy - ch * 0.25], fill=(26, 34, 44, 255))
        for wx in (0.18, 0.56):
            d.rectangle([cx + cw * wx, cy + ch * 0.32, cx + cw * (wx + 0.22), cy + ch * 0.62], fill=HARBOR + (255,))
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for (gx, gy) in ((w * 0.2, h * 0.27), (w * 0.3, h * 0.27), (w * 0.44, h * 0.28), (w * 0.52, h * 0.28)):
        gd.ellipse([gx - 50, gy - 40, gx + 50, gy + 40], fill=BEAM + (70,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))
    # Window light on the water.
    for gx in (w * 0.24, w * 0.47):
        for k in range(8):
            y = h * 0.44 + k * 9
            d.line([(gx - 20 + k * 2, y), (gx + 20 - k * 2, y)], fill=HARBOR + (110 - k * 12,), width=2)
    # Breakwater lamp.
    d.ellipse([w * 0.95 - 9, h * 0.56 - 28, w * 0.95 + 9, h * 0.56 - 10], fill=HARBOR + (255,))
    tip = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tip).ellipse([w * 0.95 - 40, h * 0.56 - 60, w * 0.95 + 40, h * 0.56 + 20], fill=BEAM + (90,))
    img.alpha_composite(tip.filter(ImageFilter.GaussianBlur(18)))
    # Moored boats.
    for (bx, by) in ((w * 0.7, h * 0.47), (w * 0.82, h * 0.5)):
        d.polygon([(bx - 26, by), (bx + 26, by), (bx + 18, by + 12), (bx - 18, by + 12)], fill=(40, 50, 62, 255))
        d.line([(bx, by), (bx, by - 44)], fill=(90, 104, 118, 255), width=3)
    save(img, 'harbor.png')


def lamp_gallery():
    """The lamp room seen from the gallery behind it, bottom centre of the play
    field. 2x of 300x220 world units. The lens itself is drawn live (it glows
    in the beam's colour)."""
    w, h = 600, 440
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h * 0.42
    # Gallery floor: an iron ring seen in perspective.
    d.ellipse([cx - 270, cy + 30, cx + 270, cy + 230], fill=(18, 26, 36, 255))
    d.ellipse([cx - 270, cy + 30, cx + 270, cy + 230], outline=lerp(TIDE, MUTED, 0.55) + (200,), width=4)
    # Railing posts and top rail.
    for k in range(17):
        a = math.pi * (k / 16)
        px = cx + math.cos(a) * 262
        py = cy + 130 - math.sin(a) * 96
        d.line([(px, py), (px, py - 70)], fill=(56, 68, 82, 255), width=5)
    d.arc([cx - 262, cy + 34 - 70, cx + 262, cy + 226 - 70], 180, 360, fill=(80, 96, 112, 255), width=6)
    # Lamp room: glazed drum with iron mullions, dome on top.
    d.rounded_rectangle([cx - 120, cy - 70, cx + 120, cy + 120], radius=14, fill=(24, 34, 48, 255))
    for k in range(-2, 3):
        d.line([(cx + k * 48, cy - 70), (cx + k * 48, cy + 120)], fill=(46, 58, 72, 255), width=6)
    d.pieslice([cx - 130, cy - 170, cx + 130, cy + 30], 180, 360, fill=(30, 40, 54, 255))
    d.arc([cx - 130, cy - 170, cx + 130, cy + 30], 200, 300, fill=lerp(TIDE, MUTED, 0.7) + (220,), width=4)
    d.ellipse([cx - 12, cy - 186, cx + 12, cy - 162], fill=(52, 64, 78, 255))
    # Rim light from the lens.
    d.line([(cx - 118, cy + 118), (cx + 118, cy + 118)], fill=BEAM + (120,), width=3)
    save(img, 'lamp_gallery.png')


BOAT_THEMES = {
    'skiff': {'hull': (92, 106, 124), 'sail': (206, 214, 222), 'trim': (170, 184, 198)},
    'tan': {'hull': (88, 92, 100), 'sail': (180, 120, 94), 'trim': (196, 140, 112)},
    'painted': {'hull': (52, 86, 122), 'sail': (230, 234, 236), 'trim': (244, 184, 96)},
}


def boat(style, theme):
    """A small vessel in 3/4 view, 160x160 (display ~ 64 world units)."""
    S = 160
    img = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))  # 2x supersample
    d = ImageDraw.Draw(img)
    c = BOAT_THEMES[theme]
    cx, wl = S, S * 1.36
    # Wake / waterline shadow.
    d.ellipse([cx - 86, wl - 8, cx + 86, wl + 22], fill=(4, 10, 18, 120))
    hull_w = 74 if style != 'lead' else 88
    hull = [(cx - hull_w, wl - 26), (cx + hull_w, wl - 26), (cx + hull_w * 0.78, wl + 4), (cx - hull_w * 0.72, wl + 4)]
    d.polygon(hull, fill=c['hull'] + (255,))
    d.line(hull[:2], fill=c['trim'] + (255,), width=6)
    if style in ('sloop', 'lead'):
        mast_h = 150 if style == 'lead' else 130
        d.line([(cx, wl - 26), (cx, wl - 26 - mast_h)], fill=(70, 82, 96, 255), width=6)
        d.polygon([(cx + 4, wl - 26 - mast_h + 6), (cx + 4, wl - 34), (cx + 70, wl - 34)], fill=c['sail'] + (255,))
        d.polygon([(cx - 4, wl - 26 - mast_h * 0.8), (cx - 4, wl - 34), (cx - 52, wl - 34)], fill=lerp(c['sail'], c['hull'], 0.25) + (255,))
    elif style == 'drifter':
        d.rectangle([cx - 30, wl - 76, cx + 22, wl - 26], fill=lerp(c['hull'], TEXT, 0.18) + (255,))
        d.rectangle([cx - 20, wl - 64, cx - 4, wl - 48], fill=HARBOR + (230,))
        d.line([(cx + 40, wl - 26), (cx + 40, wl - 110)], fill=(70, 82, 96, 255), width=5)
        d.line([(cx + 40, wl - 110), (cx - 50, wl - 30)], fill=(70, 82, 96, 200), width=2)
    else:  # rowing skiff with a lantern on a pole
        d.line([(cx - 40, wl - 26), (cx - 40, wl - 86)], fill=(70, 82, 96, 255), width=5)
        d.ellipse([cx - 50, wl - 104, cx - 30, wl - 82], fill=HARBOR + (255,))
    if style == 'lead':
        # Masthead lantern: leads carry a light so the fleet can follow.
        d.ellipse([cx - 13, wl - 196, cx + 13, wl - 170], fill=HARBOR + (255,))
    img = img.resize((S, S), Image.LANCZOS)
    if style == 'lead':
        halo = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([S / 2 - 24, S * 0.68 - 98 / 2 - 24, S / 2 + 24, S * 0.68 - 98 / 2 + 24], fill=BEAM + (90,))
        halo = halo.filter(ImageFilter.GaussianBlur(8))
        halo.alpha_composite(img)
        img = halo
    save(img, f'boat_{theme}_{style}.png')


def buoy(lit):
    S = 200
    img = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, wl = S, S * 1.4
    d.ellipse([cx - 60, wl - 10, cx + 60, wl + 20], fill=(4, 10, 18, 120))
    body = RUST if not lit else lerp(RUST, BEAM, 0.25)
    d.polygon([(cx - 56, wl), (cx + 56, wl), (cx + 40, wl - 40), (cx - 40, wl - 40)], fill=body + (255,))
    # Cage with the bell inside.
    for dx in (-30, 0, 30):
        d.line([(cx + dx, wl - 40), (cx + dx * 0.5, wl - 150)], fill=(80, 92, 104, 255), width=7)
    d.ellipse([cx - 22, wl - 120, cx + 22, wl - 70], fill=((150, 128, 90) if not lit else BEAM) + (255,))
    lamp = HARBOR if lit else (64, 74, 86)
    d.ellipse([cx - 16, wl - 182, cx + 16, wl - 150], fill=lamp + (255,))
    img = img.resize((S, S), Image.LANCZOS)
    if lit:
        halo = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(halo).ellipse([S / 2 - 34, S * 0.7 - 83 - 34, S / 2 + 34, S * 0.7 - 83 + 34], fill=BEAM + (120,))
        halo = halo.filter(ImageFilter.GaussianBlur(12))
        halo.alpha_composite(img)
        img = halo
    save(img, f'buoy_{"lit" if lit else "dark"}.png')


# =================================================================== hub ====
# Positions shared with lib/screens/hub_screen.dart (fractions of 1080x1920).
TOWER_X = 0.70


def hub():
    horizon = int(H * 0.585)
    img = np.zeros((H, W, 3), dtype=np.float32)
    # Dusk sky: indigo overhead warming to the last light at the horizon.
    img[:horizon] = vgrad(W, horizon, [(0, (7, 13, 28)), (0.55, (20, 36, 62)),
                                       (0.85, (58, 62, 82)), (1, (122, 96, 92))])
    img[horizon:] = vgrad(W, H - horizon, [(0, (52, 60, 80)), (0.15, (24, 40, 62)), (1, (8, 16, 28))])
    img = stars(img, 340, 0, horizon * 0.7, 300)
    # Moon (a hotspot: The Longest Night).
    mx, my = W * 0.2, H * 0.12
    img = add_glow(img, mx, my, 260, (150, 168, 196), 0.6)
    yy, xx = np.ogrid[:H, :W]
    img[(xx - mx) ** 2 + (yy - my) ** 2 <= 46 ** 2] = (224, 232, 242)
    # Moon craters, softly.
    for (ox, oy, r) in ((-14, -10, 11), (12, 8, 8), (4, -20, 6)):
        img[(xx - mx - ox) ** 2 + (yy - my - oy) ** 2 <= r ** 2] -= 14
    # Last light glow at the horizon behind the far shore.
    img = add_glow(img, W * 0.36, horizon, 620, (110, 70, 40), 0.55)

    pil = to_img(img).convert('RGBA')
    d = ImageDraw.Draw(pil)
    r = rng(8)

    # Far shore across the cove with the village (windows are drawn live).
    shore = [(0, horizon - 70), (W * 0.1, horizon - 92), (W * 0.22, horizon - 60), (W * 0.34, horizon - 78),
             (W * 0.46, horizon - 30), (W * 0.56, horizon - 12), (W * 0.56, horizon + 8), (0, horizon + 8)]
    d.polygon(shore, fill=(18, 26, 40, 255))
    for k in range(14):
        hx = W * 0.02 + k * W * 0.032 + r.random() * 8
        hw, hh = 22 + r.random() * 14, 18 + r.random() * 16
        base = horizon - 40 + k * 2.2
        d.rectangle([hx, base - hh, hx + hw, base + 30], fill=(24, 32, 46, 255))
        d.polygon([(hx - 3, base - hh), (hx + hw / 2, base - hh - 12), (hx + hw + 3, base - hh)], fill=(20, 28, 42, 255))
    # A church spire, because every cove has one.
    d.polygon([(W * 0.29, horizon - 78), (W * 0.30, horizon - 150), (W * 0.31, horizon - 78)], fill=(20, 28, 42, 255))

    # Water reflections of the dusk light.
    ref = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ref)
    for _ in range(700):
        u = r.random() ** 1.5
        y = horizon + 10 + u * (H - horizon)
        x = W * 0.36 + (r.random() - 0.5) * (200 + u * 700)
        L = 6 + u * 70
        rd.line([(x - L, y), (x + L, y)], fill=(200, 160, 120, int(20 + 90 * (1 - u) * r.random())), width=1 + int(u * 2))
    for _ in range(500):
        u = r.random() ** 1.5
        y = horizon + 10 + u * (H - horizon)
        x = r.random() * W
        L = 4 + u * 50
        rd.line([(x - L, y), (x + L, y)], fill=(150, 170, 200, int(15 + 50 * r.random())), width=1)
    pil.alpha_composite(ref.filter(ImageFilter.GaussianBlur(0.7)))

    # Left spit with the boathouse (The Chandlery) and the jetty with the tide bell.
    spit = [(0, H * 0.66), (W * 0.2, H * 0.655), (W * 0.3, H * 0.69), (W * 0.24, H * 0.72), (0, H * 0.74)]
    d.polygon(spit, fill=(14, 20, 30, 255))
    d.line(spit[:3], fill=lerp(TIDE, MUTED, 0.45) + (150,), width=3)
    bx, by = W * 0.06, H * 0.615
    d.rectangle([bx, by, bx + 190, by + 90], fill=(34, 42, 54, 255))
    d.polygon([(bx - 14, by), (bx + 95, by - 64), (bx + 204, by)], fill=(26, 32, 44, 255))
    d.line([(bx - 14, by), (bx + 95, by - 64), (bx + 204, by)], fill=lerp(TIDE, MUTED, 0.5) + (170,), width=3)
    d.rectangle([bx + 70, by + 30, bx + 120, by + 90], fill=(18, 24, 34, 255))  # boat door
    d.rectangle([bx + 18, by + 26, bx + 50, by + 52], fill=HARBOR + (230,))
    # Jetty planks running out over the water.
    jx, jy = W * 0.2, H * 0.7
    for k in range(9):
        px = jx + k * 26
        py = jy + k * 14
        d.polygon([(px, py), (px + 28, py + 14), (px + 28, py + 26), (px, py + 12)], fill=(46, 40, 38, 255))
        d.line([(px + 10, py + 18), (px + 10, py + 80)], fill=(30, 28, 30, 255), width=4)
    # The tide bell on its post at the end of the jetty.
    tbx, tby = W * 0.425, H * 0.735
    d.line([(tbx, tby + 70), (tbx, tby - 70)], fill=(52, 46, 44, 255), width=8)
    d.line([(tbx - 30, tby - 70), (tbx + 30, tby - 70)], fill=(52, 46, 44, 255), width=8)
    d.polygon([(tbx - 22, tby - 22), (tbx + 22, tby - 22), (tbx + 14, tby - 60), (tbx - 14, tby - 60)], fill=(150, 116, 70, 255))
    d.arc([tbx - 22, tby - 30, tbx + 22, tby - 14], 0, 180, fill=(200, 160, 100, 255), width=3)

    # Rocks under the lighthouse.
    rocks = [(W * 0.44, H * 0.86), (W * 0.5, H * 0.76), (W * 0.58, H * 0.72), (W * 0.66, H * 0.7),
             (W * 0.82, H * 0.71), (W * 0.92, H * 0.74), (W, H * 0.73), (W, H * 0.9), (W * 0.44, H * 0.9)]
    d.polygon(rocks, fill=(14, 20, 28, 255))
    d.line(rocks[:7], fill=lerp(TIDE, MUTED, 0.5) + (170,), width=4)
    # Boulders along the waterline, back to front so nearer ones overlap.
    for row in range(3):
        y = H * (0.8 + row * 0.035)
        x = W * (0.44 + row * 0.01) + r.random() * 30
        while x < W:
            rw = 90 + r.random() * 130
            rock(d, x, y, rw, 40 + r.random() * 50, r, 0.6 + row * 0.2)
            x += rw * (0.7 + r.random() * 0.2)
    # Keeper's cottage at the foot of the tower (door, window with the logbook).
    kx, ky = W * 0.47, H * 0.7
    d.rectangle([kx, ky, kx + 150, ky + 96], fill=(40, 48, 60, 255))
    d.polygon([(kx - 14, ky), (kx + 75, ky - 58), (kx + 164, ky)], fill=(30, 36, 48, 255))
    d.line([(kx - 14, ky), (kx + 75, ky - 58), (kx + 164, ky)], fill=lerp(TIDE, MUTED, 0.5) + (170,), width=3)
    d.rectangle([kx + 96, ky + 34, kx + 130, ky + 96], fill=(24, 30, 40, 255))  # door
    d.rectangle([kx + 18, ky + 28, kx + 66, ky + 64], fill=HARBOR + (240,))  # window (logbook sits here)
    d.line([(kx + 42, ky + 28), (kx + 42, ky + 64)], fill=(40, 48, 60, 255), width=3)
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([kx - 30, ky - 10, kx + 110, ky + 100], fill=BEAM + (60,))
    ImageDraw.Draw(glow).ellipse([bx - 20, by - 10, bx + 90, by + 80], fill=BEAM + (50,))
    pil.alpha_composite(glow.filter(ImageFilter.GaussianBlur(30)))

    arr = grain(np.array(pil.convert('RGB'), dtype=np.float32), 2.0, 999)
    save(arr, 'hub.jpg')


def tower(paint):
    """The lighthouse tower, drawn separately so its paint can change.
    360x1300 px; placed by the hub centred at TOWER_X, top at 0.165 H."""
    w, h = 360, 1300
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = w / 2
    top, base = 260, h - 20
    top_w, base_w = 78, 124
    stripes = {
        'rust': ((214, 220, 226), RUST),
        'tide': ((214, 220, 226), (36, 62, 92)),
        'whitewash': ((206, 212, 218), (206, 212, 218)),
        'stone': ((96, 100, 104), (82, 86, 90)),
    }[paint]
    bands = 6
    for k in range(bands):
        y0 = top + (base - top) * k / bands
        y1 = top + (base - top) * (k + 1) / bands
        hw0 = top_w + (base_w - top_w) * k / bands
        hw1 = top_w + (base_w - top_w) * (k + 1) / bands
        col = stripes[k % 2]
        d.polygon([(cx - hw0, y0), (cx + hw0, y0), (cx + hw1, y1), (cx - hw1, y1)], fill=col + (255,))
    if paint == 'stone':
        r = rng(3)
        for _ in range(260):
            y = top + r.random() * (base - top)
            hw = top_w + (base_w - top_w) * (y - top) / (base - top)
            x = cx - hw + r.random() * hw * 2
            d.rectangle([x, y, x + 18, y + 8], outline=(70, 74, 78, 255))
    # Shading: the moon lights the left side, the right falls into shadow.
    shade = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for k in range(40):
        t = k / 40
        x0 = cx + (t - 0.1) * base_w
        sd.line([(x0, top), (x0 + 30, base)], fill=(6, 10, 18, int(150 * t)), width=6)
    shade = shade.filter(ImageFilter.GaussianBlur(8))
    mask = Image.new('L', (w, h), 0)
    ImageDraw.Draw(mask).polygon([(cx - top_w, top), (cx + top_w, top), (cx + base_w, base), (cx - base_w, base)], fill=255)
    img.paste(Image.alpha_composite(img, shade), (0, 0), mask)
    d = ImageDraw.Draw(img)
    # Small windows up the tower.
    for y in (top + 260, top + 560, top + 820):
        d.rounded_rectangle([cx - 10, y, cx + 10, y + 34], radius=8, fill=(30, 40, 52, 255))
    # Gallery and railing.
    d.rectangle([cx - 104, top - 24, cx + 104, top + 6], fill=(30, 38, 50, 255))
    for k in range(13):
        x = cx - 100 + k * 16.6
        d.line([(x, top - 24), (x, top - 70)], fill=(70, 82, 96, 255), width=3)
    d.line([(cx - 104, top - 70), (cx + 104, top - 70)], fill=(80, 94, 110, 255), width=5)
    # Lamp room (the window is a hotspot: Tend the Light).
    d.rectangle([cx - 62, top - 160, cx + 62, top - 24], fill=(28, 36, 48, 255))
    d.rectangle([cx - 52, top - 150, cx + 52, top - 34], fill=HARBOR + (255,))
    for x in (-18, 18):
        d.line([(cx + x, top - 150), (cx + x, top - 34)], fill=(60, 66, 74, 255), width=4)
    d.pieslice([cx - 72, top - 236, cx + 72, top - 92], 180, 360, fill=(36, 44, 56, 255))
    d.line([(cx, top - 236), (cx, top - 260)], fill=(70, 82, 96, 255), width=5)
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([cx - 130, top - 200, cx + 130, top + 20], fill=BEAM + (110,))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    glow.alpha_composite(img)
    save(glow, f'tower_{paint}.png')


def keepsakes():
    S = 192

    def canvas():
        return Image.new('RGBA', (S, S), (0, 0, 0, 0))

    # Wind vane: an iron cockerel on a rod.
    img = canvas()
    d = ImageDraw.Draw(img)
    d.line([(96, 190), (96, 70)], fill=(80, 92, 104, 255), width=6)
    d.line([(60, 120), (132, 120)], fill=(80, 92, 104, 255), width=4)
    d.polygon([(70, 70), (110, 46), (140, 60), (126, 74), (100, 76)], fill=(60, 70, 82, 255))
    d.polygon([(70, 70), (52, 56), (62, 80)], fill=(60, 70, 82, 255))
    save(img, 'keepsake_vane.png')
    # Herb garden: a low bed of greens with a few pale flowers.
    img = canvas()
    d = ImageDraw.Draw(img)
    r = rng(12)
    d.rectangle([16, 150, 176, 186], fill=(54, 44, 40, 255))
    for _ in range(90):
        x, y = 20 + r.random() * 152, 100 + r.random() * 56
        d.ellipse([x - 7, y - 4, x + 7, y + 4], fill=(48 + int(r.random() * 30), 78 + int(r.random() * 30), 66, 255))
    for _ in range(14):
        x, y = 24 + r.random() * 144, 100 + r.random() * 40
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=(222, 214, 196, 255))
    save(img, 'keepsake_garden.png')
    # A sleeping cat, curled.
    img = canvas()
    d = ImageDraw.Draw(img)
    d.ellipse([30, 104, 162, 176], fill=(46, 50, 58, 255))
    d.ellipse([116, 92, 168, 140], fill=(46, 50, 58, 255))
    d.polygon([(124, 100), (130, 76), (142, 98)], fill=(46, 50, 58, 255))
    d.polygon([(148, 98), (158, 76), (164, 102)], fill=(46, 50, 58, 255))
    d.arc([40, 120, 150, 184], 170, 300, fill=(70, 76, 86, 255), width=10)
    d.arc([130, 112, 146, 122], 20, 160, fill=(120, 126, 134, 255), width=2)
    save(img, 'keepsake_cat.png')
    # Bunting: a string of small flags.
    img = Image.new('RGBA', (S * 2, S // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = [(x, 20 + 18 * math.sin(math.pi * x / (S * 2))) for x in range(0, S * 2 + 1, 4)]
    d.line(pts, fill=(120, 128, 136, 255), width=2)
    cols = [RUST, (214, 220, 226), (36, 62, 92), BEAM]
    for k in range(10):
        x = 16 + k * 36
        y = 20 + 18 * math.sin(math.pi * x / (S * 2))
        d.polygon([(x - 12, y), (x + 12, y), (x, y + 30)], fill=cols[k % 4] + (255,))
    save(img, 'keepsake_bunting.png')
    # A brass telescope on a tripod.
    img = canvas()
    d = ImageDraw.Draw(img)
    for dx in (-40, 0, 40):
        d.line([(96, 110), (96 + dx, 186)], fill=(70, 62, 52, 255), width=5)
    d.line([(40, 120), (160, 70)], fill=(176, 138, 82, 255), width=16)
    d.line([(40, 120), (70, 108)], fill=(140, 108, 64, 255), width=20)
    d.ellipse([152, 62, 168, 80], fill=(120, 150, 170, 255))
    save(img, 'keepsake_telescope.png')


if __name__ == '__main__':
    for i in range(4):
        season_sea(i)
    rocks_strip()
    harbor()
    lamp_gallery()
    for theme in BOAT_THEMES:
        for style in ('skiff', 'sloop', 'drifter', 'lead'):
            boat(style, theme)
    buoy(False)
    buoy(True)
    hub()
    for p in ('rust', 'tide', 'whitewash', 'stone'):
        tower(p)
    keepsakes()
