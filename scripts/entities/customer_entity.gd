class_name CustomerEntity
extends CharacterBody2D

const GroupDiningConstants := preload("res://scripts/core/customer/group_dining_constants.gd")

signal state_changed(state: CustomerStates.Id)
signal finished(customer: CustomerEntity)

const WAYPOINT_TOLERANCE: float = 6.0
const PATH_WAYPOINT_TOLERANCE: float = 2.0
const QUEUE_ARRIVAL_TOLERANCE: float = 14.0
const MIN_EATING_HOURS: float = 0.5
const MAX_EATING_HOURS: float = 1.0
const UNREACHABLE_MOVE_TIMEOUT: float = 5.0
const MAX_PATIENCE: float = 100.0
const PATIENCE_DECAY_WAITING_CHAIR_PER_5_MIN: float = 2.0
const PATIENCE_DECAY_COUNTER_PER_5_MIN: float = 5.0
const PATIENCE_DECAY_FOOD_PER_5_MIN: float = 8.0

@export var move_speed: float = 95.0

var customer_id: String = ""
var view_id: ViewIds.Id = ViewIds.Id.INN_F1
var persona: CustomerPersonas.Id = CustomerPersonas.Id.TRAVELER
var current_state: CustomerStates.Id = CustomerStates.Id.TO_QUEUE_SLOT
var order: Dictionary = {}
var satisfaction: float = 0.75
var patience: float = MAX_PATIENCE
var was_served: bool = false
var counter_position: Vector2 = Vector2.ZERO
var queue_position: Vector2 = Vector2.ZERO
var queue_index: int = 0
var chair_position: Vector2 = Vector2.ZERO
var bed_position: Vector2 = Vector2.ZERO
var exit_position: Vector2 = Vector2.ZERO
var chair_instance_id: String = ""
var waiting_chair_instance_id: String = ""
var bed_instance_id: String = ""
var checkout_day: int = 0
var order_taken: bool = false
var bags_dropped: bool = false
var lodging_meal_available: bool = false
var needs: CustomerNeeds = CustomerNeeds.new()
var is_selected: bool = false
var group_id: String = ""
var group_size: int = 1
var is_group_leader: bool = false
var is_group_highlighted: bool = false
var group_companion_persona: CustomerPersonas.Id = CustomerPersonas.Id.TRAVELER
var is_group_companion_waiting_for_leader: bool = false
var group_meal_finished: bool = false

var _exit_reason: String = ""
var _state_timer: float = 0.0
var _navigation_token: int = 0
var _movement_target: Vector2 = Vector2.ZERO
var _floor_path: Array[Vector2] = []
var _path_retry_timer: float = 0.0
var _food_served: bool = false
var _food_paid: bool = false
var _lodging_paid: bool = false
var _move_stall_timer: float = 0.0
var _unreachable_move_timer: float = 0.0
var _debug_state_label: Label = null
var _facing_direction: Vector2 = Vector2(0.0, 1.0)
var _facing_dir: HumanFigureDrawer.FacingDir = HumanFigureDrawer.FacingDir.DOWN

const DEBUG_LABEL_OFFSET := Vector2(-52.0, -34.0)
const DEBUG_LABEL_WIDTH := 104.0


func _ready() -> void:
	collision_layer = 1 << (GameConstants.COLLISION_LAYER_UNITS - 1)
	collision_mask = (
		(1 << (GameConstants.COLLISION_LAYER_TERRAIN - 1))
		| (1 << (GameConstants.COLLISION_LAYER_FURNITURE - 1))
	)
	add_to_group("customers")
	set_physics_process(false)


func configure(
	p_customer_id: String,
	p_view_id: ViewIds.Id,
	p_persona: CustomerPersonas.Id,
	spawn_position: Vector2,
	p_counter_position: Vector2,
	p_exit_position: Vector2
) -> void:
	customer_id = p_customer_id
	view_id = p_view_id
	persona = p_persona
	counter_position = InnLayoutHelper.exact_floor_world_point(view_id, p_counter_position)
	exit_position = InnLayoutHelper.get_closest_floor_world_point(view_id, p_exit_position)
	global_position = InnLayoutHelper.snap_to_floor_world(view_id, spawn_position)
	_update_depth_sort()
	order = MenuCatalog.pick_service_request(view_id)
	current_state = CustomerStates.Id.TO_QUEUE_SLOT
	order_taken = false
	patience = MAX_PATIENCE
	bags_dropped = false
	lodging_meal_available = false
	checkout_day = 0
	_food_served = false
	_food_paid = false
	_lodging_paid = false
	group_id = ""
	group_size = 1
	is_group_leader = false
	is_group_highlighted = false
	group_companion_persona = CustomerPersonas.Id.TRAVELER
	is_group_companion_waiting_for_leader = false
	group_meal_finished = false
	_exit_reason = ""
	was_served = false
	needs = CustomerNeeds.random_initial()
	if get_order_type() == CustomerOrderTypes.Id.FOOD_AND_LODGING:
		needs = CustomerNeeds.random_initial_for_combo_guest()
	is_selected = false
	_state_timer = 0.0
	_path_retry_timer = 0.0
	_move_stall_timer = 0.0
	_unreachable_move_timer = 0.0
	_floor_path.clear()
	queue_redraw()
	_refresh_debug_state_label()
	sync_debug_visuals()


