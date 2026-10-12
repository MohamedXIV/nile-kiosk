extends RefCounted
## D001 Ink contender uses the SAME P0 canonical world state and spatial simulation.

const World = preload("res://scripts/conversation_orchestrator.gd")
const Session = preload("res://scripts/ink_conversation_session.gd")

var world := World.new()
var sessions: Dictionary = {}

var player_position: Vector2:
    get: return world.player_position
    set(value): world.player_position = value

var game_state:
    get: return world.game_state

var tea_steps: int:
    get: return world.tea_steps

var tick_number: int:
    get: return world.tick_number

var events: Array[Dictionary]:
    get: return world.events

func _init() -> void:
    sessions["football"] = Session.new("football", "res://content/ink/football.ink.json")
    sessions["rumor"] = Session.new("rumor", "res://content/ink/rumor.ink.json")

func heard(id: String) -> bool:
    return world.heard(id)

func grant_match_knowledge() -> void:
    world.grant_match_knowledge()

func prepare_tea_step() -> bool:
    return world.prepare_tea_step()

func interject() -> bool:
    if not heard("football") or not game_state.has_fact("knows_match"):
        return false
    var emitted: Array[Dictionary] = sessions["football"].choose_interjection()
    for event in emitted:
        world._emit_event(event)
    return not emitted.is_empty()

func advance_async(delta: float) -> void:
    world.tick_number += 1
    for id in ["football", "rumor"]:
        var can_join: bool = id == "football" and heard(id) and game_state.has_fact("knows_match")
        var emitted: Array[Dictionary] = sessions[id].tick(delta, can_join)
        for event in emitted:
            world._emit_event(event)

func dispose() -> void:
    for session in sessions.values():
        session.dispose()
