extends RefCounted
## SYS P5 canonical, integer-minor-unit zero-sum ledger and priced P4 claims.
## Values in EGP minor units are intentionally authored, never hardcoded here.
const Supply = preload("res://scripts/core/supply_contracts.gd")
const LIMIT: int = 2147483647

var supply_offers: Dictionary = {}
var supply_resolutions: Dictionary = {}
var accounts: Dictionary = {
    "player": 0, "world:treasury": 0, "world:vendors": 0,
    "world:landlord": 0, "world:customers": 0
}
var transactions: Dictionary = {}
var journal: Array = []
var refunded: Dictionary = {}
var prices: Dictionary = {}
var quotes: Dictionary = {}

static func identity(v: Variant) -> bool:
    return typeof(v) == TYPE_STRING and not (v as String).strip_edges().is_empty() and (v as String).length() <= 128

static func minor(v: Variant, minimum: int = 0) -> bool:
    if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
        return false
    return is_finite(float(v)) and float(v) >= float(minimum) and float(v) <= float(LIMIT) and float(v) == float(int(v))

static func exact(p: Dictionary, keys: Array) -> bool:
    if p.size() != keys.size(): return false
    for key in keys:
        if not p.has(key): return false
    return true

static func owns(kind: String) -> bool:
    return Supply.owns(kind) or kind in ["economy.fund", "economy.pay", "economy.refund",
        "economy.recipe.price.set", "economy.order.quote", "economy.order.settle"]

static func event_kind(kind: String) -> String:
    if Supply.owns(kind): return Supply.event_kind(kind)
    match kind:
        "economy.fund": return "economy.funded"
        "economy.pay": return "economy.paid"
        "economy.refund": return "economy.refunded"
        "economy.recipe.price.set": return "economy.recipe_price_set"
        "economy.order.quote": return "economy.order_quoted"
        "economy.order.settle": return "economy.order_settled"
    return ""

static func command_kind(kind: String) -> String:
    var supply_kind: String = Supply.command_kind(kind)
    if not supply_kind.is_empty(): return supply_kind
    match kind:
        "economy.funded": return "economy.fund"
        "economy.paid": return "economy.pay"
        "economy.refunded": return "economy.refund"
        "economy.recipe_price_set": return "economy.recipe.price.set"
        "economy.order_quoted": return "economy.order.quote"
        "economy.order_settled": return "economy.order.settle"
    return ""

static func fail(code: String) -> Dictionary:
    return {"ok": false, "code": code}

func snapshot() -> Dictionary:
    return {"supply_offers":supply_offers.duplicate(true),"supply_resolutions":supply_resolutions.duplicate(true),"accounts": accounts.duplicate(true), "transactions": transactions.duplicate(true),
        "journal": journal.duplicate(true), "refunded": refunded.duplicate(true),
        "prices": prices.duplicate(true), "quotes": quotes.duplicate(true)}

func _transfer_effect(id: String, from_id: String, to_id: String, amount: int, cause: String) -> Dictionary:
    if not identity(id) or not identity(cause) or not accounts.has(from_id) or not accounts.has(to_id) or from_id == to_id or amount < 1:
        return fail("INVALID_TRANSFER")
    if transactions.has(id):
        return fail("TRANSACTION_EXISTS")
    if from_id == "player" and int(accounts[from_id]) < amount:
        return fail("INSUFFICIENT_FUNDS")
    if amount > LIMIT - int(accounts[to_id]) or int(accounts[from_id]) < -LIMIT + amount:
        return fail("BALANCE_OVERFLOW")
    return {"ok": true, "effect": {"transaction_id": id, "from_account": from_id,
        "to_account": to_id, "amount_minor": amount, "cause_id": cause}}

func plan_transfer(transfer: Dictionary) -> Dictionary:
    if not exact(transfer, ["transaction_id", "from_account", "to_account", "amount_minor", "cause_id"]):
        return fail("INVALID_TRANSFER")
    if not minor(transfer.get("amount_minor"), 1):
        return fail("INVALID_TRANSFER")
    return _transfer_effect(str(transfer["transaction_id"]), str(transfer["from_account"]),
        str(transfer["to_account"]), int(transfer["amount_minor"]), str(transfer["cause_id"]))