func start_counter_consultation(p_counter_position: Vector2) -> void:
	queue_index = 0
	queue_position = Vector2.ZERO
	counter_position = InnLayoutHelper.exact_floor_world_point(view_id, p_counter_position)
	if counter_position == Vector2.ZERO:
		counter_position = p_counter_position
	_begin_state(CustomerStates.Id.TO_COUNTER)


func sync_debug_visuals() -> void:
	if DebugService.is_active():
		if _debug_state_label == null:
			_setup_debug_state_label()
		elif _debug_state_label:
			_debug_state_label.show()
	elif _debug_state_label:
		_debug_state_label.hide()


func get_activity_label() -> String:
	if group_meal_finished:
		return "일행 기다리는 중"
	return CustomerStates.activity_label_for(current_state, _food_served)


func get_status_panel_text() -> String:
	var lines: PackedStringArray = []
	lines.append("손님: %s" % customer_id)
	lines.append("분류: %s" % CustomerOrderTypes.customer_label_for(get_order_type()))
	lines.append("인내심: %d/%d" % [int(round(patience)), int(MAX_PATIENCE)])
	lines.append("만족도: %d/100" % int(round(satisfaction * 100.0)))
	var region_aesthetics_text: String = _get_current_region_aesthetics_text()
	if region_aesthetics_text != "":
		lines.append(region_aesthetics_text)
	if group_id != "":
		var role_label: String = "대표" if is_group_leader else "동행"
		lines.append("그룹: %s (%d인, %s)" % [group_id, group_size, role_label])
	else:
		lines.append("그룹: 개인")
	lines.append("상태: %s" % get_activity_label())
	lines.append(needs.format_line("배고픔", needs.hunger))
	lines.append(needs.format_line("수면", needs.sleep))
	lines.append(needs.format_line("피로", needs.fatigue))
	lines.append(needs.format_line("청결", needs.cleanliness))
	lines.append(needs.format_line("재미", needs.fun))
	lines.append(needs.format_line("체력", needs.health))
	return "\n".join(lines)


func get_panel_title() -> String:
	if (
		group_id != ""
		and group_size >= GroupDiningConstants.MIN_GROUP_SIZE
	):
		var role_label: String = "대표" if is_group_leader else "동행"
		return "%s · %d인 %s" % [customer_id, group_size, role_label]
	return customer_id


func _get_food_quality_satisfaction_bonus() -> float:
	return FoodQuality.satisfaction_bonus_for(FoodQuality.from_value(order.get("quality")))


func _get_current_region_aesthetics_text() -> String:
	var seat_position: Vector2 = Vector2.ZERO
	match current_state:
		CustomerStates.Id.EATING:
			seat_position = chair_position
		CustomerStates.Id.SLEEPING, CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			seat_position = bed_position
		_:
			return ""
	if seat_position == Vector2.ZERO:
		return ""
	return "구역 미관: %s" % RoomAestheticsService.get_aesthetics_label_at_world_position(view_id, seat_position)


func _apply_region_aesthetics(seat_position: Vector2) -> void:
	if seat_position == Vector2.ZERO:
		return
	var score: float = RoomAestheticsService.get_aesthetics_at_world_position(view_id, seat_position)
	var bonus: float = RoomAestheticsService.satisfaction_bonus_for(score)
	if bonus == 0.0:
		return
	satisfaction = clampf(satisfaction + bonus, 0.0, 1.0)


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func set_group_highlighted(highlighted: bool) -> void:
	is_group_highlighted = highlighted
	queue_redraw()


func contains_world_point(world_position: Vector2) -> bool:
	var local_position: Vector2 = to_local(world_position)
	var hit_rect := Rect2(-12.0, -24.0, 24.0, 30.0)
	return hit_rect.has_point(local_position)


func get_debug_status_text() -> String:
	var text: String = "%s\n%s" % [
		CustomerOrderTypes.customer_label_for(get_order_type()),
		CustomerStates.label_for(current_state),
	]
	if current_state in [
		CustomerStates.Id.TO_QUEUE_SLOT,
		CustomerStates.Id.WAITING_IN_QUEUE,
		CustomerStates.Id.WAITING_AT_COUNTER,
		CustomerStates.Id.TO_COUNTER,
		CustomerStates.Id.REQUEST_PENDING,
	]:
		text += " #%d" % (queue_index + 1)
	if order_taken:
		text += "\n[주문접수]"
	elif current_state in [CustomerStates.Id.WAITING_AT_COUNTER, CustomerStates.Id.REQUEST_PENDING]:
		text += "\n[주문대기]"
	return text


