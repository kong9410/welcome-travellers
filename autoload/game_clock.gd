extends Node

const DEFAULT_OPEN_HOUR: int = 12
const DEFAULT_CLOSE_HOUR: int = 22
const CLOSING_DURATION_HOURS: float = 2.0
const SECONDS_PER_HOUR: float = 36.0
const MIN_OPEN_DURATION_HOURS: int = 4

var active_open_hour: int = DEFAULT_OPEN_HOUR
var active_close_hour: int = DEFAULT_CLOSE_HOUR
var scheduled_open_hour: int = DEFAULT_OPEN_HOUR
var scheduled_close_hour: int = DEFAULT_CLOSE_HOUR
var current_hour: float = float(DEFAULT_OPEN_HOUR)
var _closing_start_hour: float = -1.0
var _closing_finish_scheduled: bool = false


func _process(delta: float) -> void:
	if not GameTimeManager.is_simulation_active():
		return

	var previous_hour: int = int(floor(current_hour))
	current_hour += GameTimeManager.scaled_delta(delta) / SECONDS_PER_HOUR

	match GameTimeManager.phase:
		GamePhases.Id.OPEN:
			if current_hour >= float(active_close_hour):
				current_hour = float(active_close_hour)
				begin_closing()
		GamePhases.Id.CLOSING:
			var closing_end_hour: float = get_closing_end_hour()
			if current_hour >= closing_end_hour:
				current_hour = closing_end_hour
				_try_finish_closing_if_due()

	var next_hour: int = int(floor(current_hour))
	if next_hour != previous_hour:
		EventBus.game_hour_changed.emit(current_hour)


func is_open_hours() -> bool:
	return GameTimeManager.phase == GamePhases.Id.OPEN


func is_closing_hours() -> bool:
	return GameTimeManager.phase == GamePhases.Id.CLOSING


func is_service_active() -> bool:
	return is_open_hours() or is_closing_hours()


func is_work_hours() -> bool:
	return is_open_hours()


func skip_remaining_closing_time() -> void:
	if GameTimeManager.phase != GamePhases.Id.CLOSING:
		return
	current_hour = get_closing_end_hour()
	GameTimeManager.set_time_paused(false)
	EventBus.game_hour_changed.emit(current_hour)
	_try_finish_closing_if_due()


func begin_open_day() -> void:
	_closing_finish_scheduled = false
	_closing_start_hour = -1.0
	current_hour = float(active_open_hour)
	EventBus.game_hour_changed.emit(current_hour)


func begin_closing(from_current_time: bool = false) -> void:
	if GameTimeManager.phase != GamePhases.Id.OPEN:
		return
	_closing_finish_scheduled = false
	if not from_current_time:
		current_hour = maxf(current_hour, float(active_close_hour))
	_closing_start_hour = current_hour
	GameTimeManager.set_phase(GamePhases.Id.CLOSING)
	GameTimeManager.set_time_paused(false)
	CustomerService.on_service_closed()
	EventBus.game_hour_changed.emit(current_hour)
	_try_finish_closing_if_due()


func get_closing_end_hour() -> float:
	if _closing_start_hour >= 0.0:
		return _closing_start_hour + CLOSING_DURATION_HOURS
	return float(active_close_hour) + CLOSING_DURATION_HOURS


func _try_finish_closing_if_due() -> void:
	if GameTimeManager.phase != GamePhases.Id.CLOSING:
		return
	if _closing_finish_scheduled:
		return
	if current_hour + 0.0001 < get_closing_end_hour():
		return
	_closing_finish_scheduled = true
	GameTimeManager.call_deferred("finish_closing_day")


func get_time_label() -> String:
	var hour: int = int(floor(current_hour))
	var minute: int = int(floor(fmod(current_hour, 1.0) * 60.0))
	return "%02d:%02d" % [hour, minute]


func get_hours_label() -> String:
	return "%02d:00-%02d:00" % [active_open_hour, active_close_hour]


func get_scheduled_hours_label() -> String:
	return "%02d:00-%02d:00" % [scheduled_open_hour, scheduled_close_hour]


func format_hour(hour: int) -> String:
	return "%02d:00" % hour


func get_max_open_hour() -> int:
	return 24 - MIN_OPEN_DURATION_HOURS


func adjust_scheduled_open(delta_hours: int) -> bool:
	var next_open: int = clampi(scheduled_open_hour + delta_hours, 0, get_max_open_hour())
	var min_close: int = next_open + MIN_OPEN_DURATION_HOURS
	var next_close: int = maxi(scheduled_close_hour, min_close)
	if next_close > 24:
		return false
	return set_scheduled_hours(next_open, next_close)


func adjust_scheduled_close(delta_hours: int) -> bool:
	var min_close: int = scheduled_open_hour + MIN_OPEN_DURATION_HOURS
	var next_close: int = clampi(scheduled_close_hour + delta_hours, min_close, 24)
	return set_scheduled_hours(scheduled_open_hour, next_close)


func set_scheduled_hours(open_hour: int, close_hour: int) -> bool:
	if not _validate_hours(open_hour, close_hour):
		return false
	scheduled_open_hour = open_hour
	scheduled_close_hour = close_hour
	EventBus.business_hours_changed.emit()
	return true


func apply_scheduled_to_active() -> void:
	if not _validate_hours(scheduled_open_hour, scheduled_close_hour):
		return
	active_open_hour = scheduled_open_hour
	active_close_hour = scheduled_close_hour
	EventBus.business_hours_changed.emit()


func export_save_data() -> Dictionary:
	return {
		"current_hour": current_hour,
		"active_open_hour": active_open_hour,
		"active_close_hour": active_close_hour,
		"scheduled_open_hour": scheduled_open_hour,
		"scheduled_close_hour": scheduled_close_hour,
	}


func import_save_data(data: Dictionary) -> void:
	current_hour = float(data.get("current_hour", float(DEFAULT_OPEN_HOUR)))
	active_open_hour = int(data.get("active_open_hour", data.get("open_hour", DEFAULT_OPEN_HOUR)))
	active_close_hour = int(data.get("active_close_hour", data.get("close_hour", DEFAULT_CLOSE_HOUR)))
	scheduled_open_hour = int(
		data.get("scheduled_open_hour", data.get("active_open_hour", active_open_hour))
	)
	scheduled_close_hour = int(
		data.get("scheduled_close_hour", data.get("active_close_hour", active_close_hour))
	)


func _validate_hours(open_hour: int, close_hour: int) -> bool:
	if close_hour <= open_hour:
		return false
	if close_hour - open_hour < MIN_OPEN_DURATION_HOURS:
		return false
	return open_hour >= 0 and close_hour <= 24
