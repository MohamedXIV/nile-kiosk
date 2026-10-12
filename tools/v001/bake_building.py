"""Nile Kiosk V001 P1: deterministic 3D-authored fixed-camera sprite baker.

Run: blender -b -t 2 --python tools/v001/bake_building.py -- --output assets/v001
Source and layer manifest stay editable; output PNGs all have identical 960x540 canvas.
Architecture: 1940s-50s modest Cairo residential building, seen circa 2000-2005.
"""
import bpy
import json
import math
import os
import sys
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

W, H = 960, 540
LOGICAL_PER_METRE = 12.0
FLOOR_H = 3.4
FLOORS = 6
WIDTH = 180.0 / LOGICAL_PER_METRE
DEPTH = 132.0 / LOGICAL_PER_METRE
ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
dest = Path(args[args.index("--output") + 1]) if "--output" in args else ROOT / "assets/v001"
if not dest.is_absolute():
    dest = ROOT / dest
dest.mkdir(parents=True, exist_ok=True)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != "Collection":
        bpy.data.collections.remove(c)
COLLECTIONS = {}
def layer(key):
    if key not in COLLECTIONS:
        collection = bpy.data.collections.new(key)
        bpy.context.scene.collection.children.link(collection)
        COLLECTIONS[key] = collection
    return COLLECTIONS[key]

def material(name, hex_rgb, lit=False):
    h = hex_rgb.lstrip("#")
    rgb = tuple(int(h[i:i+2], 16)/255 for i in (0, 2, 4))
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.85
    if lit:
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 0.0
    return m

plaster = material("warm aged limestone", "#bda98a")
plaster_alt = material("slightly warmer aged plaster", "#bea888")
mortar = material("molding pale", "#cdbd9f")
stone = material("weathered base stone", "#998165")
shadowstone = material("balcony shadows", "#777064")
iron = material("wrought iron charcoal", "#3e5555")
teal = material("Egyptian muted teal shutters", "#4b7670")
terracotta = material("plant pots fired earthenware", "#ae7158")
leaf = material("balcony pothos foliage", "#427148")
sea_green = material("painted old shutters", "#688c7e")
window = material("blue-grey glass", "#547c83", True)
warmglass = material("warm lived-in window", "#be885a", True)
wood = material("wood old walnut", "#75553b")
floor_tile = material("warm cream worn tile", "#d6c3a0")
floor_dark = material("tile grout", "#9e917b")
mint = material("interior green paint", "#aebba9")
linen = material("bed cover faded flax", "#c0b9a9")
rust = material("water tank oxidized blue", "#52717a")
rug = material("old rug muted red", "#a66c60")
tree = material("planter olive green", "#42664d")
metal = material("satellite dish", "#a3a9a2")
tile = material("roof tile slab", "#908a7c")
cream = material("room fan / CRT light", "#e2d2b0")

def box(name, category, center, size, mat):
    # Swap authored logical X/Y into the camera's physical right-handed world axes.
    center=(center[1], center[0], center[2])
    size=(size[1], size[0], size[2])
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    layer(category).objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def cylinder(name, category, center, radius, depth, mat, verts=20):
    center=(center[1], center[0], center[2])
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center)
    obj = bpy.context.object
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    layer(category).objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def foliage(name, category, center, radius, mat):
    center=(center[1],center[0],center[2])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=radius,location=center)
    obj=bpy.context.object
    obj.name=name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    layer(category).objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def rail(name, category, a, b, radius, mat):
    pa, pb = Vector(a), Vector(b)
    logical_direction = pb-pa
    direction = Vector((logical_direction.y, logical_direction.x, logical_direction.z))
    obj = cylinder(name, category, (pa+pb)*0.5, radius, direction.length, mat, 10)
    obj.rotation_euler = direction.to_track_quat('Z','Y').to_euler()
    return obj

