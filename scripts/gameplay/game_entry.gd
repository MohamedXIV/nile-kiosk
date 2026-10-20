extends RefCounted
## E6/P0: game entry adapter over the one canonical WorldSession.
## No scene-local cash, NPC, location, order, or clock authority.
const Session = preload("res://scripts/integration/world_session.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const TravelTime = preload("res://scripts/gameplay/travel_time_policy.gd")
const Procurement = preload("res://scripts/gameplay/procurement_play.gd")
const LivingConversation = preload("res://scripts/gameplay/living_conversation_play.gd")
const TeaTechnique = preload("res://scripts/gameplay/tea_technique_play.gd")
const CustomerMemory = preload("res://scripts/gameplay/customer_memory_play.gd")
const SocialVisitor = preload("res://scripts/gameplay/social_visitor_play.gd")
const Demand = preload("res://scripts/integration/customer_demand_config.gd")
const ServicePlay = preload("res://scripts/integration/kiosk_service_play.gd")
const CookingContent = preload("res://scripts/core/cooking_content.gd")
const Sandwich = preload("res://scripts/gameplay/sandwich_play.gd")
const SandwichService = preload("res://scripts/gameplay/sandwich_service_play.gd")
const CONTENT = "res://content/world/nile_opening.v1.json"
const ROUTES = "res://content/navigation/nile_opening_routes.v1.json"
const COMMUTE = "res://content/navigation/nile_commute.v1.json"
const VISITS = "res://content/navigation/nile_kiosk_visit_spots.v1.json"
const WALKABLE = "res://content/navigation/nile_kiosk_walkable.v1.json"
const DEMAND = "res://content/service/nile_opening_demand.v1.json"
const DAILY_POLICY = "res://content/life/nile_opening.v1.json"
const QUIET_POLICY = "res://content/life/nile_quiet_activities.v1.json"
const RADIO_POLICY = "res://content/life/nile_radio.v1.json"
const BED_POLICY = "res://content/life/nile_bed.v1.json"
const MEAL_POLICY = "res://content/life/nile_meals.v1.json"
const TEA_ACTION_POLICY = "res://content/cooking/nile_tea_actions.v1.json"
const TEA_REACTIONS_POLICY = "res://content/service/nile_tea_reactions.v1.json"
const RIVER_STORY_POLICY = "res://content/social/nile_river_reflection.v1.json"
const RIVER_STORY_ID = "river_watch_reflection"
const MAHMOUD_STORY_POLICY = "res://content/social/nile_mahmoud_after_tea.v1.json"
const MAHMOUD_STORY_ID = "mahmoud_after_tea"
const DEFAULT_SAVE = "user://nile-kiosk-game-v1.json"
const START_MINUTE = 16 * 60 + 30  # Start at home before the 30-minute commute; kiosk demand still opens at 17:00.
const COUNTER = Vector2(115, 80)
const COUNTER_RADIUS = 48.0

var procurement: RefCounted = Procurement.new()
var conversation: RefCounted = LivingConversation.new()
var session: RefCounted
var graph: RefCounted
var travel_minutes: Dictionary = {}
var quiet_captions: Dictionary = {}
var radio_pack: Dictionary = {}
var bed_pack: Dictionary = {}
var tea_actions: Dictionary = {}
var tea_reactions: Dictionary = {}
var sandwich_reactions: Dictionary = {}
var river_story_pack: Dictionary = {}
var mahmoud_story_pack: Dictionary = {}
var customer_memory: RefCounted = CustomerMemory.new()
var social_visitor: RefCounted = SocialVisitor.new()

func start(save_path: String = DEFAULT_SAVE) -> Dictionary:
    session = Session.new(71, save_path)
    var existing: Dictionary = session.load_existing()
    if not existing.get("ok", false):
        return existing  # Never erase a corrupt or incompatible save.
    if existing["code"] == "NEW_WORLD":
        var boot: Dictionary = session.bootstrap_from_content(CONTENT)
        if not boot.get("ok", false): return boot
    # Register authored recipes and paid offers in the sole canonical world.
    # Installer preflights/restores history, is idempotent on existing saves
    # and deliberately never gifts supplies or alters the clock.
    var sandwich_content: Dictionary = CookingContent.install(session.world)
    if not sandwich_content.get("ok",false): return sandwich_content
    var sandwich_service: Dictionary = SandwichService.configure(session)
    if not sandwich_service.get("ok",false): return sandwich_service
    sandwich_reactions = sandwich_service["reactions"]
    var nav: Dictionary = session.configure_navigation(ROUTES)
    if not nav.get("ok", false): return nav
    var parsed: Dictionary = Graph.from_data(session.world.spatial_view()["graph"])
    if not parsed.get("ok", false): return parsed
    graph = parsed["graph"]
    var time_policy: Dictionary = TravelTime.load_packaged(
        COMMUTE,session.world.spatial_view()["graph"]["portals"])
    if not time_policy.get("ok",false): return time_policy
    travel_minutes = time_policy["durations"].duplicate(true)
    if not FileAccess.file_exists(VISITS):
        return {"ok":false,"code":"VISIT_SPOTS_NOT_FOUND"}
    var visit_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISITS))
    var configured_visits: Dictionary = graph.configure_visit_spots(visit_data)
    if not configured_visits.get("ok",false): return configured_visits
    if not FileAccess.file_exists(WALKABLE):
        return {"ok":false,"code":"NAV_MESH_NOT_FOUND"}
    var walkable: Variant = JSON.parse_string(FileAccess.get_file_as_string(WALKABLE))
    var configured_walk: Dictionary = graph.configure_walkable(walkable)
    if not configured_walk.get("ok",false): return configured_walk
    var configured_visitor: Dictionary = social_visitor.configure(session,graph)
    if not configured_visitor.get("ok",false): return configured_visitor
    if session.world.view()["life"]["policy"].is_empty():
        if not FileAccess.file_exists(DAILY_POLICY):
            return {"ok":false,"code":"DAILY_POLICY_NOT_FOUND"}
        var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DAILY_POLICY))
        if typeof(raw) != TYPE_DICTIONARY or raw.size() != 2 or raw.get("schema") != 1 or typeof(raw.get("policy")) != TYPE_DICTIONARY:
            return {"ok":false,"code":"INVALID_DAILY_POLICY"}
        var configured_life: Dictionary = session.command("game:life:configure", "system:director",
            "life.configure", raw["policy"])
        if not configured_life.get("ok",false): return configured_life
    if not FileAccess.file_exists(QUIET_POLICY):
        return {"ok":false,"code":"QUIET_POLICY_NOT_FOUND"}
    var quiet: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUIET_POLICY))
    if typeof(quiet) != TYPE_DICTIONARY or quiet.size() != 3 or quiet.get("schema") != 1 or typeof(quiet.get("activities")) != TYPE_ARRAY or typeof(quiet.get("captions")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_QUIET_POLICY"}
    quiet_captions = quiet["captions"].duplicate(true)
    if not session.world.view()["life"]["policy"].has("activities"):
        var configured_quiet: Dictionary = session.command("game:life:quiet:v1","system:director",
            "life.activities.configure",{"activities":quiet["activities"]})
        if not configured_quiet.get("ok",false): return configured_quiet
    if not FileAccess.file_exists(RADIO_POLICY):
        return {"ok":false,"code":"RADIO_POLICY_NOT_FOUND"}
    var radio_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RADIO_POLICY))
    if typeof(radio_raw) != TYPE_DICTIONARY or radio_raw.size() != 7 or radio_raw.get("schema") != 1 or typeof(radio_raw.get("type")) != TYPE_DICTIONARY or typeof(radio_raw.get("activity")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_RADIO_POLICY"}
    radio_pack = radio_raw.duplicate(true)
    var h: Dictionary = session.world.housing_view()
    if not h["types"].has(radio_pack["type"]["type_id"]):
        var item_type: Dictionary = session.command("game:radio:type:v1","system:catalog",
            "home.type.define",radio_pack["type"])
        if not item_type.get("ok",false): return item_type
    var has_activity: bool = false
    for activity in quiet_activities():
        if activity["id"] == radio_pack["activity"]["id"]: has_activity = true
    if not has_activity:
        var radio_activity: Dictionary = session.command("game:radio:activity:v1","system:director",
            "life.activities.extend",{"activities":[radio_pack["activity"]]})
        if not radio_activity.get("ok",false): return radio_activity
    if not FileAccess.file_exists(BED_POLICY):
        return {"ok":false,"code":"BED_POLICY_NOT_FOUND"}
    var bed_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BED_POLICY))
    if typeof(bed_raw) != TYPE_DICTIONARY or bed_raw.size() != 6 or bed_raw.get("schema") != 1 or typeof(bed_raw.get("type")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_BED_POLICY"}
    bed_pack = bed_raw.duplicate(true)
    if bed_pack["type"].get("type_id") != "bed" or bed_pack.get("unit_id") != "roof" or bed_pack["type"].get("actions") != ["sleep"]:
        return {"ok":false,"code":"INVALID_BED_POLICY"}
    if not session.world.housing_view()["types"].has("bed"):
        var bed_type: Dictionary = session.command("game:bed:type:v1","system:catalog",
            "home.type.define",bed_pack["type"])
        if not bed_type.get("ok",false): return bed_type
    if not FileAccess.file_exists(MEAL_POLICY): return {"ok":false,"code":"MISSING_MEAL_POLICY"}
    var meals: Variant = JSON.parse_string(FileAccess.get_file_as_string(MEAL_POLICY))
    if typeof(meals) != TYPE_DICTIONARY or meals.size() != 2 or meals.get("schema") != 1 or typeof(meals.get("recipes")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_MEAL_POLICY"}
    if session.world.needs_view()["meal_values"].is_empty():
        var provision: Dictionary = session.command("game:needs:meals:v1","system:director",
            "needs.meals.configure",{"recipes":meals["recipes"],"policy_version":2})
        if not provision.get("ok",false): return provision
    if not FileAccess.file_exists(TEA_ACTION_POLICY):
        return {"ok":false,"code":"TEA_ACTION_POLICY_NOT_FOUND"}
    var tea_pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEA_ACTION_POLICY))
    if typeof(tea_pack) != TYPE_DICTIONARY or tea_pack.size() != 3 or tea_pack.get("schema") != 1 or tea_pack.get("recipe_id") != "tea" or typeof(tea_pack.get("gestures")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_TEA_ACTION_POLICY"}
    tea_actions = tea_pack["gestures"].duplicate(true)
    if tea_actions.size() != 2 or not tea_actions.has("heat") or not tea_actions.has("serve"):
        return {"ok":false,"code":"INVALID_TEA_ACTION_POLICY"}
    for station_type in tea_actions:
        var gesture: Variant = tea_actions[station_type]
        if typeof(gesture) != TYPE_DICTIONARY or gesture.size() != 3 or gesture.get("key") not in ["H","U"] or typeof(gesture.get("start")) != TYPE_STRING or typeof(gesture.get("finish")) != TYPE_STRING:
            return {"ok":false,"code":"INVALID_TEA_ACTION_POLICY"}
    if str(tea_actions["heat"]["key"]) == str(tea_actions["serve"]["key"]):
        return {"ok":false,"code":"INVALID_TEA_ACTION_POLICY"}
    if not session.world.cooking_view()["recipes"].has("tea"):
        return {"ok":false,"code":"TEA_RECIPE_NOT_FOUND"}
    if not FileAccess.file_exists(TEA_REACTIONS_POLICY):
        return {"ok":false,"code":"TEA_REACTIONS_NOT_FOUND"}
    var reactions: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEA_REACTIONS_POLICY))
    if typeof(reactions) != TYPE_DICTIONARY or reactions.size() != 3 or reactions.get("schema") != 1 or reactions.get("recipe_id") != "tea" or typeof(reactions.get("npcs")) != TYPE_DICTIONARY:
        return {"ok":false,"code":"INVALID_TEA_REACTIONS"}
    tea_reactions = reactions["npcs"].duplicate(true)
    if tea_reactions.is_empty(): return {"ok":false,"code":"INVALID_TEA_REACTIONS"}
    for npc_id in tea_reactions:
        var lines: Variant = tea_reactions[npc_id]
        if not session.world.social_view()["npcs"].has(npc_id) or typeof(lines) != TYPE_DICTIONARY or lines.size() != 3:
            return {"ok":false,"code":"INVALID_TEA_REACTIONS"}
        for grade in ["good","okay","rough"]:
            if typeof(lines.get(grade)) != TYPE_STRING or str(lines[grade]).strip_edges().is_empty() or str(lines[grade]).length() > 65:
                return {"ok":false,"code":"INVALID_TEA_REACTIONS"}
    # P6 owns the story contract, and the packaged Ink asset owns only prose.
    if not FileAccess.file_exists(RIVER_STORY_POLICY):
        return {"ok":false,"code":"RIVER_STORY_MANIFEST_NOT_FOUND"}
    var river_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIVER_STORY_POLICY))
    if typeof(river_raw) != TYPE_DICTIONARY or river_raw.size() != 5 or river_raw.get("schema") != 1 or river_raw.get("opportunity_id") != RIVER_STORY_ID or river_raw.get("session_id") != RIVER_STORY_ID or typeof(river_raw.get("story")) != TYPE_DICTIONARY or typeof(river_raw.get("ink_path")) != TYPE_STRING:
        return {"ok":false,"code":"INVALID_RIVER_STORY_MANIFEST"}
    if not str(river_raw["ink_path"]).begins_with("res://content/ink/") or not str(river_raw["ink_path"]).ends_with(".ink.json") or str(river_raw["ink_path"]).contains(".."):
        return {"ok":false,"code":"INVALID_RIVER_STORY_PATH"}
    if river_raw["story"].get("story_id", "") != RIVER_STORY_ID:
        return {"ok":false,"code":"INVALID_RIVER_STORY_ID"}
    river_story_pack = river_raw.duplicate(true)
    # Salma owns an authored P2 fact. An actual P6 Ink river_rest beat,
    # not choosing the option alone, is the only way the player learns it.
    if not session.world.social_view()["social_facts"].has(TeaTechnique.FACT):
        var tea_fact: Dictionary = session.command("game:e3:tea-tip-fact:v1","system:director",
            "social.fact.register",{"fact_id":TeaTechnique.FACT,"source_npc_id":"salma","visibility":"public"})
        if not tea_fact.get("ok",false): return tea_fact
    if not session.world.narrative_view()["stories"].has(RIVER_STORY_ID):
        var registered: Dictionary = session.command("game:e4:river:story:v1", "system:narrative",
            "narrative.story.register", river_story_pack["story"])
        if not registered.get("ok", false): return registered
    if not FileAccess.file_exists(MAHMOUD_STORY_POLICY):
        return {"ok":false,"code":"MAHMOUD_STORY_MANIFEST_NOT_FOUND"}
    var mahmoud_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAHMOUD_STORY_POLICY))
    if typeof(mahmoud_raw) != TYPE_DICTIONARY or mahmoud_raw.size() != 5 or mahmoud_raw.get("schema") != 1 or mahmoud_raw.get("opportunity_id") != MAHMOUD_STORY_ID or mahmoud_raw.get("session_id") != MAHMOUD_STORY_ID or typeof(mahmoud_raw.get("story")) != TYPE_DICTIONARY or typeof(mahmoud_raw.get("ink_path")) != TYPE_STRING:
        return {"ok":false,"code":"INVALID_MAHMOUD_STORY_MANIFEST"}
    if not str(mahmoud_raw["ink_path"]).begins_with("res://content/ink/") or not str(mahmoud_raw["ink_path"]).ends_with(".ink.json") or str(mahmoud_raw["ink_path"]).contains("..") or mahmoud_raw["story"].get("story_id","") != MAHMOUD_STORY_ID:
        return {"ok":false,"code":"INVALID_MAHMOUD_STORY_PATH"}
    mahmoud_story_pack = mahmoud_raw.duplicate(true)
    if not session.world.narrative_view()["stories"].has(MAHMOUD_STORY_ID):
        var registered_mahmoud: Dictionary = session.command("game:e4:mahmoud:story:v1", "system:narrative",
            "narrative.story.register", mahmoud_story_pack["story"])
        if not registered_mahmoud.get("ok", false): return registered_mahmoud
    var conversation_config: Dictionary = conversation.configure(session)
    if not conversation_config.get("ok",false): return conversation_config
    var market_config: Dictionary = procurement.configure(session)
    if not market_config.get("ok",false): return market_config
    var memory_config: Dictionary = customer_memory.configure(session)
    if not memory_config.get("ok",false): return memory_config
    if existing["code"] == "NEW_WORLD":
        var configured: Dictionary = Demand.configure(session, DEMAND)
        if not configured.get("ok", false): return configured
        var opening: Dictionary = session.advance(START_MINUTE, "game:opening:clock")
        if not opening.get("ok", false): return opening
    return {"ok": true, "code": existing["code"], "location": room()}

