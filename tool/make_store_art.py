"""Draws Keeper of the Cove's logo, launcher icon sources and Play Store art.
Run from the project root (after tool/make_art.py):

    python tool/make_store_art.py

Writes:
  assets/icon/app_icon.png      1024 full-bleed icon (legacy launcher icon)
  assets/icon/app_icon_fg.png   1024 transparent foreground (adaptive icon)
  store/icon-512.png            Play Store hi-res icon
  store/feature-graphic.png     1024 x 500 Play Store feature graphic
Everything is drawn from code in the game's palette; the title uses the
bundled Spectral font (SIL OFL).
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ART = os.path.join(ROOT, 'assets', 'art')
ICON = os.path.join(ROOT, 'assets', 'icon')
STORE = os.path.join(ROOT, 'store')
os.makedirs(ICON, exist_ok=True)
os.makedirs(STORE, exist_ok=True)

SEA = (11, 22, 38)
TIDE = (21, 42, 63)
BEAM = (244, 184, 96)
HARBOR = (255, 217, 160)
RUST = (126, 74, 59)
WHITE = (222, 228, 234)


def vgrad(w, h, top, bottom):
    t = np.linspace(0, 1, h)[:, None, None]
    arr = np.array(top, dtype=np.float32) * (1 - t) + np.array(bottom, dtype=np.float32) * t
    return Image.fromarray(np.repeat(arr, w, axis=1).astype(np.uint8), 'RGB')


def radial(size, cx, cy, r, colour, alpha):
    """A light source: alpha falls off smoothly to exactly zero at r."""
    yy, xx = np.mgrid[0:size[1], 0:size[0]].astype(np.float32)
    d = np.clip(1 - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r, 0, 1) ** 2.2
    a = (d * alpha * 255).astype(np.uint8)
    img = Image.new('RGBA', size, colour + (0,))
    img.putalpha(Image.fromarray(a))
    return img


def beam_wedge(size, origin, angle, half, length, colour, alpha):
    """A cone of light with a soft radial falloff along its length."""
    w, h = size
    mask = Image.new('L', size, 0)
    ox, oy = origin
    pts = [(ox, oy),
           (ox + math.cos(angle - half) * length, oy + math.sin(angle - half) * length),
           (ox + math.cos(angle + half) * length, oy + math.sin(angle + half) * length)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(length * 0.02))
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    fall = np.clip(1 - np.sqrt((xx - ox) ** 2 + (yy - oy) ** 2) / length, 0, 1) ** 1.3
    a = (np.array(mask, dtype=np.float32) / 255 * fall * alpha * 255).astype(np.uint8)
    img = Image.new('RGBA', size, colour + (0,))
    img.putalpha(Image.fromarray(a))
    return img


def tower(img, cx, top, base, top_w, base_w, bands=5):
    """Banded tower with lamp room on [img]; returns the lamp centre."""
    d = ImageDraw.Draw(img)
    for k in range(bands):
        y0 = top + (base - top) * k / bands
        y1 = top + (base - top) * (k + 1) / bands
        hw0 = top_w + (base_w - top_w) * k / bands
        hw1 = top_w + (base_w - top_w) * (k + 1) / bands
        d.polygon([(cx - hw0, y0), (cx + hw0, y0), (cx + hw1, y1), (cx - hw1, y1)],
                  fill=(WHITE if k % 2 == 0 else RUST) + (255,))
    # Shadow side, blended (drawing straight onto the image would replace pixels).
    shade = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon(
        [(cx + top_w * 0.25, top), (cx + top_w, top), (cx + base_w, base), (cx + base_w * 0.25, base)],
        fill=(6, 10, 18, 90))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    s = top_w / 60
    # Gallery and lamp room.
    d.rectangle([cx - top_w * 1.35, top - 14 * s, cx + top_w * 1.35, top + 4 * s], fill=(30, 38, 50, 255))
    lamp_top = top - 110 * s
    d.rectangle([cx - top_w * 0.85, lamp_top, cx + top_w * 0.85, top - 14 * s], fill=(28, 36, 48, 255))
    d.rectangle([cx - top_w * 0.7, lamp_top + 10 * s, cx + top_w * 0.7, top - 24 * s], fill=HARBOR + (255,))
    d.pieslice([cx - top_w, lamp_top - 60 * s, cx + top_w, lamp_top + 50 * s], 180, 360, fill=(36, 44, 56, 255))
    return cx, (lamp_top + top - 14 * s) / 2


def logo(size, transparent):
    S = size * 2
    if transparent:
        img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    else:
        img = vgrad(S, S, (8, 14, 30), TIDE).convert('RGBA')
        # Stars.
        r = np.random.default_rng(3)
        d = ImageDraw.Draw(img)
        for _ in range(70):
            x, y = r.random() * S, r.random() * S * 0.6
            b = int(120 + 120 * r.random() ** 3)
            d.point((x, y), fill=(b, b, min(255, b + 20), 255))
    cx = S / 2
    # The adaptive foreground is inset 16 % by the icon tool, so draw it larger.
    top, base = (S * 0.36, S * 0.92) if transparent else (S * 0.42, S * 0.86)
    lamp = (cx, top - S * 0.06)
    # Two beams, as a real lighthouse throws them.
    for ang in (-math.pi * 0.86, -math.pi * 0.14):
        img.alpha_composite(beam_wedge((S, S), lamp, ang, 0.13, S * (0.4 if transparent else 0.9), BEAM,
                                       0.55 if transparent else 0.6))
    img.alpha_composite(radial((S, S), lamp[0], lamp[1], S * (0.24 if transparent else 0.32), BEAM, 0.75))
    if not transparent:
        # Sea and its glitter under the tower.
        sea = vgrad(S, int(S * 0.2), (30, 52, 80), SEA).convert('RGBA')
        img.alpha_composite(sea, (0, int(S * 0.8)))
        d = ImageDraw.Draw(img)
        r = np.random.default_rng(4)
        for _ in range(60):
            y = S * 0.82 + r.random() * S * 0.17
            x = cx + (r.random() - 0.5) * S * 0.5
            L = 6 + r.random() * 26
            d.line([(x - L, y), (x + L, y)], fill=HARBOR + (int(60 + 120 * r.random()),), width=3)
    d = ImageDraw.Draw(img)
    # Rock under the tower.
    d.polygon([(cx - S * 0.2, base), (cx - S * 0.13, base - S * 0.05), (cx + S * 0.12, base - S * 0.06),
               (cx + S * 0.21, base)], fill=(18, 24, 34, 255))
    tw = 0.075 if transparent else 0.055
    lx, ly = tower(img, cx, top, base - S * 0.04, S * tw, S * tw * 1.55)
    img.alpha_composite(radial((S, S), lx, ly, S * 0.09, HARBOR, 0.9))
    return img.resize((size, size), Image.LANCZOS)


def font(px, weight='SemiBold'):
    return ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', f'Spectral-{weight}.ttf'), px)


def feature_graphic():
    W, H = 1024, 500
    sea = Image.open(os.path.join(ART, 'sea_0.jpg')).convert('RGB')
    # The sea painting cropped to a wide strip, horizon near the top third.
    s = W / sea.width
    sea = sea.resize((W, int(sea.height * s)))
    img = sea.crop((0, int(sea.height * 0.02), W, int(sea.height * 0.02) + H)).convert('RGBA')
    img.alpha_composite(Image.new('RGBA', (W, H), SEA + (70,)))
    d = ImageDraw.Draw(img)
    # Lighthouse on the right, beam sweeping left across the water.
    cx, base = W * 0.8, H * 1.02
    lamp = (cx, H * 0.27)
    img.alpha_composite(beam_wedge((W, H), lamp, math.pi * 1.04, 0.11, W * 0.85, BEAM, 0.55))
    img.alpha_composite(radial((W, H), lamp[0], lamp[1], 150, BEAM, 0.7))
    d = ImageDraw.Draw(img)
    d.polygon([(cx - 120, H), (cx - 70, H * 0.86), (cx + 90, H * 0.84), (cx + 160, H)], fill=(16, 22, 32, 255))
    tower(img, cx, H * 0.38, base - 40, 30, 46)
    img.alpha_composite(radial((W, H), lamp[0], lamp[1], 46, HARBOR, 0.9))
    # Boats in the beam, using the game's own sprites.
    for (bx, by, sz, name) in ((W * 0.6, H * 0.72, 120, 'boat_skiff_lead'), (W * 0.46, H * 0.86, 96, 'boat_skiff_sloop'),
                               (W * 0.66, H * 0.5, 70, 'boat_skiff_drifter')):
        b = Image.open(os.path.join(ART, name + '.png')).convert('RGBA').resize((sz, sz), Image.LANCZOS)
        img.alpha_composite(radial((W, H), bx, by, sz * 0.5, BEAM, 0.35))
        img.alpha_composite(b, (int(bx - sz / 2), int(by - sz * 0.68)))
    # Title.
    d = ImageDraw.Draw(img)
    title = font(70)
    d.text((56, 150), 'Keeper', font=title, fill=(234, 241, 248, 255))
    d.text((56, 222), 'of the Cove', font=title, fill=(234, 241, 248, 255))
    d.text((60, 322), 'Sweep the light. Bring them home.', font=font(26, 'Medium'), fill=HARBOR + (255,))
    img.convert('RGB').save(os.path.join(STORE, 'feature-graphic.png'), optimize=True)
    print('store/feature-graphic.png 1024x500')


if __name__ == '__main__':
    full = logo(1024, False)
    full.convert('RGB').save(os.path.join(ICON, 'app_icon.png'), optimize=True)
    logo(1024, True).save(os.path.join(ICON, 'app_icon_fg.png'), optimize=True)
    full.resize((512, 512), Image.LANCZOS).convert('RGB').save(os.path.join(STORE, 'icon-512.png'), optimize=True)
    print('assets/icon/app_icon.png, app_icon_fg.png, store/icon-512.png')
    feature_graphic()