# Facade planes on camera-facing +X and +Y. Each storey belongs to one layer.
for storey in range(FLOORS):
    group = "facade_lower" if storey < FLOORS-1 else "facade_upper"
    z0 = storey * FLOOR_H
    zmid = z0 + FLOOR_H*0.5
    box("east plaster %d"%storey, group, (WIDTH, DEPTH/2,zmid),
        (.23, DEPTH, FLOOR_H-.12), plaster_alt if storey in (1,4) else plaster)
    box("south plaster %d"%storey, group, (WIDTH/2,DEPTH,zmid),
        (WIDTH,.23,FLOOR_H-.12), plaster_alt if storey in (1,4) else plaster)
    # Rounded corner pilaster softens the box and recalls pre-1960 Cairo facades.
    cylinder("rounded stone corner pilaster %d"%storey,group,
        (WIDTH+.02,DEPTH+.02,zmid),.29,FLOOR_H-.18,mortar,16)
    for y in (0.8,5.5,10.15):
        box("east vertical stone pilaster",group,(WIDTH+.12,y,zmid),
            (.13,.16,FLOOR_H-.48),stone)
    for x in (1.1,6.8,13.9):
        box("south vertical stone pilaster",group,(x,DEPTH+.12,zmid),
            (.16,.13,FLOOR_H-.48),stone)
    if storey in (0,2,4):
        # Period-correct external window AC units with open grille slats.
        box("old AC body",group,(WIDTH+.43,5.1,zmid-.45),(.51,1.13,.64),mortar)
        for slot in range(4):
            box("AC grille slot",group,(WIDTH+.705,4.70+slot*.20,zmid-.48),
                (.022,.11,.30),shadowstone)
    # Belts and restrained classical details, not a palace.
    for z in (z0+.22,z0+FLOOR_H-.18):
        box("east stone cornice %d"%storey,group,(WIDTH+.14,DEPTH/2,z),(.35,DEPTH,.16),mortar)
        box("south stone cornice %d"%storey,group,(WIDTH/2,DEPTH+.14,z),(WIDTH,.35,.16),mortar)
    for y in (2.5,7.6):
        for x in (3.4,9.9):
            box("east window recess",group,(WIDTH+.145,y,zmid),(.09,1.25,1.55),shadowstone)
            box("east glass",group,(WIDTH+.22,y,zmid),(.08,1.08,1.35),
                warmglass if (storey+y)>8 and storey%2==0 else window)
            box("east lintel",group,(WIDTH+.27,y,zmid+.87),(.21,1.62,.14),mortar)
            box("south window recess",group,(x,DEPTH+.145,zmid),(1.35,.09,1.55),shadowstone)
            box("south glass",group,(x,DEPTH+.22,zmid),(1.17,.08,1.38),
                warmglass if storey in (1,4,5) else window)
            box("south lintel",group,(x,DEPTH+.27,zmid+.86),(1.68,.22,.13),mortar)
            # Visible frames and painted side shutters make the windows read at 960x540.
            box("east central window mullion",group,(WIDTH+.335,y,zmid),
                (.07,.085,1.36),mortar)
            box("south central window mullion",group,(x,DEPTH+.335,zmid),
                (.085,.07,1.40),mortar)
            box("painted south shutter panel",group,(x+.83,DEPTH+.34,zmid),
                (.32,.11,1.50),sea_green)
            box("east shutter tongue",group,(WIDTH+.33,y-.72,zmid),
                (.11,.31,1.50),teal)
            # shutters partially opened, cool aged blue-green wooden panels
            box("east shutter",group,(WIDTH+.3,y+.72,zmid),(.12,.3,1.55),teal)
            box("south shutter",group,(x-.76,DEPTH+.3,zmid),(.28,.12,1.55),teal)
    if storey in (1,3,5):
        h = z0 + 1.00
        box("restrained apartment balcony slab",group,(9.9,DEPTH+.66,h),(3.6,1.6,.20),stone)
        rail("balcony top rail",group,(8.05,DEPTH+1.42,h+1.00),(11.75,DEPTH+1.42,h+1.00),.047,iron)
        for i in range(12):
            x=8.1+i*.32
            rail("balcony vertical",group,(x,DEPTH+1.42,h+.10),(x,DEPTH+1.42,h+1.02),.027,iron)
        # Everyday plastic/terracotta pots and modest trailing foliage.
        for bx in (8.42,11.35):
            cylinder("balcony plant pot",group,(bx,DEPTH+1.20,h+.25),.20,.38,terracotta,12)
            foliage("balcony pothos",group,(bx,DEPTH+1.19,h+.56),.31,leaf)
        if storey==3:
            box("faded drying cotton",group,(9.35,DEPTH+1.45,h+.73),
                (1.05,.08,.65),linen)

