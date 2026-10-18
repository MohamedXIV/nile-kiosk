extends RefCounted
## P6 authored NPC exchange. All progression derives from P1 and existing
## P6 history. Furniture sightlines are NOT an acoustic simulation.
const RADIUS = 70.0
const HEARING = 110.0

static func valid(c: Variant) -> bool:
    if typeof(c) != TYPE_DICTIONARY or c.size() != 12: return false
    for k in ["room_id","participants","first_minute","beat_minutes","visible_minutes","join_beat","join_minutes","public","requires_known","requires_trusted","lines","joined_endings"]:
        if not c.has(k): return false
    if typeof(c["room_id"]) != TYPE_STRING or c["room_id"].is_empty() or typeof(c["public"]) != TYPE_BOOL: return false
    if typeof(c["participants"]) != TYPE_ARRAY or c["participants"].size()!=2 or c["participants"][0]==c["participants"][1]: return false
    for p in c["participants"]:
        if typeof(p)!=TYPE_STRING or p.is_empty() or p=="player": return false
    for k in ["first_minute","beat_minutes","visible_minutes","join_beat","join_minutes"]:
        if typeof(c[k])!=TYPE_INT or c[k]<0 or c[k]>1440: return false
    if c["first_minute"]>=1440 or c["beat_minutes"]<1 or c["visible_minutes"]<1 or c["visible_minutes"]>=c["beat_minutes"] or c["join_minutes"]<1: return false
    if typeof(c["lines"])!=TYPE_ARRAY or c["lines"].size()<3 or c["lines"].size()>8 or c["join_beat"]<1 or c["join_beat"]>=c["lines"].size()-1: return false
    if c["first_minute"]+c["beat_minutes"]*c["lines"].size()>1440: return false
    for line in c["lines"]:
        if typeof(line)!=TYPE_DICTIONARY or line.size()!=2 or not c["participants"].has(line.get("speaker_id")) or typeof(line.get("text"))!=TYPE_STRING or line["text"].is_empty() or line["text"].length()>180: return false
    if typeof(c["requires_known"])!=TYPE_ARRAY or c["requires_known"].size()>16 or typeof(c["requires_trusted"])!=TYPE_STRING or typeof(c["joined_endings"])!=TYPE_DICTIONARY: return false
    for f in c["requires_known"]:
        if typeof(f)!=TYPE_STRING or f.is_empty(): return false
    for text in c["joined_endings"].values():
        if typeof(text)!=TYPE_STRING or text.is_empty() or text.length()>180: return false
    return true

static func timeline(story_id: String, narrative: RefCounted, society: RefCounted, minute: int) -> Dictionary:
    var c: Dictionary = narrative.stories.get(story_id,{}).get("conversation",{})
    if c.is_empty(): return {}
    var day: int = int(minute/1440)
    var elapsed: int = minute%1440-int(c["first_minute"])
    var beat: int = int(elapsed/int(c["beat_minutes"])) if elapsed>=0 else -1
    var id: String = "%s:%d" % [story_id,day]
    var active: Dictionary = narrative.sessions.get(id,{})
    var consumed: bool = false
    for s in narrative.sessions.values():
        if s["story_id"]==story_id and s.get("conversation_day",-1)==day: consumed=true
    var present: bool = true
    for npc in c["participants"]:
        if society.npcs.get(npc,{}).get("location_id","")!=c["room_id"]: present=false
    var start: int = int(c["join_beat"])*int(c["beat_minutes"])
    var joinable: bool = c["public"] and present and not consumed and elapsed>=start and elapsed<start+int(c["join_minutes"])
    for f in c["requires_known"]:
        if not society.knowledge.get("player",{}).has(f): joinable=false
    if not c["requires_trusted"].is_empty() and society.familiarity.get("player",{}).get(c["requires_trusted"],"")!="trusted": joinable=false
    var out: Dictionary = {"session_id":id,"day":day,"joinable":joinable,"beat":-1,"npc_id":"","line":""}
    if c["public"] and present and beat>=0 and beat<c["lines"].size() and elapsed%int(c["beat_minutes"])<int(c["visible_minutes"]):
        out["beat"]=beat
        out["npc_id"]=c["lines"][beat]["speaker_id"]
        out["line"]=c["lines"][beat]["text"]
        if beat==c["lines"].size()-1 and not active.get("choices",[]).is_empty():
            out["line"]=c["joined_endings"].get(active["choices"][-1]["option_id"],out["line"])
    return out

static func near(c: Dictionary, session: RefCounted, graph: RefCounted, radius: float = RADIUS) -> bool:
    var p: Dictionary = session.world.spatial_view().get("player",{})
    if not c["public"] or p.get("room_id","")!=c["room_id"]: return false
    if not graph.npcs_have_visual_contact(session,c["participants"][0],c["participants"][1]): return false
    var at: Vector2 = Vector2(float(p["x"]),float(p["y"]))
    for npc in c["participants"]:
        var pose: Dictionary = graph.npc_pose(session,npc)
        if pose.is_empty() or pose["room_id"]!=p["room_id"] or at.distance_to(pose["position"])>radius: return false
    return true

# Read-only facade lets the existing route sampler consume canonical state
# during command planning/replay, without creating another WorldKernel.
class Evidence extends RefCounted:
    var world: RefCounted
    func _init(s: RefCounted) -> void: world=StateView.new(s)

class StateView extends RefCounted:
    var state: RefCounted
    func _init(s: RefCounted) -> void: state=s
    func view() -> Dictionary: return {"world_minute":state.world_minute,"jobs":state.jobs}
    func spatial_view() -> Dictionary: return state.spatial.snapshot()
    func orders_view() -> Dictionary: return state.service.snapshot()
    func npc(id: String) -> Dictionary: return state.society.npcs.get(id,{})

static func guarded(c: Dictionary, state: RefCounted) -> bool:
    if state == null or not state.spatial.initialized(): return false
    # Shared Godot route implementation, including live P4 counter movement.
    # Dynamic load avoids a static WorldState/RoomTraversal preload cycle.
    var traversal: GDScript = load("res://scripts/integration/room_traversal.gd")
    var made: Dictionary = traversal.from_data(state.spatial.graph)
    if not made.get("ok",false): return false
    var graph: RefCounted = made["graph"]
    var visits: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/navigation/nile_kiosk_visit_spots.v1.json"))
    var walkable: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/navigation/nile_kiosk_walkable.v1.json"))
    var okay: bool = graph.configure_visit_spots(visits).get("ok",false) and graph.configure_walkable(walkable).get("ok",false)
    if okay: okay=near(c,Evidence.new(state),graph)
    graph.dispose_navigation()
    return okay
