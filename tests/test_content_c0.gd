extends SceneTree
## CONTENT C0: production content importer, staging rollback, replay and domains.
const World = preload("res://scripts/integration/world_session.gd")
const Bootstrap = preload("res://scripts/integration/world_content_bootstrap.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAMPLE = "res://content/world/qa_nile_kiosk.v1.json"
const SAVE = "user://nk-content-c0.json"
var errors: Array[String] = []

func _initialize() -> void:
    _run()
    if errors.is_empty():
        print("CONTENT C0: PASS (data validation, atomic staging, domain commands, replay and save slot safety)")
        quit(0)
    else:
        for error in errors: push_error(error)
        print("CONTENT C0: FAIL (%d)" % errors.size())
        quit(1)

func check(valid: bool, reason: String) -> void:
    if not valid: errors.append(reason)

func _load_source() -> Dictionary:
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE))
    return data if typeof(data) == TYPE_DICTIONARY else {}

func _cmd(session: RefCounted, key: String, kind: String, payload: Dictionary, actor: String = "player") -> Dictionary:
    return session.command("c0:scenario:" + key, actor, kind, payload)

func _invalid_imports(source: Dictionary) -> void:
    var invalid: Dictionary = source.duplicate(true)
    invalid["schema"] = 2
    check(Bootstrap.prepare(invalid, 42)["code"] == "UNSUPPORTED_BUNDLE_SCHEMA", "schema compatibility")
    invalid = source.duplicate(true)
    invalid["commands"][1]["id"] = invalid["commands"][0]["id"]
    check(Bootstrap.prepare(invalid, 42)["code"] == "DUPLICATE_COMMAND_ID", "repeated ID accepted")
    invalid = source.duplicate(true)
    invalid["commands"][0]["actor_id"] = "player"
    check(Bootstrap.prepare(invalid, 42)["code"] == "DISALLOWED_AUTHORING_COMMAND", "forged source actor")
    invalid = source.duplicate(true)
    invalid["commands"][0]["kind"] = "time.advance"
    invalid["commands"][0]["payload"] = {"steps": 999999}
    check(Bootstrap.prepare(invalid, 42)["code"] == "DISALLOWED_AUTHORING_COMMAND", "arbitrary time execution")
    invalid = source.duplicate(true)
    invalid["commands"][0]["kind"] = "economy.refund"
    check(Bootstrap.prepare(invalid, 42)["code"] == "DISALLOWED_AUTHORING_COMMAND", "arbitrary refund")
    invalid = source.duplicate(true)
    invalid["commands"][6]["payload"]["ingredient_id"] = "leaves"
    check(Bootstrap.prepare(invalid, 42)["code"] == "BUNDLE_COMMAND_REJECTED", "domain conflict partially accepted")
    invalid = source.duplicate(true)
    invalid["commands"][13]["payload"]["steps"][0]["inputs"] = {"nonexistent": 2}
    var bad: Dictionary = Bootstrap.prepare(invalid, 42)
    check(bad["code"] == "BUNDLE_COMMAND_REJECTED" and bad["command_index"] == 13, "dependency-invalid content")
    check(not bad.has("candidate"), "invalid bundle leaked partially populated candidate")
    invalid = source.duplicate(true)
    invalid["commands"].append({"id": "x", "kind": "npc.register", "actor_id": "system:director", "payload": {"npc_id": "x", "location_id": "x"}, "extra": "no"})
    var extra_result: Dictionary = Bootstrap.prepare(invalid, 42)
    check(extra_result["code"] == "INVALID_ENTRY", "extra unreviewed directive accepted: "+JSON.stringify(extra_result))
    invalid = source.duplicate(true)
    invalid["commands"] = []
    check(Bootstrap.prepare(invalid, 42)["code"] == "INVALID_COMMAND_LIST", "empty bootstrap accepted")
    check(Bootstrap.from_file("user://other.json",42)["code"] == "UNTRUSTED_CONTENT_PATH", "untrusted user writable import")
    check(Bootstrap.from_file("res://content/world/../other.json",42)["code"] == "UNTRUSTED_CONTENT_PATH", "content traversal")
    check(Bootstrap.from_file("res://content/world/no_such_file.json",42)["code"] == "CONTENT_NOT_FOUND", "missing authored asset")
    check(Bootstrap.prepare(source, 0)["code"] == "INVALID_SEED", "invalid world seed")

