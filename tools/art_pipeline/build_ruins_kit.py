#!/usr/bin/env python3
"""
Blender 4.x Headless Pipeline: Build Girls' Frontline 2 (少女前線 2：追放) Modular Post-Apocalyptic Urban Ruins Kit
Outputs:
  - assets/models/ruins/building_ruin_a.glb
  - assets/models/ruins/building_ruin_b.glb
  - assets/models/ruins/overpass_pillar.glb
  - assets/models/ruins/wrecked_car.glb
  - assets/models/ruins/tactical_cover.glb
  - assets/models/ruins/supply_crate.glb
  - assets/models/ruins/streetlight_broken.glb
"""

import math
import os
import random
import bpy
import bmesh
from mathutils import Vector

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT_DIR, "assets", "models", "ruins")
ENV_DIR = os.path.join(ROOT_DIR, "assets", "textures", "env")
os.makedirs(OUT_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c):
    return tuple(((v / 255.0) ** 2.2) for v in c)


def make_mat(name, rgb255, roughness=0.75, metallic=0.1, emission_rgb255=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    lin = srgb_to_linear(rgb255)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission_rgb255 is not None and emission_strength > 0.0:
        elin = srgb_to_linear(emission_rgb255)
        bsdf.inputs["Emission Color"].default_value = (elin[0], elin[1], elin[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def make_concrete_mat():
    mat = bpy.data.materials.new(name="RuinedConcrete")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.88
    bsdf.inputs["Metallic"].default_value = 0.04
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(os.path.join(ENV_DIR, "ruined_concrete.png"), check_existing=True)
    img.pack()
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def box_project_uv(bm, scale=0.22):
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for l in f.loops:
            v = l.vert.co
            if az >= ax and az >= ay:
                l[uv_layer].uv = (v.x * scale, v.y * scale)
            elif ax >= ay:
                l[uv_layer].uv = (v.y * scale, v.z * scale)
            else:
                l[uv_layer].uv = (v.x * scale, v.z * scale)


def create_obj(name, bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False, uv_scale=0.22):
    box_project_uv(bm, scale=uv_scale)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    obj.rotation_euler = rot
    if mat:
        obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def add_box(name, size, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.03):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    return create_obj(name, bm, mat, loc, rot)


def add_cyl(name, r1, r2, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), segs=14):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return create_obj(name, bm, mat, loc, rot, smooth=True)


def export_glb(filename):
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    print(f"[Ruins] Exported -> {path}")


def build_building_ruin_a():
    """Shattered Brutalist Concrete Office Building with hollow window bays, collapsed slab & exposed rebar."""
    clear_scene()
    conc = make_concrete_mat()
    dark_conc = make_mat("DarkConcrete", (58, 62, 70), roughness=0.92, metallic=0.0)
    rebar = make_mat("RustRebar", (112, 62, 42), roughness=0.72, metallic=0.65)
    glass_frame = make_mat("WindowFrame", (42, 48, 56), roughness=0.55, metallic=0.55)

    # Structural corner & mid pillars (3 stories, right side blasted lower)
    pillar_specs = [
        (-4.5, -3.0, 9.5),
        (-1.5, -3.0, 9.2),
        (1.5, -3.0, 7.6),
        (4.5, -3.0, 5.4),
        (-4.5, 3.0, 9.8),
        (0.0, 3.0, 8.8),
        (4.5, 3.0, 6.2),
    ]
    for i, (px, py, ph) in enumerate(pillar_specs):
        add_box(f"Pillar_{i}", (0.75, 0.75, ph), conc, (px, py, ph * 0.5))

    # Floor slabs (Ground, Floor 2, partial collapsed Floor 3)
    add_box("Floor_0", (9.8, 6.8, 0.45), dark_conc, (0, 0, 0.22))
    add_box("Floor_1", (9.6, 6.6, 0.42), conc, (0, 0, 3.4))
    add_box("Floor_2", (6.8, 6.4, 0.42), conc, (-1.4, 0, 6.6))
    # Collapsed tilted slab crashing down on the right side!
    add_box("CollapsedSlab", (4.2, 5.8, 0.42), conc, (3.2, -0.2, 4.1), (0.08, math.radians(32), -0.05))

    # Solid spandrel walls & broken facade walls (creating realistic hollow window bays!)
    add_box("BackWallLow", (9.4, 0.48, 6.6), conc, (0, 3.0, 3.3))
    add_box("BackWallTop", (5.8, 0.48, 3.2), conc, (-1.8, 3.0, 8.1))
    add_box("LeftWall", (0.48, 6.2, 9.2), conc, (-4.5, 0.0, 4.6))
    # Front waist-high parapets per floor
    add_box("FrontParapet_1", (9.2, 0.42, 1.1), conc, (0, -3.0, 3.95))
    add_box("FrontParapet_2", (6.4, 0.42, 1.05), conc, (-1.5, -3.0, 7.15))
    # Broken window mullions
    for wx in (-3.0, 0.0, 3.0):
        add_box(f"Mullion_{wx}", (0.14, 0.16, 2.2), glass_frame, (wx, -2.95, 2.0))
    # Exposed rusted rebar rods sticking out of broken upper floor & pillars!
    rng = random.Random(77)
    for k in range(14):
        rx = rng.uniform(1.6, 4.4)
        ry = rng.uniform(-2.6, 2.6)
        rz = rng.uniform(5.2, 7.2)
        add_cyl(
            f"Rebar_{k}",
            0.04,
            0.04,
            rng.uniform(1.2, 2.4),
            rebar,
            (rx, ry, rz),
            (rng.uniform(-0.4, 0.4), math.radians(rng.uniform(55, 115)), rng.uniform(-0.4, 0.4)),
            segs=6,
        )
    # Rubble chunks scattered at base
    for k in range(12):
        add_box(
            f"Rubble_{k}",
            (rng.uniform(0.5, 1.5), rng.uniform(0.5, 1.3), rng.uniform(0.35, 0.9)),
            dark_conc,
            (rng.uniform(-3.8, 4.8), rng.uniform(-3.9, 1.5), rng.uniform(0.2, 0.7)),
            (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, 3.14)),
            bevel=0.05,
        )
    export_glb("building_ruin_a.glb")


def build_building_ruin_b():
    """Collapsed Mid-Rise Corner Apartment Block with balconies, AC units & signage frame."""
    clear_scene()
    conc = make_concrete_mat()
    brick_tint = make_mat("WeatheredPlaster", (102, 96, 94), roughness=0.90, metallic=0.0)
    rust = make_mat("RustMetal", (108, 66, 48), roughness=0.72, metallic=0.58)
    dark = make_mat("DarkInterior", (36, 38, 44), roughness=0.95, metallic=0.0)

    add_box("CoreWallA", (7.2, 5.4, 6.2), brick_tint, (-0.5, 0.4, 3.1))
    add_box("CoreWallB", (4.6, 4.6, 8.4), conc, (-1.8, 0.8, 4.2))
    # Recessed dark window openings on front face
    for row_z in (2.2, 4.8):
        for col_x in (-2.8, -0.8, 1.2):
            add_box(f"Win_{row_z}_{col_x}", (1.15, 0.25, 1.45), dark, (col_x, -2.26, row_z), bevel=0.01)
    # Broken concrete balconies
    add_box("Balcony_1", (3.6, 1.25, 0.28), conc, (-1.2, -2.75, 3.65))
    add_box("BalconyRail_1", (3.6, 0.16, 0.85), rust, (-1.2, -3.3, 4.15))
    add_box("Balcony_2", (2.6, 1.15, 0.28), conc, (-1.8, -2.65, 6.45), (0.08, 0.12, 0))
    # Rusted AC outdoor units & rooftop billboard truss
    add_box("AC_1", (0.75, 0.42, 0.55), rust, (2.2, -2.45, 4.1))
    add_box("AC_2", (0.75, 0.42, 0.55), rust, (2.2, -2.45, 2.1))
    add_box("SignPostL", (0.22, 0.22, 2.8), rust, (-3.4, -0.8, 9.6))
    add_box("SignPostR", (0.22, 0.22, 2.8), rust, (-0.2, -0.8, 9.6))
    add_box("SignFrame", (3.8, 0.18, 1.45), rust, (-1.8, -0.8, 10.2), (0, 0.08, 0))
    export_glb("building_ruin_b.glb")


def build_overpass_pillar():
    """Massive cracked highway viaduct T-pier + shattered elevated road deck (GFL2 staple)."""
    clear_scene()
    conc = make_concrete_mat()
    asphalt = make_mat("RoadDeck", (50, 52, 58), roughness=0.92, metallic=0.0)
    rebar = make_mat("RustRebar", (112, 62, 42), roughness=0.72, metallic=0.65)

    # Massive fluted highway pier
    add_box("PierBase", (2.8, 2.6, 1.0), conc, (0, 0, 0.5))
    add_box("PierShaft", (2.1, 1.8, 6.4), conc, (0, 0, 3.9))
    add_box("PierCap", (7.4, 2.3, 1.15), conc, (0, 0, 7.4))
    # Broken elevated highway deck resting on T-pier (tilted slightly on broken edge!)
    add_box("DeckSlab", (9.2, 6.6, 0.72), conc, (0.4, 0, 8.25))
    add_box("DeckAsphalt", (9.0, 5.6, 0.14), asphalt, (0.4, 0, 8.64), bevel=0.01)
    for side in (-1, 1):
        add_box(f"Barrier_{side}", (9.1, 0.42, 0.85), conc, (0.4, side * 3.05, 8.95))
    # Jagged exposed steel rebar at broken end (+X)
    for k in range(8):
        add_cyl(f"DeckRebar_{k}", 0.05, 0.05, 1.8, rebar, (5.5, -2.2 + k * 0.62, 8.25), (0, math.radians(88), (k % 3 - 1) * 0.14), segs=6)
    export_glb("overpass_pillar.glb")


def build_wrecked_car():
    """Rusted post-apocalyptic abandoned SUV/sedan tactical wreck."""
    clear_scene()
    rust_body = make_mat("WreckBody", (96, 68, 56), roughness=0.78, metallic=0.35)
    char_dark = make_mat("CharDark", (34, 36, 40), roughness=0.88, metallic=0.25)
    tire_mat = make_mat("Tire", (26, 26, 28), roughness=0.92, metallic=0.0)

    # Slightly tilted wrecked chassis
    tilt = (math.radians(4), math.radians(-3), 0)
    add_box("CarLowerBody", (4.1, 1.85, 0.72), rust_body, (0, 0, 0.66), tilt, bevel=0.08)
    add_box("CarCabin", (2.05, 1.62, 0.68), rust_body, (-0.15, 0, 1.28), tilt, bevel=0.08)
    add_box("CarInterior", (1.85, 1.66, 0.48), char_dark, (-0.15, 0, 1.25), tilt, bevel=0.02)
    add_box("CarBumperF", (0.28, 1.88, 0.30), char_dark, (2.05, 0, 0.44), tilt, bevel=0.04)
    add_box("CarBumperR", (0.28, 1.88, 0.30), char_dark, (-2.05, 0, 0.46), tilt, bevel=0.04)
    # 4 Wheels
    for wx in (-1.25, 1.25):
        for wy in (-0.92, 0.92):
            add_cyl(f"Wheel_{wx}_{wy}", 0.38, 0.38, 0.26, tire_mat, (wx, wy, 0.38), (math.radians(90), 0, 0), segs=16)
    export_glb("wrecked_car.glb")


def build_tactical_cover():
    """Girls' Frontline 2 tactical cover cluster: chipped Jersey barrier + sandbags + rusted oil drum."""
    clear_scene()
    conc = make_concrete_mat()
    sandbag = make_mat("Sandbag", (142, 128, 98), roughness=0.92, metallic=0.0)
    barrel = make_mat("RustBarrel", (118, 52, 40), roughness=0.68, metallic=0.45)
    hazard = make_mat("BarrierHazard", (215, 162, 42), roughness=0.58, metallic=0.1)

    # Jersey concrete barrier
    add_box("BarrierBase", (2.6, 0.72, 0.45), conc, (0, 0, 0.22), bevel=0.04)
    add_box("BarrierTop", (2.6, 0.36, 0.65), conc, (0, 0, 0.72), bevel=0.04)
    add_box("BarrierStripe", (2.62, 0.38, 0.14), hazard, (0, 0, 0.88), bevel=0.01)
    # Stacked sandbags next to barrier
    for row in range(3):
        for col in range(3 - (row % 2)):
            add_box(
                f"Sandbag_{row}_{col}",
                (0.68, 0.38, 0.24),
                sandbag,
                (-1.65 - col * 0.64 + (row % 2) * 0.28, 0.12 + row * 0.04, 0.12 + row * 0.22),
                (0, 0, math.radians(-18 + col * 8)),
                bevel=0.08,
            )
    # Rusted oil drum
    add_cyl("OilDrum", 0.32, 0.32, 0.92, barrel, (1.68, 0.18, 0.46), segs=16)
    export_glb("tactical_cover.glb")


def build_supply_crate():
    """Interactive Salvage / Lockbox Supply Crate with glowing cyan status latch (for '摸東摸西'!)."""
    clear_scene()
    olive = make_mat("CrateOlive", (76, 88, 68), roughness=0.62, metallic=0.25)
    dark = make_mat("CrateFrame", (42, 46, 52), roughness=0.5, metallic=0.65)
    yellow = make_mat("CrateYellow", (236, 182, 48), roughness=0.45, metallic=0.2)
    cyan_glow = make_mat("CrateBeacon", (68, 232, 255), roughness=0.2, emission_rgb255=(58, 226, 255), emission_strength=4.5)

    add_box("CrateBody", (1.28, 0.86, 0.68), olive, (0, 0, 0.36), bevel=0.04)
    add_box("CrateLid", (1.34, 0.92, 0.16), dark, (0, 0, 0.74), bevel=0.03)
    for sx in (-0.42, 0.42):
        add_box(f"CrateLatch_{sx}", (0.14, 0.96, 0.26), yellow, (sx, 0, 0.64), bevel=0.02)
    # Glowing lockpad panel on front (-Y) & top beacon
    add_box("LockPad", (0.34, 0.08, 0.24), cyan_glow, (0, -0.45, 0.46), bevel=0.01)
    add_cyl("TopBeacon", 0.08, 0.08, 0.12, cyan_glow, (0.45, 0.25, 0.86), segs=12)
    export_glb("supply_crate.glb")


def build_streetlight_broken():
    """Bent post-apocalyptic urban streetlight pole."""
    clear_scene()
    pole = make_mat("PoleMetal", (68, 72, 78), roughness=0.62, metallic=0.68)
    conc = make_concrete_mat()
    lamp_glass = make_mat("LampWarm", (255, 205, 132), roughness=0.2, emission_rgb255=(255, 186, 98), emission_strength=2.2)

    add_cyl("PoleBase", 0.34, 0.24, 0.55, conc, (0, 0, 0.27), segs=10)
    add_cyl("PoleLower", 0.11, 0.09, 3.2, pole, (0, 0, 2.0), (0, math.radians(6), 0), segs=10)
    add_cyl("PoleUpper", 0.09, 0.07, 2.8, pole, (0.36, 0, 4.85), (0, math.radians(18), 0), segs=10)
    add_cyl("LampArm", 0.055, 0.055, 1.5, pole, (1.42, 0, 6.08), (0, math.radians(82), 0), segs=8)
    add_box("LampHead", (0.65, 0.30, 0.18), pole, (2.15, 0, 6.12), (0, math.radians(12), 0), bevel=0.03)
    add_box("LampLens", (0.52, 0.22, 0.06), lamp_glass, (2.15, 0, 6.02), (0, math.radians(12), 0), bevel=0.01)
    export_glb("streetlight_broken.glb")


def main():
    build_building_ruin_a()
    build_building_ruin_b()
    build_overpass_pillar()
    build_wrecked_car()
    build_tactical_cover()
    build_supply_crate()
    build_streetlight_broken()


if __name__ == "__main__":
    main()
