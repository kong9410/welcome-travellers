extends Node

const STARTING_GOLD: int = 320
const STARTING_LOAN: int = 200
const LOAN_INTEREST_RATE: float = 0.05
const DAILY_UPKEEP: int = 8
const BANKRUPT_NEGATIVE_GOLD_DAYS: int = 3

var gold: int = STARTING_GOLD
var loan_balance: int = STARTING_LOAN
var daily_income: int = 0
var daily_expenses: int = 0
var negative_gold_days: int = 0
var last_day_profit: int = 0


func _ready() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	gold = STARTING_GOLD
	loan_balance = STARTING_LOAN
	daily_income = 0
	daily_expenses = 0
	negative_gold_days = 0
	last_day_profit = 0


func record_sale(amount: int) -> void:
	if amount <= 0:
		return
	daily_income += amount
	gold += amount
	EventBus.economy_changed.emit()


func record_expense(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	daily_expenses += amount
	gold -= amount
	EventBus.economy_changed.emit()


func end_of_day_settlement(day: int) -> Dictionary:
	record_expense(DAILY_UPKEEP, "daily_upkeep")
	var interest: int = 0
	if loan_balance > 0:
		interest = int(ceil(float(loan_balance) * LOAN_INTEREST_RATE))
		if interest > 0:
			record_expense(interest, "loan_interest")

	var profit: int = daily_income - daily_expenses
	last_day_profit = profit
	if gold < 0:
		negative_gold_days += 1
	else:
		negative_gold_days = 0

	var summary := {
		"day": day,
		"income": daily_income,
		"expenses": daily_expenses,
		"profit": profit,
		"gold": gold,
		"interest_paid": interest if loan_balance > 0 else 0,
		"negative_gold_days": negative_gold_days,
	}

	daily_income = 0
	daily_expenses = 0
	EventBus.economy_changed.emit()
	EventBus.day_settled.emit(summary)
	return summary


func is_bankrupt() -> bool:
	return gold < 0 and negative_gold_days >= BANKRUPT_NEGATIVE_GOLD_DAYS


func is_warning_week() -> bool:
	return gold < 0 and negative_gold_days > 0


func export_save_data() -> Dictionary:
	return {
		"gold": gold,
		"loan_balance": loan_balance,
		"daily_income": daily_income,
		"daily_expenses": daily_expenses,
		"negative_gold_days": negative_gold_days,
		"last_day_profit": last_day_profit,
	}


func import_save_data(data: Dictionary) -> void:
	gold = data.get("gold", STARTING_GOLD)
	loan_balance = data.get("loan_balance", STARTING_LOAN)
	daily_income = data.get("daily_income", 0)
	daily_expenses = data.get("daily_expenses", 0)
	negative_gold_days = data.get("negative_gold_days", data.get("consecutive_loss_days", 0))
	last_day_profit = data.get("last_day_profit", 0)
	EventBus.economy_changed.emit()
