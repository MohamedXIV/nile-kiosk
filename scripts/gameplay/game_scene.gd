extends Node2D
## E6/P0 — playable production entry with intentionally provisional 2D shapes.
## No D001 fixture, QA HUD, V001 art import, or scene-owned simulation state.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const MOVE_INTERVAL = 0.13
const MINUTE_INTERVAL = 2.0

var game: RefCounted
var initialized: bool = false
var notice: String = "Opening the kiosk world..."
var move_elapsed: float = 0.0
var minute_elapsed: float = 0.0
var last_marker: String = ""
var player_body: CharacterBody2D
var furniture_bodies: Array[StaticBody2D] = []
var story_open: bool = false # View only. P6 owns Ink cursor and narrative choices.
var story_pending: bool = false
var story_line: String = ""

func _ready() -> void:
    call_deferred("_boot")

func _boot() -> void:
    game = Game.new()
    var result: Dictionary = game.start()
    if not result.get("ok", false):
        notice = "Unable to open saved world: " + str(result.get("code","UNKNOWN"))
        push_error("E6_GAME_BOOT_FAILED " + str(result))
        queue_redraw()
        return
    _setup_physics()
    initialized = true
    notice = "A quiet evening by the Nile."
    report("E6_GAME_RESTORED" if result["code"] != "NEW_WORLD" else "E6_GAME_READY")

func _exit_tree() -> void:
    if game != null:
        game.dispose()

func report(marker: String) -> void:
    last_marker = marker
    print(marker + " " + JSON.stringify(game.status()))
    queue_redraw()

func _process(delta: float) -> void:
    if not initialized: return
    if story_pending and game.session.ink_ready(Game.RIVER_STORY_ID):
        _story_action("begin")
    # Runtime input drives canonical integer movement; no extra scene position.
    move_elapsed += minf(delta, 0.25)
    minute_elapsed += minf(delta, 0.25)
    if move_elapsed >= MOVE_INTERVAL:
        move_elapsed = fmod(move_elapsed, MOVE_INTERVAL)
        if story_open or story_pending:
            move_elapsed = 0.0
        else:
            _process_movement()
    _process_clock()

func _process_movement() -> void:
    var dx: int = int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    var dy: int = int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    if dx != 0 or dy != 0:
        var intended: Vector2i = Game.screen_delta(dx,dy)
        if _player_move_clear(Vector2(intended)):
            var moved: Dictionary = game.move_screen(dx, dy)
            if moved.get("ok", false): queue_redraw()

func _process_clock() -> void:
    if minute_elapsed >= MINUTE_INTERVAL:
        minute_elapsed = fmod(minute_elapsed, MINUTE_INTERVAL)
        var tick: Dictionary = game.wait_minutes(1)
        if tick.get("ok", false): queue_redraw()

func _setup_physics() -> void:
    # CharacterBody2D is an engine collision probe; canonical P2 still
    # commits every accepted integer position. We never save a Node position.
    player_body = CharacterBody2D.new()
    player_body.collision_layer = 2
    player_body.collision_mask = 1
    var player_shape: CollisionShape2D = CollisionShape2D.new()
    var disk: CircleShape2D = CircleShape2D.new()
    disk.radius = 4.0
    player_shape.shape = disk
    player_body.add_child(player_shape)
    add_child(player_body)
    for rect in game.graph.navigator.obstacle_rects():
        var wall: StaticBody2D = StaticBody2D.new()
        wall.collision_layer = 1
        wall.collision_mask = 0
        var shape: CollisionShape2D = CollisionShape2D.new()
        var box: RectangleShape2D = RectangleShape2D.new()
        box.size = rect.size
        shape.shape = box
        wall.position = rect.get_center()
        wall.add_child(shape)
        add_child(wall)
        furniture_bodies.append(wall)

func _player_move_clear(delta: Vector2) -> bool:
    if game.room() != "kiosk" or player_body == null: return true
    player_body.global_position = game.position()
    return not player_body.test_move(player_body.global_transform,delta)