func room() -> String:
    return str(session.world.spatial_view()["player"]["room_id"])

func position() -> Vector2:
    var p: Dictionary = session.world.spatial_view()["player"]
    return Vector2(int(p["x"]), int(p["y"]))

func npc_pose(npc_id: String) -> Dictionary:
    return graph.npc_pose(session,npc_id)

func _id(action: String) -> String:
    return "game:e6:%s:%d" % [action, int(session.world.view()["sequence"]) + 1]

func move_world(dx: int, dy: int) -> Dictionary:
    return session.command(_id("move"), "player", "spatial.player.move", {"dx": dx, "dy": dy})

static func screen_delta(horizontal: int, vertical: int) -> Vector2i:
    if horizontal == 0 and vertical == 0: return Vector2i.ZERO
    var direction: Vector2 = Vector2(horizontal+vertical,vertical-horizontal).normalized()*17.0
    return Vector2i(roundi(direction.x),roundi(direction.y))

func move_screen(horizontal: int, vertical: int) -> Dictionary:
    var delta: Vector2i = screen_delta(horizontal,vertical)
    if delta == Vector2i.ZERO: return {"ok":true,"code":"NO_OP"}
    return move_world(delta.x,delta.y)

func nearest_portal() -> Dictionary:
    var nearest: Dictionary = {}
    var distance: float = INF
    for portal in graph.visible_exits(room()):
        var d: float = position().distance_to(Graph.point(portal["entry"]))
        if d <= Graph.RADIUS and (d < distance or (is_equal_approx(d, distance) and str(portal["id"]) < str(nearest.get("id","")))):
            nearest = portal
            distance = d
    return nearest.duplicate(true)