# Simple older doorway with shaded recessed entrance and narrow 1950s awning.
box("arched doorway void silhouette","facade_lower",(WIDTH/2,DEPTH+.18,1.06),(2.5,.10,2.15),shadowstone)
box("entrance wood double door","facade_lower",(WIDTH/2,DEPTH+.27,1.0),(2.08,.13,2.0),wood)
box("entrance canopy","facade_lower",(WIDTH/2,DEPTH+.90,2.60),(3.6,1.95,.16),stone)
box("street number enamel panel","facade_lower",(WIDTH/2+2.8,DEPTH+.27,2.18),(.55,.12,.38),teal)

# Flat roof and unobtrusive utilities from early-2000s residential Cairo.
zroof=FLOORS*FLOOR_H
box("flat reinforced roof","roof",(WIDTH/2,DEPTH/2,zroof), (WIDTH,DEPTH,.32),tile)
for a in (0,WIDTH):
    box("roof low parapet x","roof",(a,DEPTH/2,zroof+.36),(.26,DEPTH,.69),plaster)
for a in (0,DEPTH):
    box("roof low parapet y","roof",(WIDTH/2,a,zroof+.36),(WIDTH,.26,.69),plaster)
cylinder("blue rooftop water tank","roof",(3.1,3.4,zroof+.92),.67,1.70,rust)
cylinder("water tank lid","roof",(3.1,3.4,zroof+1.78),.74,.14,metal)
cylinder("early satellite antenna stem","roof",(10.9,6.5,zroof+.84),.06,1.68,iron)
dish=cylinder("small satellite dish","roof",(10.9,6.5,zroof+1.8),.66,.12,metal,36)
dish.rotation_euler=(math.radians(42), math.radians(23), 0)

# Exposed top-floor interior: its actual slab is floor 6, NOT roof level 7.
homez=(FLOORS-1)*FLOOR_H
box("apartment floor slab","apartment",(WIDTH/2,DEPTH/2,homez+.08),(WIDTH,DEPTH,.16),floor_tile)
box("north/left back wall","apartment",(0,DEPTH/2,homez+1.47),(.22,DEPTH,2.94),mint)
box("west/back wall","apartment",(WIDTH/2,0,homez+1.47),(WIDTH,.22,2.94),mint)
for gx in range(1,10):
    x=WIDTH*gx/10
    box("subtle apartment tile joint X","apartment",(x,DEPTH/2,homez+.167),(.025,DEPTH,.012),floor_dark)
for gy in range(1,8):
    y=DEPTH*gy/8
    box("subtle apartment tile joint Y","apartment",(WIDTH/2,y,homez+.167),(WIDTH,.025,.012),floor_dark)
box("narrow rug","apartment",(7.8,6.1,homez+.19),(3.2,2.0,.04),rug)
box("worn bed frame","apartment",(3.4,2.6,homez+.48),(2.35,1.32,.59),wood)
box("bed sheet","apartment",(3.4,2.6,homez+.78),(2.2,1.17,.07),linen)
box("old small CRT TV cabinet","apartment",(12.3,2.1,homez+.63),(1.2,.65,1.05),wood)
box("CRT glass screen","apartment",(12.3,1.72,homez+1.34),(.79,.14,.52),window)
box("cheap kitchenette","apartment",(1.0,8.95,homez+.77),(1.25,2.35,1.44),stone)
box("kitchen shelf","apartment",(1.0,8.95,homez+1.59),(1.36,2.48,.12),wood)
# A roof cutaway is NOT an open terrace: low front walls and room partitions
# keep the spatial reading of an enclosed rented home.
box("east cutaway knee wall","apartment",(WIDTH-.10,DEPTH/2,homez+.47),
    (.20,DEPTH,.74),plaster)
box("south cutaway knee wall","apartment",(WIDTH/2,DEPTH-.10,homez+.47),
    (WIDTH,.20,.74),plaster)
box("small kitchenette partition","apartment",(3.1,8.12,homez+.91),
    (5.0,.21,1.65),mint)
