extends RefCounted
## Canonical world facts. No dialogue adapter should own these.

var facts: Dictionary = {}
var applied_effects: Dictionary = {}

func has_fact(fact_id: String) -> bool:
    return facts.get(fact_id, false) == true

func grant_fact(fact_id: String, effect_id: String) -> bool:
    if applied_effects.has(effect_id):
        return false
    applied_effects[effect_id] = true
    facts[fact_id] = true
    return true
