extends Node2D
## E6/P0 — playable production entry with intentionally provisional 2D shapes.
## No D001 fixture, QA HUD, V001 art import, or scene-owned simulation state.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const Graph = preload("res://scripts/integration/room_traversal.gd")
const Ambient = preload("res://scripts/gameplay/ambient_soundscape.gd")
const SandwichPanel = preload("res://scripts/gameplay/sandwich_panel.gd")
const SandwichControls = preload("res://scripts/gameplay/sandwich_controls.gd")
const WorldTouchControls = preload("res://scripts/gameplay/world_touch_controls.gd")
const NextStepGuide = preload("res://scripts/gameplay/next_step_guide.gd")
const Contextual = preload("res://scripts/gameplay/contextual_interactions.gd")
const RoomFade = preload("res://scripts/gameplay/room_fade.gd")
const WebSaveConfirmation = preload("res://scripts/gameplay/web_save_confirmation.gd")
const MONA_STORY_ID = "mona_visits_salma"
const MOVE_INTERVAL = 0.13
const MINUTE_INTERVAL = 2.0
# Continuous, constant-speed visual traversal of each *authoritative* P2 step.
# Never tween/ease-out anew on every 130ms input tick.
const VISUAL_WORLD_UNITS_PER_SECOND = 17.0 / MOVE_INTERVAL
const CAMERA_MIN_ZOOM = 1.0
const CAMERA_MAX_ZOOM = 3.2
const CAMERA_DEFAULT_ZOOM = 2.0
const CAMERA_FOLLOW_RATE = 9.0
const ISO_X = 1.36 # Current schematic 2:1 basis, not the unapproved V001 art projection.
const ISO_Y = 0.68
const PLAYFIELD = Rect2(100.0,114.0,760.0,238.0) # Reserve HUD, guidance and notices.
const TOUCH_PLAYFIELD = Rect2(246.0,114.0,474.0,238.0) # Unobstructed center between touch columns.

var game: RefCounted
var initialized: bool = false
var notice: String = "Opening the kiosk world..."
var move_elapsed: float = 0.0
var minute_elapsed: float = 0.0
var last_marker: String = ""
var soundscape: Node
var player_body: CharacterBody2D
var player_visual_position: Vector2 = Vector2.ZERO
var visual_frame: Dictionary = {} # Read-only projection of the current P2 room.
var camera_visual_focus: Vector2 = Vector2.ZERO
var camera_zoom: float = CAMERA_DEFAULT_ZOOM
var camera_target_zoom: float = CAMERA_DEFAULT_ZOOM
# Read-only projection cache, updated only after a canonical world change.
# Never changes P2/Ink, saves, command IDs, or game domain state.
var render_state: Dictionary = {}
var pinch_points: Dictionary = {}
var pinch_distance: float = 0.0
var controls_open: bool = false # Local view-only overlay; does not pause P1 world time.
var sandwich_open: bool = false # View-only P3 cooking workstation; time never pauses.
var sandwich_buttons: Control # Standard Godot Buttons, no UI-owned domain data.
var touch_pad: Control # Optional pointer/touch input; no P2 state authority.
var room_fade: CanvasLayer # No canonical world state.
var save_confirmation: RefCounted = WebSaveConfirmation.new() # Display-only; no save data.
var furniture_bodies: Array[StaticBody2D] = []
var story_open: bool = false # View only. P6 owns Ink cursor and narrative choices.
var story_pending: bool = false
var story_line: String = ""
var story_id: String = Game.RIVER_STORY_ID

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
    _frame_current_room()
    _snap_player_visual()
    soundscape = Ambient.new()
    add_child(soundscape)
    sandwich_buttons = SandwichControls.new()
    add_child(sandwich_buttons)
    sandwich_buttons.on_toggle = Callable(self,"_toggle_sandwich")
    sandwich_buttons.on_purchase = Callable(self,"_buy_sandwich")
    sandwich_buttons.on_step = Callable(self,"_ui_sandwich_step")
    sandwich_buttons.on_wait = Callable(self,"_ui_sandwich_wait")
    sandwich_buttons.on_save = Callable(self,"_ui_sandwich_save")
    sandwich_buttons.on_close = Callable(self,"_close_sandwich")
    touch_pad = WorldTouchControls.new()
    add_child(touch_pad)
    touch_pad.on_move = Callable(self,"_touch_move_now")
    touch_pad.on_action = Callable(self,"_touch_action")
    room_fade = RoomFade.new()
    add_child(room_fade)
    initialized = true
    notice = "A quiet evening by the Nile."
    report("E6_GAME_RESTORED" if result["code"] != "NEW_WORLD" else "E6_GAME_READY")

func _exit_tree() -> void:
    if game != null:
        game.dispose()

