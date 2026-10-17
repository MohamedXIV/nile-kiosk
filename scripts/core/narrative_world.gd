extends RefCounted
## SYS P6: deterministic authored narrative sessions. Ink owns prose/cursor, not world truth.
const MAX_INT: int = 2147483647
const OpportunityRules = preload("res://scripts/core/story_opportunity_rules.gd")
var stories: Dictionary = {}
var sessions: Dictionary = {}
var opportunity_rules: Dictionary = {}
var opportunities: Dictionary = {}

static func id(v: Variant) -> bool:
    return typeof(v) == TYPE_STRING and not (v as String).strip_edges().is_empty() and (v as String).length() <= 128

static func exact(p: Dictionary, keys: Array) -> bool:
    if p.size() != keys.size(): return false
    for k in keys:
        if not p.has(k): return false
    return true

static func owns(kind: String) -> bool:
    return kind in ["narrative.story.register", "narrative.opportunity.register", "narrative.opportunity.begin", "narrative.session.start",
        "narrative.line.commit", "narrative.choice.wait", "narrative.choice.select",
        "narrative.session.finish"]

static func event_kind(kind: String) -> String:
    match kind:
        "narrative.story.register": return "narrative.story_registered"
        "narrative.opportunity.register": return "narrative.opportunity_registered"
        "narrative.opportunity.begin": return "narrative.opportunity_begun"
        "narrative.session.start": return "narrative.session_started"
        "narrative.line.commit": return "narrative.line_committed"
        "narrative.choice.wait": return "narrative.choice_waiting"
        "narrative.choice.select": return "narrative.choice_selected"
        "narrative.session.finish": return "narrative.session_finished"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "narrative.story_registered": return "narrative.story.register"
        "narrative.opportunity_registered": return "narrative.opportunity.register"
        "narrative.opportunity_begun": return "narrative.opportunity.begin"
        "narrative.session_started": return "narrative.session.start"
        "narrative.line_committed": return "narrative.line.commit"
        "narrative.choice_waiting": return "narrative.choice.wait"
        "narrative.choice_selected": return "narrative.choice.select"
        "narrative.session_finished": return "narrative.session.finish"
    return ""

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func snapshot() -> Dictionary:
    return {"stories": stories.duplicate(true), "sessions": sessions.duplicate(true),
        "opportunity_rules": opportunity_rules.duplicate(true),
        "opportunities": opportunities.duplicate(true)}

static func _valid_cursor(cursor: Variant) -> bool:
    if typeof(cursor) != TYPE_ARRAY or cursor.is_empty() or cursor.size() > 128:
        return false
    for part in cursor:
        if typeof(part) != TYPE_STRING or part.is_empty() or part.length() > 4096:
            return false
    return true

func _location(person: String, society: RefCounted) -> String:
    if person == "player": return society.player_location
    return society.npcs.get(person, {}).get("location_id", "")

func _participants(raw: Variant, society: RefCounted) -> Dictionary:
    if typeof(raw) != TYPE_ARRAY or raw.size() < 2 or raw.size() > 32:
        return fail("INVALID_PARTICIPANTS")
    var seen: Dictionary = {}
    var location: String = ""
    for person in raw:
        if not id(person) or seen.has(person) or (person != "player" and not society.npcs.has(person)):
            return fail("INVALID_PARTICIPANTS")
        seen[person] = true
        var here: String = _location(person, society)
        if here.is_empty() or (not location.is_empty() and here != location):
            return fail("PARTICIPANT_ABSENT")
        location = here
    return {"ok": true, "location_id": location}

func _eligible(option: Dictionary, session: Dictionary, society: RefCounted) -> bool:
    if not session["participants"].has("player") or _location("player", society) != session["location_id"]:
        return false
    for fact in option["requires_known"]:
        if not society.knowledge.get("player", {}).has(fact):
            return false
    if not option["requires_trusted"].is_empty() and society.familiarity.get("player", {}).get(option["requires_trusted"], "") != "trusted":
        return false
    return true

func available(session_id: String, society: RefCounted) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    if not sessions.has(session_id): return out
    var s: Dictionary = sessions[session_id]
    if s["phase"] != "choice": return out
    var options: Dictionary = stories[s["story_id"]]["choice_points"][s["point_id"]]
    var keys: Array = options.keys()
    keys.sort()
    for option_id in keys:
        var o: Dictionary = options[option_id]
        if _eligible(o, s, society):
            out.append({"option_id": option_id, "text": o["text"]})
    return out

