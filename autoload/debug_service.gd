extends Node

var enabled: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F3:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	set_enabled(not enabled)


func set_enabled(active: bool) -> void:
	if enabled == active:
		return
	enabled = active
	EventBus.debug_mode_changed.emit(enabled)
	CustomerService.sync_debug_visuals()


func is_active() -> bool:
	return enabled