func travel_near() -> Dictionary:
    var portal: Dictionary = nearest_portal()
    if portal.is_empty(): return {"ok": false, "code": "NO_NEARBY_DOOR"}
    var minutes: int = TravelTime.minutes_for(travel_minutes,str(portal["id"]))
    # Check the P1 rate/overflow BEFORE committing the one-way P2 portal.
    # Both effects are ordinary serial, replayable WorldKernel events.
    var planned: Dictionary = TravelTime.preflight(session.world.view(),minutes)
    if not planned.get("ok",false): return planned
    var arrival: Dictionary = session.command(_id("travel"),"player",
        "spatial.player.travel",{"portal_id":portal["id"]})
    if not arrival.get("ok",false): return arrival
    if minutes > 0:
        var elapsed: Dictionary = session.advance(int(planned["steps"]),_id("commute"))
        if not elapsed.get("ok",false):
            # Should be unreachable after preflight with a healthy WorldKernel.
            # Make an integrity failure conspicuous rather than lying about
            # a completed 30-minute trip; never synthesize an arrival clock.
            push_error("COMMUTE_CLOCK_REJECTED " + str(elapsed))
            return {"ok":false,"code":"COMMUTE_CLOCK_REJECTED"}
    arrival["travel_minutes"] = minutes
    arrival["arrival_minute"] = int(session.world.view()["world_minute"])
    return arrival

