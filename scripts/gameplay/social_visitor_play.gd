extends RefCounted
## One authored nonbuyer visit: P2/P1/P6 own the truth, Godot graph owns a
## reversible animation from authoritative routine firings.
const PATH = "res://content/social/nile_mona_visit.v1.json"
const WorldState = preload("res://scripts/core/world_state.gd")
const STORY_ID = "mona_visits_salma"
const RADIUS = 38.0
var pack: Dictionary = {}

func configure(session: RefCounted, graph: RefCounted) -> Dictionary:
    if not FileAccess.file_exists(PATH): return {"ok":false,"code":"SOCIAL_VISIT_NOT_FOUND"}
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if typeof(raw) != TYPE_DICTIONARY or raw.size() != 11 or raw.get("schema") != 1:
        return {"ok":false,"code":"INVALID_SOCIAL_VISIT"}
    if raw.get("npc_id") != "mona" or raw.get("routine_id") != "mona_salma_visit" or raw.get("room_id") != "kiosk" or raw.get("opportunity_id") != STORY_ID:
        return {"ok":false,"code":"INVALID_SOCIAL_VISIT"}
    if typeof(raw.get("story")) != TYPE_DICTIONARY or raw["story"].get("story_id","") != STORY_ID:
        return {"ok":false,"code":"INVALID_SOCIAL_STORY"}
    if typeof(raw.get("ink_path")) != TYPE_STRING or not str(raw["ink_path"]).begins_with("res://content/ink/") or not str(raw["ink_path"]).ends_with(".ink.json") or str(raw["ink_path"]).contains(".."):
        return {"ok":false,"code":"INVALID_SOCIAL_INK"}
    var initiative: Variant = raw.get("npc_initiation")
    if typeof(initiative) != TYPE_DICTIONARY or initiative.size() != 2 or \
            not initiative.has("after_minutes") or not initiative.has("within_minutes") or \
            not WorldState.integral(initiative["after_minutes"],0,120) or \
            not WorldState.integral(initiative["within_minutes"],1,120) or \
            int(initiative["within_minutes"]) <= int(initiative["after_minutes"]):
        return {"ok":false,"code":"INVALID_SOCIAL_NPC_INITIATION"}
    var route: Dictionary = raw.duplicate(true)
    route.erase("story")
    route.erase("npc_initiation")
    var configured: Dictionary = graph.configure_social_visit(route,session)
    if not configured.get("ok",false): return configured
    if not session.world.narrative_view()["stories"].has(STORY_ID):
        var registered: Dictionary = session.command("game:e4:mona:story:v1","system:narrative",
            "narrative.story.register",raw["story"])
        if not registered.get("ok",false): return registered
    pack = raw.duplicate(true)
    return {"ok":true}

func session_state(session: RefCounted) -> Dictionary:
    return session.world.narrative_session(STORY_ID)

func near(session: RefCounted, graph: RefCounted) -> bool:
    if pack.is_empty() or not session.world.narrative_opportunities().has(STORY_ID):
        return false
    if session_state(session).get("phase","") == "finished": return false
    var player: Dictionary = session.world.spatial_view()["player"]
    if player["room_id"] != pack["room_id"]: return false
    var npc: Dictionary = session.world.npc("mona")
    if npc.get("location_id","") != pack["room_id"] or npc.get("routine_id","") != pack["routine_id"]:
        return false
    var pose: Dictionary = graph.npc_pose(session,"mona")
    if pose.is_empty() or pose.get("mode","") == "leaving": return false
    return Vector2(float(player["x"]),float(player["y"])).distance_to(pose["position"]) <= RADIUS

# One authored visit greeting. The player must actually be near when Mona
# initiates. No invented social event, timer or relationship penalty is
# committed: the P6 source event, cursor and reply deadline are canonical.
func initiation_ready(session: RefCounted, graph: RefCounted) -> bool:
    var offered: Dictionary = session.world.narrative_opportunities().get(STORY_ID,{})
    if offered.is_empty() or not session_state(session).is_empty() or \
            not near(session,graph):
        return false
    var now: int = int(session.world.view()["world_minute"])
    var elapsed: int = now - int(offered.get("world_minute",-1))
    var policy: Dictionary = pack.get("npc_initiation",{})
    return not policy.is_empty() and elapsed >= int(policy["after_minutes"]) and \
        elapsed < int(policy["within_minutes"])

# The actual opening still requires proximity; subsequent answers are valid
# only while player and visitor share the same kiosk and the P6 window lives.
func exchange_available(session: RefCounted) -> bool:
    var active: Dictionary = session_state(session)
    if active.get("phase","") not in ["running","choice"]:
        return false
    if session.world.spatial_view()["player"].get("room_id","") != "kiosk" or \
            session.world.npc("mona").get("location_id","") != "kiosk":
        return false
    var deadline: int = int(active.get("reply_deadline_minute",-1))
    return deadline < 0 or int(session.world.view()["world_minute"]) < deadline

func begin(session: RefCounted, graph: RefCounted, command_id: String) -> Dictionary:
    if not session.world.narrative_opportunities().has(STORY_ID):
        return {"ok":false,"code":"VISIT_NOT_AVAILABLE"}
    if session_state(session).get("phase","") == "finished":
        return {"ok":false,"code":"STORY_ALREADY_FINISHED"}
    if not near(session,graph):
        return {"ok":false,"code":"MONA_TOO_FAR"}
    if session.ink == null or not session.ink.sessions.has(STORY_ID):
        if not session.attach_ink(STORY_ID,pack["ink_path"]):
            return {"ok":false,"code":"INK_STORY_NOT_FOUND"}
    if not session.ink_ready(STORY_ID): return {"ok":false,"code":"INK_LOADING"}
    if not session_state(session).is_empty():
        return {"ok":true,"code":"RESUMED","phase":session_state(session)["phase"]}
    var result: Dictionary = session.ink_begin_opportunity(STORY_ID,STORY_ID,
        ["mona","player"],command_id)
    if result.get("ok",false): result["code"] = "STARTED"
    return result

func next(session: RefCounted, command_id: String) -> Dictionary:
    if not exchange_available(session): return {"ok":false,"code":"MONA_LEFT_OR_TIMED_OUT"}
    if not session.ink_ready(STORY_ID): return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_next(STORY_ID,command_id)

func choose(session: RefCounted, option_id: String, command_id: String) -> Dictionary:
    if not exchange_available(session): return {"ok":false,"code":"MONA_LEFT_OR_TIMED_OUT"}
    if not session.ink_ready(STORY_ID): return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_choose(STORY_ID,option_id,command_id)
