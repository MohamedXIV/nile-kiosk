extends RefCounted
## Shared orchestration layer; neither Ink nor Dialogue Manager owns world truth.

const GameState = preload("res://scripts/game_state.gd")
const ConversationSession = preload("res://scripts/conversation_session.gd")

const HEARING_RANGE: float = 180.0
const TABLE_A := Vector2(245.0, 325.0)
const TABLE_B := Vector2(725.0, 325.0)
const COUNTER := Vector2(480.0, 133.0)

var game_state := GameState.new()
var player_position := Vector2(480.0, 240.0)
var tick_number: int = 0
var tea_steps: int = 0
var events: Array[Dictionary] = []
var sessions: Dictionary = {}

func _init() -> void:
    sessions["football"] = ConversationSession.new("football", [
        {"speaker": "Samir", "text": "The referee ruined the match.", "delay": 0.50},
        {"speaker": "Mahmoud", "text": "You're only upset because your team lost.", "delay": 1.00},
        {"kind": "window", "delay": 0.50},
        {"speaker": "Samir", "text": "Next Thursday, we'll see.", "delay": 0.50}
    ])
    sessions["rumor"] = ConversationSession.new("rumor", [
        {"speaker": "Mona", "text": "Have you heard about Hassan's shop?", "delay": 1.00},
        {"speaker": "Hossam", "text": "The rent is getting impossible.", "fact": "hassan_shop_rumor", "delay": 2.00},
        {"speaker": "Mona", "text": "I hope he finds a way to stay.", "delay": 2.00}
    ])

func heard(session_id: String) -> bool:
    var table_position: Vector2 = TABLE_A if session_id == "football" else TABLE_B
    return player_position.distance_to(table_position) <= HEARING_RANGE

func advance(delta: float) -> void:
    tick_number += 1
    for session_id in ["football", "rumor"]:
        var can_join: bool = session_id == "football" and heard(session_id) and game_state.has_fact("knows_match")
        var outputs: Array[Dictionary] = sessions[session_id].tick(delta, can_join)
        for event in outputs:
            _emit_event(event)

func grant_match_knowledge() -> void:
    if game_state.grant_fact("knows_match", "fixture_match_knowledge"):
        _emit_event({"kind": "fact", "session": "world", "fact": "knows_match"})

func interject() -> bool:
    if not heard("football") or not game_state.has_fact("knows_match"):
        return false
    var outputs: Array[Dictionary] = sessions["football"].choose_interjection()
    for event in outputs:
        _emit_event(event)
    return not outputs.is_empty()

func prepare_tea_step() -> bool:
    if player_position.distance_to(COUNTER) > 135.0:
        return false
    tea_steps += 1
    _emit_event({"kind": "tea_step", "session": "world", "step": tea_steps})
    if tea_steps == 3:
        tea_steps = 0
        _emit_event({"kind": "tea_served", "session": "world"})
    return true

func _emit_event(event: Dictionary) -> void:
    var recorded: Dictionary = event.duplicate(true)
    recorded["tick"] = tick_number
    events.append(recorded)
    if recorded.get("kind") == "line" and heard(recorded["session"]):
        var fact_id: String = recorded.get("fact", "")
        if not fact_id.is_empty():
            var effect_id := "heard:%s:%s" % [recorded["session"], fact_id]
            if game_state.grant_fact(fact_id, effect_id):
                events.append({"kind": "fact", "session": recorded["session"], "fact": fact_id, "tick": tick_number})