func listen_near() -> Dictionary:
    return graph.overhear(session, position(), _id("listen"))

func service_near() -> Dictionary:
    if not session.world.view()["life"]["open"]:
        return {"ok":false,"code":"KIOSK_CLOSED"}
    if room() != "kiosk":
        return {"ok":false,"code":"NOT_AT_KIOSK"}
    if position().distance_to(COUNTER) > COUNTER_RADIUS:
        return {"ok":false,"code":"COUNTER_TOO_FAR"}
    var next: Dictionary = ServicePlay.next_action(session, "kiosk")
    if next.get("ok",false) and _tea_transition(next):
        return {"ok":false,"code":"HAND_ACTION_REQUIRED"}
    # The P3 technique gesture must happen via F7. G may accept, deliver,
    # quote or settle, but must never create a parallel auto-cooking job.
    if next.get("ok",false) and str(next.get("kind","")).begins_with("cook."):
        var recipe_id: String = str(next.get("payload",{}).get("recipe_id",""))
        var job_id: String = str(next.get("payload",{}).get("job_id",""))
        if recipe_id == Sandwich.RECIPE or (not job_id.is_empty() and \
                session.world.cooking_view()["preparations"].get(job_id,{}).get("recipe_id","") == Sandwich.RECIPE):
            return {"ok":false,"code":"SANDWICH_HAND_ACTION_REQUIRED",
                "caption":"F7 · Prepare and turn the sandwich before serving"}
    var result: Dictionary = ServicePlay.perform_next(session, "kiosk")
    if result.get("ok",false) and result.get("kind","") == "order.deliver":
        var reply: Dictionary = customer_reaction()
        if not reply.is_empty():
            result["customer_reaction"] = reply.duplicate(true)
            result["caption"] = str(reply["npc_id"]).capitalize() + ": " + str(reply["line"])
    return result

func customer_reaction() -> Dictionary:
    # Real grade-specific sandwich feedback competes with the latest tea
    # delivery solely by canonical P4 close time, never by a UI-owned event.
    var sandwich_reply: Dictionary = SandwichService.reaction(session,sandwich_reactions)
    # A brief authored utterance projected from an actual P4 delivery and
    # verified P3 item quality. It expires naturally with world time; no
    # trust score, synthetic memory event, or dialogue-system authority.
    if room() != "kiosk": return {}
    var v: Dictionary = session.world.view()
    var latest: Dictionary = {}
    for order in v["service"]["orders"].values():
        if order["status"] != "delivered" or order["recipe_id"] != "tea":
            continue
        if latest.is_empty() or int(order["closed_minute"]) > int(latest["closed_minute"]):
            latest = order
    if latest.is_empty(): return sandwich_reply
    if not sandwich_reply.is_empty() and int(sandwich_reply["closed_minute"]) >= int(latest["closed_minute"]):
        return sandwich_reply
    var elapsed: int = int(v["world_minute"]) - int(latest["closed_minute"])
    if elapsed < 0 or elapsed > 30: return sandwich_reply
    var npc_id: String = str(latest["npc_id"])
    if not tea_reactions.has(npc_id) or session.world.npc(npc_id).get("location_id","") != "kiosk":
        return sandwich_reply
    var quality: Dictionary = session.world.prepared_quality(str(latest["item_id"]))
    if quality.is_empty() or not tea_reactions[npc_id].has(quality["grade"]):
        return sandwich_reply
    return {"order_id":str(latest["order_id"]),"npc_id":npc_id,
        "item_id":str(latest["item_id"]),"grade":str(quality["grade"]),
        "line":str(tea_reactions[npc_id][quality["grade"]]),
        "source_event_id":str(latest["closure_event_id"])}

func ambient_exchange() -> Dictionary:
    if not customer_reaction().is_empty(): return {}
    return conversation.ambient(session,graph)

func conversation_id() -> String: return conversation.id(session)
func conversation_begin() -> Dictionary: return conversation.begin(session,graph,_id("conversation_begin"))
func conversation_next() -> Dictionary: return conversation.next(session,graph,_id("conversation_next"))
func conversation_choose(option: String) -> Dictionary: return conversation.choose(session,graph,option,_id("conversation_choose"))

func _tea_transition(action: Dictionary) -> bool:
    if str(action.get("kind","")) not in ["cook.step.begin","cook.step.resume","cook.step.finish"]:
        return false
    var job_id: String = str(action.get("payload",{}).get("job_id",""))
    var prep: Dictionary = session.world.cooking_view()["preparations"].get(job_id,{})
    return not prep.is_empty() and str(prep["recipe_id"]) == "tea"

