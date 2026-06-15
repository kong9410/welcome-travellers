extends Node

const INNKEEPER_SCENE: PackedScene = preload("res://scenes/entities/innkeeper_entity.tscn")

var innkeeper: InnkeeperEntity = null

var _job_queue: Array[StaffJob] = []
var _work_schedule_pending: bool = false


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.grid_loaded.connect(_on_grid_loaded)
	EventBus.navigation_map_ready.connect(_on_navigation_map_ready)
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	EventBus.furniture_placed.connect(_on_furniture_changed)
	EventBus.furniture_removed.connect(_on_furniture_changed)


func get_innkeeper() -> InnkeeperEntity:
	return innkeeper


func ensure_innkeeper() -> void:
	if is_instance_valid(innkeeper):
		return
	if not NavService.is_map_synchronized(ViewIds.Id.INN_F1):
		return

	_ensure_owner_room_setup()

	var view: ViewRoot = ViewManager.get_view(ViewIds.Id.INN_F1)
	if view == null:
		return

	var spawn_position: Vector2 = InnLayoutHelper.find_owner_room_position(ViewIds.Id.INN_F1)
	if spawn_position == Vector2.ZERO:
		spawn_position = GridCoord.new(3, 3, ViewIds.Id.INN_F1).to_world_center()

	innkeeper = INNKEEPER_SCENE.instantiate() as InnkeeperEntity
	innkeeper.name = "Innkeeper"
	view.entity_layer.add_child(innkeeper)
	innkeeper.configure(ViewIds.Id.INN_F1, spawn_position)
	innkeeper.job_finished.connect(_on_innkeeper_job_finished)
	innkeeper.task_changed.connect(_on_innkeeper_task_changed)
	innkeeper.call_deferred("activate")
	_apply_shift_state(true)


func schedule_work() -> void:
	if _work_schedule_pending:
		return
	_work_schedule_pending = true
	call_deferred("_run_scheduled_work")


func _run_scheduled_work() -> void:
	_work_schedule_pending = false
	_try_assign_next_job()


func on_kitchen_order_ready() -> void:
	schedule_work()


func request_take_order(_customer: CustomerEntity) -> void:
	schedule_work()


func enqueue_clean(seat_position: Vector2) -> void:
	if CustomerService.has_pending_counter_service():
		return
	if KitchenService.has_cook_queue() or KitchenService.has_serve_queue():
		return
	var clean_position: Vector2 = InnLayoutHelper.get_clean_position(ViewIds.Id.INN_F1, seat_position)
	if clean_position == Vector2.ZERO:
		return
	_enqueue_job(StaffJob.new(StaffTasks.Id.CLEAN, clean_position))


func _try_assign_next_job() -> void:
	if not is_instance_valid(innkeeper) or innkeeper.is_busy():
		return
	if not GameTimeManager.is_time_flowing() or not GameClock.is_work_hours():
		return

	match _resolve_duty_state(innkeeper.current_task):
		"cook":
			_apply_cook_state_rules()
		"serve":
			_apply_serve_state_rules()
		_:
			_apply_counter_state_rules()


func _resolve_duty_state(task: StaffTasks.Id) -> String:
	match task:
		StaffTasks.Id.COOK:
			return "cook"
		StaffTasks.Id.SERVE:
			return "serve"
		_:
			return "counter"


func _apply_cook_state_rules() -> void:
	if KitchenService.has_cook_queue():
		if KitchenService.can_start_cooking():
			var pending_customer: CustomerEntity = KitchenService.peek_pending_customer()
			if pending_customer != null:
				_assign_cook_job(pending_customer)
				return
		_hold_cook_if_needed()
		return

	if KitchenService.has_serve_queue():
		var serve_customer: CustomerEntity = KitchenService.peek_ready_customer()
		if serve_customer != null:
			_assign_serve_job(serve_customer)
			return

	if _has_clean_jobs():
		_try_assign_clean_job()
		return

	_ensure_innkeeper_at_counter(true)


