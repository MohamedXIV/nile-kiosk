extends RefCounted
## Compact bottom-of-world workstation. The real P3 job and P1 minute supply
## every displayed state; nothing here freezes the camera or stores cooking.
const STRIP_TOP: float = 380.0
const STRIP_HEIGHT: float = 160.0

static func _text(canvas: CanvasItem, at: Vector2, line: String,
        size: int = 14, color: Color = Color("#e5d7be"),
        width: float = -1.0) -> void:
    canvas.draw_string(ThemeDB.fallback_font,at,line,
        HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

static func _pan(canvas: CanvasItem, context: Dictionary) -> void:
    var center := Vector2(76,465)
    var heat_state: String = str(context.get("heat_state","idle"))
    var ring: Color = Color("#a9ad9b")
    if heat_state == "turn_window": ring=Color("#91c7ab")
    elif heat_state in ["overseared","second_face_late"]: ring=Color("#dc9270")
    elif heat_state in ["warming","turned"]: ring=Color("#e6be78")
    canvas.draw_line(center+Vector2(26,14),center+Vector2(58,32),
        Color("#997d5e"),8.0,true)
    canvas.draw_circle(center,34.0,Color("#3e4846"))
    canvas.draw_circle(center,28.0,Color("#17282a"))
    canvas.draw_arc(center,30.0,0.0,TAU,44,ring,3.0,true)
    if int(context.get("step_index",-1))==1:
        canvas.draw_circle(center+Vector2(-10,-4),11,Color("#a75e40"))
        canvas.draw_circle(center+Vector2(9,4),12,Color("#c57f4a"))
    else:
        canvas.draw_rect(Rect2(center-Vector2(16,12),Vector2(30,23)),
            Color("#b99367"))

static func draw(canvas: CanvasItem, context: Dictionary,
        selected_offer_index: int = -1) -> void:
    # More than 70% of the physical 960x540 scene stays unobstructed.
    canvas.draw_rect(Rect2(0,STRIP_TOP,960,STRIP_HEIGHT),
        Color(0.055,0.094,0.102,0.97))
    canvas.draw_rect(Rect2(0,STRIP_TOP,960,3),Color("#d6ae76"))
    _pan(canvas,context)
    var can_start: bool = bool(context.get("can_start",false))
    var stage: String = str(context.get("stage",""))
    var offers: Array = context.get("offers",[])
    if stage.is_empty() and not can_start:
        _text(canvas,Vector2(140,411),"Counter stock",17,Color("#f2d5a1"))
        if selected_offer_index>=0 and selected_offer_index<offers.size():
            var offer: Dictionary = offers[selected_offer_index]
            var id: String = str(offer.get("ingredient_id","")).replace("_"," ")
            _text(canvas,Vector2(140,439),"Next: %s · %d p" %
                [id,int(offer.get("cost",0))],16,Color("#f5e1b6"),408)
        _text(canvas,Vector2(140,465),str(context.get("service_note","")),13,
            Color("#ccd8cd"),408)
        var missing: int = 0
        for offer in offers:
            if not bool(offer.get("resolved",false)): missing+=1
        _text(canvas,Vector2(140,493),"%d ingredient lots still available" % missing,
            14,Color("#c7d1c7"))
    else:
        _text(canvas,Vector2(140,411),str(context.get("phase_label","Cooking")),
            18,Color("#f2d5a1"),408)
        var heat: String = str(context.get("heat_state",""))
        var heading: String = {
            "turn_window":"Turn now", "warming":"Heat the pan",
            "turned":"Other side", "overseared":"Overcooking",
            "second_face_late":"Too long on heat", "working":"Preparing",
            "ready":"Ready to finish"
        }.get(heat,"Ready")
        _text(canvas,Vector2(140,441),heading,17,
            Color("#eca78d") if heat in ["overseared","second_face_late"]
            else Color("#bbd6ae"),408)
        _text(canvas,Vector2(140,466),str(context.get("heat_caption","")),
            14,Color("#c9d1bf"),408)
        _text(canvas,Vector2(140,493),str(context.get("cue","")),
            14,Color("#efd8b1"),408)
    if not str(context.get("item_id","")).is_empty():
        _text(canvas,Vector2(140,519),
            "%s · %d/100" % [str(context.get("grade","")),
            int(context.get("score",0))],13,Color("#d8bd8f"))
