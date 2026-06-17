extends Node

const CUSTOMER_SCENE: PackedScene = preload("res://scenes/entities/customer_entity.tscn")
const GroupDiningConstants := preload("res://scripts/core/customer/group_dining_constants.gd")
const MAX_PATH_BUILDS_PER_FRAME: int = 8
const MAX_OUTSIDE_QUEUE_SIZE: int = 6
const OUTSIDE_GROUP_COMPANION_OFFSET: Vector2 = Vector2(18.0, 12.0)
const OUTSIDE_GROUP_COMPANION_OFFSETS: Array[Vector2] = [
	Vector2(18.0, 12.0),
	Vector2(-18.0, 12.0),
	Vector2(0.0, 24.0),
]
const OUTSIDE_PATIENCE_DECAY_PER_5_MIN: float = 2.0

var _customers: Dictionary = {}
var _next_customer_number: int = 1
var _next_outside_customer_number: int = 1
var _next_group_number: int = 1
var _spawn_timer: Timer
var _counter_queue: Array[CustomerEntity] = []
var _outside_queue: Array[OutsideCustomerEntity] = []
var _entering_outside_customer: OutsideCustomerEntity = null
var _pending_outside_companions: Dictionary = {}
var _furniture_reservations: Dictionary = {}
var _waiting_chair_reservations: Dictionary = {}
const DEBUG_WAITING_CHAIR_LOCK_ID: String = "__debug_lock__"
var _path_build_queue: Array[Dictionary] = []
var _pending_activations: Array[CustomerEntity] = []
var _layout_refresh_pending: bool = false
var _last_checkout_day: int = 0
var selected_customer: CustomerEntity = null


func _ready() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	_spawn_timer.timeout.connect(_try_spawn_customer)
	add_child(_spawn_timer)
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.game_time_pause_changed.connect(_on_game_time_pause_changed)
	EventBus.game_time_speed_changed.connect(_on_game_time_speed_changed)
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	EventBus.service_phase_changed.connect(_on_service_phase_changed)
	EventBus.navigation_map_ready.connect(_on_navigation_map_ready)
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.furniture_placed.connect(_on_layout_changed)
	EventBus.furniture_removed.connect(_on_layout_changed)
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)


func _process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		return
	var scaled_delta: float = GameTimeManager.scaled_delta(delta)
	_recover_stalled_outside_admission()
	_tick_outside_queue_patience(scaled_delta)
	_sync_pending_outside_companion_patience()
	_drain_path_build_queue()
	for customer: CustomerEntity in get_active_customers():
		if is_instance_valid(customer):
			customer.tick_needs(scaled_delta)


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
			_free_outside_group_visuals(outside_customer)
			outside_customer.queue_free()
	_outside_queue.clear()
	if is_instance_valid(_entering_outside_customer):
		_free_outside_group_visuals(_entering_outside_customer)
		_entering_outside_customer.queue_free()
	_entering_outside_customer = null
	_clear_all_pending_outside_companions()
	for customer_id: String in _customers.keys():
		_release_customer_reservations(customer_id)
		var customer = _customers[customer_id]
		if is_instance_valid(customer):
			customer.queue_free()
	_customers.clear()
	_counter_queue.clear()
	_furniture_reservations.clear()
	_waiting_chair_reservations.clear()
	_next_outside_customer_number = 1
	_next_group_number = 1
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
		_highlight_customer_group(selected_customer)
		EventBus.customer_selected.emit(selected_customer)


func clear_customer_selection() -> void:
	if selected_customer and is_instance_valid(selected_customer):
		selected_customer.set_selected(false)
	_clear_group_highlights()
	selected_customer = null
	EventBus.customer_selected.emit(null)


