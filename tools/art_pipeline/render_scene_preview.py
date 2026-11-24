#!/usr/bin/env python3
"""
Renders a full LoL Fixed Top-Down (52 deg) Dusk Composite Preview of:
  - Kabaneri Armored Fortress Train Base
  - Girls' Frontline 2 Post-Apocalyptic Urban Ruins
  - All 3 Blue Archive Chibi Girls on the Plaza
Output: tools/art_pipeline/previews/scene_lol_preview.png
"""

import math
import os
import bpy
from mathutils import Vector

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS = os.path.join(ROOT_DIR, "assets", "models")
ENV_TEX = os.path.join(ROOT_DIR, "assets", "textures", "env")
PREVIEW_DIR = os.path.join(ROOT_DIR, "tools", "art_pipeline", "previews")
os.makedirs(PREVIEW_DIR, exist_ok=True)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(rel_path, loc=(0, 0, 0), rot_z_deg=0.0, scale=1.0, pose_name=None):
    full = os.path.join(MODELS, rel_path)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=full)
    added = [o for o in bpy.data.objects if o not in before]
    roots = [o for o in added if o.parent is None]
    for r in roots:
        r.location = (r.location.x + loc[0], r.location.y + loc[1], r.location.z + loc[2])
        r.rotation_euler.z += math.radians(rot_z_deg)
        r.scale = (r.scale.x * scale, r.scale.y * scale, r.scale.z * scale)
    if pose_name:
        for o in added:
            if o.type == "ARMATURE" and o.animation_data and o.animation_data.nla_tracks:
                for tr in o.animation_data.nla_tracks:
                    tr.mute = (pose_name not in tr.name.lower())


def main():
    clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720

    # Cinematic Dusk World
    world = bpy.data.worlds.new("DuskWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.20, 0.16, 0.24, 1.0)
    bg.inputs["Strength"].default_value = 0.75

    # Cracked Asphalt Ground
    bpy.ops.mesh.primitive_plane_add(size=120.0, location=(0, 0, 0))
    ground = bpy.context.active_object
    gmat = bpy.data.materials.new("GroundAsphalt")
    gmat.use_nodes = True
    nt = gmat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.90
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (14.0, 14.0, 1.0)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(ENV_TEX, "asphalt_cracked.png"))
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    ground.data.materials.append(gmat)

    # Note: In Blender Z-up, North is +Y (Godot -Z), South is -Y (Godot +Z)
    # 1. Kabaneri Armored Train Base along Y = +8.5
    import_glb("train/kabaneri_armored_train.glb", loc=(0.0, 8.5, 0.0))

    # 2. GFL2 Urban Ruins framing behind & flanking the plaza
    import_glb("ruins/building_ruin_a.glb", loc=(-16.0, 19.0, 0.0), rot_z_deg=-6.0, scale=1.2)
    import_glb("ruins/building_ruin_b.glb", loc=(-3.5, 20.0, 0.0), rot_z_deg=5.0, scale=1.25)
    import_glb("ruins/building_ruin_a.glb", loc=(11.0, 19.5, 0.0), rot_z_deg=175.0, scale=1.2)
    import_glb("ruins/overpass_pillar.glb", loc=(19.5, -1.5, 0.0), rot_z_deg=96.0, scale=1.1)
    import_glb("ruins/wrecked_car.glb", loc=(-11.0, -5.5, 0.0), rot_z_deg=-24.0)
    import_glb("ruins/wrecked_car.glb", loc=(11.5, -2.5, 0.0), rot_z_deg=140.0)
    import_glb("ruins/tactical_cover.glb", loc=(-7.5, -1.5, 0.0), rot_z_deg=-10.0)
    import_glb("ruins/tactical_cover.glb", loc=(6.2, -4.5, 0.0), rot_z_deg=-165.0)
    import_glb("ruins/supply_crate.glb", loc=(-5.8, -0.2, 0.0), rot_z_deg=15.0)
    import_glb("ruins/supply_crate.glb", loc=(3.8, -2.2, 0.0), rot_z_deg=-18.0)
    import_glb("ruins/streetlight_broken.glb", loc=(-10.5, 3.0, 0.0), rot_z_deg=-15.0)
    import_glb("ruins/streetlight_broken.glb", loc=(9.5, 3.0, 0.0), rot_z_deg=165.0)

    # 3. 3 Blue Archive Chibi Girls on the Plaza (scaled 1.25x for visual check!)
    import_glb("characters/reina_ar.glb", loc=(-1.2, -1.0, 0.0), rot_z_deg=22.0, scale=1.2, pose_name="shoot")
    import_glb("characters/chisa_smg.glb", loc=(-4.6, -0.4, 0.0), rot_z_deg=-40.0, scale=1.2, pose_name="interact")
    import_glb("characters/lily_sg.glb", loc=(2.4, -1.6, 0.0), rot_z_deg=-15.0, scale=1.2, pose_name="walk")

    scene.frame_set(7)

    # Dusk Sunset Key + Cool Twilight Fill + Warm Furnace & Workshop Point Lights
    def add_light(name, ltype, energy, color, loc, rot_deg=(0, 0, 0)):
        ld = bpy.data.lights.new(name=name, type=ltype)
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = tuple(math.radians(a) for a in rot_deg)

    add_light("DuskSun", "SUN", 4.5, (1.0, 0.65, 0.38), (20, -20, 22), (56, 0, 38))
    add_light("TwilightFill", "SUN", 1.2, (0.52, 0.68, 1.0), (-20, 20, 25), (42, 0, -140))
    add_light("FurnaceGlow", "POINT", 950.0, (1.0, 0.40, 0.10), (10.3, 5.2, 2.8))
    add_light("WorkshopGlow", "POINT", 650.0, (1.0, 0.72, 0.34), (-2.6, 5.8, 3.2))

    # Exact LoL Fixed 52-degree Top-Down Camera!
    cam_d = bpy.data.cameras.new("LolCam")
    cam_d.lens = 42
    cam_o = bpy.data.objects.new("LolCam", cam_d)
    bpy.context.collection.objects.link(cam_o)
    cam_o.location = (0.5, -18.5, 22.5)
    direction = Vector((0.5, 2.5, 1.0)) - cam_o.location
    cam_o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam_o

    out_path = os.path.join(PREVIEW_DIR, "scene_lol_preview.png")
    scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"[Preview] Rendered full LoL dusk scene -> {out_path}")


if __name__ == "__main__":
    main()