func _tea_step(job: Dictionary, cooking: Dictionary) -> Dictionary:
    if job.is_empty() or str(job.get("recipe_id","")) != "tea":
        return {}
    var recipe: Dictionary = cooking["recipes"].get("tea",{})
    var index: int = int(job.get("step_index",-1))
    if recipe.is_empty() or index < 0 or index >= recipe["steps"].size():
        return {}
    var station_type: String = str(recipe["steps"][index]["station_type"])
    if not tea_actions.has(station_type):
        return {}
    return tea_actions[station_type]

func active_tea_step() -> Dictionary:
    # UI-only projection; the P3 job remains the sole cooking state machine.
    var cooking: Dictionary = session.world.cooking_view()
    var ids: Array = cooking["preparations"].keys()
    ids.sort()
    for job_id in ids:
        var job: Dictionary = cooking["preparations"][job_id]
        if not str(job_id).begins_with("play:c3:prep:") or str(job["stage"]) not in ["waiting","active","interrupted"]:
            continue
        var step: Dictionary = _tea_step(job,cooking)
        if step.is_empty(): continue
        return {"job_id":job_id,"stage":job["stage"],"key":step["key"],
            "caption":step["finish"] if job["stage"] == "active" else step["start"],
            "ready_in":maxi(0,int(job["ready_minute"])-int(session.world.view()["world_minute"])) if job["stage"] == "active" else 0}
    return {}

func tea_action_near(key: String) -> Dictionary:
    if not session.world.view()["life"]["open"]: return {"ok":false,"code":"KIOSK_CLOSED"}
    if room() != "kiosk": return {"ok":false,"code":"NOT_AT_KIOSK"}
    if position().distance_to(COUNTER) > COUNTER_RADIUS:
        return {"ok":false,"code":"COUNTER_TOO_FAR"}
    if key not in ["H","U"]: return {"ok":false,"code":"UNKNOWN_GESTURE"}
    var context: Dictionary = active_tea_step()
    if context.is_empty(): return {"ok":false,"code":"NO_TEA_PREPARATION"}
    if str(context["key"]) != key: return {"ok":false,"code":"WRONG_GESTURE"}
    var next: Dictionary = ServicePlay.next_action(session,"kiosk")
    if not next.get("ok",false): return next
    if not _tea_transition(next) or str(next["payload"].get("job_id","")) != str(context["job_id"]):
        return {"ok":false,"code":"NO_TEA_ACTION_READY"}
    var response: Dictionary = ServicePlay.perform_next(session,"kiosk")
    if response.get("ok",false):
        response["caption"] = "Hands on: " + str(context["caption"])
        response["gesture"] = key
        if str(response.get("kind","")) == "cook.step.finish":
            var quality: Dictionary = session.world.prepared_quality("item:" + str(context["job_id"]))
            if not quality.is_empty():
                response["quality"] = quality.duplicate(true)
                response["caption"] = "Tea finished: " + str(quality["grade"]) + " (timing matters)."
    return response

func personal_bread_near() -> Dictionary:
    # A modest self-meal is a real P3 recipe, not a free Hunger hotkey.
    # Each press advances a canonical cook step; world time still passes and
    # unfinished preparation survives save/reload until its own deadline.
    if room() != "kiosk": return {"ok":false,"code":"NOT_AT_KIOSK"}
    if position().distance_to(COUNTER) > COUNTER_RADIUS:
        return {"ok":false,"code":"COUNTER_TOO_FAR"}
    var v: Dictionary = session.world.view()
    var cooking: Dictionary = v["cooking"]
    var ids: Array = cooking["items"].keys()
    ids.sort()
    for item_id in ids:
        var item: Dictionary = cooking["items"][item_id]
        if str(item["job_id"]).begins_with("personal:") and item["status"] == "ready":
            var eaten: Dictionary = session.command(_id("personal_eat"),"player","needs.eat",{"item_id":item_id})
            if eaten.get("ok",false):
                eaten["phase"] = "eat"
                eaten["caption"] = "A little bread, made for yourself."
            return eaten
    ids = cooking["preparations"].keys()
    ids.sort()
    for job_id in ids:
        if not str(job_id).begins_with("personal:"): continue
        var stage: String = str(cooking["preparations"][job_id]["stage"])
        var command_kind: String = ""
        var payload: Dictionary = {"job_id":job_id}
        match stage:
            "waiting":
                command_kind = "cook.step.begin"
                payload["station_id"] = "counter"
            "active": command_kind = "cook.step.finish"
            "interrupted":
                command_kind = "cook.step.resume"
                payload["station_id"] = "counter"
        if command_kind.is_empty(): continue
        var result: Dictionary = session.command(_id("personal_step"),"player",command_kind,payload)
        if result.get("ok",false):
            result["phase"] = "finish" if stage == "active" else "begin"
            result["caption"] = "Bread is ready to eat." if stage == "active" else "Preparing a little bread. Give it a minute."
        return result
    if int(v["world_minute"]) > 2147483587:
        return {"ok":false,"code":"TIME_OVERFLOW"}
    var started: Dictionary = session.command(_id("personal_start"),"player","cook.start",
        {"job_id":"personal:" + str(v["sequence"] + 1),"recipe_id":"plain_bread",
         "deadline_minute":int(v["world_minute"])+60})
    if started.get("ok",false):
        started["phase"] = "start"
        started["caption"] = "A little bread for yourself. Press K again to prepare it."
    return started

func open_kiosk() -> Dictionary:
    return session.command(_id("open"),"player","life.open",{})

func close_kiosk() -> Dictionary:
    return session.command(_id("close"),"player","life.close",{})

func sleep_at_home() -> Dictionary:
    return session.command(_id("sleep"),"player","life.sleep",{})

func quiet_activities() -> Array:
    return session.world.view()["life"]["policy"].get("activities",[])