func _highlight_customer_group(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.group_id == "":
		return
	for active_customer: CustomerEntity in get_active_customers():
		if not is_instance_valid(active_customer):
			continue
		active_customer.set_group_highlighted(active_customer.group_id == customer.group_id)


func _clear_group_highlights() -> void:
	for customer: CustomerEntity in get_active_customers():
		if is_instance_valid(customer):
			customer.set_group_highlighted(false)


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


func on_group_member_meal_finished(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.group_id == "" or customer.group_size <= 1:
		return

	var members: Array[CustomerEntity] = _get_active_group_members(customer.group_id)
	if members.is_empty():
		return

	var dining_members: Array[CustomerEntity] = []
	for member: CustomerEntity in members:
		if not is_instance_valid(member):
			continue
		if member.get_order_type() != CustomerOrderTypes.Id.FOOD:
			continue
		if member.current_state == CustomerStates.Id.EATING or member.group_meal_finished:
			dining_members.append(member)

	if dining_members.is_empty():
		return

	for member: CustomerEntity in dining_members:
		if not member.group_meal_finished:
			return

	if members.size() < customer.group_size:
		_depart_pending_outside_companions(customer.group_id)
	_complete_group_food_exit_for_members(dining_members)


func on_customer_patience_depleted(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.current_state in [CustomerStates.Id.LEAVING, CustomerStates.Id.DONE]:
		return
	if CustomerOrderTypes.needs_lodging(customer.get_order_type()):
		return

	var reason: String = "인내심이 바닥났습니다."
	if customer.group_id != "":
		_depart_pending_outside_companions(customer.group_id)
	var customers_to_dismiss: Array[CustomerEntity] = []
	if customer.group_id != "":
		customers_to_dismiss = _get_active_group_members(customer.group_id)
	else:
		customers_to_dismiss = [customer]

	for member: CustomerEntity in customers_to_dismiss:
		if not is_instance_valid(member):
			continue
		if member.current_state in [CustomerStates.Id.LEAVING, CustomerStates.Id.DONE]:
			continue
		_dismiss_customer_for_patience(member, reason)

	_refresh_counter_queue(0)
	_try_start_next_outside_admission()
	StaffService.schedule_work()


func _dismiss_customer_for_patience(customer: CustomerEntity, reason: String) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.is_group_leader and customer.group_id != "":
		_depart_pending_outside_companions(customer.group_id)
	_counter_queue.erase(customer)
	_release_waiting_chair_reservation(customer)
	KitchenService.release_customer(customer)
	TableFoodService.clear_food(customer)
	customer.is_group_companion_waiting_for_leader = false
	customer.on_order_rejected(reason)


func _get_active_group_members(group_id: String) -> Array[CustomerEntity]:
	var members: Array[CustomerEntity] = []
	if group_id == "":
		return members
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer.group_id == group_id:
			members.append(customer)
	return members


func _complete_group_food_exit_for_members(members: Array[CustomerEntity]) -> void:
	for member: CustomerEntity in members:
		if is_instance_valid(member) and member.group_meal_finished:
			member.complete_group_food_exit()


func get_reserved_instance_ids() -> Dictionary:
	var reserved: Dictionary = _furniture_reservations.duplicate()
	for instance_id: String in _waiting_chair_reservations.keys():
		reserved[instance_id] = _waiting_chair_reservations[instance_id]
	return reserved


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


func _tick_outside_queue_patience(delta: float) -> void:
	if delta <= 0.0:
		return
	var queue_changed: bool = false
	for index in range(_outside_queue.size() - 1, -1, -1):
		var outside_customer: OutsideCustomerEntity = _outside_queue[index]
		if not is_instance_valid(outside_customer):
			_outside_queue.remove_at(index)
			queue_changed = true
			continue
		if outside_customer.is_moving:
			continue
		if outside_customer.tick_outside_wait_patience(delta, OUTSIDE_PATIENCE_DECAY_PER_5_MIN):
			_outside_queue.remove_at(index)
			queue_changed = true
			outside_customer.depart_to_edge(index % 2 == 0)
	if queue_changed:
		_refresh_outside_queue(0)


func _sync_pending_outside_companion_patience() -> void:
	if _pending_outside_companions.is_empty():
		return

	var group_ids: Array = _pending_outside_companions.keys()
	for group_id_variant in group_ids:
		var group_id: String = str(group_id_variant)
		if not _pending_outside_companions.has(group_id):
			continue

		var leader: CustomerEntity = _find_inside_group_leader(group_id)
		if leader == null or not is_instance_valid(leader):
			_depart_pending_outside_companions(group_id)
			continue

		var shared_patience: float = leader.patience
		for companion in _pending_outside_companions[group_id]:
			if is_instance_valid(companion):
				companion.sync_shared_patience(shared_patience)

		if shared_patience <= 0.0:
			_depart_pending_outside_companions(group_id)


func _count_pending_outside_companions() -> int:
	var count: int = 0
	for group_id: String in _pending_outside_companions.keys():
		for companion in _pending_outside_companions[group_id]:
			if is_instance_valid(companion):
				count += 1
	return count


func get_customer_display_label(customer: CustomerEntity) -> String:
	if customer == null or not is_instance_valid(customer):
		return "손님"
	if (
		customer.group_id != ""
		and customer.group_size >= GroupDiningConstants.MIN_GROUP_SIZE
	):
		var role_label: String = "대표" if customer.is_group_leader else "동행"
		return "%s · %d인 %s" % [customer.customer_id, customer.group_size, role_label]
	return customer.customer_id


func get_group_dining_capacity_summary(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> String:
	var reserved: Dictionary = get_reserved_instance_ids()
	var max_seatable: int = InnLayoutHelper.find_max_seatable_group_size(view_id, reserved)
	var waiting_chairs: Dictionary = InnLayoutHelper.count_waiting_chairs(
		view_id,
		_waiting_chair_reservations
	)
	var parts: PackedStringArray = []
	if max_seatable >= GroupDiningConstants.MIN_GROUP_SIZE:
		parts.append("단체석 최대 %d인" % max_seatable)
	else:
		parts.append("단체석 없음")
	parts.append(
		"대기의자 %d/%d" % [
			int(waiting_chairs.get("available", 0)),
			int(waiting_chairs.get("total", 0)),
		]
	)
	var pending_outside_count: int = _count_pending_outside_companions()
	if pending_outside_count > 0:
		parts.append("야외 동행 %d명" % pending_outside_count)
	return " · ".join(parts)


func get_group_dining_debug_lines(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> PackedStringArray:
	var lines: PackedStringArray = []
	var reserved: Dictionary = get_reserved_instance_ids()
	var max_seatable: int = InnLayoutHelper.find_max_seatable_group_size(view_id, reserved)
	var waiting_chairs: Dictionary = InnLayoutHelper.count_waiting_chairs(
		view_id,
		_waiting_chair_reservations
	)
	lines.append("단체 식사 (최대 %d인)" % max_seatable)
	lines.append(
		"대기의자: 사용가능 %d / 전체 %d" % [
			int(waiting_chairs.get("available", 0)),
			int(waiting_chairs.get("total", 0)),
		]
	)
	lines.append("야외 대기 동행: %d명" % _count_pending_outside_companions())
	var table_entries: Array[Dictionary] = InnLayoutHelper.get_table_group_capacity_entries(
		view_id,
		reserved
	)
	if table_entries.is_empty():
		lines.append("  테이블: 없음")
	else:
		lines.append("테이블 수용:")
		for entry: Dictionary in table_entries:
			lines.append(
				"  %s · %d인" % [entry.get("label", "테이블"), int(entry.get("capacity", 0))]
			)
	return lines


func get_player_queue_summary() -> String:
	var queue_customers: Array[CustomerEntity] = get_counter_queue_customers()
	var outside_count: int = 0
	for outside_customer: OutsideCustomerEntity in get_outside_queue_customers():
		outside_count += _outside_customer_pressure(outside_customer)
	var entering_count: int = _outside_customer_pressure(_entering_outside_customer)
	var pending_outside_count: int = _count_pending_outside_companions()
	var capacity_summary: String = get_group_dining_capacity_summary()
	if queue_customers.is_empty() and outside_count == 0 and entering_count == 0 and pending_outside_count == 0:
		return "대기 줄: 없음 · %s" % capacity_summary
	var queue_part: String = ""
	if queue_customers.is_empty():
		queue_part = "야외 줄: %d명 · 입장중: %d명 · 대기 동행: %d명" % [
			outside_count,
			entering_count,
			pending_outside_count,
		]
	else:
		var front: CustomerEntity = queue_customers[0]
		var front_label: String = CustomerStates.label_for(front.current_state)
		var front_group_hint: String = ""
		if (
			front.group_size >= GroupDiningConstants.MIN_GROUP_SIZE
			and front.is_group_leader
		):
			front_group_hint = " · %d인" % front.group_size
		if queue_customers.size() == 1:
			queue_part = "야외 줄: %d명 · 입장중: %d명 · 카운터: 1명 (%s%s)" % [
				outside_count,
				entering_count,
				front_label,
				front_group_hint,
			]
		else:
			queue_part = "야외 줄: %d명 · 입장중: %d명 · 카운터: %d명 (앞: %s%s)" % [
				outside_count,
				entering_count,
				queue_customers.size(),
				front_label,
				front_group_hint,
			]
		if pending_outside_count > 0:
			queue_part += " · 대기 동행: %d명" % pending_outside_count
	return "%s · %s" % [queue_part, capacity_summary]


func spawn_debug_group_outside(group_size: int = GroupDiningConstants.MAX_GROUP_SIZE) -> OutsideCustomerEntity:
	if not DebugService.is_active():
		return null
	if not GameTimeManager.is_running():
		return null
	if get_outside_queue_customers().size() >= MAX_OUTSIDE_QUEUE_SIZE:
		return null

	var outside_view: ViewRoot = ViewManager.get_view(ViewIds.Id.OUTSIDE)
	if not (outside_view is OutsideViewRoot):
		return null

	var forced_size: int = clampi(
		group_size,
		GroupDiningConstants.MIN_GROUP_SIZE,
		GroupDiningConstants.MAX_GROUP_SIZE
	)
	var queue_position: Vector2 = OutsideViewConstants.outside_queue_position(_outside_queue.size())
	var outside_customer: OutsideCustomerEntity = (
		outside_view as OutsideViewRoot
	).spawn_outside_customer_from_edge(queue_position, -1, -1)
	if outside_customer == null:
		return null

	outside_customer.customer_id = _generate_outside_customer_id()
	outside_customer.name = outside_customer.customer_id
	_configure_outside_group(
		outside_view as OutsideViewRoot,
		outside_customer,
		queue_position,
		forced_size
	)
	outside_customer.reached_target.connect(_on_outside_customer_reached_target)
	_outside_queue.append(outside_customer)
	_refresh_outside_queue(maxi(0, _outside_queue.size() - 1))
	_try_start_next_outside_admission()
	return outside_customer


func debug_set_waiting_chair_limit(max_free: int) -> void:
	if not DebugService.is_active():
		return
	_clear_debug_waiting_chair_reservations()
	max_free = maxi(max_free, 0)
	var available_ids: Array[String] = []
	for instance: FurnitureInstance in FurnitureService.get_instances(ViewIds.Id.INN_F1):
		if instance.def_id != "waiting_chair":
			continue
		if _waiting_chair_reservations.has(instance.instance_id):
			continue
		var stand_position: Vector2 = InnLayoutHelper.get_furniture_customer_position(instance)
		if stand_position == Vector2.ZERO:
			continue
		if not InnLayoutHelper.is_customer_target_reachable(ViewIds.Id.INN_F1, Vector2.ZERO, stand_position):
			continue
		available_ids.append(instance.instance_id)

	var lock_count: int = maxi(available_ids.size() - max_free, 0)
	for index in range(lock_count):
		_waiting_chair_reservations[available_ids[index]] = DEBUG_WAITING_CHAIR_LOCK_ID


func debug_clear_waiting_chair_limit() -> void:
	_clear_debug_waiting_chair_reservations()


func get_group_qa_report() -> String:
	var lines: PackedStringArray = []
	var waiting_chairs: Dictionary = InnLayoutHelper.count_waiting_chairs(
		ViewIds.Id.INN_F1,
		_waiting_chair_reservations
	)
	lines.append("=== 그룹 QA ===")
	lines.append(
		"대기의자: 빈칸 %d / 전체 %d" % [
			int(waiting_chairs.get("available", 0)),
			int(waiting_chairs.get("total", 0)),
		]
	)
	lines.append("야외 pending 동행: %d명" % _count_pending_outside_companions())

	var group_ids: Dictionary = {}
	for customer: CustomerEntity in get_active_customers():
		if customer.group_id != "":
			group_ids[customer.group_id] = true
	for group_id: String in _pending_outside_companions.keys():
		group_ids[group_id] = true

	if group_ids.is_empty():
		lines.append("활성 그룹: 없음")
	else:
		for group_id: String in group_ids.keys():
			var leader: CustomerEntity = _find_inside_group_leader(group_id)
			var members: Array[CustomerEntity] = _get_active_group_members(group_id)
			var waiting_inside: int = 0
			var dining: int = 0
			for member: CustomerEntity in members:
				if member.is_group_companion_waiting_for_leader:
					waiting_inside += 1
				if member.current_state == CustomerStates.Id.EATING:
					dining += 1
			var pending_outside: int = 0
			if _pending_outside_companions.has(group_id):
				for companion in _pending_outside_companions[group_id]:
					if is_instance_valid(companion):
						pending_outside += 1
			var group_size: int = leader.group_size if is_instance_valid(leader) else 0
			if group_size <= 0 and not members.is_empty():
				group_size = members[0].group_size
			lines.append(
				"[%s] %d인 · 안쪽 %d · 대기동행 %d · pending %d · 식사중 %d · 대표 %s" % [
					group_id,
					group_size,
					members.size(),
					waiting_inside,
					pending_outside,
					dining,
					leader.customer_id if is_instance_valid(leader) else "없음",
				]
			)
			if (
				group_size == 4
				and is_instance_valid(leader)
				and leader.is_group_leader
				and members.size() == 2
				and waiting_inside == 1
				and pending_outside == 2
			):
				lines.append("  → 시나리오1 패턴: 대표+동행1 inside, 동행2 outside")
			if pending_outside > 0 and int(waiting_chairs.get("available", 0)) > 0:
				lines.append("  → 시나리오2: 빈 대기의자 있음 → pending 순차 입장 가능")
			if group_size >= 4 and dining >= 4:
				lines.append("  → 시나리오3: 4인 동시 식사 중")
	return "\n".join(lines)


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
			var group_text: String = ""
			if outside_customer.is_group_leader and outside_customer.group_size > 1:
				group_text = " · %d인 일행" % outside_customer.group_size
			lines.append(
				"  #%d %s · %s%s" % [index + 1, outside_customer.customer_id, state_text, group_text]
			)

	var pending_count: int = _count_pending_outside_companions()
	lines.append("입장 대기 동행 (%d명)" % pending_count)
	if pending_count == 0:
		lines.append("  (비어 있음)")
	else:
		for group_id: String in _pending_outside_companions.keys():
			var leader: CustomerEntity = _find_inside_group_leader(group_id)
			var leader_label: String = (
				leader.customer_id if is_instance_valid(leader) else "대표 없음"
			)
			var pending: Array = _pending_outside_companions[group_id]
			for pending_index in range(pending.size()):
				var companion = pending[pending_index]
				if not is_instance_valid(companion):
					continue
				lines.append(
					"  %s · %s · 인내 %d · 대표 %s" % [
						companion.customer_id,
						group_id,
						int(round(companion.patience)),
						leader_label,
					]
				)

	lines.append_array(get_group_dining_debug_lines())

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
	lines.append("")
	lines.append(get_group_qa_report())
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
	if customer.group_size >= GroupDiningConstants.MIN_GROUP_SIZE:
		var role_label: String = "대표" if customer.is_group_leader else "동행"
		tags.append("%d인 %s" % [customer.group_size, role_label])

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
	_refresh_counter_queue(_counter_queue.size() - 1)


func on_customer_request_pending(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer != get_front_customer():
		return
	StaffService.request_take_order(customer)


func unregister_waiting_customer(customer: CustomerEntity) -> void:
	if customer in _counter_queue:
		_counter_queue.erase(customer)
		_release_waiting_chair_reservation(customer)
		_refresh_counter_queue(0)
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
	if not GameClock.is_open_hours():
		customer.on_order_rejected("영업이 종료되었습니다.")
		_remove_from_counter_queue(customer)
		return
	if not (customer.current_state in [
		CustomerStates.Id.REQUEST_PENDING,
		CustomerStates.Id.WAITING_AT_COUNTER,
	]):
		return

	var order_type: CustomerOrderTypes.Id = customer.get_order_type()
	var block_reason: String = _get_order_block_reason(customer)
	if block_reason != "":
		if _is_group_dining_leader(customer):
			_fail_group_order(customer, block_reason)
		else:
			customer.on_order_rejected(block_reason)
			_remove_from_counter_queue(customer)
		StaffService.schedule_work()
		return

	var chair_data: Dictionary = {}
	var bed_data: Dictionary = {}
	var group_pair_data: Dictionary = {}
	var group_chairs: Array = []
	var is_group_order: bool = _is_group_dining_leader(customer)
	if is_group_order:
		group_pair_data = InnLayoutHelper.find_available_chairs_for_table(
			customer.view_id,
			customer.group_size,
			_furniture_reservations,
			customer.global_position
		)
		if group_pair_data.is_empty():
			_fail_group_order(customer, "%d인 단체석이 부족합니다." % customer.group_size)
			StaffService.schedule_work()
			return
		group_chairs = group_pair_data.get("chairs", [])
		if group_chairs.size() < customer.group_size:
			_fail_group_order(customer, "%d인 단체석이 부족합니다." % customer.group_size)
			StaffService.schedule_work()
			return
		chair_data = group_chairs[0]
	elif CustomerOrderTypes.needs_food(order_type):
		chair_data = InnLayoutHelper.find_available_chair(
			customer.view_id,
			_furniture_reservations,
			customer.global_position
		)
		if chair_data.is_empty():
			customer.on_order_rejected("사용 가능한 좌석이 없습니다.")
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
			customer.on_order_rejected("사용 가능한 침대가 없습니다.")
			_remove_from_counter_queue(customer)
			StaffService.schedule_work()
			return

	if not chair_data.is_empty():
		_furniture_reservations[chair_data["instance_id"]] = customer.customer_id
	if not bed_data.is_empty():
		_furniture_reservations[bed_data["instance_id"]] = customer.customer_id

	var companion: CustomerEntity = null
	var assigned_dining_companions: Array[CustomerEntity] = []
	if is_group_order:
		for chair_index in range(1, group_chairs.size()):
			companion = _assign_group_companion_order(customer, group_chairs[chair_index])
			if companion == null:
				if not chair_data.is_empty():
					_furniture_reservations.erase(chair_data["instance_id"])
				_rollback_assigned_dining_companions(assigned_dining_companions)
				_fail_group_order(customer, "동행 손님을 입장시킬 수 없습니다.")
				StaffService.schedule_work()
				return
			assigned_dining_companions.append(companion)

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
	if not GameClock.is_open_hours():
		return
	if _get_total_customer_pressure() >= 6:
		return
	if get_outside_queue_customers().size() >= MAX_OUTSIDE_QUEUE_SIZE:
		return
	if not NavService.is_map_synchronized(ViewIds.Id.INN_F1):
		return
	if not InnLayoutHelper.has_service_space(ViewIds.Id.INN_F1):
		return
	var counter_customer_position: Vector2 = InnLayoutHelper.find_counter_customer_position(ViewIds.Id.INN_F1)
	if counter_customer_position == Vector2.ZERO:
		return
	if InnLayoutHelper.find_available_chair(
		ViewIds.Id.INN_F1,
		_furniture_reservations,
		counter_customer_position
	).is_empty():
		return
	spawn_outside_customer()


func spawn_outside_customer() -> OutsideCustomerEntity:
	var outside_view: ViewRoot = ViewManager.get_view(ViewIds.Id.OUTSIDE)
	if not (outside_view is OutsideViewRoot):
		return null

	var queue_position: Vector2 = OutsideViewConstants.outside_queue_position(_outside_queue.size())
	var outside_customer: OutsideCustomerEntity = (outside_view as OutsideViewRoot).spawn_outside_customer_from_edge(
		queue_position,
		-1,
		-1
	)
	if outside_customer == null:
		return null

	outside_customer.customer_id = _generate_outside_customer_id()
	outside_customer.name = outside_customer.customer_id
	_configure_outside_group_if_available(outside_view as OutsideViewRoot, outside_customer, queue_position)
	outside_customer.reached_target.connect(_on_outside_customer_reached_target)
	_outside_queue.append(outside_customer)
	_refresh_outside_queue(maxi(0, _outside_queue.size() - 1))
	_try_start_next_outside_admission()
	return outside_customer


func _configure_outside_group_if_available(
	outside_view: OutsideViewRoot,
	leader: OutsideCustomerEntity,
	queue_position: Vector2
) -> void:
	if outside_view == null or leader == null or not is_instance_valid(leader):
		return
	if randf() > GroupDiningConstants.GROUP_DINING_CHANCE:
		return
	var approach_from: Vector2 = InnLayoutHelper.find_counter_customer_position(ViewIds.Id.INN_F1)
	if approach_from == Vector2.ZERO:
		return

	var group_size: int = _resolve_group_dining_size(ViewIds.Id.INN_F1, approach_from)
	if group_size < GroupDiningConstants.MIN_GROUP_SIZE:
		return
	_configure_outside_group(outside_view, leader, queue_position, group_size)


func _configure_outside_group(
	outside_view: OutsideViewRoot,
	leader: OutsideCustomerEntity,
	queue_position: Vector2,
	group_size: int
) -> void:
	if outside_view == null or leader == null or not is_instance_valid(leader):
		return
	if group_size < GroupDiningConstants.MIN_GROUP_SIZE:
		return

	var group_id: String = _generate_group_id()
	leader.configure_group(group_id, group_size, true)

	for companion_index in range(group_size - 1):
		var follow_offset: Vector2 = OUTSIDE_GROUP_COMPANION_OFFSETS[
			companion_index % OUTSIDE_GROUP_COMPANION_OFFSETS.size()
		]
		var companion: OutsideCustomerEntity = outside_view.spawn_outside_customer_from_edge(
			queue_position + follow_offset,
			leader.spawn_side,
			-1
		)
		if companion == null:
			_free_outside_group_visuals(leader)
			leader.group_id = ""
			leader.group_size = 1
			leader.is_group_leader = false
			leader.group_companions.clear()
			leader.group_companion = null
			return

		companion.customer_id = _generate_outside_customer_id()
		companion.name = companion.customer_id
		companion.configure_group(
			group_id,
			group_size,
			false,
			follow_offset
		)
		leader.add_group_companion(companion)

	leader.set_target_position(queue_position)


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


func _recover_stalled_outside_admission() -> void:
	if not is_instance_valid(_entering_outside_customer):
		return
	if _entering_outside_customer.is_moving:
		return
	if _entering_outside_customer.position.distance_to(OutsideViewConstants.inn_door_position()) > OutsideCustomerEntity.ARRIVAL_TOLERANCE:
		return
	call_deferred("_complete_outside_admission", _entering_outside_customer)


func _try_start_next_outside_admission() -> void:
	if is_instance_valid(_entering_outside_customer):
		return

	_purge_invalid_outside_queue_entries()
	if _outside_queue.is_empty():
		return

	var outside_customer: OutsideCustomerEntity = _outside_queue[0]
	if not _has_counter_entry_capacity(outside_customer):
		return

	outside_customer = _outside_queue.pop_front()
	if not is_instance_valid(outside_customer):
		_refresh_outside_queue(0)
		call_deferred("_try_start_next_outside_admission")
		return

	_entering_outside_customer = outside_customer
	_refresh_outside_queue(0)
	outside_customer.set_target_position(OutsideViewConstants.inn_door_position())


func _has_counter_entry_capacity(outside_customer: OutsideCustomerEntity = null) -> bool:
	_purge_invalid_counter_queue_entries()
	if GroupDiningConstants.uses_partial_outside_wait():
		if _counter_queue.is_empty():
			return true
		return _count_available_waiting_chairs(1) >= 1

	var group_size: int = 1
	if is_instance_valid(outside_customer):
		group_size = maxi(outside_customer.group_size, 1)
	var counter_spots_available: int = 1 if _counter_queue.is_empty() else 0
	var required_waiting_chairs: int = maxi(group_size - counter_spots_available, 0)
	if required_waiting_chairs <= 0:
		return true
	return _count_available_waiting_chairs(required_waiting_chairs) >= required_waiting_chairs


func _count_available_waiting_chairs(required_count: int) -> int:
	var reservations: Dictionary = _waiting_chair_reservations.duplicate()
	var count: int = 0
	while count < required_count:
		var chair_data: Dictionary = InnLayoutHelper.find_available_waiting_chair(
			ViewIds.Id.INN_F1,
			reservations
		)
		if chair_data.is_empty():
			return count
		var instance_id: String = chair_data.get("instance_id", "")
		if instance_id == "":
			return count
		reservations[instance_id] = "__capacity_check_%d" % count
		count += 1
	return count


func _complete_outside_admission(outside_customer: OutsideCustomerEntity) -> void:
	if outside_customer != _entering_outside_customer:
		return

	var persona_id: int = outside_customer.persona
	var remaining_patience: float = outside_customer.patience
	var group_id: String = outside_customer.group_id
	var group_size: int = outside_customer.group_size
	var is_group_leader: bool = outside_customer.is_group_leader
	var outside_companions: Array[OutsideCustomerEntity] = []
	if is_group_leader and group_size > 1:
		outside_companions = outside_customer.get_all_group_companions()
	var companion_persona: int = (
		outside_companions[0].persona
		if not outside_companions.is_empty()
		else CustomerPersonas.Id.TRAVELER
	)
	_entering_outside_customer = null
	if is_instance_valid(outside_customer):
		outside_customer.queue_free()

	var inside_customer: CustomerEntity = spawn_customer(
		persona_id,
		group_id,
		group_size,
		is_group_leader,
		companion_persona,
		false
	)
	if inside_customer != null:
		inside_customer.patience = remaining_patience
	if inside_customer != null and _is_group_dining_leader(inside_customer):
		_admit_inside_group_waiting_companions(inside_customer, outside_companions, group_id)
	call_deferred("_try_start_next_outside_admission")
	call_deferred("_try_admit_outside_group_companions")


func _get_total_customer_pressure() -> int:
	var entering_count: int = _outside_customer_pressure(_entering_outside_customer)
	var outside_count: int = 0
	for outside_customer: OutsideCustomerEntity in get_outside_queue_customers():
		outside_count += _outside_customer_pressure(outside_customer)
	var pending_outside_count: int = _count_pending_outside_companions()
	return get_active_count() + outside_count + entering_count + pending_outside_count


func _outside_customer_pressure(outside_customer: OutsideCustomerEntity) -> int:
	if not is_instance_valid(outside_customer):
		return 0
	return maxi(outside_customer.group_size, 1)


func spawn_customer(
	persona_id: int = -1,
	group_id: String = "",
	group_size: int = 1,
	is_group_leader: bool = false,
	companion_persona: int = CustomerPersonas.Id.TRAVELER,
	allow_group_roll: bool = true
) -> CustomerEntity:
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
	if is_group_leader and group_id != "":
		customer.order = _make_food_order(view_id)
		customer.group_id = group_id
		customer.group_size = group_size
		customer.is_group_leader = true
		customer.group_companion_persona = companion_persona as CustomerPersonas.Id
	elif allow_group_roll:
		_maybe_mark_group_leader(customer, counter_position)
	customer.finished.connect(_on_customer_finished)
	_customers[customer_id] = customer
	join_counter_queue(customer)
	request_activation(customer)
	call_deferred("_emit_customer_spawned", customer)
	return customer


func _maybe_mark_group_leader(customer: CustomerEntity, approach_from: Vector2) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.get_order_type() != CustomerOrderTypes.Id.FOOD:
		return
	if randf() > GroupDiningConstants.GROUP_DINING_CHANCE:
		return

	var group_size: int = _resolve_group_dining_size(customer.view_id, approach_from)
	if group_size < GroupDiningConstants.MIN_GROUP_SIZE:
		return

	customer.group_id = _generate_group_id()
	customer.group_size = group_size
	customer.is_group_leader = true
	customer.group_companion_persona = CustomerPersonas.random()


func _make_food_order(view_id: ViewIds.Id) -> Dictionary:
	var meal: Dictionary = KitchenUpgradeService.pick_food_order(view_id)
	meal["order_type"] = CustomerOrderTypes.Id.FOOD
	meal["food_price"] = int(meal.get("price", 3))
	meal["ingredient_cost"] = int(meal.get("ingredient_cost", 1))
	meal["lodging_price"] = 0
	return meal


func _spawn_group_waiting_companion(
	leader: CustomerEntity,
	companion_persona: int = -1
) -> CustomerEntity:
	if leader == null or not is_instance_valid(leader):
		return null

	var view: ViewRoot = ViewManager.get_view(leader.view_id)
	if view == null:
		return null

	var chair_data: Dictionary = InnLayoutHelper.find_available_waiting_chair(
		leader.view_id,
		_waiting_chair_reservations,
		leader.global_position
	)
	if chair_data.is_empty():
		return null

	var chair_instance_id: String = chair_data.get("instance_id", "")
	var chair_position: Vector2 = chair_data.get("position", Vector2.ZERO)
	if chair_instance_id == "" or chair_position == Vector2.ZERO:
		return null

	var persona: CustomerPersonas.Id = leader.group_companion_persona
	if companion_persona >= 0:
		persona = companion_persona as CustomerPersonas.Id

	var companion: CustomerEntity = CUSTOMER_SCENE.instantiate() as CustomerEntity
	var companion_id: String = _generate_customer_id()
	var spawn_position: Vector2 = InnLayoutHelper.find_entry_position(leader.view_id)
	if spawn_position == Vector2.ZERO:
		spawn_position = leader.global_position
	companion.name = companion_id
	view.entity_layer.add_child(companion)
	companion.configure(
		companion_id,
		leader.view_id,
		persona,
		spawn_position,
		leader.counter_position,
		leader.exit_position
	)
	companion.order = leader.order.duplicate(true)
	companion.patience = leader.patience
	companion.group_id = leader.group_id
	companion.group_size = leader.group_size
	companion.is_group_leader = false
	companion.is_group_companion_waiting_for_leader = true
	companion.waiting_chair_instance_id = chair_instance_id
	companion.finished.connect(_on_customer_finished)
	_customers[companion_id] = companion
	_waiting_chair_reservations[chair_instance_id] = companion_id
	companion.update_queue_slot(1, chair_position)
	request_activation(companion)
	call_deferred("_emit_customer_spawned", companion)
	return companion


func _spawn_group_waiting_companions(leader: CustomerEntity, max_count: int) -> int:
	if leader == null or not is_instance_valid(leader) or max_count <= 0:
		return 0

	var spawned: int = 0
	for _attempt_index in range(max_count):
		if _spawn_group_waiting_companion(leader, CustomerPersonas.random()) == null:
			break
		spawned += 1
	return spawned


func _assign_group_companion_order(leader: CustomerEntity, chair_data: Dictionary) -> CustomerEntity:
	var waiting_companions: Array[CustomerEntity] = _get_group_waiting_companions(leader)
	var companion: CustomerEntity = null
	if not waiting_companions.is_empty():
		companion = waiting_companions[0]
	if companion == null:
		var pending_outside: OutsideCustomerEntity = _take_pending_outside_companion_for_group(
			leader.group_id
		)
		if pending_outside != null:
			var persona: int = pending_outside.persona
			pending_outside.queue_free()
			_reposition_all_pending_outside_companions()
			return _spawn_group_companion(leader, chair_data, persona)
		return _spawn_group_companion(leader, chair_data)

	var chair_instance_id: String = chair_data.get("instance_id", "")
	if chair_instance_id == "":
		return null

	_release_waiting_chair_reservation(companion)
	companion.is_group_companion_waiting_for_leader = false
	_furniture_reservations[chair_instance_id] = companion.customer_id
	companion.on_order_accepted(
		chair_data.get("position", Vector2.ZERO),
		Vector2.ZERO,
		chair_instance_id,
		""
	)
	KitchenService.enqueue_pending(companion)
	return companion


func _get_group_waiting_companions(leader: CustomerEntity) -> Array[CustomerEntity]:
	var companions: Array[CustomerEntity] = []
	if leader == null or not is_instance_valid(leader) or leader.group_id == "":
		return companions
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer == leader:
			continue
		if (
			customer.group_id == leader.group_id
			and customer.is_group_companion_waiting_for_leader
		):
			companions.append(customer)
	companions.sort_custom(func(a: CustomerEntity, b: CustomerEntity) -> bool:
		return a.customer_id < b.customer_id
	)
	return companions


func _get_group_waiting_companion(leader: CustomerEntity) -> CustomerEntity:
	var companions: Array[CustomerEntity] = _get_group_waiting_companions(leader)
	if companions.is_empty():
		return null
	return companions[0]


func _reject_group_waiting_companion(leader: CustomerEntity, reason: String) -> void:
	_reject_group_waiting_companions(leader, reason)


func _reject_group_waiting_companions(leader: CustomerEntity, reason: String) -> void:
	if leader == null or not is_instance_valid(leader):
		return
	while true:
		var companion: CustomerEntity = _get_group_waiting_companion(leader)
		if companion == null:
			break
		_release_waiting_chair_reservation(companion)
		companion.is_group_companion_waiting_for_leader = false
		companion.on_order_rejected(reason)


func _spawn_group_companion(
	leader: CustomerEntity,
	chair_data: Dictionary,
	companion_persona: int = -1
) -> CustomerEntity:
	if leader == null or not is_instance_valid(leader):
		return null
	if chair_data.is_empty():
		return null
	var chair_instance_id: String = chair_data.get("instance_id", "")
	if chair_instance_id == "":
		return null

	var view: ViewRoot = ViewManager.get_view(leader.view_id)
	if view == null:
		return null

	var persona: CustomerPersonas.Id = CustomerPersonas.random()
	if companion_persona >= 0:
		persona = companion_persona as CustomerPersonas.Id

	var companion: CustomerEntity = CUSTOMER_SCENE.instantiate() as CustomerEntity
	var companion_id: String = _generate_customer_id()
	var spawn_position: Vector2 = InnLayoutHelper.find_entry_position(leader.view_id)
	if spawn_position == Vector2.ZERO:
		spawn_position = leader.global_position
	companion.name = companion_id
	view.entity_layer.add_child(companion)
	companion.configure(
		companion_id,
		leader.view_id,
		persona,
		spawn_position,
		leader.counter_position,
		leader.exit_position
	)
	companion.order = leader.order.duplicate(true)
	companion.patience = leader.patience
	companion.group_id = leader.group_id
	companion.group_size = leader.group_size
	companion.is_group_leader = false
	companion.finished.connect(_on_customer_finished)
	_customers[companion_id] = companion
	_furniture_reservations[chair_instance_id] = companion_id
	companion.on_order_accepted(
		chair_data.get("position", Vector2.ZERO),
		Vector2.ZERO,
		chair_instance_id,
		""
	)
	KitchenService.enqueue_pending(companion)
	request_activation(companion)
	call_deferred("_emit_customer_spawned", companion)
	return companion


func _emit_customer_spawned(customer: CustomerEntity) -> void:
	if is_instance_valid(customer):
		DayStatsService.record_guest()
		EventBus.customer_spawned.emit(customer)


func _on_customer_finished(customer: CustomerEntity) -> void:
	if selected_customer == customer:
		clear_customer_selection()
	if is_instance_valid(customer) and customer.is_group_leader:
		_reject_group_waiting_companions(customer, "일행 대표가 떠났습니다.")
		_depart_pending_outside_companions(customer.group_id)
	if is_instance_valid(customer) and customer.group_id != "":
		_release_finished_group_waiters(customer.group_id)
	release_customer(customer)
	if _customers.has(customer.customer_id):
		_customers.erase(customer.customer_id)
	if is_instance_valid(customer):
		customer.queue_free()


func _release_finished_group_waiters(group_id: String) -> void:
	if group_id == "":
		return
	var members: Array[CustomerEntity] = _get_active_group_members(group_id)
	for member: CustomerEntity in members:
		if is_instance_valid(member) and member.group_meal_finished:
			member.complete_group_food_exit()


func on_service_closed() -> void:
	_handle_service_closed()


func _on_day_started(day: int) -> void:
	_checkout_overnight_guests_once(day)
	_refresh_spawn_timer_interval()
	_sync_spawn_timer_for_open_hours()


func _on_day_ended(_day: int, _summary: Dictionary) -> void:
	_spawn_timer.stop()
	for outside_customer: OutsideCustomerEntity in _outside_queue:
		if is_instance_valid(outside_customer):
			_free_outside_group_visuals(outside_customer)
			outside_customer.queue_free()
	_outside_queue.clear()
	if is_instance_valid(_entering_outside_customer):
		_free_outside_group_visuals(_entering_outside_customer)
		_entering_outside_customer.queue_free()
	_entering_outside_customer = null
	_clear_all_pending_outside_companions()
	KitchenService.reset_all()
	TableFoodService.reset_all()


func _on_game_time_speed_changed(_speed: float) -> void:
	_refresh_spawn_timer_interval()
	_sync_spawn_timer_for_open_hours()


func _on_game_time_pause_changed(paused: bool) -> void:
	if paused or not GameTimeManager.is_running():
		return
	_refresh_spawn_timer_interval()
	_sync_spawn_timer_for_open_hours()


func _on_service_phase_changed(_previous_phase: GamePhases.Id, next_phase: GamePhases.Id) -> void:
	if next_phase == GamePhases.Id.CLOSING:
		_let_food_only_diners_finish()
	_sync_spawn_timer_for_open_hours()


func _on_game_hour_changed(_hour: float) -> void:
	if GameClock.is_open_hours():
		_checkout_overnight_guests_once(GameTimeManager.current_day)
	_sync_spawn_timer_for_open_hours()


func _on_navigation_map_ready(view_id: ViewIds.Id) -> void:
	if view_id != ViewIds.Id.INN_F1:
		return
	if GameTimeManager.is_time_flowing():
		call_deferred("_try_start_next_outside_admission")
		call_deferred("_try_spawn_customer")


func _refresh_spawn_timer_interval() -> void:
	var scale: float = maxf(GameTimeManager.time_scale, 0.001)
	_spawn_timer.wait_time = ReputationManager.get_spawn_interval() / scale


func _sync_spawn_timer_for_open_hours() -> void:
	if not GameTimeManager.is_time_flowing() or not GameClock.is_open_hours():
		if not _spawn_timer.is_stopped():
			_spawn_timer.stop()
		return
	if _spawn_timer.is_stopped():
		_spawn_timer.start()
	call_deferred("_try_spawn_customer")


func _checkout_overnight_guests_once(day: int) -> void:
	if _last_checkout_day == day:
		return
	_last_checkout_day = day
	checkout_overnight_guests(day)


func _handle_service_closed() -> void:
	_spawn_timer.stop()
	_dismiss_outside_queue()
	_dismiss_counter_waiting_customers()
	_let_food_only_diners_finish()
	StaffService.schedule_work()


func _dismiss_outside_queue() -> void:
	for index in range(_outside_queue.size()):
		var outside_customer: OutsideCustomerEntity = _outside_queue[index]
		if not is_instance_valid(outside_customer):
			continue
		outside_customer.depart_to_edge(index % 2 == 0)
	_outside_queue.clear()

	if is_instance_valid(_entering_outside_customer):
		var entering_customer: OutsideCustomerEntity = _entering_outside_customer
		_entering_outside_customer = null
		entering_customer.depart_to_edge(
			entering_customer.spawn_side == OutsideCustomerEntity.SpawnSide.LEFT
		)
	else:
		_entering_outside_customer = null


func _dismiss_counter_waiting_customers() -> void:
	var waiting_customers: Array[CustomerEntity] = _counter_queue.duplicate()
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if (
			is_instance_valid(customer)
			and customer.is_group_companion_waiting_for_leader
			and customer not in waiting_customers
		):
			waiting_customers.append(customer)
	_counter_queue.clear()
	_waiting_chair_reservations.clear()
	for customer: CustomerEntity in waiting_customers:
		if not is_instance_valid(customer):
			continue
		customer.waiting_chair_instance_id = ""
		if customer.current_state in [
			CustomerStates.Id.TO_COUNTER,
			CustomerStates.Id.REQUEST_PENDING,
			CustomerStates.Id.WAITING_AT_COUNTER,
			CustomerStates.Id.TO_QUEUE_SLOT,
			CustomerStates.Id.WAITING_IN_QUEUE,
		]:
			customer.on_order_rejected("영업이 종료되었습니다.")


func _let_food_only_diners_finish() -> void:
	for customer: CustomerEntity in get_active_customers():
		if not is_instance_valid(customer):
			continue
		if not CustomerOrderTypes.needs_food(customer.get_order_type()):
			continue
		if customer.current_state == CustomerStates.Id.EATING:
			if KitchenService.has_customer_order(customer):
				continue
			customer.mark_served()


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
	_refresh_counter_queue(0)
	_restart_moving_customers()
	call_deferred("_try_start_next_outside_admission")


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


func _generate_group_id() -> String:
	var group_id: String = "group_%d" % _next_group_number
	_next_group_number += 1
	return group_id


func _can_fulfill_order(customer: CustomerEntity) -> bool:
	return _get_order_block_reason(customer) == ""


func _get_order_block_reason(customer: CustomerEntity) -> String:
	if customer == null or not is_instance_valid(customer):
		return "손님 정보를 확인할 수 없습니다."
	var order_type: CustomerOrderTypes.Id = customer.get_order_type()
	if CustomerOrderTypes.needs_food(order_type):
		var serving_count: int = customer.group_size if _is_group_dining_leader(customer) else 1
		if not FoodStorage.can_consume(KitchenService.get_ingredient_cost(customer) * serving_count):
			return "식재료가 부족합니다."
		if _is_group_dining_leader(customer):
			if InnLayoutHelper.find_available_chairs_for_table(
				ViewIds.Id.INN_F1,
				customer.group_size,
				_furniture_reservations,
				customer.global_position
			).is_empty():
				return "%d인 단체석이 부족합니다." % customer.group_size
		else:
			if InnLayoutHelper.find_available_chair(
				ViewIds.Id.INN_F1,
				_furniture_reservations,
				customer.global_position
			).is_empty():
				return "사용 가능한 좌석이 없습니다."
	if CustomerOrderTypes.needs_lodging(order_type):
		if InnLayoutHelper.find_available_bed(
			ViewIds.Id.INN_F1,
			_furniture_reservations,
			customer.global_position
		).is_empty():
			return "사용 가능한 침대가 없습니다."
	return ""


func _is_group_dining_leader(customer: CustomerEntity) -> bool:
	return (
		customer != null
		and is_instance_valid(customer)
		and customer.is_group_leader
		and customer.group_size >= GroupDiningConstants.MIN_GROUP_SIZE
		and customer.group_id != ""
		and customer.get_order_type() == CustomerOrderTypes.Id.FOOD
	)


func _remove_from_counter_queue(customer: CustomerEntity) -> void:
	if customer in _counter_queue:
		_counter_queue.erase(customer)
		_release_waiting_chair_reservation(customer)
		_refresh_counter_queue(0)
		_try_admit_outside_group_companions()
		_try_start_next_outside_admission()


func _refresh_counter_queue(from_index: int = 0) -> void:
	_purge_invalid_counter_queue_entries()
	from_index = clampi(from_index, 0, _counter_queue.size())
	var counter_position: Vector2 = InnLayoutHelper.find_counter_customer_position(ViewIds.Id.INN_F1)
	var next_waiting_chair_reservations: Dictionary = _get_non_queue_waiting_chair_reservations()
	var customers_to_remove: Array[CustomerEntity] = []
	var needs_staff: bool = false
	for index in range(_counter_queue.size()):
		var customer = _counter_queue[index]
		if not is_instance_valid(customer):
			continue

		if index == 0:
			customer.waiting_chair_instance_id = ""
			if index >= from_index:
				_send_customer_to_counter(customer, counter_position)
				if customer.current_state in [
					CustomerStates.Id.REQUEST_PENDING,
					CustomerStates.Id.WAITING_AT_COUNTER,
				]:
					needs_staff = true
			continue

		var chair_data: Dictionary = _reserve_waiting_chair_for_queue_customer(
			customer,
			next_waiting_chair_reservations
		)
		if chair_data.is_empty():
			customer.waiting_chair_instance_id = ""
			customer.on_order_rejected("빈 대기의자가 없습니다.")
			customers_to_remove.append(customer)
			continue
		var slot_position: Vector2 = chair_data.get("position", Vector2.ZERO)
		if index >= from_index:
			customer.update_queue_slot(index, slot_position)
		else:
			customer.prepare_queue_slot(index, slot_position)

	_waiting_chair_reservations = next_waiting_chair_reservations
	for customer: CustomerEntity in customers_to_remove:
		if customer in _counter_queue:
			_counter_queue.erase(customer)

	if needs_staff or get_customer_ready_for_order() != null:
		StaffService.schedule_work()
	_try_admit_outside_group_companions()


func _get_non_queue_waiting_chair_reservations() -> Dictionary:
	var reservations: Dictionary = {}
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer in _counter_queue:
			continue
		if customer.waiting_chair_instance_id == "":
			continue
		var instance: FurnitureInstance = InnLayoutHelper.get_instance_by_id(
			customer.view_id,
			customer.waiting_chair_instance_id
		)
		if instance == null or instance.def_id != "waiting_chair":
			customer.waiting_chair_instance_id = ""
			continue
		reservations[customer.waiting_chair_instance_id] = customer.customer_id
	return reservations


func _send_customer_to_counter(customer: CustomerEntity, counter_position: Vector2) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if counter_position == Vector2.ZERO:
		return
	if customer.current_state in [
		CustomerStates.Id.REQUEST_PENDING,
		CustomerStates.Id.WAITING_AT_COUNTER,
	]:
		return
	customer.start_counter_consultation(counter_position)


func _reserve_waiting_chair_for_queue_customer(
	customer: CustomerEntity,
	next_reservations: Dictionary
) -> Dictionary:
	if customer == null or not is_instance_valid(customer):
		return {}
	var existing_id: String = customer.waiting_chair_instance_id
	if existing_id != "":
		var existing_instance: FurnitureInstance = InnLayoutHelper.get_instance_by_id(
			customer.view_id,
			existing_id
		)
		if (
			existing_instance != null
			and existing_instance.def_id == "waiting_chair"
			and not next_reservations.has(existing_id)
		):
			var existing_position: Vector2 = InnLayoutHelper.get_furniture_customer_position(existing_instance)
			if existing_position != Vector2.ZERO:
				next_reservations[existing_id] = customer.customer_id
				return {
					"instance_id": existing_id,
					"position": existing_position,
				}

	var chair_data: Dictionary = InnLayoutHelper.find_available_waiting_chair(
		customer.view_id,
		next_reservations,
		customer.global_position
	)
	if chair_data.is_empty():
		return {}
	var instance_id: String = chair_data.get("instance_id", "")
	if instance_id == "":
		return {}
	customer.waiting_chair_instance_id = instance_id
	next_reservations[instance_id] = customer.customer_id
	return chair_data


func _release_waiting_chair_reservation(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	if customer.waiting_chair_instance_id != "":
		_waiting_chair_reservations.erase(customer.waiting_chair_instance_id)
		customer.waiting_chair_instance_id = ""
		_try_admit_outside_group_companions()


func _purge_invalid_waiting_chair_reservations() -> void:
	var active_customer_ids: Dictionary = {}
	for customer: CustomerEntity in _counter_queue:
		if is_instance_valid(customer):
			active_customer_ids[customer.customer_id] = true
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if (
			is_instance_valid(customer)
			and customer.waiting_chair_instance_id != ""
		):
			active_customer_ids[customer.customer_id] = true
	for instance_id: String in _waiting_chair_reservations.keys():
		var customer_id: String = _waiting_chair_reservations[instance_id]
		if not active_customer_ids.has(customer_id):
			_waiting_chair_reservations.erase(instance_id)
			continue
		var instance: FurnitureInstance = InnLayoutHelper.get_instance_by_id(ViewIds.Id.INN_F1, instance_id)
		if instance == null or instance.def_id != "waiting_chair":
			_waiting_chair_reservations.erase(instance_id)


func _release_customer_reservations(customer_id: String) -> void:
	var instance_ids: Array = _furniture_reservations.keys()
	for instance_id: String in instance_ids:
		if _furniture_reservations[instance_id] == customer_id:
			_furniture_reservations.erase(instance_id)
	instance_ids = _waiting_chair_reservations.keys()
	for instance_id: String in instance_ids:
		if _waiting_chair_reservations[instance_id] == customer_id:
			_waiting_chair_reservations.erase(instance_id)


func _purge_invalid_counter_queue_entries() -> void:
	for index in range(_counter_queue.size() - 1, -1, -1):
		var customer = _counter_queue[index]
		if not is_instance_valid(customer):
			_counter_queue.remove_at(index)
	_purge_invalid_waiting_chair_reservations()


func _resolve_group_dining_size(view_id: ViewIds.Id, approach_from: Vector2) -> int:
	var max_seatable: int = InnLayoutHelper.find_max_seatable_group_size(
		view_id,
		_furniture_reservations,
		approach_from
	)
	var rolled_size: int = GroupDiningConstants.roll_group_size(max_seatable)
	if rolled_size < GroupDiningConstants.MIN_GROUP_SIZE:
		return 1
	if not InnLayoutHelper.find_available_chairs_for_table(
		view_id,
		rolled_size,
		_furniture_reservations,
		approach_from
	).is_empty():
		return rolled_size

	for fallback_size in range(rolled_size - 1, GroupDiningConstants.MIN_GROUP_SIZE - 1, -1):
		if not InnLayoutHelper.find_available_chairs_for_table(
			view_id,
			fallback_size,
			_furniture_reservations,
			approach_from
		).is_empty():
			return fallback_size
	return 1


func _admit_inside_group_waiting_companions(
	leader: CustomerEntity,
	outside_companions: Array[OutsideCustomerEntity],
	group_id: String
) -> void:
	if leader == null or not is_instance_valid(leader):
		return

	var companions_needed: int = leader.group_size - 1
	var admitted: int = 0
	var remaining_outside: Array[OutsideCustomerEntity] = []

	for outside_companion: OutsideCustomerEntity in outside_companions:
		if not is_instance_valid(outside_companion):
			continue
		if admitted >= companions_needed:
			remaining_outside.append(outside_companion)
			continue
		if _spawn_group_waiting_companion(leader, outside_companion.persona) != null:
			outside_companion.queue_free()
			admitted += 1
		else:
			remaining_outside.append(outside_companion)

	var still_needed: int = companions_needed - _get_group_waiting_companions(leader).size()
	if still_needed > 0:
		_spawn_group_waiting_companions(leader, still_needed)

	var pending: Array = _pending_outside_companions.get(group_id, [])
	for outside_companion: OutsideCustomerEntity in remaining_outside:
		if is_instance_valid(outside_companion):
			outside_companion.sync_shared_patience(leader.patience)
			pending.append(outside_companion)
	if pending.is_empty() or group_id == "":
		return
	_pending_outside_companions[group_id] = pending
	_reposition_all_pending_outside_companions()
	EventBus.group_outside_wait_notice.emit(
		leader.group_size,
		pending.size(),
		get_customer_display_label(leader)
	)


func _try_admit_outside_group_companions() -> void:
	if _pending_outside_companions.is_empty():
		return

	for group_id: String in _pending_outside_companions.keys():
		var leader: CustomerEntity = _find_inside_group_leader(group_id)
		if leader == null:
			_depart_pending_outside_companions(group_id)
			continue

		var pending: Array = _pending_outside_companions[group_id]
		while not pending.is_empty():
			var outside_companion = pending[0]
			if not is_instance_valid(outside_companion):
				pending.remove_at(0)
				continue
			if _spawn_group_waiting_companion(leader, outside_companion.persona) == null:
				break
			outside_companion.queue_free()
			pending.remove_at(0)

		if pending.is_empty():
			_pending_outside_companions.erase(group_id)
		else:
			_pending_outside_companions[group_id] = pending

	_reposition_all_pending_outside_companions()


func _find_inside_group_leader(group_id: String) -> CustomerEntity:
	if group_id == "":
		return null
	for customer_id: String in _customers.keys():
		var customer = _customers[customer_id]
		if not is_instance_valid(customer):
			continue
		if customer.group_id == group_id and customer.is_group_leader:
			return customer
	return null


func _take_pending_outside_companion_for_group(group_id: String) -> OutsideCustomerEntity:
	if group_id == "" or not _pending_outside_companions.has(group_id):
		return null
	var pending: Array = _pending_outside_companions[group_id]
	while not pending.is_empty():
		var companion = pending[0]
		pending.remove_at(0)
		if is_instance_valid(companion):
			if pending.is_empty():
				_pending_outside_companions.erase(group_id)
			else:
				_pending_outside_companions[group_id] = pending
			return companion
	if pending.is_empty():
		_pending_outside_companions.erase(group_id)
	return null


func _clear_debug_waiting_chair_reservations() -> void:
	var instance_ids: Array = _waiting_chair_reservations.keys()
	for instance_id: String in instance_ids:
		if _waiting_chair_reservations[instance_id] == DEBUG_WAITING_CHAIR_LOCK_ID:
			_waiting_chair_reservations.erase(instance_id)


func _free_outside_group_visuals(outside_customer: OutsideCustomerEntity) -> void:
	if outside_customer == null or not is_instance_valid(outside_customer):
		return
	for companion: OutsideCustomerEntity in outside_customer.get_all_group_companions():
		if is_instance_valid(companion):
			companion.queue_free()
	outside_customer.group_companions.clear()
	outside_customer.group_companion = null


func _clear_pending_outside_companions(group_id: String) -> void:
	if group_id == "" or not _pending_outside_companions.has(group_id):
		return
	for companion in _pending_outside_companions[group_id]:
		if is_instance_valid(companion):
			companion.queue_free()
	_pending_outside_companions.erase(group_id)


func _depart_pending_outside_companions(group_id: String) -> void:
	if group_id == "" or not _pending_outside_companions.has(group_id):
		return
	for companion in _pending_outside_companions[group_id]:
		if not is_instance_valid(companion):
			continue
		companion.depart_to_edge(companion.spawn_side == OutsideCustomerEntity.SpawnSide.LEFT)
	_pending_outside_companions.erase(group_id)


func _fail_group_order(leader: CustomerEntity, reason: String) -> void:
	if leader == null or not is_instance_valid(leader):
		return
	_rollback_assigned_dining_companions_for_group(leader.group_id, leader)
	_reject_group_waiting_companions(leader, reason)
	_depart_pending_outside_companions(leader.group_id)
	leader.on_order_rejected(reason)
	_remove_from_counter_queue(leader)


func _rollback_assigned_dining_companions(assigned_companions: Array[CustomerEntity]) -> void:
	for companion: CustomerEntity in assigned_companions:
		if not is_instance_valid(companion):
			continue
		KitchenService.release_customer(companion)
		_release_customer_reservations(companion.customer_id)
		_customers.erase(companion.customer_id)
		companion.queue_free()


func _rollback_assigned_dining_companions_for_group(
	group_id: String,
	leader: CustomerEntity
) -> void:
	if group_id == "":
		return
	var rollback_targets: Array[CustomerEntity] = []
	for member: CustomerEntity in _get_active_group_members(group_id):
		if not is_instance_valid(member) or member == leader:
			continue
		if member.is_group_companion_waiting_for_leader:
			continue
		rollback_targets.append(member)
	_rollback_assigned_dining_companions(rollback_targets)


func _clear_all_pending_outside_companions() -> void:
	for group_id: String in _pending_outside_companions.keys():
		_clear_pending_outside_companions(group_id)
	_pending_outside_companions.clear()


func _reposition_all_pending_outside_companions() -> void:
	var slot_index: int = _outside_queue.size()
	for group_id: String in _pending_outside_companions.keys():
		var pending: Array = _pending_outside_companions[group_id]
		if pending.is_empty():
			continue
		var base_position: Vector2 = OutsideViewConstants.outside_queue_position(slot_index)
		for pending_index in range(pending.size()):
			var companion = pending[pending_index]
			if is_instance_valid(companion):
				(companion as OutsideCustomerEntity).reposition_as_group_cluster(
					base_position,
					pending_index
				)
		slot_index += 1
