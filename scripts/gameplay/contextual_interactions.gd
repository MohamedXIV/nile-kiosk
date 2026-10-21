extends RefCounted
## View/input-only interaction resolver. Orders nearby authored opportunities
## into a maximum of two buttons. Actions still go through GameEntry and
## WorldKernel; this file never grants proximity, resources or story knowledge.
##
## Each candidate is {"kind": String, "label": String}; the scene must
## re-resolve at press time because P1 minutes and NPC schedules keep moving.

static func _append(result: Array[Dictionary], kind: String, label: String) -> void:
    if kind.is_empty() or result.size() >= 2:
        return
    for candidate in result:
        if candidate["kind"] == kind:
            return
    result.append({"kind":kind, "label":label})

static func resolve(state: Dictionary, portal_name: String,
        counter_near: bool, quiet_near: bool,
        dialogue_target: String, sandwich_near: bool) -> Array[Dictionary]:
    var actions: Array[Dictionary] = []
    var place: String = str(state.get("location",""))
    var kiosk_open: bool = bool(state.get("kiosk_open",false))
    var stage: String = str(state.get("tea_stage",""))
    var tea_key: String = str(state.get("tea_action",""))
    var current_order: String = str(state.get("active_order",""))
    var order_status: String = str(state.get("order_status",""))
    var order_recipe: String = str(state.get("order_recipe",""))

    # Work within physical reach wins over generic conversation/door hints.
    if place == "kiosk" and counter_near and kiosk_open:
        if not stage.is_empty():
            if int(state.get("tea_ready_in",0)) > 0:
                _append(actions,"wait","Wait 5m")
            elif tea_key == "H":
                _append(actions,"tea_heat","Heat / lift")
            elif tea_key == "U":
                _append(actions,"tea_pour","Pour tea")
        elif not current_order.is_empty() and order_status in ["offered","accepted"]:
            if order_recipe == "liver_sandwich" and order_status == "accepted" and sandwich_near:
                _append(actions,"sandwich","Prepare sandwich")
            else:
                _append(actions,"serve","Serve customer")
        elif not current_order.is_empty() and order_status == "delivered" and \
                str(state.get("order_payment","none")) not in ["settled","none"]:
            # P5 settlement survives a spontaneous NPC greeting. The same
            # real Serve/ledger action stays first in reach on touch devices.
            _append(actions,"serve","Settle payment")
    # An actual nearby person must never disappear behind two vending
    # choices. Conversation after serving has only a brief genuine P1/P4
    # proximity window; unattended procurement can wait or expire.
    if not dialogue_target.is_empty():
        _append(actions,"talk","Talk to " + dialogue_target.capitalize())
    if not portal_name.is_empty():
        _append(actions,"door","Go to " + portal_name.capitalize())

    if place == "kiosk":
        if not kiosk_open:
            _append(actions,"open","Open kiosk")
        elif counter_near:
            # The counter has a separate physically reachable P12 opener.
            # Show genuine available business offers only after nearby people.
            if state.get("market_offer",{}).get("status","") == "available":
                _append(actions,"market_buy","Buy market leaves")
                _append(actions,"market_decline","Decline market offer")
            elif state.get("referral_offer",{}).get("status","") == "available":
                _append(actions,"supply_buy","Buy delivered leaves")
                _append(actions,"supply_decline","Decline supplier offer")
            if sandwich_near and current_order.is_empty():
                _append(actions,"sandwich","Sandwich counter")
        else:
            _append(actions,"close","Close kiosk")
    elif place == "roof" and bool(state.get("bed_placed",false)):
        _append(actions,"sleep","Sleep")

    if quiet_near:
        _append(actions,"quiet","Quiet moment")
    return actions
