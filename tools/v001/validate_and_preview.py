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
assert len(images)==14,len(images)

def compose(mode,time):
    night=time=="night"
    frame=Image.new("RGBA",(960,540),"#243b43" if night else "#a1c6c0")
    canvas=ImageDraw.Draw(frame)
    canvas.rectangle((0,408,959,539),fill="#333e43" if night else "#788078")
    canvas.rectangle((0,397,959,411),fill="#8b8c75")
    for x in (110,300,765,880):
        canvas.rectangle((x-4,325,x+4,400),fill="#5b5443")
        canvas.ellipse((x-32,290,x+32,360),fill="#2c4e40" if night else "#537653")
    layers=["facade_lower","facade_upper","roof"] if mode=="street" else ["facade_lower","apartment","chair","table"]
    for layer in layers:
        frame.alpha_composite(images[f"{layer}_{time}.png"])
    if mode!="street":
        # P0 actor as a small placeholder at floor 6. Sprites stay untrimmed/registered.
        x=490+.93*86-.93*58
        y=390+.45*(86+58)-47*5
        canvas=ImageDraw.Draw(frame)
        canvas.ellipse((x-8,y-8,x+8,y+8),fill="#275783",outline="#faf1d8",width=2)
    canvas=ImageDraw.Draw(frame)
    canvas.rectangle((0,0,959,40),fill=(19,32,37,235))
    canvas.text((15,10),f"V001 | {mode} {time} | Blender layer composite (not Godot screenshot)",fill="white")
    output=preview_dir/f"{mode}_{time}.png"
    frame.convert("RGB").save(output)
    print("V001_PREVIEW",output)
for mode in ("street","apartment"):
    for time in ("day","night"):
        compose(mode,time)
print("V001_IMAGE_VALIDATION_PASS",len(images),"transparent sprite layers, four previews")
