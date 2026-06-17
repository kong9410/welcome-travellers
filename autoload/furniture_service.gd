extends Node

const _DoorKinds := preload("res://scripts/core/door/door_kinds.gd")

var current_def_id: String = "chair"
var current_rotation: int = 0
var removal_tool_active: bool = false

var _instances_by_view: Dictionary = {}
var _occupancy: Dictionary = {}
var _next_instance_number: int = 1
var _selected_instance_id: String = ""
var _selected_view_id: ViewIds.Id = ViewIds.Id.INN_F1


func _ready() -> void:
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.grid_loaded.connect(refresh_all_visuals)


func has_any_instances() -> bool:
	for view_id: ViewIds.Id in _instances_by_view.keys():
		if not (_instances_by_view[view_id] as Dictionary).is_empty():
			return true
	return false


func get_instances(view_id: ViewIds.Id) -> Array[FurnitureInstance]:
	var result: Array[FurnitureInstance] = []
	if not _instances_by_view.has(view_id):
		return result
	for instance_id: String in _instances_by_view[view_id].keys():
		result.append(_instances_by_view[view_id][instance_id] as FurnitureInstance)
	return result


func get_selected_instance() -> FurnitureInstance:
	if _selected_instance_id == "":
		return null
	return InnLayoutHelper.get_instance_by_id(_selected_view_id, _selected_instance_id)


func try_select_at(world_position: Vector2, view_id: ViewIds.Id) -> bool:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		clear_selection()
		return false
	var local_position: Vector2 = view.to_local(world_position)
	var coord: GridCoord = GridCoord.from_local(view_id, local_position)
	var instance: FurnitureInstance = get_instance_at(coord)
	if instance == null:
		instance = _find_furniture_at(view_id, local_position)
	if instance == null:
		clear_selection()
		return false
	select_instance(instance)
	return true


func select_instance(instance: FurnitureInstance) -> void:
	if instance == null:
		clear_selection()
		return
	if (
		_selected_instance_id == instance.instance_id
		and _selected_view_id == instance.origin.view_id
	):
		return
	_set_visual_selected(_selected_view_id, _selected_instance_id, false)
	_selected_instance_id = instance.instance_id
	_selected_view_id = instance.origin.view_id
	_set_visual_selected(_selected_view_id, _selected_instance_id, true)
	EventBus.furniture_selected.emit(instance)


func clear_selection() -> void:
	if _selected_instance_id == "":
		return
	_set_visual_selected(_selected_view_id, _selected_instance_id, false)
	_selected_instance_id = ""
	EventBus.furniture_selected.emit(null)


func get_instance_at(coord: GridCoord) -> FurnitureInstance:
	var occupancy_key: String = _occupancy_key(coord)
	if not _occupancy.has(occupancy_key):
		return null
	var instance_id: String = _occupancy[occupancy_key]
	if not _instances_by_view.has(coord.view_id):
		return null
	var view_instances: Dictionary = _instances_by_view[coord.view_id]
	if not view_instances.has(instance_id):
		return null
	return view_instances[instance_id] as FurnitureInstance


func can_place(origin: GridCoord, def_id: String, rotation_steps: int) -> bool:
	return get_placement_block_reason(origin, def_id, rotation_steps) == ""


func get_placement_block_reason(origin: GridCoord, def_id: String, rotation_steps: int) -> String:
	if not origin.is_in_bounds():
		return "맵 밖입니다."

	var interior_door_reason: String = GridLayoutRules.get_interior_door_block_reason(origin, def_id)
	if interior_door_reason != "":
		return interior_door_reason

	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
	var cells: Array[GridCoord] = FurnitureFootprint.get_occupied_cells(
		origin,
		definition.footprint,
		rotation_steps
	)

	for coord: GridCoord in cells:
		if not coord.is_in_bounds():
			return "맵 밖입니다."
		var cell: CellData = GridService.get_cell(coord)
		if cell.tile_type != definition.required_tile_type:
			return "여기에 가구를 배치할 수 없습니다."
		if _occupancy.has(_occupancy_key(coord)):
			return "이미 다른 가구가 있습니다."

	return ""


