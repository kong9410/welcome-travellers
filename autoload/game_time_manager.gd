extends Node

var current_day: int = 1
var phase: GamePhases.Id = GamePhases.Id.BRIEFING
var time_paused: bool = false


func _ready() -> void:
	phase = GamePhases.Id.BRIEFING


func is_running() -> bool:
	return phase == GamePhases.Id.RUNNING


func is_time_flowing() -> bool:
	return is_running() and not time_paused


func set_time_paused(paused: bool) -> void:
	if time_paused == paused:
		return
	time_paused = paused
	EventBus.game_time_pause_changed.emit(paused)


func is_briefing() -> bool:
	return phase == GamePhases.Id.BRIEFING


func request_morning_briefing() -> void:
	phase = GamePhases.Id.BRIEFING
	EventBus.morning_briefing_requested.emit(current_day)


func start_day() -> void:
	if phase == GamePhases.Id.GAME_OVER:
		return
	phase = GamePhases.Id.RUNNING
	time_paused = false
	EventBus.day_started.emit(current_day)


func end_day() -> void:
	if not is_running():
		return
	time_paused = false
	CustomerService.on_day_ending()
	var summary: Dictionary = EconomyManager.end_of_day_settlement(current_day)
	EventBus.day_ended.emit(current_day, summary)
	if EconomyManager.is_bankrupt():
		phase = GamePhases.Id.GAME_OVER
		EventBus.game_over.emit("7일 연속 적자. 여관이 문을 닫았습니다.")
		return
	current_day += 1
	request_morning_briefing()


func export_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"phase": phase,
	}


func import_save_data(data: Dictionary) -> void:
	current_day = data.get("current_day", 1)
	phase = data.get("phase", GamePhases.Id.BRIEFING)
	time_paused = false