func _apply_serve_state_rules() -> void:
	if KitchenService.has_serve_queue():
		var serve_customer: CustomerEntity = KitchenService.peek_ready_customer()
		if serve_customer != null:
			_assign_serve_job(serve_customer)
			return

	if KitchenService.has_cook_queue():
		if KitchenService.can_start_cooking():
			var pending_customer: CustomerEntity = KitchenService.peek_pending_customer()
			if pending_customer != null:
				_assign_cook_job(pending_customer)
				return
		_hold_cook_if_needed()
		return

	if _has_clean_jobs():
		_try_assign_clean_job()
		return

	_ensure_innkeeper_at_counter(true)


func _apply_counter_state_rules() -> void:
	if CustomerService.has_pending_counter_service():
		var ready_customer: CustomerEntity = CustomerService.get_customer_ready_for_order()
		if ready_customer != null and _assign_take_order_job(ready_customer):
			return
		_ensure_innkeeper_at_counter(true)
		return

	if KitchenService.has_serve_queue():
		var serve_customer: CustomerEntity = KitchenService.peek_ready_customer()
		if serve_customer != null:
			_assign_serve_job(serve_customer)
			return

	if KitchenService.has_cook_queue():
		if KitchenService.can_start_cooking():
			var pending_customer: CustomerEntity = KitchenService.peek_pending_customer()
			if pending_customer != null:
				_assign_cook_job(pending_customer)
				return
		_hold_cook_if_needed()
		return

	_try_assign_clean_job()
	_ensure_innkeeper_at_counter()


func _hold_cook_if_needed() -> void:
	if not is_instance_valid(innkeeper) or innkeeper.is_busy():
		return
	if innkeeper.current_task == StaffTasks.Id.COOK:
		return
	innkeeper.hold_cook_state()


func _assign_take_order_job(customer: CustomerEntity) -> bool:
	var counter_position: Vector2 = InnLayoutHelper.find_counter_position(ViewIds.Id.INN_F1)
	if counter_position == Vector2.ZERO:
		return false
	innkeeper.assign_job(StaffJob.new(StaffTasks.Id.TAKE_ORDER, counter_position, customer))
	return true


