extends RefCounted
## Temporary Godot draw-only illustration of existing P3 cooking facts.
## This must never own a timer, inventory, progression or saved state.

static func _text(canvas: CanvasItem, point: Vector2, text: String,
        size: int = 14, color: Color = Color("#e5d7be"), width: float = -1.0) -> void:
    canvas.draw_string(ThemeDB.fallback_font,point,text,
        HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

static func _station(canvas: CanvasItem, context: Dictionary) -> void:
    var index: int = int(context["step_index"])
    var heat_state: String = str(context["heat_state"])
    var heat: bool = index == 1 and heat_state not in ["inactive","paused"]
    var center := Vector2(667,229)
    if index == 1:
        # The pan is a view of the *real* active step and turn status.
        var rim := Color("#a9ad9b")
        if heat_state == "turn_window": rim = Color("#91c7ab")
        elif heat_state in ["overseared","second_face_late"]: rim = Color("#dc9270")
        elif heat_state == "warming": rim = Color("#e6be78")
        canvas.draw_line(center+Vector2(47,29),center+Vector2(104,53),
            Color("#997d5e"),14.0,true)
        canvas.draw_circle(center,58.0,Color("#3e4846"))
        canvas.draw_circle(center,49.0,Color("#17282a"))
        canvas.draw_arc(center,51.0,0.0,TAU,50,rim,4.0,true)
        canvas.draw_circle(center+Vector2(-17,-5),16.0,Color("#a75e40"))
        canvas.draw_circle(center+Vector2(9,2),18.0,Color("#c57f4a"))
        canvas.draw_circle(center+Vector2(23,-12),10.0,Color("#daaa62"))
        if heat:
            for i in range(3):
                var origin := center+Vector2(-24+i*23,62)
                canvas.draw_line(origin,origin+Vector2(6,-11),rim,3.0,true)
    else:
        # One quiet cutaway icon for the prep/assembly board.
        canvas.draw_rect(Rect2(609,184,119,99),Color("#71594a"))
        canvas.draw_rect(Rect2(616,191,105,85),Color("#b99367"))
        canvas.draw_circle(center+Vector2(-14,-3),24.0,Color("#b8794e"))
        canvas.draw_circle(center+Vector2(14,3),20.0,Color("#d8b477"))
        if index == 0:
            canvas.draw_circle(center+Vector2(26,-20),5.0,Color("#d9d6aa"))
            canvas.draw_circle(center+Vector2(22,17),4.0,Color("#d9d6aa"))
        else:
            canvas.draw_arc(center,27.0,0,TAU,32,Color("#e1bf83"),3.0,true)

static func draw(canvas: CanvasItem, context: Dictionary) -> void:
    # Drawn over the existing running world, not a second UI-driven simulation.
    canvas.draw_rect(Rect2(0,64,960,383),Color(0.03,0.055,0.065,0.95))
    canvas.draw_rect(Rect2(146,83,668,350),Color("#1c3035"))
    canvas.draw_rect(Rect2(146,83,668,4),Color("#e8bc75"))
    _text(canvas,Vector2(170,119),"THE SANDWICH COUNTER",22,Color("#f1cd88"))
    _text(canvas,Vector2(170,143),str(context["service_note"]),
        13,Color("#cbbba6"),618)
    _text(canvas,Vector2(173,161),"SUPPLIES",13,Color("#e6c18b"))
    var options: Array = context["offers"]
    var stock: Dictionary = context["stock"]
    for i in range(mini(6,options.size())):
        var option: Dictionary = options[i]
        var item: String = str(option["ingredient_id"])
        var purchased: bool = bool(option["resolved"])
        var color := Color("#9fbeab") if purchased else Color("#e9dac1")
        var y: float = 182.0 + i*22.0
        canvas.draw_rect(Rect2(169,y-14,357,20),
            Color("#273d3e") if purchased else Color("#253237"))
        _text(canvas,Vector2(176,y),"%d %s" % [i+1,item.replace("_"," ")],
            13,color,159)
        _text(canvas,Vector2(341,y),"%d%s" % [int(stock.get(item,0)),
            str(option.get("unit",""))],13,color,74)
        _text(canvas,Vector2(415,y),"%d p %s" % [int(option["cost"]),
            "bought" if purchased else ""],13,color,110)
    canvas.draw_rect(Rect2(534,158,264,155),Color("#273b3c"))
    _text(canvas,Vector2(551,179),str(context["phase_label"]).to_upper(),
        14,Color("#f0d19b"),226)
    _station(canvas,context)
    var warning: String = str(context["heat_state"])
    var short_status: String = {
        "idle":"STOCK & START","inactive":"READY TO START",
        "paused":"PAUSED","warming":"HEATING","turn_window":"TURN NOW",
        "overseared":"TOO LONG ON HEAT","turned":"OTHER SIDE","second_face_late":"OVERCOOKING",
        "working":"PREPARING","ready":"READY TO FINISH"
    }.get(warning,"")
    _text(canvas,Vector2(551,301),short_status,13,
        Color("#eaa882") if warning in ["overseared","second_face_late"] else Color("#bdd2ae"),228)
    canvas.draw_rect(Rect2(163,320,634,77),Color("#203d3e"))
    _text(canvas,Vector2(177,343),str(context["cue"]),17,Color("#f3daac"),598)
    _text(canvas,Vector2(177,366),str(context["heat_caption"]),14,Color("#c6d4c0"),598)
    if not str(context["item_id"]).is_empty():
        _text(canvas,Vector2(177,387),"Last item: %s · %d/100 (verified timing)" % [
            context["grade"],context["score"]],13,Color("#d8bd8f"),600)
    _text(canvas,Vector2(170,417),
        "1–6 Buy · Enter Action · J Wait 5 min · P Save · F7/Esc Close",
        14,Color("#e8bc75"),626)