func plan(kind: String, p: Dictionary, actor: String, service: RefCounted, cooking: RefCounted, world: RefCounted = null) -> Dictionary:
    if Supply.owns(kind):
        return Supply.plan(kind,p,actor,world) if world != null else fail("WORLD_CONTEXT_REQUIRED")
    match kind:
        "economy.fund":
            if not exact(p, ["transaction_id", "amount_minor", "source_id"]) or not minor(p.get("amount_minor"), 1) or not identity(p.get("source_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "system:treasury":
                return fail("UNAUTHORIZED")
            return _transfer_effect(p["transaction_id"], "world:treasury", "player", int(p["amount_minor"]), p["source_id"])
        "economy.pay":
            if not exact(p, ["transaction_id", "recipient_id", "amount_minor", "cause_id"]) or not minor(p.get("amount_minor"), 1):
                return fail("INVALID_PAYLOAD")
            if actor != "player" or p.get("recipient_id") not in ["world:vendors", "world:landlord"]:
                return fail("UNAUTHORIZED")
            return _transfer_effect(p["transaction_id"], "player", p["recipient_id"], int(p["amount_minor"]), str(p.get("cause_id", "")))
        "economy.refund":
            if not exact(p, ["transaction_id", "original_transaction_id"]) or not identity(p.get("original_transaction_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "system:treasury":
                return fail("UNAUTHORIZED")
            var original_id: String = p["original_transaction_id"]
            if not transactions.has(original_id):
                return fail("UNKNOWN_TRANSACTION")
            if refunded.has(original_id):
                return fail("ALREADY_REFUNDED")
            var original: Dictionary = transactions[original_id]
            if original["from_account"] != "player" or original["source_kind"] != "economy.pay":
                # Housing access and bought objects are separate domain assets.
                # A raw money refund cannot reverse them; a future domain-specific
                # compensation command must settle both sides atomically.
                return fail("DOMAIN_REFUND_REQUIRED")
            return _transfer_effect(str(p["transaction_id"]), original["to_account"], "player",
                int(original["amount_minor"]), "refund:" + original_id)
        "economy.recipe.price.set":
            if not exact(p, ["recipe_id", "amount_minor"]) or not identity(p.get("recipe_id")) or not minor(p.get("amount_minor"), 1):
                return fail("INVALID_PAYLOAD")
            if actor != "system:pricing" or not cooking.recipes.has(p["recipe_id"]):
                return fail("UNAUTHORIZED_OR_UNKNOWN_RECIPE")
            return {"ok": true, "effect": {"recipe_id": p["recipe_id"], "amount_minor": int(p["amount_minor"])}}
        "economy.order.quote":
            if not exact(p, ["claim_id"]) or not identity(p.get("claim_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "system:pricing":
                return fail("UNAUTHORIZED")
            if not service.payment_claims.has(p["claim_id"]):
                return fail("UNKNOWN_CLAIM")
            var claim: Dictionary = service.payment_claims[p["claim_id"]]
            if claim["status"] != "awaiting_ledger" or quotes.has(p["claim_id"]):
                return fail("CLAIM_NOT_QUOTABLE")
            var order: Dictionary = service.orders[claim["order_id"]]
            if not prices.has(order["recipe_id"]):
                return fail("PRICE_UNDEFINED")
            return {"ok": true, "effect": {"claim_id": p["claim_id"],
                "recipe_id": order["recipe_id"], "amount_minor": prices[order["recipe_id"]]}}
        "economy.order.settle":
            if not exact(p, ["claim_id", "transaction_id"]) or not identity(p.get("claim_id")):
                return fail("INVALID_PAYLOAD")
            if actor != "system:service":
                return fail("UNAUTHORIZED")
            if not service.payment_claims.has(p["claim_id"]) or not quotes.has(p["claim_id"]):
                return fail("UNQUOTED_CLAIM")
            if service.payment_claims[p["claim_id"]]["status"] != "awaiting_ledger":
                return fail("CLAIM_ALREADY_SETTLED")
            return _transfer_effect(str(p["transaction_id"]), "world:customers", "player",
                int(quotes[p["claim_id"]]["amount_minor"]), p["claim_id"])
    return fail("UNKNOWN_COMMAND")

func apply_transfer(effect: Dictionary, event_id: String, minute: int, source_kind: String) -> void:
    var tx_id: String = effect["transaction_id"]
    var amount: int = int(effect["amount_minor"])
    var from_id: String = effect["from_account"]
    var to_id: String = effect["to_account"]
    accounts[from_id] = int(accounts[from_id]) - amount
    accounts[to_id] = int(accounts[to_id]) + amount
    var row: Dictionary = {
        "transaction_id": tx_id, "from_account": from_id, "to_account": to_id,
        "amount_minor": amount, "cause_id": effect["cause_id"], "event_id": event_id,
        "world_minute": minute, "source_kind": source_kind,
        "entries": [
            {"account_id": from_id, "delta_minor": -amount},
            {"account_id": to_id, "delta_minor": amount}
        ]
    }
    transactions[tx_id] = row.duplicate(true)
    journal.append(row)

func apply_command(kind: String, p: Dictionary, effect: Dictionary, event_id: String,
        minute: int, service: RefCounted) -> void:
    if Supply.owns(kind):
        Supply.apply(self,kind,p,effect,event_id,minute)
        return
    match kind:
        "economy.fund", "economy.pay", "economy.refund", "economy.order.settle":
            apply_transfer(effect, event_id, minute, kind)
            if kind == "economy.refund":
                refunded[p["original_transaction_id"]] = effect["transaction_id"]
            if kind == "economy.order.settle":
                var claim: Dictionary = service.payment_claims[p["claim_id"]]
                claim["status"] = "settled"
                claim["amount"] = int(effect["amount_minor"])
                claim["transaction_id"] = effect["transaction_id"]
                service.orders[claim["order_id"]]["payment_status"] = "settled"
        "economy.recipe.price.set":
            prices[p["recipe_id"]] = int(effect["amount_minor"])
        "economy.order.quote":
            quotes[p["claim_id"]] = {"claim_id": p["claim_id"],
                "recipe_id": effect["recipe_id"], "amount_minor": int(effect["amount_minor"]),
                "event_id": event_id}
