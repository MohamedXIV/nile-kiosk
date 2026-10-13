extends RefCounted
## SYS P0: production-owned world event ledger and canonical knowledge facts.
## No Godot scene, Ink, or spike orchestrator is a second state authority.

const VERSION: int = 1
const MAX_INT_JSON: int = 2147483647

var seed: int = 1
var world_minute: int = 0 # Reserved clock slot. P1 Time/Scheduler owns advancement.
var sequence: int = 0
var facts: Dictionary = {}
var receipts: Dictionary = {}
var events: Array[Dictionary] = []

func _init(world_seed: int = 1) -> void:
    seed = world_seed

static func valid_identity(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty() and (value as String).length() <= 128

static func integral(value: Variant, minimum: int = 0, maximum: int = MAX_INT_JSON) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var as_float: float = float(value)
    return is_finite(as_float) and as_float >= float(minimum) and as_float <= float(maximum) and as_float == float(int(value))

static func signature(actor_id: String, fact_id: String) -> String:
    return JSON.stringify(["knowledge.grant", actor_id, fact_id])

func _apply_event(raw: Dictionary) -> bool:
    if raw.get("kind", "") != "knowledge.granted":
        return false
    var next_seq: Variant = raw.get("sequence")
    var at: Variant = raw.get("world_minute")
    if not integral(next_seq, 1) or int(next_seq) != sequence + 1:
        return false
    if not integral(at) or int(at) != world_minute:
        return false
    var command_id: Variant = raw.get("command_id")
    var actor_id: Variant = raw.get("actor_id")
    var value: Variant = raw.get("payload")
    if not valid_identity(command_id) or not valid_identity(actor_id) or typeof(value) != TYPE_DICTIONARY:
        return false
    var fact_id: Variant = value.get("fact_id")
    if not valid_identity(fact_id) or value.size() != 1:
        return false
    var expected_id: String = "evt:%012d" % int(next_seq)
    if raw.get("event_id", "") != expected_id or receipts.has(command_id) or facts.has(fact_id):
        return false
    if raw.size() != 7:
        return false

    var next_event: Dictionary = {
        "sequence": int(next_seq), "world_minute": int(at),
        "event_id": expected_id, "kind": "knowledge.granted",
        "command_id": command_id, "actor_id": actor_id,
        "payload": {"fact_id": fact_id}
    }
    sequence = int(next_seq)
    facts[fact_id] = true
    events.append(next_event)
    receipts[command_id] = {
        "signature": signature(actor_id, fact_id),
        "result": {"ok": true, "code": "APPLIED", "event_id": expected_id, "revision": sequence}
    }
    return true

func snapshot() -> Dictionary:
    return {
        "version": VERSION, "seed": seed,
        "world_minute": world_minute, "sequence": sequence,
        "facts": facts.duplicate(true),
        "receipts": receipts.duplicate(true),
        "events": events.duplicate(true)
    }
