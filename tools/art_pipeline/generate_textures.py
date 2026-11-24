#!/usr/bin/env python3
"""
Procedural High-Resolution Texture Generator for mygame (Godot 4)
Generates:
  1. 3x Blue Archive-style crisp anime face UV textures (1024x1024, 2x supersampled)
  2. 3x Character HUD icon emblems / mini-portraits (512x512)
  3. Post-apocalyptic urban ruins & Kabaneri armored train PBR textures (1024x1024)
"""

import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FACE_DIR = os.path.join(ROOT_DIR, "assets", "textures", "faces")
ENV_DIR = os.path.join(ROOT_DIR, "assets", "textures", "env")
os.makedirs(FACE_DIR, exist_ok=True)
os.makedirs(ENV_DIR, exist_ok=True)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))


def draw_anime_eye(
    canvas: Image.Image,
    cx: float,
    cy: float,
    side: int,  # -1 = left eye (viewer's left), +1 = right eye (viewer's right)
    rx: float,
    ry: float,
    iris_top: tuple,
    iris_mid: tuple,
    iris_bot: tuple,
    pupil_col: tuple,
    lash_col: tuple,
    style: str = "cool",
):
    """Draw a single high-craft Blue Archive-style anime eye onto RGBA canvas."""
    w, h = canvas.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Outer tilt depending on eye style
    tilt = 0.08 if style == "cool" else (-0.04 if style == "cat" else 0.02)

    # 1. Sclera mask — authentic Blue Archive horizontal-almond chibi anime eye
    # Wider than tall, flatter expressive top arch, minimal white below iris
    sclera_pts = []
    steps = 56
    for i in range(steps):
        ang = (i / steps) * math.tau
        ca = math.cos(ang)
        sa = math.sin(ang)
        if sa < 0:
            # Top arch: broad anime hood curve
            y_mod = 0.78 if style == "cool" else (0.86 if style == "cat" else 0.90)
            x_mod = 1.04
        else:
            # Lower lid: gentle shallow curve so iris rests cleanly on bottom lid
            y_mod = 0.72 if style == "cool" else (0.76 if style == "cat" else 0.82)
            x_mod = 0.94
        x = ca * rx * x_mod
        y = sa * ry * y_mod
        # Subtle anime outer corner lift / inner corner softness
        if (side < 0 and ca < 0) or (side > 0 and ca > 0):
            y -= (abs(ca) ** 1.4) * ry * (0.14 if style != "round" else 0.05)
        sclera_pts.append((cx + x, cy + y))

    draw.polygon(sclera_pts, fill=(253, 253, 255, 255))

    # Build a sclera alpha mask for clean clipping of iris and upper shadow
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(sclera_pts, fill=255)

    eye_inner = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ed = ImageDraw.Draw(eye_inner)

    # 2. Soft cool lavender-blue upper sclera shadow
    ed.rectangle(
        [cx - rx * 1.2, cy - ry * 1.2, cx + rx * 1.2, cy - ry * 0.16],
        fill=(224, 230, 246, 145),
    )

    # 3. Large Blue Archive Iris (fills ~78% of visible eye, slightly tucked under upper lash!)
    irx = rx * 0.74
    iry = ry * 0.84
    icx = cx + (-side * rx * 0.04)
    icy = cy - ry * 0.02

    x0 = max(0, int(icx - irx - 4))
    x1 = min(w, int(icx + irx + 4))
    y0 = max(0, int(icy - iry - 4))
    y1 = min(h, int(icy + iry + 4))

    yy, xx = np.mgrid[y0:y1, x0:x1]
    nx = (xx - icx) / irx
    ny = (yy - icy) / iry
    r2 = nx * nx + ny * ny
    inside = r2 <= 1.0
    r = np.sqrt(np.clip(r2, 0.0, 2.0))

    vt = np.clip((ny + 1.0) * 0.5, 0.0, 1.0)

    iris_arr = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.uint8)
    for c in range(3):
        top_v = iris_top[c]
        mid_v = iris_mid[c]
        bot_v = iris_bot[c]
        col_val = np.where(
            vt < 0.48,
            top_v + (mid_v - top_v) * (vt / 0.48),
            mid_v + (bot_v - mid_v) * ((vt - 0.48) / 0.52),
        )
        # Signature luminous anime lower crescent glow
        crescent = np.exp(-((nx * 1.35) ** 2 + ((ny - 0.50) * 2.7) ** 2)) * 78.0
        col_val = col_val + crescent

        # Crisp dark outer iris rim
        ring_mask = np.clip((r - 0.84) / 0.16, 0.0, 1.0)
        col_val = col_val * (1.0 - 0.42 * ring_mask) + pupil_col[c] * (0.42 * ring_mask)

        # Rich deep top shade inside iris
        top_shade = np.clip((-ny - 0.05) / 0.90, 0.0, 1.0)
        col_val = col_val * (1.0 - 0.52 * top_shade)

        iris_arr[:, :, c] = np.clip(col_val, 0, 255).astype(np.uint8)

    alpha_iris = np.clip((1.0 - r) * 20.0, 0.0, 1.0) * 255.0
    iris_arr[:, :, 3] = np.where(inside | (r < 1.03), alpha_iris, 0).astype(np.uint8)
    iris_img = Image.fromarray(iris_arr, mode="RGBA")
    eye_inner.alpha_composite(iris_img, dest=(x0, y0))

    # 4. Crisp Anime Pupil
    prx = irx * 0.34
    pry = iry * 0.36
    ed.ellipse(
        [icx - prx, icy - pry * 0.85, icx + prx, icy + pry * 1.0],
        fill=(*pupil_col, 245),
    )

    # Lower luminous arc inside iris
    ed.arc(
        [icx - irx * 0.58, icy - iry * 0.42, icx + irx * 0.58, icy + iry * 0.68],
        start=28,
        end=152,
        fill=(255, 255, 255, 165),
        width=max(2, int(rx * 0.045)),
    )

    # 5. Glossy Blue Archive Specular Highlights
    hx1 = icx - irx * 0.38
    hy1 = icy - iry * 0.32
    ed.ellipse(
        [hx1 - irx * 0.23, hy1 - iry * 0.19, hx1 + irx * 0.23, hy1 + iry * 0.19],
        fill=(255, 255, 255, 252),
    )
    hx2 = icx + irx * 0.36
    hy2 = icy + iry * 0.28
    ed.ellipse(
        [hx2 - irx * 0.10, hy2 - iry * 0.10, hx2 + irx * 0.10, hy2 + iry * 0.10],
        fill=(255, 255, 255, 240),
    )
    hx3 = icx + irx * 0.30
    hy3 = icy - iry * 0.28
    sr = irx * 0.12
    ed.polygon(
        [(hx3, hy3 - sr), (hx3 + sr * 0.62, hy3), (hx3, hy3 + sr), (hx3 - sr * 0.62, hy3)],
        fill=(255, 255, 255, 230),
    )

    # Clip eye_inner to sclera mask
    clipped = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    clipped.paste(eye_inner, (0, 0), mask)
    layer.alpha_composite(clipped)

    # 6. Bold Curved Blue Archive Upper Eyelash Ribbon (with delicate outer wing!)
    upper_outer = []
    upper_inner = []
    arch_steps = 32
    y_top_mod = 0.78 if style == "cool" else (0.86 if style == "cat" else 0.90)
    for i in range(arch_steps + 1):
        t = i / arch_steps  # 0 = inner corner, 1 = outer corner
        ang = math.pi * t if side < 0 else math.pi * (1.0 - t)
        ca = math.cos(ang)
        sa = -abs(math.sin(ang))
        x = cx + ca * rx * 1.08
        y = cy + sa * ry * y_top_mod
        if (side < 0 and ca < 0) or (side > 0 and ca > 0):
            y -= (abs(ca) ** 1.4) * ry * (0.14 if style != "round" else 0.05)
        thickness = ry * (0.10 + 0.16 * math.sin(t * math.pi) + 0.14 * (t ** 2.2))
        upper_inner.append((x, y + thickness * 0.32))
        wing_x = side * (t ** 3.2) * rx * 0.20
        wing_y = -(t ** 3.2) * ry * (0.14 if style != "round" else 0.06)
        upper_outer.append((x + wing_x, y - thickness * 0.78 + wing_y))

    lash_poly = upper_outer + list(reversed(upper_inner))
    draw.polygon(lash_poly, fill=(*lash_col, 255))

    # Colored subtle highlight streak inside upper lash
    mid_lash = [
        (
            (upper_outer[i][0] + upper_inner[i][0]) * 0.5,
            (upper_outer[i][1] + upper_inner[i][1]) * 0.5,
        )
        for i in range(7, arch_steps - 5)
    ]
    if len(mid_lash) >= 2:
        draw.line(mid_lash, fill=(*iris_mid, 145), width=max(2, int(ry * 0.055)))

    # 7. Subtle Thin Eyelid Crease (short, delicate anime fold)
    crease_pts = []
    for i in range(6, arch_steps - 6):
        ox, oy = upper_outer[i]
        crease_pts.append((ox, oy - ry * 0.15))
    if len(crease_pts) >= 2:
        draw.line(crease_pts, fill=(172, 118, 108, 125), width=max(2, int(ry * 0.028)))

    # 8. Delicate Lower Lid Hint (short subtle stroke, not heavy circle)
    lower_pts = []
    y_bot_mod = 0.72 if style == "cool" else (0.76 if style == "cat" else 0.82)
    for i in range(8, 18):
        t = i / 24.0
        ang = math.pi * t
        ca = math.cos(ang)
        sa = abs(math.sin(ang))
        x = cx + ca * rx * 0.88
        y = cy + sa * ry * y_bot_mod
        lower_pts.append((x, y))
    if len(lower_pts) >= 2:
        draw.line(lower_pts, fill=(120, 82, 86, 130), width=max(2, int(ry * 0.032)))

    canvas.alpha_composite(layer)


