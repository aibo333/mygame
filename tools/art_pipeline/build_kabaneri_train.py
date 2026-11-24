#!/usr/bin/env python3
"""
Blender 4.x Headless Pipeline: Build Kabaneri of the Iron Fortress (甲鐵城) Inspired Armored Base Train
Outputs:
  - assets/models/train/kabaneri_armored_train.glb
  - tools/art_pipeline/previews/train_preview.png
"""

import math
import os
import bpy
import bmesh
from mathutils import Vector

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT_DIR, "assets", "models", "train")
ENV_DIR = os.path.join(ROOT_DIR, "assets", "textures", "env")
PREVIEW_DIR = os.path.join(ROOT_DIR, "tools", "art_pipeline", "previews")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PREVIEW_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c):
    return tuple(((v / 255.0) ** 2.2) for v in c)


def make_mat(name, rgb255, roughness=0.55, metallic=0.45, emission_rgb255=None, emission_strength=0.0):
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


def make_textured_mat(name, tex_path, roughness=0.52, metallic=0.62, uv_scale=1.0, emissive_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic

    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
    tex = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(tex_path, check_existing=True)
    img.pack()
    tex.image = img

    nt.links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emissive_strength > 0.0:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emissive_strength
    return mat


def box_project_uv(bm, scale=0.35):
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


def create_obj(name, bm, mat, loc=(0, 0, 0), rot=(0, 0, 0), smooth=False, uv_scale=0.32):
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


def add_box(name, size, mat, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.04, uv_scale=0.3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    return create_obj(name, bm, mat, loc, rot, smooth=False, uv_scale=uv_scale)


def add_cyl(name, r1, r2, depth, mat, loc=(0, 0, 0), rot=(0, 0, 0), segs=20):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return create_obj(name, bm, mat, loc, rot, smooth=True)


def add_wedge(name, length, width, height, mat, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Build a pointed armored train ram-plow wedge pointing toward +X."""
    bm = bmesh.new()
    hl = length * 0.5
    hw = width * 0.5
    hh = height * 0.5
    # Back rectangle at -hl, pointed prow at +hl
    v_bl_d = bm.verts.new((-hl, -hw, -hh))
    v_br_d = bm.verts.new((-hl, hw, -hh))
    v_bl_u = bm.verts.new((-hl, -hw * 0.78, hh))
    v_br_u = bm.verts.new((-hl, hw * 0.78, hh))
    v_tip_d = bm.verts.new((hl, 0.0, -hh))
    v_tip_u = bm.verts.new((hl * 0.65, 0.0, hh * 0.62))

    bm.faces.new((v_bl_d, v_tip_d, v_tip_u, v_bl_u))
    bm.faces.new((v_tip_d, v_br_d, v_br_u, v_tip_u))
    bm.faces.new((v_bl_u, v_tip_u, v_br_u))
    bm.faces.new((v_bl_d, v_br_d, v_tip_d))
    bm.faces.new((v_bl_d, v_bl_u, v_br_u, v_br_d))
    return create_obj(name, bm, mat, loc, rot, smooth=False, uv_scale=0.35)


def add_bogie_wheels(prefix, cx, num_axles, axle_spacing, wheel_r, dark_iron, brass):
    """Build heavy iron train bogie frame + spoked wheels + side connecting rod."""
    objs = []
    span = (num_axles - 1) * axle_spacing + 1.2
    # Undercarriage frame
    objs.append(add_box(f"{prefix}_Frame", (span, 3.1, 0.42), dark_iron, (cx, 0, 0.62), bevel=0.03))
    for i in range(num_axles):
        ax = cx - ((num_axles - 1) * 0.5 - i) * axle_spacing
        # Axle shaft
        objs.append(add_cyl(f"{prefix}_Axle_{i}", 0.14, 0.14, 3.45, dark_iron, (ax, 0, wheel_r), (math.radians(90), 0, 0), segs=12))
        for side in (-1, 1):
            objs.append(add_cyl(f"{prefix}_Wheel_{i}_{side}", wheel_r, wheel_r, 0.24, dark_iron, (ax, side * 1.56, wheel_r), (math.radians(90), 0, 0), segs=20))
            objs.append(add_cyl(f"{prefix}_Hub_{i}_{side}", wheel_r * 0.45, wheel_r * 0.45, 0.30, brass, (ax, side * 1.58, wheel_r), (math.radians(90), 0, 0), segs=14))
    # Connecting drive rod on both sides
    for side in (-1, 1):
        objs.append(add_box(f"{prefix}_Rod_{side}", (span - 0.5, 0.12, 0.18), brass, (cx, side * 1.72, wheel_r - 0.12), bevel=0.02))
    return objs


def build_kabaneri_train():
    """
    Construct the full Kabaneri of the Iron Fortress inspired Armored Base Train.
    Orientation: Train nose points toward +X, rails run along X, front plaza faces -Y (Godot +Z).
    """
    steel_mat = make_textured_mat("ArmorSteel", os.path.join(ENV_DIR, "train_armor_steel.png"), roughness=0.46, metallic=0.68)
    furnace_mat = make_textured_mat("FurnaceGlow", os.path.join(ENV_DIR, "train_furnace_glow.png"), roughness=0.3, metallic=0.1, emissive_strength=4.2)
    dark_iron = make_mat("DarkIron", (38, 42, 48), roughness=0.52, metallic=0.78)
    crimson_armor = make_mat("CrimsonLacquer", (142, 32, 36), roughness=0.42, metallic=0.38)
    brass_mat = make_mat("SteamBrass", (188, 146, 76), roughness=0.34, metallic=0.85)
    headlight_mat = make_mat("HeadlightGlow", (255, 240, 198), roughness=0.1, emission_rgb255=(255, 226, 156), emission_strength=6.5)
    amber_window = make_mat("AmberWindow", (255, 168, 56), roughness=0.15, emission_rgb255=(255, 152, 42), emission_strength=3.8)
    console_cyan = make_mat("ConsoleCyan", (64, 218, 255), roughness=0.2, emission_rgb255=(56, 210, 255), emission_strength=3.2)
    hazard_yellow = make_mat("HazardYellow", (222, 168, 42), roughness=0.5, metallic=0.15)
    sandbag_mat = make_mat("SandbagKhaki", (142, 128, 98), roughness=0.88, metallic=0.0)
    crate_mat = make_mat("MilitaryCrate", (88, 98, 76), roughness=0.68, metallic=0.15)

    # ==================================================================
    # 1. HEAVY LOCOMOTIVE ("甲鐵城" Armored Steam Engine, X = +4.2..+16.0)
    # ==================================================================
    # Main armored chassis & heavy boiler spine
    add_box("Loco_Chassis", (10.2, 4.1, 0.95), dark_iron, (9.2, 0.0, 1.25), bevel=0.05)
    add_bogie_wheels("LocoBogieFront", 11.4, 3, 1.55, 0.68, dark_iron, brass_mat)
    add_bogie_wheels("LocoBogieRear", 6.4, 2, 1.65, 0.62, dark_iron, brass_mat)

    # Iconic Kabaneri Sloped Armored Wedge Ram-Plow (破障排障器)
    add_wedge("Loco_RamPlow", 3.6, 4.6, 2.2, steel_mat, (15.1, 0.0, 1.45))
    add_wedge("Loco_RamPlowCrest", 2.9, 3.6, 1.35, crimson_armor, (14.4, 0.0, 2.65))
    # Heavy reinforcing ribs + steel teeth on the prow
    for z_rib in (0.75, 1.35, 1.95):
        add_box(f"PlowRib_{z_rib:.2f}", (2.4, 4.35, 0.16), dark_iron, (14.1, 0.0, z_rib), bevel=0.02)
    add_box("PlowHazardBand", (0.5, 4.48, 0.32), hazard_yellow, (13.3, 0.0, 1.05), bevel=0.02)

    # Cylindrical Armored Steam Boiler Drum + Brass Boiler Bands
    add_cyl("Loco_BoilerDrum", 1.68, 1.68, 7.6, steel_mat, (10.2, 0.0, 3.25), (0, math.radians(90), 0), segs=24)
    for bx in (7.4, 9.0, 10.6, 12.2, 13.5):
        add_cyl(f"BoilerBand_{bx:.1f}", 1.75, 1.75, 0.22, brass_mat, (bx, 0.0, 3.25), (0, math.radians(90), 0), segs=24)

    # Sloped Side Armor Skirts (Samurai-industrial layered plates)
    for side in (-1, 1):
        add_box(f"Loco_SideSkirt_{side}", (9.4, 0.38, 1.35), crimson_armor, (9.4, side * 2.15, 1.72), (math.radians(side * 12), 0, 0), bevel=0.04)
        add_box(f"Loco_UpperArmor_{side}", (8.2, 0.35, 0.95), steel_mat, (9.7, side * 1.88, 3.65), (math.radians(-side * 18), 0, 0), bevel=0.04)
        # Iconic Glowing Kabaneri Steam Furnace Core vents proudly visible along both sides!
        add_box(f"Loco_FurnaceCore_{side}", (4.8, 0.24, 0.86), furnace_mat, (10.3, side * 2.14, 2.75), bevel=0.02)
        for rib_i in range(6):
            add_box(f"Loco_FurnaceRib_{side}_{rib_i}", (0.14, 0.34, 0.92), dark_iron, (8.3 + rib_i * 0.80, side * 2.18, 2.75), bevel=0.02)
        # External copper/brass high-pressure steam pipes
        add_cyl(f"Loco_SteamPipe_{side}", 0.13, 0.13, 7.2, brass_mat, (9.8, side * 2.28, 3.25), (0, math.radians(90), 0), segs=12)
        add_cyl(f"Loco_SteamPipeLow_{side}", 0.10, 0.10, 6.4, brass_mat, (9.6, side * 2.34, 1.45), (0, math.radians(90), 0), segs=12)

    # Twin Towering Armored Smokestacks (煙囪)
    for sx, sh in [(12.3, 1.85), (10.4, 1.45)]:
        add_cyl(f"Smokestack_{sx:.1f}", 0.56, 0.46, sh, dark_iron, (sx, 0.0, 4.9 + sh * 0.35), segs=16)
        add_cyl(f"SmokestackRim_{sx:.1f}", 0.64, 0.58, 0.24, brass_mat, (sx, 0.0, 4.9 + sh * 0.85), segs=16)

    # Armored Locomotive Cab / Command Bridge (X = 4.6..7.6)
    add_box("Loco_CabBody", (3.4, 4.25, 3.45), steel_mat, (6.0, 0.0, 3.35), bevel=0.06)
    add_box("Loco_CabRoof", (3.7, 4.45, 0.45), crimson_armor, (6.0, 0.0, 5.22), bevel=0.06)
    # Narrow glowing armored bridge slit windows
    add_box("CabWindowFront", (0.18, 2.8, 0.42), amber_window, (7.72, 0.0, 4.35), bevel=0.01)
    for side in (-1, 1):
        add_box(f"CabWindowSide_{side}", (1.8, 0.18, 0.42), amber_window, (6.0, side * 2.12, 4.35), bevel=0.01)

    # Dual High-Intensity Locomotive Headlights
    for side in (-1, 1):
        add_cyl(f"HeadlightPod_{side}", 0.42, 0.36, 0.55, dark_iron, (13.9, side * 1.15, 3.45), (0, math.radians(90), 0), segs=16)
        add_cyl(f"HeadlightLens_{side}", 0.33, 0.33, 0.10, headlight_mat, (14.18, side * 1.15, 3.45), (0, math.radians(90), 0), segs=16)
    # Center Cyclops Top Searchlight
    add_cyl("CenterLampPod", 0.52, 0.46, 0.65, brass_mat, (13.6, 0.0, 4.55), (0, math.radians(90), 0), segs=18)
    add_cyl("CenterLampLens", 0.42, 0.42, 0.10, headlight_mat, (13.92, 0.0, 4.55), (0, math.radians(90), 0), segs=18)

    # Roof Heavy Rotary Twin-Autocannon Defense Turret on Cab
    add_cyl("TurretBase", 1.12, 1.25, 0.42, dark_iron, (6.0, 0.0, 5.58), segs=18)
    add_box("TurretHousing", (1.85, 1.45, 0.88), steel_mat, (6.0, 0.0, 6.12), (0, 0, math.radians(-22)), bevel=0.06)
    add_box("TurretStripe", (1.92, 0.35, 0.92), crimson_armor, (6.0, 0.0, 6.14), (0, 0, math.radians(-22)), bevel=0.03)
    for side in (-1, 1):
        add_cyl(
            f"TurretBarrel_{side}",
            0.11,
            0.09,
            2.4,
            dark_iron,
            (7.35 + side * 0.14, -0.55 + side * 0.34, 6.18),
            (0, math.radians(84), math.radians(-22)),
            segs=12,
        )

    # Heavy Armored Coupler Link (Loco <-> Base Car)
    add_box("Coupler_1", (1.4, 1.8, 1.1), dark_iron, (3.9, 0.0, 1.55), bevel=0.04)

    # ==================================================================
    # 2. MOBILE BASE & WORKSHOP CAR (基地主車廂, X = -8.5..+3.3)
    # ==================================================================
    add_box("BaseCar_Chassis", (11.8, 4.2, 0.85), dark_iron, (-2.6, 0.0, 1.22), bevel=0.05)
    add_bogie_wheels("BaseBogieFront", 1.2, 2, 1.6, 0.58, dark_iron, brass_mat)
    add_bogie_wheels("BaseBogieRear", -6.4, 2, 1.6, 0.58, dark_iron, brass_mat)

    # Armored Carriage Hull (left & right end sections + recessed open southern workshop bay facing -Y!)
    add_box("BaseCar_LeftSection", (3.6, 4.35, 3.15), steel_mat, (-6.7, 0.0, 3.18), bevel=0.06)
    add_box("BaseCar_RightSection", (3.6, 4.35, 3.15), steel_mat, (1.5, 0.0, 3.18), bevel=0.06)
    add_box("BaseCar_BackWall", (5.2, 0.55, 3.15), steel_mat, (-2.6, 1.90, 3.18), bevel=0.04)
    add_box("BaseCar_Roof", (12.1, 4.55, 0.45), steel_mat, (-2.6, 0.0, 4.92), bevel=0.06)
    add_box("BaseCar_CrimsonBand", (12.0, 4.44, 0.42), crimson_armor, (-2.6, 0.0, 4.55), bevel=0.03)

    # Open Workshop Bay Interior (facing -Y toward the squad plaza!)
    add_box("WorkshopFloor", (4.8, 3.6, 0.16), dark_iron, (-2.6, -0.1, 1.68), bevel=0.02)
    add_box("WorkshopCeilingGlow", (4.2, 1.8, 0.14), amber_window, (-2.6, 0.1, 4.62), bevel=0.01)
    # Tactical Workbench + Glowing Blue Tactical Consoles inside Base Bay
    add_box("Workbench", (3.4, 0.95, 0.88), dark_iron, (-2.6, 1.05, 2.15), bevel=0.03)
    add_box("ConsoleScreen_1", (1.25, 0.12, 0.72), console_cyan, (-3.4, 1.45, 3.05), bevel=0.01)
    add_box("ConsoleScreen_2", (1.25, 0.12, 0.72), console_cyan, (-1.8, 1.45, 3.05), bevel=0.01)
    # Deployable Armored Boarding Ramp extending cleanly from bay floor (y=-1.9, z=1.65) down to plaza (y=-4.6, z=0.08)!
    add_box("BoardingRamp", (4.4, 3.15, 0.18), steel_mat, (-2.6, -3.25, 0.86), (math.radians(30), 0, 0), bevel=0.03)
    add_box("RampStripeL", (0.28, 3.18, 0.21), hazard_yellow, (-4.55, -3.25, 0.87), (math.radians(30), 0, 0), bevel=0.01)
    add_box("RampStripeR", (0.28, 3.18, 0.21), hazard_yellow, (-0.65, -3.25, 0.87), (math.radians(30), 0, 0), bevel=0.01)

    # Armored Side Windows & Sloped Skirts on Base Car
    for sx in (-6.7, 1.5):
        for side in (-1, 1):
            add_box(f"BaseWindow_{sx:.1f}_{side}", (1.9, 0.16, 0.55), amber_window, (sx, side * 2.18, 3.55), bevel=0.01)
            add_box(f"BaseArmorPlate_{sx:.1f}_{side}", (3.2, 0.28, 1.25), crimson_armor, (sx, side * 2.22, 2.15), bevel=0.04)

    # Roof Fortified Observation Deck: Sandbags, Comms Mast & Radar Dish
    for k in range(5):
        add_box(f"RoofSandbag_{k}", (0.85, 0.42, 0.36), sandbag_mat, (-4.4 + k * 0.9, -1.95, 5.32), bevel=0.09)
    add_cyl("CommsMast", 0.10, 0.06, 3.2, dark_iron, (-6.6, 0.8, 6.65), segs=10)
    add_cyl("RadarDish", 0.95, 0.18, 0.32, steel_mat, (-6.6, 0.65, 7.65), (math.radians(65), 0, math.radians(-25)), segs=18)
    add_cyl("RadarBeacon", 0.16, 0.16, 0.22, console_cyan, (-6.6, 0.8, 8.32), segs=12)

    # Coupler 2 (Base Car <-> Tail Defense Car)
    add_box("Coupler_2", (1.2, 1.7, 1.0), dark_iron, (-9.0, 0.0, 1.50), bevel=0.04)

    # ==================================================================
    # 3. TAIL SUPPLY & DEFENSE FLATBED CAR (尾節防禦平台, X = -17.6..-9.6)
    # ==================================================================
    add_box("TailCar_Chassis", (8.0, 4.15, 0.92), dark_iron, (-13.6, 0.0, 1.25), bevel=0.05)
    add_bogie_wheels("TailBogieFront", -11.2, 2, 1.5, 0.56, dark_iron, brass_mat)
    add_bogie_wheels("TailBogieRear", -16.0, 2, 1.5, 0.56, dark_iron, brass_mat)
    # Armored waist-high parapet walls around flatbed
    for side in (-1, 1):
        add_box(f"TailWall_{side}", (7.8, 0.32, 1.15), steel_mat, (-13.6, side * 1.98, 2.25), bevel=0.04)
    add_box("TailRearShield", (0.45, 4.25, 1.65), crimson_armor, (-17.55, 0.0, 2.45), bevel=0.05)
    # Cargo crates & armored fuel barrels on flatbed
    add_box("CargoCrate_1", (1.6, 1.3, 1.2), crate_mat, (-11.6, 0.6, 2.3), bevel=0.04)
    add_box("CargoCrate_2", (1.4, 1.2, 1.0), crate_mat, (-11.4, -0.75, 2.2), (0, 0, 0.15), bevel=0.04)
    add_cyl("FuelTank_1", 0.58, 0.58, 2.6, brass_mat, (-14.8, 0.75, 2.35), (0, math.radians(90), 0), segs=16)
    add_cyl("FuelTank_2", 0.58, 0.58, 2.6, crimson_armor, (-14.8, -0.75, 2.35), (0, math.radians(90), 0), segs=16)
    # Rear red warning beacons
    for side in (-1, 1):
        add_cyl(f"TailLight_{side}", 0.24, 0.24, 0.22, furnace_mat, (-17.8, side * 1.45, 2.85), (0, math.radians(90), 0), segs=12)

    # ==================================================================
    # 4. INTEGRATED HEAVY IRON RAIL TRACK BED UNDER TRAIN
    # ==================================================================
    for side in (-1, 1):
        add_box(f"Rail_{side}", (42.0, 0.18, 0.20), dark_iron, (-1.0, side * 1.56, 0.10), bevel=0.01)
    for tx in range(-21, 21, 1):
        add_box(f"Sleeper_{tx}", (0.34, 4.1, 0.14), make_mat(f"Wood_{tx}", (56, 46, 38), roughness=0.9, metallic=0.0) if tx == -21 else bpy.data.materials["Wood_-21"], (float(tx), 0.0, 0.05), bevel=0.01)


def export_and_preview():
    clear_scene()
    build_kabaneri_train()

    out_path = os.path.join(OUT_DIR, "kabaneri_armored_train.glb")
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_yup=True,
    )
    print(f"[Train] Exported Kabaneri Armored Train -> {out_path}")

    # Render dusk LoL-angle preview framing the FULL armored locomotive prow + furnace + base car!
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720

    world = bpy.data.worlds.new("TrainWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.12, 0.14, 0.22, 1.0)
    bg.inputs["Strength"].default_value = 0.7

    floor_mat = make_mat("GroundAsphalt", (48, 50, 58), roughness=0.88, metallic=0.0)
    add_box("PreviewGround", (70.0, 50.0, 0.2), floor_mat, (0, 0, -0.1), bevel=0.0)

    def add_light(name, ltype, energy, color, loc, rot_deg):
        ld = bpy.data.lights.new(name=name, type=ltype)
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)
        return lo

    add_light("DuskSun", "SUN", 4.2, (1.0, 0.66, 0.40), (15, -20, 18), (58, 0, 38))
    add_light("SkyFill", "SUN", 1.1, (0.55, 0.70, 1.0), (-15, 20, 22), (45, 0, -140))
    add_light("WorkshopGlow", "POINT", 450.0, (1.0, 0.68, 0.30), (-2.6, -2.5, 3.2), (0, 0, 0))
    add_light("FurnaceGlowLight", "POINT", 650.0, (1.0, 0.42, 0.12), (10.3, -3.2, 2.7), (0, 0, 0))

    cam_d = bpy.data.cameras.new("TrainCam")
    cam_d.lens = 36
    cam_o = bpy.data.objects.new("TrainCam", cam_d)
    bpy.context.collection.objects.link(cam_o)
    cam_o.location = (18.5, -28.0, 16.0)
    direction = Vector((2.5, 0.0, 2.2)) - cam_o.location
    cam_o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_o

    preview_path = os.path.join(PREVIEW_DIR, "train_preview.png")
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"[Preview] Rendered train -> {preview_path}")


if __name__ == "__main__":
    export_and_preview()
