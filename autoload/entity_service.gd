extends Node

const UNIT_SCENE: PackedScene = preload("res://scenes/entities/unit_entity.tscn")

var selected_unit: UnitEntity = null
var default_invasion_route: InvasionRoute = InvasionRoute.new()

var _units_by_view: Dictionary = {}
var _next_entity_number: int = 1


func _ready() -> void:
	_reset_views()
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.grid_loaded.connect(_on_grid_loaded)
	EventBus.navigation_map_ready.connect(_on_navigation_map_ready)


func get_units_in_view(view_id: ViewIds.Id) -> Array[UnitEntity]:
	var result: Array[UnitEntity] = []
	if not _units_by_view.has(view_id):
		return result
	for entity_id: String in _units_by_view[view_id].keys():
		result.append(_units_by_view[view_id][entity_id] as UnitEntity)
	return result


func spawn_unit(
	view_id: ViewIds.Id,
	world_position: Vector2,
	team_id: EntityTeams.Id = EntityTeams.Id.PLAYER_GUARD
) -> UnitEntity:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return null

	var spawn_position: Vector2 = NavService.get_closest_walkable_point(view_id, world_position)
	var unit: UnitEntity = UNIT_SCENE.instantiate() as UnitEntity
	var entity_id: String = _generate_entity_id()
	unit.name = entity_id
	view.entity_layer.add_child(unit)
	unit.configure(entity_id, view_id, team_id, spawn_position)

	if not _units_by_view.has(view_id):
		_units_by_view[view_id] = {}
	_units_by_view[view_id][entity_id] = unit

	if ViewManager.current_view_id == view_id:
		unit.call_deferred("activate")
	else:
		unit.deactivate()

	EventBus.entity_spawned.emit(unit)
	return unit


func try_select_at(world_position: Vector2) -> bool:
	var view_id: ViewIds.Id = ViewManager.current_view_id
	var hit_unit: UnitEntity = _find_unit_at(view_id, world_position)
	if hit_unit != null:
		select_unit(hit_unit)
		return true

	clear_selection()
	return false


func select_unit(unit: UnitEntity) -> void:
	if selected_unit == unit:
		return
	clear_selection()
	selected_unit = unit
	if selected_unit:
		selected_unit.set_selected(true)
		EventBus.entity_selected.emit(selected_unit)


func clear_selection() -> void:
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
		EventBus.entity_selected.emit(null)


func command_move_selected_to(world_position: Vector2) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.view_id != ViewManager.current_view_id:
		return false

	var target_position: Vector2 = NavService.get_closest_walkable_point(
		selected_unit.view_id,
		world_position
	)
	selected_unit.command_move_to(target_position)
	EventBus.entity_move_command.emit(selected_unit.entity_id, target_position)
	return true


func ensure_debug_units() -> void:
	pass


func _spawn_debug_guard() -> void:
	pass


func _on_navigation_map_ready(view_id: ViewIds.Id) -> void:
	pass


func clear_all() -> void:
	for view_id: ViewIds.Id in _units_by_view.keys():
		_clear_view_units(view_id)
	_units_by_view.clear()
	clear_selection()
	_next_entity_number = 1


func get_total_unit_count() -> int:
	var count: int = 0
	for view_id: ViewIds.Id in _units_by_view.keys():
		count += (_units_by_view[view_id] as Dictionary).size()
	return count


func _find_unit_at(view_id: ViewIds.Id, world_position: Vector2) -> UnitEntity:
	var closest_unit: UnitEntity = null
	var closest_distance: float = INF
	for unit: UnitEntity in get_units_in_view(view_id):
		if unit.contains_world_point(world_position):
			var distance: float = unit.global_position.distance_to(world_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_unit = unit
	return closest_unit


func _generate_entity_id() -> String:
	var entity_id: String = "unit_%d" % _next_entity_number
	_next_entity_number += 1
	return entity_id


func _reset_views() -> void:
	_units_by_view.clear()


func _clear_view_units(view_id: ViewIds.Id) -> void:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return
	for child: Node in view.entity_layer.get_children():
		if child is UnitEntity:
			child.queue_free()


func _on_view_changed(_previous_view_id: ViewIds.Id, next_view_id: ViewIds.Id) -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		var is_active: bool = view_id == next_view_id
		for unit: UnitEntity in get_units_in_view(view_id):
			if is_active:
				unit.activate()
			else:
				unit.deactivate()

	if selected_unit != null and selected_unit.view_id != next_view_id:
		clear_selection()


func _on_grid_loaded() -> void:
	# Units are not persisted yet; refresh debug spawn after a full clear/load.
	pass