box("interior half-wall along old hallway","apartment",(11.85,1.9,homez+1.08),
    (.21,3.6,2.03),mint)
box("back wall wooden framed window","apartment",(5.5,.17,homez+1.70),
    (1.42,.12,1.50),teal)
box("back window warm translucent curtain","apartment",(5.5,.27,homez+1.64),
    (1.12,.065,1.20),linen)
box("faded 2001 wall calendar","apartment",(9.9,.16,homez+1.83),
    (.73,.08,.95),cream)
cylinder("standing fan stem","apartment",(6.2,2.8,homez+.79),.046,1.58,iron,12)
foliage("standing fan cage approximation","apartment",(6.2,2.8,homez+1.57),.39,metal)
# Thin railing denotes balcony/opening to the south, no blocking front wall.
rail("small iron balcony rail","apartment",(WIDTH-1.7,DEPTH-.3,homez+.28),
    (WIDTH-1.7,DEPTH-.3,homez+1.24),.07,iron)

# Furniture layer objects use default logical centers matching the P0 GameState.
chairx,chairy = 45/12.0,68/12.0
box("chair sitting slab","chair",(chairx,chairy,homez+.62),(.79,.79,.20),wood)
box("chair curved back approximation","chair",(chairx,chairy-.36,homez+1.12),(.75,.11,.91),teal)
for ax in (-.28,.28):
    for ay in (-.28,.28):
        box("chair leg","chair",(chairx+ax,chairy+ay,homez+.29),(.08,.08,.57),wood)
tablex,tabley =129/12.0,84/12.0
box("little cafe table top","table",(tablex,tabley,homez+.92),(1.35,1.05,.14),wood)
for ax in (-.52,.52):
    for ay in (-.37,.37):
        box("table leg","table",(tablex+ax,tabley+ay,homez+.43),(.085,.085,.80),wood)
cylinder("tea cup on table","table",(tablex-.19,tabley-.15,homez+1.065),.11,.13,cream,16)

# Lobby cutaway slab and stairs in the same physical ground plane.
box("entrance lobby tiled floor","lobby",(WIDTH/2,DEPTH/2,.08),(WIDTH,DEPTH,.16),floor_tile)
box("lobby back wall","lobby",(WIDTH/2,0,1.44),(WIDTH,.20,2.88),mint)
box("stair landing","lobby",(3.4,3.1,.30),(4.8,3.0,.48),stone)
for step in range(6):
    box("stair tread %d"%step,"lobby",(2.8+step*.42,3.0,.43+step*.29),(1.1,2.4,.14),floor_tile)
rail("lobby iron handrail","lobby",(2.7,4.23,.62),(5.4,4.23,2.05),.057,iron)

# Camera projection, pixel-perfect to existing Building.project:
# screen = (490,390) + (0.93,0.45)*localX + (-0.93,0.45)*localY - (0,47)*(floor-1)
scene=bpy.context.scene
scene.render.resolution_x=W
scene.render.resolution_y=H
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.film_transparent=True
# Use Cycles CPU to avoid requiring an EGL/OpenGL display on GitHub runners.
scene.render.engine="CYCLES"
scene.cycles.device="CPU"
scene.cycles.samples=28
scene.cycles.use_denoising=False  # Ubuntu 24.04 Blender 4.0 package lacks OpenImageDenoiser
scene.render.image_settings.color_depth='8'
scene.view_settings.view_transform='Standard'
scene.view_settings.look='Medium High Contrast'
scene.render.film_transparent=True
scene.camera=None
cam_data=bpy.data.cameras.new("locked_oblique_camera")
cam=bpy.data.objects.new("locked_oblique_camera",cam_data)
scene.collection.objects.link(cam)
scene.camera=cam
cam_data.type='ORTHO'
pitch=math.asin(.45/.93)
px_per_world = .93*LOGICAL_PER_METRE*math.sqrt(2)
cam_data.ortho_scale=W/px_per_world

def place_camera(target):
    target=Vector(target)
    distance=40
    horizontal=distance*math.cos(pitch)
    vertical=distance*math.sin(pitch)
    cam.location=target+Vector((horizontal/math.sqrt(2),horizontal/math.sqrt(2),vertical))
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()  # synchronize camera matrix before world_to_camera_view()