func _validate_story(p: Dictionary) -> Dictionary:
    if not exact(p, ["story_id", "beats", "choice_points"]) or not id(p.get("story_id")) or typeof(p.get("beats")) != TYPE_DICTIONARY or typeof(p.get("choice_points")) != TYPE_DICTIONARY:
        return fail("INVALID_PAYLOAD")
    if p["beats"].is_empty() or p["beats"].size() > 128 or p["choice_points"].size() > 32:
        return fail("INVALID_STORY")
    for beat_id in p["beats"]:
        var beat: Variant = p["beats"][beat_id]
        if not id(beat_id) or typeof(beat) != TYPE_DICTIONARY or not exact(beat, ["speaker_id", "fact_id"]) or not id(beat.get("speaker_id")) or typeof(beat.get("fact_id")) != TYPE_STRING:
            return fail("INVALID_BEAT")
        if not beat["fact_id"].is_empty() and not id(beat["fact_id"]):
            return fail("INVALID_BEAT")
    for point_id in p["choice_points"]:
        var options: Variant = p["choice_points"][point_id]
        if not id(point_id) or typeof(options) != TYPE_DICTIONARY or options.is_empty() or options.size() > 16:
            return fail("INVALID_OPTIONS")
        var texts: Dictionary = {}
        for option_id in options:
            var option: Variant = options[option_id]
            if not id(option_id) or typeof(option) != TYPE_DICTIONARY or not exact(option,
                ["text", "requires_known", "requires_trusted", "disclose_fact_id", "speaker_id"]):
                return fail("INVALID_OPTIONS")
            if typeof(option["text"]) != TYPE_STRING or option["text"].is_empty() or option["text"].length() > 512 or texts.has(option["text"]):
                return fail("INVALID_OPTIONS")
            texts[option["text"]] = true
            if typeof(option["requires_known"]) != TYPE_ARRAY or option["requires_known"].size() > 32 or typeof(option["requires_trusted"]) != TYPE_STRING or typeof(option["disclose_fact_id"]) != TYPE_STRING or typeof(option["speaker_id"]) != TYPE_STRING:
                return fail("INVALID_OPTIONS")
            for fact in option["requires_known"]:
                if not id(fact): return fail("INVALID_OPTIONS")
            for required in ["requires_trusted", "disclose_fact_id", "speaker_id"]:
                if not option[required].is_empty() and not id(option[required]):
                    return fail("INVALID_OPTIONS")
            if option["disclose_fact_id"].is_empty() != option["speaker_id"].is_empty():
                return fail("INVALID_OPTIONS")
    return {"ok": true}

func _speech(society: RefCounted, speaker: String, fact_id: String, mode: String, audience: Array, jobs: Dictionary, minute: int) -> Dictionary:
    var request: Dictionary = {"speaker_id": speaker, "fact_id": fact_id,
        "mode": mode, "audience_ids": audience.duplicate(true)}
    var planned: Dictionary = society.plan("social.speak", request, speaker, jobs, minute)
    if not planned.get("ok", false):
        return planned
    return {"ok": true, "request": request, "effect": planned["effect"]}

func observe_event(event: Dictionary, world: RefCounted) -> void:
    OpportunityRules.unlock(opportunity_rules, opportunities, event, world)

