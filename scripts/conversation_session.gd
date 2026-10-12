extends RefCounted
## Owns one independent authored conversation's cursor and clock.

var session_id: String
var beats: Array[Dictionary]
var cursor: int = 0
var delay_remaining: float = 0.0
var phase: String = "running"
var choice_remaining: float = 0.0

func _init(id: String, sequence: Array[Dictionary]) -> void:
    session_id = id
    beats = sequence
    _schedule_next()

func _schedule_next() -> void:
    delay_remaining = float(beats[cursor].get("delay", 0.25)) if cursor < beats.size() else 0.25

func tick(delta: float, allow_interjection: bool) -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if phase == "finished":
        return emitted
    if phase == "choice":
        choice_remaining -= delta
        if choice_remaining <= 0.0:
            phase = "running"
            _schedule_next()
            emitted.append({"kind": "choice_expired", "session": session_id})
        return emitted

    delay_remaining -= delta
    if delay_remaining > 0.0:
        return emitted
    if cursor >= beats.size():
        phase = "finished"
        emitted.append({"kind": "finished", "session": session_id})
        return emitted

    var beat: Dictionary = beats[cursor]
    cursor += 1
    if beat.get("kind", "line") == "window":
        if allow_interjection:
            phase = "choice"
            choice_remaining = 4.0
            emitted.append({"kind": "choice", "session": session_id, "text": "I watched the match."})
        else:
            _schedule_next()
    else:
        emitted.append({
            "kind": "line",
            "session": session_id,
            "speaker": beat["speaker"],
            "text": beat["text"],
            "fact": beat.get("fact", "")
        })
        _schedule_next()
    return emitted

func choose_interjection() -> Array[Dictionary]:
    var emitted: Array[Dictionary] = []
    if phase != "choice":
        return emitted
    phase = "running"
    _schedule_next()
    emitted.append({"kind": "interjection", "session": session_id, "text": "The referee did make some bad calls."})
    emitted.append({"kind": "line", "session": session_id, "speaker": "Mahmoud", "text": "Finally, somebody gets it!", "fact": ""})
    return emitted
