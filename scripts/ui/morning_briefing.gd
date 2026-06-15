extends Control

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var summary_label: Label = $Panel/MarginContainer/VBoxContainer/SummaryLabel
@onready var reviews_label: Label = $Panel/MarginContainer/VBoxContainer/ReviewsLabel
@onready var start_button: Button = $Panel/MarginContainer/VBoxContainer/StartButton


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	start_button.pressed.connect(_on_start_pressed)
	EventBus.morning_briefing_requested.connect(_on_briefing_requested)
	EventBus.game_over.connect(_on_game_over)
	EventBus.economy_changed.connect(_refresh_labels)
	EventBus.reputation_changed.connect(_refresh_labels)
	EventBus.day_settled.connect(_on_day_settled)


func _on_briefing_requested(_day: int) -> void:
	_refresh_labels()
	show()
	start_button.disabled = false
	start_button.text = "Open Inn (Start Day %d)" % GameTimeManager.current_day


func _on_day_settled(summary: Dictionary) -> void:
	var profit: int = summary.get("profit", 0)
	var profit_text: String = "+%d" % profit if profit >= 0 else str(profit)
	summary_label.text = (
		"Yesterday profit: %s gold\nGuests served, books closed for the night."
		% profit_text
	)


func _on_game_over(reason: String) -> void:
	show()
	start_button.disabled = true
	summary_label.text = reason


func _on_start_pressed() -> void:
	hide()
	GameTimeManager.start_day()


func _refresh_labels(_unused = null) -> void:
	title_label.text = "Morning Briefing — Day %d" % GameTimeManager.current_day
	var period_label: String = DayPeriods.label_for(DayNightManager.current_period)
	var warning_text: String = ""
	if EconomyManager.is_warning_week():
		warning_text = "\nWarning: losses are stacking (%d days)." % EconomyManager.consecutive_loss_days
	if not InnLayoutHelper.has_service_space(ViewIds.Id.INN_F1):
		warning_text += "\nTip: paint Floor from the door inward so guests can enter and sit."

	summary_label.text = (
		"Gold: %d | Loan: %d | Rating: %.1f\nPeriod: %s | Shift: 08:00-22:00 | Upkeep: %d/day | Interest: %.0f%%%s"
		% [
			EconomyManager.gold,
			EconomyManager.loan_balance,
			ReputationManager.average_rating,
			period_label,
			EconomyManager.DAILY_UPKEEP,
			EconomyManager.LOAN_INTEREST_RATE * 100.0,
			warning_text,
		]
	)

	var review_lines: PackedStringArray = PackedStringArray()
	for review: Dictionary in ReputationManager.recent_reviews:
		review_lines.append(
			"- %.1f %s: %s" % [
				review.get("rating", 0.0),
				review.get("guest_name", "Guest"),
				review.get("comment", ""),
			]
		)
	if review_lines.is_empty():
		reviews_label.text = "Recent reviews: none yet."
	else:
		reviews_label.text = "Recent reviews:\n" + "\n".join(review_lines)