func report(marker: String) -> void:
    last_marker = marker
    var diagnostic: Dictionary = game.status()
    diagnostic["dialogue_text"] = story_line
    diagnostic["dialogue_id"] = story_id
    diagnostic["help_visible"] = controls_open
    diagnostic["sandwich_visible"] = sandwich_open
    var guide: Dictionary = NextStepGuide.describe(diagnostic)
    diagnostic["next_step_phase"] = guide["phase"]
    diagnostic["next_step_text"] = guide["text"]
    diagnostic["save_storage_status"] = save_confirmation.status
    diagnostic["save_storage_revision"] = save_confirmation.revision
    if not visual_frame.is_empty():
        diagnostic["view_zoom"] = visual_frame["zoom"]
        diagnostic["camera_target_zoom"] = camera_target_zoom
        diagnostic["camera_actor_x"] = _iso(player_visual_position).x
        diagnostic["camera_actor_y"] = _iso(player_visual_position).y
        diagnostic["view_origin_x"] = visual_frame["origin"].x
        diagnostic["view_origin_y"] = visual_frame["origin"].y
        var avatar: Vector2 = _iso(game.position())
        diagnostic["view_actor_x"] = avatar.x
        diagnostic["view_actor_y"] = avatar.y
    diagnostic["sound_enabled"] = soundscape.enabled if soundscape != null else false
    if soundscape != null:
        soundscape.set_context(str(diagnostic["location"]),not str(diagnostic["tea_stage"]).is_empty(),int(diagnostic["hour"]) >= 18 or int(diagnostic["hour"]) < 6)
        diagnostic["sound_room"] = soundscape.room_id
        diagnostic["sound_kettle"] = soundscape.kitchen_active
    print(marker + " " + JSON.stringify(diagnostic))
    render_state = diagnostic
    if sandwich_buttons != null:
        sandwich_buttons.update_view(diagnostic["sandwich"],sandwich_open,
            story_open or story_pending,controls_open)
    _sync_touch_pad(diagnostic)
    queue_redraw()

func _process(delta: float) -> void:
    if not initialized: return
    if save_confirmation.status == "pending":
        match save_confirmation.poll():
            "confirmed":
                notice = "Saved in this browser (revision %d)." % save_confirmation.revision
                report("E6_GAME_SAVE_CONFIRMED")
            "unconfirmed":
                notice = "Saved locally; browser persistence could not be confirmed."
                report("E6_GAME_SAVE_UNCONFIRMED")
    if story_pending and (game.memory_story_ready() if story_id.begins_with("memory:") else game.session.ink_ready(story_id)):
        _story_action("begin")
    if story_open and story_id.begins_with("river_neighbors:") and not game.conversation.near(game.session,game.graph):
        story_open=false
        story_pending=false
        story_line=""
        notice="Their voices fade. Your response can wait."
        report("E4_CONVERSATION_LEFT")
    # Runtime input drives canonical integer movement; no extra scene position.
    move_elapsed += minf(delta, 0.25)
    minute_elapsed += minf(delta, 0.25)
    if controls_open or sandwich_open or (room_fade != null and room_fade.fading):
        move_elapsed = 0.0
    elif move_elapsed >= MOVE_INTERVAL:
        move_elapsed = fmod(move_elapsed, MOVE_INTERVAL)
        if (story_open or story_pending) and not story_id.begins_with("river_neighbors:"):
            move_elapsed = 0.0
        else:
            _process_movement()
    _process_clock()
    _advance_visual_camera(delta)

# The renderer may run at any frame rate; P2 world commands still execute
# exactly once per MOVE_INTERVAL and never depend on this frame rate.
func _advance_visual_camera(delta: float) -> void:
    var old_actor: Vector2 = player_visual_position
    var old_focus: Vector2 = camera_visual_focus
    var old_zoom: float = camera_zoom
    player_visual_position = visual_step_toward(player_visual_position,game.position(),delta)
    var t: float = 1.0 - exp(-CAMERA_FOLLOW_RATE * minf(delta,0.1))
    camera_visual_focus = camera_visual_focus.lerp(player_visual_position,t)
    camera_zoom = lerpf(camera_zoom,camera_target_zoom,t)
    if (old_actor.distance_to(player_visual_position) > 0.001 or
            old_focus.distance_to(camera_visual_focus) > 0.001 or
            absf(camera_zoom - old_zoom) > 0.0001):
        _frame_current_room()
        queue_redraw()

func _process_movement() -> void:
    var dx: int = int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
    var dy: int = int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
    if touch_pad != null and touch_pad.held_direction != Vector2i.ZERO:
        dx = touch_pad.held_direction.x
        dy = touch_pad.held_direction.y
    if dx != 0 or dy != 0:
        var intended: Vector2i = Game.screen_delta(dx,dy)
        if _player_move_clear(Vector2(intended)):
            var moved: Dictionary = game.move_screen(dx, dy)
            if moved.get("ok", false):
                # Visual animation advances every rendered frame above.
                # Movement redraws don't issue debug status reports. Refresh
                # the actual Godot opener at the canonical P2 near boundary.
                render_state = game.status()
                if sandwich_buttons != null:
                    sandwich_buttons.update_view(render_state["sandwich"],sandwich_open,
                        story_open or story_pending,controls_open)
                if touch_pad != null and touch_pad.mode_enabled:
                    _sync_touch_pad(render_state)
                queue_redraw()

func _process_clock() -> void:
    if minute_elapsed >= MINUTE_INTERVAL:
        minute_elapsed = fmod(minute_elapsed, MINUTE_INTERVAL)
        var tick: Dictionary = game.wait_minutes(1)
        if tick.get("ok", false):
            render_state = game.status()
            if soundscape != null:
                var state: Dictionary = render_state
                soundscape.set_context(str(state["location"]),not str(state["tea_stage"]).is_empty(),int(state["hour"]) >= 18 or int(state["hour"]) < 6)
            # This is display-only: heat cues follow the actual P1 tick,
            # without a UI-owned timer or extra simulation command.
            if sandwich_buttons != null and sandwich_open:
                sandwich_buttons.update_view(render_state["sandwich"],sandwich_open,
                    story_open or story_pending,controls_open)
            if touch_pad != null and touch_pad.mode_enabled:
                _sync_touch_pad(render_state)
            queue_redraw()

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

