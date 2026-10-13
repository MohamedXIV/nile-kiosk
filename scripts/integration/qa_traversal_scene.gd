extends Node2D
## PLAY C1 — QA-only traversable gameplay adapter backed by CONTENT C0 + SYS P0-P7.
## No V001 art, no scene-owned location/knowledge/ledger/save authority.
const Session = preload("res://scripts/integration/world_session.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const CATALOG: String = "res://content/world/qa_nile_kiosk.v1.json"
const ROUTES: String = "res://content/navigation/qa_routes.v1.json"
const SAVE: String = "user://nk-play-c1-web-qa.json"
var model: RefCounted
var graph: RefCounted
var actor_position: Vector2 = Vector2.ZERO
var initialized: bool = false
var notice: String = "Booting authored world..."
var last_marker: String = ""

func _ready() -> void:
    model = Session.new(31,SAVE)
    call_deferred("_boot")

func _boot() -> void:
    var existing: Dictionary = model.load_existing()
    if not existing.get("ok",false):
        push_error("PLAY_C1_WORLD_SAVE_FAILED "+str(existing))
        return
    if existing["code"] == "NEW_WORLD":
        var boot: Dictionary = model.bootstrap_from_content(CATALOG)
        if not boot.get("ok",false):
            push_error("PLAY_C1_CONTENT_FAILED "+str(boot))
            return
    var nav: Dictionary = model.configure_navigation(ROUTES)
    if not nav.get("ok",false):
        push_error("PLAY_C2_NAV_FAILED "+str(nav))
        return
    var graph_check: Dictionary = Graph.from_data(model.world.spatial_view()["graph"])
    if not graph_check.get("ok",false):
        push_error("PLAY_C2_SAVED_GRAPH_FAILED "+str(graph_check))
        return
    graph = graph_check["graph"]
    _sync_position()
    initialized = true
    notice = "WASD move, E doorway, F listen, R rent, P save, T pass time"
    report("PLAY_C1_RESTORED" if existing["code"]=="RESTORED" else "PLAY_C1_READY")

func _sync_position() -> void:
    var pose: Dictionary = model.world.spatial_view()["player"]
    actor_position = Vector2(int(pose["x"]), int(pose["y"]))

func current_room() -> String:
    return str(model.world.social_view()["player_location"])

func world_state() -> Dictionary:
    var state: Dictionary = model.world.view()
    return {"location":current_room(),"x":int(actor_position.x),"y":int(actor_position.y),
        "minute":state["world_minute"],"revision":state["sequence"],
        "digest":JSON.stringify(state).sha256_text(),
        "known":model.world.player_knows("weather:nile"),
        "money":model.world.balance_minor(),"flat_access":model.world.can_access_unit("flat"),
        "npc_reda":model.world.npc("reda").get("location_id",""),
        "pending_rent":state["housing"]["leases"].size(),
        "saved_revision":model.last_save_revision}

func report(marker: String) -> void:
    last_marker = marker
    print(marker+" "+JSON.stringify(world_state()))
    queue_redraw()

func _try_travel() -> void:
    var exits: Array[Dictionary] = graph.visible_exits(current_room())
    var near: Array[Dictionary] = []
    for door in exits:
        var dist: float = actor_position.distance_to(Graph.point(door["entry"]))
        if dist <= Graph.RADIUS:
            near.append({"id":door["id"],"distance":dist})
    if near.is_empty():
        notice = "Walk closer to a doorway."
        queue_redraw()
        return
    near.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return a["distance"] < b["distance"] if a["distance"] != b["distance"] else a["id"] < b["id"])
    var nearest: String = near[0]["id"]
    var current_revision: int = int(model.world.view()["sequence"])
    var result: Dictionary = model.command("play:c2:route:"+str(current_revision+1)+":"+nearest,
        "player", "spatial.player.travel", {"portal_id": nearest})
    if not result.get("ok",false):
        notice = "Doorway: "+str(result.get("code"))
        report("PLAY_C1_DENIED")
        return
    _sync_position()
    notice = "Entered "+current_room()
    report("PLAY_C1_TRAVEL")

func _listen() -> void:
    var result: Dictionary = graph.overhear(model,actor_position,
        "play:c1:listen:"+str(int(model.world.view()["sequence"])+1))
    if result.get("ok",false):
        notice = "Heard "+str(result["fact_id"])+" from "+str(result["npc_id"])
        report("PLAY_C1_HEARD")
    else:
        notice = "Listening: "+str(result.get("code","UNKNOWN"))
        queue_redraw()

