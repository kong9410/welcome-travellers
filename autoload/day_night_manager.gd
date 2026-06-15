extends Node

var current_period: DayPeriods.Id = DayPeriods.Id.DAY


func _ready() -> void:
	set_period(DayPeriods.Id.DAY, false)


func set_period(period: DayPeriods.Id, emit_signal: bool = true) -> void:
	if period == current_period and emit_signal:
		return
	var previous_period: DayPeriods.Id = current_period
	current_period = period
	if emit_signal:
		EventBus.day_period_changed.emit(previous_period, current_period)


func toggle_period() -> void:
	if current_period == DayPeriods.Id.DAY:
		set_period(DayPeriods.Id.NIGHT)
	else:
		set_period(DayPeriods.Id.DAY)


func is_day() -> bool:
	return current_period == DayPeriods.Id.DAY


func is_night() -> bool:
	return current_period == DayPeriods.Id.NIGHT
