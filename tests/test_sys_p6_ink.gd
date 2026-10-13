extends SceneTree
## Real InkPlayer integration and mid-choice whole-world disk resume.
const Kernel = preload("res://scripts/core/world_kernel.gd")
const Bridge = preload("res://scripts/core/ink_world_bridge.gd")
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func send(k, id: String, kind: String, payload: Dictionary, actor: String = "system:narrative") -> Dictionary:
    return k.dispatch({"id":id,"actor_id":actor,"kind":kind,"payload":payload})

func ok(value: bool, label: String) -> void:
    if not value: errors.append(label)

func _register(k) -> void:
    for npc in ["samir","mahmoud","mona","hossam"]:
        ok(send(k,"npc:"+npc,"npc.register",{"npc_id":npc,"location_id":"kiosk"},"system:director")["ok"],"npc:"+npc)
    for pair in [["sports:match","samir"],["sports:result","samir"],["shop:rumor","hossam"]]:
        ok(send(k,"fact:"+pair[0],"social.fact.register",{"fact_id":pair[0],
            "source_npc_id":pair[1],"visibility":"public"},"system:director")["ok"],"fact:"+pair[0])
    send(k,"player","social.player.place",{"location_id":"kiosk"},"system:director")
    var blank={"requires_known":[],"requires_trusted":"","disclose_fact_id":"","speaker_id":""}
    var ask=blank.duplicate(true)
    ask["text"]="I saw the match."
    ask["requires_known"]=["sports:match"]
    ask["requires_trusted"]="mahmoud"
    ask["disclose_fact_id"]="sports:result"
    ask["speaker_id"]="samir"
    var quiet=blank.duplicate(true)
    quiet["text"]="Stay quiet."
    ok(send(k,"a:story","narrative.story.register",{
        "story_id":"a", "beats":{
            "a_open":{"speaker_id":"samir","fact_id":""},
            "a_question":{"speaker_id":"mahmoud","fact_id":""},
            "a_yes":{"speaker_id":"mahmoud","fact_id":""},
            "a_quiet":{"speaker_id":"samir","fact_id":""},
            "a_end":{"speaker_id":"samir","fact_id":""}
        },"choice_points":{"match_choice":{"ask":ask,"quiet":quiet}}})["ok"],"story A")
    ok(send(k,"b:story","narrative.story.register",{
        "story_id":"b","beats":{
            "b_open":{"speaker_id":"mona","fact_id":""},
            "b_rumor":{"speaker_id":"hossam","fact_id":"shop:rumor"},
            "b_end":{"speaker_id":"mona","fact_id":""}
        },"choice_points":{}})["ok"],"story B")

func _wait(adapter, ids: Array) -> bool:
    for i in range(150):
        var all=true
        for id in ids:
            if adapter.sessions[id]["failed"]: return false
            if not adapter.ready(id): all=false
        if all: return true
        await process_frame
    return false