# Fixed-rate, non-easing chase: at 30/60/120fps the same canonical
# displacement takes the same time, never overshoots a target or influences P2.
static func visual_step_toward(previous: Vector2, target: Vector2, delta: float) -> Vector2:
    if not previous.is_finite() or not target.is_finite() or not is_finite(delta):
        return previous
    return previous.move_toward(target,VISUAL_WORLD_UNITS_PER_SECOND*maxf(0.0,delta))

# World P2 owns positions; view snap is reserved for boot/actual room changes.
func _snap_player_visual() -> void:
    player_visual_position = game.position()
    camera_visual_focus = player_visual_position
    camera_zoom = camera_target_zoom
    _frame_current_room()
    queue_redraw()

# Input is presentation-only zoom. Wheel on desktop, multi-touch pinch on
# phones, and platform magnify gestures change *only* camera parameters.
static func clamped_camera_zoom(current: float, factor: float) -> float:
    if not is_finite(current) or not is_finite(factor) or factor <= 0.0:
        return CAMERA_DEFAULT_ZOOM
    return clampf(current * factor,CAMERA_MIN_ZOOM,CAMERA_MAX_ZOOM)

func _apply_camera_zoom(factor: float) -> void:
    var next: float = clamped_camera_zoom(camera_target_zoom,factor)
    if not is_equal_approx(next,camera_target_zoom):
        camera_target_zoom = next
        report("E6_CAMERA_ZOOM")

func _pinch_distance() -> float:
    if pinch_points.size() != 2: return 0.0
    var points: Array = pinch_points.values()
    return Vector2(points[0]).distance_to(Vector2(points[1]))

func _input(event: InputEvent) -> void:
    if not initialized or controls_open or sandwich_open or story_open: return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: _apply_camera_zoom(1.12)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _apply_camera_zoom(1.0 / 1.12)
    elif event is InputEventMagnifyGesture:
        _apply_camera_zoom(event.factor)
    elif event is InputEventScreenTouch:
        if event.pressed: pinch_points[event.index] = event.position
        else: pinch_points.erase(event.index)
        pinch_distance = _pinch_distance()
    elif event is InputEventScreenDrag and pinch_points.has(event.index):
        pinch_points[event.index] = event.position
        var distance: float = _pinch_distance()
        if distance > 0.0 and pinch_distance > 0.0:
            _apply_camera_zoom(distance / pinch_distance)
        pinch_distance = distance

# Fade covers a genuine spatial.player.travel and releases input only after
# the destination has appeared. Unlike a new loading scene, the WorldKernel,
# clock, NPCs, Ink and P3 jobs remain alive throughout the transition.
func _begin_door_fade() -> bool:
    if room_fade == null or room_fade.fading or game.nearest_portal().is_empty():
        return false
    var started: bool = room_fade.transition(
        Callable(self,"_commit_door_covered"),
        Callable(self,"_complete_door_fade"))
    if started:
        report("E6_TRAVEL_FADE_START")
    return started

func _commit_door_covered() -> void:
    var result: Dictionary = game.travel_near()
    if result.get("ok",false):
        _snap_player_visual()
        notice = "You step into " + game.room() + "."
    else:
        notice = "Door: " + str(result.get("code","UNKNOWN"))

func _complete_door_fade() -> void:
    report("E6_GAME_DOOR")

func _act(kind: String, offer_index: int = -1) -> void:
    if kind == "door" and _begin_door_fade():
        return
    if room_fade != null and room_fade.fading:
        return
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
        "market_buy": result = game.market_purchase()
        "market_decline": result = game.market_decline()
        "supply_buy": result = game.referral_purchase()
        "supply_decline": result = game.referral_decline()
        "sandwich_purchase": result = game.sandwich_purchase(offer_index)
        "sandwich_step": result = game.sandwich_step()
    if result.get("ok", false):
        if kind == "door":
            _frame_current_room()
            _snap_player_visual()
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
            "market_buy":"You collect 30g leaves from the market. Paid 450; 40 minutes away. The kiosk kept running.",
            "market_decline":"You leave the market collection for another day. Nothing spent or received.",
            "supply_buy":"Hoda's runner brings 30g leaves. Paid 550 piastres; 15 minutes pass.",
            "supply_decline":"You leave the delivery offer. No money or stock changes hands.",
            "bed_store":"The bed is put away. Sleep will be simpler tonight.",
            "sandwich_purchase":str(result.get("caption","Ingredients purchased.")),
            "sandwich_step":str(result.get("caption","Preparing liver sandwich."))
        }.get(kind, "Done")
    else:
        notice = str(result.get("caption",kind.capitalize() + ": " + str(result.get("code","UNKNOWN"))))
    if kind == "save" and result.get("ok",false) and OS.has_feature("web"):
        save_confirmation.begin(game.session.save_path, int(result["revision"]),
            str(game.status()["digest"]))
        notice = "Verifying the browser save..." if save_confirmation.status == "pending" else \
            "Saved locally; browser persistence could not be confirmed."
    report("E6_GAME_" + kind.to_upper())

