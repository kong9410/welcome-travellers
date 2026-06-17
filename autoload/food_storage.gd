extends Node

const STARTING_FOOD: int = 100

var food: int = STARTING_FOOD


func reset_to_defaults() -> void:
	food = STARTING_FOOD
	EventBus.food_changed.emit(food)


func add_food(amount: int) -> void:
	if amount <= 0:
		return
	food += amount
	EventBus.food_changed.emit(food)


func can_consume(amount: int) -> bool:
	return amount <= 0 or food >= amount


func consume_food(amount: int) -> bool:
	if amount <= 0:
		return true
	if food < amount:
		return false
	food -= amount
	EventBus.food_changed.emit(food)
	return true


func export_save_data() -> Dictionary:
	return {"food": food}


func import_save_data(data: Dictionary) -> void:
	food = int(data.get("food", STARTING_FOOD))
	EventBus.food_changed.emit(food)
