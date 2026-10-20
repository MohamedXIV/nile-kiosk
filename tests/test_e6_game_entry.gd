extends SceneTree
## E6/P0 acceptance: separate gameplay catalog, real portals, demand, service and disk replay.
const Game = preload("res://scripts/gameplay/game_entry.gd")
const GameScene = preload("res://scripts/gameplay/game_scene.gd")
const WorldTouchControls = preload("res://scripts/gameplay/world_touch_controls.gd")
const SandwichControls = preload("res://scripts/gameplay/sandwich_controls.gd")
const NextStepGuide = preload("res://scripts/gameplay/next_step_guide.gd")
const Contextual = preload("res://scripts/gameplay/contextual_interactions.gd")
const Kernel = preload("res://scripts/core/world_kernel.gd")
const SAVE = "user://nk-e6-game-entry-acceptance.json"
var failures: Array[String] = []

func _initialize() -> void:
    _run()
    if failures.is_empty():
        print("E6 GAME ENTRY: PASS (canonical opening, traversal, demand, cooking, payment, save/reload)")
        quit(0)
    else:
        for f in failures: push_error(f)
        print("E6 GAME ENTRY: FAIL (%d)" % failures.size())
        quit(1)

func check(value: bool, label: String) -> void:
    if not value: failures.append(label)