func _story_action(kind: String, option_id: String = "") -> void:
    var result: Dictionary = {}
    if story_id.begins_with("river_neighbors:"):
        match kind:
            "begin": result = game.conversation_begin()
            "next": result = game.conversation_next()
            "choose": result = game.conversation_choose(option_id)
    elif story_id.begins_with("memory:"):
        match kind:
            "begin": result = game.memory_story_begin()
            "next": result = game.memory_story_next()
            "choose": result = game.memory_story_choose(option_id)
    elif story_id == MONA_STORY_ID:
        match kind:
            "begin": result = game.mona_story_begin()
            "next": result = game.mona_story_next()
            "choose": result = game.mona_story_choose(option_id)
    elif story_id == Game.MAHMOUD_STORY_ID:
        match kind:
            "begin": result = game.mahmoud_story_begin()
            "next": result = game.mahmoud_story_next()
            "choose": result = game.mahmoud_story_choose(option_id)
    else:
        match kind:
            "begin": result = game.river_story_begin()
            "next": result = game.river_story_next()
            "choose": result = game.river_story_choose(option_id)
    if not result.get("ok", false):
        if kind == "begin" and result.get("code", "") == "INK_LOADING":
            story_pending = true
            notice = "Someone is getting ready to talk..."
        else:
            story_pending = false
            notice = "Conversation: " + str(result.get("code", "UNKNOWN"))
        report(_story_prefix() + ("LOADING" if story_pending else "REJECTED"))
        return
    story_pending = false
    var code: String = str(result.get("code", ""))
    match code:
        "STARTED", "RESUMED":
            story_open = true
            story_line = ("Salma and Mahmoud turn toward you." if story_id.begins_with("river_neighbors:") else "Mahmoud remembers your last encounter." if story_id.begins_with("memory:") else ("Mona came by for Salma." if story_id == MONA_STORY_ID else ("Mahmoud called you over." if story_id == Game.MAHMOUD_STORY_ID else "Salma is here."))) + " Press Enter to listen."
            notice = "A moment beside the Nile."
        "LINE":
            story_open = true
            story_line = str(result.get("text", ""))
            var speaker: String = str(result.get("speaker_id", "salma")).capitalize() + ": "
            if not story_line.begins_with(speaker): story_line = speaker + story_line
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
    report(_story_prefix() + (code if code in ["STARTED","RESUMED","LINE","WAITING","FINISHED"] else "CHOICE"))

func _story_prefix() -> String:
    if story_id.begins_with("river_neighbors:"): return "E4_CONVERSATION_"
    if story_id.begins_with("memory:"): return "E4_MEMORY_"
    return "E4_VISITOR_" if story_id == MONA_STORY_ID else ("E4_NPC_" if story_id == Game.MAHMOUD_STORY_ID else "E4_STORY_")

func _story_choices(state: Dictionary) -> Array:
    if story_id.begins_with("river_neighbors:"): return state["conversation_choices"]
    if story_id.begins_with("memory:"): return state["memory_story_choices"]
    return state["mona_story_choices"] if story_id == MONA_STORY_ID else (state["mahmoud_story_choices"] if story_id == Game.MAHMOUD_STORY_ID else state["river_story_choices"])

func _toggle_sandwich() -> void:
    if story_open or story_pending or controls_open: return
    if not sandwich_open and not bool(game.sandwich_context().get("near",false)):
        notice = "Move within reach of the sandwich counter."
        report("E6_SANDWICH_TOGGLE")
        return
    sandwich_open = not sandwich_open
    notice = "Working at the counter." if sandwich_open else "Back to the kiosk."
    report("E6_SANDWICH_TOGGLE")

func _close_sandwich() -> void:
    if not sandwich_open: return
    sandwich_open = false
    notice = "Back to the kiosk."
    report("E6_SANDWICH_TOGGLE")

func _buy_sandwich(index: int) -> void:
    if sandwich_open and not story_open and not story_pending:
        _act("sandwich_purchase",index)

func _ui_sandwich_step() -> void:
    if sandwich_open and not story_open and not story_pending: _act("sandwich_step")

func _ui_sandwich_wait() -> void:
    if sandwich_open and not story_open and not story_pending: _act("wait")

func _ui_sandwich_save() -> void:
    if sandwich_open and not story_open and not story_pending: _act("save")

func _sync_touch_pad(state: Dictionary) -> void:
    if touch_pad == null or not initialized: return
    var portal: Dictionary = game.nearest_portal()
    var portal_near: bool = false
    if not portal.is_empty():
        var unit_id: String = str(portal["unit_id"])
        portal_near = unit_id.is_empty() or game.session.world.can_access_unit(unit_id)
    var counter_near: bool = game.room() == "kiosk" and \
        game.position().distance_to(Game.COUNTER) <= Game.COUNTER_RADIUS
    var salma: Dictionary = game.npc_pose("salma")
    var near_salma: bool = game.river_story_available() and not salma.is_empty() and \
        game.room() == "kiosk" and game.position().distance_to(salma["position"]) <= Graph.RADIUS
    var talk_action: String = WorldTouchControls.dialogue_target(state,near_salma)
    touch_pad.update_view(state,portal_near,counter_near,
        story_open or story_pending,controls_open or sandwich_open,talk_action,
        story_open,_story_choices(state) if story_open else [],
        _context_actions(state))