func place_furniture(
	origin: GridCoord,
	def_id: String = current_def_id,
	rotation_steps: int = current_rotation,
	charge_cost: bool = true
) -> String:
	if removal_tool_active:
		return ""
	var block_reason: String = get_placement_block_reason(origin, def_id, rotation_steps)
	if block_reason != "":
		EventBus.furniture_placement_blocked.emit(origin, block_reason)
		return ""

	var build_cost: int = FurnitureCatalog.build_cost_for(def_id) if charge_cost else 0
	if build_cost > 0 and EconomyManager.gold < build_cost:
		EventBus.furniture_placement_blocked.emit(origin, "골드가 부족합니다. (%d골드 필요)" % build_cost)
		return ""

	var instance_id: String = _generate_instance_id()
	var instance := FurnitureInstance.new(instance_id, def_id, origin, rotation_steps)
	_register_instance(instance)
	_spawn_visual(instance)
	if build_cost > 0:
		EconomyManager.record_expense(build_cost, "build_furniture")
		var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
		var center_offset := Vector2(definition.footprint) * float(GameConstants.TILE_SIZE) * 0.5
		EventBus.build_cost_spent.emit(origin.view_id, origin.to_world() + center_offset, build_cost)
	EventBus.furniture_placed.emit(instance)
	return instance_id


func remove_at(coord: GridCoord) -> bool:
	var instance: FurnitureInstance = get_instance_at(coord)
	if instance == null:
		return false
	return remove_instance(instance.instance_id)


func remove_instance(instance_id: String) -> bool:
	for view_id: ViewIds.Id in _instances_by_view.keys():
		if not (_instances_by_view[view_id] as Dictionary).has(instance_id):
			continue
		var instance: FurnitureInstance = _instances_by_view[view_id][instance_id]
		if _selected_instance_id == instance_id and _selected_view_id == view_id:
			clear_selection()
		_unregister_instance(instance)
		_despawn_visual(instance)
		EventBus.furniture_removed.emit(instance)
		return true
	return false


func rotate_preview() -> void:
	if removal_tool_active:
		return
	current_rotation = posmod(current_rotation + 1, 4)
	EventBus.furniture_catalog_changed.emit()


func set_current_def(def_id: String) -> void:
	removal_tool_active = false
	current_def_id = def_id
	EventBus.furniture_catalog_changed.emit()


func set_removal_tool() -> void:
	removal_tool_active = true
	EventBus.furniture_catalog_changed.emit()


func is_removal_tool() -> bool:
	return removal_tool_active


func blocks_movement_at(coord: GridCoord) -> bool:
	var instance: FurnitureInstance = get_instance_at(coord)
	if instance == null:
		return false
	return FurnitureCatalog.get_definition(instance.def_id).blocks_movement


func can_customer_stand_at(coord: GridCoord) -> bool:
	if not coord.is_in_bounds():
		return false
	if GridService.get_cell(coord).tile_type != CellData.TileType.FLOOR:
		return false
	var instance: FurnitureInstance = get_instance_at(coord)
	if instance == null:
		return true
	if _DoorKinds.is_interior_door_def(instance.def_id):
		return true
	return FurnitureCatalog.allows_customer_on_tile(instance.def_id)


func export_save_data() -> Dictionary:
	var data: Dictionary = {}
	for view_id: ViewIds.Id in _instances_by_view.keys():
		var entries: Array = []
		for instance: FurnitureInstance in get_instances(view_id):
			entries.append(instance.to_dict())
		data[str(view_id)] = entries
	return {
		"instances": data,
		"next_instance_number": _next_instance_number,
	}


func import_save_data(data: Dictionary) -> void:
	clear_all(false)
	_next_instance_number = data.get("next_instance_number", 1)
	var instances_data: Dictionary = data.get("instances", {})
	for key: String in instances_data.keys():
		var view_id: ViewIds.Id = int(key) as ViewIds.Id
		for entry: Dictionary in instances_data[key]:
			var instance: FurnitureInstance = FurnitureInstance.from_dict(entry)
			_register_instance(instance)
	for view_id: ViewIds.Id in ViewIds.all():
		_refresh_view_visuals(view_id)
	EventBus.furniture_loaded.emit()