func plan(kind: String, p: Dictionary, actor: String, society: RefCounted, jobs: Dictionary, minute: int) -> Dictionary:
    if kind == "narrative.opportunity.register":
        if actor != "system:narrative": return fail("UNAUTHORIZED")
        if not exact(p, ["opportunity_id", "trigger_event", "when"]) or not id(p.get("opportunity_id")) or not id(p.get("trigger_event")):
            return fail("INVALID_OPPORTUNITY")
        if p["trigger_event"] == "narrative.opportunity_registered" or not OpportunityRules.valid_condition(p.get("when")):
            return fail("INVALID_OPPORTUNITY")
        if opportunity_rules.has(p["opportunity_id"]): return fail("OPPORTUNITY_EXISTS")
        if opportunity_rules.size() >= 64: return fail("OPPORTUNITY_LIMIT")
        return {"ok": true, "effect": {"opportunity_id": p["opportunity_id"]}}
    if kind == "narrative.story.register":
        if actor != "system:narrative": return fail("UNAUTHORIZED")
        var check: Dictionary = _validate_story(p)
        if not check["ok"]: return check
        if stories.has(p["story_id"]): return fail("STORY_EXISTS")
        return {"ok": true, "effect": {"story_id": p["story_id"]}}
    if actor != "system:narrative":
        return fail("UNAUTHORIZED")
    if kind in ["narrative.session.start", "narrative.opportunity.begin"]:
        var offered: bool = kind == "narrative.opportunity.begin"
        var required: Array = ["session_id", "story_id", "participants", "ink_state", "opportunity_id"] if offered else ["session_id", "story_id", "participants", "ink_state"]
        if not exact(p, required) or not id(p.get("session_id")) or not id(p.get("story_id")) or not _valid_cursor(p.get("ink_state")):
            return fail("INVALID_PAYLOAD")
        if not stories.has(p["story_id"]): return fail("UNKNOWN_STORY")
        if sessions.has(p["session_id"]): return fail("SESSION_EXISTS")
        if offered:
            if not id(p.get("opportunity_id")) or not opportunities.has(p["opportunity_id"]):
                return fail("OPPORTUNITY_LOCKED")
            if p["story_id"] != p["opportunity_id"] or not p["participants"].has("player"):
                return fail("INVALID_OPPORTUNITY_PARTICIPANTS")
            for existing in sessions.values():
                if existing.get("opportunity_id", "") == p["opportunity_id"]:
                    return fail("OPPORTUNITY_ALREADY_STARTED")
        var present: Dictionary = _participants(p["participants"], society)
        if not present["ok"]: return present
        return {"ok": true, "effect": {"location_id": present["location_id"]}}
    if not id(p.get("session_id")) or not sessions.has(p["session_id"]):
        return fail("UNKNOWN_SESSION")
    var s: Dictionary = sessions[p["session_id"]]
    if not _valid_cursor(p.get("ink_state")):
        return fail("INVALID_CURSOR")
    if kind == "narrative.line.commit":
        if not exact(p, ["session_id", "beat_id", "mode", "audience_ids", "ink_state"]) or not id(p.get("beat_id")) or typeof(p.get("audience_ids")) != TYPE_ARRAY or p.get("mode") not in ["broadcast", "directed"]:
            return fail("INVALID_PAYLOAD")
        if s["phase"] != "running": return fail("INVALID_PHASE")
        var beats: Dictionary = stories[s["story_id"]]["beats"]
        if not beats.has(p["beat_id"]): return fail("UNKNOWN_BEAT")
        var beat: Dictionary = beats[p["beat_id"]]
        var speaker: String = beat["speaker_id"]
        if not s["participants"].has(speaker) or _location(speaker, society) != s["location_id"]:
            return fail("SPEAKER_ABSENT")
        var effect: Dictionary = {"beat_id": p["beat_id"], "speaker_id": speaker,
            "fact_id": beat["fact_id"], "heard_by": [], "speech": {}}
        if beat["fact_id"].is_empty():
            if p["mode"] != "broadcast" or not p["audience_ids"].is_empty():
                return fail("INVALID_AUDIENCE")
            var witnesses: Array = []
            var people: Array = society.npcs.keys()
            people.append("player")
            people.sort()
            for person in people:
                if person != speaker and _location(person, society) == s["location_id"]:
                    witnesses.append(person)
            effect["heard_by"] = witnesses
        else:
            var spoken: Dictionary = _speech(society, speaker, beat["fact_id"], p["mode"], p["audience_ids"], jobs, minute)
            if not spoken.get("ok", false): return spoken
            effect["heard_by"] = spoken["effect"]["heard_by"].duplicate(true)
            effect["speech"] = spoken
        return {"ok": true, "effect": effect}
    if kind == "narrative.choice.wait":
        if not exact(p, ["session_id", "point_id", "ink_state"]) or not id(p.get("point_id")):
            return fail("INVALID_PAYLOAD")
        if s["phase"] != "running" or not stories[s["story_id"]]["choice_points"].has(p["point_id"]):
            return fail("INVALID_CHOICE_POINT")
        return {"ok": true, "effect": {"point_id": p["point_id"]}}
    if kind == "narrative.choice.select":
        if not exact(p, ["session_id", "point_id", "option_id", "ink_state"]) or not id(p.get("point_id")) or not id(p.get("option_id")):
            return fail("INVALID_PAYLOAD")
        if s["phase"] != "choice" or s["point_id"] != p["point_id"]:
            return fail("INVALID_PHASE")
        var options: Dictionary = stories[s["story_id"]]["choice_points"][s["point_id"]]
        if not options.has(p["option_id"]): return fail("UNKNOWN_OPTION")
        var option: Dictionary = options[p["option_id"]]
        if not _eligible(option, s, society): return fail("CHOICE_GATED")
        var effect: Dictionary = {"option_id": p["option_id"], "speech": {}}
        if not option["disclose_fact_id"].is_empty():
            var speaker: String = option["speaker_id"]
            if not s["participants"].has(speaker): return fail("INVALID_SPEAKER")
            var spoken: Dictionary = _speech(society, speaker, option["disclose_fact_id"], "directed", ["player"], jobs, minute)
            if not spoken.get("ok", false): return spoken
            effect["speech"] = spoken
        return {"ok": true, "effect": effect}
    if kind == "narrative.session.finish":
        if not exact(p, ["session_id", "ink_state"]): return fail("INVALID_PAYLOAD")
        if s["phase"] != "running": return fail("INVALID_PHASE")
        return {"ok": true, "effect": {"session_id": p["session_id"]}}
    return fail("UNKNOWN_COMMAND")