# Input-only read of authoritative P2 proximity, service and narrative state.
# Called again on each press: a stale hint never grants a command.
func _context_actions(state: Dictionary) -> Array[Dictionary]:
    var portal: Dictionary = game.nearest_portal()
    var destination: String = ""
    if not portal.is_empty():
        var unit_id: String = str(portal["unit_id"])
        if unit_id.is_empty() or game.session.world.can_access_unit(unit_id):
            destination = str(portal["to"])
    var counter_near: bool = game.room() == "kiosk" and \
        game.position().distance_to(Game.COUNTER) <= Game.COUNTER_RADIUS
    var salma: Dictionary = game.npc_pose("salma")
    var near_salma: bool = game.river_story_available() and not salma.is_empty() and \
        game.room() == "kiosk" and game.position().distance_to(salma["position"]) <= Graph.RADIUS
    var target: String = WorldTouchControls.dialogue_target(state,near_salma)
    var quiet_near: bool = false
    for activity in game.quiet_activities():
        if activity["room_id"] != game.room(): continue
        if activity.get("requires_closed",false) and bool(state.get("kiosk_open",false)):
            continue
        if game.position().distance_to(Vector2(int(activity["x"]),int(activity["y"]))) <= int(activity["radius"]):
            quiet_near = true
            break
    return Contextual.resolve(state,destination,counter_near,quiet_near,target,
        bool(state.get("sandwich",{}).get("near",false)))

func _begin_context_talk() -> void:
    var state: Dictionary = game.status()
    var salma: Dictionary = game.npc_pose("salma")
    var near_salma: bool = game.river_story_available() and not salma.is_empty() and \
        game.room() == "kiosk" and game.position().distance_to(salma["position"]) <= Graph.RADIUS
    match WorldTouchControls.dialogue_target(state,near_salma):
        "neighbors": story_id = game.conversation_id()
        "memory": story_id = game.customer_memory.session_id(game.session)
        "mona": story_id = MONA_STORY_ID
        "mahmoud": story_id = Game.MAHMOUD_STORY_ID
        "salma": story_id = Game.RIVER_STORY_ID
        _: return
    _story_action("begin")

func _context_action(index: int) -> void:
    if story_open or story_pending or sandwich_open or controls_open: return
    var choices: Array[Dictionary] = _context_actions(game.status())
    if index < 0 or index >= choices.size(): return
    var kind: String = str(choices[index]["kind"])
    if kind == "talk": _begin_context_talk()
    elif kind == "sandwich": _toggle_sandwich()
    else: _act(kind)

func _touch_move_now() -> void:
    if not initialized or story_open or story_pending or controls_open or sandwich_open or (room_fade != null and room_fade.fading):
        return
    move_elapsed = 0.0
    _process_movement()

func _touch_action(action: String) -> void:
    if not initialized or touch_pad == null or (room_fade != null and room_fade.fading): return
    # On-screen._toggle changes mode_enabled *before* emitting this callback.
    # Process both opening and closing; only gate subsequent world actions.
    if action == "toggle":
        _frame_current_room()
        _snap_player_visual()
        report("E6_TOUCH_TOGGLE")
        return
    if action == "menu":
        report("E6_TOUCH_MENU")
        return
    if not touch_pad.mode_enabled: return
    if story_open and not controls_open and not sandwich_open:
        var choices: Array = _story_choices(game.status())
        match action:
            "next":
                if choices.is_empty(): _story_action("next")
            "choice_0", "choice_1":
                var index: int = 0 if action == "choice_0" else 1
                if index < choices.size():
                    _story_action("choose",str(choices[index]["option_id"]))
            "leave": _dismiss_story()
        return
    if story_pending or controls_open or sandwich_open: return
    match action:
        "primary": _context_action(0)
        "alternate": _context_action(1)
        "save": _act("save")
        "wait": _act("wait")

func _dismiss_story() -> void:
    story_open = false
    story_pending = false
    story_line = ""
    notice = "You can return to the conversation later."
    report("E4_STORY_DISMISS")

func _unhandled_key_input(event: InputEvent) -> void:
    if not initialized or (room_fade != null and room_fade.fading) or not (event is InputEventKey) or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F1:
        controls_open = not controls_open
        report("E6_HELP_TOGGLE")
        return
    if controls_open:
        if event.keycode == KEY_ESCAPE:
            controls_open = false
            report("E6_HELP_TOGGLE")
        return
    if event.keycode == KEY_F7 and not (story_open or story_pending):
        _toggle_sandwich()
        return
    if sandwich_open:
        # The same primary/alternate E/F keys operate the hands-on station.
        # No six ingredient hotkeys or Enter-Enter micro-menu progression.
        match event.keycode:
            KEY_ESCAPE: _close_sandwich()
            KEY_E:
                if sandwich_buttons != null: sandwich_buttons._primary_pressed()
            KEY_F:
                if sandwich_buttons != null: sandwich_buttons._secondary_pressed()
            KEY_P: _act("save")
        return
    if event.keycode == KEY_0:
        var sound_on: bool = soundscape.toggle_sound() if soundscape != null else false
        notice = "Ambient sound on." if sound_on else "Ambient sound off."
        report("E6_AUDIO_TOGGLE")
        return
    if story_open or story_pending:
        if story_id.begins_with("river_neighbors:") and event.keycode not in [KEY_ENTER,KEY_KP_ENTER,KEY_1,KEY_2,KEY_ESCAPE,KEY_P]:
            # Keep the actual cooking/movement controls usable while listening.
            if event.keycode == KEY_H: _act("tea_heat")
            elif event.keycode == KEY_U: _act("tea_pour")
            elif event.keycode == KEY_G: _act("serve")
            elif event.keycode == KEY_J: _act("wait")
            elif event.keycode == KEY_E: _act("door")
            return
        match event.keycode:
            KEY_ENTER, KEY_KP_ENTER:
                if story_open: _story_action("next")
            KEY_1, KEY_2:
                if story_open:
                    var options: Array = _story_choices(game.status())
                    var index: int = 0 if event.keycode == KEY_1 else 1
                    if index < options.size(): _story_action("choose",str(options[index]["option_id"]))
            KEY_ESCAPE: _dismiss_story()
            KEY_P: _act("save")
        return
    match event.keycode:
        KEY_T:
            if game.room()=="roof": _act("bed")
            else:
                story_id = game.conversation_id()
                _story_action("begin")
        KEY_F5: _act("market_buy")
        KEY_F6: _act("market_decline")
        KEY_F3: _act("supply_buy")
        KEY_F4: _act("supply_decline")
        KEY_F2:
            if game.status()["memory_near"]:
                story_id = game.customer_memory.session_id(game.session)
                _story_action("begin")
        KEY_N:
            story_id = Game.RIVER_STORY_ID
            _story_action("begin")
        KEY_M:
            story_id = Game.MAHMOUD_STORY_ID
            _story_action("begin")
        KEY_L:
            story_id = MONA_STORY_ID
            _story_action("begin")
        KEY_I:
            var declined: Dictionary = game.mahmoud_story_decline()
            notice = "You let Mahmoud return to his evening." if declined.get("ok",false) else "Invitation: " + str(declined.get("code","UNKNOWN"))
            report("E4_NPC_DECLINED" if declined.get("ok",false) else "E4_NPC_REJECTED")
        KEY_E: _context_action(0)
        KEY_F: _context_action(1)
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
        KEY_Y: _act("bed_store")

