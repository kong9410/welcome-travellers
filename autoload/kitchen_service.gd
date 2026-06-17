extends Node

const MAX_PORTIONS: int = 4
const COOK_DURATION: float = 4.0

var _pending: Array[CustomerEntity] = []
var _cooking: Array[Dictionary] = []
var _ready: Array[CustomerEntity] = []


func reset_all() -> void:
	_pending.clear()
	_cooking.clear()
	_ready.clear()


func enqueue_pending(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer in _pending or _is_customer_cooking(customer) or customer in _ready:
		return
	_pending.append(customer)


func has_pending() -> bool:
	return not _pending.is_empty()


func has_food_workload() -> bool:
	return not _pending.is_empty() or not _cooking.is_empty() or not _ready.is_empty()


func has_customer_order(customer: CustomerEntity) -> bool:
	if customer == null:
		return false
	if customer in _pending or customer in _ready:
		return true
	return _is_customer_cooking(customer)


func has_ready_orders() -> bool:
	return not _ready.is_empty()


func has_active_cooking() -> bool:
	return not _cooking.is_empty() or not _pending.is_empty()


func has_cook_queue() -> bool:
	return has_active_cooking()


func has_serve_queue() -> bool:
	return has_ready_orders()


func has_cooking_in_progress() -> bool:
	return not _cooking.is_empty()


func can_start_cooking() -> bool:
	if _cooking.size() >= MAX_PORTIONS or _pending.is_empty():
		return false
	_drop_uncookable_pending_orders()
	if _pending.is_empty():
		return false
	var customer: CustomerEntity = peek_pending_customer()
	return customer != null and can_cook_order(customer)


func can_cook_order(customer: CustomerEntity) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	return FoodStorage.can_consume(get_ingredient_cost(customer))


func peek_pending_customer() -> CustomerEntity:
	_drop_invalid_pending_orders()
	if _pending.is_empty():
		return null
	return _pending[0]


func peek_ready_customer() -> CustomerEntity:
	if _ready.is_empty():
		return null
	return _ready[0]


func get_queue_counts() -> Dictionary:
	return {
		"pending": _pending.size(),
		"cooking": _cooking.size(),
		"ready": _ready.size(),
	}


func get_debug_queue_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var pending_entries: PackedStringArray = []
	for index in range(_pending.size()):
		var customer = _pending[index]
		if is_instance_valid(customer):
			pending_entries.append("#%d %s · 식재료 %d" % [
				pending_entries.size() + 1,
				customer.customer_id,
				get_ingredient_cost(customer),
			])
	lines.append("조리 대기 (%d)" % pending_entries.size())
	if pending_entries.is_empty():
		lines.append("  (비어 있음)")
	else:
		for entry: String in pending_entries:
			lines.append("  %s" % entry)

	var cooking_entries: PackedStringArray = []
	for index in range(_cooking.size()):
		var entry: Dictionary = _cooking[index]
		var customer = entry.get("customer")
		if not is_instance_valid(customer):
			continue
		var remaining: float = float(entry.get("remaining", 0.0))
		cooking_entries.append("#%d %s · %.1fs" % [cooking_entries.size() + 1, customer.customer_id, remaining])
	lines.append("조리 중 (%d)" % cooking_entries.size())
	if cooking_entries.is_empty():
		lines.append("  (비어 있음)")
	else:
		for entry: String in cooking_entries:
			lines.append("  %s" % entry)

	var serve_entries: PackedStringArray = []
	for index in range(_ready.size()):
		var customer = _ready[index]
		if is_instance_valid(customer):
			serve_entries.append("#%d %s" % [serve_entries.size() + 1, customer.customer_id])
	lines.append("서빙 큐 (%d)" % serve_entries.size())
	if serve_entries.is_empty():
		lines.append("  (비어 있음)")
	else:
		for entry: String in serve_entries:
			lines.append("  %s" % entry)

	return lines


func get_primary_cooking_customer() -> CustomerEntity:
	if _cooking.is_empty():
		return null
	var customer = _cooking[0].get("customer")
	if is_instance_valid(customer):
		return customer
	return null


func start_cooking(customer: CustomerEntity) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	if _cooking.size() >= MAX_PORTIONS:
		return false
	var ingredient_cost: int = get_ingredient_cost(customer)
	if not FoodStorage.consume_food(ingredient_cost):
		_cancel_pending_customer_for_missing_ingredients(customer)
		return false
	_pending.erase(customer)
	_cooking.append({
		"customer": customer,
		"remaining": COOK_DURATION,
	})
	return true


func get_ingredient_cost(customer: CustomerEntity) -> int:
	if customer == null or not is_instance_valid(customer):
		return 0
	return int(customer.order.get("ingredient_cost", 1))


func get_serve_position(customer: CustomerEntity) -> Vector2:
	if customer == null:
		return Vector2.ZERO
	return InnLayoutHelper.get_table_serve_position(
		customer.view_id,
		customer.chair_instance_id
	)


func get_cooking_count() -> int:
	return _cooking.size()


func pop_ready_customer(customer: CustomerEntity = null) -> CustomerEntity:
	if _ready.is_empty():
		return null
	if customer != null:
		var index: int = _ready.find(customer)
		if index >= 0:
			return _ready.pop_at(index)
	return _ready.pop_front()


func release_customer(customer: CustomerEntity) -> void:
	if customer == null:
		return
	_pending.erase(customer)
	_ready.erase(customer)
	for i in range(_cooking.size() - 1, -1, -1):
		var entry: Dictionary = _cooking[i]
		if entry.get("customer") == customer:
			_cooking.remove_at(i)


func _drop_invalid_pending_orders() -> void:
	for index in range(_pending.size() - 1, -1, -1):
		if not is_instance_valid(_pending[index]):
			_pending.remove_at(index)


func _drop_uncookable_pending_orders() -> void:
	_drop_invalid_pending_orders()
	for index in range(_pending.size() - 1, -1, -1):
		var customer: CustomerEntity = _pending[index]
		if can_cook_order(customer):
			continue
		_cancel_pending_customer_for_missing_ingredients(customer)


func _cancel_pending_customer_for_missing_ingredients(customer: CustomerEntity) -> void:
	if customer == null:
		return
	_pending.erase(customer)
	_ready.erase(customer)
	for index in range(_cooking.size() - 1, -1, -1):
		if (_cooking[index] as Dictionary).get("customer") == customer:
			_cooking.remove_at(index)
	if is_instance_valid(customer):
		customer.on_order_rejected("식재료가 부족합니다.")
		CustomerService.release_customer(customer)


func _process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		return
	if _cooking.is_empty():
		return

	var scaled_delta: float = GameTimeManager.scaled_delta(delta)
	var finished: Array[CustomerEntity] = []

	for entry: Dictionary in _cooking:
		var remaining: float = float(entry.get("remaining", 0.0)) - scaled_delta
		entry["remaining"] = remaining
		if remaining > 0.0:
			continue
		var customer = entry.get("customer")
		if customer == null or not is_instance_valid(customer):
			continue
		if customer in finished:
			continue
		finished.append(customer)

	for customer: CustomerEntity in finished:
		for index in range(_cooking.size() - 1, -1, -1):
			if (_cooking[index] as Dictionary).get("customer") == customer:
				_cooking.remove_at(index)
		_resolve_food_quality(customer)
		if customer not in _ready:
			_ready.append(customer)
		StaffService.on_kitchen_order_ready()


func _is_customer_cooking(customer: CustomerEntity) -> bool:
	for entry: Dictionary in _cooking:
		if entry.get("customer") == customer:
			return true
	return false


func _resolve_food_quality(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.order.has("quality"):
		return
	var cooking_level: int = 1
	var innkeeper: InnkeeperEntity = StaffService.get_innkeeper()
	if is_instance_valid(innkeeper):
		cooking_level = innkeeper.cooking_level
		customer.order["maker_id"] = innkeeper.staff_id
		customer.order["maker_label"] = "여관주인"
		customer.order["maker_cooking_level"] = cooking_level
		innkeeper.add_cooking_experience()
	customer.order["quality"] = FoodQualityResolver.roll_quality(
		customer.order,
		cooking_level
	)
