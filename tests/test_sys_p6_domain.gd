extends SceneTree
## Production SYS P6 narrative domain acceptance (no Ink runtime).
const Kernel = preload("res://scripts/core/world_kernel.gd")
var errors: Array[String] = []

func _initialize() -> void:
    var k = Kernel.new()
    for npc in ["samir","mahmoud","mona"]:
        test(k.dispatch({"id":"npc:"+npc,"actor_id":"system:director","kind":"npc.register",
            "payload":{"npc_id":npc,"location_id":"kiosk"}})["ok"], "register "+npc)
    send(k,"player","social.player.place",{"location_id":"kiosk"},"system:director")
    send(k,"fact","social.fact.register",{"fact_id":"match","source_npc_id":"samir","visibility":"public"},"system:director")
    send(k,"secret","social.fact.register",{"fact_id":"secret","source_npc_id":"samir","visibility":"trusted"},"system:director")
    var story = {"story_id":"a","beats":{
        "intro":{"speaker_id":"samir","fact_id":"match"},
        "secret":{"speaker_id":"samir","fact_id":"secret"},
        "neutral":{"speaker_id":"mahmoud","fact_id":""}
        },"choice_points":{"decision":{
            "join":{"text":"Join", "requires_known":["match"],"requires_trusted":"samir",
                "disclose_fact_id":"", "speaker_id":""},
            "quiet":{"text":"Quiet","requires_known":[],"requires_trusted":"",
                "disclose_fact_id":"", "speaker_id":""}
        }}}
    test(send(k,"story","narrative.story.register",story)["ok"],"register")
    test(send(k,"story2","narrative.story.register",story)["code"]=="STORY_EXISTS","duplicate story")
    var start={"session_id":"s","story_id":"a","participants":["samir","mahmoud","player"],"ink_state":["cursor:0"]}
    test(send(k,"start","narrative.session.start",start)["ok"],"start")
    test(not k.player_knows("match"),"unspoken leaked")
    var before=JSON.stringify(k.view())
    test(send(k,"privatebad","narrative.line.commit",{"session_id":"s","beat_id":"secret",
        "mode":"broadcast","audience_ids":[],"ink_state":["cursor:wrong"]})["code"]=="PRIVATE_BROADCAST","privacy")
    test(JSON.stringify(k.view())==before,"failed line mutated cursor")
    send(k,"away","social.player.place",{"location_id":"elsewhere"},"system:director")
    test(send(k,"line","narrative.line.commit",{"session_id":"s","beat_id":"intro",
        "mode":"broadcast","audience_ids":[],"ink_state":["cursor:1"]})["ok"],"offscreen speech")
    test(not k.player_knows("match"),"retroactive offscreen knowledge")
    test(k.social_view()["knowledge"]["mona"].has("match"),"co-present NPC never heard")
    send(k,"back","social.player.place",{"location_id":"kiosk"},"system:director")
    test(send(k,"line2","narrative.line.commit",{"session_id":"s","beat_id":"intro",
        "mode":"broadcast","audience_ids":[],"ink_state":["cursor:2"]})["ok"],"heard repeated line")
    test(k.player_knows("match"),"world did not credit actual hearing")
    test(send(k,"wait","narrative.choice.wait",{"session_id":"s","point_id":"decision",
        "ink_state":["cursor:choices"]})["ok"],"choice wait")
    test(k.narrative_choices("s").size()==1,"trust gate")
    test(send(k,"try","narrative.choice.select",{"session_id":"s","point_id":"decision",
        "option_id":"join","ink_state":["bad"]})["code"]=="CHOICE_GATED","choice bypass")
    send(k,"trust","social.familiarity.set",{"observer_id":"player","npc_id":"samir","level":"trusted"},"system:director")
    test(k.narrative_choices("s").size()==2,"live trust gate")
    var once=send(k,"choose","narrative.choice.select",{"session_id":"s","point_id":"decision",
        "option_id":"join","ink_state":["cursor:joined"]})
    test(once["ok"],"choice")
    test(send(k,"choose","narrative.choice.select",{"session_id":"s","point_id":"decision",
        "option_id":"join","ink_state":["cursor:joined"]})==once,"receipt retry")
    test(send(k,"finish","narrative.session.finish",{"session_id":"s","ink_state":["cursor:end"]})["ok"],"end")
    var disk="user://nk-p6-domain.json"
    test(k.save_to_file(disk),"save")
    var loaded=Kernel.new()
    test(loaded.load_from_file(disk),"load")
    test(JSON.stringify(loaded.view())==JSON.stringify(k.view()),"replay match")
    var forged=k.view()
    forged["narrative"]["sessions"]["s"]["ink_state"]=["fake"]
    test(not k.restore_snapshot(forged),"forged cursor")
    forged=k.view()
    forged["version"]=6
    test(not k.restore_snapshot(forged),"v6 must reject")
    if FileAccess.file_exists(disk): DirAccess.remove_absolute(ProjectSettings.globalize_path(disk))
    if errors.is_empty():
        print("SYS P6 domain PASS (privacy, offscreen, choice, idempotency, replay)")
        quit(0)
    else:
        for e in errors: push_error(e)
        print("SYS P6 domain FAIL "+str(errors.size()))
        quit(1)

func send(k, cid: String, kind: String, p: Dictionary, actor: String = "system:narrative") -> Dictionary:
    return k.dispatch({"id":cid,"actor_id":actor,"kind":kind,"payload":p})

func test(ok: bool, reason: String) -> void:
    if not ok: errors.append(reason)
