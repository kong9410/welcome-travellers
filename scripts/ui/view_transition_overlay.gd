class_name ViewTransitionOverlay
extends ColorRect

@export var fade_duration: float = 0.18

var _is_busy: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	visible = false
	color.a = 0.0
	set_anchors_preset(Control.PRESET_FULL_RECT)


func is_busy() -> bool:
	return _is_busy


func play_transition(on_midpoint: Callable) -> void:
	if _is_busy:
		return
	_is_busy = true
	visible = true

	var tween := create_tween()
	tween.tween_property(self, "color:a", 1.0, fade_duration)
	tween.tween_callback(on_midpoint)
	tween.tween_property(self, "color:a", 0.0, fade_duration)
	tween.tween_callback(_finish_transition)


func _finish_transition() -> void:
	visible = false
	_is_busy = false
