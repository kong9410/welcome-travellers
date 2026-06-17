class_name OutsideCustomerEntity
extends Node2D

signal reached_target(customer: OutsideCustomerEntity)

enum SpawnSide {
	LEFT,
	RIGHT,
}

const ARRIVAL_TOLERANCE: float = 4.0
const MAX_PATIENCE: float = 100.0

@export var move_speed: float = 78.0

var customer_id: String = ""
var persona: CustomerPersonas.Id = CustomerPersonas.Id.TRAVELER
var patience: float = MAX_PATIENCE
var spawn_side: SpawnSide = SpawnSide.LEFT
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false
var group_id: String = ""
var group_size: int = 1
var is_group_leader: bool = false
var group_companion: OutsideCustomerEntity = null
var group_companions: Array[OutsideCustomerEntity] = []
var follow_offset: Vector2 = Vector2.ZERO

var _facing_direction: Vector2 = Vector2(1.0, 0.0)
var _queue_free_on_arrival: bool = false


func _ready() -> void:
	add_to_group("outside_customers")
	set_process(false)
	queue_redraw()


func configure(
	p_customer_id: String,
	p_persona: CustomerPersonas.Id,
	p_spawn_side: SpawnSide,
	spawn_position: Vector2,
	p_target_position: Vector2
) -> void:
	customer_id = p_customer_id
	persona = p_persona
	patience = MAX_PATIENCE
	spawn_side = p_spawn_side
	position = spawn_position
	set_target_position(p_target_position)
	queue_redraw()


func set_target_position(next_target_position: Vector2) -> void:
	_apply_target_position(next_target_position)
	if is_group_leader:
		_sync_group_companion_targets(next_target_position)


func depart_to_edge(to_left: bool) -> void:
	_queue_free_on_arrival = true
	for companion: OutsideCustomerEntity in get_all_group_companions():
		if is_instance_valid(companion):
			companion._queue_free_on_arrival = true
	set_target_position(OutsideViewConstants.guest_exit_position(to_left))


func configure_group(
	p_group_id: String,
	p_group_size: int,
	p_is_group_leader: bool,
	p_follow_offset: Vector2 = Vector2.ZERO
) -> void:
	group_id = p_group_id
	group_size = p_group_size
	is_group_leader = p_is_group_leader
	follow_offset = p_follow_offset


func add_group_companion(companion: OutsideCustomerEntity) -> void:
	if companion == null or not is_instance_valid(companion):
		return
	if companion in group_companions:
		return
	group_companions.append(companion)
	group_companion = group_companions[0]
	companion.sync_shared_patience(patience)


func sync_shared_patience(shared_patience: float) -> void:
	patience = clampf(shared_patience, 0.0, MAX_PATIENCE)
	for companion: OutsideCustomerEntity in get_all_group_companions():
		if is_instance_valid(companion):
			companion.patience = patience
	queue_redraw()


func reposition_as_group_cluster(base_position: Vector2, member_index: int) -> void:
	var offset: Vector2 = Vector2.ZERO
	if member_index > 0:
		var offsets: Array[Vector2] = [
			Vector2(18.0, 12.0),
			Vector2(-18.0, 12.0),
			Vector2(0.0, 24.0),
		]
		offset = offsets[(member_index - 1) % offsets.size()]
	_apply_target_position(base_position + offset)


func get_all_group_companions() -> Array[OutsideCustomerEntity]:
	var result: Array[OutsideCustomerEntity] = []
	for companion: OutsideCustomerEntity in group_companions:
		if is_instance_valid(companion):
			result.append(companion)
	if result.is_empty() and is_instance_valid(group_companion):
		result.append(group_companion)
	return result


func tick_outside_wait_patience(delta: float, decay_per_5_minutes: float) -> bool:
	if patience <= 0.0 or decay_per_5_minutes <= 0.0:
		return patience <= 0.0
	var game_minutes: float = delta / maxf(GameClock.SECONDS_PER_HOUR, 0.001) * 60.0
	var decay: float = decay_per_5_minutes * game_minutes / 5.0
	patience = clampf(patience - decay, 0.0, MAX_PATIENCE)
	sync_shared_patience(patience)
	return patience <= 0.0


func _process(delta: float) -> void:
	if not is_moving:
		return
	if not GameTimeManager.is_time_flowing():
		return

	var distance: float = position.distance_to(target_position)
	if distance <= ARRIVAL_TOLERANCE:
		_finish_move()
		return

	var direction: Vector2 = position.direction_to(target_position)
	if direction.length_squared() > 0.0001:
		_facing_direction = direction
		position += direction * minf(move_speed * GameTimeManager.scaled_delta(delta), distance)
		_update_depth_sort()
		queue_redraw()


func _draw() -> void:
	var style: HumanFigureDrawer.FigureStyle = HumanFigureDrawer.style_for_customer(
		persona,
		CustomerOrderTypes.Id.FOOD
	)
	HumanFigureDrawer.draw(self, _facing_direction, style)


func _finish_move() -> void:
	position = target_position
	is_moving = false
	set_process(false)
	_update_depth_sort()
	if _queue_free_on_arrival:
		queue_free()
		return
	reached_target.emit(self)


func _apply_target_position(next_target_position: Vector2) -> void:
	target_position = next_target_position
	is_moving = position.distance_to(target_position) > ARRIVAL_TOLERANCE
	set_process(is_moving)
	if is_moving:
		_facing_direction = position.direction_to(target_position)
	else:
		call_deferred("_finish_move")
	_update_depth_sort()


func _sync_group_companion_targets(base_position: Vector2) -> void:
	for companion: OutsideCustomerEntity in get_all_group_companions():
		if is_instance_valid(companion):
			companion._apply_target_position(base_position + companion.follow_offset)


func _update_depth_sort() -> void:
	TopdownDepthSort.apply_for_foot(self, TopdownDepthSort.ENTITY_OFFSET)
