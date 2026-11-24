#!/usr/bin/env python3
"""
Blender 4.x Headless Pipeline: Build 3 Blue Archive-style 3D Chibi Anime Characters
Outputs rigged & animated GLB files (with idle, walk, shoot, interact, roll):
  - assets/models/characters/reina_ar.glb
  - assets/models/characters/chisa_smg.glb
  - assets/models/characters/lily_sg.glb
Also renders a visual inspection lineup sheet to tools/art_pipeline/previews/characters_preview.png
"""

import math
import os
import sys
import bpy
import bmesh
from mathutils import Vector, Euler, Matrix

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT_DIR, "assets", "models", "characters")
FACE_DIR = os.path.join(ROOT_DIR, "assets", "textures", "faces")
PREVIEW_DIR = os.path.join(ROOT_DIR, "tools", "art_pipeline", "previews")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c):
    return tuple(((v / 255.0) ** 2.2) for v in c)


def make_mat(name, rgb255, roughness=0.58, metallic=0.0, emission_rgb255=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    lin = srgb_to_linear(rgb255)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_rgb255 is not None and emission_strength > 0.0:
        elin = srgb_to_linear(emission_rgb255)
        bsdf.inputs["Emission Color"].default_value = (elin[0], elin[1], elin[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def make_face_mat(name, image_path):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.72
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(image_path, check_existing=True)
    img.pack()
    tex.image = img
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def set_smooth(obj):
    if obj.type != "MESH":
        return
    for poly in obj.data.polygons:
        poly.use_smooth = True


def link_to_bone(obj, arm_obj, bone_name):
    """Rigid-weight an entire mesh object cleanly to a single armature bone (ideal for crisp anime chibi parts)."""
    vg = obj.vertex_groups.new(name=bone_name)
    all_idx = [v.index for v in obj.data.vertices]
    if all_idx:
        vg.add(all_idx, 1.0, "REPLACE")
    obj.parent = arm_obj
    mod = obj.modifiers.new(name="Armature", type="ARMATURE")
    mod.object = arm_obj


def create_mesh_obj(name, bm, mat, location=(0, 0, 0), rotation=(0, 0, 0), scale=(1, 1, 1)):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    obj.scale = scale
    if mat is not None:
        obj.data.materials.append(mat)
    set_smooth(obj)
    return obj


def make_capsule(name, radius, length, mat, loc=(0, 0, 0), rot=(0, 0, 0), segs=16):
    """Create a smooth rounded limb capsule centered around loc along Z."""
    bm = bmesh.new()
    # Build via uv sphere stretched vertically
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=12, radius=radius)
    half_cyl = max(0.0, length * 0.5 - radius)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.z += half_cyl
        elif v.co.z < 0:
            v.co.z -= half_cyl
    return create_mesh_obj(name, bm, mat, location=loc, rotation=rot)


def make_box(name, size, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0.0:
        bmesh.ops.bevel(
            bm,
            geom=bm.edges[:],
            offset=bevel,
            segments=2,
            affect="EDGES",
            clamp_overlap=True,
        )
    return create_mesh_obj(name, bm, mat, location=loc, rotation=rot)


def make_cyl(name, r1, r2, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), segs=18):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segs,
        radius1=r1,
        radius2=r2,
        depth=depth,
    )
    return create_mesh_obj(name, bm, mat, location=loc, rotation=rot)


def make_curved_hair_strand(
    name,
    points,
    widths,
    thicknesses,
    mat,
    segs_ring=8,
):
    """Build a sculpted tapered curved anime hair lock along a 3D spine."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, pt in enumerate(points):
        p = Vector(pt)
        if i < n - 1:
            tangent = (Vector(points[i + 1]) - p).normalized()
        else:
            tangent = (p - Vector(points[i - 1])).normalized()
        up_ref = Vector((0, 0, 1)) if abs(tangent.z) < 0.92 else Vector((0, -1, 0))
        side = tangent.cross(up_ref).normalized()
        normal = side.cross(tangent).normalized()

        w = widths[i]
        th = thicknesses[i]
        ring = []
        for s in range(segs_ring):
            ang = (s / segs_ring) * math.tau
            # Almond/diamond anime strand cross-section
            ca = math.cos(ang)
            sa = math.sin(ang)
            pos = p + side * (ca * w) + normal * (sa * th)
            ring.append(bm.verts.new(pos))
        rings.append(ring)

    for i in range(n - 1):
        r0 = rings[i]
        r1 = rings[i + 1]
        for s in range(segs_ring):
            s_next = (s + 1) % segs_ring
            bm.faces.new((r0[s], r0[s_next], r1[s_next], r1[s]))

    # Cap root & tip cleanly
    root_center = bm.verts.new(Vector(points[0]))
    tip_center = bm.verts.new(Vector(points[-1]))
    for s in range(segs_ring):
        s_next = (s + 1) % segs_ring
        bm.faces.new((rings[0][s_next], rings[0][s], root_center))
        bm.faces.new((rings[-1][s], rings[-1][s_next], tip_center))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return create_mesh_obj(name, bm, mat)


def build_anime_head(head_center_z, skin_mat, face_mat):
    """
    Sculpt a cute Blue Archive SD anime chibi head (facing -Y) with:
      - Slightly wide soft chibi cheeks and gently tapered chin
      - Clean front planar-projected UVs onto the face texture so eyes/blush/mouth align perfectly!
    """
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=24, radius=0.225)
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # Deform sphere into cute anime chibi head silhouette
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        # Slightly wider cheeks, softer lower jaw, gently tapered chin
        if z < 0:
            t = clamp(-z / 0.225, 0.0, 1.0)
            # Subtle chin taper
            taper = 1.0 - 0.24 * (t ** 1.7)
            x *= taper
            y *= 1.0 - 0.14 * (t ** 1.5)
            # Soft chibi cheek puff near z ~ -0.05
            cheek = math.exp(-((z + 0.045) / 0.07) ** 2) * 0.015
            x *= 1.0 + cheek * 4.5
            # Flatten front face slightly for crisp anime reading
            if y < 0:
                y *= 0.92
        else:
            # Round cute cranium
            y *= 0.96
            x *= 1.02
        v.co = Vector((x, y, z))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])

    # Assign materials: slot 0 = face_mat (front hemisphere), slot 1 = skin_mat (back/sides)
    for face in bm.faces:
        c = face.calc_center_median()
        if c.y < -0.04 and abs(c.x) < 0.185 and -0.195 < c.z < 0.165:
            face.material_index = 0
        else:
            face.material_index = 1
        for loop in face.loops:
            vx, vy, vz = loop.vert.co.x, loop.vert.co.y, loop.vert.co.z
            # Front orthographic UV projection for the face region (-Y is facing camera!)
            # Viewer looking at front (-Y) sees +X on their right (u=1) and -X on their left (u=0)
            u = 0.5 + (vx / 0.34)
            v_uv = 0.54 + (vz / 0.34)
            loop[uv_layer].uv = (clamp(u, 0.01, 0.99), clamp(v_uv, 0.01, 0.99))

    mesh = bpy.data.meshes.new("HeadMesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Head", mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = (0.0, 0.0, head_center_z)
    obj.data.materials.append(face_mat)
    obj.data.materials.append(skin_mat)
    set_smooth(obj)
    return obj


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def build_hair_set(cfg, head_z, hair_mat, hair_accent_mat, accessory_mat):
    """Build layered sculpted anime hair (dome + tapered bangs + side locks + signature back style)."""
    head_parts = []
    back_parts = []
    style = cfg["hair_style"]

    # 1. Smooth Outer Hair Cap/Dome covering top, back & sides of head
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=20, radius=0.244)
    for v in bm.verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        # Pull down slightly in back, open cleanly around front face
        if y < -0.05 and z < 0.065:
            # Push front-lower vertices inward/upward so they stay behind forehead bangs
            v.co.z = max(z, 0.055)
            v.co.y = max(y, -0.18)
        elif y > 0.0 and z < 0.0:
            # Fuller back hair volume
            v.co.z = z * 1.18
            v.co.y = y * 1.08
            v.co.x = x * 1.04
        else:
            v.co.x *= 1.05
            v.co.y *= 1.03
            v.co.z *= 1.04
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    dome = create_mesh_obj("HairDome", bm, hair_mat, location=(0.0, 0.012, head_z + 0.018))
    head_parts.append(dome)

    # 2. Cute Sculpted Front Anime Bangs (7 tapered curved strands framing the forehead & eyes)
    bang_specs = [
        (-0.155, 0.055, 0.022, -0.055),
        (-0.100, 0.052, 0.024, -0.032),
        (-0.045, 0.048, 0.024, -0.015),
        (0.005, 0.052, 0.026, -0.020),
        (0.055, 0.048, 0.024, -0.012),
        (0.108, 0.052, 0.024, -0.035),
        (0.158, 0.054, 0.022, -0.055),
    ]
    for idx, (bx, bw, bth, drop_extra) in enumerate(bang_specs):
        ang = bx * 2.6
        r_top = 0.205
        r_mid = 0.236
        r_tip = 0.228
        pts = [
            (bx * 0.55, -math.cos(ang) * r_top * 0.72, head_z + 0.215),
            (bx * 0.88, -math.cos(ang) * r_mid, head_z + 0.145),
            (bx * 1.02, -math.cos(ang) * (r_mid + 0.008), head_z + 0.075),
            (bx * 1.06 + (0.012 if idx == 3 else 0.0), -math.cos(ang) * r_tip, head_z + 0.035 + drop_extra),
        ]
        strand = make_curved_hair_strand(
            f"Bang_{idx}",
            pts,
            widths=[bw * 0.7, bw, bw * 0.78, 0.005],
            thicknesses=[bth * 0.8, bth, bth * 0.65, 0.004],
            mat=hair_mat,
        )
        head_parts.append(strand)

    # 3. Framing Side Locks (left & right curving past cheeks)
    for side in (-1, 1):
        side_len = 0.26 if style != "bob" else 0.20
        pts = [
            (side * 0.185, -0.04, head_z + 0.14),
            (side * 0.232, -0.09, head_z + 0.03),
            (side * 0.222, -0.10, head_z - side_len * 0.55),
            (side * 0.175, -0.08, head_z - side_len),
        ]
        s_lock = make_curved_hair_strand(
            f"SideLock_{'L' if side < 0 else 'R'}",
            pts,
            widths=[0.042, 0.052, 0.040, 0.008],
            thicknesses=[0.025, 0.030, 0.022, 0.005],
            mat=hair_mat,
        )
        head_parts.append(s_lock)

    # Cute ahoge (anime cowlick) on top for Reina & Lily!
    if style in ("ponytail", "twintails"):
        ahoge_pts = [
            (0.0, -0.02, head_z + 0.245),
            (0.035, -0.01, head_z + 0.315),
            (0.095, 0.01, head_z + 0.325),
            (0.135, 0.02, head_z + 0.285),
        ]
        head_parts.append(
            make_curved_hair_strand(
                "Ahoge",
                ahoge_pts,
                widths=[0.016, 0.018, 0.012, 0.003],
                thicknesses=[0.012, 0.012, 0.008, 0.002],
                mat=hair_mat,
            )
        )

    # 4. Signature Hairstyle Back / Accessories
    if style == "ponytail":
        # Reina: High flowing silver ponytail + tactical ribbon tie
        tie = make_cyl("HairTie", 0.055, 0.055, 0.042, accessory_mat, loc=(0.0, 0.225, head_z + 0.125), rot=(math.radians(65), 0, 0))
        head_parts.append(tie)
        # Main sweeping ponytail + 2 layered sub-strands
        for k, (ox, oz, w_sc) in enumerate([(0.0, 0.0, 1.0), (-0.055, -0.02, 0.72), (0.055, -0.02, 0.72)]):
            pts = [
                (ox * 0.4, 0.22, head_z + 0.125 + oz),
                (ox * 0.9, 0.32, head_z + 0.08 + oz),
                (ox * 1.15, 0.36, head_z - 0.10 + oz),
                (ox * 1.05, 0.33, head_z - 0.30 + oz),
                (ox * 0.85, 0.27, head_z - 0.44 + oz),
            ]
            pt_strand = make_curved_hair_strand(
                f"Ponytail_{k}",
                pts,
                widths=[0.045 * w_sc, 0.085 * w_sc, 0.095 * w_sc, 0.055 * w_sc, 0.010],
                thicknesses=[0.038 * w_sc, 0.065 * w_sc, 0.068 * w_sc, 0.042 * w_sc, 0.008],
                mat=hair_mat,
            )
            back_parts.append(pt_strand)

    elif style == "bob":
        # Chisa: Sleek curved anime bob + forehead engineer goggles!
        for k in range(-2, 3):
            bx = k * 0.075
            pts = [
                (bx * 0.85, 0.18, head_z + 0.09),
                (bx * 1.02, 0.245, head_z - 0.04),
                (bx * 0.94, 0.225, head_z - 0.17),
                (bx * 0.82, 0.175, head_z - 0.24),
            ]
            back_parts.append(
                make_curved_hair_strand(
                    f"BobBack_{k+2}",
                    pts,
                    widths=[0.062, 0.068, 0.056, 0.014],
                    thicknesses=[0.036, 0.040, 0.030, 0.008],
                    mat=hair_mat,
                )
            )
        # Tactical Engineer Goggles perched on forehead!
        strap_bm = bmesh.new()
        bmesh.ops.create_cone(strap_bm, cap_ends=False, segments=24, radius1=0.252, radius2=0.252, depth=0.045)
        strap = create_mesh_obj("GoggleStrap", strap_bm, hair_accent_mat, location=(0.0, 0.005, head_z + 0.145), rotation=(math.radians(-14), 0, 0))
        head_parts.append(strap)
        lens_mat = make_mat("GoggleLens", (255, 196, 62), roughness=0.18, metallic=0.1, emission_rgb255=(255, 178, 48), emission_strength=0.65)
        for side in (-1, 1):
            rim = make_cyl(f"GoggleRim_{side}", 0.058, 0.058, 0.042, hair_accent_mat, loc=(side * 0.076, -0.228, head_z + 0.165), rot=(math.radians(76), 0, math.radians(-side * 16)))
            lens = make_cyl(f"GoggleLens_{side}", 0.044, 0.044, 0.046, lens_mat, loc=(side * 0.076, -0.232, head_z + 0.165), rot=(math.radians(76), 0, math.radians(-side * 16)))
            head_parts.extend([rim, lens])

    elif style == "twintails":
        # Lily: Bouncy golden twin-tails with red hair clips
        for side in (-1, 1):
            clip = make_box(f"HairClip_{side}", (0.048, 0.048, 0.048), accessory_mat, loc=(side * 0.225, 0.04, head_z + 0.135), bevel=0.012)
            head_parts.append(clip)
            pts = [
                (side * 0.225, 0.045, head_z + 0.135),
                (side * 0.345, 0.085, head_z + 0.085),
                (side * 0.395, 0.115, head_z - 0.105),
                (side * 0.365, 0.110, head_z - 0.295),
                (side * 0.315, 0.085, head_z - 0.420),
            ]
            tail = make_curved_hair_strand(
                f"TwinTail_{'L' if side < 0 else 'R'}",
                pts,
                widths=[0.042, 0.078, 0.088, 0.056, 0.012],
                thicknesses=[0.036, 0.062, 0.068, 0.044, 0.008],
                mat=hair_mat,
            )
            back_parts.append(tail)

    return head_parts, back_parts


def build_halo(cfg, head_z):
    """Build Blue Archive signature floating emissive geometric Halo above the head."""
    halo_col = cfg["halo_color"]
    mat = make_mat(f"Halo_{cfg['id']}", halo_col, roughness=0.2, emission_rgb255=halo_col, emission_strength=3.8)
    parts = []
    hz = head_z + 0.395
    style = cfg["halo_style"]

    def add_torus(name, major_r, minor_r, loc, rot=(0, 0, 0), segs=36):
        bm = bmesh.new()
        for i in range(segs):
            a0 = (i / segs) * math.tau
            c0 = Vector((math.cos(a0) * major_r, math.sin(a0) * major_r, 0.0))
            rad = Vector((math.cos(a0), math.sin(a0), 0.0))
            for j in range(8):
                b0 = (j / 8) * math.tau
                p = c0 + rad * (math.cos(b0) * minor_r) + Vector((0, 0, math.sin(b0) * minor_r))
                bm.verts.new(p)
        bm.verts.ensure_lookup_table()
        for i in range(segs):
            inext = (i + 1) % segs
            for j in range(8):
                jnext = (j + 1) % 8
                v0 = bm.verts[i * 8 + j]
                v1 = bm.verts[inext * 8 + j]
                v2 = bm.verts[inext * 8 + jnext]
                v3 = bm.verts[i * 8 + jnext]
                bm.faces.new((v0, v1, v2, v3))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        return create_mesh_obj(name, bm, mat, loc, rot)

    if style == "star":
        parts.append(add_torus("HaloOuter", 0.19, 0.011, (0, 0.02, hz), rot=(math.radians(8), 0, 0)))
        parts.append(add_torus("HaloInner", 0.11, 0.008, (0, 0.02, hz + 0.005), rot=(math.radians(8), 0, 0)))
        for k in range(4):
            ang = k * (math.pi * 0.5)
            bar = make_box(f"HaloSpoke_{k}", (0.14, 0.014, 0.010), mat, loc=(math.cos(ang) * 0.15, 0.02 + math.sin(ang) * 0.15, hz), rot=(math.radians(8), 0, ang))
            parts.append(bar)
    elif style == "gear":
        parts.append(add_torus("HaloGearOuter", 0.18, 0.013, (0, 0.02, hz), rot=(math.radians(6), 0, 0)))
        parts.append(add_torus("HaloGearInner", 0.125, 0.009, (0, 0.02, hz), rot=(math.radians(6), 0, 0)))
        for k in range(8):
            ang = k * (math.tau / 8)
            tooth = make_box(f"HaloTooth_{k}", (0.042, 0.026, 0.014), mat, loc=(math.cos(ang) * 0.198, 0.02 + math.sin(ang) * 0.198, hz), rot=(math.radians(6), 0, ang))
            parts.append(tooth)
    else:
        # Crosshair double ring
        parts.append(add_torus("HaloCrossOuter", 0.20, 0.012, (0, 0.02, hz), rot=(math.radians(10), 0, 0)))
        parts.append(add_torus("HaloCrossInner", 0.13, 0.008, (0, 0.02, hz + 0.012), rot=(math.radians(10), 0, 0)))
        for k in range(4):
            ang = k * (math.pi * 0.5) + math.pi * 0.25
            tick = make_box(f"HaloTick_{k}", (0.095, 0.016, 0.012), mat, loc=(math.cos(ang) * 0.165, 0.02 + math.sin(ang) * 0.165, hz + 0.005), rot=(math.radians(10), 0, ang))
            parts.append(tick)
    return parts


def build_weapon(weapon_type, hand_r_pos):
    """Build detailed stylized tactical firearm oriented along -Y (forward) attached to right hand."""
    gun_dark = make_mat("GunDark", (42, 46, 54), roughness=0.42, metallic=0.62)
    gun_mid = make_mat("GunMid", (84, 90, 102), roughness=0.45, metallic=0.52)
    gun_accent = make_mat("GunAccent", (216, 172, 74), roughness=0.35, metallic=0.75)
    sight_glow = make_mat("SightGlow", (80, 235, 255), roughness=0.2, emission_rgb255=(70, 230, 255), emission_strength=2.5)
    parts = []
    hx, hy, hz = hand_r_pos

    if weapon_type == "ar":
        # Tactical Assault Rifle (HK416-inspired)
        parts.append(make_box("AR_Receiver", (0.056, 0.34, 0.088), gun_dark, (hx, hy - 0.14, hz + 0.03), bevel=0.008))
        parts.append(make_box("AR_Handguard", (0.050, 0.24, 0.064), gun_mid, (hx, hy - 0.38, hz + 0.035), bevel=0.006))
        parts.append(make_cyl("AR_Barrel", 0.014, 0.014, 0.22, gun_dark, (hx, hy - 0.56, hz + 0.038), (math.radians(90), 0, 0)))
        parts.append(make_cyl("AR_Muzzle", 0.021, 0.018, 0.065, gun_mid, (hx, hy - 0.67, hz + 0.038), (math.radians(90), 0, 0)))
        parts.append(make_box("AR_Stock", (0.044, 0.22, 0.092), gun_dark, (hx, hy + 0.12, hz + 0.015), bevel=0.008))
        parts.append(make_box("AR_Mag", (0.036, 0.068, 0.165), gun_mid, (hx, hy - 0.20, hz - 0.085), (math.radians(-16), 0, 0), bevel=0.005))
        parts.append(make_box("AR_Grip", (0.036, 0.052, 0.105), gun_dark, (hx, hy - 0.02, hz - 0.055), (math.radians(18), 0, 0), bevel=0.005))
        parts.append(make_cyl("AR_Scope", 0.024, 0.022, 0.15, gun_dark, (hx, hy - 0.15, hz + 0.105), (math.radians(90), 0, 0)))
        parts.append(make_cyl("AR_Lens", 0.018, 0.018, 0.012, sight_glow, (hx, hy - 0.225, hz + 0.105), (math.radians(90), 0, 0)))
    elif weapon_type == "smg":
        # Compact Tactical SMG (Vector/MP7-inspired)
        parts.append(make_box("SMG_Body", (0.058, 0.28, 0.105), gun_dark, (hx, hy - 0.12, hz + 0.035), bevel=0.008))
        parts.append(make_box("SMG_Accent", (0.062, 0.16, 0.036), gun_accent, (hx, hy - 0.14, hz + 0.048), bevel=0.004))
        parts.append(make_cyl("SMG_Suppressor", 0.022, 0.022, 0.16, gun_mid, (hx, hy - 0.34, hz + 0.038), (math.radians(90), 0, 0)))
        parts.append(make_box("SMG_Mag", (0.030, 0.046, 0.185), gun_mid, (hx, hy - 0.18, hz - 0.095), (math.radians(-10), 0, 0), bevel=0.004))
        parts.append(make_box("SMG_Stock", (0.036, 0.16, 0.068), gun_dark, (hx, hy + 0.09, hz + 0.025), bevel=0.006))
        parts.append(make_box("SMG_RedDot", (0.036, 0.068, 0.046), gun_dark, (hx, hy - 0.11, hz + 0.105), bevel=0.004))
        parts.append(make_box("SMG_Holo", (0.022, 0.012, 0.022), sight_glow, (hx, hy - 0.145, hz + 0.108)))
    else:
        # Heavy Tactical Shotgun (M1014/SPAS-inspired)
        sg_red = make_mat("SG_Red", (196, 46, 56), roughness=0.45, metallic=0.15)
        parts.append(make_box("SG_Receiver", (0.066, 0.32, 0.098), gun_dark, (hx, hy - 0.14, hz + 0.032), bevel=0.009))
        parts.append(make_cyl("SG_Barrel", 0.022, 0.022, 0.42, gun_dark, (hx, hy - 0.48, hz + 0.052), (math.radians(90), 0, 0)))
        parts.append(make_cyl("SG_UnderTube", 0.018, 0.018, 0.36, gun_mid, (hx, hy - 0.44, hz + 0.010), (math.radians(90), 0, 0)))
        parts.append(make_box("SG_Pump", (0.062, 0.16, 0.058), sg_red, (hx, hy - 0.39, hz + 0.008), bevel=0.008))
        parts.append(make_box("SG_Stock", (0.052, 0.24, 0.105), gun_dark, (hx, hy + 0.12, hz + 0.01), bevel=0.009))
        # Side shell rack (4 red shotgun shells!)
        for k in range(4):
            parts.append(make_cyl(f"SG_Shell_{k}", 0.010, 0.010, 0.046, sg_red, (hx - 0.038, hy - 0.08 - k * 0.028, hz + 0.035)))
    return parts


def build_armature(name):
    """Build standard humanoid chibi Armature (facing -Y, Z up)."""
    arm_data = bpy.data.armatures.new(f"{name}_ArmatureData")
    arm_obj = bpy.data.objects.new("Armature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")

    eb = arm_data.edit_bones

    def add_bone(bname, head, tail, parent_name=None):
        b = eb.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if parent_name:
            b.parent = eb[parent_name]
        return b

    # Proportions: Total height ~1.36m (head center at Z=0.96, top of head Z=1.18, halo Z=1.35)
    add_bone("root", (0, 0, 0.0), (0, 0, 0.18))
    add_bone("hips", (0, 0, 0.46), (0, 0, 0.56), "root")
    add_bone("spine", (0, 0, 0.56), (0, 0, 0.72), "hips")
    add_bone("head", (0, 0, 0.73), (0, 0, 1.16), "spine")
    add_bone("halo", (0, 0.02, 1.32), (0, 0.02, 1.44), "head")
    add_bone("hair_back", (0, 0.20, 1.06), (0, 0.30, 0.65), "head")

    for side, sfx in [(-1, "l"), (1, "r")]:
        sx = side * 0.155
        add_bone(f"upper_arm_{sfx}", (sx, 0.0, 0.70), (side * 0.21, 0.0, 0.55), "spine")
        add_bone(f"lower_arm_{sfx}", (side * 0.21, 0.0, 0.55), (side * 0.22, -0.04, 0.42), f"upper_arm_{sfx}")
        if sfx == "r":
            add_bone("weapon_r", (0.22, -0.06, 0.42), (0.22, -0.35, 0.42), "lower_arm_r")

        lx = side * 0.088
        add_bone(f"thigh_{sfx}", (lx, 0.0, 0.45), (lx, 0.0, 0.25), "hips")
        add_bone(f"shin_{sfx}", (lx, 0.0, 0.25), (lx, 0.0, 0.04), f"thigh_{sfx}")

    bpy.ops.object.mode_set(mode="OBJECT")
    # Set Euler XYZ rotation mode on all pose bones for clean predictable animation curves
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm_obj


def build_character_geometry(cfg, arm_obj):
    """Build all Blue Archive chibi body parts & bind cleanly to the Armature."""
    skin_mat = make_mat(f"Skin_{cfg['id']}", cfg["skin_color"], roughness=0.68)
    face_mat = make_face_mat(f"Face_{cfg['id']}", os.path.join(FACE_DIR, cfg["face_file"]))
    hair_mat = make_mat(f"Hair_{cfg['id']}", cfg["hair_color"], roughness=0.45)
    hair_acc_mat = make_mat(f"HairAcc_{cfg['id']}", cfg["hair_accent"], roughness=0.45, metallic=0.15)
    jacket_mat = make_mat(f"Jacket_{cfg['id']}", cfg["jacket_color"], roughness=0.58)
    shirt_mat = make_mat(f"Shirt_{cfg['id']}", cfg["shirt_color"], roughness=0.62)
    skirt_mat = make_mat(f"Skirt_{cfg['id']}", cfg["skirt_color"], roughness=0.56)
    trim_mat = make_mat(f"Trim_{cfg['id']}", cfg["trim_color"], roughness=0.45)
    sock_mat = make_mat(f"Sock_{cfg['id']}", cfg["sock_color"], roughness=0.65)
    boot_mat = make_mat(f"Boot_{cfg['id']}", cfg["boot_color"], roughness=0.42, metallic=0.12)

    head_z = 0.96

    # 1. Head + Anime Face UV
    head_obj = build_anime_head(head_z, skin_mat, face_mat)
    link_to_bone(head_obj, arm_obj, "head")

    # Neck
    neck = make_cyl("Neck", 0.046, 0.044, 0.09, skin_mat, loc=(0, 0, 0.75))
    link_to_bone(neck, arm_obj, "spine")

    # 2. Hair + Halo
    head_hair, back_hair = build_hair_set(cfg, head_z, hair_mat, hair_acc_mat, trim_mat)
    for obj in head_hair:
        link_to_bone(obj, arm_obj, "head")
    for obj in back_hair:
        link_to_bone(obj, arm_obj, "hair_back")

    for obj in build_halo(cfg, head_z):
        link_to_bone(obj, arm_obj, "halo")

    # 3. Torso / Tactical School Jacket
    chest = make_cyl("TorsoJacket", 0.118, 0.132, 0.25, jacket_mat, loc=(0, 0, 0.61), segs=22)
    chest.scale = (1.08, 0.78, 1.0)
    link_to_bone(chest, arm_obj, "spine")

    # Sleek flush Sailor Collar + Bow/Necktie Ribbon (no protruding block!)
    collar = make_cyl("Collar", 0.122, 0.088, 0.055, trim_mat, loc=(0, 0.0, 0.715), segs=20)
    collar.scale = (1.08, 0.84, 1.0)
    scarf_knot = make_box("RibbonKnot", (0.044, 0.026, 0.038), trim_mat, loc=(0, -0.104, 0.688), bevel=0.008)
    tie_l = make_box("RibbonTailL", (0.030, 0.016, 0.092), trim_mat, loc=(-0.020, -0.103, 0.635), rot=(math.radians(-6), math.radians(14), 0), bevel=0.005)
    tie_r = make_box("RibbonTailR", (0.030, 0.016, 0.092), trim_mat, loc=(0.020, -0.103, 0.635), rot=(math.radians(-6), math.radians(-14), 0), bevel=0.005)
    # Tactical chest harness / backpack
    pack = make_box("TacticalPack", (0.175, 0.095, 0.18), boot_mat, loc=(0, 0.122, 0.62), bevel=0.018)
    pack_trim = make_box("PackStrap", (0.182, 0.032, 0.042), trim_mat, loc=(0, 0.152, 0.64), bevel=0.006)
    for obj in (collar, scarf_knot, tie_l, tie_r, pack, pack_trim):
        link_to_bone(obj, arm_obj, "spine")

    # 4. Hips / Pleated Skirt or Tactical Shorts + Utility Belt
    belt = make_cyl("TacticalBelt", 0.136, 0.134, 0.045, boot_mat, loc=(0, 0, 0.495), segs=20)
    belt.scale = (1.06, 0.84, 1.0)
    buckle = make_box("BeltBuckle", (0.052, 0.035, 0.042), trim_mat, loc=(0, -0.116, 0.495), bevel=0.005)
    pouch_l = make_box("BeltPouchL", (0.056, 0.052, 0.068), boot_mat, loc=(-0.142, -0.02, 0.48), bevel=0.008)
    pouch_r = make_box("BeltPouchR", (0.056, 0.052, 0.068), boot_mat, loc=(0.142, -0.02, 0.48), bevel=0.008)

    if cfg["bottom_style"] == "skirt":
        skirt = make_cyl("PleatedSkirt", 0.195, 0.126, 0.21, skirt_mat, loc=(0, 0, 0.395), segs=24)
        skirt.scale = (1.06, 0.90, 1.0)
        hem = make_cyl("SkirtHem", 0.199, 0.186, 0.028, trim_mat, loc=(0, 0, 0.305), segs=24)
        hem.scale = (1.06, 0.90, 1.0)
        hip_parts = [belt, buckle, pouch_l, pouch_r, skirt, hem]
    else:
        pelvis = make_cyl("TacticalShortsBase", 0.142, 0.132, 0.13, skirt_mat, loc=(0, 0, 0.44), segs=20)
        pelvis.scale = (1.06, 0.88, 1.0)
        hip_parts = [belt, buckle, pouch_l, pouch_r, pelvis]

    for obj in hip_parts:
        link_to_bone(obj, arm_obj, "hips")

    # 5. Arms & Hands
    for side, sfx in [(-1, "l"), (1, "r")]:
        shoulder = make_capsule(f"UpperArm_{sfx}", 0.046, 0.175, jacket_mat, loc=(side * 0.182, 0.0, 0.625), rot=(0, math.radians(-side * 16), 0))
        cuff = make_cyl(f"Cuff_{sfx}", 0.048, 0.046, 0.032, trim_mat, loc=(side * 0.212, -0.015, 0.52), rot=(0, math.radians(-side * 8), 0))
        forearm = make_capsule(f"LowerArm_{sfx}", 0.038, 0.145, skin_mat, loc=(side * 0.215, -0.02, 0.485))
        hand = make_capsule(f"Hand_{sfx}", 0.036, 0.072, boot_mat, loc=(side * 0.22, -0.045, 0.415))
        link_to_bone(shoulder, arm_obj, f"upper_arm_{sfx}")
        link_to_bone(cuff, arm_obj, f"lower_arm_{sfx}")
        link_to_bone(forearm, arm_obj, f"lower_arm_{sfx}")
        link_to_bone(hand, arm_obj, f"lower_arm_{sfx}")

    # 6. Legs, Thigh-high Socks & Combat Boots
    for side, sfx in [(-1, "l"), (1, "r")]:
        lx = side * 0.088
        thigh_mat = skirt_mat if cfg["bottom_style"] == "shorts" else skin_mat
        thigh = make_capsule(f"Thigh_{sfx}", 0.058, 0.21, thigh_mat, loc=(lx, 0.0, 0.34))
        shin = make_capsule(f"Shin_{sfx}", 0.048, 0.19, sock_mat, loc=(lx, 0.0, 0.165))
        boot_shaft = make_cyl(f"BootShaft_{sfx}", 0.056, 0.054, 0.115, boot_mat, loc=(lx, 0.0, 0.085))
        boot_sole = make_box(f"BootFoot_{sfx}", (0.095, 0.165, 0.068), boot_mat, loc=(lx, -0.032, 0.036), bevel=0.016)
        link_to_bone(thigh, arm_obj, f"thigh_{sfx}")
        link_to_bone(shin, arm_obj, f"shin_{sfx}")
        link_to_bone(boot_shaft, arm_obj, f"shin_{sfx}")
        link_to_bone(boot_sole, arm_obj, f"shin_{sfx}")

    # 7. Firearm attached to weapon_r bone
    weapon_parts = build_weapon(cfg["weapon_type"], (0.22, -0.06, 0.42))
    for wobj in weapon_parts:
        link_to_bone(wobj, arm_obj, "weapon_r")


def reset_pose(arm_obj):
    for pb in arm_obj.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)


def key_all(arm_obj, frame):
    for pb in arm_obj.pose.bones:
        pb.keyframe_insert(data_path="location", frame=frame)
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def set_bone(arm_obj, name, rot_deg=(0, 0, 0), loc=(0, 0, 0)):
    pb = arm_obj.pose.bones[name]
    pb.rotation_euler = tuple(math.radians(a) for a in rot_deg)
    pb.location = loc


def push_action_to_nla(arm_obj, action):
    if not arm_obj.animation_data:
        arm_obj.animation_data_create()
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = action.name
    strip = track.strips.new(action.name, int(action.frame_range[0]), action)
    strip.name = action.name


def create_animations(arm_obj):
    """
    Author 5 clean skeletal animations using Blender pose-bone local axes:
      - Vertical bones (hips/spine/head/halo/legs/arms): local Y = axial twist/spin, local X = pitch fwd/back, local Z = lateral tilt.
      - Exported into GLB AnimationPlayer as: idle, walk, shoot, interact, roll.
    """
    bpy.context.scene.render.fps = 24
    if not arm_obj.animation_data:
        arm_obj.animation_data_create()

    # ------------------------------------------------------------------
    # 1. IDLE (breathing + weapon held ready in front + horizontal halo spin!)
    # ------------------------------------------------------------------
    act_idle = bpy.data.actions.new("idle")
    arm_obj.animation_data.action = act_idle
    for f, ph in [(1, 0.0), (11, 0.25), (21, 0.5), (31, 0.75), (41, 1.0)]:
        reset_pose(arm_obj)
        s = math.sin(ph * math.tau)
        set_bone(arm_obj, "hips", rot_deg=(0, 6, 0), loc=(0, s * 0.015, 0))
        set_bone(arm_obj, "spine", rot_deg=(2 + s * 1.5, -4, 0))
        set_bone(arm_obj, "head", rot_deg=(-2 - s * 1.0, -2, 0))
        set_bone(arm_obj, "halo", rot_deg=(0, ph * 360.0, 0), loc=(0, s * 0.022, 0))
        set_bone(arm_obj, "hair_back", rot_deg=(s * 4.0, 0, 0))
        # Downward arm bones: -X pitches arm FORWARD (-Y)!
        set_bone(arm_obj, "upper_arm_r", rot_deg=(-38, 0, -10))
        set_bone(arm_obj, "lower_arm_r", rot_deg=(-28, 0, -14))
        set_bone(arm_obj, "weapon_r", rot_deg=(58, 0, 18))
        set_bone(arm_obj, "upper_arm_l", rot_deg=(-44, 0, 22))
        set_bone(arm_obj, "lower_arm_l", rot_deg=(-32, 0, 18))
        set_bone(arm_obj, "thigh_l", rot_deg=(-4, 0, -3))
        set_bone(arm_obj, "thigh_r", rot_deg=(4, 0, 3))
        key_all(arm_obj, f)
    push_action_to_nla(arm_obj, act_idle)

    # ------------------------------------------------------------------
    # 2. WALK (energetic Blue Archive chibi tactical jog cycle)
    # ------------------------------------------------------------------
    act_walk = bpy.data.actions.new("walk")
    arm_obj.animation_data.action = act_walk
    for idx, f in enumerate([1, 7, 13, 19, 25]):
        ph = idx / 4.0
        sw = math.sin(ph * math.tau)
        bounce = abs(math.cos(ph * math.tau))
        reset_pose(arm_obj)
        set_bone(arm_obj, "hips", rot_deg=(-6, sw * 8, sw * 4), loc=(0, -0.02 + bounce * 0.048, 0))
        set_bone(arm_obj, "spine", rot_deg=(-9, -sw * 6, -sw * 2))
        set_bone(arm_obj, "head", rot_deg=(8, -sw * 2, 0))
        set_bone(arm_obj, "halo", rot_deg=(0, ph * 180.0, 0), loc=(0, bounce * 0.018, 0))
        set_bone(arm_obj, "hair_back", rot_deg=(16 + bounce * 14, 0, sw * 8))
        set_bone(arm_obj, "thigh_l", rot_deg=(-sw * 44, 0, 0))
        set_bone(arm_obj, "shin_l", rot_deg=(max(0.0, -sw) * 48 + 8, 0, 0))
        set_bone(arm_obj, "thigh_r", rot_deg=(sw * 44, 0, 0))
        set_bone(arm_obj, "shin_r", rot_deg=(max(0.0, sw) * 48 + 8, 0, 0))
        set_bone(arm_obj, "upper_arm_r", rot_deg=(-42 + sw * 12, 0, -12))
        set_bone(arm_obj, "lower_arm_r", rot_deg=(-30, 0, -14))
        set_bone(arm_obj, "weapon_r", rot_deg=(64, 0, 22))
        set_bone(arm_obj, "upper_arm_l", rot_deg=(-46 - sw * 14, 0, 22))
        set_bone(arm_obj, "lower_arm_l", rot_deg=(-34, 0, 16))
        key_all(arm_obj, f)
    push_action_to_nla(arm_obj, act_walk)

    # ------------------------------------------------------------------
    # 3. SHOOT (braced firing stance + firearm aimed straight forward -Y + recoil!)
    # ------------------------------------------------------------------
    act_shoot = bpy.data.actions.new("shoot")
    arm_obj.animation_data.action = act_shoot
    shoot_keys = [
        (1, 0.0),
        (3, 1.0),
        (6, 0.15),
        (9, 0.9),
        (13, 0.0),
    ]
    for f, kick in shoot_keys:
        reset_pose(arm_obj)
        set_bone(arm_obj, "hips", rot_deg=(-6, 14, 0), loc=(0, -0.04, kick * 0.022))
        set_bone(arm_obj, "spine", rot_deg=(-8 + kick * 7.0, -12, 0))
        set_bone(arm_obj, "head", rot_deg=(7 - kick * 2.5, -3, 0))
        set_bone(arm_obj, "halo", rot_deg=(0, 0, 0), loc=(0, kick * 0.016, 0))
        set_bone(arm_obj, "hair_back", rot_deg=(12 + kick * 10, 0, 0))
        set_bone(arm_obj, "thigh_l", rot_deg=(-24, 0, -6))
        set_bone(arm_obj, "shin_l", rot_deg=(26, 0, 0))
        set_bone(arm_obj, "thigh_r", rot_deg=(20, 0, 8))
        set_bone(arm_obj, "shin_r", rot_deg=(14, 0, 0))
        # Raise both arms straight forward (-X) & level barrel directly ahead (-Y)!
        set_bone(arm_obj, "upper_arm_r", rot_deg=(-78 - kick * 9, 0, -10))
        set_bone(arm_obj, "lower_arm_r", rot_deg=(-12 + kick * 3, 0, -6))
        set_bone(arm_obj, "weapon_r", rot_deg=(88 - kick * 10, 0, 12))
        set_bone(arm_obj, "upper_arm_l", rot_deg=(-78 - kick * 7, 0, 32))
        set_bone(arm_obj, "lower_arm_l", rot_deg=(-22, 0, 22))
        key_all(arm_obj, f)
    push_action_to_nla(arm_obj, act_shoot)

    # ------------------------------------------------------------------
    # 4. INTERACT ("摸東摸西" — crouched forward tinkering / lockpicking / crafting)
    # ------------------------------------------------------------------
    act_interact = bpy.data.actions.new("interact")
    arm_obj.animation_data.action = act_interact
    for idx, f in enumerate([1, 7, 13, 19, 25, 33]):
        ph = idx / 5.0
        w1 = math.sin(ph * math.tau * 2.0)
        w2 = math.cos(ph * math.tau * 2.0)
        reset_pose(arm_obj)
        set_bone(arm_obj, "hips", rot_deg=(-14, w1 * 5, 0), loc=(0, -0.14 + abs(w1) * 0.02, -0.04))
        set_bone(arm_obj, "spine", rot_deg=(-22 - w2 * 4, w1 * 6, 0))
        set_bone(arm_obj, "head", rot_deg=(16 - w1 * 5, w1 * 8, w2 * 6))
        set_bone(arm_obj, "halo", rot_deg=(0, ph * 360.0, 0), loc=(0, 0.015 * w2, 0))
        set_bone(arm_obj, "hair_back", rot_deg=(22 + abs(w1) * 8, 0, w2 * 6))
        set_bone(arm_obj, "thigh_l", rot_deg=(-58, 0, -10))
        set_bone(arm_obj, "shin_l", rot_deg=(70, 0, 0))
        set_bone(arm_obj, "thigh_r", rot_deg=(-52, 0, 10))
        set_bone(arm_obj, "shin_r", rot_deg=(66, 0, 0))
        # Both hands reaching forward in front of chest alternating ("摸東摸西"!)
        set_bone(arm_obj, "upper_arm_l", rot_deg=(-68 - w1 * 18, 0, 20 + w2 * 8))
        set_bone(arm_obj, "lower_arm_l", rot_deg=(-36 + w1 * 22, 0, 12))
        set_bone(arm_obj, "upper_arm_r", rot_deg=(-68 + w1 * 18, 0, -20 + w2 * 8))
        set_bone(arm_obj, "lower_arm_r", rot_deg=(-36 - w1 * 22, 0, -12))
        # Sling gun neatly back/down out of the way while hands work
        set_bone(arm_obj, "weapon_r", rot_deg=(-30, -85, -35), loc=(-0.16, 0.14, -0.14))
        key_all(arm_obj, f)
    push_action_to_nla(arm_obj, act_interact)

    # ------------------------------------------------------------------
    # 5. ROLL ("翻滾" — crisp tucked 360-degree forward tactical combat roll)
    # ------------------------------------------------------------------
    act_roll = bpy.data.actions.new("roll")
    arm_obj.animation_data.action = act_roll
    roll_frames = [
        (1, 0.0, 0.0, 0.0),
        (5, -90.0, 0.10, 1.0),
        (10, -180.0, 0.16, 1.0),
        (15, -270.0, 0.08, 0.9),
        (18, -345.0, -0.06, 0.4),
        (21, -360.0, 0.0, 0.0),
    ]
    for f, pitch_deg, y_lift, tuck in roll_frames:
        reset_pose(arm_obj)
        set_bone(arm_obj, "hips", rot_deg=(pitch_deg, 0, 0), loc=(0, -0.06 * (1.0 - tuck) + y_lift, 0))
        set_bone(arm_obj, "spine", rot_deg=(-tuck * 36, 0, 0))
        set_bone(arm_obj, "head", rot_deg=(-tuck * 26, 0, 0))
        set_bone(arm_obj, "halo", rot_deg=(0, pitch_deg, 0))
        set_bone(arm_obj, "hair_back", rot_deg=(tuck * 45, 0, 0))
        set_bone(arm_obj, "thigh_l", rot_deg=(-tuck * 92, 0, -6))
        set_bone(arm_obj, "shin_l", rot_deg=(tuck * 112, 0, 0))
        set_bone(arm_obj, "thigh_r", rot_deg=(-tuck * 88, 0, 6))
        set_bone(arm_obj, "shin_r", rot_deg=(tuck * 108, 0, 0))
        set_bone(arm_obj, "upper_arm_r", rot_deg=(-50 - tuck * 28, 0, -18))
        set_bone(arm_obj, "lower_arm_r", rot_deg=(-65 - tuck * 26, 0, -16))
        set_bone(arm_obj, "weapon_r", rot_deg=(68, 0, 18))
        set_bone(arm_obj, "upper_arm_l", rot_deg=(-56 - tuck * 32, 0, 24))
        set_bone(arm_obj, "lower_arm_l", rot_deg=(-62 - tuck * 26, 0, 18))
        key_all(arm_obj, f)
    push_action_to_nla(arm_obj, act_roll)

    arm_obj.animation_data.action = None


CHARACTERS = [
    {
        "id": "reina_ar",
        "name": "白羽 玲奈 (Reina)",
        "face_file": "face_reina.png",
        "skin_color": (253, 228, 212),
        "hair_color": (228, 236, 248),     # Silver-white anime hair
        "hair_accent": (126, 152, 188),
        "hair_style": "ponytail",
        "halo_color": (86, 220, 255),      # Ice-blue star halo
        "halo_style": "star",
        "jacket_color": (244, 248, 255),   # Crisp white tactical sailor blazer
        "shirt_color": (255, 255, 255),
        "skirt_color": (38, 56, 98),       # Deep navy pleated skirt
        "trim_color": (68, 168, 248),      # Blue Archive sky-blue accents
        "sock_color": (34, 42, 62),
        "boot_color": (46, 50, 60),
        "bottom_style": "skirt",
        "weapon_type": "ar",
    },
    {
        "id": "chisa_smg",
        "name": "蒼井 千紗 (Chisa)",
        "face_file": "face_chisa.png",
        "skin_color": (252, 226, 210),
        "hair_color": (36, 46, 76),        # Deep navy-black bob hair
        "hair_accent": (72, 82, 102),
        "hair_style": "bob",
        "halo_color": (255, 186, 66),      # Warm amber gear halo
        "halo_style": "gear",
        "jacket_color": (92, 104, 86),     # Tactical olive engineer vest
        "shirt_color": (246, 238, 224),
        "skirt_color": (54, 58, 68),       # Charcoal tactical shorts
        "trim_color": (242, 174, 58),      # Amber hazard/engineer trim
        "sock_color": (56, 62, 74),
        "boot_color": (86, 62, 46),        # Rugged engineer boots
        "bottom_style": "shorts",
        "weapon_type": "smg",
    },
    {
        "id": "lily_sg",
        "name": "星野 莉莉 (Lily)",
        "face_file": "face_lily.png",
        "skin_color": (253, 230, 215),
        "hair_color": (248, 206, 96),      # Warm golden twin-tails
        "hair_accent": (212, 62, 72),
        "hair_style": "twintails",
        "halo_color": (255, 76, 106),      # Crimson crosshair halo
        "halo_style": "crosshair",
        "jacket_color": (46, 42, 54),      # Black & crimson cropped academy jacket
        "shirt_color": (255, 246, 246),
        "skirt_color": (168, 38, 54),      # Crimson pleated skirt
        "trim_color": (236, 76, 92),       # Vibrant crimson accents
        "sock_color": (248, 246, 250),     # White knee-high socks
        "boot_color": (44, 34, 42),
        "bottom_style": "skirt",
        "weapon_type": "sg",
    },
]


def export_single_character(cfg):
    clear_scene()
    arm_obj = build_armature(cfg["id"])
    build_character_geometry(cfg, arm_obj)
    create_animations(arm_obj)

    out_path = os.path.join(OUT_DIR, f"{cfg['id']}.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_animations=True,
        export_nla_strips=True,
        export_force_sampling=True,
        export_yup=True,
    )
    print(f"[Chibi] Exported {cfg['name']} -> {out_path}")


def render_lineup_preview():
    """Import all 3 exported GLBs into a studio dusk scene and render a crisp preview PNG."""
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 28
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720

    # Dusk sky backdrop
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.16, 0.20, 0.30, 1.0)
    bg.inputs["Strength"].default_value = 0.9

    # Ground pad
    floor_mat = make_mat("PreviewFloor", (58, 62, 74), roughness=0.78)
    make_box("Floor", (10.0, 10.0, 0.1), floor_mat, (0, 0, -0.05))

    # Import all 3 characters side by side in distinct showcase poses!
    placements = [
        ("reina_ar.glb", -1.15, "shoot", 1),
        ("chisa_smg.glb", 0.0, "interact", 7),
        ("lily_sg.glb", 1.15, "walk", 7),
    ]
    for fname, px, pose_name, frame in placements:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(OUT_DIR, fname))
        added = [o for o in bpy.data.objects if o not in before]
        roots = [o for o in added if o.parent is None]
        for r in roots:
            r.location.x += px
        # Set preview pose from NLA/actions
        for o in added:
            if o.type == "ARMATURE":
                for act in bpy.data.actions:
                    if pose_name in act.name.lower() and o.animation_data:
                        # Check if action belongs to this import
                        pass
                if o.animation_data and o.animation_data.nla_tracks:
                    for tr in o.animation_data.nla_tracks:
                        tr.mute = (pose_name not in tr.name.lower())

    scene.frame_set(7)

    # Warm dusk key light + cool fill light + rim light
    def add_light(name, ltype, energy, color, loc, rot_deg):
        ld = bpy.data.lights.new(name=name, type=ltype)
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)
        return lo

    add_light("KeySun", "SUN", 3.6, (1.0, 0.84, 0.68), (3, -4, 5), (52, 0, 32))
    add_light("FillLight", "AREA", 120.0, (0.65, 0.80, 1.0), (-2.5, -3.5, 2.5), (65, 0, -35))
    add_light("RimLight", "AREA", 160.0, (1.0, 0.65, 0.35), (0.0, 3.0, 2.8), (-65, 0, 180))

    # Front 3/4 slightly elevated camera (clear face + silhouette check)
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = 50
    cam_o = bpy.data.objects.new("Cam", cam_d)
    bpy.context.collection.objects.link(cam_o)
    cam_o.location = (0.0, -4.3, 1.55)
    cam_o.rotation_euler = (math.radians(78), 0, 0)
    scene.camera = cam_o

    preview_path = os.path.join(PREVIEW_DIR, "characters_preview.png")
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[Preview] Rendered lineup -> {preview_path}")


def main():
    for cfg in CHARACTERS:
        export_single_character(cfg)
    render_lineup_preview()


if __name__ == "__main__":
    main()
