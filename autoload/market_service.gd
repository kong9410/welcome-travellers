extends Node

const GRAIN_BATCH_SIZE: int = MarketConstants.GRAIN_BATCH_SIZE
const GRAIN_BATCH_PRICE: int = MarketConstants.GRAIN_BATCH_PRICE

var pending_orders: Array[Dictionary] = []
var _next_order_id: int = 1


var pending_grain: int:
	get:
		return _sum_pending_grain()


func _sum_pending_grain() -> int:
	var total: int = 0
	for order: Dictionary in pending_orders:
		total += int(order.get("grain", 0))
	return total


func is_valid_grain_amount(grain_amount: int) -> bool:
	return grain_amount > 0 and grain_amount % GRAIN_BATCH_SIZE == 0


func get_order_price(grain_amount: int) -> int:
	if not is_valid_grain_amount(grain_amount):
		return 0
	return int(grain_amount / GRAIN_BATCH_SIZE) * GRAIN_BATCH_PRICE


func get_pending_cost() -> int:
	return get_order_price(pending_grain)


func has_pending_orders() -> bool:
	return not pending_orders.is_empty()


func has_unaffordable_pending() -> bool:
	return has_pending_orders() and EconomyManager.gold < get_pending_cost()


func get_pending_orders() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for order: Dictionary in pending_orders:
		copies.append(order.duplicate())
	return copies


func place_grain_order(grain_amount: int) -> bool:
	if not is_valid_grain_amount(grain_amount):
		return false
	pending_orders.append({
		"id": _next_order_id,
		"grain": grain_amount,
	})
	_next_order_id += 1
	_emit_pending_changed()
	return true


func update_order(order_id: int, grain_amount: int) -> bool:
	if not is_valid_grain_amount(grain_amount):
		return false
	for order: Dictionary in pending_orders:
		if int(order.get("id", -1)) == order_id:
			order["grain"] = grain_amount
			_emit_pending_changed()
			return true
	return false


func cancel_order(order_id: int) -> bool:
	for index: int in range(pending_orders.size()):
		var order: Dictionary = pending_orders[index]
		if int(order.get("id", -1)) != order_id:
			continue
		var cancelled_grain: int = int(order.get("grain", 0))
		pending_orders.remove_at(index)
		_emit_pending_changed()
		if cancelled_grain > 0:
			EventBus.market_orders_cancelled.emit(cancelled_grain, "manual")
		return true
	return false


func try_settle_pending() -> void:
	if pending_grain <= 0:
		return
	var price: int = get_pending_cost()
	if EconomyManager.gold < price:
		cancel_pending_orders("insufficient_gold")
		return
	EconomyManager.record_expense(price, "market_grain")
	var amount: int = pending_grain
	pending_orders.clear()
	FoodStorage.add_food(amount)
	_emit_pending_changed()
	EventBus.market_delivered.emit(amount)


func cancel_pending_orders(reason: String = "") -> int:
	if pending_grain <= 0:
		return 0
	var cancelled: int = pending_grain
	pending_orders.clear()
	_emit_pending_changed()
	EventBus.market_orders_cancelled.emit(cancelled, reason)
	return cancelled


func reset_to_defaults() -> void:
	pending_orders.clear()
	_next_order_id = 1
	_emit_pending_changed()


func export_save_data() -> Dictionary:
	var orders_data: Array = []
	for order: Dictionary in pending_orders:
		orders_data.append(order.duplicate())
	return {
		"orders": orders_data,
		"next_order_id": _next_order_id,
	}


func import_save_data(data: Dictionary) -> void:
	pending_orders.clear()
	if data.has("orders"):
		for raw_order: Variant in data.get("orders", []):
			if typeof(raw_order) != TYPE_DICTIONARY:
				continue
			var grain: int = int(raw_order.get("grain", 0))
			if not is_valid_grain_amount(grain):
				continue
			pending_orders.append({
				"id": int(raw_order.get("id", _next_order_id)),
				"grain": grain,
			})
			_next_order_id = maxi(_next_order_id, int(raw_order.get("id", 0)) + 1)
	else:
		var legacy_grain: int = int(data.get("pending_grain", 0))
		if is_valid_grain_amount(legacy_grain):
			pending_orders.append({"id": _next_order_id, "grain": legacy_grain})
			_next_order_id += 1
	_emit_pending_changed()


func _emit_pending_changed() -> void:
	EventBus.market_pending_changed.emit(pending_grain)