func quiet_near() -> Dictionary:
    var current: Vector2 = position()
    var chosen: Dictionary = {}
    var nearest: float = INF
    for activity in quiet_activities():
        if activity["room_id"] != room(): continue
        var d: float = current.distance_to(Vector2(int(activity["x"]),int(activity["y"])))
        if d <= int(activity["radius"]) and d < nearest:
            chosen = activity
            nearest = d
    if chosen.is_empty(): return {"ok":false,"code":"NO_QUIET_SPOT_NEARBY"}
    var response: Dictionary = session.command(_id("quiet"),"player","life.activity",
        {"activity_id":chosen["id"]})
    if response.get("ok",false):
        response["activity_id"] = chosen["id"]
        response["caption"] = quiet_captions.get(chosen["id"],"A quiet moment passes.")
    return response

func buy_radio() -> Dictionary:
    # Temporary neighborhood-order affordance, not a finished supplier UI.
    if room() != radio_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    var item_id: String = str(radio_pack["object_id"])
    return session.command(_id("radio_buy"),"player","home.object.acquire",
        {"object_id":item_id,"type_id":radio_pack["type"]["type_id"],
        "transaction_id":"opening:radio:purchase:1"})

func place_radio() -> Dictionary:
    if room() != radio_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    return session.command(_id("radio_place"),"player","home.object.place",
        {"object_id":radio_pack["object_id"],"unit_id":radio_pack["unit_id"],
        "slot_id":radio_pack["slot_id"]})

func store_radio() -> Dictionary:
    if room() != radio_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    return session.command(_id("radio_store"),"player","home.object.store",
        {"object_id":radio_pack["object_id"]})

# A secondhand bed is bought and placed with the real P5 ledger/ownership.
# E2 only rewards it on sleep, not on buy/place. The two steps are explicit
# so store/re-place and rejection paths cannot mint free furniture or energy.
func buy_bed() -> Dictionary:
    if room() != bed_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    return session.command(_id("bed_buy"),"player","home.object.acquire",
        {"object_id":bed_pack["object_id"],"type_id":"bed",
         "transaction_id":"opening:bed:purchase:1"})

func place_bed() -> Dictionary:
    if room() != bed_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    return session.command(_id("bed_place"),"player","home.object.place",
        {"object_id":bed_pack["object_id"],"unit_id":bed_pack["unit_id"],
         "slot_id":bed_pack["slot_id"]})

func store_bed() -> Dictionary:
    if room() != bed_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    return session.command(_id("bed_store"),"player","home.object.store",
        {"object_id":bed_pack["object_id"]})

func bed_near() -> Dictionary:
    if room() != bed_pack["unit_id"]: return {"ok":false,"code":"NOT_AT_HOME"}
    var bed: Dictionary = session.world.housing_view()["objects"].get(bed_pack["object_id"],{})
    if bed.is_empty():
        var bought: Dictionary = buy_bed()
        if bought.get("ok",false): bought["caption"] = "You paid for a secondhand bed. Place it in your room."
        return bought
    if not str(bed["unit_id"]).is_empty():
        return {"ok":false,"code":"BED_ALREADY_PLACED"}
    var placed: Dictionary = place_bed()
    if placed.get("ok",false): placed["caption"] = "A real place to sleep. You can rest here tonight."
    return placed

func listen_radio() -> Dictionary:
    var response: Dictionary = session.command(_id("radio_listen"),"player","life.activity",
        {"activity_id":radio_pack["activity"]["id"]})
    if response.get("ok",false):
        response["activity_id"] = radio_pack["activity"]["id"]
        response["caption"] = radio_pack["caption"]
    return response

func wait_minutes(minutes: int = 5) -> Dictionary:
    if minutes < 1 or minutes > 5:
        return {"ok":false,"code":"INVALID_WAIT"}
    return session.advance(minutes, _id("wait"))

func river_story_session() -> Dictionary:
    return session.world.narrative_session(RIVER_STORY_ID)

func river_story_available() -> bool:
    return session.world.narrative_opportunities().has(RIVER_STORY_ID)

func river_story_begin() -> Dictionary:
    if not river_story_available():
        return {"ok":false,"code":"STORY_NOT_UNLOCKED"}
    var active: Dictionary = river_story_session()
    if active.get("phase", "") == "finished":
        return {"ok":false,"code":"STORY_ALREADY_FINISHED"}
    if room() != "kiosk":
        return {"ok":false,"code":"NOT_AT_KIOSK"}
    var pose: Dictionary = npc_pose("salma")
    if pose.is_empty() or position().distance_to(pose["position"]) > Graph.RADIUS:
        return {"ok":false,"code":"SALMA_TOO_FAR"}
    if session.ink == null or not session.ink.sessions.has(RIVER_STORY_ID):
        if not session.attach_ink(RIVER_STORY_ID, river_story_pack["ink_path"]):
            return {"ok":false,"code":"INK_STORY_NOT_FOUND"}
    if not session.ink_ready(RIVER_STORY_ID):
        return {"ok":false,"code":"INK_LOADING"}
    if not active.is_empty():
        return {"ok":true,"code":"RESUMED","phase":active["phase"]}
    var started: Dictionary = session.ink_begin_opportunity(RIVER_STORY_ID, RIVER_STORY_ID,
        ["salma","player"], _id("story_begin"))
    if started.get("ok", false): started["code"] = "STARTED"
    return started

func river_story_next() -> Dictionary:
    if not session.ink_ready(RIVER_STORY_ID):
        return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_next(RIVER_STORY_ID, _id("story_next"))

func river_story_choose(option_id: String) -> Dictionary:
    if not session.ink_ready(RIVER_STORY_ID):
        return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_choose(RIVER_STORY_ID, option_id, _id("story_choose"))

func mahmoud_story_session() -> Dictionary:
    return session.world.narrative_session(MAHMOUD_STORY_ID)

func mahmoud_invitation() -> Dictionary:
    return session.world.narrative_opportunities().get(MAHMOUD_STORY_ID, {}).duplicate(true)

func mahmoud_invite_near() -> bool:
    var offer: Dictionary = mahmoud_invitation()
    if offer.is_empty() or offer.has("declined_event_id") or mahmoud_story_session().get("phase","") == "finished":
        return false
    if room() != "kiosk" or session.world.npc("mahmoud").get("location_id","") != "kiosk":
        return false
    var pose: Dictionary = npc_pose("mahmoud")
    return not pose.is_empty() and position().distance_to(pose["position"]) <= Graph.RADIUS