func _setup_debug_state_label() -> void:
	_debug_state_label = Label.new()
	_debug_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_state_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_debug_state_label.position = DEBUG_LABEL_OFFSET
	_debug_state_label.custom_minimum_size = Vector2(DEBUG_LABEL_WIDTH, 0.0)
	_debug_state_label.add_theme_font_size_override("font_size", 9)
	_debug_state_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_debug_state_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_debug_state_label.add_theme_constant_override("outline_size", 3)
	_debug_state_label.z_index = 10
	add_child(_debug_state_label)
	state_changed.connect(_refresh_debug_state_label)
	_refresh_debug_state_label()


func _refresh_debug_state_label(_unused = null) -> void:
	if _debug_state_label == null:
		return
	var next_text: String = get_debug_status_text()
	if _debug_state_label.text == next_text:
		return
	_debug_state_label.text = next_text


func get_order_type() -> CustomerOrderTypes.Id:
	return order.get("order_type", CustomerOrderTypes.Id.FOOD) as CustomerOrderTypes.Id


func _resolve_exit_reason() -> String:
	if not _exit_reason.is_empty():
		return _exit_reason
	return _success_exit_reason()


func _success_exit_reason() -> String:
	var order_type: CustomerOrderTypes.Id = get_order_type()
	if CustomerOrderTypes.needs_lodging(order_type) and _lodging_paid:
		return CustomerExitReasons.SUCCESS_LODGING
	if CustomerOrderTypes.needs_food(order_type) and _food_paid:
		return CustomerExitReasons.SUCCESS_MEAL
	return CustomerExitReasons.SUCCESS_NORMAL


func should_persist_overnight() -> bool:
	if get_order_type() == CustomerOrderTypes.Id.FOOD_AND_LODGING:
		return current_state in [
			CustomerStates.Id.SLEEPING,
			CustomerStates.Id.TO_BED,
			CustomerStates.Id.TO_BED_AFTER_MEAL,
			CustomerStates.Id.DROPPING_BAGS,
			CustomerStates.Id.TO_CHAIR,
			CustomerStates.Id.EATING,
		]
	return current_state in [
		CustomerStates.Id.SLEEPING,
		CustomerStates.Id.TO_BED,
		CustomerStates.Id.TO_BED_AFTER_MEAL,
		CustomerStates.Id.DROPPING_BAGS,
	]


func should_checkout_on_day(day: int) -> bool:
	return current_state == CustomerStates.Id.SLEEPING and checkout_day > 0 and day >= checkout_day


func on_order_accepted(
	p_chair_position: Vector2,
	p_bed_position: Vector2,
	p_chair_instance_id: String,
	p_bed_instance_id: String
) -> void:
	order_taken = true
	chair_position = InnLayoutHelper.exact_customer_world_point(view_id, p_chair_position)
	bed_position = InnLayoutHelper.exact_customer_world_point(view_id, p_bed_position)
	chair_instance_id = p_chair_instance_id
	bed_instance_id = p_bed_instance_id
	_refresh_debug_state_label()

	match get_order_type():
		CustomerOrderTypes.Id.FOOD:
			_begin_state(CustomerStates.Id.TO_CHAIR)
		CustomerOrderTypes.Id.LODGING:
			_complete_lodging_payment()
			bags_dropped = false
			_begin_state(CustomerStates.Id.TO_BED)
		CustomerOrderTypes.Id.FOOD_AND_LODGING:
			_complete_lodging_payment()
			bags_dropped = false
			lodging_meal_available = true
			was_served = false
			_food_served = false
			_begin_state(CustomerStates.Id.TO_BED)


func prepare_queue_slot(index: int, slot_position: Vector2) -> void:
	queue_index = index
	if slot_position == Vector2.ZERO:
		queue_position = Vector2.ZERO
		return
	var coord: GridCoord = GridCoord.from_local(view_id, slot_position)
	if InnLayoutHelper.is_customer_walkable(coord):
		queue_position = coord.to_world_center()
	else:
		queue_position = InnLayoutHelper.exact_customer_world_point(view_id, slot_position)
	_refresh_debug_state_label()


func is_at_assigned_queue_slot() -> bool:
	if queue_position == Vector2.ZERO:
		return false
	return global_position.distance_to(queue_position) <= QUEUE_ARRIVAL_TOLERANCE


func promote_to_counter_wait() -> void:
	if queue_index != 0:
		return
	_begin_state(CustomerStates.Id.WAITING_AT_COUNTER)


