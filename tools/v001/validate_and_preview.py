"""Validate the camera/alpha layers and generate reviewable composites.

IMPORTANT: these previews composite actual Blender PNGs; they are not Godot screenshots.
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

asset_dir=Path(sys.argv[1])
preview_dir=Path(sys.argv[2])
preview_dir.mkdir(parents=True,exist_ok=True)
manifest=json.loads((asset_dir/"manifest.json").read_text(encoding="utf-8"))
assert manifest["resolution"]==[960,540]
expected={"origin":(490,390),"axis_x":(11.16,5.4),
          "axis_y":(-11.16,5.4),"floor_delta":(0,-47)}
for key,values in expected.items():
    assert max(abs(a-b) for a,b in zip(manifest["projection"][key],values))<1.5,key
images={}
for name in manifest["assets"]:
    frame=Image.open(asset_dir/name).convert("RGBA")
    assert frame.size==(960,540),name
    alpha=frame.getchannel("A")
    box=alpha.getbbox()
    assert box is not None,("transparent/empty frame",name)
    assert alpha.getextrema()[0]==0,("missing transparency",name)
    images[name]=frame
    print("V001_LAYER_PASS",name,box)
assert len(images)==24,len(images)
assert manifest["south_apartment_m2"]==60
assert manifest["roof_room_m2"]==24

def compose(mode,time):
    night=time=="night"
    frame=Image.new("RGBA",(960,540),"#243b43" if night else "#a1c6c0")
    canvas=ImageDraw.Draw(frame)
    canvas.rectangle((0,408,959,539),fill="#333e43" if night else "#788078")
    canvas.rectangle((0,397,959,411),fill="#8b8c75")
    for x in (110,300,765,880):
        canvas.rectangle((x-4,325,x+4,400),fill="#5b5443")
        canvas.ellipse((x-32,290,x+32,360),fill="#2c4e40" if night else "#537653")
    views={
        "street":["facade_lower","facade_upper","roof","roof_room"],
        "roof_room":["facade_lower","roof","roof_room_cut"],
        "landing":["facade_lower","neighbor","landing"],
        "apartment":["facade_lower","neighbor","landing","apartment","front_wall_cut","chair","table"]
    }
    layers=views[mode]
    for layer in layers:
        frame.alpha_composite(images[f"{layer}_{time}.png"])
    if mode in ("apartment","roof_room"):
        level=7 if mode=="roof_room" else 6
        px,py=(85,99) if mode=="roof_room" else (114,85)
        x=490+.93*px-.93*py
        y=390+.45*(px+py)-47*(level-1)
        canvas=ImageDraw.Draw(frame)
        canvas.ellipse((x-8,y-8,x+8,y+8),fill="#275783",outline="#faf1d8",width=2)
    canvas=ImageDraw.Draw(frame)
    canvas.rectangle((0,0,959,40),fill=(19,32,37,235))
    canvas.text((15,10),f"V001 | {mode} {time} | Blender layer composite (not Godot screenshot)",fill="white")
    output=preview_dir/f"{mode}_{time}.png"
    frame.convert("RGB").save(output)
    print("V001_PREVIEW",output)
for mode in ("street","roof_room","landing","apartment"):
    for time in ("day","night"):
        compose(mode,time)
print("V001_IMAGE_VALIDATION_PASS",len(images),"transparent sprite layers, eight previews")