func clear_all(refresh: bool = true) -> void:
	for view_id: ViewIds.Id in _instances_by_view.keys():
		_clear_view_visuals(view_id)
	_instances_by_view.clear()
	_occupancy.clear()
	_next_instance_number = 1
	if refresh:
		EventBus.furniture_loaded.emit()


func refresh_all_visuals() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		_refresh_view_visuals(view_id)


func _register_instance(instance: FurnitureInstance) -> void:
	var view_id: ViewIds.Id = instance.origin.view_id
	if not _instances_by_view.has(view_id):
		_instances_by_view[view_id] = {}
	_instances_by_view[view_id][instance.instance_id] = instance
	for coord: GridCoord in instance.get_occupied_cells():
		_occupancy[_occupancy_key(coord)] = instance.instance_id


func _unregister_instance(instance: FurnitureInstance) -> void:
	var view_id: ViewIds.Id = instance.origin.view_id
	for coord: GridCoord in instance.get_occupied_cells():
		_occupancy.erase(_occupancy_key(coord))
	if _instances_by_view.has(view_id):
		_instances_by_view[view_id].erase(instance.instance_id)


func _occupancy_key(coord: GridCoord) -> String:
	return "%d:%d:%d" % [coord.view_id, coord.x, coord.y]


func _generate_instance_id() -> String:
	var instance_id: String = "furniture_%d" % _next_instance_number
	_next_instance_number += 1
	return instance_id


func _spawn_visual(instance: FurnitureInstance) -> void:
	var view: ViewRoot = ViewManager.get_view(instance.origin.view_id)
	if view == null:
		return
	var visual := FurnitureVisual.new()
	visual.name = instance.instance_id
	view.furniture_layer.add_child(visual)
	visual.setup(instance, FurnitureCatalog.get_definition(instance.def_id))


func _despawn_visual(instance: FurnitureInstance) -> void:
	var view: ViewRoot = ViewManager.get_view(instance.origin.view_id)
	if view == null:
		return
	var node: Node = view.furniture_layer.get_node_or_null(NodePath(str(instance.instance_id)))
	if node:
		node.queue_free()


func _refresh_view_visuals(view_id: ViewIds.Id) -> void:
	_clear_view_visuals(view_id)
	for instance: FurnitureInstance in get_instances(view_id):
		_spawn_visual(instance)
	if _selected_view_id == view_id and _selected_instance_id != "":
		_set_visual_selected(view_id, _selected_instance_id, true)


func _get_visual(view_id: ViewIds.Id, instance_id: String) -> FurnitureVisual:
	if instance_id == "":
		return null
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return null
	var node: Node = view.furniture_layer.get_node_or_null(NodePath(instance_id))
	if node is FurnitureVisual:
		return node as FurnitureVisual
	return null


func _set_visual_selected(view_id: ViewIds.Id, instance_id: String, selected: bool) -> void:
	var visual: FurnitureVisual = _get_visual(view_id, instance_id)
	if visual != null:
		visual.set_selected(selected)


func _clear_view_visuals(view_id: ViewIds.Id) -> void:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return
	for child: Node in view.furniture_layer.get_children():
		child.queue_free()


func _on_view_changed(_previous_view_id: ViewIds.Id, next_view_id: ViewIds.Id) -> void:
	var selected: FurnitureInstance = get_selected_instance()
	if selected != null and selected.origin.view_id != next_view_id:
		clear_selection()


func _find_furniture_at(view_id: ViewIds.Id, local_position: Vector2) -> FurnitureInstance:
	var closest_instance: FurnitureInstance = null
	var closest_distance: float = INF
	var tile_size: float = float(GameConstants.TILE_SIZE)
	for instance: FurnitureInstance in get_instances(view_id):
		var bounds: Rect2 = _get_local_bounds(instance, tile_size)
		if not bounds.has_point(local_position):
			continue
		var distance: float = bounds.get_center().distance_to(local_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_instance = instance
	return closest_instance


func _get_local_bounds(instance: FurnitureInstance, tile_size: float) -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for coord: GridCoord in instance.get_occupied_cells():
		var world_point: Vector2 = coord.to_world()
		min_point = min_point.min(world_point)
		max_point = max_point.max(world_point + Vector2.ONE * tile_size)
	return Rect2(min_point, max_point - min_point)
