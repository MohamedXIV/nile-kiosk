extends RefCounted
## Bounded offsite collection, honestly presented as an elapsed activity.
## No invented market room or parallel vendor stock, cash, location or clock.
const Supply = preload("res://scripts/core/supply_contracts.gd")
const PATH = "res://content/economy/nile_market_collection.v1.json"
const OFFER = "market:tea-collection"
func configure(session: RefCounted) -> Dictionary:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=3 or raw.get("schema")!=1 or raw.get("terms_status")!="PROPOSED" or typeof(raw.get("offer"))!=TYPE_DICTIONARY or raw["offer"].get("offer_id","")!=OFFER:
        return {"ok":false,"code":"INVALID_MARKET_CONTENT"}
    if not session.world.economy_view()["supply_offers"].has(OFFER):
        return session.command("game:market:offer:v1","system:catalog","supply.offer.register",raw["offer"])
    return {"ok":true}
func view(session: RefCounted) -> Dictionary:
    var economy: Dictionary = session.world.economy_view()
    if not economy["supply_offers"].has(OFFER): return {}
    var offer: Dictionary = economy["supply_offers"][OFFER].duplicate(true)
    # Shared P5 day-aware finite lot and exact current-day resolution; the
    # existing learned-contact route remains strictly one-shot as before.
    var minute: int = int(session.world.view()["world_minute"])
    offer["remaining_stock"]=Supply.remaining(economy["supply_offers"],
        economy["supply_resolutions"],offer,minute)
    var status: String = Supply.availability(offer,minute,true)
    if status.is_empty() and offer["remaining_stock"]<int(offer["quantity"]): status="SUPPLY_OUT_OF_STOCK"
    var receipt_key: String = Supply.receipt_id(OFFER,offer,economy["supply_resolutions"],minute)
    offer["status"]=economy["supply_resolutions"].get(receipt_key,{}).get(
        "status","available" if status.is_empty() else status)
    return offer
func resolve(session: RefCounted, at_counter: bool, buy: bool, command_id: String) -> Dictionary:
    if not at_counter: return {"ok":false,"code":"NOT_AT_SUPPLY_COUNTER"}
    return session.command(command_id,"player","supply.purchase" if buy else "supply.decline",{"offer_id":OFFER})