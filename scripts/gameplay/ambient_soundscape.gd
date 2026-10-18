extends Node
## E6 minimum, asset-free local ambience. Never a WorldKernel authority.
## Live Godot audio, not a claimed historical recording or licensed radio.
const SETTINGS_PATH = "user://nile-kiosk-sound.cfg"
const SAMPLE_RATE = 11025.0

var enabled: bool = true
var room_id: String = "roof"
var kitchen_active: bool = false
var night: bool = false
var voice: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var tick: float = 0.0
var noise_seed: int = 7927
var breeze: float = 0.0
var water: float = 0.0

func _ready() -> void:
    var settings: ConfigFile = ConfigFile.new()
    if settings.load(SETTINGS_PATH) == OK:
        enabled = bool(settings.get_value("audio", "enabled", true))
    voice = AudioStreamPlayer.new()
    var stream: AudioStreamGenerator = AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = 0.25
    voice.stream = stream
    voice.volume_db = -9.0
    add_child(voice)
    voice.play()
    playback = voice.get_stream_playback() as AudioStreamGeneratorPlayback

func set_context(location: String, heating: bool, after_dark: bool) -> void:
    room_id = location
    kitchen_active = heating and location == "kiosk"
    night = after_dark

func toggle_sound() -> bool:
    enabled = not enabled
    var settings: ConfigFile = ConfigFile.new()
    settings.set_value("audio", "enabled", enabled)
    var saved: Error = settings.save(SETTINGS_PATH)
    if saved != OK:
        push_warning("E6_SOUND_SETTINGS_NOT_SAVED: " + str(saved))
    return enabled

func _process(_delta: float) -> void:
    if not enabled or playback == null: return
    # The audio is intentionally quiet and purely local. A small filtered
    # noise bed + river/roof/street movement and a gentle kettle tone react
    # to actual room and preparation, without gameplay RNG or sound assets.
    var available: int = playback.get_frames_available()
    for i in range(available):
        tick += 1.0 / SAMPLE_RATE
        noise_seed = (noise_seed * 1103515245 + 12345) & 0x7fffffff
        var noise: float = float(noise_seed % 65536) / 32768.0 - 1.0
        breeze = lerpf(breeze, noise, 0.0015)
        water = lerpf(water, noise, 0.04)
        var sample: float = breeze * 0.46
        if room_id == "kiosk":
            sample += water * 0.13 + sin(tick * TAU * 73.0) * 0.014
            if kitchen_active:
                sample += sin(tick * TAU * 490.0) * 0.018
        elif room_id == "street":
            sample += water * 0.045 + sin(tick * TAU * 93.0) * 0.009
        elif room_id == "roof":
            sample += water * 0.07
        else:
            sample *= 0.35
        if night: sample *= 0.72
        playback.push_frame(Vector2(sample, sample))