func _act(kind: String) -> void:
    var result: Dictionary = {}
    match kind:
        "door": result = game.travel_near()
        "talk": result = game.listen_near()
        "serve": result = game.service_near()
        "tea_heat": result = game.tea_action_near("H")
        "tea_pour": result = game.tea_action_near("U")
        "meal": result = game.personal_bread_near()
        "wait": result = game.wait_minutes()
        "save": result = game.save_game()
        "open": result = game.open_kiosk()
        "close": result = game.close_kiosk()
        "sleep": result = game.sleep_at_home()
        "quiet": result = game.quiet_near()
        "radio_buy": result = game.buy_radio()
        "radio_place": result = game.place_radio()
        "radio_store": result = game.store_radio()
        "radio_listen": result = game.listen_radio()
        "bed": result = game.bed_near()
        "bed_store": result = game.store_bed()
    if result.get("ok", false):
        notice = {
            "door":"You step into " + game.room() + ".",
            "talk":"You heard something by the kiosk.",
            "serve":str(result.get("caption","Service: " + str(result.get("kind","updated")))),
            "tea_heat":str(result.get("caption","Kettle handled.")),
            "tea_pour":str(result.get("caption","Tea poured.")),
            "meal":str(result.get("caption","Bread prepared.")),
            "wait":"Five quiet minutes pass.",
            "save":"Your evening has been saved.",
            "open":"Kiosk open. Take your time.",
            "close":"Closed for now. Your evening is yours.",
            "sleep":"Another morning begins.",
            "quiet":str(result.get("caption","A quiet moment passes.")),
            "radio_buy":"A secondhand radio is yours. Find a corner for it.",
            "radio_place":"The radio now has a place in your room.",
            "radio_store":"Radio put away safely.",
            "radio_listen":str(result.get("caption","The radio fills the room.")),
            "bed":str(result.get("caption","A bed for home.")),
            "bed_store":"The bed is put away. Sleep will be simpler tonight."
        }.get(kind, "Done")
    else:
        notice = kind.capitalize() + ": " + str(result.get("code","UNKNOWN"))
    report("E6_GAME_" + kind.to_upper())

func _story_action(kind: String, option_id: String = "") -> void:
    var result: Dictionary = {}
    match kind:
        "begin": result = game.river_story_begin()
        "next": result = game.river_story_next()
        "choose": result = game.river_story_choose(option_id)
    if not result.get("ok", false):
        if kind == "begin" and result.get("code", "") == "INK_LOADING":
            story_pending = true
            notice = "Salma is getting ready to talk..."
        else:
            story_pending = false
            notice = "Conversation: " + str(result.get("code", "UNKNOWN"))
        report("E4_STORY_" + ("LOADING" if story_pending else "REJECTED"))
        return
    story_pending = false
    var code: String = str(result.get("code", ""))
    match code:
        "STARTED", "RESUMED":
            story_open = true
            story_line = "Salma is here. Press Enter to listen."
            notice = "A moment beside the Nile."
        "LINE":
            story_open = true
            story_line = str(result.get("speaker_id", "salma")).capitalize() + ": " + str(result.get("text", ""))
        "WAITING":
            story_open = true
            story_line = "What would you like to say?"
        "FINISHED":
            story_open = false
            story_line = ""
            notice = "The conversation settles. You return to the evening."
        _:
            story_open = true
            story_line = "Press Enter to continue."
    report("E4_STORY_" + (code if code in ["STARTED","RESUMED","LINE","WAITING","FINISHED"] else "CHOICE"))

func _unhandled_key_input(event: InputEvent) -> void:
    if not initialized or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if story_open or story_pending:
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER:
                if story_open: _story_action("next")
            KEY_1:
                if story_open: _story_action("choose", "city")
            KEY_2:
                if story_open: _story_action("choose", "rest")
            KEY_ESCAPE:
                story_open = false
                story_pending = false
                story_line = ""
                notice = "You can return to the conversation later."
                report("E4_STORY_DISMISS")
            KEY_P: _act("save")
        return
    match event.keycode:
        KEY_N: _story_action("begin")
        KEY_E: _act("door")
        KEY_F: _act("talk")
        KEY_G: _act("serve")
        KEY_H: _act("tea_heat")
        KEY_U: _act("tea_pour")
        KEY_K: _act("meal")
        KEY_J: _act("wait")
        KEY_P: _act("save")
        KEY_O: _act("open")
        KEY_C: _act("close")
        KEY_Z: _act("sleep")
        KEY_Q: _act("quiet")
        KEY_B: _act("radio_buy")
        KEY_V: _act("radio_place")
        KEY_X: _act("radio_store")
        KEY_R: _act("radio_listen")
        KEY_T: _act("bed")
        KEY_Y: _act("bed_store")

