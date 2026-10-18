extends RefCounted
## E4/E5 production adapter. All history, choices, knowledge and money live
## in WorldKernel; this object owns packaged content and proximity queries only.
const POLICY = "res://content/social/nile_returning_customer.v1.json"
const FACT = "mahmoud:tea-supplier"
const STORY = "returning_customer"
const RADIUS = 38.0
var pack: Dictionary = {}

func configure(session: RefCounted) -> Dictionary:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(POLICY))
    if typeof(raw) != TYPE_DICTIONARY or raw.get("schema") != 1 or raw.get("npc_id") != "mahmoud" or raw.get("venue_id") != "kiosk" or typeof(raw.get("story")) != TYPE_DICTIONARY or raw.get("ink_path") != "res://content/ink/nile_returning_customer.ink.json":
        return {"ok":false,"code":"INVALID_CUSTOMER_MEMORY_CONTENT"}
    pack = raw.duplicate(true)
    if not session.world.social_view()["social_facts"].has(FACT):
        var fact: Dictionary = session.command("game:memory:supplier-fact:v1","system:director",
            "social.fact.register",{"fact_id":FACT,"source_npc_id":pack["npc_id"],"visibility":"public"})
        if not fact.get("ok",false): return fact
    if not session.world.narrative_view()["stories"].has(STORY):
        return session.command("game:memory:story:v1","system:narrative","narrative.story.register",pack["story"])
    return {"ok":true,"code":"CONFIGURED"}

func memory(session: RefCounted) -> Dictionary:
    return session.world.customer_memory(pack["npc_id"],pack["venue_id"])

func session_id(session: RefCounted) -> String:
    # Resume an unfinished conversation before opening another encounter.
    var latest: Dictionary = {}
    for s in session.world.narrative_view()["sessions"].values():
        if s["story_id"] == STORY and s["phase"] != "finished" and (latest.is_empty() or str(s["started_event_id"]) > str(latest["started_event_id"])):
            latest = s
    if not latest.is_empty(): return latest["session_id"]
    var current: Dictionary = memory(session)
    return "memory:"+str(current["return_order_id"]) if not current.is_empty() else ""

func state(session: RefCounted) -> Dictionary:
    return session.world.narrative_session(session_id(session))

func near(session: RefCounted, graph: RefCounted) -> bool:
    if session.world.social_view()["player_location"] != pack["venue_id"]: return false
    var pose: Dictionary = graph.npc_pose(session,pack["npc_id"])
    var p: Dictionary = session.world.spatial_view()["player"]
    return not pose.is_empty() and pose["room_id"] == pack["venue_id"] and Vector2(p["x"],p["y"]).distance_to(pose["position"]) <= RADIUS

func available(session: RefCounted, graph: RefCounted) -> bool:
    return not session_id(session).is_empty() and state(session).get("phase","") != "finished" and near(session,graph)

func begin(session: RefCounted, graph: RefCounted, command_id: String) -> Dictionary:
    var id: String = session_id(session)
    if id.is_empty(): return {"ok":false,"code":"NO_CUSTOMER_MEMORY"}
    var previous: Dictionary = state(session)
    if previous.get("phase","") == "finished": return {"ok":false,"code":"STORY_ALREADY_FINISHED"}
    if not near(session,graph): return {"ok":false,"code":"CUSTOMER_TOO_FAR"}
    if session.ink == null or not session.ink.sessions.has(id):
        if not session.attach_ink(id,pack["ink_path"]): return {"ok":false,"code":"INK_STORY_NOT_FOUND"}
    if not session.ink_ready(id): return {"ok":false,"code":"INK_LOADING"}
    if not previous.is_empty(): return {"ok":true,"code":"RESUMED","phase":previous["phase"]}
    var result: Dictionary = session.ink_begin(id,STORY,[pack["npc_id"],"player"],command_id)
    if result.get("ok",false): result["code"] = "STARTED"
    return result

func next(session: RefCounted, graph: RefCounted, command_id: String) -> Dictionary:
    if not near(session,graph): return {"ok":false,"code":"CUSTOMER_TOO_FAR"}
    return session.ink_next(session_id(session),command_id)

func choose(session: RefCounted, graph: RefCounted, option_id: String, command_id: String) -> Dictionary:
    if not near(session,graph): return {"ok":false,"code":"CUSTOMER_TOO_FAR"}
    return session.ink_choose(session_id(session),option_id,command_id)