func _rent() -> void:
    var loc: String = current_room()
    var units: Dictionary = model.world.housing_view()["units"]
    var keys: Array = units.keys()
    keys.sort()
    for unit_id in keys:
        var unit: Dictionary = units[unit_id]
        if unit["kind"] != "apartment" or model.world.can_access_unit(unit_id):
            continue
        var reachable: bool = false
        for door in graph.visible_exits(loc):
            if door["unit_id"] == unit_id and actor_position.distance_to(Graph.point(door["entry"])) <= Graph.RADIUS:
                reachable = true
        if not reachable: continue
        var revision: int = int(model.world.view()["sequence"])+1
        var result: Dictionary = model.command("play:c1:lease:"+str(revision),"player",
            "housing.lease.start",{"lease_id":"play:c1:lease:"+str(revision),
            "unit_id":unit_id,"transaction_id":"play:c1:rent:"+str(revision)})
        if not result.get("ok",false):
            notice = "Rental: "+str(result.get("code"))
            report("PLAY_C1_DENIED")
            return
        notice = "Apartment rented from the authored catalog."
        report("PLAY_C1_RENTED")
        return
    notice = "No unrented apartment doorway nearby."
    queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not initialized or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var direction: Vector2 = Vector2.ZERO
    match event.keycode:
        KEY_W, KEY_UP: direction = Vector2(0,-Graph.STEP)
        KEY_S, KEY_DOWN: direction = Vector2(0,Graph.STEP)
        KEY_A, KEY_LEFT: direction = Vector2(-Graph.STEP,0)
        KEY_D, KEY_RIGHT: direction = Vector2(Graph.STEP,0)
        KEY_E: _try_travel()
        KEY_F: _listen()
        KEY_R: _rent()
        KEY_P:
            var saved: Dictionary = model.save()
            if saved.get("ok",false):
                notice = "Whole-world save verified."
                report("PLAY_C1_SAVED")
            else:
                push_error("PLAY_C1_SAVE_FAILED "+str(saved))
        KEY_T:
            var revision: int = int(model.world.view()["sequence"])+1
            var jump: Dictionary = model.advance(5,"play:c1:time:"+str(revision))
            if jump.get("ok",false):
                notice = "Canonical world advanced five minutes."
                report("PLAY_C1_TIME")
            else:
                notice = "Time: "+str(jump.get("code"))
    if direction != Vector2.ZERO:
        var seq: int = int(model.world.view()["sequence"])+1
        var moved: Dictionary = model.command("play:c2:move:"+str(seq),
            "player", "spatial.player.move", {"dx":int(direction.x), "dy":int(direction.y)})
        if moved.get("ok",false):
            _sync_position()
        else:
            notice = "Boundary: "+str(moved.get("code"))
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#1c242b"))
    draw_rect(Rect2(0,0,960,68),Color("#324b51"))
    draw_string(ThemeDB.fallback_font,Vector2(20,30),"NILE KIOSK / C1 TRAVERSABLE QA SCENE",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
    if not initialized:
        draw_string(ThemeDB.fallback_font,Vector2(30,125),notice,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
        return
    var room: String = current_room()
    var r: Dictionary = graph.rooms[room]
    var scale_map: float = 1.8
    var origin: Vector2 = Vector2(60,104)
    draw_rect(Rect2(origin.x,origin.y,float(r["width"])*scale_map,float(r["height"])*scale_map),Color("#35464a"))
    draw_rect(Rect2(origin.x,origin.y,float(r["width"])*scale_map,float(r["height"])*scale_map),Color("#98aaa8"),false,2)
    for door in graph.visible_exits(room):
        var entry: Vector2 = origin+Graph.point(door["entry"])*scale_map
        var color: Color = Color("#dcba78")
        if not door["unit_id"].is_empty() and not model.world.can_access_unit(door["unit_id"]):
            color=Color("#c77878")
        draw_circle(entry,11.0,color)
        draw_string(ThemeDB.fallback_font,entry+Vector2(-20,-16),door["to"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
    var anchor_keys: Array = graph.anchors.keys()
    anchor_keys.sort()
    for npc_id in anchor_keys:
        var a: Dictionary = graph.anchors[npc_id]
        if a["room_id"] != room or model.world.npc(npc_id).get("location_id","") != room:
            continue
        var here: Vector2 = origin+Graph.point(a["point"])*scale_map
        draw_circle(here,12,Color("#9cbe92"))
        draw_string(ThemeDB.fallback_font,here+Vector2(-20,-20),str(npc_id),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
    var actor: Vector2 = origin+actor_position*scale_map
    draw_circle(actor,11,Color("#eeeecc"))
    var s: Dictionary = world_state()
    var lines: Array = [
        notice,
        "Room: %s  /  Time: %s  /  Revision: %s" % [room,s["minute"],s["revision"]],
        "Cash: %s minor units  /  Flat access: %s" % [s["money"],s["flat_access"]],
        "Heard Nile fact: %s  /  Reda: %s" % [s["known"],s["npc_reda"]],
        "QA CONTENT — prices, route drawings and NPC labels are NOT final game art."
    ]
    for i in range(lines.size()):
        draw_string(ThemeDB.fallback_font,Vector2(510,115+i*51),str(lines[i]),HORIZONTAL_ALIGNMENT_LEFT,410,15,Color("#ece5d4"))
