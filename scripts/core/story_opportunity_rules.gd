extends RefCounted
## Bounded, pure conditions for authored once-only narrative opportunities.
## Reads canonical WorldState only; never owns a clock, actor, ledger or Ink cursor.
const MAX_DEPTH: int = 4
const MAX_CHILDREN: int = 8

static func _exact(value: Dictionary, keys: Array) -> bool:
    if value.size() != keys.size(): return false
    for key in keys:
        if not value.has(key): return false
    return true

static func _id(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not (value as String).strip_edges().is_empty() and (value as String).length() <= 128

static func valid_condition(condition: Variant, depth: int = 0) -> bool:
    if depth > MAX_DEPTH or typeof(condition) != TYPE_DICTIONARY or condition.size() != 1:
        return false
    var key: String = str(condition.keys()[0])
    var value: Variant = condition[key]
    match key:
        "all", "any":
            if typeof(value) != TYPE_ARRAY or value.is_empty() or value.size() > MAX_CHILDREN:
                return false
            for part in value:
                if not valid_condition(part, depth + 1): return false
            return true
        "not":
            return valid_condition(value, depth + 1)
        "time_at_least", "time_before":
            return typeof(value) == TYPE_INT and value >= 0 and value <= 2147483647
        "player_knows", "has_fact", "event_seen", "player_at":
            return _id(value)
        "npc_at":
            return typeof(value) == TYPE_DICTIONARY and _exact(value, ["npc_id", "location_id"]) and _id(value["npc_id"]) and _id(value["location_id"])
        "kiosk_open":
            return typeof(value) == TYPE_BOOL
    return false

static func satisfied(condition: Dictionary, state: RefCounted) -> bool:
    var key: String = str(condition.keys()[0])
    var value: Variant = condition[key]
    match key:
        "all":
            for part in value:
                if not satisfied(part, state): return false
            return true
        "any":
            for part in value:
                if satisfied(part, state): return true
            return false
        "not":
            return not satisfied(value, state)
        "time_at_least":
            return state.world_minute >= int(value)
        "time_before":
            return state.world_minute < int(value)
        "player_knows":
            return state.society.knowledge.get("player", {}).has(value)
        "has_fact":
            return state.facts.has(value)
        "event_seen":
            for event in state.events:
                if event["kind"] == value: return true
            return false
        "player_at":
            if state.spatial.initialized():
                return state.spatial.player.get("room_id", "") == value
            return state.society.player_location == value
        "npc_at":
            return state.society.npcs.get(value["npc_id"], {}).get("location_id", "") == value["location_id"]
        "kiosk_open":
            return not state.life.policy.is_empty() and state.life.open == value
    return false

static func unlock(rules: Dictionary, opportunities: Dictionary, event: Dictionary, state: RefCounted) -> void:
    # Lexical ordering is explicit so registration order cannot change outcomes.
    var ids: Array = rules.keys()
    ids.sort()
    for opportunity_id in ids:
        if opportunities.has(opportunity_id): continue
        var rule: Dictionary = rules[opportunity_id]
        if rule["trigger_event"] != event["kind"]: continue
        # NPC-initiated offers must originate from that NPC's actual customer
        # delivery, not an unrelated delivery by somebody else.
        if rule.has("initiator_npc_id"):
            var order_id: String = str(event["payload"]["request"].get("order_id", ""))
            if state.service.orders.get(order_id, {}).get("npc_id", "") != rule["initiator_npc_id"]:
                continue
        if not satisfied(rule["when"], state): continue
        opportunities[opportunity_id] = {
            "source_event_id": event["event_id"],
            "source_command_id": event["command_id"],
            "world_minute": state.world_minute,
            "trigger_event": event["kind"]
        }
        if rule.has("initiator_npc_id"):
            opportunities[opportunity_id]["initiator_npc_id"] = rule["initiator_npc_id"]
