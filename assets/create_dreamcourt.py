"""Build the original Moonlight Rally arena and export it for Godot.

Run with:
  blender --background --python assets/create_dreamcourt.py

The generated mesh uses Blender's built-in primitives and materials; no external
asset library is required.
"""

import bpy
import math
import os
import random
from mathutils import Vector

random.seed(23)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSET_DIR = os.path.join(ROOT, "assets")
SOURCE_DIR = os.path.join(ROOT, "source_art")
os.makedirs(ASSET_DIR, exist_ok=True)
os.makedirs(SOURCE_DIR, exist_ok=True)


def rgb(hex_color):
    value = hex_color.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def material(name, color, metallic=0.0, roughness=0.48, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb(color), 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb(color), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb(color), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


INK = material("Midnight enamel", "12182B", metallic=0.22, roughness=0.32)
STONE = material("Blue slate", "252D48", metallic=0.12, roughness=0.68)
WALL = material("Dream hall velvet", "30314C", roughness=0.82)
COURT = material("Moonlit court", "287D82", metallic=0.18, roughness=0.33)
COURT_ALT = material("Court inlay", "3F9992", metallic=0.14, roughness=0.35)
GOLD = material("Warm brass", "E9B96D", metallic=0.72, roughness=0.27, emission=0.12)
GOLD_LIGHT = material("Lantern glow", "FFD89A", metallic=0.08, roughness=0.25, emission=1.4)
MINT = material("Sea glass", "78D9C4", metallic=0.12, roughness=0.31, emission=0.16)
CREAM = material("Warm ivory", "F5E8CE", roughness=0.56)
CORAL = material("Coral team", "F28E80", roughness=0.43)
LAVENDER = material("Lilac team", "9587E8", roughness=0.4)
BALL_MAT = material("Pearl volleyball", "FFF2D7", metallic=0.08, roughness=0.3)
BALL_SEAM = material("Ball seam ink", "766083", metallic=0.16, roughness=0.34)
WINDOW = material("Window at midnight", "142739", metallic=0.1, roughness=0.24, emission=0.22)


def assign(obj, mat):
    if mat:
        obj.data.materials.append(mat)
    return obj


def cube(name, location, dimensions, mat, bevel=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    if bevel:
        mod = obj.modifiers.new("Soft caught light", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def sphere(name, location, scale, mat, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def cylinder(name, a, b, radius, mat, vertices=16):
    a, b = Vector(a), Vector(b)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=direction.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    assign(obj, mat)
    bevel = obj.modifiers.new("Rounded highlights", "BEVEL")
    bevel.width = min(radius * 0.18, 0.035)
    bevel.segments = 2
    obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj


def curve_line(name, points, mat, radius=0.025, cyclic=False):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.resolution_u = 1
    data.bevel_depth = radius
    data.bevel_resolution = 2
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def text_object(name, text, location, size, mat, rotation=(math.pi / 2, 0, 0)):
    bpy.ops.object.text_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.body = text
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.size = size
    obj.data.extrude = 0.012
    obj.data.bevel_depth = 0.004
    assign(obj, mat)
    return obj


def avatar(name, x, y, jacket, facing=1):
    # Small, readable dream-sports characters built entirely from mesh primitives.
    sphere(f"{name} / soft shadow", (x, y, 0.16), (0.56, 0.4, 0.12), INK)
    cube(f"{name} / jersey", (x, y, 0.92), (0.68, 0.42, 0.88), jacket, bevel=0.18)
    sphere(f"{name} / hood", (x, y + 0.02, 1.73), (0.43, 0.4, 0.43), CREAM)
    # Pointed hood ears make the mascots distinct without borrowing a known character.
    for side in (-1, 1):
        ear = sphere(f"{name} / hood ear", (x + side * 0.28, y + 0.01, 2.07), (0.15, 0.15, 0.34), jacket, 16, 12)
        ear.rotation_euler[1] = -side * 0.22
    for side in (-1, 1):
        sphere(f"{name} / eye", (x + side * 0.13 * facing, y - 0.352, 1.78), (0.055, 0.035, 0.075), INK, 12, 8)
    cylinder(f"{name} / left arm", (x - 0.27, y, 1.15), (x - 0.68, y - 0.14, 1.46), 0.12, jacket)
    cylinder(f"{name} / right arm", (x + 0.27, y, 1.15), (x + 0.62, y - 0.12, 1.42), 0.12, jacket)
    sphere(f"{name} / left mitt", (x - 0.68, y - 0.14, 1.46), (0.16, 0.14, 0.16), CREAM, 16, 10)
    sphere(f"{name} / right mitt", (x + 0.62, y - 0.12, 1.42), (0.16, 0.14, 0.16), CREAM, 16, 10)
    cylinder(f"{name} / left leg", (x - 0.17, y, 0.62), (x - 0.23, y - 0.12, 0.22), 0.13, INK)
    cylinder(f"{name} / right leg", (x + 0.17, y, 0.62), (x + 0.22, y - 0.08, 0.22), 0.13, INK)
    sphere(f"{name} / left shoe", (x - 0.25, y - 0.2, 0.18), (0.23, 0.31, 0.13), GOLD, 16, 10)
    sphere(f"{name} / right shoe", (x + 0.23, y - 0.2, 0.18), (0.23, 0.31, 0.13), GOLD, 16, 10)


# Clear the default file and create a tidy scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for block in bpy.data.materials:
    if block.name.startswith("Material") and block.users == 0:
        bpy.data.materials.remove(block)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1440
scene.render.resolution_y = 960
scene.render.resolution_percentage = 75
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.world.color = (0.035, 0.05, 0.1)

# Floating oval plinth and a softly lit, two-tone indoor court.
bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=1, depth=0.48, location=(0, 0, -0.42))
plinth = bpy.context.object
plinth.name = "Moonlit stadium / floating plinth"
plinth.scale = (13.4, 9.8, 1)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
assign(plinth, INK)
mod = plinth.modifiers.new("Gold inlay bevel", "BEVEL")
mod.width = 0.2
mod.segments = 4
plinth.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")

cube("Court / foundation", (0, 0, -0.08), (17.5, 10.8, 0.32), STONE, bevel=0.16)
cube("Court / playing surface", (0, 0, 0.115), (16.3, 9.6, 0.12), COURT, bevel=0.09)
cube("Court / near service lane", (0, -2.33, 0.18), (15.8, 0.055, 0.035), MINT, bevel=0.01)
cube("Court / far service lane", (0, 2.33, 0.18), (15.8, 0.055, 0.035), MINT, bevel=0.01)
cube("Court / near boundary", (0, -4.61, 0.18), (15.8, 0.075, 0.035), CREAM, bevel=0.012)
cube("Court / far boundary", (0, 4.61, 0.18), (15.8, 0.075, 0.035), CREAM, bevel=0.012)
cube("Court / left boundary", (-7.91, 0, 0.18), (0.075, 9.25, 0.035), CREAM, bevel=0.012)
cube("Court / right boundary", (7.91, 0, 0.18), (0.075, 9.25, 0.035), CREAM, bevel=0.012)
cube("Court / center stripe", (0, 0, 0.18), (0.07, 9.3, 0.035), GOLD, bevel=0.012)

# Net posts and a fine open mesh, so the court reads clearly from an angled camera.
for x in (-8.25, 8.25):
    cylinder("Net / brass post", (x, 0, 0.24), (x, 0, 2.75), 0.09, GOLD, vertices=20)
    sphere("Net / post cap", (x, 0, 2.76), (0.16, 0.16, 0.16), GOLD_LIGHT, 16, 10)
for z in [0.42 + i * 0.23 for i in range(10)]:
    curve_line("Net / horizontal thread", [(-8.16, 0, z), (8.16, 0, z)], CREAM, radius=0.012)
for x in [(-8.0 + i * 0.5) for i in range(33)]:
    curve_line("Net / vertical thread", [(x, 0, 0.4), (x, 0, 2.5)], CREAM, radius=0.012)
cube("Net / top binding", (0, 0, 2.58), (16.5, 0.13, 0.16), GOLD, bevel=0.055)

# Architectural backdrop: arched moon windows, brass ribs and velvet seating.
cube("Hall / back wall", (0, 8.1, 5.1), (28, 0.5, 11), WALL, bevel=0.12)
cube("Hall / back wall lower rail", (0, 7.72, 1.05), (25, 0.24, 0.35), GOLD, bevel=0.08)
for idx, x in enumerate((-10, -5, 0, 5, 10)):
    cube(f"Window {idx} / midnight glass", (x, 7.79, 5.1), (3.1, 0.08, 5.7), WINDOW, bevel=0.08)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.52, minor_radius=0.07, major_segments=48, minor_segments=8, location=(x, 7.69, 7.92), rotation=(math.pi / 2, 0, 0))
    arch = bpy.context.object
    arch.name = f"Window {idx} / brass arch"
    assign(arch, GOLD)
    cube(f"Window {idx} / left mullion", (x - 1.0, 7.67, 5.0), (0.055, 0.08, 5.2), GOLD, bevel=0.018)
    cube(f"Window {idx} / right mullion", (x + 1.0, 7.67, 5.0), (0.055, 0.08, 5.2), GOLD, bevel=0.018)
    cube(f"Window {idx} / cross mullion", (x, 7.67, 5.0), (2.0, 0.08, 0.05), GOLD, bevel=0.015)

# Tiered, curved-feeling stands built as beveled platforms, with individual seat glints.
for row in range(4):
    y = 5.25 + row * 0.53
    z = 0.4 + row * 0.39
    cube(f"Stand / rear tier {row}", (0, y, z), (21.5 - row * 0.7, 0.5, 0.34), STONE, bevel=0.11)
    for x in range(-9, 10, 2):
        sphere(f"Stand / dream spectator {row}-{x}", (x + random.uniform(-0.22, 0.22), y - 0.15, z + 0.33), (0.19, 0.17, 0.24), random.choice([CORAL, LAVENDER, MINT, GOLD]), 12, 8)

# Tall pillars and glowing fixtures frame the court without hiding the view.
for x in (-11.7, 11.7):
    cube("Hall / fluted pillar", (x, 6.7, 4.1), (0.52, 0.65, 8.2), STONE, bevel=0.18)
    cube("Hall / pillar capital", (x, 6.55, 8.2), (1.15, 0.9, 0.3), GOLD, bevel=0.12)
    sphere("Hall / hanging lantern", (x, 4.3, 7.2), (0.45, 0.45, 0.52), GOLD_LIGHT, 20, 12)

# A large pearl moon and a ring of tiny lights anchor the hall's dreamlike skyline.
sphere("Moon / pearl", (0, 7.2, 8.6), (1.05, 0.28, 1.05), GOLD_LIGHT, 32, 24)
bpy.ops.mesh.primitive_torus_add(major_radius=1.45, minor_radius=0.045, major_segments=64, minor_segments=8, location=(0, 7.15, 8.6), rotation=(math.pi / 2, 0, 0))
moon_ring = bpy.context.object
moon_ring.name = "Moon / orbit ring"
assign(moon_ring, MINT)
for i in range(28):
    angle = random.random() * math.tau
    radius = random.uniform(8.9, 12.0)
    x = math.cos(angle) * radius
    y = random.uniform(5.2, 7.0)
    z = random.uniform(4.0, 9.4)
    sphere(f"Sky / floating spark {i:02d}", (x, y, z), (0.045, 0.045, 0.045), GOLD_LIGHT, 8, 6)

# Two original hooded mascots set up for a lively point.
avatar("Home team / Luna", -4.7, -1.9, CORAL, facing=1)
avatar("Dream team / Comet", 4.6, 1.75, LAVENDER, facing=-1)

# Fine volleyball seams are modeled as four curved great-circle-like paths.
ball_center = Vector((2.1, -3.5, 1.2))
ball_radius = 0.52
sphere("Game ball / pearl", ball_center, (ball_radius, ball_radius, ball_radius), BALL_MAT, 32, 24)
for plane in range(3):
    seam = []
    for step in range(49):
        theta = math.tau * step / 48
        if plane == 0:
            direction = Vector((math.cos(theta), math.sin(theta), 0))
        elif plane == 1:
            direction = Vector((math.cos(theta), 0, math.sin(theta)))
        else:
            direction = Vector((0, math.cos(theta), math.sin(theta)))
        seam.append(ball_center + direction * (ball_radius * 1.005))
    curve_line(f"Game ball / seam {plane}", seam, BALL_SEAM, radius=0.016, cyclic=True)

# A small sign identifies the original game world.
cube("Hall sign / backing", (0, 7.58, 10.0), (6.8, 0.28, 1.05), INK, bevel=0.18)
text_object("Hall sign / title", "DREAMCOURT", (0, 7.41, 10.0), 0.58, GOLD_LIGHT)

# Camera and practical lights are kept in the editable .blend, not in the exported GLB.
bpy.ops.object.camera_add(location=(13.8, -19.8, 13.5))
camera = bpy.context.object
camera.name = "Preview camera"
look_at = Vector((0, 0.65, 2.0))
camera.rotation_euler = (look_at - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 47
scene.camera = camera

bpy.ops.object.light_add(type="AREA", location=(-5, -5, 12))
key = bpy.context.object
key.name = "Soft moon key"
key.data.energy = 1800
key.data.shape = "DISK"
key.data.size = 9

bpy.ops.object.light_add(type="AREA", location=(7, 5, 10))
rim = bpy.context.object
rim.name = "Mint rim light"
rim.data.energy = 1450
rim.data.color = (0.36, 0.82, 0.79)
rim.data.size = 7

bpy.ops.object.light_add(type="AREA", location=(0, 0, 15))
court_light = bpy.context.object
court_light.name = "Court softbox"
court_light.data.energy = 1100
court_light.data.shape = "RECTANGLE"
court_light.data.size = 10
court_light.data.size_y = 6

world = bpy.data.worlds.new("Blue hour") if not bpy.data.worlds else bpy.data.worlds[0]
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.035, 0.05, 0.1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.36

# Keep the editable scene and web-ready GLB adjacent to this script.
blend_path = os.path.join(SOURCE_DIR, "dreamcourt.blend")
glb_path = os.path.join(ASSET_DIR, "dreamcourt.glb")
preview_path = os.path.join(ASSET_DIR, "dreamcourt-preview.png")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

# Convert curves and text to mesh for broad glTF compatibility; export only geometry.
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj.type in {"CURVE", "FONT"}:
        obj.select_set(True)
if bpy.context.selected_objects:
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.convert(target="MESH")
bpy.ops.object.select_all(action="DESELECT")
for obj in scene.objects:
    if obj.type == "MESH" and not obj.name.startswith("Game ball /"):
        obj.select_set(True)
if bpy.context.selected_objects:
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", use_selection=True, export_apply=True)
print(f"EXPORTED_GLB={glb_path}")

try:
    scene.render.filepath = preview_path
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED_PREVIEW={preview_path}")
except Exception as exc:
    print(f"PREVIEW_RENDER_SKIPPED={exc}")
