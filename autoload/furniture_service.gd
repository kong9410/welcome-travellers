extends Node

const _DoorKinds := preload("res://scripts/core/door/door_kinds.gd")

var current_def_id: String = "chair"
var current_rotation: int = 0
var removal_tool_active: bool = false

var _instances_by_view: Dictionary = {}
var _occupancy: Dictionary = {}
var _next_instance_number: int = 1


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


func place_furniture(origin: GridCoord, def_id: String = current_def_id, rotation_steps: int = current_rotation) -> String:
	if removal_tool_active:
		return ""
	var block_reason: String = get_placement_block_reason(origin, def_id, rotation_steps)
	if block_reason != "":
		EventBus.furniture_placement_blocked.emit(origin, block_reason)
		return ""

	var instance_id: String = _generate_instance_id()
	var instance := FurnitureInstance.new(instance_id, def_id, origin, rotation_steps)
	_register_instance(instance)
	_spawn_visual(instance)
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


func _clear_view_visuals(view_id: ViewIds.Id) -> void:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return
	for child: Node in view.furniture_layer.get_children():
		child.queue_free()


func _on_view_changed(_previous_view_id: ViewIds.Id, _next_view_id: ViewIds.Id) -> void:
	pass