func mahmoud_story_begin() -> Dictionary:
    var offer: Dictionary = mahmoud_invitation()
    if offer.is_empty(): return {"ok":false,"code":"STORY_NOT_UNLOCKED"}
    if offer.has("declined_event_id"): return {"ok":false,"code":"OPPORTUNITY_DECLINED"}
    var active: Dictionary = mahmoud_story_session()
    if active.get("phase","") == "finished": return {"ok":false,"code":"STORY_ALREADY_FINISHED"}
    if not mahmoud_invite_near(): return {"ok":false,"code":"MAHMOUD_TOO_FAR"}
    if session.ink == null or not session.ink.sessions.has(MAHMOUD_STORY_ID):
        if not session.attach_ink(MAHMOUD_STORY_ID,mahmoud_story_pack["ink_path"]):
            return {"ok":false,"code":"INK_STORY_NOT_FOUND"}
    if not session.ink_ready(MAHMOUD_STORY_ID):
        return {"ok":false,"code":"INK_LOADING"}
    if not active.is_empty(): return {"ok":true,"code":"RESUMED","phase":active["phase"]}
    var result: Dictionary = session.ink_begin_opportunity(MAHMOUD_STORY_ID,MAHMOUD_STORY_ID,
        ["mahmoud","player"],_id("mahmoud_begin"))
    if result.get("ok",false): result["code"] = "STARTED"
    return result

func mahmoud_story_decline() -> Dictionary:
    if not mahmoud_invite_near():
        return {"ok":false,"code":"INVITATION_NOT_NEARBY"}
    return session.command(_id("mahmoud_decline"),"system:narrative","narrative.opportunity.decline",
        {"opportunity_id":MAHMOUD_STORY_ID})

func mahmoud_story_next() -> Dictionary:
    if not session.ink_ready(MAHMOUD_STORY_ID): return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_next(MAHMOUD_STORY_ID,_id("mahmoud_next"))

func mahmoud_story_choose(option_id: String) -> Dictionary:
    if not session.ink_ready(MAHMOUD_STORY_ID): return {"ok":false,"code":"INK_NOT_READY"}
    return session.ink_choose(MAHMOUD_STORY_ID,option_id,_id("mahmoud_choose"))

func mona_story_begin() -> Dictionary:
    return social_visitor.begin(session,graph,_id("mona_begin"))

func mona_story_next() -> Dictionary:
    return social_visitor.next(session,_id("mona_next"))

func mona_story_choose(option_id: String) -> Dictionary:
    return social_visitor.choose(session,option_id,_id("mona_choose"))

func mona_visit_near() -> bool:
    return social_visitor.near(session,graph)

func mona_story_session() -> Dictionary:
    return social_visitor.session_state(session)

func memory_story_begin() -> Dictionary:
    return customer_memory.begin(session,graph,_id("memory_begin"))

func memory_story_next() -> Dictionary:
    return customer_memory.next(session,graph,_id("memory_next"))

func memory_story_choose(option_id: String) -> Dictionary:
    return customer_memory.choose(session,graph,option_id,_id("memory_choose"))

func memory_story_session() -> Dictionary:
    return customer_memory.state(session)

func memory_story_ready() -> bool:
    return session.ink_ready(customer_memory.session_id(session))

func referral_purchase() -> Dictionary:
    return customer_memory.resolve_referral(session,room() == "kiosk" and position().distance_to(COUNTER) <= COUNTER_RADIUS,true,_id("supply_buy"))

func referral_decline() -> Dictionary:
    return customer_memory.resolve_referral(session,room() == "kiosk" and position().distance_to(COUNTER) <= COUNTER_RADIUS,false,_id("supply_decline"))

func market_purchase() -> Dictionary:
    return procurement.resolve(session,room()=="kiosk" and position().distance_to(COUNTER)<=COUNTER_RADIUS,true,_id("market_buy"))

func market_decline() -> Dictionary:
    return procurement.resolve(session,room()=="kiosk" and position().distance_to(COUNTER)<=COUNTER_RADIUS,false,_id("market_decline"))

func sandwich_offers() -> Array[Dictionary]:
    return Sandwich.offers(session)

func sandwich_context() -> Dictionary:
    return Sandwich.context(session)

func sandwich_purchase(index: int) -> Dictionary:
    return Sandwich.purchase(session,index,_id("sandwich_purchase"))

func sandwich_step() -> Dictionary:
    return Sandwich.advance(session,_id("sandwich_step"))

func save_game() -> Dictionary:
    return session.save()

