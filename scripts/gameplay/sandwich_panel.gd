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
    var center := Vector2(765,238)
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
        canvas.draw_rect(Rect2(708,193,119,99),Color("#71594a"))
        canvas.draw_rect(Rect2(715,200,105,85),Color("#b99367"))
        canvas.draw_circle(center+Vector2(-14,-3),24.0,Color("#b8794e"))
        canvas.draw_circle(center+Vector2(14,3),20.0,Color("#d8b477"))
        if index == 0:
            canvas.draw_circle(center+Vector2(26,-20),5.0,Color("#d9d6aa"))
            canvas.draw_circle(center+Vector2(22,17),4.0,Color("#d9d6aa"))
        else:
            canvas.draw_arc(center,27.0,0,TAU,32,Color("#e1bf83"),3.0,true)

static func draw(canvas: CanvasItem, context: Dictionary) -> void:
    # View-only full workstation; P1/P3/P4/P5 own every value and decision.
    # Cards match native Godot Button coordinates at 640x360 Web scaling.
    canvas.draw_rect(Rect2(0,64,960,476),Color(0.03,0.055,0.065,0.98))
    canvas.draw_rect(Rect2(16,78,928,366),Color("#1c3035"))
    canvas.draw_rect(Rect2(16,78,928,4),Color("#e8bc75"))
    _text(canvas,Vector2(32,115),"THE SANDWICH COUNTER",22,Color("#f1cd88"))
    _text(canvas,Vector2(34,137),str(context["service_note"]),
        14,Color("#d4c6af"),890)
    var options: Array = context["offers"]
    var stock: Dictionary = context["stock"]
    for i in range(mini(6,options.size())):
        var col: int = int(i / 3)
        var row: int = i % 3
        var x: float = 26.0 + col*300.0
        var y: float = 149.0 + row*78.0
        var option: Dictionary = options[i]
        var ingredient: String = str(option["ingredient_id"])
        var bought: bool = bool(option["resolved"])
        var ink: Color = Color("#b8d2c1") if bought else Color("#f0dec3")
        canvas.draw_rect(Rect2(x,y,290,74),
            Color("#31474a") if bought else Color("#24383d"))
        _text(canvas,Vector2(x+10,y+27),
            "%d · %s" % [i+1,ingredient.replace("_"," ")],15,ink,162)
        _text(canvas,Vector2(x+10,y+54),
            "%d%s  ·  %d p" % [int(stock.get(ingredient,0)),
                str(option.get("unit","")),int(option["cost"])],14,ink,162)
    canvas.draw_rect(Rect2(632,149,301,290),Color("#273b3c"))
    _text(canvas,Vector2(650,175),str(context["phase_label"]).to_upper(),
        15,Color("#f0d19b"),267)
    _station(canvas,context)
    var warning: String = str(context["heat_state"])
    var caption: String = {
        "idle":"STOCK & START","inactive":"READY TO START",
        "paused":"PAUSED","warming":"HEATING","turn_window":"TURN NOW",
        "overseared":"TOO LONG ON HEAT","turned":"OTHER SIDE",
        "second_face_late":"OVERCOOKING","working":"PREPARING",
        "ready":"READY TO FINISH"
    }.get(warning,"")
    _text(canvas,Vector2(652,334),caption,15,
        Color("#eaa882") if warning in ["overseared","second_face_late"]
        else Color("#bdd2ae"),260)
    _text(canvas,Vector2(650,372),str(context["cue"]),15,
        Color("#f3daac"),268)
    _text(canvas,Vector2(650,394),str(context["heat_caption"]),13,
        Color("#c6d4c0"),268)
    if not str(context["item_id"]).is_empty():
        _text(canvas,Vector2(650,419),
            "%s · %d/100" % [str(context["grade"]),int(context["score"])],
            14,Color("#d8bd8f"),268)
    canvas.draw_rect(Rect2(0,448,960,92),Color("#172128"))
