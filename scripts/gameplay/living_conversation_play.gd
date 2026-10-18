extends RefCounted
## Content/input adapter only: P1 timeline, P6 sessions and P2 facts own truth.
const Rules = preload("res://scripts/core/conversation_rules.gd")
const PATH = "res://content/social/nile_neighbors_conversation.v1.json"
const STORY = "river_neighbors"
var pack: Dictionary = {}
func configure(session: RefCounted) -> Dictionary:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=4 or raw.get("schema")!=1 or typeof(raw.get("story"))!=TYPE_DICTIONARY or raw["story"].get("story_id","")!=STORY or raw.get("ink_path")!="res://content/ink/nile_neighbors_conversation.ink.json":
        return {"ok":false,"code":"INVALID_CONVERSATION_PACK"}
    pack=raw.duplicate(true)
    if not session.world.social_view()["social_facts"].has(pack["fact"]["fact_id"]):
        var fact: Dictionary = session.command("game:neighbors:fact:v1","system:director","social.fact.register",pack["fact"])
        if not fact.get("ok",false): return fact
    if not session.world.narrative_view()["stories"].has(STORY):
        return session.command("game:neighbors:story:v1","system:narrative","narrative.story.register",pack["story"])
    return {"ok":true}
func id(session: RefCounted) -> String:
    # Unfinished accepted response remains resumable after its original day.
    for s in session.world.narrative_view()["sessions"].values():
        if s["story_id"]==STORY and s["phase"]!="finished": return s["session_id"]
    return str(session.world.conversation_view(STORY).get("session_id",""))
func state(session: RefCounted) -> Dictionary: return session.world.narrative_session(id(session))
func near(session: RefCounted, graph: RefCounted) -> bool:
    if pack.is_empty(): return false
    return Rules.near(pack["story"]["conversation"],session,graph)
func available(session: RefCounted, graph: RefCounted) -> bool:
    if not near(session,graph): return false
    var s: Dictionary = state(session)
    return s.get("phase","")!="finished" and (not s.is_empty() or session.world.conversation_view(STORY).get("joinable",false))
func ambient(session: RefCounted, graph: RefCounted) -> Dictionary:
    if pack.is_empty(): return {}
    var c: Dictionary = pack["story"]["conversation"]
    var v: Dictionary = session.world.conversation_view(STORY)
    if v.get("beat",-1)<0: return {}
    var player: Dictionary = session.world.spatial_view()["player"]
    if player["room_id"]!=c["room_id"] or not graph.npcs_have_visual_contact(session,c["participants"][0],c["participants"][1]): return {}
    var pose: Dictionary = graph.npc_pose(session,v["npc_id"])
    if pose.is_empty() or Vector2(float(player["x"]),float(player["y"])).distance_to(pose["position"])>Rules.HEARING: return {}
    return {"npc_id":v["npc_id"],"line":v["line"],"beat":v["beat"]}
func begin(session: RefCounted, graph: RefCounted, command_id: String) -> Dictionary:
    if not available(session,graph): return {"ok":false,"code":"CONVERSATION_UNAVAILABLE"}
    var sid: String = id(session)
    if session.ink==null or not session.ink.sessions.has(sid):
        if not session.attach_ink(sid,pack["ink_path"]): return {"ok":false,"code":"INK_STORY_NOT_FOUND"}
    if not session.ink_ready(sid): return {"ok":false,"code":"INK_LOADING"}
    if not state(session).is_empty(): return {"ok":true,"code":"RESUMED"}
    var result: Dictionary = session.ink_begin(sid,STORY,["salma","mahmoud","player"],command_id)
    if result.get("ok",false): result["code"]="STARTED"
    return result
func next(session: RefCounted, graph: RefCounted, command_id: String) -> Dictionary:
    if not near(session,graph): return {"ok":false,"code":"CONVERSATION_TOO_FAR"}
    return session.ink_next(id(session),command_id)
func choose(session: RefCounted, graph: RefCounted, option: String, command_id: String) -> Dictionary:
    if not near(session,graph): return {"ok":false,"code":"CONVERSATION_TOO_FAR"}
    return session.ink_choose(id(session),option,command_id)