func update_queue_slot(index: int, slot_position: Vector2) -> bool:
	var next_position: Vector2 = slot_position
	if slot_position != Vector2.ZERO:
		var coord: GridCoord = GridCoord.from_local(view_id, slot_position)
		if InnLayoutHelper.is_customer_walkable(coord):
			next_position = coord.to_world_center()
		else:
			next_position = InnLayoutHelper.exact_customer_world_point(view_id, slot_position)
	var index_changed := queue_index != index
	var position_changed := queue_position.distance_to(next_position) > 1.0
	queue_index = index
	queue_position = next_position
	_refresh_debug_state_label()
	if current_state in [
		CustomerStates.Id.TO_CHAIR,
		CustomerStates.Id.TO_BED,
		CustomerStates.Id.TO_BED_AFTER_MEAL,
		CustomerStates.Id.DROPPING_BAGS,
		CustomerStates.Id.EATING,
		CustomerStates.Id.SLEEPING,
		CustomerStates.Id.LEAVING,
		CustomerStates.Id.DONE,
	]:
		return false

	if not index_changed and not position_changed:
		return false

	if index == 0 and is_at_assigned_queue_slot():
		if current_state != CustomerStates.Id.WAITING_AT_COUNTER:
			_begin_state(CustomerStates.Id.WAITING_AT_COUNTER)
		return true

	_begin_state(CustomerStates.Id.TO_QUEUE_SLOT)
	return false


func on_order_rejected(reason: String = "주문을 처리할 수 없습니다.") -> void:
	satisfaction = clampf(satisfaction - 0.35, 0.0, 1.0)
	_exit_reason = reason
	EventBus.customer_order_rejected.emit(self, reason)
	_begin_state(CustomerStates.Id.LEAVING)


func on_table_missing() -> void:
	satisfaction = clampf(satisfaction - 0.4, 0.0, 1.0)
	_exit_reason = CustomerExitReasons.TABLE_MISSING
	_begin_state(CustomerStates.Id.LEAVING)


func checkout() -> void:
	if current_state != CustomerStates.Id.SLEEPING:
		return
	_complete_payment()
	_begin_state(CustomerStates.Id.LEAVING)


func mark_served() -> void:
	if was_served or current_state != CustomerStates.Id.EATING:
		return
	was_served = true
	_food_served = true
	group_meal_finished = false
	TableFoodService.place_food(self)
	var kitchen_bonus: float = KitchenUpgradeService.get_satisfaction_bonus(view_id)
	var food_quality_bonus: float = _get_food_quality_satisfaction_bonus()
	satisfaction = clampf(satisfaction + 0.18 + kitchen_bonus + food_quality_bonus, 0.0, 1.0)
	_state_timer = randf_range(MIN_EATING_HOURS, MAX_EATING_HOURS) * GameClock.SECONDS_PER_HOUR
	_update_physics_active()


func complete_group_food_exit() -> void:
	if current_state != CustomerStates.Id.EATING:
		return
	if not group_meal_finished:
		return
	group_meal_finished = false
	_complete_food_payment()
	_add_review()
	_begin_state(CustomerStates.Id.LEAVING)


func activate() -> void:
	_update_physics_active()
	if current_state == CustomerStates.Id.TO_COUNTER:
		_begin_state(CustomerStates.Id.TO_COUNTER)
	elif CustomerStates.is_queue_walking(current_state):
		_begin_state(CustomerStates.Id.TO_QUEUE_SLOT)
	elif CustomerStates.is_moving(current_state):
		call_deferred("_restart_navigation_for_state")


func restart_movement_if_needed() -> void:
	if not is_physics_processing():
		return
	if CustomerStates.is_moving(current_state):
		_restart_navigation_for_state()


func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	_navigation_token += 1
	_movement_target = Vector2.ZERO
	_floor_path.clear()


func _restart_navigation_for_state() -> void:
	match current_state:
		CustomerStates.Id.TO_COUNTER:
			_schedule_navigation(counter_position)
		CustomerStates.Id.TO_QUEUE_SLOT:
			_schedule_navigation(_get_queue_target_position())
		CustomerStates.Id.TO_CHAIR:
			_schedule_navigation(chair_position)
		CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			_schedule_navigation(bed_position)
		CustomerStates.Id.LEAVING:
			_schedule_navigation(exit_position)


func _schedule_navigation(world_position: Vector2) -> void:
	if world_position == Vector2.ZERO:
		return
	_navigation_token += 1
	var token: int = _navigation_token
	CustomerService.enqueue_path_build(self, world_position, token)


