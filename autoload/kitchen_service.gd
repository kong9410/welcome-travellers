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
	return _cooking.size() < MAX_PORTIONS and not _pending.is_empty()


func peek_pending_customer() -> CustomerEntity:
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
			pending_entries.append("#%d %s" % [pending_entries.size() + 1, customer.customer_id])
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


func start_cooking(customer: CustomerEntity) -> bool:
	if customer == null or not is_instance_valid(customer):
		return false
	if _cooking.size() >= MAX_PORTIONS:
		return false
	_pending.erase(customer)
	_cooking.append({
		"customer": customer,
		"remaining": COOK_DURATION,
	})
	return true


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


func _process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		return
	if _cooking.is_empty():
		return

	var finished: Array[CustomerEntity] = []

	for entry: Dictionary in _cooking:
		var remaining: float = float(entry.get("remaining", 0.0)) - delta
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
		if customer not in _ready:
			_ready.append(customer)
		StaffService.on_kitchen_order_ready()


func _is_customer_cooking(customer: CustomerEntity) -> bool:
	for entry: Dictionary in _cooking:
		if entry.get("customer") == customer:
			return true
	return false
