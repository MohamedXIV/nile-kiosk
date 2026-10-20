extends CanvasLayer
## View-only scene cover for an actual P2 portal command. This layer
## never owns a world minute, location, destination or saved transition.
const FADE_OUT_SECONDS: float = 0.16
const FADE_IN_SECONDS: float = 0.22
const VIEW_SIZE: Vector2 = Vector2(960.0,540.0)

var shade: ColorRect
var fading: bool = false

func _ready() -> void:
    layer = 20
    shade = ColorRect.new()
    shade.color = Color(0.015,0.025,0.035,0.0)
    shade.position = Vector2.ZERO
    shade.size = VIEW_SIZE
    shade.visible = false
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(shade)

func transition(at_black: Callable, after_clear: Callable) -> bool:
    if fading or not at_black.is_valid() or not after_clear.is_valid():
        return false
    fading = true
    shade.visible = true
    shade.color = Color(0.015,0.025,0.035,0.0)
    var tween: Tween = create_tween()
    tween.tween_property(shade,"color:a",1.0,FADE_OUT_SECONDS)
    tween.tween_callback(at_black)
    tween.tween_property(shade,"color:a",0.0,FADE_IN_SECONDS)
    tween.tween_callback(_finish.bind(after_clear))
    return true

func _finish(after_clear: Callable) -> void:
    shade.visible = false
    fading = false
    after_clear.call()