func build_floor_path(world_position: Vector2, token: int) -> void:
	if not is_physics_processing():
		return
	if token != _navigation_token:
		return

	var target: Vector2 = _resolve_move_target(world_position)
	if target == Vector2.ZERO:
		return
	if _movement_target.distance_to(target) <= 1.0 and not _floor_path.is_empty():
		return

	_movement_target = target
	_floor_path = FloorPathfinder.find_path(view_id, global_position, target)
	_path_retry_timer = 0.0
	_move_stall_timer = 0.0

	if _floor_path.is_empty():
		var arrival_tolerance: float = (
			QUEUE_ARRIVAL_TOLERANCE
			if CustomerStates.is_queue_walking(current_state)
			else WAYPOINT_TOLERANCE
		)
		if global_position.distance_to(target) <= arrival_tolerance:
			global_position = target
			_snap_to_floor()
			_on_move_finished()
		return

	_unreachable_move_timer = 0.0
	_snap_to_floor()


func _begin_state(state: CustomerStates.Id) -> void:
	if current_state == state:
		if state == CustomerStates.Id.WAITING_AT_COUNTER and not order_taken:
			StaffService.schedule_work()
		elif state == CustomerStates.Id.TO_QUEUE_SLOT:
			_update_physics_active()
			_start_navigation_for_state(state)
		elif state in [
			CustomerStates.Id.WAITING_IN_QUEUE,
			CustomerStates.Id.WAITING_AT_COUNTER,
		]:
			return
	current_state = state
	_state_timer = 0.0
	state_changed.emit(state)
	match state:
		CustomerStates.Id.TO_COUNTER:
			_floor_path.clear()
			_movement_target = Vector2.ZERO
		CustomerStates.Id.REQUEST_PENDING:
			_floor_path.clear()
			_movement_target = Vector2.ZERO
			CustomerService.on_customer_request_pending(self)
		CustomerStates.Id.TO_QUEUE_SLOT:
			_floor_path.clear()
			_movement_target = Vector2.ZERO
		CustomerStates.Id.WAITING_IN_QUEUE:
			_floor_path.clear()
			_movement_target = Vector2.ZERO
		CustomerStates.Id.WAITING_AT_COUNTER:
			_floor_path.clear()
			_movement_target = Vector2.ZERO
			StaffService.schedule_work()
		CustomerStates.Id.TO_CHAIR:
			pass
		CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			pass
		CustomerStates.Id.DROPPING_BAGS:
			_floor_path.clear()
			_state_timer = 1.2
			bags_dropped = true
		CustomerStates.Id.EATING:
			_floor_path.clear()
			_food_served = false
			_apply_region_aesthetics(chair_position)
			if get_order_type() == CustomerOrderTypes.Id.FOOD and not GameClock.is_open_hours():
				call_deferred("_serve_food_after_closing")
		CustomerStates.Id.SLEEPING:
			_floor_path.clear()
			_apply_region_aesthetics(bed_position)
			checkout_day = GameTimeManager.current_day + 1
		CustomerStates.Id.LEAVING:
			pass
		CustomerStates.Id.DONE:
			DayStatsService.record_exit_reason(_resolve_exit_reason())
			finished.emit(self)
	_update_physics_active()
	_start_navigation_for_state(state)


func _serve_food_after_closing() -> void:
	if current_state != CustomerStates.Id.EATING:
		return
	if get_order_type() != CustomerOrderTypes.Id.FOOD:
		return
	if GameClock.is_open_hours():
		return
	mark_served()


func _should_sync_group_food_exit() -> bool:
	return (
		group_id != ""
		and group_size > 1
		and get_order_type() == CustomerOrderTypes.Id.FOOD
	)


func _start_navigation_for_state(state: CustomerStates.Id) -> void:
	if not is_physics_processing():
		return
	match state:
		CustomerStates.Id.TO_COUNTER:
			_schedule_navigation(counter_position)
		CustomerStates.Id.TO_QUEUE_SLOT:
			_schedule_navigation(_get_queue_target_position())
		CustomerStates.Id.TO_CHAIR:
			_schedule_navigation(chair_position)
		CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			_schedule_navigation(bed_position)
		CustomerStates.Id.LEAVING:
			_schedule_navigation(exit_position)
		_:
			pass


func _update_physics_active() -> void:
	var should_run: bool = false
	match current_state:
		CustomerStates.Id.TO_COUNTER, CustomerStates.Id.TO_QUEUE_SLOT, CustomerStates.Id.TO_CHAIR, CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL, CustomerStates.Id.LEAVING, CustomerStates.Id.DROPPING_BAGS:
			should_run = true
		CustomerStates.Id.EATING:
			should_run = _food_served and not group_meal_finished
		_:
			should_run = false
	set_physics_process(should_run)


func _complete_payment() -> void:
	var base_price: int = 0
	if CustomerOrderTypes.needs_lodging(get_order_type()) and not _lodging_paid:
		base_price = int(order.get("lodging_price", order.get("price", 8)))
		_lodging_paid = true
	elif CustomerOrderTypes.needs_food(get_order_type()) and not _food_paid:
		base_price = int(order.get("food_price", order.get("price", 3)))
		_food_paid = true
	if base_price <= 0:
		_add_review()
		return

	var theme_bonus: float = 1.0
	if ThemeService.get_theme_id_for_view(view_id) == "rustic":
		theme_bonus = 1.05
	var tip: int = int(round(float(base_price) * satisfaction * CustomerPersonas.tip_multiplier(persona) * theme_bonus * 0.25))
	var total: int = base_price + tip
	EconomyManager.record_sale(total)
	_add_review()