func _assign_serve_job(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	var serve_position: Vector2 = KitchenService.get_serve_position(customer)
	if serve_position == Vector2.ZERO:
		serve_position = customer.global_position
	innkeeper.assign_job(StaffJob.new(StaffTasks.Id.SERVE, serve_position, customer))


func _assign_cook_job(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	var view_id: ViewIds.Id = ViewIds.Id.INN_F1
	var waypoints: Array[Vector2] = InnLayoutHelper.get_kitchen_patrol_points(view_id)
	var start_position: Vector2 = waypoints[0] if not waypoints.is_empty() else Vector2.ZERO
	if start_position == Vector2.ZERO:
		start_position = InnLayoutHelper.find_interior_fallback_position(view_id)
	innkeeper.assign_job(
		StaffJob.new(StaffTasks.Id.COOK, start_position, customer, waypoints)
	)


func _enqueue_job(job: StaffJob) -> void:
	for queued: StaffJob in _job_queue:
		if queued.task == job.task and queued.target_position.distance_to(job.target_position) < 4.0:
			return
	_job_queue.append(job)
	schedule_work()


func _try_assign_clean_job() -> void:
	if _job_queue.is_empty():
		return
	_job_queue.sort_custom(_sort_jobs)
	innkeeper.assign_job(_job_queue.pop_front())


func _has_clean_jobs() -> bool:
	return not _job_queue.is_empty()


func has_kitchen_queue_work() -> bool:
	return KitchenService.has_cook_queue() or KitchenService.has_serve_queue()


func _ensure_innkeeper_at_counter(force: bool = false) -> void:
	if not is_instance_valid(innkeeper) or innkeeper.is_busy():
		return
	var counter_position: Vector2 = InnLayoutHelper.find_counter_position(ViewIds.Id.INN_F1)
	if counter_position != Vector2.ZERO:
		innkeeper.go_counter(counter_position, force)


func _sort_jobs(a: StaffJob, b: StaffJob) -> bool:
	return _job_priority(a.task) < _job_priority(b.task)


func _job_priority(task: StaffTasks.Id) -> int:
	match task:
		StaffTasks.Id.CLEAN:
			return 10
		_:
			return 3


func _on_innkeeper_job_finished(job: StaffJob) -> void:
	match job.task:
		StaffTasks.Id.TAKE_ORDER:
			if job.customer != null and is_instance_valid(job.customer):
				call_deferred("_finalize_take_order", job.customer)
			return
		StaffTasks.Id.COOK:
			if job.customer != null and is_instance_valid(job.customer):
				KitchenService.start_cooking(job.customer)
		StaffTasks.Id.SERVE:
			if job.customer != null and is_instance_valid(job.customer):
				job.customer.mark_served()
				KitchenService.pop_ready_customer(job.customer)
		StaffTasks.Id.CLEAN:
			pass
	schedule_work()


func _finalize_take_order(customer: CustomerEntity) -> void:
	if is_instance_valid(customer):
		CustomerService.complete_take_order(customer)
	schedule_work()


func _on_customer_spawned(customer: CustomerEntity) -> void:
	customer.state_changed.connect(_on_customer_state_changed.bind(customer))


func _on_customer_state_changed(state: CustomerStates.Id, customer: CustomerEntity) -> void:
	if not is_instance_valid(customer):
		return
	match state:
		CustomerStates.Id.REQUEST_PENDING:
			schedule_work()
		CustomerStates.Id.WAITING_AT_COUNTER:
			schedule_work()
		CustomerStates.Id.LEAVING:
			if customer.chair_position != Vector2.ZERO:
				enqueue_clean(customer.chair_position)


func _on_day_started(_day: int) -> void:
	call_deferred("ensure_innkeeper")
	call_deferred("_apply_shift_state", true)


func _on_day_ended(_day: int, _summary: Dictionary) -> void:
	_job_queue.clear()
	KitchenService.reset_all()
	_send_innkeeper_to_rest()


func _on_grid_loaded() -> void:
	if is_instance_valid(innkeeper):
		innkeeper.queue_free()
	innkeeper = null
	call_deferred("ensure_innkeeper")


func _on_innkeeper_task_changed(task: StaffTasks.Id) -> void:
	EventBus.staff_task_changed.emit(task)


func _on_navigation_map_ready(view_id: ViewIds.Id) -> void:
	if view_id == ViewIds.Id.INN_F1:
		call_deferred("ensure_innkeeper")


func _on_game_hour_changed(_hour: float) -> void:
	_apply_shift_state(false)


func _on_furniture_changed(_instance: FurnitureInstance) -> void:
	if not is_instance_valid(innkeeper) or innkeeper.is_busy():
		return
	if GameClock.is_work_hours():
		schedule_work()


func _apply_shift_state(_force: bool) -> void:
	if not is_instance_valid(innkeeper):
		return

	if GameTimeManager.is_running() and GameClock.is_work_hours():
		_job_queue.clear()
		schedule_work()
		return

	_job_queue.clear()
	_send_innkeeper_to_rest()


func _send_innkeeper_to_rest() -> void:
	if not is_instance_valid(innkeeper):
		return
	var rest_position: Vector2 = InnLayoutHelper.find_owner_room_position(ViewIds.Id.INN_F1)
	if rest_position == Vector2.ZERO:
		rest_position = GridCoord.new(3, 3, ViewIds.Id.INN_F1).to_world_center()
	innkeeper.go_rest(rest_position)


func _ensure_owner_room_setup() -> void:
	var view_id: ViewIds.Id = ViewIds.Id.INN_F1
	GridLayoutSeeder.ensure_owner_room_floor(GridService.get_grid(view_id))

	if not _has_owner_bed(view_id):
		var bed_origin := GridCoord.new(
			GridLayoutRules.OWNER_ROOM_ORIGIN.x,
			GridLayoutRules.OWNER_ROOM_ORIGIN.y,
			view_id
		)
		if FurnitureService.can_place(bed_origin, "owner_bed", 0):
			FurnitureService.place_furniture(bed_origin, "owner_bed", 0)


func _has_owner_bed(view_id: ViewIds.Id) -> bool:
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		if instance.def_id == "owner_bed":
			return true
	return false
