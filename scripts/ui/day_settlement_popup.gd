extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $Panel/MarginContainer/VBoxContainer/SummaryLabel
@onready var warning_label: Label = $Panel/MarginContainer/VBoxContainer/WarningLabel
@onready var confirm_button: Button = $Panel/MarginContainer/VBoxContainer/ConfirmButton


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_button.pressed.connect(_on_confirm_pressed)
	EventBus.day_settlement_requested.connect(_on_settlement_requested)
	EventBus.game_over.connect(_on_game_over)


func _on_settlement_requested(ended_day: int, summary: Dictionary) -> void:
	_refresh(ended_day, summary, false)
	show()


func _on_game_over(reason: String) -> void:
	if GameTimeManager.phase != GamePhases.Id.GAME_OVER:
		return
	if visible:
		warning_label.text = reason
		warning_label.show()
		confirm_button.disabled = true


func _on_confirm_pressed() -> void:
	if GameTimeManager.phase != GamePhases.Id.SETTLEMENT:
		return
	hide()
	GameTimeManager.confirm_day_closed()


func _refresh(ended_day: int, summary: Dictionary, _game_over: bool) -> void:
	var is_game_over: bool = GameTimeManager.phase == GamePhases.Id.GAME_OVER
	title_label.text = "일일 정산 — %s" % _calendar_label_for_day(ended_day)
	var income: int = int(summary.get("income", 0))
	var expenses: int = int(summary.get("expenses", 0))
	var profit: int = int(summary.get("profit", 0))
	var profit_text: String = "+%d" % profit if profit >= 0 else str(profit)
	var food_delta: int = int(summary.get("food_delta", 0))
	var food_delta_text: String = "+%d" % food_delta if food_delta >= 0 else str(food_delta)
	var exit_lines: String = CustomerExitReasons.format_summary_lines(
		summary.get("exit_reason_counts", {})
	)
	var template: String = (
		"매출: %d골드\n"
		+ "지출: %d골드\n"
		+ "순이익: %s골드\n\n"
		+ "식재료: %s (보유 %d)\n\n"
		+ "손님: %d명 · 식사: %d · 숙박: %d\n\n"
		+ "퇴장 사유:\n%s"
	)
	summary_label.text = template % [
		income,
		expenses,
		profit_text,
		food_delta_text,
		int(summary.get("food_end", FoodStorage.food)),
		int(summary.get("guests_total", 0)),
		int(summary.get("meals_served", 0)),
		int(summary.get("lodgings_served", 0)),
		exit_lines,
	]
	var warning_text: String = ""
	if EconomyManager.is_warning_week():
		warning_text = "경고: 보유 금액이 0골드 미만입니다 (%d/3일)." % EconomyManager.negative_gold_days
	if is_game_over:
		warning_text = "보유 금액이 3일 이상 0골드 미만입니다. 여관이 문을 닫았습니다."
	if warning_text.is_empty():
		warning_label.hide()
	else:
		warning_label.text = warning_text
		warning_label.show()
	confirm_button.disabled = is_game_over
	confirm_button.text = "영업 종료"


func _calendar_label_for_day(day: int) -> String:
	var day_index: int = maxi(day - 1, 0)
	var year: int = GameTimeManager.START_YEAR + int(day_index / GameTimeManager.DAYS_PER_YEAR)
	var season: String = GameTimeManager.SEASON_LABELS[
		int((day_index % GameTimeManager.DAYS_PER_YEAR) / GameTimeManager.DAYS_PER_SEASON)
	]
	var season_day: int = int(day_index % GameTimeManager.DAYS_PER_SEASON) + 1
	return "%d년 %s %d일" % [year, season, season_day]
