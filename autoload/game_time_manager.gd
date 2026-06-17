extends Node

const START_YEAR: int = 320
const DAYS_PER_SEASON: int = 30
const SEASONS_PER_YEAR: int = 4
const DAYS_PER_YEAR: int = DAYS_PER_SEASON * SEASONS_PER_YEAR
const SEASON_LABELS: PackedStringArray = ["봄", "여름", "가을", "겨울"]

var current_day: int = 1
var phase: GamePhases.Id = GamePhases.Id.PRE_OPEN
var time_paused: bool = false
var time_scale: float = 1.0
const MAX_TIME_SCALE: float = 3.0


func _ready() -> void:
	phase = GamePhases.Id.PRE_OPEN
	time_paused = true


func is_simulation_active() -> bool:
	return is_service_time_phase() and not time_paused


func is_service_time_phase() -> bool:
	return phase in [GamePhases.Id.OPEN, GamePhases.Id.CLOSING]


func is_running() -> bool:
	return is_simulation_active()


func is_time_flowing() -> bool:
	return is_simulation_active()


func can_prepare_inn() -> bool:
	return phase in [GamePhases.Id.PRE_OPEN, GamePhases.Id.SETTLEMENT] or is_simulation_active()


func is_pre_open() -> bool:
	return phase == GamePhases.Id.PRE_OPEN


func is_briefing() -> bool:
	return phase == GamePhases.Id.PRE_OPEN


func get_calendar_year() -> int:
	var day_index: int = maxi(current_day - 1, 0)
	return START_YEAR + int(day_index / DAYS_PER_YEAR)


func get_season_index() -> int:
	var day_index: int = maxi(current_day - 1, 0)
	return int((day_index % DAYS_PER_YEAR) / DAYS_PER_SEASON)


func get_season_label() -> String:
	return SEASON_LABELS[get_season_index()]


func get_season_day() -> int:
	var day_index: int = maxi(current_day - 1, 0)
	return int(day_index % DAYS_PER_SEASON) + 1


func get_calendar_label() -> String:
	return "%d년 %s %d일" % [
		get_calendar_year(),
		get_season_label(),
		get_season_day(),
	]


func get_service_status_label() -> String:
	match phase:
		GamePhases.Id.OPEN:
			return "영업 중"
		GamePhases.Id.CLOSING:
			return "마감 중"
		_:
			return GamePhases.label_for(phase)


func scaled_delta(delta: float) -> float:
	return delta * time_scale if is_simulation_active() else 0.0


func set_time_paused(paused: bool) -> void:
	if time_paused == paused:
		return
	time_paused = paused
	EventBus.game_time_pause_changed.emit(paused)


func toggle_time_paused() -> void:
	set_time_paused(not time_paused)


func set_time_scale(scale: float) -> void:
	var next_scale: float = clampf(scale, 1.0, MAX_TIME_SCALE)
	var changed: bool = not is_equal_approx(time_scale, next_scale)
	time_scale = next_scale
	if time_paused and is_service_time_phase():
		set_time_paused(false)
	if changed:
		EventBus.game_time_speed_changed.emit(time_scale)


func set_phase(next_phase: GamePhases.Id) -> void:
	if phase == next_phase:
		return
	var previous_phase: GamePhases.Id = phase
	phase = next_phase
	EventBus.service_phase_changed.emit(previous_phase, next_phase)


func _unhandled_input(event: InputEvent) -> void:
	if not is_service_time_phase():
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_1:
				set_time_scale(1.0)
				get_viewport().set_input_as_handled()
			KEY_2:
				set_time_scale(2.0)
				get_viewport().set_input_as_handled()
			KEY_3:
				set_time_scale(3.0)
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				toggle_time_paused()
				get_viewport().set_input_as_handled()


func request_morning_briefing() -> void:
	# Deprecated: PRE_OPEN uses HUD [영업시작] instead.
	pass


func start_open_day() -> bool:
	if phase != GamePhases.Id.PRE_OPEN:
		return false
	MarketService.try_settle_pending()
	set_phase(GamePhases.Id.OPEN)
	time_paused = false
	time_scale = 1.0
	GameClock.begin_open_day()
	DayStatsService.begin_day()
	EventBus.day_started.emit(current_day)
	return true


func start_day() -> void:
	start_open_day()


func end_day() -> void:
	if phase == GamePhases.Id.OPEN:
		set_time_paused(false)
		GameClock.begin_closing(true)
		return
	if phase == GamePhases.Id.CLOSING:
		GameClock.skip_remaining_closing_time()


func finish_closing_day() -> void:
	if phase != GamePhases.Id.CLOSING:
		return
	set_phase(GamePhases.Id.SETTLEMENT)
	time_paused = true
	time_scale = 1.0
	var summary: Dictionary = _run_day_settlement(current_day)
	if EconomyManager.is_bankrupt():
		set_phase(GamePhases.Id.GAME_OVER)
		EventBus.game_over.emit("보유 금액이 3일 이상 0골드 미만입니다. 여관이 문을 닫았습니다.")
	EventBus.day_settlement_requested.emit(current_day, summary)


func confirm_day_closed() -> void:
	if phase != GamePhases.Id.SETTLEMENT:
		return
	GameClock.apply_scheduled_to_active()
	current_day += 1
	set_phase(GamePhases.Id.PRE_OPEN)
	time_paused = true


func complete_continuous_day() -> void:
	pass


func _run_day_settlement(ended_day: int) -> Dictionary:
	CustomerService.on_day_ending()
	var summary: Dictionary = EconomyManager.end_of_day_settlement(ended_day)
	summary.merge(DayStatsService.build_summary())
	EventBus.day_ended.emit(ended_day, summary)
	return summary


func export_save_data() -> Dictionary:
	return {
		"current_day": current_day,
		"phase": phase,
		"time_paused": time_paused,
		"time_scale": time_scale,
	}


func import_save_data(data: Dictionary, save_version: int = 7) -> void:
	current_day = data.get("current_day", 1)
	phase = GamePhases.migrate_saved_phase(int(data.get("phase", GamePhases.Id.PRE_OPEN)), save_version)
	time_paused = bool(data.get("time_paused", phase == GamePhases.Id.PRE_OPEN))
	time_scale = clampf(float(data.get("time_scale", 1.0)), 1.0, MAX_TIME_SCALE)