# Hints read existing world/player proximity only. They do not grant access,
# initiate actions, manufacture knowledge or become save/replay authority.
static func context_hint(state: Dictionary, exit_name: String,
        quiet_near: bool, counter_near: bool) -> String:
    if str(state.get("location","")) == "kiosk":
        if counter_near and not str(state.get("tea_stage","")).is_empty():
            var action: String = str(state.get("tea_action",""))
            var remaining: int = int(state.get("tea_ready_in",0))
            return "%s · Tea ready in %d world min" % [action, remaining] if remaining > 0 else \
                "%s · %s tea step" % [action, "Finish" if state.get("tea_stage") == "active" else "Start"]
        if state.get("conversation_near",false):
            return "T · Join the nearby conversation"
        if counter_near and state.get("order_recipe","") == "liver_sandwich":
            return "G · Accept Salma's sandwich order" if state.get("order_status","") == "offered" else \
                "F7 · Cook Salma's sandwich, then G to serve" if state.get("order_status","") == "accepted" else \
                "G · Collect payment for Salma's sandwich"
        if counter_near and not str(state.get("active_order","")).is_empty():
            return "G · Continue the customer order"
    if not exit_name.is_empty():
        return "E · Go to " + exit_name
    if quiet_near:
        return "Q · Take a quiet moment"
    if str(state.get("location","")) == "roof":
        if state.get("bed_placed",false):
            return "Z · Rest at home"
        if state.get("radio_placed",false):
            return "R · Listen to your radio"
    if str(state.get("location","")) == "kiosk":
        if not state.get("kiosk_open",false):
            return "O · Open the kiosk when ready"
        if counter_near:
            return "J · Let a little time pass"
    return "WASD · Explore    F1 · Controls"

# Current schematic renderer: one authored projection, sized to the space
# *between* the HUD and interaction notices. No room-specific magic offsets,
# player-follow game state or migration of V001 sprite anchors is involved.
static func frame_for_room(room_size: Vector2, pad_visible: bool = false) -> Dictionary:
    if not room_size.is_finite() or room_size.x <= 0.0 or room_size.y <= 0.0:
        return {}
    var safe_area: Rect2 = TOUCH_PLAYFIELD if pad_visible else PLAYFIELD
    var ground_span: float = room_size.x + room_size.y
    var zoom: float = minf(1.0,minf(safe_area.size.x / (ground_span * ISO_X),
        safe_area.size.y / (ground_span * ISO_Y)))
    var middle: Vector2 = room_size / 2.0
    var projected_middle := Vector2((middle.x-middle.y)*ISO_X,
        (middle.x+middle.y)*ISO_Y)
    return {"zoom":zoom,"origin":safe_area.get_center() - projected_middle*zoom}

static func project_in_frame(point: Vector2, frame: Dictionary) -> Vector2:
    return frame["origin"] + Vector2((point.x-point.y)*ISO_X,
        (point.x+point.y)*ISO_Y) * float(frame["zoom"])

# Keep the player's smoothed *visual* feet in the safe center, not the
# room's center. This is a closer dolly which never moves canonical P2 state.
static func camera_frame(room_size: Vector2, focus: Vector2, factor: float,
        pad_visible: bool = false) -> Dictionary:
    var frame: Dictionary = frame_for_room(room_size,pad_visible)
    if frame.is_empty() or not focus.is_finite(): return {}
    var safe: Rect2 = TOUCH_PLAYFIELD if pad_visible else PLAYFIELD
    frame["zoom"] = maxf(1.15,float(frame["zoom"]) * clampf(factor,CAMERA_MIN_ZOOM,CAMERA_MAX_ZOOM))
    frame["origin"] = safe.get_center() - Vector2(
        (focus.x - focus.y)*ISO_X,(focus.x + focus.y)*ISO_Y) * float(frame["zoom"])
    return frame

func _frame_current_room() -> void:
    var dimensions: Dictionary = game.graph.rooms[game.room()]
    visual_frame = camera_frame(Vector2(dimensions["width"],dimensions["height"]),
        camera_visual_focus,camera_zoom,touch_pad != null and touch_pad.mode_enabled)

