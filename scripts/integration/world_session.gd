extends RefCounted
## SYS P7: sole presentation-facing facade. All world mutations are commands.
## This component does not generate cash, time, NPCs or dialogue facts.
const Kernel = preload("res://scripts/core/world_kernel.gd")
const InkAdapter = preload("res://scripts/core/ink_world_bridge.gd")
const ContentBootstrap = preload("res://scripts/integration/world_content_bootstrap.gd")

var world: RefCounted
var ink: RefCounted
var last_error: String = ""
var save_path: String = ""
var last_save_revision: int = -1
var restored: bool = false

func _init(world_seed: int = 1, disk_path: String = "user://nile-kiosk-world-v7.json") -> void:
    world = Kernel.new(world_seed)
    save_path = disk_path

func command(command_id: String, actor_id: String, kind: String, payload: Dictionary) -> Dictionary:
    var result: Dictionary = world.dispatch({"id": command_id, "actor_id": actor_id,
        "kind": kind, "payload": payload.duplicate(true)})
    if not result.get("ok", false):
        last_error = "%s: %s" % [kind, result.get("code", "UNKNOWN")]
    else:
        last_error = ""
    return result

func advance(steps: int, command_id: String) -> Dictionary:
    return command(command_id, "system:clock", "time.advance", {"steps": steps})

func projection() -> Dictionary:
    var view: Dictionary = world.view()
    return {"version": view["version"], "revision": view["sequence"],
        "minute": view["world_minute"], "npc": view["society"].duplicate(true),
        "cooking": view["cooking"].duplicate(true), "orders": view["service"].duplicate(true),
        "economy": view["economy"].duplicate(true), "housing": view["housing"].duplicate(true),
        "narrative": view["narrative"].duplicate(true), "jobs": view["jobs"].duplicate(true)}

func bootstrap_from_content(path: String) -> Dictionary:
    # Deliberately only a fresh world, with no disk slot and no live InkPlayers.
    # A failed bundle never changes the current world or its save slot.
    if restored or ink != null or int(world.view()["sequence"]) != 0:
        return {"ok": false, "code": "WORLD_ALREADY_INITIALIZED"}
    if FileAccess.file_exists(save_path):
        return {"ok": false, "code": "SAVE_EXISTS"}
    var staged: Dictionary = ContentBootstrap.from_file(path, int(world.view()["seed"]))
    if not staged.get("ok", false):
        last_error = str(staged.get("code", "BUNDLE_REJECTED"))
        return staged
    world = staged["candidate"]
    last_error = ""
    return {"ok": true, "code": "BOOTSTRAPPED",
        "bundle_id": staged["bundle_id"], "revision": staged["revision"],
        "commands": staged["commands"]}

func load_existing() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return {"ok": true, "code": "NEW_WORLD"}
    var replacement: RefCounted = Kernel.new()
    if not replacement.load_from_file(save_path):
        last_error = "INVALID_WORLD_SAVE"
        return {"ok": false, "code": "INVALID_WORLD_SAVE"}
    if ink != null:
        ink.dispose()
        ink = null
    world = replacement
    restored = true
    last_save_revision = int(world.view()["sequence"])
    last_error = ""
    return {"ok": true, "code": "RESTORED", "revision": last_save_revision}

func save() -> Dictionary:
    var snapshot: Dictionary = world.view()
    if not world.save_to_file(save_path):
        last_error = "DISK_WRITE_FAILED"
        return {"ok": false, "code": last_error}
    # Read back from disk into a fresh Kernel, exercising complete P0–P6 replay.
    var verify: RefCounted = Kernel.new()
    if not verify.load_from_file(save_path) or not Kernel._matches(verify.view(), snapshot):
        last_error = "DISK_VERIFY_FAILED"
        return {"ok": false, "code": last_error}
    last_save_revision = int(snapshot["sequence"])
    last_error = ""
    return {"ok": true, "code": "SAVED", "revision": last_save_revision}

func attach_ink(session_id: String, story_path: String) -> bool:
    if ink == null:
        ink = InkAdapter.new(world)
    return ink.attach(session_id, story_path)

func ink_ready(session_id: String) -> bool:
    return ink != null and ink.ready(session_id)

func ink_begin(session_id: String, story_id: String, participants: Array, command_id: String) -> Dictionary:
    if ink == null: return {"ok": false, "code": "INK_NOT_ATTACHED"}
    return ink.begin(session_id, story_id, participants, command_id)

func ink_next(session_id: String, command_id: String) -> Dictionary:
    if ink == null: return {"ok": false, "code": "INK_NOT_ATTACHED"}
    return ink.advance(session_id, command_id)

func ink_choices(session_id: String) -> Array[Dictionary]:
    if ink == null: return []
    return ink.choices(session_id)

func ink_choose(session_id: String, option_id: String, command_id: String) -> Dictionary:
    if ink == null: return {"ok": false, "code": "INK_NOT_ATTACHED"}
    return ink.choose(session_id, option_id, command_id)

func diagnostics() -> Dictionary:
    var snapshot: Dictionary = world.view()
    return {
        "schema_version": snapshot["version"],
        "revision": snapshot["sequence"], "world_minute": snapshot["world_minute"],
        "events": snapshot["events"].size(), "receipts": snapshot["receipts"].size(),
        "pending_jobs": snapshot["jobs"].values().filter(func(x: Dictionary) -> bool: return x["status"] == "pending").size(),
        "session_count": snapshot["narrative"]["sessions"].size(),
        "balance_minor": snapshot["economy"]["accounts"]["player"],
        "last_save_revision": last_save_revision, "last_error": last_error
    }

func dispose() -> void:
    if ink != null:
        ink.dispose()
        ink = null
