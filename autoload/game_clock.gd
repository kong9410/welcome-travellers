extends Node

const SHIFT_START_HOUR: int = 8
const SHIFT_END_HOUR: int = 22
const SECONDS_PER_HOUR: float = 12.0

var current_hour: float = float(SHIFT_START_HOUR)


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)


func _process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		return
	if current_hour >= float(SHIFT_END_HOUR):
		return

	var previous_hour: int = int(floor(current_hour))
	current_hour += delta / SECONDS_PER_HOUR
	if current_hour >= float(SHIFT_END_HOUR):
		current_hour = float(SHIFT_END_HOUR)

	var next_hour: int = int(floor(current_hour))
	if next_hour != previous_hour or current_hour >= float(SHIFT_END_HOUR):
		EventBus.game_hour_changed.emit(current_hour)


func is_work_hours() -> bool:
	return current_hour >= float(SHIFT_START_HOUR) and current_hour < float(SHIFT_END_HOUR)


func get_time_label() -> String:
	var hour: int = int(floor(current_hour)) % 24
	var minute: int = int(floor(fmod(current_hour, 1.0) * 60.0))
	return "%02d:%02d" % [hour, minute]


func export_save_data() -> Dictionary:
	return {"current_hour": current_hour}


func import_save_data(data: Dictionary) -> void:
	current_hour = data.get("current_hour", float(SHIFT_START_HOUR))


func _on_day_started(_day: int) -> void:
	current_hour = float(SHIFT_START_HOUR)
	EventBus.game_hour_changed.emit(current_hour)


func _on_day_ended(_day: int, _summary: Dictionary) -> void:
	current_hour = float(SHIFT_START_HOUR)
