#!/usr/bin/env python3
"""
High-Detail Koutetsujou (甲鐵城 / Hayajiro) Armored Fortress Train Pipeline
Pure Python 3 + NumPy -> Generates:
  - assets/textures/env/train_armor_steel.png   (1024x1024 clean anime riveted silver-blue steel plates)
  - assets/textures/env/train_armor_dark.png    (1024x1024 shaded battleship blue-steel plates)
  - assets/models/train/kabaneri_armored_train.glb (glTF 2.0 Y-up, ready for Godot 4)

Coordinate convention (Godot 4 / glTF 2.0 Y-up):
  +X : Forward (Train prow / ram-plow pointing east)
  +Y : Up
  +Z : South (Facing player squad plaza)
  Rails at Z = +/-1.56, Y = 0.0
"""

import json
import math
import os
import struct
import zlib
from typing import List, Tuple, Dict, Optional

import numpy as np

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT_DIR, "assets", "models", "train")
ENV_DIR = os.path.join(ROOT_DIR, "assets", "textures", "env")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(ENV_DIR, exist_ok=True)


# ============================================================================
# 1. PURE PYTHON + NUMPY PNG WRITER & CLEAN ANIME KOUTETSUJOU STEEL TEXTURES
# ============================================================================

def write_png_rgb(path: str, arr_u8: np.ndarray) -> bytes:
    """Encode an (H, W, 3) uint8 numpy array to a valid RGB PNG and save it."""
    h, w, c = arr_u8.shape
    assert c == 3 and arr_u8.dtype == np.uint8

    raw = np.concatenate(
        [np.zeros((h, 1), dtype=np.uint8), arr_u8.reshape(h, w * 3)], axis=1
    ).tobytes()
    compressed = zlib.compress(raw, level=6)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", compressed)
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png_bytes)
    return png_bytes


def _bilinear_upsample(grid: np.ndarray, size: int) -> np.ndarray:
    gh, gw = grid.shape
    y = np.linspace(0, gh, size, endpoint=False, dtype=np.float32)
    x = np.linspace(0, gw, size, endpoint=False, dtype=np.float32)
    y0 = np.floor(y).astype(np.int32) % gh
    x0 = np.floor(x).astype(np.int32) % gw
    y1 = (y0 + 1) % gh
    x1 = (x0 + 1) % gw
    fy = (y - np.floor(y))[:, None]
    fx = (x - np.floor(x))[None, :]
    v00 = grid[np.ix_(y0, x0)]
    v10 = grid[np.ix_(y0, x1)]
    v01 = grid[np.ix_(y1, x0)]
    v11 = grid[np.ix_(y1, x1)]
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


def _fbm_tileable(size: int, seed: int, freqs=(4, 8, 16, 32, 64)) -> np.ndarray:
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), dtype=np.float32)
    w_sum = 0.0
    w = 1.0
    for f in freqs:
        g = rng.random((f, f), dtype=np.float32)
        acc += _bilinear_upsample(g, size) * w
        w_sum += w
        w *= 0.55
    return acc / w_sum


