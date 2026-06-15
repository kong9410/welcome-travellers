class_name OutsideCustomerEntity
extends Node2D

signal reached_target(customer: OutsideCustomerEntity)

enum SpawnSide {
	LEFT,
	RIGHT,
}

const ARRIVAL_TOLERANCE: float = 4.0

@export var move_speed: float = 78.0

var customer_id: String = ""
var persona: CustomerPersonas.Id = CustomerPersonas.Id.TRAVELER
var spawn_side: SpawnSide = SpawnSide.LEFT
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

var _facing_direction: Vector2 = Vector2(1.0, 0.0)


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
	spawn_side = p_spawn_side
	position = spawn_position
	set_target_position(p_target_position)
	queue_redraw()


func set_target_position(next_target_position: Vector2) -> void:
	target_position = next_target_position
	is_moving = position.distance_to(target_position) > ARRIVAL_TOLERANCE
	set_process(is_moving)
	if is_moving:
		_facing_direction = position.direction_to(target_position)
	_update_depth_sort()


func _process(delta: float) -> void:
	if not is_moving:
		return

	var distance: float = position.distance_to(target_position)
	if distance <= ARRIVAL_TOLERANCE:
		_finish_move()
		return

	var direction: Vector2 = position.direction_to(target_position)
	if direction.length_squared() > 0.0001:
		_facing_direction = direction
		position += direction * minf(move_speed * delta, distance)
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
	reached_target.emit(self)


func _update_depth_sort() -> void:
	TopdownDepthSort.apply_for_foot(self, TopdownDepthSort.ENTITY_OFFSET)
