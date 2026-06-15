extends Node

const SETTINGS_PATH := "user://display_settings.cfg"
const SETTINGS_SECTION := "display"
const SETTINGS_KEY := "resolution_preset"

var current_preset: ResolutionPresets.Id = ResolutionPresets.Id.P720


func _ready() -> void:
	_load_settings()
	apply_preset(current_preset, false)


func apply_preset(preset: ResolutionPresets.Id, save: bool = true) -> void:
	current_preset = preset
	var window_size: Vector2i = ResolutionPresets.get_size(preset)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	_center_window(window_size)

	if save:
		_save_settings()

	EventBus.resolution_changed.emit(preset)


func get_current_window_size() -> Vector2i:
	return DisplayServer.window_get_size()


func _center_window(window_size: Vector2i) -> void:
	var screen_index: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_index)
	var centered_position: Vector2i = (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_position)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	current_preset = config.get_value(
		SETTINGS_SECTION,
		SETTINGS_KEY,
		ResolutionPresets.Id.P720
	) as ResolutionPresets.Id


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, current_preset)
	config.save(SETTINGS_PATH)