func _complete_lodging_payment() -> void:
	if _lodging_paid:
		return
	var lodging_price: int = int(order.get("lodging_price", 8))
	if lodging_price <= 0:
		return
	_lodging_paid = true
	EconomyManager.record_sale(lodging_price)
	DayStatsService.record_lodging()
	_show_income_text(lodging_price)


func _complete_food_payment() -> void:
	if _food_paid:
		return
	var food_price: int = int(order.get("food_price", order.get("price", 3)))
	if food_price <= 0:
		return
	_food_paid = true
	EconomyManager.record_sale(food_price)
	DayStatsService.record_meal()
	_show_income_text(food_price)


func _add_review() -> void:
	var patience_score: float = clampf(patience / MAX_PATIENCE, 0.0, 1.0)
	var experience_score: float = patience_score * 0.45 + satisfaction * 0.55
	var rating: float = clampf(1.0 + experience_score * 4.0, 1.0, 5.0)
	if CustomerOrderTypes.needs_food(get_order_type()) and not was_served:
		rating = clampf(rating - 0.35, 1.0, 5.0)
	var guest_name: String = "%s %s" % [CustomerPersonas.label_for(persona), customer_id]
	var comment: String = _build_review_comment(rating)
	ReputationManager.add_review(rating, guest_name, comment)
	EventBus.customer_reviewed.emit(self, rating, comment)


func _show_income_text(amount: int) -> void:
	if amount <= 0:
		return
	var label := Label.new()
	label.text = "+%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-32.0, -46.0)
	label.custom_minimum_size = Vector2(64.0, 18.0)
	label.z_index = 100
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.35, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.finished.connect(label.queue_free)


func _build_review_comment(rating: float) -> String:
	if rating >= 4.5:
		return "Warm service and a cozy stop on the road."
	if rating >= 3.5:
		return "Good meal, would visit again."
	if rating >= 2.5:
		return "Acceptable, but the inn could use polish."
	return "Too crowded and not worth the coin."