func apply_command(kind: String, p: Dictionary, effect: Dictionary, minute: int, event_id: String,
        society: RefCounted, sequence: int) -> void:
    match kind:
        "narrative.opportunity.register":
            opportunity_rules[p["opportunity_id"]] = p.duplicate(true)
        "narrative.story.register":
            stories[p["story_id"]] = p.duplicate(true)
        "narrative.session.start", "narrative.opportunity.begin":
            sessions[p["session_id"]] = {"session_id": p["session_id"], "story_id": p["story_id"],
                "participants": p["participants"].duplicate(true), "location_id": effect["location_id"],
                "phase": "running", "point_id": "", "ink_state": p["ink_state"].duplicate(true),
                "lines": [], "choices": [], "started_minute": minute, "started_event_id": event_id,
                "last_event_id": event_id}
            if kind == "narrative.opportunity.begin":
                sessions[p["session_id"]]["opportunity_id"] = p["opportunity_id"]
        "narrative.line.commit":
            var s: Dictionary = sessions[p["session_id"]]
            s["lines"].append({"beat_id": effect["beat_id"], "speaker_id": effect["speaker_id"],
                "fact_id": effect["fact_id"], "heard_by": effect["heard_by"].duplicate(true),
                "minute": minute, "event_id": event_id})
            s["ink_state"] = p["ink_state"].duplicate(true)
            s["last_event_id"] = event_id
            if not effect["speech"].is_empty():
                society.apply_command("social.speak", effect["speech"]["request"], effect["speech"]["effect"],
                    minute, event_id, sequence, effect["speaker_id"], event_id, {})
        "narrative.choice.wait":
            var s: Dictionary = sessions[p["session_id"]]
            s["phase"] = "choice"
            s["point_id"] = p["point_id"]
            s["ink_state"] = p["ink_state"].duplicate(true)
            s["last_event_id"] = event_id
        "narrative.choice.select":
            var s: Dictionary = sessions[p["session_id"]]
            s["phase"] = "running"
            s["point_id"] = ""
            s["ink_state"] = p["ink_state"].duplicate(true)
            s["last_event_id"] = event_id
            s["choices"].append({"option_id": p["option_id"], "minute": minute, "event_id": event_id})
            if not effect["speech"].is_empty():
                society.apply_command("social.speak", effect["speech"]["request"], effect["speech"]["effect"],
                    minute, event_id, sequence, effect["speech"]["request"]["speaker_id"], event_id, {})
        "narrative.session.finish":
            var s: Dictionary = sessions[p["session_id"]]
            s["phase"] = "finished"
            s["ink_state"] = p["ink_state"].duplicate(true)
            s["last_event_id"] = event_id