def sample(coord):
    p=world_to_camera_view(scene,cam,Vector(coord))
    return ((p.x*W),(1-p.y)*H)

place_camera((0,0,0))
origin=sample((0,0,0))
x_1=sample((0,1,0))  # logical X is Blender world Y
y_1=sample((1,0,0))  # logical Y is Blender world X
z_1=sample((0,0,1))
dx,dy,dz=[(v[0]-origin[0],v[1]-origin[1]) for v in (x_1,y_1,z_1)]
# Move camera target to register world (0,0,0) exactly with Godot ORIGIN.
# The x-axis target offset uses opposing X/Y positions; Z raises projected ground.
a=(490-origin[0])/(dx[0]-dy[0])
c=-(390-origin[1])/dz[1]
place_camera((a,-a,c))
finalorigin=sample((0,0,0))
finalx=sample((0,1,0))
finaly=sample((1,0,0))
finalz=sample((0,0,FLOOR_H))
actual={"origin":list(finalorigin),
        "axis_x":list(Vector(finalx)-Vector(finalorigin)),
        "axis_y":list(Vector(finaly)-Vector(finalorigin)),
        "floor_delta":list(Vector(finalz)-Vector(finalorigin))}
expected={"origin":(490,390),"axis_x":(.93*12,.45*12),
          "axis_y":(-.93*12,.45*12),"floor_delta":(0,-47)}
for key in expected:
    error=max(abs(actual[key][j]-expected[key][j]) for j in (0,1))
    if error>1.5:
        raise RuntimeError("Camera mismatch %s: %s vs %s (%.2f px)" %
            (key,actual[key],expected[key],error))

sun_data=bpy.data.lights.new("low angle natural sunlight",'SUN')
sun=bpy.data.objects.new("low angle natural sunlight",sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler=(math.radians(30),math.radians(-30),math.radians(25))
world=bpy.data.worlds.new("warm sky illumination")
scene.world=world
world.use_nodes=True
background=world.node_tree.nodes.get("Background")

scene.render.image_settings.compression=42
scene.render.filepath=str(dest/"unused.png")
bpy.ops.wm.save_as_mainfile(filepath=str(dest/"v001_cairo_building.blend"))

manifest={
    "schema_version":1,"renderer":"Blender","resolution":[W,H],
    "logical_units_per_blender_metre":LOGICAL_PER_METRE,
    "floor_height_metres":FLOOR_H,"total_floors":FLOORS,
    "player_floor":6,"camera":"locked_oblique_camera",
    "projection":actual,
    "reference_godot_projection":{k:list(v) for k,v in expected.items()},
    "sprite_anchor":"Full 960x540 RGBA canvas, position (0,0), no trimming",
    "furniture_default_local":{"chair":[45,68],"table":[129,84]},
    "furniture_translation":"Translate sprite image by Building.project(current,6)-Building.project(default,6)",
    "assets":{}
}
for time_of_day in ("day","night"):
    night=time_of_day=="night"
    # More unbiased samples at night; system Blender does not ship OIDN.
    scene.cycles.samples=64 if night else 28
    sun_data.energy=.16 if night else 1.7
    sun_data.color=(.65,.73,1) if night else (1,.91,.78)
    background.inputs["Color"].default_value=(.07,.10,.18,1) if night else (.60,.66,.74,1)
    background.inputs["Strength"].default_value=.40 if night else .76
    for m in (window,warmglass):
        bsdf=m.node_tree.nodes.get("Principled BSDF")
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = (.25 if night else .33) if m==window else (1.18 if night else .38)
    for label in ("facade_lower","facade_upper","roof","apartment","lobby","chair","table"):
        for layer_name,collection in COLLECTIONS.items():
            visible=layer_name==label
            for obj in collection.objects:
                obj.hide_render=not visible
        path=dest/("%s_%s.png"%(label,time_of_day))
        scene.render.filepath=str(path)
        bpy.ops.render.render(write_still=True)
        manifest["assets"][path.name]={"layer":label,"time":time_of_day}
        print("V001_RENDERED", path.name, path.stat().st_size)
(dest/"manifest.json").write_text(json.dumps(manifest,indent=2,sort_keys=True),encoding="utf-8")
print("V001_BAKE_PASS", json.dumps(actual))