func _iso(point: Vector2) -> Vector2:
    # Deliberately temporary schematic 2:1 layout, NOT production sprite projection.
    return Vector2(480.0 + (point.x-point.y)*1.36, 126.0 + (point.x+point.y)*0.68)

func _floor_polygon(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
    return PackedVector2Array([
        _iso(from_point),
        _iso(Vector2(to_point.x,from_point.y)),
        _iso(to_point),
        _iso(Vector2(from_point.x,to_point.y))
    ])

func _text(p: Vector2, line: String, size: int = 16, color: Color = Color("#eadfc4")) -> void:
    draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _need(at: Vector2, name: String, value: int, color: Color) -> void:
    _text(at,name,13,Color("#d4c9b8"))
    draw_rect(Rect2(at + Vector2(54,-10),Vector2(62,7)),Color("#3b4449"))
    draw_rect(Rect2(at + Vector2(54,-10),Vector2(62.0 * float(value) / 100.0,7)),color)

func _figure(at: Vector2, color: Color, label: String) -> void:
    var foot: Vector2 = _iso(at)
    draw_ellipse(foot+Vector2(0,2),13.0,5.0,Color(0,0,0,0.3))
    draw_rect(Rect2(foot+Vector2(-7,-27),Vector2(14,20)),color)
    draw_circle(foot+Vector2(0,-32),8,Color("#dcae7d"))
    _text(foot+Vector2(-22,-46),label,12,Color("#fff2d5"))

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#101a21"))
    if not initialized:
        _text(Vector2(45,260),notice,20)
        return
    var state: Dictionary = game.status()
    var location: String = state["location"]
    var room: Dictionary = game.graph.rooms[location]
    var max_point: Vector2 = Vector2(room["width"],room["height"])
    var night: bool = state["hour"] >= 18 or state["hour"] < 6
    if location == "kiosk":
        draw_rect(Rect2(0,0,960,200),Color("#113c50") if night else Color("#5788a0"))
        draw_line(Vector2(0,164),Vector2(960,164),Color("#d6ad72"),2)
        for i in range(7):
            draw_line(Vector2(60+i*140,180+i%3*7),Vector2(135+i*140,180+i%3*7),Color("#7b9ca8"),1)
    var floor_color: Color = Color("#68584b") if location in ["roof","flat"] else Color("#706152")
    if location == "kiosk": floor_color = Color("#73675a")
    if location == "landing": floor_color = Color("#80745d")
    draw_colored_polygon(_floor_polygon(Vector2.ZERO,max_point),floor_color)
    for x in range(0,int(max_point.x)+1,40):
        draw_line(_iso(Vector2(x,0)),_iso(Vector2(x,max_point.y)),Color(1,1,1,0.08),1)
    for y in range(0,int(max_point.y)+1,40):
        draw_line(_iso(Vector2(0,y)),_iso(Vector2(max_point.x,y)),Color(1,1,1,0.08),1)
    if location == "roof":
        draw_colored_polygon(_floor_polygon(Vector2(35,30),Vector2(92,95)),Color("#aa947a"))
        draw_colored_polygon(_floor_polygon(Vector2(45,40),Vector2(72,70)),Color("#e1d4ad"))
        draw_colored_polygon(_floor_polygon(Vector2(90,105),Vector2(112,124)),Color("#80564d"))
        _text(_iso(Vector2(62,30))+Vector2(-10,-18),"Rooftop room",12)
    if location == "roof" and state["bed_placed"]:
        draw_colored_polygon(_floor_polygon(Vector2(44,43),Vector2(70,68)),Color("#745e50"))
        draw_colored_polygon(_floor_polygon(Vector2(47,44),Vector2(67,62)),Color("#c7ac83"))
        draw_colored_polygon(_floor_polygon(Vector2(47,44),Vector2(67,51)),Color("#ddd1b3"))
        _text(_iso(Vector2(58,42))+Vector2(-11,-12),"Bed",12)
    if location == "kiosk":
        draw_colored_polygon(_floor_polygon(Vector2(80,55),Vector2(143,115)),Color("#366653"))
        draw_colored_polygon(_floor_polygon(Vector2(94,67),Vector2(134,84)),Color("#bb8a4f"))
        draw_circle(_iso(Vector2(116,80)),8,Color("#e7bc6d"))
        draw_colored_polygon(_floor_polygon(Vector2(94,111),Vector2(135,119)),Color("#a87346"))
        draw_colored_polygon(_floor_polygon(Vector2(168,99),Vector2(177,121)),Color("#607d94"))
        _text(_iso(Vector2(100,50))+Vector2(-18,-18),"Tea counter",12)
    if location == "flat":
        draw_colored_polygon(_floor_polygon(Vector2(48,48),Vector2(104,100)),Color("#ac9078"))
        _text(_iso(Vector2(57,45))+Vector2(-10,-18),"Small apartment",12)
    # Authored quiet spots are world positions, not UI-owned activity state.
    for activity in game.quiet_activities():
        if activity["room_id"] != location: continue
        var center: Vector2 = _iso(Vector2(int(activity["x"]),int(activity["y"])))
        var reachable: bool = game.position().distance_to(Vector2(int(activity["x"]),int(activity["y"]))) <= int(activity["radius"])
        draw_circle(center,7,Color("#f0cb7f") if reachable else Color("#8b8c79"))
        _text(center + Vector2(-32,-17),"Q: " + str(activity["id"]).replace("_"," "),12,
            Color("#f3e1bb") if reachable else Color("#b8a89a"))
    if location == "roof":
        var radio_spot: Dictionary = game.radio_pack.get("activity",{})
        if not radio_spot.is_empty():
            var radio_pos: Vector2 = _iso(Vector2(int(radio_spot["x"]),int(radio_spot["y"])))
            if state["radio_placed"]:
                draw_rect(Rect2(radio_pos + Vector2(-10,-17),Vector2(20,16)),Color("#bb9a69"))
                draw_circle(radio_pos + Vector2(-4,-9),4,Color("#343d3c"))
                draw_rect(Rect2(radio_pos + Vector2(4,-14),Vector2(5,10)),Color("#3d4e50"))
                _text(radio_pos+Vector2(-20,-24),"R: Radio",12)
            else:
                _text(radio_pos+Vector2(-26,-18),"Radio nook",12,Color("#b2a391"))
    for door in game.graph.visible_exits(location):
        var target: Vector2 = _iso(Graph.point(door["entry"]))
        var locked: bool = not door["unit_id"].is_empty() and not game.session.world.can_access_unit(door["unit_id"])
        draw_circle(target,10,Color("#be7472") if locked else Color("#eec47b"))
        _text(target+Vector2(-24,-18),str(door["to"]),12)
    for npc_id in game.graph.anchors:
        var pose: Dictionary = game.npc_pose(str(npc_id))
        if not pose.is_empty() and pose["room_id"] == location:
            _figure(pose["position"],Color("#719f90"),str(npc_id))
            if pose["mode"] in ["approaching","counter","takeaway","table"]:
                _text(_iso(pose["position"])+Vector2(-26,-57),
                    "Ordering" if pose["mode"] == "approaching" else str(pose["mode"]).capitalize(),11,Color("#e8d0a3"))
            var speech: String = ""
            if npc_id == state["customer_reaction_npc"]:
                speech = str(state["customer_reaction"])
            elif npc_id == state["ambient_npc"]:
                speech = str(state["ambient_line"])
            if not speech.is_empty():
                var npc_pos: Vector2 = _iso(pose["position"])
                var left: float = clampf(npc_pos.x - 130.0,16.0,640.0)
                draw_rect(Rect2(left,npc_pos.y-98.0,300.0,28.0),Color("#263a3d"))
                _text(Vector2(left+9.0,npc_pos.y-79.0),speech,14,Color("#f0d6a2"))
    _figure(game.position(),Color("#78a8b8"),"You")
    draw_rect(Rect2(0,0,960,64),Color("#172128"))
    _text(Vector2(24,28),"KIOSK ON THE NILE",22,Color("#efbd73"))
    _text(Vector2(480,27),"Day %d   %02d:%02d" % [state["day"],state["hour"],state["minute_of_hour"]],17)
    _text(Vector2(765,27),"%d piastres" % state["money"],16)
    _text(Vector2(25,53),"KIOSK OPEN" if state["kiosk_open"] else "KIOSK CLOSED",14,
        Color("#abdb9f") if state["kiosk_open"] else Color("#e1aa91"))
    _need(Vector2(245,53),"Hunger",state["hunger"],Color("#d4ae78"))
    _need(Vector2(385,53),"Rest",state["rest"],Color("#8badc6"))
    _need(Vector2(525,53),"Mood",state["mood"],Color("#96b79a"))
    if location == "kiosk" and not state["tea_stage"].is_empty():
        draw_rect(Rect2(0,408,960,38),Color("#263a3d"))
        var guidance: String = "Tea · %s: %s" % [state["tea_action"],
            "Give it %d world minute(s)" % state["tea_ready_in"] if state["tea_ready_in"] > 0 else
            ("Lift / finish" if state["tea_stage"] == "active" else "Start the next step")]
        _text(Vector2(28,431),guidance,18,Color("#f0d6a2"))
    if location == "kiosk" and state["tea_stage"].is_empty() and not state["tea_quality"].is_empty():
        draw_rect(Rect2(0,408,960,38),Color("#263a3d"))
        _text(Vector2(28,431),"Last tea: " + str(state["tea_quality"]) + " · timing stays with the prepared cup",17,Color("#f0d6a2"))
    draw_rect(Rect2(0,447,960,93),Color("#172128"))
    _text(Vector2(28,472),notice,17)
    _text(Vector2(28,500),"WASD move   E door   F listen   G orders   H heat   U pour   Q quiet   O/C open/close",14,Color("#e2c18b"))
    _text(Vector2(480,526),"J wait   P save   N talk to Salma   Radio listens: %d" % state["radio_uses"],13,Color("#e2c18b"))
    if location == "roof":
        _text(Vector2(28,526),"B/V/R/X radio    T buy/place bed (%d)    Y store bed" % state["bed_price"],13,Color("#e2c18b"))
    if location == "kiosk":
        _text(Vector2(205,526),"K prepare/eat personal bread",13,Color("#e2c18b"))
    var near: Dictionary = game.nearest_portal()
    if not near.is_empty():
        _text(Vector2(28,526),"E: " + str(near["to"]),14,Color("#d2b98c"))
    if not state["active_order"].is_empty():
        _text(Vector2(585,526),"Order: " + str(state["order_status"]),14,Color("#d2b98c"))
    if game.river_story_available() and state["river_story_phase"] != "finished" and location == "kiosk":
        var salma: Dictionary = game.npc_pose("salma")
        if not salma.is_empty() and game.position().distance_to(salma["position"]) <= Graph.RADIUS:
            _text(Vector2(710,395),"N · Talk to Salma",15,Color("#f1ca80"))
    if story_open or story_pending:
        draw_rect(Rect2(60,242,840,192),Color("#162d31"))
        draw_rect(Rect2(60,242,840,3),Color("#e1bd81"))
        _text(Vector2(84,280),"By the Nile · Salma",20,Color("#f0d8a8"))
        _text(Vector2(84,315),story_line if not story_pending else "Opening conversation...",17)
        var choices: Array = state["river_story_choices"]
        if choices.is_empty():
            _text(Vector2(84,394),"Enter · Continue       Esc · Leave       P · Save",15,Color("#ddbb7f"))
        else:
            for i in range(mini(choices.size(),2)):
                _text(Vector2(84,356+i*25),"%d · %s" % [i+1, str(choices[i]["text"])],16,Color("#ddbb7f"))
            _text(Vector2(610,411),"Esc · Leave   P · Save",13,Color("#ddbb7f"))