func _physics_process(delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		velocity = Vector2.ZERO
		_update_depth_sort()
		return

	var scaled_delta: float = GameTimeManager.scaled_delta(delta)

	if current_state == CustomerStates.Id.DROPPING_BAGS:
		_state_timer -= scaled_delta
		if _state_timer <= 0.0:
			_begin_state(CustomerStates.Id.SLEEPING)
		_update_depth_sort()
		return

	if current_state == CustomerStates.Id.EATING:
		if group_meal_finished:
			_update_depth_sort()
			return
		if not _food_served:
			_update_depth_sort()
			return
		_state_timer -= scaled_delta
		if _state_timer <= 0.0:
			TableFoodService.clear_food(self)
			FilthService.spawn_empty_bowl_at_table(view_id, chair_instance_id)
			if _should_sync_group_food_exit():
				group_meal_finished = true
				CustomerService.on_group_member_meal_finished(self)
				_update_physics_active()
				_update_depth_sort()
				return
			_complete_food_payment()
			if get_order_type() == CustomerOrderTypes.Id.FOOD_AND_LODGING:
				_begin_state(CustomerStates.Id.TO_BED_AFTER_MEAL)
			else:
				_add_review()
				_begin_state(CustomerStates.Id.LEAVING)
		_update_depth_sort()
		return

	if CustomerStates.is_moving(current_state):
		if _floor_path.is_empty() and _movement_target == Vector2.ZERO:
			_move_stall_timer += scaled_delta
			if _move_stall_timer >= 0.5:
				_move_stall_timer = 0.0
				var retry_target: Vector2 = _get_move_retry_target()
				if retry_target != Vector2.ZERO:
					_schedule_navigation(retry_target)
		else:
			_move_stall_timer = 0.0
		_process_floor_movement(delta)
	_update_depth_sort()


func tick_needs(delta: float) -> void:
	_tick_patience(delta)

	var hunger_rate: float = 1.2
	var sleep_rate: float = 1.0
	var fatigue_rate: float = 1.4
	var cleanliness_rate: float = 0.35
	var fun_rate: float = 1.1

	match current_state:
		CustomerStates.Id.SLEEPING:
			needs.sleep += 8.0 * delta
			needs.fatigue += 6.0 * delta
			hunger_rate = 0.4
			fatigue_rate = 0.0
		CustomerStates.Id.EATING:
			if _food_served:
				needs.hunger += 10.0 * delta
				needs.fun += 4.0 * delta
				hunger_rate = 0.0
				fun_rate = 0.0
			else:
				fun_rate = 2.0
		CustomerStates.Id.REQUEST_PENDING, CustomerStates.Id.WAITING_IN_QUEUE, CustomerStates.Id.WAITING_AT_COUNTER:
			fun_rate = 2.4
			fatigue_rate = 0.8
		CustomerStates.Id.DROPPING_BAGS:
			needs.fatigue += 2.0 * delta
			fatigue_rate = 0.0
		CustomerStates.Id.LEAVING, CustomerStates.Id.DONE:
			return

	if CustomerStates.is_moving(current_state):
		fatigue_rate += 0.8
		cleanliness_rate += 0.15

	needs.hunger -= hunger_rate * delta
	needs.sleep -= sleep_rate * delta
	needs.fatigue -= fatigue_rate * delta
	needs.cleanliness -= cleanliness_rate * delta
	needs.fun -= fun_rate * delta

	var average_need: float = (
		needs.hunger + needs.sleep + needs.fatigue + needs.cleanliness + needs.fun
	) / 5.0
	if average_need < 35.0:
		needs.health -= 2.5 * delta
	elif average_need > 70.0:
		needs.health += 1.0 * delta

	needs.clamp_all()
	_try_request_lodging_meal()


func _tick_patience(delta: float) -> void:
	if patience <= 0.0:
		return
	var decay_per_5_minutes: float = _get_patience_decay_per_5_minutes()
	if decay_per_5_minutes <= 0.0:
		return

	var game_minutes: float = delta / maxf(GameClock.SECONDS_PER_HOUR, 0.001) * 60.0
	var decay: float = decay_per_5_minutes * game_minutes / 5.0
	if decay <= 0.0:
		return

	patience = clampf(patience - decay, 0.0, MAX_PATIENCE)
	if patience <= 0.0:
		CustomerService.on_customer_patience_depleted(self)


func _get_patience_decay_per_5_minutes() -> float:
	match current_state:
		CustomerStates.Id.WAITING_IN_QUEUE:
			if waiting_chair_instance_id != "":
				return PATIENCE_DECAY_WAITING_CHAIR_PER_5_MIN
		CustomerStates.Id.REQUEST_PENDING, CustomerStates.Id.WAITING_AT_COUNTER:
			return PATIENCE_DECAY_COUNTER_PER_5_MIN
		CustomerStates.Id.EATING:
			if not _food_served and not group_meal_finished:
				return PATIENCE_DECAY_FOOD_PER_5_MIN
	return 0.0


func _try_request_lodging_meal() -> void:
	if get_order_type() != CustomerOrderTypes.Id.FOOD_AND_LODGING:
		return
	if not GameClock.is_open_hours():
		return
	if current_state != CustomerStates.Id.SLEEPING:
		return
	if not lodging_meal_available:
		return
	if needs.hunger > CustomerNeeds.LODGING_MEAL_HUNGER_THRESHOLD:
		return
	if chair_position == Vector2.ZERO or chair_instance_id == "":
		return
	if not KitchenService.can_cook_order(self):
		return

	lodging_meal_available = false
	was_served = false
	_food_served = false
	KitchenService.enqueue_pending(self)
	_begin_state(CustomerStates.Id.TO_CHAIR)


func _get_move_retry_target() -> Vector2:
	match current_state:
		CustomerStates.Id.TO_COUNTER:
			return counter_position
		CustomerStates.Id.TO_QUEUE_SLOT:
			return _get_queue_target_position()
		CustomerStates.Id.TO_CHAIR:
			return chair_position
		CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			return bed_position
		CustomerStates.Id.LEAVING:
			return exit_position
		_:
			return Vector2.ZERO


func _process_floor_movement(delta: float) -> void:
	var arrival_tolerance: float = (
		QUEUE_ARRIVAL_TOLERANCE
		if CustomerStates.is_queue_walking(current_state)
		else WAYPOINT_TOLERANCE
	)
	if _floor_path.is_empty():
		if _movement_target != Vector2.ZERO and global_position.distance_to(_movement_target) <= arrival_tolerance:
			_snap_to_floor()
			_on_move_finished()
			return
		if _movement_target != Vector2.ZERO:
			_path_retry_timer += GameTimeManager.scaled_delta(delta)
			_unreachable_move_timer += GameTimeManager.scaled_delta(delta)
			if _unreachable_move_timer >= UNREACHABLE_MOVE_TIMEOUT:
				_handle_unreachable_move_target()
				return
			if _path_retry_timer >= 0.75:
				_path_retry_timer = 0.0
				_schedule_navigation(_movement_target)
		velocity = Vector2.ZERO
		return

	var next_waypoint: Vector2 = _floor_path[0]
	_unreachable_move_timer = 0.0
	var distance_to_waypoint: float = global_position.distance_to(next_waypoint)
	var direction: Vector2 = global_position.direction_to(next_waypoint)
	if direction.length_squared() > 0.0001:
		_facing_direction = direction
		var next_facing_dir: HumanFigureDrawer.FacingDir = HumanFigureDrawer.resolve_facing_dir(direction)
		if next_facing_dir != _facing_dir:
			_facing_dir = next_facing_dir
			queue_redraw()
		var scaled_speed: float = move_speed * GameTimeManager.time_scale
		velocity = direction * minf(scaled_speed, distance_to_waypoint / maxf(delta, 0.0001))
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if global_position.distance_to(next_waypoint) <= PATH_WAYPOINT_TOLERANCE:
		_floor_path.pop_front()
		if _floor_path.is_empty():
			_snap_to_floor()
			_on_move_finished()


func _handle_unreachable_move_target() -> void:
	_path_retry_timer = 0.0
	_unreachable_move_timer = 0.0
	_movement_target = Vector2.ZERO
	_floor_path.clear()
	match current_state:
		CustomerStates.Id.TO_COUNTER, CustomerStates.Id.TO_QUEUE_SLOT:
			CustomerService.unregister_waiting_customer(self)
			on_order_rejected("카운터로 가는 길이 막혀 있습니다.")
		CustomerStates.Id.TO_CHAIR, CustomerStates.Id.TO_BED, CustomerStates.Id.TO_BED_AFTER_MEAL:
			on_order_rejected("배정된 자리로 갈 수 없습니다.")
		CustomerStates.Id.LEAVING:
			_begin_state(CustomerStates.Id.DONE)
		_:
			pass


func _resolve_move_target(world_position: Vector2) -> Vector2:
	if current_state in [
		CustomerStates.Id.TO_QUEUE_SLOT,
		CustomerStates.Id.TO_CHAIR,
		CustomerStates.Id.TO_BED,
		CustomerStates.Id.TO_BED_AFTER_MEAL,
	]:
		return InnLayoutHelper.exact_customer_world_point(view_id, world_position)
	return InnLayoutHelper.exact_floor_world_point(view_id, world_position)


func _snap_to_floor() -> void:
	var coord: GridCoord = GridCoord.from_local(view_id, global_position)
	if InnLayoutHelper.is_customer_walkable(coord):
		global_position = coord.to_world_center()
		_update_depth_sort()
		return
	var snapped: Vector2 = InnLayoutHelper.get_closest_customer_walkable_point(view_id, global_position)
	if snapped != Vector2.ZERO:
		global_position = snapped
		_update_depth_sort()
		return
	snapped = InnLayoutHelper.get_closest_floor_world_point(view_id, global_position)
	if snapped != Vector2.ZERO:
		global_position = snapped
	_update_depth_sort()


func _get_queue_target_position() -> Vector2:
	if queue_position != Vector2.ZERO:
		return queue_position
	if queue_index == 0:
		return counter_position
	return global_position


func _on_move_finished() -> void:
	match current_state:
		CustomerStates.Id.TO_COUNTER:
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			_begin_state(CustomerStates.Id.REQUEST_PENDING)
		CustomerStates.Id.TO_QUEUE_SLOT:
			satisfaction = 0.72 if InnLayoutHelper.is_customer_walkable(GridCoord.from_local(view_id, global_position)) else 0.55
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			if queue_index == 0:
				_begin_state(CustomerStates.Id.WAITING_AT_COUNTER)
			else:
				_begin_state(CustomerStates.Id.WAITING_IN_QUEUE)
		CustomerStates.Id.TO_CHAIR:
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			if not InnLayoutHelper.chair_has_table(view_id, chair_instance_id):
				on_table_missing()
				return
			if FilthService.is_dining_chair_blocked(view_id, chair_instance_id):
				on_order_rejected("테이블에 빈 그릇이 남아 있습니다.")
				return
			_begin_state(CustomerStates.Id.EATING)
		CustomerStates.Id.TO_BED:
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			if get_order_type() == CustomerOrderTypes.Id.FOOD_AND_LODGING and not bags_dropped:
				_begin_state(CustomerStates.Id.DROPPING_BAGS)
			else:
				_begin_state(CustomerStates.Id.SLEEPING)
		CustomerStates.Id.TO_BED_AFTER_MEAL:
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			_begin_state(CustomerStates.Id.SLEEPING)
		CustomerStates.Id.LEAVING:
			_movement_target = Vector2.ZERO
			_floor_path.clear()
			_begin_state(CustomerStates.Id.DONE)


func _draw() -> void:
	var style: HumanFigureDrawer.FigureStyle = HumanFigureDrawer.style_for_customer(
		persona,
		get_order_type()
	)
	HumanFigureDrawer.draw(self, _facing_direction, style, is_selected, is_group_highlighted)


func _update_depth_sort() -> void:
	TopdownDepthSort.apply_for_actor(self, view_id, TopdownDepthSort.ENTITY_OFFSET)
