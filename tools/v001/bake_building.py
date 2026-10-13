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

# Upper landing: two opposing entrance doors. Northern unit is deliberately opaque.
homez=(FLOORS-1)*FLOOR_H
px=1.0/12.0
def at(logical_x,logical_y):
    return (logical_x*px,logical_y*px)
def room_box(name,collection,x,y,z,width,depth,height,mat):
    return box(name,collection,(x*px,y*px,homez+z),
               (width*px,depth*px,height),mat)

# North unit: silhouette ONLY, no fake accessible interior.
room_box("northern neighbor floor (not playable)","neighbor",108,24,.09,120,48,.18,stone)
room_box("northern neighbor closed south wall","neighbor",108,48,1.50,120,2,2.9,plaster)
room_box("opposite northern apartment door","neighbor",120,49,1.12,19,2.0,2.19,wood)
room_box("neighbor brass number plate","neighbor",136,49,1.87,6,1,0.13,mortar)

# Shared upper landing is visible independently of any apartment cutaway.
room_box("landing terrazzo slab","landing",108,54,.09,120,12,.18,floor_tile)
room_box("stairs landing to roof","landing",30,54,.12,36,45,.22,stone)
for step in range(5):
    room_box("shared stair step %d"%step,"landing",25,38+step*7,.23+step*.30,24,7,.20,stone)
rail("stair handrail","landing",(1.08,3.05,homez+.7),(3.6,5.85,homez+2.0),.058,iron)
room_box("south apartment exterior door frame","landing",120,59,1.20,25,1.6,2.40,mortar)
room_box("south apartment old wooden door","landing",120,60,1.14,18,1.7,2.22,wood)
room_box("south door enamel number","landing",137,60,1.86,6,1.0,.15,teal)
room_box("landing faded notice board","landing",73,51,1.73,17,1.1,.79,wood)

# Only the SOUTH flat is playable: logical x=48..168, y=60..132 => 60m2.
room_box("south apartment tile slab 60m2","apartment",108,96,.10,120,72,.18,floor_tile)
for gx in range(1,10):
    room_box("south apartment tile X","apartment",48+gx*12,96,.199,.35,72,.018,floor_dark)
for gy in range(1,6):
    room_box("south apartment tile Y","apartment",108,60+gy*12,.199,120,.35,.018,floor_dark)
room_box("west structural wall","apartment",48,96,1.48,2,72,2.86,mint)
room_box("north permanent wall","apartment",108,60,1.48,120,2,2.86,mint)
# Tiny private bathroom occupying upper east corner. Functional wall/fixtures.
room_box("small bathroom west partition","apartment",137,76,1.48,2,32,2.86,mint)
room_box("small bathroom south divider","apartment",151,91,1.48,32,2,2.86,mint)
room_box("bathroom doorway timber trim","apartment",137,83,1.34,3,7,2.45,wood)
room_box("bathroom toilet ceramic","apartment",154,71,.39,13,16,.51,cream)
room_box("bathroom basin","apartment",164,84,.91,7,10,.20,cream)
# A humble private kitchenette is the actual lifestyle upgrade.
room_box("kitchen counter cabinet","apartment",64,76,.63,27,12,1.10,wood)
room_box("kitchen counter tile","apartment",64,76,1.20,28,13,.12,stone)
room_box("small sink steel","apartment",59,76,1.28,10,7,.06,metal)
room_box("kitchen upper shelf","apartment",67,62,1.92,22,5,.11,wood)
room_box("bedroom dividing half-wall","apartment",91,110,.76,2,42,1.48,mint)
room_box("aged small window frame","apartment",80,60,2.12,19,3,.95,teal)
room_box("window glass north","apartment",80,62,2.13,13,1.5,.71,window)
room_box("compact tiled threshold","apartment",118,66,.22,24,9,.055,mortar)

# Keep a low wall silhouette rather than erasing the southern apartment boundary.
room_box("south low cutaway wall","front_wall_cut",108,131,.42,120,2,.78,plaster)
room_box("east low cutaway wall","front_wall_cut",167,96,.42,2,72,.78,plaster)
room_box("front cutaway wall cap","front_wall_cut",108,131,.84,120,2.6,.09,stone)

