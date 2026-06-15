class_name InnkeeperEntity
extends CharacterBody2D

signal task_changed(task: StaffTasks.Id)
signal job_finished(job: StaffJob)

@export var move_speed: float = 88.0

const COOK_PATROL_DURATION: float = 2.6
const WAYPOINT_TOLERANCE: float = 6.0
const JOB_ARRIVAL_TOLERANCE: float = 14.0

var staff_id: String = "innkeeper"
var view_id: ViewIds.Id = ViewIds.Id.INN_F1
var current_task: StaffTasks.Id = StaffTasks.Id.REST
var current_job: StaffJob = null

var _work_timer: float = 0.0
var _was_navigating: bool = false
var _navigation_token: int = 0
var _cook_patrol_elapsed: float = 0.0
var _cook_patrol_waypoints: Array[Vector2] = []
var _cook_patrol_index: int = 0
var _cook_patrol_active: bool = false
var _job_travel_ready: bool = false
var _nav_retry_count: int = 0
var _nav_wait_elapsed: float = 0.0
var _floor_path: Array[Vector2] = []
var _movement_target: Vector2 = Vector2.ZERO
var _path_retry_timer: float = 0.0
var _facing_direction: Vector2 = Vector2(0.0, 1.0)
var _facing_dir: HumanFigureDrawer.FacingDir = HumanFigureDrawer.FacingDir.DOWN


func _ready() -> void:
	collision_layer = 1 << (GameConstants.COLLISION_LAYER_UNITS - 1)
	collision_mask = (
		(1 << (GameConstants.COLLISION_LAYER_TERRAIN - 1))
		| (1 << (GameConstants.COLLISION_LAYER_FURNITURE - 1))
	)
	add_to_group("staff")
	set_physics_process(false)
	EventBus.navigation_rebuilt.connect(_on_navigation_rebuilt)
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)
	EventBus.furniture_placed.connect(_on_furniture_layout_changed)
	EventBus.furniture_removed.connect(_on_furniture_layout_changed)


func configure(p_view_id: ViewIds.Id, spawn_position: Vector2) -> void:
	view_id = p_view_id
	global_position = InnLayoutHelper.snap_to_floor_world(view_id, spawn_position)
	_update_depth_sort()
	queue_redraw()


func activate() -> void:
	set_physics_process(true)


func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	_navigation_token += 1
	_floor_path.clear()
	_movement_target = Vector2.ZERO


func assign_job(job: StaffJob) -> void:
	current_job = job
	_set_task(job.task)
	_work_timer = 0.0
	_cook_patrol_elapsed = 0.0
	_cook_patrol_waypoints = job.waypoints.duplicate()
	_cook_patrol_index = 0
	_cook_patrol_active = job.task == StaffTasks.Id.COOK and not _cook_patrol_waypoints.is_empty()
	_job_travel_ready = false
	_was_navigating = false
	_nav_retry_count = 0
	_nav_wait_elapsed = 0.0
	_schedule_navigation(job.target_position)


func clear_job() -> void:
	current_job = null
	_work_timer = 0.0


func is_busy() -> bool:
	return current_job != null


func hold_cook_state() -> void:
	clear_job()
	_set_task(StaffTasks.Id.COOK)
	if not _floor_path.is_empty() or _movement_target != Vector2.ZERO:
		return
	var waypoints: Array[Vector2] = InnLayoutHelper.get_kitchen_patrol_points(view_id)
	var target_position: Vector2 = waypoints[0] if not waypoints.is_empty() else Vector2.ZERO
	if target_position == Vector2.ZERO:
		target_position = InnLayoutHelper.find_interior_fallback_position(view_id)
	if target_position != Vector2.ZERO:
		_schedule_navigation(target_position)


func go_rest(target_position: Vector2) -> void:
	clear_job()
	_set_task(StaffTasks.Id.REST)
	_schedule_navigation(target_position)