func _iso(point: Vector2) -> Vector2:
    return project_in_frame(point, visual_frame)

func _floor_polygon(from_point: Vector2, to_point: Vector2) -> PackedVector2Array:
    return PackedVector2Array([
        _iso(from_point),
        _iso(Vector2(to_point.x,from_point.y)),
        _iso(to_point),
        _iso(Vector2(from_point.x,to_point.y))
    ])

func _text(p: Vector2, line: String, size: int = 16,
        color: Color = Color("#eadfc4"), max_width: float = -1.0) -> void:
    draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,max_width,size,color)

func _need(at: Vector2, name: String, value: int, color: Color) -> void:
    _text(at,name,13,Color("#d4c9b8"))
    draw_rect(Rect2(at + Vector2(54,-10),Vector2(62,7)),Color("#3b4449"))
    draw_rect(Rect2(at + Vector2(54,-10),Vector2(62.0 * float(value) / 100.0,7)),color)

func _figure(at: Vector2, color: Color, label: String) -> void:
    var foot: Vector2 = _iso(at)
    var size_factor: float = clampf(float(visual_frame.get("zoom",1.0)),0.75,3.2)
    draw_ellipse(foot+Vector2(0,2)*size_factor,13.0*size_factor,
        5.0*size_factor,Color(0,0,0,0.3))
    draw_rect(Rect2(foot+Vector2(-7,-27)*size_factor,
        Vector2(14,20)*size_factor),color)
    draw_circle(foot+Vector2(0,-32)*size_factor,8*size_factor,
        Color("#dcae7d"))
    _text(foot+Vector2(-22,-46)*size_factor,label,
        maxi(12,roundi(12.0*size_factor)),Color("#fff2d5"))

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#101a21"))
    if not initialized:
        _text(Vector2(45,260),notice,20)
        return
    # Never reconstruct/rehash the entire event-sourced world for every
    # animation frame. Only P2 moves, P1 ticks and explicit actions refresh it.
    var state: Dictionary = render_state if not render_state.is_empty() else game.status()
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
    var quiet_near: bool = false
    for activity in game.quiet_activities():
        if activity["room_id"] != location: continue
        var center: Vector2 = _iso(Vector2(int(activity["x"]),int(activity["y"])))
        var reachable: bool = game.position().distance_to(Vector2(int(activity["x"]),int(activity["y"]))) <= int(activity["radius"])
        if activity.get("requires_closed",false) and state["kiosk_open"]:
            reachable = false
        if reachable: quiet_near = true
        if reachable:
            draw_circle(center,7,Color("#f0cb7f"))
            _text(center + Vector2(-32,-17),str(activity["id"]).replace("_"," "),12,
                Color("#f3e1bb"))
    if location == "roof":
        var radio_spot: Dictionary = game.radio_pack.get("activity",{})
        if not radio_spot.is_empty():
            var radio_pos: Vector2 = _iso(Vector2(int(radio_spot["x"]),int(radio_spot["y"])))
            if state["radio_placed"]:
                draw_rect(Rect2(radio_pos + Vector2(-10,-17),Vector2(20,16)),Color("#bb9a69"))
                draw_circle(radio_pos + Vector2(-4,-9),4,Color("#343d3c"))
                draw_rect(Rect2(radio_pos + Vector2(4,-14),Vector2(5,10)),Color("#3d4e50"))
                _text(radio_pos+Vector2(-20,-24),"Radio",12)
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
            if pose["mode"] in ["approaching","counter","takeaway","table","arriving","leaving","visiting"]:
                _text(_iso(pose["position"])+Vector2(-26,-57),
                    "Visiting Salma" if pose["mode"] == "visiting" else ("Ordering" if pose["mode"] == "approaching" else str(pose["mode"]).capitalize()),11,Color("#e8d0a3"))
            var speech: String = ""
            if npc_id == state["customer_reaction_npc"]:
                speech = str(state["customer_reaction"])
            elif npc_id == state["ambient_npc"]:
                speech = str(state["ambient_line"])
            elif npc_id == "salma" and str(state["tea_technique"].get("item_id","")) != "" and \
                    state["minute"] - int(state["tea_technique"]["created_minute"]) <= 25 and \
                    game.position().distance_to(pose["position"]) <= Graph.RADIUS:
                # A nearby mentor acknowledges only a genuine post-advice P3
                # cup and its actual quality; this caption is not a P2 fact,
                # a free P3 bonus or a new autonomous dialogue state.
                speech = "You lifted it in time. That is the trick." if \
                    state["tea_technique"]["phase"] == "understood" else \
                    "The kettle stayed too long. Try again next time."
            if not speech.is_empty():
                var npc_pos: Vector2 = _iso(pose["position"])
                var left: float = clampf(npc_pos.x - 130.0,16.0,640.0)
                draw_rect(Rect2(left,npc_pos.y-98.0,300.0,28.0),Color("#263a3d"))
                _text(Vector2(left+9.0,npc_pos.y-79.0),speech,14,Color("#f0d6a2"))
    _figure(player_visual_position,Color("#78a8b8"),"You")
    draw_rect(Rect2(0,0,960,64),Color("#172128"))
    _text(Vector2(24,28),"KIOSK ON THE NILE",22,Color("#efbd73"))
    _text(Vector2(480,27),"Day %d   %02d:%02d" % [state["day"],state["hour"],state["minute_of_hour"]],17)
    _text(Vector2(765,27),"%d piastres" % state["money"],16)
    _text(Vector2(25,53),"KIOSK OPEN" if state["kiosk_open"] else "KIOSK CLOSED",14,
        Color("#abdb9f") if state["kiosk_open"] else Color("#e1aa91"))
    _need(Vector2(245,53),"Hunger",state["hunger"],Color("#d4ae78"))
    _need(Vector2(385,53),"Rest",state["rest"],Color("#8badc6"))
    _need(Vector2(525,53),"Mood",state["mood"],Color("#96b79a"))
    var counter_near: bool = location == "kiosk" and game.position().distance_to(Game.COUNTER) <= Game.COUNTER_RADIUS
    var portal_near: Dictionary = game.nearest_portal()
    var exit_name: String = ""
    if not portal_near.is_empty():
        var unit_id: String = str(portal_near["unit_id"])
        if unit_id.is_empty() or game.session.world.can_access_unit(unit_id):
            exit_name = str(portal_near["to"])
    if location == "kiosk" and not state["tea_stage"].is_empty():
        draw_rect(Rect2(0,408,960,38),Color("#263a3d"))
        var guidance: String = "Tea · %s" % [
            "Ready in %d world minute(s)" % state["tea_ready_in"] if state["tea_ready_in"] > 0 else
            ("Ready to lift" if state["tea_stage"] == "active" else "Next step ready")]
        _text(Vector2(28,431),guidance,18,Color("#f0d6a2"))
    if location == "kiosk" and state["tea_stage"].is_empty() and not state["tea_quality"].is_empty():
        draw_rect(Rect2(0,408,960,38),Color("#263a3d"))
        _text(Vector2(28,431),"Last tea: " + str(state["tea_quality"]) + " · timing stays with the prepared cup",17,Color("#f0d6a2"))
    draw_rect(Rect2(0,447,960,93),Color("#172128"))
    _text(Vector2(28,472),notice,17)
    # Only nearby currently actionable verbs are shown. Save and audio
    # remain utilities, not permanent world-interaction buttons.
    var available: Array[Dictionary] = _context_actions(state)
    var prompts: PackedStringArray = PackedStringArray()
    for i in range(available.size()):
        prompts.append(("%s  %s" % ["E" if i == 0 else "F",str(available[i]["label"])]))
    if not prompts.is_empty():
        _text(Vector2(28,502),"     ".join(prompts),16,Color("#e2c18b"),904)
    if not state["active_order"].is_empty():
        _text(Vector2(555,526),str(state["order_recipe"]).replace("_"," ") + " · " + str(state["order_status"]),14,Color("#d2b98c"))
    # Market/referral verbs are already shown by the live E/F resolver below.
    # Do not paint parallel F3/F4/F5/F6 shortcut walls over the isometric scene.
    if story_open or story_pending:
        draw_rect(Rect2(60,242,840,192),Color("#162d31"))
        draw_rect(Rect2(60,242,840,3),Color("#e1bd81"))
        _text(Vector2(84,280),"Salma & Mahmoud · By the river" if story_id.begins_with("river_neighbors:") else "Mahmoud · A familiar customer" if story_id.begins_with("memory:") else ("Mona · Here to see Salma" if story_id == MONA_STORY_ID else ("Mahmoud · A word after tea" if story_id == Game.MAHMOUD_STORY_ID else "By the Nile · Salma")),20,Color("#f0d8a8"))
        _text(Vector2(84,315),story_line if not story_pending else "Opening conversation...",17)
        var choices: Array = _story_choices(state)
        if choices.is_empty():
            _text(Vector2(84,394),"Enter · Continue       Esc · Leave       P · Save",15,Color("#ddbb7f"))
        else:
            for i in range(mini(choices.size(),2)):
                _text(Vector2(84,356+i*25),"%d · %s" % [i+1, str(choices[i]["text"])],16,Color("#ddbb7f"))
            _text(Vector2(610,411),"Esc · Leave   P · Save",13,Color("#ddbb7f"))
    if controls_open:
        # Built-in draw primitives form an intentionally provisional overlay;
        # later approved visual assets can replace presentation independently.
        draw_rect(Rect2(0,64,960,383),Color(0.03,0.055,0.065,0.94))
        draw_rect(Rect2(140,86,680,344),Color("#1c3035"))
        draw_rect(Rect2(140,86,680,4),Color("#e8bc75"))
        _text(Vector2(168,128),"A QUIET DAY · CONTROLS",23,Color("#f3d59a"))
        _text(Vector2(168,155),"Actions work only in the right place. World time keeps moving.",
            14,Color("#d8c8b2"),635)
        var guide: PackedStringArray = PackedStringArray([
            "WASD / Arrows    Move around the isometric scene",
            "E    Primary nearby action     F    Alternate nearby action",
            "Mouse wheel / Pinch    Camera zoom",
            "On-screen    Optional touch movement pad",
            "Menu    Save and wait (touchscreen utility panel)",
            "P    Save game     0    Toggle ambient sound",
            "Only reachable actions appear. World time keeps moving.",
            "Some early-game furniture/supplier shortcuts are still available",
            "during the gameplay transition; they will join E/F in P1b."
        ])
        for i in range(guide.size()):
            _text(Vector2(168,194+i*22),guide[i],15,Color("#f1e2cd"),635)
        _text(Vector2(168,415),"F1 or Esc · Back to the evening",15,Color("#edc27d"))
    if sandwich_open:
        SandwichPanel.draw(self,state["sandwich"],
            sandwich_buttons.selected_offer_index if sandwich_buttons != null else -1)
