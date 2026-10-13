extends SceneTree
## PLAY C1: actual C0 world + authored graph, not a V001 or D001 spike.
const Session = preload("res://scripts/integration/world_session.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const CATALOG = "res://content/world/qa_nile_kiosk.v1.json"
const ROUTES = "res://content/navigation/qa_routes.v1.json"
const SAVE = "user://nk-play-c1-qa-test.json"
var errors: Array[String] = []

func _initialize() -> void:
    _run()
    if errors.is_empty():
        print("PLAY C1: PASS (graph validation, actual movement, portal rights, hearing and reload)")
        quit(0)
    else:
        for x in errors: push_error(x)
        print("PLAY C1: FAIL (%d)" % errors.size())
        quit(1)

func check(ok: bool, message: String) -> void:
    if not ok: errors.append(message)

func _run() -> void:
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var parsed: Dictionary = Graph.load_packaged(ROUTES)
    check(parsed.get("ok", false), "valid route load: "+str(parsed.get("code")))
    if not parsed.get("ok", false): return
    var g: RefCounted = parsed["graph"]
    var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
    var broken: Dictionary = source.duplicate(true)
    broken["portals"][0]["to"] = "nowhere"
    check(Graph.from_data(broken)["code"] == "INVALID_PORTAL_LINK", "unknown destination accepted")
    broken = source.duplicate(true)
    broken["portals"][1]["id"] = broken["portals"][0]["id"]
    check(Graph.from_data(broken)["code"] == "INVALID_PORTAL_LINK", "duplicate portal accepted")
    broken = source.duplicate(true)
    broken["rooms"][0]["spawn"] = [-1, 100]
    check(Graph.from_data(broken)["code"] == "INVALID_ROOM_SPAWN", "invalid spawn accepted")
    broken = source.duplicate(true)
    broken["anchors"][0]["room_id"] = "void"
    check(Graph.from_data(broken)["code"] == "INVALID_ANCHOR", "invalid NPC anchor accepted")
    broken = source.duplicate(true)
    broken["schema"] = 2
    check(Graph.from_data(broken)["code"] == "UNSUPPORTED_GRAPH", "unsupported schema accepted")
    check(Graph.load_packaged("user://qa_routes.json")["code"] == "UNTRUSTED_GRAPH_PATH", "user-writable graph accepted")
    check(Graph.load_packaged("res://content/navigation/../world/file.json")["code"] == "UNTRUSTED_GRAPH_PATH", "path traversal accepted")
    check(Graph.load_packaged("res://content/navigation/not-here.json")["code"] == "GRAPH_NOT_FOUND", "missing asset accepted")
    check(g.move("roof", Vector2(10,10), Vector2(-18,0))["code"] == "WALL", "walked through room bounds")
    check(g.move("roof", Vector2(10,10), Vector2(40,0))["code"] == "INVALID_MOVE", "unbounded movement")
    check(g.move("roof", Vector2(10,10), Vector2(18,0))["ok"], "normal movement refused")
    var session = Session.new(23,SAVE)
    check(session.bootstrap_from_content(CATALOG).get("ok", false), "C0 catalog bootstrapping")
    var initial: Dictionary = session.world.view()
    check(initial["society"]["player_location"] == "roof", "authored roof start")
    var spawn: Dictionary = g.spawn_for("roof")
    check(spawn.get("ok", false) and spawn["position"] == Vector2(175,70), "authored spawn point")
    check(g.travel(session, "landing_to_roof", Vector2(35,70), "c1:wrong")["code"] == "WRONG_ROOM", "remote portal crossed")
    check(g.travel(session, "roof_to_landing", Vector2(0,0), "c1:far")["code"] == "TOO_FAR", "remote travel")
    check(session.world.view()["sequence"] == initial["sequence"], "rejected travel generated world event")
    var first: Dictionary = g.travel(session, "roof_to_landing", spawn["position"], "c1:roof_to_landing")
    check(first.get("ok",false) and first["location_id"] == "landing", "roof to landing")
    check(session.world.social_view()["player_location"] == "landing", "traversal did not update kernel")
    check(g.travel(session, "landing_to_flat", Vector2(120,35), "c1:flat:deny")["code"] == "ACCESS_DENIED", "unpaid south flat entered")
    check(session.world.social_view()["player_location"] == "landing", "locked flat modified location")
    check(g.travel(session, "landing_to_street", Vector2(210,70), "c1:street")["ok"], "landing to street")
    check(g.travel(session, "street_to_kiosk", Vector2(205,70), "c1:kiosk")["ok"], "street to kiosk")
    check(not session.world.player_knows("weather:nile"), "knowledge leaked before talk")
    check(g.overhear(session, Vector2(10,10), "c1:too_far")["code"] == "NO_NEARBY_NPC", "hearing without proximity")
    var heard: Dictionary = g.overhear(session, Vector2(125,70), "c1:heard:1")
    check(heard.get("ok",false) and heard.get("fact_id") == "weather:nile", "nearby NPC did not speak authored fact")
    check(session.world.player_knows("weather:nile"), "P2 first heard not recorded")
    var repeat: Dictionary = g.overhear(session, Vector2(125,70), "c1:heard:2")
    check(repeat["code"] == "NO_AUTHORED_PUBLIC_FACT", "repeat encounter invented new facts")
    check(g.travel(session, "kiosk_to_street", Vector2(35,70), "c1:leave")["ok"], "leave kiosk")
    check(g.overhear(session, Vector2(125,70), "c1:remote")["code"] == "NO_NEARBY_NPC", "player remote overheard NPC")
    check(g.travel(session, "street_to_landing", Vector2(40,70), "c1:back")["ok"], "return from street")
    var rented: Dictionary = session.command("c1:rent","player","housing.lease.start",
        {"lease_id":"c1:lease","unit_id":"flat","transaction_id":"c1:initial-rent"})
    check(rented.get("ok",false), "rent authored south flat")
    check(session.world.balance_minor() == 150 and session.world.can_access_unit("flat"), "housing ledger charge/access")
    check(g.travel(session, "landing_to_flat", Vector2(120,35), "c1:flat:enter")["ok"], "legit flat travel")
    check(session.world.social_view()["player_location"] == "flat", "flat location not canonical")
    var before: Dictionary = session.world.view()
    check(session.save().get("ok", false), "disk save")
    var restored = Session.new(999,SAVE)
    check(restored.load_existing().get("code") == "RESTORED", "saved world did not reload")
    check(JSON.stringify(restored.world.view()) == JSON.stringify(before), "world changed across save")
    check(g.spawn_for(restored.world.social_view()["player_location"])["position"] == Vector2(55,80), "canonical room didn't restore spawn")
    check(g.travel(restored,"flat_to_landing",Vector2(40,80),"c1:flat:leave")["ok"], "exit rented flat")
    check(restored.world.social_view()["player_location"]=="landing", "world location didn't follow portal")
    check(restored.save().get("ok",false), "second save")
    var second: Dictionary=restored.world.view()
    var third=Session.new(7,SAVE)
    check(third.load_existing().get("ok",false),"second reload")
    check(JSON.stringify(third.world.view())==JSON.stringify(second),"second reload mutated events")
    check(third.save().get("ok",false) and JSON.stringify(third.world.view())==JSON.stringify(second),"repeat save created duplicate event")
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
