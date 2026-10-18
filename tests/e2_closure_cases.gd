extends RefCounted
const Game=preload("res://scripts/gameplay/game_entry.gd")
const Kernel=preload("res://scripts/core/world_kernel.gd")
const SAVE="user://e2-current-scope-closure.json"
var errors: Array[String]=[]
func check(v: bool, message: String) -> void:
    if not v: errors.append(message);push_error(message)
func ok(r: Dictionary, label: String) -> void: check(r.get("ok",false),label+": "+str(r))
func move(g: RefCounted,dx: int,dy: int,n: int) -> void:
    for i in range(n):ok(g.move_world(dx,dy),"walk")
func kiosk(g: RefCounted) -> void:
    move(g,18,0,1);ok(g.travel_near(),"roof exit");move(g,18,0,9);ok(g.travel_near(),"landing exit");move(g,18,0,9);ok(g.travel_near(),"street exit");move(g,18,0,4)
func home(g: RefCounted) -> void:
    while g.position().x>55:ok(g.move_world(-18,0),"counter to street door")
    ok(g.travel_near(),"kiosk exit")
    while g.position().x>55:ok(g.move_world(-18,0),"street to landing door")
    ok(g.travel_near(),"street exit")
    while g.position().x>55:ok(g.move_world(-18,0),"landing to roof door")
    ok(g.travel_near(),"home")
func bread(g: RefCounted,n: int) -> void:
    for i in range(n):
        ok(g.personal_bread_near(),"start bread");ok(g.personal_bread_near(),"prepare bread");ok(g.wait_minutes(1),"bread time");ok(g.personal_bread_near(),"finish bread");ok(g.personal_bread_near(),"eat real bread")
func bounded(g: RefCounted) -> void:
    var n: Dictionary=g.session.world.needs_view()
    for key in ["hunger","rest","mood","wellbeingBaseline"]:check(n[key]>=0 and n[key]<=100,"bounded "+key)
func run() -> Array[String]:
    if FileAccess.file_exists(SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
    var g: RefCounted=Game.new();ok(g.start(SAVE),"actual production boot")
    var initial: Dictionary=g.status()
    ok(g.bed_near(),"buy actual bed");ok(g.bed_near(),"place actual bed")
    check(g.status()["money"]==initial["money"]-3400,"P5 paid bed")
    check(g.status()["mood"]==initial["mood"] and g.status()["rest"]==initial["rest"],"no arbitrary buying/placing benefit")
    ok(g.session.advance(2880,"e2:actual-neglect"),"two genuine neglected days")
    check(g.status()["hunger"]==0 and g.status()["rest"]<25,"genuinely depleted context")
    var mood: int=g.status()["mood"];ok(g.quiet_near(),"same rooftop quiet in poor context")
    var tired_gain: int=g.status()["mood"]-mood
    check(tired_gain<=1,"poor physical context should limit quiet benefit")
    # Concrete failed invariant: same history and physiology, elapsed chunks.
    var a: RefCounted=Kernel.new();var b: RefCounted=Kernel.new()
    check(a.restore_snapshot(g.session.world.view()) and b.restore_snapshot(g.session.world.view()),"fork actual depleted history")
    ok(a.advance_time(1440,"e2:whole-day"),"whole day")
    for i in range(144):ok(b.advance_time(10,"e2:ten-minutes:"+str(i)),"ten-minute chunk")
    check(a.needs_view()==b.needs_view(),"depleted Mood must be invariant under P1 time chunking")
    kiosk(g);ok(g.open_kiosk(),"low-Mood player chooses to open")
    ok(g.session.advance(19,"e2:scheduled-order"),"actual demand")
    var cash: int=g.status()["money"]
    ok(g.service_near(),"accept at low needs");ok(g.service_near(),"prepare at low needs")
    ok(g.tea_action_near("H"),"heat at low needs");ok(g.wait_minutes(2),"heat time");ok(g.tea_action_near("H"),"lift at low needs")
    ok(g.tea_action_near("U"),"pour at low needs");ok(g.wait_minutes(1),"pour time");ok(g.tea_action_near("U"),"finish at low needs")
    check(g.status()["tea_quality"]=="good","low Mood does not sabotage careful cooking")
    ok(g.service_near(),"deliver");ok(g.service_near(),"quote");ok(g.service_near(),"settle actual income")
    check(g.status()["money"]>cash,"low Mood never blocks earning")
    var leaves: int=g.status()["leaves_stock"];cash=g.status()["money"]
    ok(g.market_purchase(),"paid procurement remains usable at low needs")
    check(g.status()["money"]==cash-450 and g.status()["leaves_stock"]==leaves+30,"procurement remains audited")
    bread(g,4);ok(g.close_kiosk(),"choose to close without quota");home(g)
    var before_sleep: Dictionary=g.session.world.view()
    var bare: RefCounted=Game.new();ok(bare.start("user://e2-contrast-bare-shell.json"),"contrast shell")
    check(bare.session.world.restore_snapshot(before_sleep),"same actual paid/food/history")
    ok(bare.store_bed(),"legitimate stored-bed home context")
    check(bare.status()["mood"]==g.status()["mood"] and bare.status()["rest"]==g.status()["rest"],"storing does not grant need changes")
    ok(bare.sleep_at_home(),"same sleep with stored bed");ok(g.sleep_at_home(),"same sleep with placed bed")
    check(g.status()["minute"]==bare.status()["minute"] and g.status()["rest"]==bare.status()["rest"]+12,"actual placed-bed sleep contrast")
    bare.dispose();bounded(g)
    mood=g.status()["mood"];ok(g.quiet_near(),"same rooftop activity after real recovery")
    check(g.status()["mood"]-mood>tired_gain,"same real activity responds to recovered needs")
    var short_baseline: int=g.session.world.needs_view()["wellbeingBaseline"]
    check(short_baseline==60,"one quiet/rest day is not instant long-term wellbeing")
    ok(g.quiet_near(),"second quiet");mood=g.status()["mood"]
    for i in range(6):ok(g.quiet_near(),"saturated quiet")
    check(g.status()["mood"]<=mood,"no repeated quiet Mood farming")
    # Two more qualified recovery days, using existing real P3 meals and P1 sleep.
    for day in range(2):
        kiosk(g);bread(g,2 if day==0 else 3);home(g)
        var now: int=g.status()["minute"]
        var next_midnight: int=(int(now/1440)+1)*1440
        ok(g.session.advance(next_midnight-now,"e2:next-night:"+str(day)),"canonical next rest opportunity")
        ok(g.sleep_at_home(),"recover on a later real day");bounded(g)
    check(g.session.world.needs_view()["wellbeingBaseline"]==61,"three fed/rested days slowly improve hidden baseline")
    check(g.status()["rest"]>=35 and g.status()["hunger"]>=35 and g.status()["mood"]>=58,"bad-day recovery remains attainable")
    ok(g.save_game(),"genuine disk save/replay")
    var saved: Dictionary=g.session.world.view();g.dispose()
    g=Game.new();ok(g.start(SAVE),"genuine disk reload")
    check(Kernel._matches(saved,g.session.world.view()),"week-scale recovery replay identical")
    var fake: Dictionary=saved.duplicate(true);fake["needs"]["wellbeingBaseline"]=100
    check(not Kernel.new().restore_snapshot(fake),"hidden baseline forgery denied")
    g.dispose()
    print("E2 CLOSURE: PASS" if errors.is_empty() else "E2 CLOSURE: FAIL "+str(errors.size()))
    return errors
