class_name UnitEntity
extends CharacterBody2D

signal move_finished()

@export var team_id: EntityTeams.Id = EntityTeams.Id.PLAYER_GUARD
@export var move_speed: float = 110.0

var entity_id: String = ""
var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE
var is_selected: bool = false
var _facing_direction: Vector2 = Vector2(0.0, 1.0)

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	navigation_agent.path_desired_distance = 6.0
	navigation_agent.target_desired_distance = 6.0
	navigation_agent.radius = 7.0
	navigation_agent.avoidance_enabled = true
	collision_layer = 1 << (GameConstants.COLLISION_LAYER_UNITS - 1)
	collision_mask = (
		(1 << (GameConstants.COLLISION_LAYER_TERRAIN - 1))
		| (1 << (GameConstants.COLLISION_LAYER_FURNITURE - 1))
	)
	add_to_group("units")
	set_physics_process(false)


func configure(p_entity_id: String, p_view_id: ViewIds.Id, p_team_id: EntityTeams.Id, spawn_position: Vector2) -> void:
	entity_id = p_entity_id
	view_id = p_view_id
	team_id = p_team_id
	global_position = spawn_position
	_update_depth_sort()
	set_selected(false)


func activate() -> void:
	set_physics_process(true)
	call_deferred("_sync_navigation_agent")


func _sync_navigation_agent() -> void:
	if not is_inside_tree():
		return
	navigation_agent.target_position = global_position


func deactivate() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func command_move_to(world_position: Vector2) -> void:
	navigation_agent.target_position = world_position


func contains_world_point(world_position: Vector2) -> bool:
	var local_position: Vector2 = to_local(world_position)
	var hit_rect := Rect2(-12.0, -24.0, 24.0, 30.0)
	return hit_rect.has_point(local_position)


func _physics_process(_delta: float) -> void:
	if not GameTimeManager.is_time_flowing():
		velocity = Vector2.ZERO
		_update_depth_sort()
		return

	if navigation_agent.is_navigation_finished():
		if velocity.length_squared() > 0.0:
			velocity = Vector2.ZERO
			move_finished.emit()
		_update_depth_sort()
		return

	var next_path_position: Vector2 = navigation_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_path_position)
	if direction.length_squared() > 0.0:
		_facing_direction = direction
		velocity = direction * move_speed * GameTimeManager.time_scale
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_depth_sort()


func _draw() -> void:
	HumanFigureDrawer.draw(
		self,
		_facing_direction,
		HumanFigureDrawer.style_for_unit(team_id),
		is_selected
	)


func _update_depth_sort() -> void:
	TopdownDepthSort.apply_for_actor(self, view_id, TopdownDepthSort.ENTITY_OFFSET)