func status() -> Dictionary:
    var v: Dictionary = session.world.view()
    var clock: Dictionary = session.world.calendar()
    var orders: Dictionary = v["service"]["orders"]
    var pending: Array[String] = []
    for key in orders:
        if orders[key]["status"] in ["offered","accepted","delivered"]:
            pending.append(str(key))
    pending.sort_custom(func(a: String,b: String) -> bool:
        var a_done: bool = orders[a]["status"] == "delivered" and orders[a]["payment_status"] == "settled"
        var b_done: bool = orders[b]["status"] == "delivered" and orders[b]["payment_status"] == "settled"
        if a_done != b_done: return not a_done
        if a_done and int(orders[a]["created_minute"]) != int(orders[b]["created_minute"]):
            return int(orders[a]["created_minute"]) > int(orders[b]["created_minute"])
        return a < b)
    var active: Dictionary = orders.get(pending[0], {}) if not pending.is_empty() else {}
    var radio_state: Dictionary = v["housing"]["objects"].get(radio_pack.get("object_id",""),{})
    var bed_state: Dictionary = v["housing"]["objects"].get(bed_pack.get("object_id",""),{})
    var last_quiet: String = ""
    var quiet_count: int = 0
    for event in v["events"]:
        if event["kind"] == "life.activity_done":
            quiet_count += 1
            last_quiet = str(event["payload"]["request"]["activity_id"])
    var tea_context: Dictionary = active_tea_step()
    var aside: Dictionary = ambient_exchange()
    var spoken: Dictionary = customer_reaction()
    var mahmoud_pose: Dictionary = npc_pose("mahmoud")
    var mahmoud_xy: Vector2 = mahmoud_pose.get("position",Vector2.ZERO)
    var latest_tea: Dictionary = {}
    for item in v["cooking"]["items"].values():
        if str(item["recipe_id"]) != "tea" or not str(item["job_id"]).begins_with("play:c3:prep:"):
            continue
        if latest_tea.is_empty() or str(item["event_id"]) > str(latest_tea["event_id"]):
            latest_tea = item
    var quality: Dictionary = session.world.prepared_quality(str(latest_tea.get("item_id",""))) if not latest_tea.is_empty() else {}
    return {
        "customer_memory":customer_memory.memory(session),
        "memory_near":customer_memory.available(session,graph),
        "memory_story_id":customer_memory.session_id(session),
        "memory_story_phase":str(memory_story_session().get("phase","")),
        "memory_story_choices":session.ink_choices(customer_memory.session_id(session)) if memory_story_ready() else [],
        "referral_offer":customer_memory.referral(session),
        "leaves_stock":int(v["cooking"]["stock"].get("leaves",0)),
        "sandwich":sandwich_context(),
        "supply_resolutions":v["economy"]["supply_resolutions"],
        "market_offer":procurement.view(session),
        "supplier_known":session.world.player_knows(CustomerMemory.FACT),
        "conversation_fact_known":session.world.player_knows("salma:evening-boats"),
        "conversation_id":conversation_id(),
        "conversation_near":conversation.available(session,graph),
        "conversation_choices":session.ink_choices(conversation_id()) if conversation.near(session,graph) and session.ink_ready(conversation_id()) else [],
        "conversation_phase":conversation.state(session).get("phase",""),
        "ambient_line":str(aside.get("line","")),
        "ambient_npc":str(aside.get("npc_id","")),
        "ambient_beat":int(aside.get("beat",-1)),
        "npc_mahmoud_mode":str(mahmoud_pose.get("mode","absent")),
        "npc_mahmoud_waypoints":int(mahmoud_pose.get("route_waypoints",0)),
        "npc_mahmoud_x":roundi(mahmoud_xy.x),
        "npc_mahmoud_y":roundi(mahmoud_xy.y),
        "customer_reaction":str(spoken.get("line","")),
        "customer_reaction_npc":str(spoken.get("npc_id","")),
        "customer_reaction_order":str(spoken.get("order_id","")),
        "customer_reaction_event":str(spoken.get("source_event_id","")),
        "tea_quality":str(quality.get("grade","")),
        "tea_technique":TeaTechnique.progress(session),
        "tea_technique_known":session.world.player_knows(TeaTechnique.FACT),
        "tea_quality_score":int(quality.get("score",0)),
        "tea_quality_item":str(quality.get("item_id","")),
        "tea_stage":str(tea_context.get("stage","")),
        "tea_action":str(tea_context.get("key","")),
        "tea_ready_in":int(tea_context.get("ready_in",0)),
        "location": room(),
        "x": int(position().x),
        "y": int(position().y),
        "minute": int(v["world_minute"]),
        "day": int(clock["day_index"]) + 1,
        "hour": int(clock["hour"]),
        "minute_of_hour": int(clock["minute"]),
        "money": session.world.balance_minor(),
        "revision": int(v["sequence"]),
        "digest": JSON.stringify(v).sha256_text(),
        "offer_count": orders.size(),
        "kiosk_open": bool(v["life"]["open"]),
        "sleep_count": int(v["life"]["sleep_count"]),
        "hunger": int(v["needs"]["hunger"]), "rest": int(v["needs"]["rest"]),
        "mood": int(v["needs"]["mood"]),
        "quiet_count": quiet_count,
        "story_opportunities": session.world.narrative_opportunities(),
        "river_story_phase": str(river_story_session().get("phase","")),
        "river_story_choices": session.ink_choices(RIVER_STORY_ID) if session.ink_ready(RIVER_STORY_ID) else [],
        "mahmoud_invitation": mahmoud_invitation(),
        "mahmoud_invite_near": mahmoud_invite_near(),
        "mahmoud_story_phase": str(mahmoud_story_session().get("phase","")),
        "mahmoud_story_deadline": int(mahmoud_story_session().get("reply_deadline_minute",-1)),
        "mahmoud_story_outcome": str(mahmoud_story_session().get("outcome","")),
        "mahmoud_story_choices": session.ink_choices(MAHMOUD_STORY_ID) if session.ink_ready(MAHMOUD_STORY_ID) else [],
        "mona_visit_near": mona_visit_near(),
        "mona_story_phase": str(mona_story_session().get("phase","")),
        "mona_story_choices": session.ink_choices(SocialVisitor.STORY_ID) if session.ink_ready(SocialVisitor.STORY_ID) else [],
        "npc_mona": str(session.world.npc("mona").get("location_id","")),
        "npc_mona_mode": str(npc_pose("mona").get("mode","absent")),
        "player_knows_mona_visit": session.world.player_knows("mona:visiting-salma"),
        "radio_owned": not radio_state.is_empty(),
        "radio_placed": not radio_state.is_empty() and radio_state.get("unit_id","") == radio_pack.get("unit_id","") and radio_state.get("slot_id","") == radio_pack.get("slot_id",""),
        "radio_uses": int(radio_state.get("use_count",0)),
        "bed_owned": not bed_state.is_empty(),
        "bed_placed": not bed_state.is_empty() and bed_state.get("unit_id","") == bed_pack.get("unit_id","") and bed_state.get("slot_id","") == bed_pack.get("slot_id",""),
        "bed_price": int(v["housing"]["types"].get("bed",{}).get("price_minor",0)),
        "last_quiet": last_quiet,
        "active_order": active.get("order_id",""),
        "order_status": active.get("status","none"),
        "order_recipe": active.get("recipe_id",""),
        "order_created_minute": int(active.get("created_minute",-1)),
        "order_npc": active.get("npc_id",""),
        "order_payment": active.get("payment_status","none"),
        "sandwich_price":int(v["economy"]["prices"].get(Sandwich.RECIPE,0)),
        "npc_mahmoud": session.world.npc("mahmoud").get("location_id",""),
        "roof_access": session.world.can_access_unit("roof"),
        "flat_access": session.world.can_access_unit("flat")
    }

func dispose() -> void:
    if graph != null:
        graph.dispose_navigation()
    if session != null:
        session.dispose()
