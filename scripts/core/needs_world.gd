extends RefCounted
## E2: canonical, intentionally gentle physical needs and short/long emotional state.
## Rates are provisional integer balance values. No HUD or story runtime owns truth.
const MINUTE_PER_DAY: int = 1440
var hunger: int = 75
var rest: int = 80
var mood: int = 65
var wellbeing_baseline: int = 60
var meal_values: Dictionary = {}
var last_activity_day: int = -1
var uses_today: Dictionary = {}
var last_good_day: int = -1
var good_days: int = 0
# Policy 1 remains byte-compatible for authenticated older event histories.
# Policy 2 is explicitly recorded by a new needs.meals.configure command.
var policy_version: int = 1

static func owns(kind: String) -> bool:
    return kind in ["needs.meals.configure", "needs.eat"]

static func event_kind(kind: String) -> String:
    match kind:
        "needs.meals.configure": return "needs.meals_configured"
        "needs.eat": return "needs.ate"
    return ""

static func command_kind(kind: String) -> String:
    match kind:
        "needs.meals_configured": return "needs.meals.configure"
        "needs.ate": return "needs.eat"
    return ""

func snapshot() -> Dictionary:
    var result: Dictionary = {"hunger":hunger,"rest":rest,"mood":mood,
        "wellbeingBaseline":wellbeing_baseline,"meal_values":meal_values.duplicate(true),
        "last_activity_day":last_activity_day,"uses_today":uses_today.duplicate(true),
        "last_good_day":last_good_day,"good_days":good_days}
    # Old v12 snapshots did not contain this key; preserving their exact
    # serialized projection is essential for authenticated legacy replay.
    if policy_version == 2: result["policy_version"] = 2
    return result