func _run() -> void:
    # P0 game-feel: constant-speed view-only traversal is not a repeated
    # ease-out tween and never overshoots or persists a second P2 position.
    var physical_target := Vector2(17.0,0)
    var visual := Vector2.ZERO
    for frame in range(8):
        var next: Vector2 = GameScene.visual_step_toward(visual,physical_target,0.01625)
        check(next.x > visual.x and next.x <= 17.0 and next.y == 0.0,
            "visual movement must be monotonically smooth without overshoot")
        visual = next
    check(visual.distance_to(physical_target)<0.001,
        "130ms of frame playback must arrive exactly at one real P2 step")
    check(GameScene.visual_step_toward(visual,physical_target,0.01625)==physical_target and
        GameScene.visual_step_toward(Vector2.ZERO,physical_target,-1.0)==Vector2.ZERO,
        "visual movement must be still at rest and safe on invalid delta")
    check(is_equal_approx(GameScene.clamped_camera_zoom(2.0,10.0),
        GameScene.CAMERA_MAX_ZOOM) and is_equal_approx(
        GameScene.clamped_camera_zoom(2.0,0.001),
        GameScene.CAMERA_MIN_ZOOM),
        "wheel and pinch zoom must respect comfortable bounds")
    for touch_mode in [false,true]:
        var actor := Vector2(135,70)
        var follow: Dictionary = GameScene.camera_frame(Vector2(220,140),actor,2.0,touch_mode)
        var safe_rect: Rect2 = GameScene.TOUCH_PLAYFIELD if touch_mode else GameScene.PLAYFIELD
        check(GameScene.project_in_frame(actor,follow).distance_to(
            safe_rect.get_center())<0.01,"camera must follow current visual feet in HUD-safe area")
        var closer: Dictionary = GameScene.camera_frame(Vector2(220,140),actor,2.8,touch_mode)
        check(float(closer["zoom"]) > float(follow["zoom"]),
            "closer camera setting should dolly toward player in both UI layouts")
    # P1: never put more than E/F on the world HUD or offer disabled actions.
    var empty_ctx: Array[Dictionary] = Contextual.resolve(
        {"location":"street"},"",false,false,"",false)
    check(empty_ctx.is_empty(),"street with no nearby interactable must show zero actions")
    var doorway_ctx: Array[Dictionary] = Contextual.resolve(
        {"location":"landing"},"street",false,false,"",false)
    check(doorway_ctx.size()==1 and doorway_ctx[0]["kind"]=="door",
        "nearby accessible portal must be primary E")
    var work_ctx: Array[Dictionary] = Contextual.resolve({
        "location":"kiosk","kiosk_open":true,"tea_stage":"active",
        "tea_action":"U","tea_ready_in":0,"active_order":"order:1",
        "order_status":"accepted"}, "street",true,true,"mahmoud",true)
    check(work_ctx.size()==2 and work_ctx[0]["kind"]=="tea_pour" and
        work_ctx[1]["kind"]=="talk",
        "in-range cooking and nearby Ink must be E/F, not a wall of actions")
    var tea_wait: Array[Dictionary] = Contextual.resolve({
        "location":"kiosk","kiosk_open":true,"tea_stage":"active",
        "tea_action":"H","tea_ready_in":3},"",true,false,"",false)
    check(tea_wait.size()==1 and tea_wait[0]["kind"]=="wait",
        "timed kettle must not offer a premature Heat command")
    var snack_ctx: Array[Dictionary] = Contextual.resolve({
        "location":"kiosk","kiosk_open":true,"tea_stage":"",
        "active_order":"order:2","order_status":"accepted",
        "order_recipe":"liver_sandwich"},"",true,false,"",true)
    check(snack_ctx.size()==1 and snack_ctx[0]["kind"]=="sandwich",
        "real liver order exposes hand-worked workstation, not auto service")
    var closed_ctx: Array[Dictionary] = Contextual.resolve({
        "location":"kiosk","kiosk_open":false,"active_order":"order:3",
        "order_status":"offered"},"",true,false,"",false)
    check(closed_ctx.size()==1 and closed_ctx[0]["kind"]=="open",
        "closed kiosk cannot expose unavailable P4 service")
    var bed_ctx: Array[Dictionary] = Contextual.resolve({
        "location":"roof","bed_placed":true},"landing",false,false,"",false)
    check(bed_ctx.size()==2 and bed_ctx[0]["kind"]=="door" and
        bed_ctx[1]["kind"]=="sleep",
        "roof doorway and rest must fit exactly two available actions")
    # P1 touchscreen stays movement-only + at most two contextual verbs.
    var touch: Control = WorldTouchControls.new()
    root.add_child(touch)
    touch.build()
    check(touch.arrows.size()==8 and touch.actions.size()==2 and
        touch.dialogue_buttons.size()==4 and touch.utility_buttons.size()==2,
        "contextual touch UI must not present eight persistent action buttons")
    check(not touch.mode_enabled and not touch.arrows[0].visible,
        "pad is optional and hidden at boot")
    check(touch.toggle.size.y >= 68 and touch.arrows[7].size==Vector2(70,70) and
        touch.actions["primary"].size==Vector2(104,68),
        "landscape E and movement targets must remain thumb-sized")
    var pad_frame: Dictionary = GameScene.frame_for_room(Vector2(220,140),true)
    var corners_clear: bool = true
    for point in [Vector2.ZERO,Vector2(220,0),Vector2(220,140),Vector2(0,140)]:
        var projected: Vector2 = GameScene.project_in_frame(point,pad_frame)
        if projected.x < 245.8 or projected.x > 720.2 or \
                projected.y < 113.8 or projected.y > 352.2:
            corners_clear = false
    check(corners_clear,"baseline camera math still supports touch safe framing")
    check(GameScene.frame_for_room(Vector2(220,140),false)["origin"] != pad_frame["origin"],
        "touchsafe and keyboardsafe regions still differ")
    touch._toggle()
    touch.update_view({"location":"roof"},true,false,false,false,"",false,[],
        [{"kind":"door","label":"Go to landing"}])
    check(touch.mode_enabled and touch.arrows[7].visible and
        touch.actions["primary"].visible and
        touch.actions["primary"].text.contains("Door") and
        not touch.actions["alternate"].visible,
        "one nearby door must show only contextual E, no disabled F")
    touch._direction_down(Vector2i(1,1))
    check(touch.held_direction==Vector2i(1,1),
        "holding SE produces the existing canonical movement intent")
    touch._direction_up(Vector2i(1,1))
    check(touch.held_direction==Vector2i.ZERO,"release stops movement")
    touch.update_view({"location":"roof"},true,false,false,false,"",false,[],
        [{"kind":"door","label":"Go to landing"},{"kind":"sleep","label":"Sleep"}])
    check(touch.actions["alternate"].visible and
        touch.actions["alternate"].text.contains("Sleep"),
        "two reachable verbs must appear as E and F")
    touch._utility_toggle()
    touch.update_view({"location":"roof"},true,false,false,false,"",false,[],
        [{"kind":"door","label":"Go to landing"}])
    check(touch.utility_buttons["save"].visible and
        touch.utility_buttons["wait"].visible and
        not touch.actions["primary"].visible and not touch.arrows[0].visible,
        "utility menu must be separate and suppress world actions")
    touch._utility_toggle()
    touch.update_view({"location":"kiosk"},false,true,true,false,"",true,
        [{"option_id":"yes"},{"option_id":"no"}])
    check(not touch.toggle.visible and not touch.actions["primary"].visible and
        touch.dialogue_buttons["choice_0"].visible and
        touch.dialogue_buttons["choice_1"].visible and
        not touch.dialogue_buttons["next"].visible and
        touch.dialogue_buttons["leave"].visible,
        "Ink choices must replace nearby E/F and retain real option identities")
    touch.update_view({"location":"kiosk"},false,true,true,false,"",true,[])
    check(touch.dialogue_buttons["next"].visible and
        not touch.dialogue_buttons["choice_0"].visible,
        "authored Ink line without choices retains advance path until P4")
    touch.update_view({"location":"kiosk"},false,true,true,true,"",true,[])
    check(not touch.dialogue_buttons["next"].visible and
        not touch.dialogue_buttons["leave"].visible,
        "existing overlays must suppress Ink responses")
    check(WorldTouchControls.dialogue_target({"location":"kiosk",
        "conversation_near":true,"mahmoud_invite_near":true},false)=="mahmoud" and
        WorldTouchControls.dialogue_target({"location":"kiosk",
        "conversation_near":true},false)=="neighbors" and
        WorldTouchControls.dialogue_target({"location":"roof",
        "mahmoud_invite_near":true},false).is_empty(),
        "contextual Talk never grants ungrounded NPC proximity")
    root.remove_child(touch)
    touch.free()
    # P12 station: each of six *real* numbered purchase actions remains
    # independently tap-sized and cannot intersect another purchasing target.
    var station: Control = SandwichControls.new()
    root.add_child(station)
    station.build()
    check(station.purchases.size() == 6 and station.opener.size.y >= 68,
        "sandwich workstation must have six intact offers and thumb-sized opener")
    var station_buttons: Array[Button] = []
    for buy in station.purchases:
        station_buttons.append(buy)
        check(buy.size.x >= 100 and buy.size.y >= 68,
            "ingredient purchase target is too small for 640x360 landscape")
    station_buttons.append_array([station.action_button,station.wait_button,
        station.save_button,station.close_button])
    var no_overlap: bool = true
    for i in range(station_buttons.size()):
        var a: Button = station_buttons[i]
        if i >= 6 and a.size.y < 68: no_overlap = false
        for j in range(i+1,station_buttons.size()):
            var b: Button = station_buttons[j]
            if Rect2(a.position,a.size).intersects(Rect2(b.position,b.size)):
                no_overlap = false
    check(no_overlap,"purchase/step/wait/save/close targets must not overlap")
    check(not Rect2(station.opener.position,station.opener.size).intersects(
        Rect2(810,455,136,70)),
        "station opener must not intercept the P10/P11 touch pad toggle")
    var lots: Array = []
    for ingredient in ["bread","cooking_oil","garlic","green_pepper",
            "lemon_juice","liver"]:
        lots.append({"ingredient_id":ingredient,"cost":100,"resolved":false})
    var station_state: Dictionary = {"near":true,"offers":lots,"cue":"Start pan"}
    station.update_view(station_state,false,false,false)
    check(station.opener.visible and not station.purchases[0].visible,
        "closed station must expose its touch opener without leaking stock controls")
    station.update_view(station_state,true,false,false)
    check(not station.opener.visible and station.purchases[5].visible and
        not station.purchases[5].disabled and station.close_button.visible,
        "open station must expose all six canonical offers and close affordance")
    lots[0]["resolved"] = true
    station.update_view(station_state,true,false,false)
    check(station.purchases[0].disabled and station.purchases[0].text=="BOUGHT" and
        not station.purchases[1].disabled,
        "already purchased ingredient must stay disabled while other real offers remain")
    station.update_view(station_state,true,true,false)
    check(not station.purchases[0].visible and not station.action_button.visible and
        not station.close_button.visible,
        "authored Ink overlay must hide every sandwich touch action")
    root.remove_child(station)
    station.free()
    # Every authored floor corner must remain inside the visible playfield,
    # not beneath the header, tea strip or bottom action text. This camera
    # math is view-only and independent of the saved P2 actor location.
    for shape in [Vector2(240,160),Vector2(120,90),Vector2(420,250)]:
        var frame: Dictionary = GameScene.frame_for_room(shape)
        check(not frame.is_empty(),"missing room camera frame")
        if frame.is_empty(): continue
        for corner in [Vector2.ZERO,Vector2(shape.x,0),shape,Vector2(0,shape.y)]:
            var pixel: Vector2 = GameScene.project_in_frame(corner,frame)
            check(pixel.x >= GameScene.PLAYFIELD.position.x-0.1 and
                pixel.x <= GameScene.PLAYFIELD.end.x+0.1 and
                pixel.y >= GameScene.PLAYFIELD.position.y-0.1 and
                pixel.y <= GameScene.PLAYFIELD.end.y+0.1,
                "room corner under a HUD overlay %s -> %s" % [shape,pixel])
        var reference: Vector2 = GameScene.project_in_frame(Vector2.ZERO,frame)
        var x_axis: Vector2 = GameScene.project_in_frame(Vector2(18,0),frame)-reference
        var y_axis: Vector2 = GameScene.project_in_frame(Vector2(0,18),frame)-reference
        check(is_equal_approx(x_axis.x,-y_axis.x) and
            is_equal_approx(x_axis.y,y_axis.y) and
            is_equal_approx(x_axis.x,2.0*x_axis.y),
            "fixed 2:1 orientation changed during visual framing")
        var center: Vector2 = GameScene.project_in_frame(shape/2.0,frame)
        check(center.distance_to(GameScene.PLAYFIELD.get_center()) < 0.01,
            "room auto-frame failed to center floor within safe playfield")
    check(GameScene.frame_for_room(Vector2.ZERO).is_empty() and
        GameScene.frame_for_room(Vector2(-10,160)).is_empty(),
        "invalid room extents acquired a camera frame")
    # Read-only guided day: zero synthetic objectives or saved completion.
    var guide: Dictionary = NextStepGuide.describe({"location":"roof","minute":1020})
    check(guide["phase"]=="head_to_shop","opening roof needs physical travel")
    check(NextStepGuide.describe({"location":"kiosk","kiosk_open":false})["phase"]=="open_kiosk",
        "closed shop must suggest actual opening")
    check(NextStepGuide.describe({"location":"kiosk","kiosk_open":true,
        "sandwich":{"can_start":false,"offers":[{"resolved":true},{"resolved":false}]}})["phase"]=="stock_counter",
        "shop supply guidance must depend on real paid receipts")
    var order: Dictionary = {"location":"kiosk","minute":1084,
        "order_created_minute":1080,"order_recipe":"liver_sandwich",
        "order_status":"offered","order_payment":"none","sandwich":{"can_start":true,
            "item_status":"","stage":""}}
    check(NextStepGuide.describe(order)["phase"]=="accept_order",
        "authentic offered P4 order takes precedence over market hints")
    order["order_status"]="accepted"
    check(NextStepGuide.describe(order)["phase"]=="prepare_liver",
        "accepted P4 sandwich needs the real P3 technique")
    order["sandwich"]["stage"]="active"
    order["sandwich"]["heat_caption"]="First side · turn now"
    check(NextStepGuide.describe(order)["text"]=="First side · turn now",
        "active P3 heat feedback should be projected without UI timers")
    order["sandwich"]["stage"]=""
    order["sandwich"]["item_status"]="ready"
    check(NextStepGuide.describe(order)["phase"]=="deliver_order",
        "already prepared genuine ready item must be served, not cooked again")
    order["order_status"]="delivered"
    check(NextStepGuide.describe(order)["phase"]=="collect_payment",
        "delivered but unpaid P4 order must prompt real P5 settlement")
    order["order_payment"]="settled"
    order["kiosk_open"]=true
    check(NextStepGuide.describe(order)["phase"]=="close_after_sale",
        "P5 paid sale should lead into closing the real shop")
    order["kiosk_open"]=false
    order["location"]="roof"
    check(NextStepGuide.describe(order)["phase"]=="sleep_after_sale",
        "return home after a real sale should suggest P1 sleep")
    order["minute"]=1920 # Next morning, old settled order remains in history.
    check(NextStepGuide.describe(order)["phase"]=="head_to_shop",
        "yesterday's settled order must not become an eternal tutorial flag")
    # Game-first prompts are pure presentation of canonical facts; they do
    # not invent actions, move actors or alter the world to display guidance.
    check(GameScene.context_hint({"location":"kiosk","tea_stage":"active",
        "tea_action":"H","tea_ready_in":2},"landing",false,true) ==
        "H · Tea ready in 2 world min","active tea should outrank an exit")
    check(GameScene.context_hint({"location":"kiosk","conversation_near":true},
        "",false,true) == "T · Join the nearby conversation",
        "visible living talk should take precedence over idle service")
    check(GameScene.context_hint({"location":"landing"},"roof",false,false) ==
        "E · Go to roof","nearby accessible doorway should be discoverable")
    check(GameScene.context_hint({"location":"roof","bed_placed":true},"",
        true,false) == "Q · Take a quiet moment",
        "actual quiet spot should be more contextual than generic sleep")
    check(GameScene.context_hint({"location":"roof","bed_placed":true},"",
        false,false) == "Z · Rest at home","owned placed bed should suggest rest")
    check(GameScene.context_hint({"location":"kiosk","kiosk_open":false},"",
        false,false) == "O · Open the kiosk when ready",
        "closed kiosk should suggest voluntary opening")
    for path in [SAVE, SAVE+".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var g: RefCounted = Game.new()
    var started: Dictionary = g.start(SAVE)
    check(started.get("ok",false) and started.get("code","")=="NEW_WORLD","new session "+JSON.stringify(started))
    if not started.get("ok",false): return
    check(g.room()=="roof" and g.status()["minute"]==1020,"initial roof at authored opening time")
    check(g.status()["money"]==6000 and g.status()["roof_access"],"world content vs QA economics")
    check(g.status()["npc_mahmoud"]=="street","visitor not pre-teleported")
    check(g.npc_pose("mahmoud").is_empty(),"absent visitor cannot be drawn")
    check(g.ambient_exchange().is_empty(),"no dialogue while on roof or Mahmoud absent")
    check(not g.graph.configure_visit_spots({"schema":1}).get("ok",false),"invalid visits must reject")
    var digest_before: String = g.status()["digest"]
    check(g.move_world(60,0)["code"]=="INVALID_DELTA","no movement teleport")
    check(g.status()["digest"]==digest_before,"invalid move wrote event")
    check(g.move_world(18,0).get("ok",false),"roof move")
    check(g.travel_near().get("ok",false) and g.room()=="landing","roof/landing")
    check(g.travel_near().get("ok",false) and g.room()=="roof","return to roof")
    check(g.travel_near().get("ok",false) and g.room()=="landing","return to landing")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"landing walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="street","landing/street")
    for i in range(9):
        check(g.move_world(18,0).get("ok",false),"street walk %d" % i)
    check(g.travel_near().get("ok",false) and g.room()=="kiosk","street/kiosk")
    check(g.service_near()["code"]=="KIOSK_CLOSED","closed store rejects service")
    for i in range(4):
        check(g.move_world(18,0).get("ok",false),"kiosk counter approach %d" % i)
    check(g.open_kiosk().get("ok",false),"player opens kiosk")
    check(g.service_near()["code"]=="NO_ACTIVE_ORDER","no fake offer")
    for i in range(3):
        check(g.wait_minutes().get("ok",false),"real clock waiting")
    check(g.status()["minute"]==1035 and g.status()["npc_mahmoud"]=="kiosk","independent NPC visit")
    check(g.status()["order_status"]=="offered","autonomous customer order")
    # Built-in Geometry2D: being in the same P2 room is NOT visual contact.
    # Mahmoud's authored standing point is behind the solid table from Salma.
    check(not g.graph.npcs_have_visual_contact(g.session,"salma","mahmoud"),
        "NPCs unrealistically see each other straight through the kiosk table")
    check(not g.graph.clear_sightline("kiosk",Vector2(160,110),Vector2(190,110)),
        "straight sightline leaked through Godot furniture")
    check(g.graph.clear_sightline("kiosk",Vector2(160,75),Vector2(190,75)),
        "open Godot sightline incorrectly blocked")
    check(not g.graph.npcs_have_visual_contact(g.session,"salma","salma"),
        "one NPC counts as two conversing participants")
    var path: PackedVector2Array = g.graph.navigation_path(Vector2(200,110),Vector2(145,85))
    check(path.size() >= 3,"Godot AStarGrid2D did not create a route around kiosk furniture")
    var straight: float = Vector2(200,110).distance_to(Vector2(145,85))
    var routed: float = 0.0
    for k in range(1,path.size()):
        routed += path[k-1].distance_to(path[k])
    check(routed > straight+1.0,"NPC path cut through table instead of detouring")
    # An NPC has radius, not just a mathematical point. Verify the
    # entire timeline stays outside furniture with physical clearance.
    for blocked in g.graph.navigator.obstacle_rects():
        for t in range(101):
            var sample: Vector2 = g.graph.sample_path(path,float(t)/100.0)
            check(not blocked.grow(4.0).has_point(sample),
                "NPC route clipped a furniture collider/actor clearance at %d" % t)
    var bad_mesh: Dictionary = {"schema":1,"room_id":"kiosk","x_edges":[8,90,139,160,195,232],
        "y_edges":[8,63,86,99,130,152],"blocked_cells":[[1,2],[3,3],[3,3]]}
    check(not g.graph.configure_walkable(bad_mesh).get("ok",false),"invalid duplicate mesh blocker accepted")
    check(g.graph.navigation_path(Vector2(200,110),Vector2(145,85))==path,
        "failed nav config altered active Godot AStarGrid2D")
    # Grid-center solids alone are insufficient: an off-grid NPC can stand
    # inside the four-unit padded footprint even if its rounded cell is free.
    # The engine must reject such authored geometry, not return a clipping path.
    var clearance_grid: Dictionary = {"schema":1,"room_id":"kiosk",
        "x_edges":[8,65,68,240],"y_edges":[8,77,82,160],
        "blocked_cells":[[1,1]]}
    var KioskNav = load("res://scripts/integration/kiosk_navigation.gd")
    var clearance_probe: RefCounted = KioskNav.new()
    var clearance_result: Dictionary = clearance_probe.configure(
        clearance_grid,{"width":240,"height":160},
        [Vector2(62,80)],[Vector2(80,80)])
    check(clearance_result.get("code","")=="NAV_CLEARANCE_BLOCKED",
        "off-grid NPC endpoint slipped into padded furniture despite AStarGrid2D")
    clearance_probe.dispose()
    check(g.graph.navigation_path(Vector2(200,110),Vector2(145,85))==path,
        "negative clearance configuration must not change the live visitor route")
    var approaching: Dictionary = g.npc_pose("mahmoud")
    check(approaching.get("mode","")=="approaching" and
        approaching.get("position",Vector2.ZERO)==Vector2(200,110),
        "visitor didn't begin from authored standing position on real offer")
    check(g.ambient_exchange().is_empty(),"no incidental exchange before the first authored beat")
    check(g.wait_minutes(4).get("ok",false),"reach first spontaneous NPC aside")
    var before_aside: String = g.status()["digest"]
    var first_aside: Dictionary = g.ambient_exchange()
    check(first_aside.get("npc_id","")=="salma" and first_aside.get("beat",-1)==0 and
        first_aside.get("line","").contains("river"),"Salma did not speak during real joint presence")
    check(g.status()["ambient_line"]==first_aside.get("line","") and g.status()["digest"]==before_aside,
        "ambient projection wrote GameState or failed to reach UI")
    check(g.graph.npcs_have_visual_contact(g.session,"salma","mahmoud"),
        "arriving at real counter did not restore NPCs' mutual line of sight")
    check(g.customer_reaction().is_empty(),"customer cannot react before delivery")
    var first: Dictionary = g.service_near()
    check(first.get("ok",false) and first.get("kind","")=="order.accept","accept real order")
    check(g.service_near().get("kind","")=="cook.start","start recipe")
    check(g.service_near().get("code","")=="HAND_ACTION_REQUIRED","G cannot skip player hand action")
    var stalled: String = g.status()["digest"]
    check(g.tea_action_near("U").get("code","")=="WRONG_GESTURE","cannot pour before heating")
    check(g.status()["digest"]==stalled,"wrong gesture changed canonical world")
    check(g.tea_action_near("H").get("kind","")=="cook.step.begin","player puts kettle on")
    check(g.tea_action_near("H").get("code","")=="STEP_NOT_READY","cannot lift kettle early")
    check(g.save_game().get("ok",false),"save mid-cooking")
    var before_load: Dictionary = g.session.world.view()
    var restored: RefCounted = Game.new()
    check(restored.start(SAVE).get("code","")=="RESTORED","restore existing opening game")
    check(JSON.stringify(restored.session.world.view())==JSON.stringify(before_load),"entire world state preserved")
    check(restored.room()=="kiosk" and restored.position()==g.position(),"canonical world pose retained")
    check(restored.graph.npcs_have_visual_contact(restored.session,"salma","mahmoud") ==
        g.graph.npcs_have_visual_contact(g.session,"salma","mahmoud"),
        "authored NPC visual contact differs after world reload")
    var job_id: String = "play:c3:prep:" + str(g.status()["active_order"])
    var item_id: String = "item:" + job_id
    # A counterfactual world from the exact same persisted mid-heat snapshot:
    # intentionally late hands produce a different real item-quality outcome.
    var slow: RefCounted = Kernel.new()
    check(slow.restore_snapshot(before_load),"counterfactual replay baseline")
    check(slow.prepared_quality(item_id).is_empty(),"no quality for food not yet prepared")
    check(slow.prepared_quality("item:forged").is_empty(),"forged item quality rejected")
    check(slow.advance_time(9,"e3:slow:heat").get("ok",false),"deliberate slow heating")
    check(slow.dispatch({"id":"e3:slow:lift","actor_id":"player","kind":"cook.step.finish",
        "payload":{"job_id":job_id}}).get("ok",false),"slow lift P3 step")
    check(slow.dispatch({"id":"e3:slow:pour","actor_id":"player","kind":"cook.step.begin",
        "payload":{"job_id":job_id,"station_id":"counter"}}).get("ok",false),"slow pour P3 step")
    check(slow.advance_time(7,"e3:slow:pour:time").get("ok",false),"deliberate slow pour")
    check(slow.dispatch({"id":"e3:slow:finish","actor_id":"player","kind":"cook.step.finish",
        "payload":{"job_id":job_id}}).get("ok",false),"slow tea made a real cup")
    var rough: Dictionary = slow.prepared_quality(item_id)
    check(rough.get("grade","")=="rough" and int(rough.get("score",0)) < 60,
        "late tea did not receive worse world-owned quality")
    check(rough.get("source_event_id","") == slow.prepared_item(item_id).get("event_id",""),
        "quality lacks physical item provenance")
    var slow_again: RefCounted = Kernel.new()
    check(slow_again.restore_snapshot(slow.view()) and slow_again.prepared_quality(item_id)==rough,
        "late cup quality changed across canonical replay")
    check(restored.wait_minutes(2).get("ok",false),"wait for heat")
    var at_counter: Dictionary = restored.npc_pose("mahmoud")
    check(at_counter.get("mode","")=="counter" and at_counter.get("position",Vector2.ZERO)==Vector2(145,85),
        "visitor failed to reach authored counter with canonical time")
    check(restored.graph.nearby_npc(restored.session,restored.position()).get("npc_id","")=="mahmoud",
        "hearing target disagrees with visible counter position")
    check(restored.graph.navigation_path(Vector2(200,110),Vector2(145,85))==path,
        "Godot native navigation route changed on disk replay")
    check(restored.tea_action_near("H").get("kind","")=="cook.step.finish","player lifts hot kettle")
    check(restored.tea_action_near("U").get("kind","")=="cook.step.begin","player pours tea")
    check(restored.wait_minutes(1).get("ok",false),"wait for serving")
    check(restored.tea_action_near("U").get("kind","")=="cook.step.finish","finish physical pour")
    var balanced: Dictionary = restored.session.world.prepared_quality(item_id)
    check(balanced.get("grade","")=="good" and int(balanced.get("score",0))==100,
        "on-time hand actions didn't produce a good cup")
    check(balanced["score"] > rough["score"],"patient vs delayed tea same quality")
    check(restored.status()["tea_quality"]=="good" and restored.status()["tea_quality_item"]==item_id,
        "real game failed to surface canonical sensory quality")
    # Nonblocking: Salma's short line remains visible while tea is brewed.
    check(restored.ambient_exchange().get("npc_id","")=="salma","cooking should not freeze the nearby speaker")
    check(restored.wait_minutes(5).get("ok",false) and restored.wait_minutes(2).get("ok",false),
        "advance to the second authored speech beat without moving NPCs by hand")
    var second_aside: Dictionary = restored.ambient_exchange()
    check(second_aside.get("npc_id","")=="mahmoud" and second_aside.get("beat",-1)==1 and
        second_aside.get("line","").contains("still"),"Mahmoud did not answer Salma without player interaction")
    check(restored.customer_reaction().is_empty(),"finished but undelivered cup triggered conversation")
    var served: Dictionary = restored.service_near()
    check(served.get("kind","")=="order.deliver","deliver paid item")
    var reply: Dictionary = restored.customer_reaction()
    check(reply.get("npc_id","")=="mahmoud" and reply.get("grade","")=="good" and
        reply.get("line","").contains("cup"),"real delivered tea did not trigger authored good reaction")
    check(reply.get("order_id","")==restored.status()["active_order"] and
        reply.get("source_event_id","")==restored.session.world.order(reply["order_id"])["closure_event_id"],
        "reaction unlinked from real P4 delivery event")
    check(served.get("customer_reaction",{})==reply and restored.status()["customer_reaction"]==reply["line"],
        "customer response not visible to production gameplay")
    check(restored.ambient_exchange().is_empty(),"incidental remark must give way to genuine customer response")
    check(restored.npc_pose("mahmoud").get("mode","")=="returning" and
        restored.npc_pose("mahmoud").get("position",Vector2.ZERO)==Vector2(145,85),
        "visitor jumped to anchor on delivery")
    check(restored.service_near().get("kind","")=="economy.order.quote","quote")
    check(restored.service_near().get("kind","")=="economy.order.settle","settle")
    check(restored.status()["money"]==6200,"no duplicate payment")
    check(restored.save_game().get("ok",false),"save settled state")
    var once: String=restored.status()["digest"]
    var final: RefCounted=Game.new()
    check(final.start(SAVE).get("code","")=="RESTORED","second game boot")
    check(final.status()["digest"]==once and final.status()["money"]==6200,"settled state unchanged after reload")
    check(final.session.world.prepared_quality(item_id)==balanced and final.status()["tea_quality"]=="good",
        "delivered tea lost immutable quality after paid service and disk reload")
    check(final.customer_reaction()==reply,"delivered response lost after canonical P5 settlement and save")
    check(final.ambient_exchange().is_empty(),"settled customer response takes precedence")
    check(final.npc_pose("mahmoud")==restored.npc_pose("mahmoud"),
        "visitor position changed after P5 settlement and world reload")
    check(final.wait_minutes(3).get("ok",false),"advance world while visitor steps away")
    check(final.npc_pose("mahmoud").get("mode","")=="standing" and
        final.npc_pose("mahmoud").get("position",Vector2.ZERO)==Vector2(200,110),
        "visitor did not return to standing spot")
    check(final.status()["money"]==6200,"visual visit changed economy")
    var same: String = final.status()["digest"]
    check(final.service_near()["code"]=="NO_ACTIVE_ORDER","already served customer can no longer order again")
    check(final.status()["digest"]==same,"rejected second service changed delivery/reaction")
    var forged: Dictionary = final.session.world.view()
    for record in forged["events"]:
        if record["kind"] == "cook.step_finished" and record["payload"]["request"]["job_id"] == job_id:
            record["world_minute"] = int(record["world_minute"]) + 1
            break
    check(not final.session.world.restore_snapshot(forged),"changed cooking timing bypassed event replay")
    check(final.status()["digest"]==same,"failed event replay changed live world")
    check(final.service_near()["code"]=="NO_ACTIVE_ORDER","no duplicate order service")
    check(final.status()["digest"]==same,"rejected service mutated settled state")
    for obj in [g,restored,final]: obj.dispose()
    if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