func _run() -> void:
    var k=Kernel.new(11)
    _register(k)
    send(k,"trust","social.familiarity.set",{"observer_id":"player","npc_id":"mahmoud","level":"trusted"},"system:director")
    send(k,"initial","social.speak",{"speaker_id":"samir","fact_id":"sports:match",
        "mode":"broadcast","audience_ids":[]},"samir")
    var adapter=Bridge.new(k)
    ok(adapter.attach("a","res://content/ink/sys_p6_conversation.ink.json"),"attach A")
    ok(adapter.attach("b","res://content/ink/sys_p6_gossip.ink.json"),"attach B")
    if not await _wait(adapter,["a","b"]):
        ok(false,"Ink real stories load")
        adapter.dispose()
        _done()
        return
    ok(adapter.begin("a","a",["samir","mahmoud","player"],"start:a")["ok"],"start A")
    ok(adapter.begin("b","b",["mona","hossam"],"start:b")["ok"],"start B")
    ok(adapter.advance("a","a:line1").get("beat_id")=="a_open","A first beat")
    ok(adapter.advance("a","a:line2").get("beat_id")=="a_question","A second beat")
    ok(adapter.advance("a","a:wait").get("code")=="WAITING","choice pending")
    ok(adapter.choices("a").size()==2,"choice eligibility")
    ok(adapter.advance("b","b:line1").get("beat_id")=="b_open","B independent line")
    send(k,"leave","social.player.place",{"location_id":"home"},"system:director")
    ok(adapter.advance("b","b:rumor").get("beat_id")=="b_rumor","B offscreen rumor")
    ok(not k.player_knows("shop:rumor"),"offscreen player gained knowledge")
    ok(k.social_view()["knowledge"]["mona"].has("shop:rumor"),"NPC missed offscreen rumor")
    ok(adapter.advance("b","b:line3").get("beat_id")=="b_end","B continues while A waits")
    ok(adapter.advance("b","b:done").get("code")=="FINISHED","B completes")
    ok(adapter.choices("a").is_empty(),"absent player allowed choice")
    ok(k.advance_time(13,"time:13")["ok"],"non-blocking world clock")
    ok(k.narrative_session("a")["phase"]=="choice","time consumed narrative choice")
    var disk="user://nk-p6-ink.json"
    ok(k.save_to_file(disk),"save mid-choice")
    adapter.dispose()
    var fresh=Kernel.new()
    ok(fresh.load_from_file(disk),"reload all domains")
    var resumed=Bridge.new(fresh)
    ok(resumed.attach("a","res://content/ink/sys_p6_conversation.ink.json"),"re-attach A")
    ok(resumed.attach("b","res://content/ink/sys_p6_gossip.ink.json"),"re-attach B")
    if not await _wait(resumed,["a","b"]):
        ok(false,"resume compiled stories")
        resumed.dispose()
        _done()
        return
    send(fresh,"return","social.player.place",{"location_id":"kiosk"},"system:director")
    ok(not fresh.player_knows("shop:rumor"),"retroactive knowledge on return")
    ok(resumed.choices("a").size()==2,"Ink native pending choices lost in reload")
    ok(resumed.choose("a","ask","choose:ask")["ok"],"Ink selection after reload")
    ok(fresh.player_knows("sports:result"),"choice did not disclose world-approved fact")
    ok(fresh.social_view()["knowledge"]["player"]["sports:result"]["heard_minute"]==13,"wrong hearing minute")
    ok(resumed.advance("a","a:yes").get("beat_id")=="a_yes","Ink choice branch")
    ok(resumed.advance("a","a:join").get("beat_id")=="a_end","Ink rejoined")
    ok(resumed.advance("a","a:done").get("code")=="FINISHED","Ink end")
    var copy=Kernel.new()
    ok(copy.restore_snapshot(fresh.view()),"full replay snapshot")
    ok(JSON.stringify(copy.view())==JSON.stringify(fresh.view()),"replay differs")
    var corrupt=fresh.view()
    corrupt["narrative"]["sessions"]["a"]["ink_state"]=["fabricated"]
    ok(not fresh.restore_snapshot(corrupt),"forged cursor accepted")
    corrupt=fresh.view()
    corrupt["version"]=6
    ok(not fresh.restore_snapshot(corrupt),"old v6 implicitly migrated")
    resumed.dispose()
    if FileAccess.file_exists(disk): DirAccess.remove_absolute(ProjectSettings.globalize_path(disk))
    # A second branch: without the player's knowledge/trust the authored choice is gated.
    var q=Kernel.new(12)
    _register(q)
    var quiet_bridge=Bridge.new(q)
    quiet_bridge.attach("a","res://content/ink/sys_p6_conversation.ink.json")
    if await _wait(quiet_bridge,["a"]):
        quiet_bridge.begin("a","a",["samir","mahmoud","player"],"quiet:start")
        quiet_bridge.advance("a","quiet:line1")
        quiet_bridge.advance("a","quiet:line2")
        quiet_bridge.advance("a","quiet:wait")
        ok(quiet_bridge.choices("a").size()==1,"blocked choice shown")
        ok(quiet_bridge.choose("a","ask","quiet:bad")["code"]=="CHOICE_GATED","adapter bypass")
        ok(quiet_bridge.choose("a","quiet","quiet:yes")["ok"],"quiet choice")
        ok(quiet_bridge.advance("a","quiet:branch").get("beat_id")=="a_quiet","quiet branch")
        ok(quiet_bridge.advance("a","quiet:join").get("beat_id")=="a_end","quiet reconverge")
        ok(not q.player_knows("sports:result"),"denied branch disclosed knowledge")
    else: ok(false,"quiet story load")
    quiet_bridge.dispose()
    _done()

func _done() -> void:
    if errors.is_empty():
        print("SYS P6 Ink PASS (native concurrent sessions, world gating, disk mid-choice, branching/replay)")
        quit(0)
    else:
        for x in errors: push_error(x)
        print("SYS P6 Ink FAIL "+str(errors.size()))
        quit(1)
