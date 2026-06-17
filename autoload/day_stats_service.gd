extends Node

var food_start: int = 0
var guests_total: int = 0
var meals_served: int = 0
var lodgings_served: int = 0
var exit_reason_counts: Dictionary = {}


func begin_day() -> void:
	food_start = FoodStorage.food
	guests_total = 0
	meals_served = 0
	lodgings_served = 0
	exit_reason_counts.clear()


func record_guest() -> void:
	guests_total += 1


func record_meal() -> void:
	meals_served += 1


func record_lodging() -> void:
	lodgings_served += 1


func record_exit_reason(reason: String) -> void:
	var key: String = reason.strip_edges()
	if key.is_empty():
		key = "알 수 없음"
	exit_reason_counts[key] = int(exit_reason_counts.get(key, 0)) + 1


func build_summary() -> Dictionary:
	return {
		"guests_total": guests_total,
		"meals_served": meals_served,
		"lodgings_served": lodgings_served,
		"food_start": food_start,
		"food_end": FoodStorage.food,
		"food_delta": FoodStorage.food - food_start,
		"exit_reason_counts": exit_reason_counts.duplicate(),
	}
