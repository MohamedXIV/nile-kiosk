extends SceneTree
## E4: authored event/condition opportunities, single P1/P2 truth and replay.
const Kernel = preload("res://scripts/core/world_kernel.gd")
const Content = preload("res://scripts/integration/world_content_bootstrap.gd")
var errors: Array[String] = []

func check(value: bool, label: String) -> void:
    if not value: errors.append(label)

func send(k: RefCounted, id: String, kind: String, payload: Dictionary, actor: String = "system:narrative") -> Dictionary:
    return k.dispatch({"id": id, "actor_id": actor, "kind": kind, "payload": payload})

func _initialize() -> void:
    _canonical_unlock_and_replay()
    _validated_content()
    if errors.is_empty():
        print("E4 OPPORTUNITIES: PASS (authored predicates, trigger order, one-shot, provenance, disk replay, tampering)")
        quit(0)
    else:
        for error in errors: push_error(error)
        print("E4 OPPORTUNITIES: FAIL " + str(errors.size()))
        quit(1)

func _canonical_unlock_and_replay() -> void:
    var k: RefCounted = Kernel.new(9)
    var rule: Dictionary = {
        "opportunity_id": "quiet_followup", "trigger_event": "knowledge.granted",
        "when": {"all": [
            {"time_at_least": 10},
            {"event_seen": "time.advanced"},
            {"any": [{"has_fact": "chapter_two"}, {"player_knows": "rumor"}]},
            {"not": {"kiosk_open": true}}
        ]}
    }
    check(send(k, "register", "narrative.opportunity.register", rule).get("ok", false), "register authored rule")
    var before_bad: String = JSON.stringify(k.view())
    check(send(k, "duplicate", "narrative.opportunity.register", rule).get("code") == "OPPORTUNITY_EXISTS", "duplicate opportunity")
    check(send(k, "unauthorized", "narrative.opportunity.register", {
        "opportunity_id": "stealth", "trigger_event": "knowledge.granted", "when": {"has_fact": "chapter_two"}
    }, "player").get("code") == "UNAUTHORIZED", "unauthorized author")
    check(send(k, "bad", "narrative.opportunity.register", {
        "opportunity_id": "arbitrary", "trigger_event": "knowledge.granted", "when": {"eval": "money += 10"}
    }).get("code") == "INVALID_OPPORTUNITY", "untrusted predicate")
    check(JSON.stringify(k.view()) == before_bad, "rejected rule mutated canonical state")
    check(send(k, "too-early", "knowledge.grant", {"fact_id": "chapter_one"}, "npc:samir").get("ok", false), "first fact")
    check(k.narrative_opportunities().is_empty(), "time gate ignored")
    check(k.advance_time(10, "clock").get("ok", false), "canonical advance")
    check(k.narrative_opportunities().is_empty(), "time alone fired wrong event trigger")
    var second: Dictionary = send(k, "chapter-two", "knowledge.grant", {"fact_id": "chapter_two"}, "npc:samir")
    check(second.get("ok", false), "second fact")
    var unlocked: Dictionary = k.narrative_opportunities()
    check(unlocked.size() == 1 and unlocked.has("quiet_followup"), "authored opportunity did not fire")
    check(unlocked.get("quiet_followup", {}).get("source_event_id", "") == second.get("event_id", ""), "missing event provenance")
    check(unlocked.get("quiet_followup", {}).get("world_minute", -1) == 10, "noncanonical unlock time")
    var digest: String = JSON.stringify(k.view())
    check(send(k, "chapter-two", "knowledge.grant", {"fact_id": "chapter_two"}, "npc:samir") == second, "command not idempotent")
    check(JSON.stringify(k.view()) == digest, "retry duplicated opportunity")
    check(k.advance_time(1440, "next-day").get("ok", false), "advance next day")
    check(k.narrative_opportunities().size() == 1, "opportunity fired twice")
    var exposed: Dictionary = k.narrative_opportunities()
    exposed["quiet_followup"]["source_event_id"] = "forged"
    check(k.narrative_opportunities()["quiet_followup"]["source_event_id"] == second["event_id"], "public view mutated canonical opportunity")
    var path: String = "user://nk-e4-opportunities.json"
    check(k.save_to_file(path), "save rule and result")
    var loaded: RefCounted = Kernel.new(99)
    check(loaded.load_from_file(path), "load rules and results")
    check(JSON.stringify(k.view()) == JSON.stringify(loaded.view()), "replay changed state")
    var before_forge: String = JSON.stringify(loaded.view())
    var forged: Dictionary = loaded.view()
    forged["narrative"]["opportunities"]["quiet_followup"]["source_event_id"] = "forged"
    check(not loaded.restore_snapshot(forged), "forged unlock provenance accepted")
    check(JSON.stringify(loaded.view()) == before_forge, "forged save damaged live state")
    forged = loaded.view()
    forged["narrative"]["opportunity_rules"]["quiet_followup"]["when"] = {"has_fact": "never"}
    check(not loaded.restore_snapshot(forged), "forged authored condition accepted")
    check(JSON.stringify(loaded.view()) == before_forge, "forged condition changed live state")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _validated_content() -> void:
    var imported: Dictionary = Content.from_file("res://content/world/nile_opening.v1.json", 71)
    check(imported.get("ok", false), "production bundle failed validation: " + str(imported.get("code", "")))
    if not imported.get("ok", false): return
    var k: RefCounted = imported["candidate"]
    var rules: Dictionary = k.narrative_view().get("opportunity_rules", {})
    check(rules.has("river_watch_reflection"), "authored Nile moment not registered")
    check(k.narrative_opportunities().is_empty(), "moment unlocked during bootstrap")