# Independent movable furniture — no full-floor furnished villa.
chairx,chairy=83/12.0,101/12.0
box("old chair seat","chair",(chairx,chairy,homez+.61),(.74,.75,.18),wood)
box("chair back","chair",(chairx,chairy-.34,homez+1.11),(.70,.13,.92),teal)
for ax in (-.27,.27):
    for ay in (-.27,.27):
        box("chair leg","chair",(chairx+ax,chairy+ay,homez+.27),(.075,.075,.51),wood)
tablex,tabley=145/12.0,103/12.0
box("small reused table","table",(tablex,tabley,homez+.85),(1.05,.92,.13),wood)
for ax in (-.39,.39):
    for ay in (-.33,.33):
        box("table leg","table",(tablex+ax,tabley+ay,homez+.40),(.08,.08,.70),wood)

# One ROOM on the common roof, 4 x 6 metres, directly over the southern flat.
# Roof height is the TOP of residential floor six, never a seventh dwelling floor.
rx0,rx1=5.0,9.0
ry0,ry1=5.0,11.0
def roof_box(name,collection,x,y,z,width,depth,height,mat):
    return box(name,collection,(x,y,zroof+z),(width,depth,height),mat)

roof_box("roof room tiled floor","roof_room",7.0,8.0,.16,4,6,.24,floor_tile)
roof_box("roof room north wall","roof_room",7.0,5.0,1.46,4,.18,2.75,plaster)
roof_box("roof room west wall","roof_room",5.0,8.0,1.46,.18,6,2.75,plaster)
roof_box("roof room east wall","roof_room",9.0,8.0,1.46,.18,6,2.75,plaster)
roof_box("roof room south wall","roof_room",7.0,11.0,1.46,4,.18,2.75,plaster)
roof_box("roof room flat ceiling","roof_room",7.0,8.0,2.93,4.4,6.3,.20,stone)
roof_box("roof room exterior door","roof_room",9.07,8.6,1.19,.15,1.1,2.20,wood)
roof_box("roof room little shutter","roof_room",7.5,11.15,1.83,1.2,.12,.81,teal)

roof_box("roof room cut floor","roof_room_cut",7.0,8.0,.20,4,6,.18,floor_tile)
roof_box("roof room cut north wall","roof_room_cut",7.0,5.0,1.46,4,.18,2.75,plaster)
roof_box("roof room cut west wall","roof_room_cut",5.0,8.0,1.46,.18,6,2.75,plaster)
roof_box("roof room low south sill","roof_room_cut",7.0,10.98,.42,4,.19,.78,stone)
roof_box("roof room low east sill","roof_room_cut",8.98,8.0,.42,.19,6,.78,stone)
roof_box("roof room simple bed frame","roof_room_cut",6.28,6.75,.38,1.60,.92,.51,wood)
roof_box("roof room mattress","roof_room_cut",6.28,6.75,.69,1.52,.85,.15,linen)
roof_box("roof room narrow desk","roof_room_cut",8.25,7.00,.72,.90,.70,.17,wood)
roof_box("roof room standing fan stem","roof_room_cut",8.07,9.48,.76,.12,.12,1.38,iron)
foliage("roof room humble fan head","roof_room_cut",(8.07,9.48,zroof+1.48),.36,metal)

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
    "furniture_default_local":{"chair":[83,101],"table":[145,103]},
    "south_apartment_m2":60,"roof_room_m2":24,
    "roof_room_bounds_logical":[60,60,48,72],
    "south_apartment_bounds_logical":[48,60,120,72],
    "furniture_translation":"Translate sprite image by Building.project(current,6)-Building.project(default,6)",
    "assets":{}
}
for time_of_day in ("day","night"):
    night=time_of_day=="night"
    # More unbiased samples at night; system Blender does not ship OIDN.
    scene.cycles.samples=35 if night else 18
    sun_data.energy=.16 if night else 1.7
    sun_data.color=(.65,.73,1) if night else (1,.91,.78)
    background.inputs["Color"].default_value=(.07,.10,.18,1) if night else (.60,.66,.74,1)
    background.inputs["Strength"].default_value=.40 if night else .76
    for m in (window,warmglass):
        bsdf=m.node_tree.nodes.get("Principled BSDF")
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = (.25 if night else .33) if m==window else (1.18 if night else .38)
    for label in ("facade_lower","facade_upper","roof","apartment","lobby","chair","table",
                  "neighbor","landing","front_wall_cut","roof_room","roof_room_cut"):
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