func plan(kind: String, payload: Dictionary, actor: String,
          cooking: RefCounted, service: RefCounted, society: RefCounted,
          jobs: Dictionary, minute: int) -> Dictionary:
    if kind == "needs.meals.configure":
        if actor != "system:director": return {"ok":false,"code":"UNAUTHORIZED"}
        if not meal_values.is_empty(): return {"ok":false,"code":"MEALS_ALREADY_CONFIGURED"}
        var modern: bool = payload.has("policy_version")
        if (modern and (payload.size() != 2 or typeof(payload["policy_version"]) != TYPE_INT or payload["policy_version"] != 2)) or (not modern and payload.size() != 1) or typeof(payload.get("recipes")) != TYPE_DICTIONARY or payload["recipes"].is_empty() or payload["recipes"].size() > 32:
            return {"ok":false,"code":"INVALID_MEAL_POLICY"}
        var values: Dictionary = payload["recipes"]
        for recipe_id in values:
            if typeof(recipe_id) != TYPE_STRING or not cooking.recipes.has(recipe_id):
                return {"ok":false,"code":"UNKNOWN_RECIPE"}
            if typeof(values[recipe_id]) != TYPE_INT or int(values[recipe_id]) < 1 or int(values[recipe_id]) > 50:
                return {"ok":false,"code":"INVALID_NOURISHMENT"}
        var effect: Dictionary = {"recipes":values.duplicate(true)}
        if modern: effect["policy_version"] = 2
        return {"ok":true,"effect":effect
    if actor != "player": return {"ok":false,"code":"INVALID_PLAYER_ACTION"}
    if payload.size() != 1 or typeof(payload.get("item_id")) != TYPE_STRING:
        return {"ok":false,"code":"INVALID_MEAL"}
    var item_id: String = payload["item_id"]
    if not cooking.items.has(item_id): return {"ok":false,"code":"UNKNOWN_ITEM"}
    var item: Dictionary = cooking.items[item_id]
    if item["status"] != "ready": return {"ok":false,"code":"ITEM_NOT_READY"}
    if not meal_values.has(item["recipe_id"]): return {"ok":false,"code":"NOT_A_PERSONAL_MEAL"}
    # Existing cooked items do not track portable location yet. Personal eating is
    # only allowed at an actual operating venue, never remotely from the home HUD.
    var at_venue: bool = false
    for venue in service.venues.values():
        if society.player_location == venue["location_id"]: at_venue = true
    if not at_venue: return {"ok":false,"code":"PLAYER_ABSENT"}
    # Never silently take food promised to a currently accepted customer.
    for order in service.orders.values():
        if order["status"] == "accepted" and order["recipe_id"] == item["recipe_id"]:
            return {"ok":false,"code":"ORDER_NEEDS_RECIPE"}
    var consume: Dictionary = cooking.plan("cook.item.use",
        {"item_id":item_id,"purpose_id":"player:meal"},actor,jobs,minute)
    if not consume.get("ok",false): return consume
    return {"ok":true,"effect":{"item_id":item_id,
        "recipe_id":item["recipe_id"],"nourishment":int(meal_values[item["recipe_id"]])}}

func _good_day(day: int) -> void:
    if day == last_good_day or hunger < 35 or rest < 35: return
    last_good_day = day
    good_days += 1
    # A slow tendency; never a visible +Contentment popup.
    if good_days % 3 == 0:
        wellbeing_baseline = mini(78, wellbeing_baseline + 1)

func _placed_bed(housing: RefCounted, home_room: String) -> bool:
    for item in housing.objects.values():
        if item["type_id"] == "bed" and item["unit_id"] == home_room and housing.allowed(home_room):
            return true
    return false

func on_elapsed(from_minute: int, to_minute: int, kind: String,
                housing: RefCounted, home_room: String) -> void:
    var hunger_before: int = hunger
    var rest_before: int = rest
    hunger = maxi(0, hunger - (int(to_minute / 45) - int(from_minute / 45)))
    if kind == "life.sleep":
        var sleep_minutes: int = to_minute - from_minute
        var recovery: int = mini(42, int(sleep_minutes / 30))
        if _placed_bed(housing, home_room):
            recovery += 12
        rest = mini(100, rest + recovery)
        _good_day(int(to_minute / MINUTE_PER_DAY))
    else:
        rest = maxi(0, rest - (int(to_minute / 60) - int(from_minute / 60)))
    var beats: int = int(to_minute / 120) - int(from_minute / 120)
    if policy_version == 1:
        # Authenticated legacy events must still replay exactly. This old
        # event-batched discomfort rule was not chunk-invariant for tired days.
        if mood < wellbeing_baseline:
            mood = mini(wellbeing_baseline, mood + beats)
        elif mood > wellbeing_baseline:
            mood = maxi(wellbeing_baseline, mood - beats)
        if hunger < 20 or rest < 20:
            mood = maxi(25, mood - mini(2, beats))
    else:
        # E2 policy 2: every absolute 120-minute boundary evolves Mood once.
        # Physiological readings at each boundary are computed from the same
        # P1 timeline, not the arbitrary size of this time.advance command.
        # The loop is capped by the finite 32-bit canonical world horizon.
        for slot in range(int(from_minute / 120) + 1, int(to_minute / 120) + 1):
            var at_minute: int = slot * 120
            var beat_hunger: int = maxi(0, hunger_before -
                (int(at_minute / 45) - int(from_minute / 45)))
            var beat_rest: int = rest if kind == "life.sleep" else maxi(0,
                rest_before - (int(at_minute / 60) - int(from_minute / 60)))
            if mood < wellbeing_baseline:
                mood += 1
            elif mood > wellbeing_baseline:
                mood -= 1
            if beat_hunger < 20 or beat_rest < 20:
                mood = maxi(25, mood - 1)
    mood = clampi(mood, 0, 100)

func on_activity(activity_id: String, world_minute: int) -> void:
    var day: int = int(world_minute / MINUTE_PER_DAY)
    if last_activity_day != day:
        last_activity_day = day
        uses_today = {}
    var visits: int = int(uses_today.get(activity_id,0))
    uses_today[activity_id] = mini(3,visits + 1)
    # Same chosen quiet moment works best once; repeating it is not a grinder.
    var benefit: int = 4 if visits == 0 else (1 if visits == 1 else 0)
    if hunger < 25 or rest < 25: benefit = mini(benefit,1)
    mood = mini(100,mood + benefit)
    if benefit >= 4:
        _good_day(day)

func apply_command(kind: String, effect: Dictionary, cooking: RefCounted,
                   jobs: Dictionary, minute: int, event_id: String, sequence: int,
                   actor: String, command_id: String) -> void:
    if kind == "needs.meals.configure":
        meal_values = effect["recipes"].duplicate(true)
        if effect.get("policy_version",1) == 2: policy_version = 2
    elif kind == "needs.eat":
        var item_id: String = effect["item_id"]
        cooking.apply_command("cook.item.use",
            {"item_id":item_id,"purpose_id":"player:meal"},{"item_id":item_id},
            minute,event_id,sequence,actor,command_id,jobs)
        var before: int = hunger
        hunger = mini(100,hunger + int(effect["nourishment"]))
        if before < 35: mood = mini(100,mood + 4)
        elif before < 65: mood = mini(100,mood + 2)