def generate_anime_face(
    filename: str,
    skin_color: tuple,
    iris_top: tuple,
    iris_mid: tuple,
    iris_bot: tuple,
    pupil_col: tuple,
    brow_col: tuple,
    lash_col: tuple,
    eye_style: str,
    mouth_style: str,
):
    """Generate a 1024x1024 crisp UV face texture (rendered at 2048x2048 and downsampled)."""
    S = 2048
    # Build skin + pure soft rosy cheek blush directly in NumPy (ZERO dark alpha fringe!)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    base_rgb = np.zeros((S, S, 3), dtype=np.float32)
    base_rgb[:, :, 0] = skin_color[0]
    base_rgb[:, :, 1] = skin_color[1]
    base_rgb[:, :, 2] = skin_color[2]

    blush_y = S * 0.595
    blush_color = np.array([255.0, 148.0, 162.0], dtype=np.float32)
    for side in (-1, 1):
        bx = S * (0.5 + side * 0.255)
        dist2 = ((xx - bx) / (S * 0.115)) ** 2 + ((yy - blush_y) / (S * 0.056)) ** 2
        glow = np.exp(-dist2 * 1.45) * 0.42
        for c in range(3):
            base_rgb[:, :, c] = base_rgb[:, :, c] * (1.0 - glow) + blush_color[c] * glow

    img = Image.fromarray(np.clip(base_rgb, 0, 255).astype(np.uint8), mode="RGB").convert("RGBA")

    # Delicate diagonal anime blush ticks
    draw = ImageDraw.Draw(img)
    for side in (-1, 1):
        bx = S * (0.5 + side * 0.255)
        for k in (-1, 0, 1):
            tx = bx + k * (S * 0.019)
            ty = blush_y + S * 0.002
            draw.line(
                [(tx - 8, ty + 14), (tx + 8, ty - 14)],
                fill=(242, 128, 144, 150),
                width=5,
            )

    # Eyes (authentic Blue Archive chibi positioning)
    eye_y = S * 0.485
    eye_sep = S * 0.208
    eye_rx = S * 0.138
    eye_ry = S * 0.128 if eye_style == "cool" else S * 0.134

    for side in (-1, 1):
        draw_anime_eye(
            img,
            cx=S * 0.5 + side * eye_sep,
            cy=eye_y,
            side=side,
            rx=eye_rx,
            ry=eye_ry,
            iris_top=iris_top,
            iris_mid=iris_mid,
            iris_bot=iris_bot,
            pupil_col=pupil_col,
            lash_col=lash_col,
            style=eye_style,
        )

    # Eyebrows (delicate, clean anime strokes)
    draw = ImageDraw.Draw(img)
    brow_y = S * 0.318
    for side in (-1, 1):
        pts = []
        for i in range(16):
            t = i / 15.0
            x = S * 0.5 + side * (eye_sep * 0.54 + t * eye_rx * 1.38)
            arch = -math.sin(t * math.pi) * (S * 0.014)
            if eye_style == "cool":
                slant = (0.5 - t) * (S * 0.015)
            elif eye_style == "cat":
                slant = (t - 0.3) * (S * 0.010)
            else:
                slant = -abs(t - 0.45) * (S * 0.010)
            pts.append((x, brow_y + arch + slant))
        draw.line(pts, fill=(*brow_col, 235), width=12, joint="curve")

    # Tiny anime nose dot
    nx = S * 0.5
    ny = S * 0.588
    draw.polygon(
        [(nx - 5, ny - 5), (nx + 4, ny + 5), (nx - 2, ny + 6)],
        fill=(198, 138, 126, 155),
    )

    # Anime Mouth
    my = S * 0.678
    mouth_line = (158, 82, 92, 235)
    if mouth_style == "gentle":
        pts = []
        for i in range(21):
            t = (i / 20.0) * 2.0 - 1.0
            x = S * 0.5 + t * (S * 0.056)
            y = my + (1.0 - t * t) * (S * 0.019)
            pts.append((x, y))
        draw.line(pts, fill=mouth_line, width=9, joint="curve")
    elif mouth_style == "cat":
        pts = []
        for i in range(33):
            t = (i / 32.0) * 2.0 - 1.0
            x = S * 0.5 + t * (S * 0.066)
            y = my + (math.sin(abs(t) * math.pi) * (S * 0.020)) - (1.0 - abs(t)) * (S * 0.007)
            pts.append((x, y))
        draw.line(pts, fill=mouth_line, width=9, joint="curve")
    else:
        mw = S * 0.062
        mh = S * 0.044
        mouth_poly = []
        for i in range(17):
            t = (i / 16.0) * 2.0 - 1.0
            mouth_poly.append((S * 0.5 + t * mw, my - S * 0.005 + (t * t) * (S * 0.007)))
        for i in range(17):
            t = 1.0 - (i / 16.0) * 2.0
            mouth_poly.append((S * 0.5 + t * mw, my + (1.0 - t * t) * mh))
        draw.polygon(mouth_poly, fill=(228, 118, 130, 255))
        draw.ellipse(
            [S * 0.5 - mw * 0.56, my + mh * 0.35, S * 0.5 + mw * 0.56, my + mh * 1.0],
            fill=(250, 158, 168, 255),
        )
        draw.rectangle(
            [S * 0.5 - mw * 0.70, my - S * 0.004, S * 0.5 + mw * 0.70, my + mh * 0.22],
            fill=(255, 252, 252, 255),
        )
        draw.line(mouth_poly + [mouth_poly[0]], fill=mouth_line, width=8, joint="curve")

    out = img.resize((1024, 1024), Image.Resampling.LANCZOS)
    out_path = os.path.join(FACE_DIR, filename)
    out.convert("RGB").save(out_path, "PNG")
    print(f"[Texture] Saved anime face: {out_path}")


