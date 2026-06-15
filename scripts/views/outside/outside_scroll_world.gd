class_name OutsideScrollWorld
extends Node2D

const OUTSIDE_CUSTOMER_SCENE: PackedScene = preload("res://scenes/entities/outside_customer_entity.tscn")

@onready var sky_renderer: OutsideSkyRenderer = $OutsideSkyRenderer
@onready var ground_renderer: OutsideGroundRenderer = $GroundRenderer
@onready var inn_building: OutsideInnBuildingRenderer = $InnBuilding
@onready var outside_customer_layer: Node2D = $OutsideCustomerLayer

var _next_outside_customer_number: int = 1


func _ready() -> void:
	if inn_building:
		inn_building.door_clicked.connect(_on_inn_door_clicked)
	if outside_customer_layer:
		outside_customer_layer.y_sort_enabled = true


func try_open_inn_door(global_position: Vector2) -> bool:
	if inn_building == null:
		return false
	return inn_building.try_handle_door_click(global_position)


func get_world_bounds() -> Rect2:
	return OutsideViewConstants.world_bounds()


func spawn_outside_customer_from_edge(
	target_position: Vector2 = Vector2.ZERO,
	spawn_side: int = -1,
	persona_id: int = -1
) -> OutsideCustomerEntity:
	if outside_customer_layer == null:
		return null

	var resolved_target: Vector2 = (
		OutsideViewConstants.outside_queue_position(0)
		if target_position == Vector2.ZERO
		else target_position
	)
	var resolved_spawn_side: OutsideCustomerEntity.SpawnSide = (
		_random_spawn_side()
		if spawn_side < 0
		else spawn_side as OutsideCustomerEntity.SpawnSide
	)
	var resolved_persona: CustomerPersonas.Id = (
		CustomerPersonas.random()
		if persona_id < 0
		else persona_id as CustomerPersonas.Id
	)
	var from_left: bool = resolved_spawn_side == OutsideCustomerEntity.SpawnSide.LEFT
	var spawn_position: Vector2 = OutsideViewConstants.guest_spawn_position(from_left)
	var customer := OUTSIDE_CUSTOMER_SCENE.instantiate() as OutsideCustomerEntity
	var customer_id: String = _generate_outside_customer_id()
	customer.name = customer_id
	outside_customer_layer.add_child(customer)
	customer.configure(
		customer_id,
		resolved_persona,
		resolved_spawn_side,
		spawn_position,
		resolved_target
	)
	return customer


func _on_inn_door_clicked() -> void:
	ViewManager.switch_to(ViewIds.Id.INN_F1)


static func _random_spawn_side() -> OutsideCustomerEntity.SpawnSide:
	return (
		OutsideCustomerEntity.SpawnSide.LEFT
		if randi() % 2 == 0
		else OutsideCustomerEntity.SpawnSide.RIGHT
	)


func _generate_outside_customer_id() -> String:
	var id: String = "outside_customer_%d" % _next_outside_customer_number
	_next_outside_customer_number += 1
	return id