func go_counter(target_position: Vector2, force: bool = false) -> void:
	clear_job()
	_set_task(StaffTasks.Id.COUNTER)
	if target_position == Vector2.ZERO:
		return
	var resolved_target: Vector2 = _resolve_free_target(target_position)
	var at_counter: bool = (
		resolved_target != Vector2.ZERO
		and global_position.distance_to(resolved_target) <= JOB_ARRIVAL_TOLERANCE
	)
	if at_counter:
		_floor_path.clear()
		_movement_target = Vector2.ZERO
		_navigation_token += 1
		_snap_to_floor()
		return
	_movement_target = resolved_target if resolved_target != Vector2.ZERO else target_position
	_schedule_navigation(target_position)


func _set_task(task: StaffTasks.Id) -> void:
	if current_task == task:
		return
	current_task = task
	task_changed.emit(task)


func _schedule_navigation(world_position: Vector2) -> void:
	if world_position == Vector2.ZERO:
		_handle_unreachable_job_target()
		return
	_job_travel_ready = false
	_navigation_token += 1
	var token: int = _navigation_token
	call_deferred("_build_floor_path", world_position, token)


func _build_floor_path(world_position: Vector2, token: int) -> void:
	if token != _navigation_token or not is_physics_processing():
		return

	var target: Vector2 = _resolve_navigation_target(world_position)
	if target == Vector2.ZERO:
		_handle_unreachable_job_target()
		return

	_movement_target = target
	_floor_path = FloorPathfinder.find_floor_path(view_id, global_position, target)
	_path_retry_timer = 0.0
	_job_travel_ready = true
	_nav_wait_elapsed = 0.0
	_was_navigating = false

	if _floor_path.is_empty():
		if global_position.distance_to(target) <= _get_arrival_tolerance():
			_snap_to_floor()
			call_deferred("_handle_travel_arrival")
			return
		if _try_force_unreachable_job():
			return

	_snap_to_floor()


func _physics_process(delta: float) -> void:
	if current_job == null:
		_process_floor_movement(delta)
		_update_depth_sort()
		return

	if _work_timer > 0.0:
		_work_timer -= delta
		velocity = Vector2.ZERO
		if _work_timer <= 0.0:
			_finish_job()
		_update_depth_sort()
		return

	if current_job != null and not _job_travel_ready and _work_timer <= 0.0:
		_nav_wait_elapsed += delta
		if _nav_wait_elapsed >= 0.35:
			_force_navigation_ready()

	if current_job.task == StaffTasks.Id.COOK and _cook_patrol_active:
		_cook_patrol_elapsed += delta
		if _cook_patrol_elapsed >= COOK_PATROL_DURATION:
			_cook_patrol_active = false
			_work_timer = 0.5
			velocity = Vector2.ZERO
			_update_depth_sort()
			return

	_process_floor_movement(delta)
	_update_depth_sort()


func _process_floor_movement(delta: float) -> void:
	if _floor_path.is_empty():
		if _movement_target != Vector2.ZERO and global_position.distance_to(_movement_target) <= _get_arrival_tolerance():
			_snap_to_floor()
			_handle_travel_arrival()
			return
		if _movement_target != Vector2.ZERO and _job_travel_ready:
			_path_retry_timer += delta
			if _path_retry_timer >= 0.35:
				_path_retry_timer = 0.0
				if _try_force_unreachable_job():
					return
				_schedule_navigation(_movement_target)
		velocity = Vector2.ZERO
		_was_navigating = false
		return

	_was_navigating = true
	var next_waypoint: Vector2 = _floor_path[0]
	var direction: Vector2 = global_position.direction_to(next_waypoint)
	if direction.length_squared() > 0.0001:
		_facing_direction = direction
		var next_facing_dir: HumanFigureDrawer.FacingDir = HumanFigureDrawer.resolve_facing_dir(direction)
		if next_facing_dir != _facing_dir:
			_facing_dir = next_facing_dir
			queue_redraw()
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if global_position.distance_to(next_waypoint) <= WAYPOINT_TOLERANCE:
		global_position = next_waypoint
		_floor_path.pop_front()
		if _floor_path.is_empty():
			_snap_to_floor()
			_handle_travel_arrival()