def fbm_noise(size: int, seed: int, octaves=(4, 8, 16, 32, 64)):
    """Fast tileable fractal noise via multi-octave smooth upsampling."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), dtype=np.float32)
    weight_sum = 0.0
    w = 1.0
    for freq in octaves:
        grid = rng.random((freq, freq)).astype(np.float32)
        im = Image.fromarray((grid * 255).astype(np.uint8), mode="L").resize(
            (size, size), Image.Resampling.BICUBIC
        )
        acc += (np.asarray(im, dtype=np.float32) / 255.0) * w
        weight_sum += w
        w *= 0.55
    return acc / weight_sum


def generate_env_textures():
    """Generate crisp GFL2 urban ruins & Kabaneri armored train textures (1024x1024)."""
    S = 1024

    # 1. Ruined Brutalist Concrete (Girls' Frontline 2 aesthetic)
    n1 = fbm_noise(S, seed=101, octaves=(4, 10, 24, 64, 128))
    n2 = fbm_noise(S, seed=102, octaves=(2, 6, 16))
    # Vertical rain streaks
    streak_seed = np.random.default_rng(103).random((1, 128)).astype(np.float32)
    streaks = np.asarray(
        Image.fromarray((streak_seed * 255).astype(np.uint8)).resize((S, S), Image.Resampling.BICUBIC),
        dtype=np.float32,
    ) / 255.0
    v_grad = np.linspace(0.75, 1.15, S, dtype=np.float32)[:, None]

    base = 0.42 + (n1 - 0.5) * 0.24 + (n2 - 0.5) * 0.14 - streaks * 0.09 * v_grad
    r = np.clip(base * 138, 28, 220)
    g = np.clip(base * 144, 30, 224)
    b = np.clip(base * 156, 34, 236)  # Cool slate-grey concrete
    conc = np.stack([r, g, b], axis=-1).astype(np.uint8)
    im_conc = Image.fromarray(conc, mode="RGB")
    dc = ImageDraw.Draw(im_conc)
    # Brutalist formwork panel seams & tie holes
    for y in range(0, S, 256):
        dc.line([(0, y), (S, y)], fill=(48, 52, 60), width=4)
        dc.line([(0, y + 3), (S, y + 3)], fill=(122, 128, 138), width=2)
    for x in range(0, S, 256):
        dc.line([(x, 0), (x, S)], fill=(52, 56, 64), width=3)
    for y in range(64, S, 128):
        for x in range(64, S, 128):
            dc.ellipse([x - 5, y - 5, x + 5, y + 5], fill=(42, 46, 54))
    # Jagged cracks
    rng = random.Random(202)
    for _ in range(14):
        cx, cy = rng.randint(0, S), rng.randint(0, S)
        pts = [(cx, cy)]
        for _ in range(12):
            cx += rng.randint(-38, 38)
            cy += rng.randint(-38, 38)
            pts.append((cx, cy))
        dc.line(pts, fill=(36, 39, 46), width=rng.choice([2, 3]))
    im_conc.save(os.path.join(ENV_DIR, "ruined_concrete.png"))

    # 2. Cracked Urban Asphalt Road
    an = fbm_noise(S, seed=201, octaves=(6, 16, 48, 128, 256))
    dust = fbm_noise(S, seed=202, octaves=(3, 8, 20))
    ar = np.clip(48 + an * 42 + np.clip(dust - 0.55, 0, 1) * 95, 22, 165)
    ag = np.clip(50 + an * 40 + np.clip(dust - 0.55, 0, 1) * 82, 24, 158)
    ab = np.clip(56 + an * 44 + np.clip(dust - 0.55, 0, 1) * 65, 28, 154)
    im_asp = Image.fromarray(np.stack([ar, ag, ab], axis=-1).astype(np.uint8), mode="RGB")
    da = ImageDraw.Draw(im_asp)
    for _ in range(20):
        cx, cy = rng.randint(0, S), rng.randint(0, S)
        pts = [(cx, cy)]
        for _ in range(15):
            cx += rng.randint(-45, 45)
            cy += rng.randint(-45, 45)
            pts.append((cx, cy))
        da.line(pts, fill=(24, 25, 30), width=rng.choice([2, 3]))
    im_asp.save(os.path.join(ENV_DIR, "asphalt_cracked.png"))

    # 3. Kabaneri Heavy Riveted Armored Steel Plating
    sn = fbm_noise(S, seed=301, octaves=(4, 12, 32, 96))
    rust = fbm_noise(S, seed=302, octaves=(3, 10, 28))
    rust_m = np.clip((rust - 0.58) * 3.2, 0.0, 1.0)
    sr = np.clip((52 + sn * 34) * (1 - rust_m) + 128 * rust_m, 20, 190)
    sg = np.clip((56 + sn * 36) * (1 - rust_m) + 64 * rust_m, 22, 180)
    sb = np.clip((64 + sn * 40) * (1 - rust_m) + 42 * rust_m, 26, 185)
    im_steel = Image.fromarray(np.stack([sr, sg, sb], axis=-1).astype(np.uint8), mode="RGB")
    ds = ImageDraw.Draw(im_steel)
    # Armored welded plate seams + heavy Kabaneri rivets
    for y in range(0, S, 256):
        ds.line([(0, y), (S, y)], fill=(20, 22, 26), width=8)
        ds.line([(0, y + 6), (S, y + 6)], fill=(115, 122, 134), width=3)
        for rx in range(28, S, 48):
            for ry in (y + 22, (y + 256 - 22) % S):
                ds.ellipse([rx - 7, ry - 7, rx + 7, ry + 7], fill=(24, 26, 30))
                ds.ellipse([rx - 5, ry - 5, rx + 5, ry + 5], fill=(122, 110, 92))
                ds.ellipse([rx - 3, ry - 4, rx + 1, ry], fill=(180, 165, 135))
    for x in range(0, S, 512):
        ds.line([(x, 0), (x, S)], fill=(20, 22, 26), width=8)
        ds.line([(x + 6, 0), (x + 6, S)], fill=(108, 114, 125), width=3)
    # Battle scratches
    for _ in range(35):
        sx, sy = rng.randint(0, S), rng.randint(0, S)
        ds.line(
            [(sx, sy), (sx + rng.randint(-55, 55), sy + rng.randint(-18, 18))],
            fill=(152, 158, 168),
            width=2,
        )
    im_steel.save(os.path.join(ENV_DIR, "train_armor_steel.png"))

    # 4. Kabaneri Furnace Core Glow Texture
    fn = fbm_noise(S, seed=401, octaves=(4, 12, 32))
    fr = np.clip(220 + fn * 35, 180, 255)
    fg = np.clip(75 + fn * 145, 45, 235)
    fb = np.clip(18 + (fn ** 2) * 85, 8, 120)
    im_furn = Image.fromarray(np.stack([fr, fg, fb], axis=-1).astype(np.uint8), mode="RGB")
    df = ImageDraw.Draw(im_furn)
    for y in range(0, S, 128):
        df.rectangle([0, y, S, y + 26], fill=(28, 22, 22))
    for x in range(0, S, 256):
        df.rectangle([x, 0, x + 22, S], fill=(28, 22, 22))
    im_furn.save(os.path.join(ENV_DIR, "train_furnace_glow.png"))

    print(f"[Texture] Saved environment & train textures to {ENV_DIR}")


def main():
    # 1. 白羽 玲奈 (Reina) — Silver Ponytail AR Leader, Ice-Blue Eyes
    generate_anime_face(
        filename="face_reina.png",
        skin_color=(253, 228, 212),
        iris_top=(32, 74, 152),
        iris_mid=(76, 168, 242),
        iris_bot=(166, 234, 255),
        pupil_col=(20, 38, 86),
        brow_col=(142, 154, 174),
        lash_col=(34, 38, 56),
        eye_style="cool",
        mouth_style="gentle",
    )
    # 2. 蒼井 千紗 (Chisa) — Dark-Navy Bob SMG Engineer, Amber-Gold Eyes
    generate_anime_face(
        filename="face_chisa.png",
        skin_color=(252, 226, 210),
        iris_top=(148, 76, 16),
        iris_mid=(232, 158, 42),
        iris_bot=(255, 228, 118),
        pupil_col=(72, 34, 12),
        brow_col=(48, 58, 92),
        lash_col=(36, 30, 44),
        eye_style="cat",
        mouth_style="cat",
    )
    # 3. 星野 莉莉 (Lily) — Golden Twin-Tails Shotgun Vanguard, Crimson-Red Eyes
    generate_anime_face(
        filename="face_lily.png",
        skin_color=(253, 230, 215),
        iris_top=(142, 24, 46),
        iris_mid=(232, 62, 86),
        iris_bot=(255, 162, 158),
        pupil_col=(68, 14, 28),
        brow_col=(172, 128, 54),
        lash_col=(46, 26, 36),
        eye_style="round",
        mouth_style="grin",
    )
    generate_env_textures()


if __name__ == "__main__":
    main()