func _run() -> void:
    for path in [SAVE, SAVE + ".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var source: Dictionary = _load_source()
    check(not source.is_empty(), "QA content fixture not found")
    if source.is_empty(): return
    _invalid_imports(source)
    var staged: Dictionary = Bootstrap.from_file(SAMPLE, 42)
    check(staged.get("ok",false), "valid content staged: "+JSON.stringify(staged))
    if not staged.get("ok",false): return
    var first: RefCounted = staged["candidate"]
    var repeated: Dictionary = Bootstrap.prepare(source, 42)
    check(repeated.get("ok",false), "repeat stage")
    if not repeated.get("ok",false): return
    check(JSON.stringify(first.view()) == JSON.stringify(repeated["candidate"].view()), "not byte-identical deterministic import")
    check(first.view()["sequence"] == source["commands"].size(), "not one event per authored command")
    check(first.view()["version"] == 8, "world schema accidentally changed")
    check(first.view()["world_minute"] == 0, "import advanced time")
    check(first.npc("amina")["location_id"] == "kiosk", "registered NPC absent")
    check(first.npc("reda")["location_id"] == "street", "registered routine origin")
    check(first.npc_routines().has("workday"), "registered routine missing")
    check(first.cooking_view()["recipes"].has("tea") and first.cooking_view()["recipes"].has("plain_bread"), "authored recipes absent")
    check(first.cooking_view()["stock"]["leaves"] == 24, "authored quantity lost")
    check(first.balance_minor() == 300, "authored funds lost")
    check(first.can_access_unit("roof") and not first.can_access_unit("flat"), "unauthorized flat access")
    check(first.housing_view()["units"]["flat"]["area_sqm"] == 60, "authored unit topology lost")
    var replay: RefCounted = Kernel.new()
    check(replay.restore_snapshot(first.view()) and JSON.stringify(replay.view()) == JSON.stringify(first.view()), "canonical replay changed content import")
    var session: RefCounted = World.new(42,SAVE)
    check(session.world.view()["sequence"] == 0, "new world unexpectedly populated")
    var bad_content: Dictionary = session.bootstrap_from_content("res://content/world/missing.json")
    check(not bad_content.get("ok",false) and session.world.view()["sequence"] == 0, "failed boot mutated live session")
    var accepted: Dictionary = session.bootstrap_from_content(SAMPLE)
    check(accepted.get("ok",false) and accepted.get("commands") == 24, "session did not apply catalog")
    check(JSON.stringify(session.world.view()) == JSON.stringify(first.view()), "session staged world differs")
    check(session.bootstrap_from_content(SAMPLE)["code"] == "WORLD_ALREADY_INITIALIZED", "duplicate catalog import")
    # Continue through real domain commands; the authored price/rent are QA data only.
    check(_cmd(session,"player_to_kiosk","social.player.place",{"location_id":"kiosk"},"system:director").get("ok",false), "player arrives")
    check(_cmd(session,"offer","order.offer",{"order_id":"o1","venue_id":"kiosk","npc_id":"amina","recipe_id":"tea","route":"counter","deadline_minute":45},"amina").get("ok",false), "customer offer")
    check(_cmd(session,"accept","order.accept",{"order_id":"o1","seat_id":""}).get("ok",false), "customer acceptance")
    check(_cmd(session,"start_cooking","cook.start",{"job_id":"cup1","recipe_id":"tea","deadline_minute":45}).get("ok",false), "cooking start")
    check(_cmd(session,"heat","cook.step.begin",{"job_id":"cup1","station_id":"kettle"}).get("ok",false), "recipe heat step")
    check(session.advance(2,"c0:advance:heat").get("ok",false), "heat time")
    check(_cmd(session,"finish_heat","cook.step.finish",{"job_id":"cup1"}).get("ok",false), "finish first step")
    check(_cmd(session,"serve_step","cook.step.begin",{"job_id":"cup1","station_id":"counter"}).get("ok",false), "recipe service step")
    check(session.advance(1,"c0:advance:serve").get("ok",false), "serve time")
    check(_cmd(session,"complete","cook.step.finish",{"job_id":"cup1"}).get("ok",false), "prepared item")
    check(_cmd(session,"deliver","order.deliver",{"order_id":"o1","item_id":"item:cup1"}).get("ok",false), "deliver")
    check(_cmd(session,"quote","economy.order.quote",{"claim_id":"payment:order:o1"},"system:pricing").get("ok",false), "quote catalog price")
    check(_cmd(session,"settle","economy.order.settle",{"claim_id":"payment:order:o1","transaction_id":"sale:c0"},"system:service").get("ok",false), "settle authored price")
    check(session.world.balance_minor() == 317, "catalog price not used in ledger")
    check(_cmd(session,"rent","housing.lease.start",{"lease_id":"tenant","unit_id":"flat","transaction_id":"rent:start"}).get("ok",false), "rent authored apartment")
    check(session.world.balance_minor() == 167 and session.world.can_access_unit("flat"), "catalog rent not applied")
    check(session.save().get("ok",false), "disk save canonical imported world")
    var expected: String = JSON.stringify(session.world.view())
    var loaded: RefCounted = World.new(77,SAVE)
    check(loaded.bootstrap_from_content(SAMPLE)["code"] == "SAVE_EXISTS", "overwrote pre-existing player save")
    check(loaded.world.view()["sequence"] == 0, "refused import modified new instance")
    check(loaded.load_existing().get("code") == "RESTORED", "real save lost")
    check(JSON.stringify(loaded.world.view()) == expected, "disk replay after catalog import")
    check(loaded.save().get("ok",false) and JSON.stringify(loaded.world.view()) == expected, "unchanged save duplicated effects")
    for path in [SAVE, SAVE + ".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