func _handle_travel_arrival() -> void:
	var should_handle_arrival := _was_navigating or (
		current_job != null and _work_timer <= 0.0 and _job_travel_ready
	)
	_was_navigating = false
	_movement_target = Vector2.ZERO
	if not should_handle_arrival:
		return
	_on_move_finished()
	if current_job == null and current_task == StaffTasks.Id.COUNTER:
		StaffService.schedule_work()


func _on_move_finished() -> void:
	if current_job == null:
		return
	match current_job.task:
		StaffTasks.Id.TAKE_ORDER:
			if _work_timer <= 0.0:
				if not _is_at_job_target(JOB_ARRIVAL_TOLERANCE):
					_nav_retry_count += 1
					if _nav_retry_count >= 5:
						_work_timer = 1.2
						return
					_schedule_navigation(current_job.target_position)
					return
				_work_timer = 1.2
		StaffTasks.Id.COOK:
			if _work_timer <= 0.0:
				if _cook_patrol_active and _cook_patrol_elapsed < COOK_PATROL_DURATION:
					_advance_cook_patrol()
				else:
					_work_timer = 1.2
		StaffTasks.Id.SERVE:
			if _work_timer <= 0.0:
				if not _is_at_job_target(JOB_ARRIVAL_TOLERANCE):
					_nav_retry_count += 1
					if _nav_retry_count >= 5:
						if current_job.customer != null and is_instance_valid(current_job.customer):
							current_job.customer.mark_served()
						_work_timer = 1.0
						return
					_schedule_navigation(current_job.target_position)
					return
				if current_job.customer != null and is_instance_valid(current_job.customer):
					current_job.customer.mark_served()
				_work_timer = 1.0
		StaffTasks.Id.CLEAN:
			if _work_timer <= 0.0:
				if not _is_at_job_target(JOB_ARRIVAL_TOLERANCE):
					_nav_retry_count += 1
					if _nav_retry_count >= 5:
						_work_timer = 1.8
						return
					_schedule_navigation(_resolve_job_target())
					return
				_work_timer = 1.8
		_:
			_finish_job()


func _force_navigation_ready() -> void:
	if current_job == null or _job_travel_ready:
		return
	var target: Vector2 = _movement_target
	if target == Vector2.ZERO:
		target = _get_active_travel_target()
	_build_floor_path(target, _navigation_token)


func _resolve_navigation_target(world_position: Vector2) -> Vector2:
	var explicit_target: Vector2 = _resolve_free_target(world_position)
	if explicit_target != Vector2.ZERO:
		return explicit_target
	if current_job != null:
		return _resolve_job_target()
	return Vector2.ZERO


func _get_active_travel_target() -> Vector2:
	if current_job == null:
		return Vector2.ZERO
	if (
		current_job.task == StaffTasks.Id.COOK
		and _cook_patrol_active
		and not _cook_patrol_waypoints.is_empty()
	):
		return _cook_patrol_waypoints[_cook_patrol_index]
	return current_job.target_position


func _handle_unreachable_job_target() -> void:
	_job_travel_ready = true
	if current_job == null:
		return
	_nav_retry_count += 1
	if _nav_retry_count >= 3:
		match current_job.task:
			StaffTasks.Id.COOK:
				_work_timer = 1.2
			StaffTasks.Id.SERVE, StaffTasks.Id.TAKE_ORDER:
				_work_timer = 1.0
			StaffTasks.Id.CLEAN:
				_work_timer = 1.8
			_:
				_finish_job()


