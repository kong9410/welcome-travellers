extends Node

const CUSTOMER_SCENE: PackedScene = preload("res://scenes/entities/customer_entity.tscn")
const MAX_PATH_BUILDS_PER_FRAME: int = 8
const MAX_OUTSIDE_QUEUE_SIZE: int = 6

var _customers: Dictionary = {}
var _next_customer_number: int = 1
var _next_outside_customer_number: int = 1
var _spawn_timer: Timer
var _counter_queue: Array[CustomerEntity] = []
var _outside_queue: Array[OutsideCustomerEntity] = []
var _entering_outside_customer: OutsideCustomerEntity = null
var _furniture_reservations: Dictionary = {}
var _path_build_queue: Array[Dictionary] = []
var _pending_activations: Array[CustomerEntity] = []
var _layout_refresh_pending: bool = false
var selected_customer: CustomerEntity = null


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	_spawn_timer.timeout.connect(_try_spawn_customer)
	add_child(_spawn_timer)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.furniture_placed.connect(_on_layout_changed)
	EventBus.furniture_removed.connect(_on_layout_changed)
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)


func _process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		return
	_drain_path_build_queue()
	for customer: CustomerEntity in get_active_customers():
		if is_instance_valid(customer):
			customer.tick_needs(delta)


func enqueue_path_build(customer: CustomerEntity, world_position: Vector2, token: int) -> void:
	if customer == null or not is_instance_valid(customer) or customer.customer_id == "":
		return
	for index in range(_path_build_queue.size() - 1, -1, -1):
		var pending: Dictionary = _path_build_queue[index]
		if pending.get("customer_id", "") == customer.customer_id:
			_path_build_queue.remove_at(index)
	_path_build_queue.append({
		"customer_id": customer.customer_id,
		"world_position": world_position,
		"token": token,
	})


func request_activation(customer: CustomerEntity) -> void:
	if customer == null or customer in _pending_activations:
		return
	_pending_activations.append(customer)
	if _pending_activations.size() == 1:
		call_deferred("_activate_next_customer")


func _activate_next_customer() -> void:
	while not _pending_activations.is_empty():
		var customer = _pending_activations.pop_front()
		if not is_instance_valid(customer):
			continue
		customer.activate()
		break
	if not _pending_activations.is_empty():
		call_deferred("_activate_next_customer")


func _drain_path_build_queue() -> void:
	var processed: int = 0
	while processed < MAX_PATH_BUILDS_PER_FRAME and not _path_build_queue.is_empty():
		var request: Dictionary = _path_build_queue.pop_front()
		var customer_id: String = request.get("customer_id", "")
		if customer_id == "" or not _customers.has(customer_id):
			continue
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			_customers.erase(customer_id)
			continue
		customer.build_floor_path(
			request.get("world_position", Vector2.ZERO),
			int(request.get("token", -1))
		)
		processed += 1


func despawn_all() -> void:
	clear_customer_selection()
	_path_build_queue.clear()
	_pending_activations.clear()
	for outside_customer: OutsideCustomerEntity in _outside_queue:
		if is_instance_valid(outside_customer):
			outside_customer.queue_free()
	_outside_queue.clear()
	if is_instance_valid(_entering_outside_customer):
		_entering_outside_customer.queue_free()
	_entering_outside_customer = null
	for customer_id: String in _customers.keys():
		_release_customer_reservations(customer_id)
		var customer = _customers[customer_id]
		if is_instance_valid(customer):
			customer.queue_free()
	_customers.clear()
	_counter_queue.clear()
	_furniture_reservations.clear()
	_next_outside_customer_number = 1
	KitchenService.reset_all()
	TableFoodService.reset_all()


func get_active_count() -> int:
	return _customers.size()


func try_select_at(world_position: Vector2, view_id: ViewIds.Id) -> bool:
	var customer: CustomerEntity = _find_customer_at(view_id, world_position)
	if customer != null:
		select_customer(customer)
		return true
	clear_customer_selection()
	return false


func select_customer(customer: CustomerEntity) -> void:
	if selected_customer == customer:
		return
	clear_customer_selection()
	selected_customer = customer
	if selected_customer:
		selected_customer.set_selected(true)
		EventBus.customer_selected.emit(selected_customer)