def generate_koutetsujou_steel_texture(
    path: str,
    size: int = 1024,
    base_rgb: Tuple[float, float, float] = (204.0, 214.0, 225.0),
    shadow_rgb: Tuple[float, float, float] = (146.0, 162.0, 180.0),
    seed: int = 404,
) -> bytes:
    """
    Generate clean anime-illustrated Koutetsujou riveted silver-blue steel plating.
    Smooth painterly steel gradients, crisp dark ink panel seams, bright top bevels,
    dense rivet rows, and delicate fine ink weathering specks (no blotchy spots).
    """
    rng = np.random.default_rng(seed)
    S = size

    n_macro = _fbm_tileable(S, seed + 1, freqs=(2, 5, 10, 20))
    n_micro = _fbm_tileable(S, seed + 2, freqs=(24, 48, 96))
    # Subtle soft vertical brushed steel & rain shading
    streak_1d = rng.random((1, 128), dtype=np.float32)
    streaks = _bilinear_upsample(np.repeat(streak_1d, 4, axis=0), S)
    streaks = np.clip((streaks - 0.50) * 1.4, 0.0, 1.0)

    # Panel grid (4 horizontal strakes x 2 staggered battleship plates per row)
    row_h = S // 4
    col_w = S // 2
    yy, xx = np.mgrid[0:S, 0:S]
    row_id = yy // row_h
    x_shift = (row_id % 2) * (col_w // 2)
    col_id = ((xx + x_shift) % S) // col_w
    local_y = yy % row_h
    local_x = (xx + x_shift) % col_w

    plate_tones = rng.uniform(-8.0, 8.0, size=(4, 2)).astype(np.float32)
    plate_delta = plate_tones[row_id, col_id]
    plate_grad = (1.0 - (local_y.astype(np.float32) / float(row_h))) * 16.0 - 8.0

    # Soft edge AO inside each plate
    edge_dist = np.minimum(
        np.minimum(local_y, row_h - 1 - local_y),
        np.minimum(local_x, col_w - 1 - local_x),
    ).astype(np.float32)
    edge_ao = 1.0 - 0.11 * np.exp(-edge_dist / (S * 0.022))

    t = np.clip(0.42 + (n_macro - 0.5) * 0.44 + (n_micro - 0.5) * 0.14, 0.0, 1.0)
    img = np.zeros((S, S, 3), dtype=np.float32)
    for ch in range(3):
        c_val = shadow_rgb[ch] * (1.0 - t) + base_rgb[ch] * t
        c_val += plate_delta + plate_grad
        c_val -= streaks * (11.0 if ch < 2 else 8.0)
        img[:, :, ch] = c_val * edge_ao

    # Delicate hand-inked fine specks & micro-scuffing near seams (authentic anime cel detail)
    edge_near = np.clip(1.0 - edge_dist / (S * 0.055), 0.0, 1.0)
    fine_dust = _fbm_tileable(S, seed + 9, freqs=(32, 64, 128))
    speck_mask = (fine_dust > (0.78 - 0.11 * edge_near)) & (rng.random((S, S)) > 0.72)
    img[speck_mask] *= np.array([0.62, 0.65, 0.70], dtype=np.float32)

    # Subtle fine ink scratches
    for _ in range(42):
        sx = int(rng.integers(0, S))
        sy = int(rng.integers(0, S))
        length = int(rng.integers(10, 42))
        dx = int(rng.choice([-1, 1]))
        dy_slope = float(rng.uniform(-0.22, 0.22))
        bright = bool(rng.random() > 0.42)
        for step in range(length):
            px = (sx + dx * step) % S
            py = int(sy + dy_slope * step) % S
            if bright:
                img[py, px] = np.minimum(img[py, px] + 22.0, 245.0)
            else:
                img[py, px] *= 0.72

    # Crisp dark anime ink seams + bright upper/left metallic bevel highlight
    seam_w = max(3, S // 260)
    bevel_w = max(2, S // 384)
    h_seam = local_y < seam_w
    v_seam = local_x < seam_w
    h_bevel = (local_y >= seam_w) & (local_y < seam_w + bevel_w)
    v_bevel = (local_x >= seam_w) & (local_x < seam_w + bevel_w)

    img[h_bevel | v_bevel] = np.minimum(img[h_bevel | v_bevel] + 30.0, 246.0)
    ink_col = np.array([32.0, 38.0, 48.0], dtype=np.float32)
    img[h_seam | v_seam] = ink_col

    # Dense uniform anime rivet rows along every horizontal and vertical seam
    rivet_r = max(3.0, S / 275.0)
    rivet_pad = int(S * 0.016)
    rivet_step = max(24, S // 34)
    ry_off_list = [rivet_pad, row_h - rivet_pad]

    def draw_rivet(cx: int, cy: int):
        rad = int(math.ceil(rivet_r + 2))
        y0 = max(0, cy - rad)
        y1 = min(S, cy + rad + 1)
        x0 = max(0, cx - rad)
        x1 = min(S, cx + rad + 1)
        gy, gx = np.mgrid[y0:y1, x0:x1]
        d2 = (gx - cx) ** 2 + (gy - cy) ** 2
        m_ring = d2 <= (rivet_r + 0.85) ** 2
        m_cap = d2 <= (rivet_r * 0.64) ** 2
        m_hi = ((gx - (cx - rivet_r * 0.24)) ** 2 + (gy - (cy - rivet_r * 0.24)) ** 2) <= (rivet_r * 0.34) ** 2
        img[y0:y1, x0:x1][m_ring] = np.array([38.0, 45.0, 56.0], dtype=np.float32)
        img[y0:y1, x0:x1][m_cap] = np.array([178.0, 190.0, 204.0], dtype=np.float32)
        img[y0:y1, x0:x1][m_hi] = np.array([234.0, 241.0, 248.0], dtype=np.float32)
        if (cx + cy) % 4 == 0:
            drip_h = int(rivet_r * 2.8)
            dy1 = min(S, cy + rad + drip_h)
            if dy1 > cy + rad:
                fade = np.linspace(0.88, 1.0, dy1 - (cy + rad), dtype=np.float32)[:, None, None]
                img[cy + rad : dy1, max(0, cx - 1) : min(S, cx + 2)] *= fade

    for r in range(4):
        y_base = r * row_h
        shift = (r % 2) * (col_w // 2)
        for x in range(rivet_step // 2, S, rivet_step):
            lx = (x + shift) % col_w
            if lx < rivet_pad or lx > col_w - rivet_pad:
                continue
            for roff in ry_off_list:
                draw_rivet(x, (y_base + roff) % S)
        for c in range(2):
            seam_x = (c * col_w - shift) % S
            for y_rel in range(rivet_pad + rivet_step // 2, row_h - rivet_pad, rivet_step):
                draw_rivet((seam_x + rivet_pad) % S, (y_base + y_rel) % S)
                draw_rivet((seam_x - rivet_pad) % S, (y_base + y_rel) % S)

    arr_u8 = np.clip(img, 0, 255).astype(np.uint8)
    return write_png_rgb(path, arr_u8)


# ============================================================================
# 2. PURE PYTHON + NUMPY 3D MESH & GLB 2.0 BUILDER (WITH AUTO-OUTWARD WINDING!)
# ============================================================================

def _normalize(v: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return np.where(n > 1e-8, v / np.maximum(n, 1e-8), np.array([0.0, 1.0, 0.0], dtype=np.float32))


def _rot_matrix_deg(rx: float, ry: float, rz: float) -> np.ndarray:
    ax, ay, az = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx = math.cos(ax), math.sin(ax)
    cy, sy = math.cos(ay), math.sin(ay)
    cz, sz = math.cos(az), math.sin(az)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], dtype=np.float32)
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], dtype=np.float32)
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]], dtype=np.float32)
    return Rz @ Ry @ Rx


def _triplanar_uvs(verts: np.ndarray, norms: np.ndarray, uv_scale: float) -> np.ndarray:
    an = np.abs(norms)
    uv = np.zeros((len(verts), 2), dtype=np.float32)
    m_y = (an[:, 1] >= an[:, 0]) & (an[:, 1] >= an[:, 2])
    m_x = (~m_y) & (an[:, 0] >= an[:, 2])
    m_z = (~m_y) & (~m_x)

    uv[m_y, 0] = verts[m_y, 0] * uv_scale
    uv[m_y, 1] = verts[m_y, 2] * uv_scale
    uv[m_x, 0] = verts[m_x, 2] * uv_scale
    uv[m_x, 1] = verts[m_x, 1] * uv_scale
    uv[m_z, 0] = verts[m_z, 0] * uv_scale
    uv[m_z, 1] = verts[m_z, 1] * uv_scale
    return uv


def _ensure_outward_winding(verts: np.ndarray, tris: np.ndarray) -> np.ndarray:
    """
    Guarantee outward-facing CCW winding for any closed/convex-ish solid mesh
    using signed tetrahedral volume (sum of v0 . (v1 x v2) > 0).
    """
    center = verts.mean(axis=0)
    v0 = verts[tris[:, 0]] - center
    v1 = verts[tris[:, 1]] - center
    v2 = verts[tris[:, 2]] - center
    signed_vol6 = float(np.sum(np.einsum("ij,ij->i", v0, np.cross(v1, v2))))
    if signed_vol6 < 0.0:
        return tris[:, [0, 2, 1]]
    return tris


class MeshBucket:
    def __init__(self, material_name: str):
        self.material_name = material_name
        self.positions: List[np.ndarray] = []
        self.normals: List[np.ndarray] = []
        self.uvs: List[np.ndarray] = []
        self.indices: List[np.ndarray] = []
        self._vert_count = 0

    def add_mesh(
        self,
        verts: np.ndarray,
        tris: np.ndarray,
        smooth: bool = False,
        uv_scale: float = 0.24,
        auto_outward: bool = True,
        flip_winding: bool = False,
    ):
        verts = np.asarray(verts, dtype=np.float32)
        tris = np.asarray(tris, dtype=np.uint32)
        if auto_outward:
            tris = _ensure_outward_winding(verts, tris)
        if flip_winding:
            tris = tris[:, [0, 2, 1]]

        if smooth:
            v0 = verts[tris[:, 0]]
            v1 = verts[tris[:, 1]]
            v2 = verts[tris[:, 2]]
            fn = np.cross(v1 - v0, v2 - v0)
            v_norms = np.zeros_like(verts)
            np.add.at(v_norms, tris[:, 0], fn)
            np.add.at(v_norms, tris[:, 1], fn)
            np.add.at(v_norms, tris[:, 2], fn)
            v_norms = _normalize(v_norms)
            uvs = _triplanar_uvs(verts, v_norms, uv_scale)
            idx = tris.reshape(-1) + self._vert_count
            self.positions.append(verts)
            self.normals.append(v_norms)
            self.uvs.append(uvs.astype(np.float32))
            self.indices.append(idx.astype(np.uint32))
            self._vert_count += len(verts)
        else:
            tri_verts = verts[tris.reshape(-1)]
            v0 = tri_verts[0::3]
            v1 = tri_verts[1::3]
            v2 = tri_verts[2::3]
            fn = _normalize(np.cross(v1 - v0, v2 - v0))
            tri_norms = np.repeat(fn, 3, axis=0)
            tri_uvs = _triplanar_uvs(tri_verts, tri_norms, uv_scale)
            idx = np.arange(len(tri_verts), dtype=np.uint32) + self._vert_count
            self.positions.append(tri_verts)
            self.normals.append(tri_norms)
            self.uvs.append(tri_uvs.astype(np.float32))
            self.indices.append(idx)
            self._vert_count += len(tri_verts)

    def finalize(self):
        if not self.positions:
            return None
        return (
            np.concatenate(self.positions, axis=0),
            np.concatenate(self.normals, axis=0),
            np.concatenate(self.uvs, axis=0),
            np.concatenate(self.indices, axis=0),
        )


class TrainBuilder:
    def __init__(self):
        self.buckets: Dict[str, MeshBucket] = {}

    def _bucket(self, mat: str) -> MeshBucket:
        if mat not in self.buckets:
            self.buckets[mat] = MeshBucket(mat)
        return self.buckets[mat]

    def add_thick_plate(
        self,
        quad_pts: List[Tuple[float, float, float]],
        thickness: float,
        mat: str,
        uv_scale: float = 0.28,
    ):
        """Extrude an arbitrary 3D planar quad/polygon along its normal into a solid flush armor plate."""
        pts = np.array(quad_pts, dtype=np.float32)
        n = len(pts)
        # Compute normal from first 3 non-collinear points
        normal = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        nl = float(np.linalg.norm(normal))
        if nl < 1e-6:
            return
        normal /= nl
        back_pts = pts - normal * thickness
        front_pts = pts
        verts = np.vstack([front_pts, back_pts])
        tris = []
        for i in range(1, n - 1):
            tris.append([0, i, i + 1])
            tris.append([n, n + i + 1, n + i])
        for i in range(n):
            j = (i + 1) % n
            tris.append([i, n + i, n + j])
            tris.append([i, n + j, j])
        self._bucket(mat).add_mesh(verts, np.array(tris, dtype=np.uint32), smooth=False, uv_scale=uv_scale, auto_outward=True)

    def add_box(
        self,
        center: Tuple[float, float, float],
        size: Tuple[float, float, float],
        mat: str,
        rot_deg: Tuple[float, float, float] = (0.0, 0.0, 0.0),
        uv_scale: float = 0.24,
    ):
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        verts = np.array(
            [
                [-hx, -hy, -hz],
                [hx, -hy, -hz],
                [hx, hy, -hz],
                [-hx, hy, -hz],
                [-hx, -hy, hz],
                [hx, -hy, hz],
                [hx, hy, hz],
                [-hx, hy, hz],
            ],
            dtype=np.float32,
        )
        tris = np.array(
            [
                [4, 5, 6], [4, 6, 7],
                [1, 0, 3], [1, 3, 2],
                [5, 1, 2], [5, 2, 6],
                [0, 4, 7], [0, 7, 3],
                [7, 6, 2], [7, 2, 3],
                [0, 1, 5], [0, 5, 4],
            ],
            dtype=np.uint32,
        )
        if any(abs(a) > 1e-4 for a in rot_deg):
            R = _rot_matrix_deg(*rot_deg)
            verts = verts @ R.T
        verts += np.array(center, dtype=np.float32)
        self._bucket(mat).add_mesh(verts, tris, smooth=False, uv_scale=uv_scale, auto_outward=True)

    def add_extruded_xy(
        self,
        poly_xy: List[Tuple[float, float]],
        z0: float,
        z1: float,
        mat: str,
        uv_scale: float = 0.24,
    ):
        if z0 > z1:
            z0, z1 = z1, z0
        n = len(poly_xy)
        area = sum(poly_xy[i][0] * poly_xy[(i + 1) % n][1] - poly_xy[(i + 1) % n][0] * poly_xy[i][1] for i in range(n))
        if area < 0:
            poly_xy = list(reversed(poly_xy))

        verts = [[x, y, z1] for x, y in poly_xy] + [[x, y, z0] for x, y in poly_xy]
        tris = []
        for i in range(1, n - 1):
            tris.append([0, i, i + 1])
            tris.append([n, n + i + 1, n + i])
        for i in range(n):
            j = (i + 1) % n
            tris.append([i, n + i, n + j])
            tris.append([i, n + j, j])
        self._bucket(mat).add_mesh(np.array(verts, dtype=np.float32), np.array(tris, dtype=np.uint32), smooth=False, uv_scale=uv_scale, auto_outward=True)

    def add_loft(
        self,
        rings: List[List[Tuple[float, float, float]]],
        mat: str,
        closed_ring: bool = True,
        cap_start: bool = True,
        cap_end: bool = True,
        smooth: bool = False,
        uv_scale: float = 0.24,
        auto_outward: bool = True,
        flip_winding: bool = False,
    ):
        n_rings = len(rings)
        n_pts = len(rings[0])
        verts = np.array([p for ring in rings for p in ring], dtype=np.float32)
        tris = []
        seg_count = n_pts if closed_ring else n_pts - 1
        for r in range(n_rings - 1):
            b0 = r * n_pts
            b1 = (r + 1) * n_pts
            for i in range(seg_count):
                j = (i + 1) % n_pts
                tris.append([b0 + i, b1 + i, b1 + j])
                tris.append([b0 + i, b1 + j, b0 + j])

        if closed_ring and cap_start and n_pts >= 3:
            c_idx = len(verts)
            c_pt = np.mean(verts[0:n_pts], axis=0)
            verts = np.vstack([verts, c_pt[None, :]])
            for i in range(n_pts):
                j = (i + 1) % n_pts
                tris.append([c_idx, i, j])

        if closed_ring and cap_end and n_pts >= 3:
            c_idx = len(verts)
            last = (n_rings - 1) * n_pts
            c_pt = np.mean(verts[last : last + n_pts], axis=0)
            verts = np.vstack([verts, c_pt[None, :]])
            for i in range(n_pts):
                j = (i + 1) % n_pts
                tris.append([c_idx, last + j, last + i])

        self._bucket(mat).add_mesh(
            verts,
            np.array(tris, dtype=np.uint32),
            smooth=smooth,
            uv_scale=uv_scale,
            auto_outward=auto_outward,
            flip_winding=flip_winding,
        )

    def add_cylinder(
        self,
        p0: Tuple[float, float, float],
        p1: Tuple[float, float, float],
        r0: float,
        r1: float,
        mat: str,
        segs: int = 24,
        cap0: bool = True,
        cap1: bool = True,
        smooth: bool = True,
        uv_scale: float = 0.24,
    ):
        a = np.array(p0, dtype=np.float32)
        b = np.array(p1, dtype=np.float32)
        axis = b - a
        length = float(np.linalg.norm(axis))
        if length < 1e-6:
            return
        w = axis / length
        ref = np.array([0.0, 1.0, 0.0], dtype=np.float32) if abs(w[1]) < 0.9 else np.array([1.0, 0.0, 0.0], dtype=np.float32)
        u = np.cross(ref, w)
        u /= np.linalg.norm(u)
        v = np.cross(w, u)

        angles = np.linspace(0.0, 2.0 * math.pi, segs, endpoint=False)
        ca, sa = np.cos(angles), np.sin(angles)
        ring0 = [tuple(a + r0 * (ca[i] * u + sa[i] * v)) for i in range(segs)]
        ring1 = [tuple(b + r1 * (ca[i] * u + sa[i] * v)) for i in range(segs)]
        self.add_loft(
            [ring0, ring1],
            mat=mat,
            closed_ring=True,
            cap_start=cap0,
            cap_end=cap1,
            smooth=smooth,
            uv_scale=uv_scale,
            auto_outward=True,
        )

    def add_hollow_tube(
        self,
        p0: Tuple[float, float, float],
        p1: Tuple[float, float, float],
        ro0: float,
        ri0: float,
        ro1: float,
        ri1: float,
        mat: str,
        segs: int = 30,
        smooth: bool = True,
        uv_scale: float = 0.24,
    ):
        """Watertight thick-walled hollow tube (outer wall + inner wall + both end rims)."""
        a = np.array(p0, dtype=np.float32)
        b = np.array(p1, dtype=np.float32)
        axis = b - a
        length = float(np.linalg.norm(axis))
        if length < 1e-6:
            return
        w = axis / length
        ref = np.array([0.0, 1.0, 0.0], dtype=np.float32) if abs(w[1]) < 0.9 else np.array([1.0, 0.0, 0.0], dtype=np.float32)
        u = np.cross(ref, w)
        u /= np.linalg.norm(u)
        v = np.cross(w, u)

        angles = np.linspace(0.0, 2.0 * math.pi, segs, endpoint=False)
        ca, sa = np.cos(angles), np.sin(angles)

        def make_ring(origin, rad):
            return [tuple(origin + rad * (ca[i] * u + sa[i] * v)) for i in range(segs)]

        r_out0 = make_ring(a, ro0)
        r_out1 = make_ring(b, ro1)
        r_in1 = make_ring(b, ri1)
        r_in0 = make_ring(a, ri0)
        # Outer wall outward -> flip_winding=True
        self.add_loft([r_out0, r_out1], mat, True, False, False, smooth=smooth, uv_scale=uv_scale, auto_outward=False, flip_winding=True)
        # End rim at p1 (+w normal) -> flip_winding=True
        self.add_loft([r_out1, r_in1], mat, True, False, False, smooth=False, uv_scale=uv_scale, auto_outward=False, flip_winding=True)
        # Inner wall pointing inward toward axis -> flip_winding=True
        self.add_loft([r_in1, r_in0], mat, True, False, False, smooth=smooth, uv_scale=uv_scale, auto_outward=False, flip_winding=True)
        # Start rim at p0 (-w normal) -> flip_winding=True
        self.add_loft([r_in0, r_out0], mat, True, False, False, smooth=False, uv_scale=uv_scale, auto_outward=False, flip_winding=True)

    def add_dome(
        self,
        center: Tuple[float, float, float],
        rx: float,
        ry: float,
        rz: float,
        mat: str,
        lat_segs: int = 10,
        lon_segs: int = 28,
        hemi: bool = True,
        smooth: bool = True,
        uv_scale: float = 0.24,
    ):
        cx, cy, cz = center
        theta_min = 0.0 if hemi else -math.pi * 0.5
        theta_max = math.pi * 0.5
        rings = []
        for i in range(lat_segs + 1):
            t = i / float(lat_segs)
            th = theta_min + (theta_max - theta_min) * t
            ct = max(math.cos(th), 0.002)
            st = math.sin(th)
            ring = []
            for j in range(lon_segs):
                phi = 2.0 * math.pi * j / float(lon_segs)
                ring.append((cx + rx * ct * math.cos(phi), cy + ry * st, cz + rz * ct * math.sin(phi)))
            rings.append(ring)
        self.add_loft(
            rings,
            mat=mat,
            closed_ring=True,
            cap_start=hemi,
            cap_end=False,
            smooth=smooth,
            uv_scale=uv_scale,
            auto_outward=True,
        )

    def add_torus(
        self,
        center: Tuple[float, float, float],
        axis: Tuple[float, float, float],
        major_r: float,
        minor_r: float,
        mat: str,
        maj_segs: int = 24,
        min_segs: int = 10,
        smooth: bool = True,
    ):
        c = np.array(center, dtype=np.float32)
        w = np.array(axis, dtype=np.float32)
        w /= np.linalg.norm(w)
        ref = np.array([0.0, 1.0, 0.0], dtype=np.float32) if abs(w[1]) < 0.9 else np.array([1.0, 0.0, 0.0], dtype=np.float32)
        u = np.cross(ref, w)
        u /= np.linalg.norm(u)
        v = np.cross(w, u)

        rings = []
        for i in range(maj_segs + 1):
            phi = 2.0 * math.pi * (i % maj_segs) / float(maj_segs)
            radial = math.cos(phi) * u + math.sin(phi) * v
            rc = c + major_r * radial
            ring = []
            for j in range(min_segs):
                th = 2.0 * math.pi * j / float(min_segs)
                pt = rc + minor_r * (math.cos(th) * radial + math.sin(th) * w)
                ring.append(tuple(pt))
            rings.append(ring)
        # Torus tube is closed; verify per-ring outward against rc
        self.add_loft(rings, mat=mat, closed_ring=True, cap_start=False, cap_end=False, smooth=smooth, auto_outward=True)

    def add_pipe_railing(
        self,
        pts: List[Tuple[float, float, float]],
        height: float,
        mat: str,
        rad: float = 0.036,
        mid_bar: bool = True,
    ):
        for i, p in enumerate(pts):
            top = (p[0], p[1] + height, p[2])
            self.add_cylinder(p, top, rad, rad, mat, segs=8, smooth=True)
            if i < len(pts) - 1:
                q = pts[i + 1]
                q_top = (q[0], q[1] + height, q[2])
                self.add_cylinder(top, q_top, rad, rad, mat, segs=8, smooth=True)
                if mid_bar:
                    p_mid = (p[0], p[1] + height * 0.52, p[2])
                    q_mid = (q[0], q[1] + height * 0.52, q[2])
                    self.add_cylinder(p_mid, q_mid, rad * 0.8, rad * 0.8, mat, segs=8, smooth=True)


# ============================================================================
# 3. KOUTETSUJOU (甲鐵城) ARMORED FORTRESS TRAIN ARCHITECTURE
# ============================================================================

def build_koutetsujou_train(tb: TrainBuilder):
    # ========================================================================
    # PART A: GIANT SWEEPING BATTLESHIP PROW & LOWER COWCATCHER (X = 11.2..20.5)
    # ========================================================================

    # --- A1. Lowest Ground-Hugging Wide V-Cowcatcher Apron (X = 15.0..20.5, Y = 0.08..1.85) ---
    plow_lower_base = [
        (20.48, 0.10, -0.34),
        (20.48, 0.10, 0.34),
        (17.95, 0.10, 2.28),
        (15.65, 0.10, 3.30),
        (15.10, 0.10, 2.55),
        (15.10, 0.10, -2.55),
        (15.65, 0.10, -3.30),
        (17.95, 0.10, -2.28),
    ]
    plow_lower_top = [
        (18.08, 1.56, -0.18),
        (18.08, 1.56, 0.18),
        (16.45, 1.66, 1.66),
        (14.90, 1.86, 2.48),
        (14.65, 1.86, 2.10),
        (14.65, 1.86, -2.10),
        (14.90, 1.86, -2.48),
        (16.45, 1.66, -1.66),
    ]
    tb.add_loft([plow_lower_base, plow_lower_top], "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.22)

    # Flush bolted access hatch plates on the exact lower cowcatcher slope (constructed directly on slope plane!)
    def lerp3(a, b, t):
        return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)

    def bilerp_quad(p00, p10, p11, p01, u0, u1, v0, v1, lift=0.06):
        def eval_uv(u, v):
            return lerp3(lerp3(p00, p10, u), lerp3(p01, p11, u), v)
        q = [eval_uv(u0, v0), eval_uv(u1, v0), eval_uv(u1, v1), eval_uv(u0, v1)]
        arr = np.array(q, dtype=np.float32)
        n = np.cross(arr[1] - arr[0], arr[2] - arr[0])
        nl = float(np.linalg.norm(n))
        if nl > 1e-6:
            n /= nl
            # Ensure lift moves outward (+Y or away from X=14,Z=0)
            if n[1] < 0:
                n = -n
            q = [tuple(pt + n * lift) for pt in arr]
        return q

    for side in (-1, 1):
        # Slope segment 1 (outer cheek near front)
        b_front = (20.48, 0.10, side * 0.34)
        b_mid = (17.95, 0.10, side * 2.28)
        t_front = (18.08, 1.56, side * 0.18)
        t_mid = (16.45, 1.66, side * 1.66)
        hatch1 = bilerp_quad(b_front, b_mid, t_mid, t_front, 0.16, 0.46, 0.04, 0.52, lift=0.05)
        tb.add_thick_plate(hatch1, 0.07, "SteelMid", uv_scale=0.35)

        # Slope segment 2 (wide rear cheek hatch right next to curved fender)
        b_rear = (15.65, 0.10, side * 3.30)
        t_rear = (14.90, 1.86, side * 2.48)
        hatch2 = bilerp_quad(b_mid, b_rear, t_rear, t_mid, 0.25, 0.80, 0.04, 0.62, lift=0.05)
        tb.add_thick_plate(hatch2, 0.07, "SteelMid", uv_scale=0.35)

    # --- A2. Stepped V-Collar Chin Ridge sweeping upward from X=18.0,Y=1.52 to X=11.65,Y=3.45 ---
    collar_bot = [
        (18.02, 1.50, -0.18),
        (18.02, 1.50, 0.18),
        (15.60, 1.82, 2.02),
        (12.20, 2.65, 2.54),
        (11.65, 2.85, 2.44),
        (11.65, 2.85, -2.44),
        (12.20, 2.65, -2.54),
        (15.60, 1.82, -2.02),
    ]
    collar_top = [
        (17.15, 2.15, -0.14),
        (17.15, 2.15, 0.14),
        (15.05, 2.45, 1.76),
        (11.95, 3.35, 2.44),
        (11.60, 3.45, 2.36),
        (11.60, 3.45, -2.36),
        (11.95, 3.35, -2.44),
        (15.05, 2.45, -1.76),
    ]
    tb.add_loft([collar_bot, collar_top], "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.22)

    # Flush V-deck central diamond hatch + twin compact steel tie-down cleats
    tb.add_box((17.08, 1.78, 0.0), (1.35, 0.12, 1.05), "SteelMid", rot_deg=(0, 0, -21), uv_scale=0.32)
    for side in (-1, 1):
        for cx, cy, cz in [(17.45, 1.86, side * 0.56), (16.45, 2.04, side * 1.10), (14.35, 2.52, side * 1.98)]:
            tb.add_box((cx, cy, cz), (0.28, 0.18, 0.20), "SteelTrim", rot_deg=(0, side * -28, -16))

    # --- A3. Curved Bulbous Lower Side Cheek Fenders (covering front bogie, X = 11.15..15.85) ---
    for side in (-1, 1):
        fender_rings = []
        f_specs = [
            (0.10, 11.15, 15.80, 3.24, 2.35),
            (0.65, 11.20, 15.60, 3.16, 2.30),
            (1.30, 11.30, 15.30, 2.95, 2.25),
            (1.92, 11.45, 14.90, 2.68, 2.20),
            (2.48, 11.65, 14.45, 2.44, 2.15),
        ]
        for yv, x_rear, x_front, z_out, z_in in f_specs:
            pts = []
            for t in (0.0, 0.25, 0.5, 0.75, 1.0):
                ang = t * math.pi
                px = x_rear + (x_front - x_rear) * t
                bulge = math.sin(ang) * 0.34
                pz = side * (z_out + bulge - 0.16 * (1.0 - math.sin(ang)))
                pts.append((px, yv, pz))
            pts.append((x_front - 0.3, yv, side * (z_in - 0.3)))
            pts.append((x_rear + 0.1, yv, side * (z_in - 0.3)))
            if side < 0:
                pts = list(reversed(pts))
            fender_rings.append(pts)
        tb.add_loft(fender_rings, "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=True, uv_scale=0.22)

    # --- A4. Iconic Swept-Forward Concave Battleship Bow (Y = 2.05..7.40, X = 11.6..19.5) ---
    bow_levels = [
        (2.10, 16.75, 14.70, 1.56, 11.75, 2.28),
        (3.15, 16.58, 14.85, 1.80, 11.75, 2.38),
        (4.10, 17.08, 15.10, 1.94, 11.75, 2.42),
        (5.15, 17.78, 15.40, 2.06, 11.75, 2.44),
        (6.25, 18.68, 15.70, 2.14, 11.75, 2.44),
        (7.30, 19.58, 16.00, 2.18, 11.85, 2.42),
    ]
    bow_rings = []
    for y, xt, xm, zm, xr, zr in bow_levels:
        ring = [
            (xt, y, 0.0),
            (xm, y, zm),
            (xr, y, zr),
            (xr, y, -zr),
            (xm, y, -zm),
        ]
        bow_rings.append(ring)
    # Guaranteed watertight outward winding!
    tb.add_loft(bow_rings, "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.21)

    # Horizontal armor strake rib seams hugging the bow cheeks cleanly
    for idx in (1, 2, 3, 4):
        y, xt, xm, zm, xr, zr = bow_levels[idx]
        for side in (-1, 1):
            p_tip = (xt + 0.03, y, side * 0.03)
            p_mid = (xm + 0.03, y, side * (zm + 0.03))
            p_rear = (xr + 0.02, y, side * (zr + 0.03))
            tb.add_cylinder(p_tip, p_mid, 0.038, 0.038, "SteelTrim", segs=6, smooth=False)
            tb.add_cylinder(p_mid, p_rear, 0.038, 0.038, "SteelTrim", segs=6, smooth=False)

    # Sharp vertical keel spine edge guard along the very nose edge
    for idx in range(len(bow_levels) - 1):
        y0, x0 = bow_levels[idx][0], bow_levels[idx][1]
        y1, x1 = bow_levels[idx + 1][0], bow_levels[idx + 1][1]
        tb.add_cylinder((x0 + 0.03, y0, 0.0), (x1 + 0.03, y1, 0.0), 0.065, 0.065, "SteelTrim", segs=8, smooth=False)

    # Lower vertical cooling/gun slits flush on the bow cheeks
    for side in (-1, 1):
        tb.add_box((15.45, 2.92, side * 1.66), (0.14, 0.54, 0.14), "DarkCavity", rot_deg=(0, side * -32, 0))
        tb.add_box((13.45, 3.65, side * 2.18), (0.14, 0.50, 0.14), "DarkCavity", rot_deg=(0, side * -18, 0))

    # --- A5. Overhanging Armored Upper Prow Deck Lip & Signature Bow Pipe Railing ---
    deck_bot = [
        (19.88, 7.26, 0.0),
        (16.15, 6.82, 2.34),
        (11.90, 6.32, 2.58),
        (11.90, 6.32, -2.58),
        (16.15, 6.82, -2.34),
    ]
    deck_top = [
        (19.98, 7.52, 0.0),
        (16.20, 7.06, 2.40),
        (11.90, 6.56, 2.62),
        (11.90, 6.56, -2.62),
        (16.20, 7.06, -2.40),
    ]
    tb.add_loft([deck_bot, deck_top], "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.25)

    bow_rail_pts = [
        (16.35, 7.08, -2.18),
        (17.95, 7.28, -1.16),
        (19.65, 7.50, -0.06),
        (19.65, 7.50, 0.06),
        (17.95, 7.28, 1.16),
        (16.35, 7.08, 2.18),
    ]
    tb.add_pipe_railing(bow_rail_pts, height=0.68, mat="SteelTrim", rad=0.038, mid_bar=True)

    # --- A6. Flush Dark Triangular Shadow Alcoves + Caged Brass Spherical Headlights (BOTH SIDES!) ---
    # Evaluate exact points on the rear-upper bow cheek face (xm, zm) -> (xr, zr) so the alcove hugs the hull!
    def bow_cheek_pt(x_val: float, y_val: float, side_sign: int, push_out: float = 0.0) -> Tuple[float, float, float]:
        # Interpolate bow_levels vertically for y_val
        for k in range(len(bow_levels) - 1):
            y0, _, xm0, zm0, xr0, zr0 = bow_levels[k]
            y1, _, xm1, zm1, xr1, zr1 = bow_levels[k + 1]
            if y0 <= y_val <= y1:
                ty = (y_val - y0) / max(1e-5, y1 - y0)
                xm = xm0 + (xm1 - xm0) * ty
                zm = zm0 + (zm1 - zm0) * ty
                xr = xr0 + (xr1 - xr0) * ty
                zr = zr0 + (zr1 - zr0) * ty
                tx = max(0.0, min(1.0, (x_val - xr) / max(1e-5, xm - xr)))
                z_surf = zr + (zm - zr) * tx
                return (x_val, y_val, side_sign * (z_surf + push_out))
        return (x_val, y_val, side_sign * (2.25 + push_out))

    for side in (-1, 1):
        # Flush dark triangular shadow recess plate right on the upper prow cheek under the brow deck!
        p_top_f = bow_cheek_pt(15.65, 6.48, side, push_out=0.04)
        p_top_r = bow_cheek_pt(13.05, 6.26, side, push_out=0.04)
        p_bot = bow_cheek_pt(14.55, 4.78, side, push_out=0.04)

        # Solid pitch-black triangular recess plate backing (slightly raised 0.04m on hull so zero z-fighting)
        tb.add_thick_plate([p_top_f, p_top_r, p_bot], 0.08, "DarkCavity")

        # Recessed hooded steel shadow brow framing the top & diagonal edges of the triangular alcove
        f_pts = [
            bow_cheek_pt(15.72, 6.52, side, push_out=0.14),
            bow_cheek_pt(13.00, 6.30, side, push_out=0.14),
            bow_cheek_pt(14.55, 4.72, side, push_out=0.14),
        ]
        for fi in range(3):
            tb.add_cylinder(f_pts[fi], f_pts[(fi + 1) % 3], 0.068, 0.068, "SteelTrim", segs=8, smooth=False)

        # Deep antique-gold SPHERICAL headlight orb nested cleanly inside the dark triangular alcove!
        orb_c = bow_cheek_pt(14.48, 5.76, side, push_out=0.08)
        orb_r = 0.48
        tb.add_dome(orb_c, orb_r, orb_r, orb_r, "BrassOrb", lat_segs=10, lon_segs=22, hemi=False, smooth=True)
        # Signature cruciform dark-steel protective cage bands wrapping the brass orb!
        tb.add_torus(orb_c, (0, 1, 0), orb_r + 0.025, 0.042, "SteelTrim", maj_segs=22, min_segs=8)
        tb.add_torus(orb_c, (1, 0, 0), orb_r + 0.025, 0.042, "SteelTrim", maj_segs=22, min_segs=8)
        tb.add_torus(orb_c, (0, 0, 1), orb_r + 0.025, 0.036, "SteelTrim", maj_segs=22, min_segs=8)

    # ========================================================================
    # PART B: CENTRAL CONNING DOME, CITADEL WALLS & SIDE CONICAL TURRETS (X = 8.4..13.0)
    # ========================================================================

    # --- B1. Tall Main Armored Citadel Hull (X = 8.45..12.1, Y = 1.85..6.85) ---
    tb.add_box((10.25, 4.35, 0.0), (3.65, 4.95, 4.86), "SteelLight", uv_scale=0.22)
    fin_poly = [
        (8.48, 6.75),
        (9.75, 6.75),
        (9.45, 7.62),
        (8.62, 7.62),
    ]
    tb.add_extruded_xy(fin_poly, -2.18, 2.18, "SteelLight", uv_scale=0.24)
    for side in (-1, 1):
        tb.add_pipe_railing(
            [(8.66, 7.62, side * 2.05), (9.42, 7.62, side * 2.05)],
            height=0.58,
            mat="SteelTrim",
            rad=0.032,
            mid_bar=True,
        )

    # --- B2. Iconic Central Riveted Conning Bridge Dome (X = 12.15, Y = 6.2..8.35) ---
    dome_cx = 12.15
    tb.add_cylinder((dome_cx, 6.15, 0.0), (dome_cx, 7.35, 0.0), 2.38, 2.28, "SteelLight", segs=32, smooth=True, uv_scale=0.22)
    tb.add_cylinder((dome_cx, 6.92, 0.0), (dome_cx, 7.10, 0.0), 2.43, 2.41, "SteelMid", segs=32, smooth=True, uv_scale=0.28)
    tb.add_cylinder((dome_cx, 7.30, 0.0), (dome_cx, 7.42, 0.0), 2.36, 2.32, "SteelTrim", segs=32, smooth=True)
    tb.add_dome((dome_cx, 7.32, 0.0), 2.26, 0.96, 2.26, "SteelLight", lat_segs=10, lon_segs=32, hemi=True, smooth=True, uv_scale=0.22)
    tb.add_cylinder((dome_cx, 8.12, 0.0), (dome_cx, 8.34, 0.0), 0.92, 0.84, "SteelMid", segs=22, smooth=True)
    tb.add_dome((dome_cx, 8.32, 0.0), 0.84, 0.24, 0.84, "SteelLight", lat_segs=6, lon_segs=22, hemi=True, smooth=True)
    for ang_deg in (-135, -90, -50, -18, 18, 50, 90, 135):
        ar = math.radians(ang_deg)
        sx = dome_cx + math.cos(ar) * 2.33
        sz = math.sin(ar) * 2.33
        tb.add_box((sx, 6.98, sz), (0.18, 0.48, 0.16), "DarkCavity", rot_deg=(0, -ang_deg, 0))
        tb.add_box((sx, 6.98, sz), (0.14, 0.56, 0.24), "SteelTrim", rot_deg=(0, -ang_deg, 0))

    # --- B3. Iconic Twin Side Conical Turret Sponsons + Heavy Cannons (BOTH SIDES!) ---
    for side in (-1, 1):
        sp_x = 10.75
        sp_z = side * 2.48
        tb.add_cylinder((sp_x, 4.55, sp_z), (sp_x, 6.26, sp_z), 0.24, 0.94, "SteelLight", segs=24, smooth=True, uv_scale=0.26)
        tb.add_dome((sp_x, 4.58, sp_z), 0.24, 0.22, 0.24, "SteelMid", lat_segs=5, lon_segs=16, hemi=False, smooth=True)
        tb.add_cylinder((sp_x, 6.18, sp_z), (sp_x, 6.32, sp_z), 0.99, 0.99, "SteelTrim", segs=24, smooth=True)
        tb.add_cylinder((sp_x, 6.32, sp_z), (sp_x, 6.46, sp_z), 0.95, 0.94, "CrimsonRim", segs=24, smooth=True)
        tb.add_dome((sp_x, 6.45, sp_z), 0.93, 0.50, 0.93, "SteelLight", lat_segs=8, lon_segs=24, hemi=True, smooth=True, uv_scale=0.25)

        barrel_dx = -2.25 if side > 0 else 2.25
        barrel_dz = side * 0.65
        p_b0 = (sp_x + (0.15 if barrel_dx > 0 else -0.15), 6.22, sp_z + side * 0.25)
        p_b1 = (p_b0[0] + barrel_dx, 6.24, p_b0[2] + barrel_dz)
        tb.add_cylinder(p_b0, p_b1, 0.145, 0.105, "SteelTrim", segs=14, smooth=True)
        p_m0 = (p_b0[0] + barrel_dx * 0.90, 6.24, p_b0[2] + barrel_dz * 0.90)
        tb.add_cylinder(p_m0, p_b1, 0.135, 0.135, "Gunmetal", segs=14, smooth=True)

        # 4 stacked heavy boxy armor hinges along the prow-to-citadel seam
        for hy in (3.72, 4.26, 4.80, 5.34):
            tb.add_box((11.98, hy, side * 2.50), (0.48, 0.34, 0.28), "SteelMid", uv_scale=0.35)

        # Recessed armored crew door + walkway + handrail + boarding ladder
        tb.add_box((10.95, 2.98, side * 2.46), (0.86, 1.56, 0.14), "SteelTrim")
        tb.add_box((10.95, 2.98, side * 2.50), (0.72, 1.42, 0.08), "SteelLight")
        for gy in (3.28, 3.44, 3.60):
            tb.add_box((10.95, gy, side * 2.55), (0.50, 0.06, 0.04), "DarkCavity")
        tb.add_cylinder((10.75, 2.86, side * 2.54), (10.75, 2.86, side * 2.66), 0.05, 0.05, "Gunmetal", segs=8)
        tb.add_box((10.45, 2.08, side * 2.82), (2.25, 0.12, 0.78), "SteelTrim")
        tb.add_pipe_railing(
            [
                (11.50, 2.14, side * 2.48),
                (11.50, 2.14, side * 3.16),
                (9.40, 2.14, side * 3.16),
                (9.40, 2.14, side * 2.48),
            ],
            height=0.82,
            mat="SteelTrim",
            rad=0.032,
            mid_bar=True,
        )
        lad_x = 10.18
        lad_z = side * 2.96
        for lx_off in (-0.22, 0.22):
            tb.add_cylinder((lad_x + lx_off, 0.18, lad_z), (lad_x + lx_off, 2.12, lad_z), 0.028, 0.028, "SteelTrim", segs=8)
        for rung_y in (0.42, 0.76, 1.10, 1.44, 1.78):
            tb.add_cylinder((lad_x - 0.22, rung_y, lad_z), (lad_x + 0.22, rung_y, lad_z), 0.022, 0.022, "SteelTrim", segs=6)

        for sy, sx in [(5.45, 9.55), (4.65, 9.35), (3.85, 9.60)]:
            tb.add_box((sx, sy, side * 2.46), (0.58, 0.15, 0.10), "DarkCavity")

    # ========================================================================
    # PART C: RIBBED ARMORED BOILER + TWIN COLOSSAL RED-RIMMED SIDE TURBINES (X = -1.6..8.5)
    # ========================================================================
    tb.add_box((3.5, 1.35, 0.0), (10.4, 0.95, 3.10), "Gunmetal")

    # Central ribbed armored boiler barrel
    tb.add_cylinder((-1.65, 3.88, 0.0), (8.55, 3.88, 0.0), 1.48, 1.48, "SteelLight", segs=28, smooth=True, uv_scale=0.22)
    for i in range(12):
        rx = -1.2 + i * 0.84
        tb.add_cylinder((rx - 0.11, 3.88, 0.0), (rx + 0.11, 3.88, 0.0), 1.60, 1.60, "SteelMid", segs=28, smooth=True, uv_scale=0.30)
        tb.add_cylinder((rx - 0.03, 3.88, 0.0), (rx + 0.03, 3.88, 0.0), 1.64, 1.64, "SteelTrim", segs=28, smooth=False)

    for side in (-1, 1):
        tb.add_cylinder((-1.5, 5.18, side * 0.62), (8.45, 5.18, side * 0.62), 0.16, 0.16, "SteelMid", segs=12, smooth=True)
        tb.add_pipe_railing(
            [(-1.2, 5.26, side * 0.92), (3.5, 5.26, side * 0.92), (8.1, 5.26, side * 0.92)],
            height=0.54,
            mat="SteelTrim",
            rad=0.028,
            mid_bar=True,
        )
    # Low-profile armored steam exhaust dome behind main citadel
    tb.add_cylinder((7.65, 5.20, 0.0), (7.65, 6.08, 0.0), 0.72, 0.62, "SteelMid", segs=20, smooth=True)
    tb.add_hollow_tube((7.65, 6.02, 0.0), (7.65, 6.24, 0.0), 0.70, 0.48, 0.72, 0.48, "SteelTrim", segs=20, smooth=True)
    tb.add_cylinder((7.65, 5.85, 0.0), (7.65, 6.05, 0.0), 0.48, 0.48, "DarkCavity", segs=18, smooth=True)

    # Twin Colossal Side Intake Turbines with Signature Crimson Collars!
    for side in (-1, 1):
        ty = 2.38
        tz = side * 2.12

        tb.add_cylinder((3.80, ty, tz), (7.85, ty, tz), 1.24, 1.24, "SteelLight", segs=28, smooth=True, uv_scale=0.22)
        tb.add_cylinder((-1.45, ty - 0.06, tz * 0.96), (3.85, ty - 0.06, tz * 0.96), 1.04, 1.04, "SteelMid", segs=26, smooth=True, uv_scale=0.24)
        tb.add_cylinder((3.55, ty - 0.03, tz * 0.98), (4.15, ty, tz), 1.08, 1.26, "SteelTrim", segs=26, smooth=True)

        for bx, br in [(7.35, 1.30), (6.05, 1.30), (4.75, 1.30), (2.70, 1.11), (1.35, 1.11), (0.0, 1.11)]:
            by = ty if bx > 3.9 else ty - 0.06
            bz = tz if bx > 3.9 else tz * 0.96
            tb.add_cylinder((bx - 0.14, by, bz), (bx + 0.14, by, bz), br, br, "SteelTrim", segs=26, smooth=True)

        # Hollow front turbine intake cowling + iconic crimson red inner lip!
        tb.add_hollow_tube((7.75, ty, tz), (8.36, ty, tz), 1.28, 1.06, 1.32, 1.08, "SteelLight", segs=30, smooth=True)
        tb.add_hollow_tube((7.55, ty, tz), (8.44, ty, tz), 1.12, 0.92, 1.15, 0.96, "CrimsonRim", segs=30, smooth=True)
        tb.add_cylinder((6.95, ty, tz), (7.64, ty, tz), 0.96, 0.96, "DarkCavity", segs=24, smooth=True)
        for ly_off in (-0.64, -0.32, 0.0, 0.32, 0.64):
            chord = math.sqrt(max(0.05, 0.92 ** 2 - ly_off ** 2)) * 1.92
            tb.add_box((8.06, ty + ly_off, tz), (0.50, 0.11, chord), "Gunmetal")
        tb.add_cylinder((7.55, ty, tz), (8.32, ty, tz), 0.36, 0.15, "SteelTrim", segs=16, smooth=True)
        tb.add_dome((8.30, ty, tz), 0.15, 0.15, 0.15, "SteelMid", lat_segs=5, lon_segs=14, hemi=False, smooth=True)

        tb.add_cylinder((8.50, ty - 0.15, tz + side * 0.42), (8.50, ty + 0.35, tz + side * 0.42), 0.24, 0.24, "SteelMid", segs=14, smooth=True)
        tb.add_box((8.55, ty - 0.48, tz + side * 0.28), (0.34, 0.56, 0.34), "SteelTrim")

        tb.add_cylinder((3.65, ty + 0.95, tz + side * 0.28), (5.05, ty + 0.95, tz + side * 0.28), 0.42, 0.42, "SteelLight", segs=18, smooth=True)
        tb.add_dome((5.05, ty + 0.95, tz + side * 0.28), 0.24, 0.42, 0.42, "SteelMid", lat_segs=6, lon_segs=16, hemi=False, smooth=True)
        tb.add_cylinder((0.8, ty + 0.92, tz + side * 0.12), (3.7, ty + 0.92, tz + side * 0.12), 0.15, 0.15, "SteelTrim", segs=10, smooth=True)

    # Heavy Dark-Iron Spoked Locomotive Wheels + Angled Overlapping Bogie Skirts
    def add_wheel_axle(wx: float, wheel_r: float = 0.76):
        tb.add_cylinder((wx, wheel_r + 0.08, -1.72), (wx, wheel_r + 0.08, 1.72), 0.15, 0.15, "Gunmetal", segs=10)
        for s in (-1, 1):
            tb.add_cylinder((wx, wheel_r + 0.08, s * 1.56), (wx, wheel_r + 0.08, s * 1.82), wheel_r, wheel_r, "Gunmetal", segs=22, smooth=True)
            tb.add_cylinder((wx, wheel_r + 0.08, s * 1.54), (wx, wheel_r + 0.08, s * 1.86), wheel_r * 0.42, wheel_r * 0.42, "SteelTrim", segs=14, smooth=True)

    for wx in (10.1, 8.6, 6.2, 4.4, 2.2, 0.4, -3.2, -5.0, -8.5, -10.5, -13.5, -15.5, -18.8, -20.8, -23.5):
        add_wheel_axle(wx, 0.74 if wx > -1.0 else 0.64)

    def add_sloped_skirt_row(x_start: float, x_end: float, count: int, h_top: float = 1.68, z_top: float = 2.04, z_bot: float = 2.66):
        step = (x_end - x_start) / float(count)
        gap = 0.14
        for i in range(count):
            xa = x_start + i * step + gap * 0.5
            xb = x_start + (i + 1) * step - gap * 0.5
            slant = 0.22
            for side in (-1, 1):
                ring_top = [
                    (xa + slant, h_top, side * z_top),
                    (xb + slant, h_top, side * z_top),
                    (xb + slant, h_top, side * (z_top - 0.22)),
                    (xa + slant, h_top, side * (z_top - 0.22)),
                ]
                ring_bot = [
                    (xa, 0.14, side * z_bot),
                    (xb, 0.14, side * z_bot),
                    (xb, 0.14, side * (z_bot - 0.22)),
                    (xa, 0.14, side * (z_bot - 0.22)),
                ]
                tb.add_loft([ring_bot, ring_top], "SteelMid", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.30)

    add_sloped_skirt_row(-1.2, 8.0, count=6, h_top=1.74, z_top=2.08, z_bot=2.72)

    # ========================================================================
    # PART D: SECONDARY CHAMFERED ARMORED CITADEL & KOUTETSUJOU SERVICE BAY (X = -6.5..-1.4)
    # ========================================================================
    cit_bot = [
        (-1.45, 1.75, -2.25),
        (-1.45, 1.75, 2.25),
        (-6.45, 1.75, 2.25),
        (-6.45, 1.75, -2.25),
    ]
    cit_mid = [
        (-1.45, 4.75, -2.35),
        (-1.45, 4.75, 2.35),
        (-6.45, 4.75, 2.35),
        (-6.45, 4.75, -2.35),
    ]
    cit_top = [
        (-2.25, 6.28, -1.62),
        (-2.25, 6.28, 1.62),
        (-5.65, 6.28, 1.62),
        (-5.65, 6.28, -1.62),
    ]
    tb.add_loft([cit_bot, cit_mid, cit_top], "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.22)
    tb.add_box((-3.95, 1.35, 0.0), (5.2, 0.85, 3.6), "Gunmetal")

    tb.add_cylinder((-4.05, 6.20, 0.0), (-4.05, 6.68, 0.0), 1.48, 1.38, "SteelMid", segs=24, smooth=True)
    tb.add_dome((-4.05, 6.66, 0.0), 1.36, 0.42, 1.36, "SteelLight", lat_segs=6, lon_segs=24, hemi=True, smooth=True)
    tb.add_cylinder((-2.65, 6.20, 0.0), (-2.65, 6.82, 0.0), 0.56, 0.48, "SteelTrim", segs=18, smooth=True)
    tb.add_cylinder((-2.65, 6.72, 0.0), (-2.65, 6.84, 0.0), 0.36, 0.36, "DarkCavity", segs=16, smooth=True)

    for side in (-1, 1):
        for rx in (-2.1, -3.3, -4.6, -5.8):
            tb.add_box((rx, 3.30, side * 2.36), (0.20, 2.95, 0.18), "SteelTrim")
        for sx in (-2.7, -4.0, -5.2):
            tb.add_box((sx, 4.15, side * 2.36), (0.64, 0.24, 0.10), "DarkCavity")
            tb.add_box((sx, 4.15, side * 2.34), (0.52, 0.14, 0.06), "AmberGlow")

    # Sleek Koutetsujou Armored Maintenance Platform & Tactical Console Bay on South Flank (X = -2.6)
    tb.add_box((-2.60, 1.55, 2.75), (2.75, 0.16, 0.92), "SteelTrim")
    tb.add_box((-2.60, 2.65, 2.46), (2.28, 1.62, 0.28), "SteelMid")
    tb.add_box((-2.60, 2.80, 2.59), (1.84, 0.84, 0.08), "DarkCavity")
    tb.add_box((-2.60, 2.80, 2.63), (1.68, 0.68, 0.05), "ConsoleCyan")
    # Sloped armored rain-hood awning protecting the tactical console bay
    tb.add_box((-2.60, 3.52, 2.82), (2.46, 0.14, 0.98), "SteelMid", rot_deg=(14.0, 0.0, 0.0))
    tb.add_box((-2.60, 2.02, 2.78), (1.95, 0.76, 0.42), "Gunmetal")
    for step_i in range(4):
        sy = 1.32 - step_i * 0.32
        sz = 3.22 + step_i * 0.30
        tb.add_box((-2.60, sy, sz), (1.75, 0.10, 0.34), "SteelTrim")
    for sx_off in (-0.92, 0.92):
        tb.add_cylinder((-2.60 + sx_off, 1.55, 3.16), (-2.60 + sx_off, 0.25, 4.28), 0.036, 0.036, "SteelTrim", segs=8)
        tb.add_cylinder((-2.60 + sx_off, 2.25, 3.16), (-2.60 + sx_off, 0.95, 4.28), 0.032, 0.032, "SteelTrim", segs=8)
        tb.add_cylinder((-2.60 + sx_off, 0.25, 4.28), (-2.60 + sx_off, 0.95, 4.28), 0.032, 0.032, "SteelTrim", segs=8)

    add_sloped_skirt_row(-6.4, -3.9, count=2, h_top=1.68, z_top=2.04, z_bot=2.66)

    # ========================================================================
    # PART E: FORTIFIED ARMORED CARRIAGES (2 LONG KOUTETSUJOU WAGONS, X = -25.8..-6.6)
    # ========================================================================
    def add_armored_wagon(x_rear: float, x_front: float, height: float = 5.45, n_bays: int = 8):
        cx = 0.5 * (x_rear + x_front)
        length = x_front - x_rear

        tb.add_box((x_front + 0.38, 3.25, 0.0), (0.85, 3.15, 3.05), "Gunmetal")
        for g_off in (-0.22, 0.0, 0.22):
            tb.add_box((x_front + 0.38 + g_off, 3.25, 0.0), (0.10, 3.28, 3.18), "SteelTrim")

        tb.add_box((cx, 1.32, 0.0), (length - 0.1, 0.78, 3.85), "Gunmetal")

        w_bot = [
            (x_front, 1.65, -2.18),
            (x_front, 1.65, 2.18),
            (x_rear, 1.65, 2.18),
            (x_rear, 1.65, -2.18),
        ]
        w_eave = [
            (x_front, height - 0.72, -2.24),
            (x_front, height - 0.72, 2.24),
            (x_rear, height - 0.72, 2.24),
            (x_rear, height - 0.72, -2.24),
        ]
        w_roof = [
            (x_front - 0.35, height, -1.62),
            (x_front - 0.35, height, 1.62),
            (x_rear + 0.35, height, 1.62),
            (x_rear + 0.35, height, -1.62),
        ]
        tb.add_loft([w_bot, w_eave, w_roof], "SteelLight", closed_ring=True, cap_start=True, cap_end=True, smooth=False, uv_scale=0.22)

        for side in (-1, 1):
            tb.add_box((cx, 3.18, side * 2.26), (length + 0.04, 0.22, 0.14), "SteelMid")
            tb.add_cylinder((x_rear + 0.5, height + 0.22, side * 1.05), (x_front - 0.5, height + 0.22, side * 1.05), 0.14, 0.14, "SteelMid", segs=10)
            tb.add_pipe_railing(
                [(x_rear + 0.5, height, side * 1.54), (cx, height, side * 1.54), (x_front - 0.5, height, side * 1.54)],
                height=0.52,
                mat="SteelTrim",
                rad=0.026,
                mid_bar=False,
            )

        bay_w = length / float(n_bays)
        for bi in range(n_bays + 1):
            rx = x_rear + bi * bay_w
            for side in (-1, 1):
                tb.add_box((rx, 3.22, side * 2.26), (0.18, height - 2.38, 0.16), "SteelTrim")
            if bi < n_bays:
                bx = rx + bay_w * 0.5
                for side in (-1, 1):
                    tb.add_box((bx, 4.02, side * 2.26), (0.48, 0.30, 0.08), "DarkCavity")
                    if bi % 3 == 1:
                        tb.add_box((bx, 4.02, side * 2.23), (0.38, 0.16, 0.05), "AmberGlow")
                    tb.add_box((bx, 2.55, side * 2.25), (0.42, 0.14, 0.08), "DarkCavity")

        add_sloped_skirt_row(x_rear + 0.15, x_front - 0.15, count=n_bays, h_top=1.65, z_top=2.04, z_bot=2.62)

    add_armored_wagon(-16.2, -7.1, height=5.55, n_bays=7)
    tb.add_box((-11.6, 5.82, 0.0), (2.8, 0.56, 2.05), "SteelMid")

    add_armored_wagon(-25.4, -16.9, height=5.20, n_bays=6)
    tb.add_box((-25.52, 3.25, 0.0), (0.32, 3.35, 4.35), "SteelMid")
    for side in (-1, 1):
        tb.add_cylinder((-25.68, 2.85, side * 1.48), (-25.80, 2.85, side * 1.48), 0.22, 0.22, "CrimsonRim", segs=12)
        tb.add_cylinder((-25.78, 2.85, side * 1.48), (-25.84, 2.85, side * 1.48), 0.15, 0.15, "AmberGlow", segs=12)

    # ========================================================================
    # PART F: HEAVY INTEGRATED STEEL RAIL TRACK & TIMBER SLEEPERS (X = -27.5..23.5)
    # ========================================================================
    for side in (-1, 1):
        tb.add_box((-2.0, 0.10, side * 1.56), (51.0, 0.18, 0.16), "Gunmetal")
    for tx in range(-27, 24):
        tb.add_box((float(tx), 0.04, 0.0), (0.34, 0.10, 4.25), "WoodSleeper")


# ============================================================================
# 4. GLB 2.0 BINARY SERIALIZER (WITH EMBEDDED PNG TEXTURES)
# ============================================================================

def export_glb(
    tb: TrainBuilder,
    out_path: str,
    steel_light_png: bytes,
    steel_dark_png: bytes,
):
    bin_chunks: List[bytes] = []
    bin_len = 0

    def append_bin(data: bytes) -> Tuple[int, int]:
        nonlocal bin_len
        pad = (4 - (bin_len % 4)) % 4
        if pad:
            bin_chunks.append(b"\x00" * pad)
            bin_len += pad
        offset = bin_len
        bin_chunks.append(data)
        bin_len += len(data)
        return offset, len(data)

    buffer_views = []
    accessors = []

    def add_buffer_view(data: bytes, target: Optional[int] = None) -> int:
        off, length = append_bin(data)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": length}
        if target is not None:
            bv["target"] = target
        idx = len(buffer_views)
        buffer_views.append(bv)
        return idx

    def add_accessor(bv_idx: int, comp_type: int, count: int, acc_type: str, vmin=None, vmax=None) -> int:
        acc = {
            "bufferView": bv_idx,
            "byteOffset": 0,
            "componentType": comp_type,
            "count": count,
            "type": acc_type,
        }
        if vmin is not None:
            acc["min"] = vmin
        if vmax is not None:
            acc["max"] = vmax
        idx = len(accessors)
        accessors.append(acc)
        return idx

    bv_img_light = add_buffer_view(steel_light_png)
    bv_img_dark = add_buffer_view(steel_dark_png)

    images = [
        {"bufferView": bv_img_light, "mimeType": "image/png", "name": "train_armor_steel"},
        {"bufferView": bv_img_dark, "mimeType": "image/png", "name": "train_armor_dark"},
    ]
    samplers = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
    textures = [
        {"sampler": 0, "source": 0},
        {"sampler": 0, "source": 1},
    ]

    mat_defs = {
        "SteelLight": {
            "name": "Koutetsujou_SteelLight",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 0},
                "baseColorFactor": [1.0, 1.0, 1.0, 1.0],
                "metallicFactor": 0.30,
                "roughnessFactor": 0.44,
            },
        },
        "SteelMid": {
            "name": "Koutetsujou_SteelMid",
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": 1},
                "baseColorFactor": [0.92, 0.95, 1.0, 1.0],
                "metallicFactor": 0.38,
                "roughnessFactor": 0.46,
            },
        },
        "SteelTrim": {
            "name": "Koutetsujou_SteelTrim",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.22, 0.26, 0.32, 1.0],
                "metallicFactor": 0.52,
                "roughnessFactor": 0.42,
            },
        },
        "Gunmetal": {
            "name": "Koutetsujou_Gunmetal",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.10, 0.12, 0.15, 1.0],
                "metallicFactor": 0.62,
                "roughnessFactor": 0.50,
            },
        },
        "DarkCavity": {
            "name": "Koutetsujou_DarkCavity",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.022, 0.026, 0.036, 1.0],
                "metallicFactor": 0.05,
                "roughnessFactor": 0.92,
            },
        },
        "CrimsonRim": {
            "name": "Koutetsujou_CrimsonRim",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.58, 0.10, 0.08, 1.0],
                "metallicFactor": 0.24,
                "roughnessFactor": 0.40,
            },
        },
        "BrassOrb": {
            "name": "Koutetsujou_BrassOrb",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.68, 0.55, 0.26, 1.0],
                "metallicFactor": 0.30,
                "roughnessFactor": 0.28,
            },
            "emissiveFactor": [0.48, 0.38, 0.14],
        },
        "AmberGlow": {
            "name": "Koutetsujou_AmberGlow",
            "pbrMetallicRoughness": {
                "baseColorFactor": [1.0, 0.72, 0.28, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.2,
            },
            "emissiveFactor": [1.0, 0.62, 0.18],
        },
        "ConsoleCyan": {
            "name": "Koutetsujou_ConsoleCyan",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.22, 0.85, 1.0, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.2,
            },
            "emissiveFactor": [0.18, 0.78, 1.0],
        },
        "WoodSleeper": {
            "name": "Koutetsujou_WoodSleeper",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.14, 0.12, 0.10, 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 0.92,
            },
        },
    }

    materials = []
    mat_index_map: Dict[str, int] = {}
    for key, mdef in mat_defs.items():
        mat_index_map[key] = len(materials)
        materials.append(mdef)

    primitives = []
    total_verts = 0
    total_tris = 0

    for mat_key, bucket in tb.buckets.items():
        res = bucket.finalize()
        if res is None:
            continue
        pos, norm, uv, idx = res
        total_verts += len(pos)
        total_tris += len(idx) // 3

        bv_pos = add_buffer_view(pos.astype("<f4").tobytes(), target=34962)
        bv_norm = add_buffer_view(norm.astype("<f4").tobytes(), target=34962)
        bv_uv = add_buffer_view(uv.astype("<f4").tobytes(), target=34962)
        bv_idx = add_buffer_view(idx.astype("<u4").tobytes(), target=34963)

        acc_pos = add_accessor(
            bv_pos, 5126, len(pos), "VEC3",
            vmin=[float(x) for x in pos.min(axis=0)],
            vmax=[float(x) for x in pos.max(axis=0)],
        )
        acc_norm = add_accessor(bv_norm, 5126, len(norm), "VEC3")
        acc_uv = add_accessor(bv_uv, 5126, len(uv), "VEC2")
        acc_idx = add_accessor(bv_idx, 5125, len(idx), "SCALAR")

        primitives.append({
            "attributes": {
                "POSITION": acc_pos,
                "NORMAL": acc_norm,
                "TEXCOORD_0": acc_uv,
            },
            "indices": acc_idx,
            "material": mat_index_map[mat_key],
            "mode": 4,
        })

    bin_pad = (4 - (bin_len % 4)) % 4
    if bin_pad:
        bin_chunks.append(b"\x00" * bin_pad)
        bin_len += bin_pad
    bin_body = b"".join(bin_chunks)

    gltf = {
        "asset": {"version": "2.0", "generator": "mygame Koutetsujou Pipeline"},
        "scene": 0,
        "scenes": [{"name": "KoutetsujouTrain", "nodes": [0]}],
        "nodes": [{"name": "Koutetsujou_ArmoredTrain", "mesh": 0}],
        "meshes": [{"name": "Koutetsujou_Mesh", "primitives": primitives}],
        "materials": materials,
        "textures": textures,
        "samplers": samplers,
        "images": images,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(bin_body)}],
    }

    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - (len(json_bytes) % 4)) % 4
    if json_pad:
        json_bytes += b" " * json_pad

    total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_body)
    header = struct.pack("<4sII", b"glTF", 2, total_len)
    chunk0 = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
    chunk1 = struct.pack("<II", len(bin_body), 0x004E4942) + bin_body

    with open(out_path, "wb") as f:
        f.write(header + chunk0 + chunk1)

    print(
        f"[Koutetsujou] Exported {out_path} ({os.path.getsize(out_path) // 1024} KB, "
        f"{total_verts} verts, {total_tris} tris, {len(primitives)} materials)"
    )


def main():
    light_tex_path = os.path.join(ENV_DIR, "train_armor_steel.png")
    dark_tex_path = os.path.join(ENV_DIR, "train_armor_dark.png")
    print("[Koutetsujou] Generating clean anime riveted silver-blue steel textures...")
    steel_light_png = generate_koutetsujou_steel_texture(
        light_tex_path,
        size=1024,
        base_rgb=(208.0, 218.0, 228.0),
        shadow_rgb=(148.0, 164.0, 182.0),
        seed=404,
    )
    steel_dark_png = generate_koutetsujou_steel_texture(
        dark_tex_path,
        size=1024,
        base_rgb=(162.0, 176.0, 192.0),
        shadow_rgb=(104.0, 118.0, 136.0),
        seed=505,
    )
    print(f"[Koutetsujou] Wrote textures -> {light_tex_path}, {dark_tex_path}")

    tb = TrainBuilder()
    build_koutetsujou_train(tb)
    out_glb = os.path.join(OUT_DIR, "kabaneri_armored_train.glb")
    export_glb(tb, out_glb, steel_light_png, steel_dark_png)


if __name__ == "__main__":
    main()