func _try_force_unreachable_job() -> bool:
	if current_job == null:
		return false
	_nav_retry_count += 1
	match current_job.task:
		StaffTasks.Id.CLEAN:
			if _nav_retry_count < 5:
				return false
			_work_timer = 1.8
			return true
		StaffTasks.Id.COOK, StaffTasks.Id.SERVE, StaffTasks.Id.TAKE_ORDER:
			if _nav_retry_count < 5:
				return false
			_work_timer = 1.0 if current_job.task != StaffTasks.Id.COOK else 1.2
			return true
		_:
			return false


func _is_at_job_target(tolerance: float = 8.0) -> bool:
	if current_job == null:
		return false
	var target: Vector2 = _movement_target
	if target == Vector2.ZERO:
		target = _resolve_job_target()
	if target == Vector2.ZERO:
		return false
	return global_position.distance_to(target) <= tolerance


func _resolve_job_target() -> Vector2:
	if current_job == null:
		return Vector2.ZERO
	if current_job.task == StaffTasks.Id.CLEAN:
		return InnLayoutHelper.get_clean_position(view_id, current_job.target_position)
	var target: Vector2 = InnLayoutHelper.exact_floor_world_point(view_id, current_job.target_position)
	if target == Vector2.ZERO:
		target = InnLayoutHelper.get_closest_floor_world_point(view_id, current_job.target_position)
	if target == Vector2.ZERO:
		return current_job.target_position
	return target


func _resolve_free_target(world_position: Vector2) -> Vector2:
	var target: Vector2 = InnLayoutHelper.exact_floor_world_point(view_id, world_position)
	if target == Vector2.ZERO:
		target = InnLayoutHelper.get_closest_floor_world_point(view_id, world_position)
	return target


func _advance_cook_patrol() -> void:
	if _cook_patrol_waypoints.is_empty():
		_cook_patrol_active = false
		_work_timer = 1.2
		return
	_cook_patrol_index = (_cook_patrol_index + 1) % _cook_patrol_waypoints.size()
	_schedule_navigation(_cook_patrol_waypoints[_cook_patrol_index])


func _get_arrival_tolerance() -> float:
	if current_job != null and current_job.task in [StaffTasks.Id.TAKE_ORDER, StaffTasks.Id.SERVE]:
		return JOB_ARRIVAL_TOLERANCE
	return WAYPOINT_TOLERANCE


func _snap_to_floor() -> void:
	var coord: GridCoord = GridCoord.from_local(view_id, global_position)
	if InnLayoutHelper.is_floor_walkable(coord):
		global_position = coord.to_world_center()
		_update_depth_sort()
		return
	var snapped: Vector2 = InnLayoutHelper.get_closest_floor_world_point(view_id, global_position)
	if snapped != Vector2.ZERO:
		global_position = snapped
	_update_depth_sort()


func _finish_job() -> void:
	var finished_job: StaffJob = current_job
	current_job = null
	_work_timer = 0.0
	_floor_path.clear()
	_movement_target = Vector2.ZERO
	_nav_retry_count = 0
	if finished_job != null:
		job_finished.emit(finished_job)


func _on_navigation_rebuilt(rebuilt_view_id: ViewIds.Id) -> void:
	_on_layout_changed(rebuilt_view_id)


func _on_grid_cell_changed(changed_view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	_on_layout_changed(changed_view_id)


func _on_furniture_layout_changed(instance: FurnitureInstance) -> void:
	if instance != null:
		_on_layout_changed(instance.origin.view_id)


func _on_layout_changed(changed_view_id: ViewIds.Id) -> void:
	if changed_view_id != view_id or not is_physics_processing():
		return
	if current_job != null:
		_schedule_navigation(current_job.target_position)
	elif current_task == StaffTasks.Id.COUNTER:
		StaffService.schedule_work()
	elif _movement_target != Vector2.ZERO:
		_schedule_navigation(_movement_target)


func _draw() -> void:
	HumanFigureDrawer.draw(
		self,
		_facing_direction,
		HumanFigureDrawer.style_for_innkeeper()
	)


func _update_depth_sort() -> void:
	TopdownDepthSort.apply_for_actor(self, view_id, TopdownDepthSort.ENTITY_OFFSET)