func clear_customer_selection() -> void:
	if selected_customer and is_instance_valid(selected_customer):
		selected_customer.set_selected(false)
	selected_customer = null
	EventBus.customer_selected.emit(null)


func _find_customer_at(view_id: ViewIds.Id, world_position: Vector2) -> CustomerEntity:
	var closest_customer: CustomerEntity = null
	var closest_distance: float = INF
	for customer: CustomerEntity in get_active_customers():
		if not is_instance_valid(customer) or customer.view_id != view_id:
			continue
		if not customer.contains_world_point(world_position):
			continue
		var distance: float = customer.global_position.distance_to(world_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_customer = customer
	return closest_customer


func get_active_customers() -> Array[CustomerEntity]:
	var result: Array[CustomerEntity] = []
	for index in range(_counter_queue.size()):
		var customer = _counter_queue[index]
		if is_instance_valid(customer) and customer not in result:
			result.append(customer)
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer in result:
			continue
		result.append(customer)
	return result


func get_reserved_instance_ids() -> Dictionary:
	return _furniture_reservations.duplicate()


func get_counter_queue_customers() -> Array[CustomerEntity]:
	var result: Array[CustomerEntity] = []
	for index in range(_counter_queue.size()):
		var customer = _counter_queue[index]
		if is_instance_valid(customer):
			result.append(customer)
	return result


func get_outside_queue_customers() -> Array[OutsideCustomerEntity]:
	_purge_invalid_outside_queue_entries()
	var result: Array[OutsideCustomerEntity] = []
	for outside_customer: OutsideCustomerEntity in _outside_queue:
		if is_instance_valid(outside_customer):
			result.append(outside_customer)
	return result


func get_player_queue_summary() -> String:
	var queue_customers: Array[CustomerEntity] = get_counter_queue_customers()
	var outside_count: int = get_outside_queue_customers().size()
	var entering_count: int = 1 if is_instance_valid(_entering_outside_customer) else 0
	if queue_customers.is_empty() and outside_count == 0 and entering_count == 0:
		return "대기 줄: 없음"
	if queue_customers.is_empty():
		return "야외 줄: %d명 · 입장중: %d명" % [outside_count, entering_count]
	var front: CustomerEntity = queue_customers[0]
	var front_label: String = CustomerStates.label_for(front.current_state)
	if queue_customers.size() == 1:
		return "야외 줄: %d명 · 입장중: %d명 · 카운터: 1명 (%s)" % [outside_count, entering_count, front_label]
	return "야외 줄: %d명 · 입장중: %d명 · 카운터: %d명 (앞: %s)" % [outside_count, entering_count, queue_customers.size(), front_label]


func sync_debug_visuals() -> void:
	for customer: CustomerEntity in get_active_customers():
		if is_instance_valid(customer):
			customer.sync_debug_visuals()


func get_debug_queue_status_text() -> String:
	if not DebugService.is_active():
		return ""

	var lines: PackedStringArray = []
	var outside_customers: Array[OutsideCustomerEntity] = get_outside_queue_customers()
	var entering_text: String = (
		_entering_outside_customer.customer_id
		if is_instance_valid(_entering_outside_customer)
		else "없음"
	)
	lines.append("야외 줄 (%d명, 입장중: %s)" % [outside_customers.size(), entering_text])
	if outside_customers.is_empty():
		lines.append("  (비어 있음)")
	else:
		for index in range(outside_customers.size()):
			var outside_customer: OutsideCustomerEntity = outside_customers[index]
			var state_text: String = "이동중" if outside_customer.is_moving else "대기"
			lines.append("  #%d %s · %s" % [index + 1, outside_customer.customer_id, state_text])

	var queue_customers: Array[CustomerEntity] = get_counter_queue_customers()
	lines.append("카운터 줄 (%d명)" % queue_customers.size())

	if queue_customers.is_empty():
		lines.append("  (비어 있음)")
	else:
		for index in range(queue_customers.size()):
			var customer: CustomerEntity = queue_customers[index]
			var detail: String = _format_counter_queue_entry(index, customer)
			lines.append("  %s" % detail)

	lines.append("주방")
	lines.append_array(KitchenService.get_debug_queue_lines())
	return "\n".join(lines)


func _format_counter_queue_entry(index: int, customer: CustomerEntity) -> String:
	var state_label: String = CustomerStates.label_for(customer.current_state)
	var tags: PackedStringArray = []

	if customer.current_state == CustomerStates.Id.TO_COUNTER:
		tags.append("상담석 이동중")
	elif customer.current_state == CustomerStates.Id.REQUEST_PENDING:
		tags.append("요청확인")
	elif CustomerStates.is_queue_walking(customer.current_state):
		if customer.is_at_assigned_queue_slot():
			tags.append("슬롯도착")
		else:
			tags.append("이동중")
	elif customer.current_state == CustomerStates.Id.WAITING_AT_COUNTER:
		if customer.order_taken:
			tags.append("주문접수됨")
		else:
			tags.append("주문대기")
	elif customer.current_state == CustomerStates.Id.WAITING_IN_QUEUE:
		tags.append("대기")

	if index == 0 and _is_front_ready_for_order(customer):
		tags.append("주문가능")

	var suffix: String = ""
	if not tags.is_empty():
		suffix = " [%s]" % ", ".join(tags)
	return "#%d %s · %s%s" % [index + 1, customer.customer_id, state_label, suffix]


func _is_front_ready_for_order(customer: CustomerEntity) -> bool:
	if customer.current_state == CustomerStates.Id.REQUEST_PENDING:
		return not customer.order_taken
	if customer.current_state == CustomerStates.Id.WAITING_AT_COUNTER:
		return not customer.order_taken
	if CustomerStates.is_queue_walking(customer.current_state):
		return customer.is_at_assigned_queue_slot()
	return false


func get_front_customer() -> CustomerEntity:
	_purge_invalid_counter_queue_entries()
	if _counter_queue.is_empty():
		return null
	return _counter_queue[0]


func has_customers_in_counter_queue() -> bool:
	for index in range(_counter_queue.size()):
		if is_instance_valid(_counter_queue[index]):
			return true
	return false


func has_counter_order_work() -> bool:
	return has_pending_counter_service()


func has_pending_counter_service() -> bool:
	for index in range(_counter_queue.size()):
		var customer = _counter_queue[index]
		if not is_instance_valid(customer):
			continue
		if customer.current_state in [
			CustomerStates.Id.REQUEST_PENDING,
			CustomerStates.Id.WAITING_AT_COUNTER,
		]:
			return true
	return false


func get_customer_ready_for_order() -> CustomerEntity:
	var front: CustomerEntity = get_front_customer()
	if front == null or not is_instance_valid(front):
		return null
	if front.current_state == CustomerStates.Id.REQUEST_PENDING:
		return front
	if front.current_state == CustomerStates.Id.WAITING_AT_COUNTER:
		return front
	if CustomerStates.is_queue_walking(front.current_state) and front.is_at_assigned_queue_slot():
		front.promote_to_counter_wait()
		return front
	return null


func has_front_customer_approaching_counter() -> bool:
	var front: CustomerEntity = get_front_customer()
	if front == null or not is_instance_valid(front):
		return false
	return front.current_state == CustomerStates.Id.TO_COUNTER or CustomerStates.is_queue_walking(front.current_state)


func join_counter_queue(customer: CustomerEntity) -> void:
	if customer == null or customer in _counter_queue:
		return
	_counter_queue.append(customer)


func on_customer_request_pending(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer != get_front_customer():
		return
	StaffService.request_take_order(customer)


func unregister_waiting_customer(customer: CustomerEntity) -> void:
	if customer in _counter_queue:
		_counter_queue.erase(customer)
		_try_start_next_outside_admission()


func try_process_counter_queue() -> void:
	if _counter_queue.is_empty():
		return
	var front: CustomerEntity = get_front_customer()
	if front == null or not is_instance_valid(front):
		return
	if front.current_state == CustomerStates.Id.REQUEST_PENDING:
		StaffService.request_take_order(front)
		return
	if front.current_state != CustomerStates.Id.WAITING_AT_COUNTER:
		return
	StaffService.request_take_order(front)


func complete_take_order(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return

	var order_type: CustomerOrderTypes.Id = customer.get_order_type()
	if not _can_fulfill_order(order_type):
		customer.on_order_rejected()
		_remove_from_counter_queue(customer)
		StaffService.schedule_work()
		return

	var chair_data: Dictionary = {}
	var bed_data: Dictionary = {}
	if CustomerOrderTypes.needs_food(order_type):
		chair_data = InnLayoutHelper.find_available_chair(
			customer.view_id,
			_furniture_reservations,
			customer.global_position
		)
		if chair_data.is_empty():
			customer.on_order_rejected()
			_remove_from_counter_queue(customer)
			StaffService.schedule_work()
			return
	if CustomerOrderTypes.needs_lodging(order_type):
		bed_data = InnLayoutHelper.find_available_bed(
			customer.view_id,
			_furniture_reservations,
			customer.global_position
		)
		if bed_data.is_empty():
			customer.on_order_rejected()
			_remove_from_counter_queue(customer)
			StaffService.schedule_work()
			return

	if not chair_data.is_empty():
		_furniture_reservations[chair_data["instance_id"]] = customer.customer_id
	if not bed_data.is_empty():
		_furniture_reservations[bed_data["instance_id"]] = customer.customer_id

	customer.on_order_accepted(
		chair_data.get("position", Vector2.ZERO),
		bed_data.get("position", Vector2.ZERO),
		chair_data.get("instance_id", ""),
		bed_data.get("instance_id", "")
	)

	if CustomerOrderTypes.needs_food(order_type) and order_type != CustomerOrderTypes.Id.FOOD_AND_LODGING:
		KitchenService.enqueue_pending(customer)

	_remove_from_counter_queue(customer)
	StaffService.schedule_work()


func release_customer(customer: CustomerEntity) -> void:
	if customer == null:
		return
	if is_instance_valid(customer):
		_purge_customer_requests(customer.customer_id)
	unregister_waiting_customer(customer)
	KitchenService.release_customer(customer)
	_release_customer_reservations(customer.customer_id)


func _purge_customer_requests(customer_id: String) -> void:
	if customer_id == "":
		return
	for index in range(_path_build_queue.size() - 1, -1, -1):
		if _path_build_queue[index].get("customer_id", "") == customer_id:
			_path_build_queue.remove_at(index)
	for index in range(_pending_activations.size() - 1, -1, -1):
		var pending_customer = _pending_activations[index]
		if not is_instance_valid(pending_customer):
			_pending_activations.remove_at(index)
			continue
		if pending_customer.customer_id == customer_id:
			_pending_activations.remove_at(index)


func checkout_overnight_guests(day: int) -> void:
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer.should_checkout_on_day(day):
			customer.checkout()


func on_day_ending() -> void:
	var customer_ids: Array = _customers.keys()
	for customer_id: String in customer_ids:
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer.should_persist_overnight():
			continue
		release_customer(customer)
		_customers.erase(customer_id)
		customer.queue_free()


func _try_spawn_customer() -> void:
	if not GameTimeManager.is_time_flowing():
		return
	if _get_total_customer_pressure() >= 6:
		return
	if get_outside_queue_customers().size() >= MAX_OUTSIDE_QUEUE_SIZE:
		return
	if not NavService.is_map_synchronized(ViewIds.Id.INN_F1):
		return
	if not InnLayoutHelper.has_service_space(ViewIds.Id.INN_F1):
		return
	if InnLayoutHelper.find_counter_customer_position(ViewIds.Id.INN_F1) == Vector2.ZERO:
		return
	if InnLayoutHelper.find_available_chair(ViewIds.Id.INN_F1, _furniture_reservations).is_empty():
		return
	spawn_outside_customer()


func spawn_outside_customer() -> OutsideCustomerEntity:
	var outside_view: ViewRoot = ViewManager.get_view(ViewIds.Id.OUTSIDE)
	if not (outside_view is OutsideViewRoot):
		return null

	var outside_customer: OutsideCustomerEntity = (outside_view as OutsideViewRoot).spawn_outside_customer_from_edge(
		OutsideViewConstants.outside_queue_position(_outside_queue.size()),
		-1,
		-1
	)
	if outside_customer == null:
		return null

	outside_customer.customer_id = _generate_outside_customer_id()
	outside_customer.name = outside_customer.customer_id
	outside_customer.reached_target.connect(_on_outside_customer_reached_target)
	_outside_queue.append(outside_customer)
	_refresh_outside_queue(maxi(0, _outside_queue.size() - 1))
	_try_start_next_outside_admission()
	return outside_customer


func _refresh_outside_queue(from_index: int = 0) -> void:
	_purge_invalid_outside_queue_entries()
	from_index = clampi(from_index, 0, _outside_queue.size())
	for index in range(from_index, _outside_queue.size()):
		var outside_customer: OutsideCustomerEntity = _outside_queue[index]
		if not is_instance_valid(outside_customer):
			continue
		outside_customer.set_target_position(OutsideViewConstants.outside_queue_position(index))


func _purge_invalid_outside_queue_entries() -> void:
	for index in range(_outside_queue.size() - 1, -1, -1):
		if not is_instance_valid(_outside_queue[index]):
			_outside_queue.remove_at(index)


func _on_outside_customer_reached_target(outside_customer: OutsideCustomerEntity) -> void:
	if outside_customer == _entering_outside_customer:
		_complete_outside_admission(outside_customer)
		return
	_try_start_next_outside_admission()


func _try_start_next_outside_admission() -> void:
	if is_instance_valid(_entering_outside_customer):
		return
	if has_customers_in_counter_queue():
		return

	_purge_invalid_outside_queue_entries()
	if _outside_queue.is_empty():
		return

	var outside_customer: OutsideCustomerEntity = _outside_queue.pop_front()
	if not is_instance_valid(outside_customer):
		_refresh_outside_queue(0)
		call_deferred("_try_start_next_outside_admission")
		return

	_entering_outside_customer = outside_customer
	_refresh_outside_queue(0)
	outside_customer.set_target_position(OutsideViewConstants.inn_door_position())


func _complete_outside_admission(outside_customer: OutsideCustomerEntity) -> void:
	if outside_customer != _entering_outside_customer:
		return

	var persona_id: int = outside_customer.persona
	_entering_outside_customer = null
	if is_instance_valid(outside_customer):
		outside_customer.queue_free()

	var inside_customer: CustomerEntity = spawn_customer(persona_id)
	if inside_customer == null:
		call_deferred("_try_start_next_outside_admission")


func _get_total_customer_pressure() -> int:
	var entering_count: int = 1 if is_instance_valid(_entering_outside_customer) else 0
	return get_active_count() + get_outside_queue_customers().size() + entering_count


func spawn_customer(persona_id: int = -1) -> CustomerEntity:
	var view_id: ViewIds.Id = ViewIds.Id.INN_F1
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return null

	var spawn_position: Vector2 = InnLayoutHelper.find_entry_position(view_id)
	var counter_position: Vector2 = InnLayoutHelper.find_counter_customer_position(view_id)
	var exit_position: Vector2 = InnLayoutHelper.find_exit_position(view_id)
	if spawn_position == Vector2.ZERO or exit_position == Vector2.ZERO or counter_position == Vector2.ZERO:
		return null

	var customer: CustomerEntity = CUSTOMER_SCENE.instantiate() as CustomerEntity
	var customer_id: String = _generate_customer_id()
	customer.name = customer_id
	view.entity_layer.add_child(customer)
	customer.configure(
		customer_id,
		view_id,
		CustomerPersonas.random() if persona_id < 0 else persona_id as CustomerPersonas.Id,
		spawn_position,
		counter_position,
		exit_position
	)
	customer.finished.connect(_on_customer_finished)
	_customers[customer_id] = customer
	join_counter_queue(customer)
	request_activation(customer)
	customer.call_deferred("start_counter_consultation", counter_position)
	call_deferred("_emit_customer_spawned", customer)
	return customer


func _emit_customer_spawned(customer: CustomerEntity) -> void:
	if is_instance_valid(customer):
		EventBus.customer_spawned.emit(customer)


func _on_customer_finished(customer: CustomerEntity) -> void:
	if selected_customer == customer:
		clear_customer_selection()
	release_customer(customer)
	if _customers.has(customer.customer_id):
		_customers.erase(customer.customer_id)
	if is_instance_valid(customer):
		customer.queue_free()


func _on_day_started(day: int) -> void:
	checkout_overnight_guests(day)
	_spawn_timer.wait_time = ReputationManager.get_spawn_interval()
	_spawn_timer.start()
	_try_spawn_customer()


func _on_day_ended(_day: int, _summary: Dictionary) -> void:
	_spawn_timer.stop()
	for outside_customer: OutsideCustomerEntity in _outside_queue:
		if is_instance_valid(outside_customer):
			outside_customer.queue_free()
	_outside_queue.clear()
	if is_instance_valid(_entering_outside_customer):
		_entering_outside_customer.queue_free()
	_entering_outside_customer = null
	KitchenService.reset_all()
	TableFoodService.reset_all()


func _on_view_changed(_previous_view_id: ViewIds.Id, _next_view_id: ViewIds.Id) -> void:
	pass


func _on_layout_changed(_instance: FurnitureInstance = null) -> void:
	_schedule_layout_refresh(ViewIds.Id.INN_F1)


func _on_grid_cell_changed(changed_view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	if changed_view_id != ViewIds.Id.INN_F1:
		return
	_schedule_layout_refresh(changed_view_id)


func _schedule_layout_refresh(view_id: ViewIds.Id) -> void:
	if _layout_refresh_pending:
		return
	_layout_refresh_pending = true
	call_deferred("_deferred_layout_refresh", view_id)


func _deferred_layout_refresh(view_id: ViewIds.Id) -> void:
	_layout_refresh_pending = false
	InnLayoutHelper.invalidate_counter_queue_cache(view_id)
	_restart_moving_customers()


func _restart_moving_customers() -> void:
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if is_instance_valid(customer):
			customer.restart_movement_if_needed()


func _generate_customer_id() -> String:
	var customer_id: String = "guest_%d" % _next_customer_number
	_next_customer_number += 1
	return customer_id


func _generate_outside_customer_id() -> String:
	var customer_id: String = "outside_guest_%d" % _next_outside_customer_number
	_next_outside_customer_number += 1
	return customer_id


func _can_fulfill_order(order_type: CustomerOrderTypes.Id) -> bool:
	if CustomerOrderTypes.needs_food(order_type):
		if InnLayoutHelper.find_available_chair(ViewIds.Id.INN_F1, _furniture_reservations).is_empty():
			return false
	if CustomerOrderTypes.needs_lodging(order_type):
		if InnLayoutHelper.find_available_bed(ViewIds.Id.INN_F1, _furniture_reservations).is_empty():
			return false
	return true


func _remove_from_counter_queue(customer: CustomerEntity) -> void:
	if customer in _counter_queue:
		_counter_queue.erase(customer)
		_try_start_next_outside_admission()


func _refresh_counter_queue(from_index: int = 0) -> void:
	_purge_invalid_counter_queue_entries()
	from_index = clampi(from_index, 0, _counter_queue.size())
	InnLayoutHelper.prepare_counter_queue_layout(ViewIds.Id.INN_F1, _counter_queue.size())
	var reserved_coords: Dictionary = {}
	var needs_staff: bool = false
	for index in range(_counter_queue.size()):
		var customer = _counter_queue[index]
		if not is_instance_valid(customer):
			continue
		var slot_position: Vector2 = InnLayoutHelper.get_counter_queue_position_at(
			customer.view_id,
			index,
			reserved_coords
		)
		if slot_position == Vector2.ZERO:
			continue
		var slot_coord: GridCoord = GridCoord.from_local(customer.view_id, slot_position)
		reserved_coords[slot_coord.to_key()] = true
		if index >= from_index and customer.update_queue_slot(index, slot_position):
			if index == 0:
				needs_staff = true
		elif index < from_index:
			customer.prepare_queue_slot(index, slot_position)

	if needs_staff or get_customer_ready_for_order() != null:
		StaffService.schedule_work()


func _release_customer_reservations(customer_id: String) -> void:
	var instance_ids: Array = _furniture_reservations.keys()
	for instance_id: String in instance_ids:
		if _furniture_reservations[instance_id] == customer_id:
			_furniture_reservations.erase(instance_id)


func _purge_invalid_counter_queue_entries() -> void:
	for index in range(_counter_queue.size() - 1, -1, -1):
		var customer = _counter_queue[index]
		if not is_instance_valid(customer):
			_counter_queue.remove_at(index)
