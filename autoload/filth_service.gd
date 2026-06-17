extends Node

const _CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _filth_by_key: Dictionary = {}
var _visual_by_key: Dictionary = {}


func _ready() -> void:
	EventBus.grid_loaded.connect(_on_grid_loaded)


func spawn_filth(coord: GridCoord, kind: FilthKinds.Id, amount: int = 1) -> bool:
	if coord == null or not coord.is_in_bounds():
		return false
	if amount <= 0:
		return false
	if not _can_hold_filth(coord):
		return false

	var key: String = coord.to_key()
	if _filth_by_key.has(key):
		var existing: Dictionary = _filth_by_key[key]
		if int(existing.get("kind", FilthKinds.NO_FILTH)) == kind:
			existing["amount"] = int(existing.get("amount", 0)) + amount
		else:
			existing["kind"] = kind
			existing["amount"] = amount
	else:
		_filth_by_key[key] = {
			"kind": kind,
			"amount": amount,
		}

	_sync_visual_for_coord(coord)
	EventBus.filth_changed.emit(coord.view_id)
	return true


func spawn_empty_bowl_at_table(view_id: ViewIds.Id, chair_instance_id: String) -> bool:
	if chair_instance_id == "":
		return false
	var world_position: Vector2 = InnLayoutHelper.get_table_food_position(view_id, chair_instance_id)
	if not spawn_filth_at_world(world_position, view_id, FilthKinds.Id.FOOD_SCRAP):
		return false
	StaffService.enqueue_clean_for_chair(chair_instance_id, view_id)
	return true


func is_dining_chair_blocked(view_id: ViewIds.Id, chair_instance_id: String) -> bool:
	if chair_instance_id == "":
		return false
	var food_position: Vector2 = InnLayoutHelper.get_table_food_position(view_id, chair_instance_id)
	if food_position == Vector2.ZERO:
		return false
	var food_coord: GridCoord = GridCoord.from_local(view_id, food_position)
	if not has_filth_at(food_coord):
		return false
	var kind: FilthKinds.Id = FilthKinds.from_value(get_filth_at(food_coord).get("kind", FilthKinds.NO_FILTH))
	return kind == FilthKinds.Id.FOOD_SCRAP


func spawn_trash_at(world_position: Vector2, view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	return spawn_filth_at_world(world_position, view_id, FilthKinds.Id.TRASH)


func spawn_filth_at_world(
	world_position: Vector2,
	view_id: ViewIds.Id,
	kind: FilthKinds.Id
) -> bool:
	if world_position == Vector2.ZERO:
		return false
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if spawn_filth(coord, kind):
		return true
	for offset: Vector2i in _CARDINAL_OFFSETS:
		var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
		if spawn_filth(neighbor, kind):
			return true
	return false


func clean_at(coord: GridCoord) -> bool:
	if coord == null:
		return false
	var key: String = coord.to_key()
	if not _filth_by_key.has(key):
		return false
	_filth_by_key.erase(key)
	_remove_visual_for_key(key)
	EventBus.filth_changed.emit(coord.view_id)
	return true


func clean_at_world(world_position: Vector2, view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	return clean_near_position(world_position, view_id, 3)


func clean_near_position(
	world_position: Vector2,
	view_id: ViewIds.Id = ViewIds.Id.INN_F1,
	max_tile_distance: int = 3
) -> bool:
	if world_position == Vector2.ZERO:
		return false
	var origin: GridCoord = GridCoord.from_local(view_id, world_position)
	if not origin.is_in_bounds():
		return false

	var best_key: String = ""
	var best_distance: int = max_tile_distance + 1
	for key: String in _filth_by_key.keys():
		var coord: GridCoord = GridCoord.from_key(key)
		if coord.view_id != view_id:
			continue
		var distance: int = absi(coord.x - origin.x) + absi(coord.y - origin.y)
		if distance > max_tile_distance:
			continue
		if distance < best_distance:
			best_distance = distance
			best_key = key

	if best_key == "":
		return false
	return clean_at(GridCoord.from_key(best_key))


func has_filth_at(coord: GridCoord) -> bool:
	if coord == null:
		return false
	return _filth_by_key.has(coord.to_key())


func get_filth_at(coord: GridCoord) -> Dictionary:
	if coord == null:
		return {}
	var data: Dictionary = _filth_by_key.get(coord.to_key(), {})
	if data.is_empty():
		return {}
	return {
		"kind": int(data.get("kind", FilthKinds.NO_FILTH)),
		"amount": int(data.get("amount", 0)),
	}


func get_aesthetic_score_at(coord: GridCoord) -> float:
	var data: Dictionary = get_filth_at(coord)
	if data.is_empty():
		return 0.0
	var kind: FilthKinds.Id = FilthKinds.from_value(data.get("kind", FilthKinds.NO_FILTH))
	var amount: int = int(data.get("amount", 0))
	if kind == FilthKinds.NO_FILTH or amount <= 0:
		return 0.0
	return FilthKinds.aesthetic_score_for(kind) * float(amount)


func get_region_filth_total(view_id: ViewIds.Id, region_id: int) -> float:
	if region_id == RoomRegionService.NO_REGION:
		return 0.0
	var total: float = 0.0
	for coord: GridCoord in RoomRegionService.get_region_coords(view_id, region_id):
		total += get_aesthetic_score_at(coord)
	return total


func get_filth_label_at(coord: GridCoord) -> String:
	var data: Dictionary = get_filth_at(coord)
	if data.is_empty():
		return ""
	var kind: FilthKinds.Id = FilthKinds.from_value(data.get("kind", FilthKinds.NO_FILTH))
	var amount: int = int(data.get("amount", 0))
	if kind == FilthKinds.NO_FILTH or amount <= 0:
		return ""
	if amount <= 1:
		return FilthKinds.label_for(kind)
	return "%s x%d" % [FilthKinds.label_for(kind), amount]


func get_filth_coords(view_id: ViewIds.Id) -> Array[GridCoord]:
	var coords: Array[GridCoord] = []
	for key: String in _filth_by_key.keys():
		var coord: GridCoord = GridCoord.from_key(key)
		if coord.view_id != view_id:
			continue
		coords.append(coord.duplicate_coord())
	return coords


func reset_all() -> void:
	_filth_by_key.clear()
	_clear_all_visuals()
	for view_id: ViewIds.Id in ViewIds.all():
		EventBus.filth_changed.emit(view_id)


func export_save_data() -> Dictionary:
	var data: Dictionary = {}
	for key: String in _filth_by_key.keys():
		var coord: GridCoord = GridCoord.from_key(key)
		var view_key: String = str(coord.view_id)
		if not data.has(view_key):
			data[view_key] = []
		var entry: Dictionary = _filth_by_key[key].duplicate()
		entry["x"] = coord.x
		entry["y"] = coord.y
		(data[view_key] as Array).append(entry)
	return data


func import_save_data(data: Dictionary) -> void:
	_filth_by_key.clear()
	_clear_all_visuals()
	for view_key: String in data.keys():
		var view_id: ViewIds.Id = int(view_key) as ViewIds.Id
		for entry_variant in data.get(view_key, []):
			if entry_variant is not Dictionary:
				continue
			var entry: Dictionary = entry_variant
			var coord := GridCoord.new(int(entry.get("x", -1)), int(entry.get("y", -1)), view_id)
			if not coord.is_in_bounds():
				continue
			var kind: FilthKinds.Id = FilthKinds.from_value(entry.get("kind", FilthKinds.NO_FILTH))
			var amount: int = int(entry.get("amount", 0))
			if kind == FilthKinds.NO_FILTH or amount <= 0:
				continue
			_filth_by_key[coord.to_key()] = {
				"kind": kind,
				"amount": amount,
			}
	_refresh_all_visuals()


func _can_hold_filth(coord: GridCoord) -> bool:
	return GridService.get_cell(coord).tile_type == CellData.TileType.FLOOR


func _on_grid_loaded() -> void:
	_refresh_all_visuals()
	for view_id: ViewIds.Id in ViewIds.all():
		EventBus.filth_changed.emit(view_id)


func _sync_visual_for_coord(coord: GridCoord) -> void:
	if coord == null:
		return
	var key: String = coord.to_key()
	var data: Dictionary = _filth_by_key.get(key, {})
	if data.is_empty():
		_remove_visual_for_key(key)
		return

	var kind: FilthKinds.Id = FilthKinds.from_value(data.get("kind", FilthKinds.NO_FILTH))
	var amount: int = int(data.get("amount", 1))
	var visual: FilthVisual = _visual_by_key.get(key) as FilthVisual
	if visual != null and is_instance_valid(visual):
		visual.global_position = coord.to_world_center()
		visual.setup(coord, kind, amount)
		return

	_remove_visual_for_key(key)
	var view: ViewRoot = ViewManager.get_view(coord.view_id)
	if view == null:
		return

	visual = FilthVisual.new()
	visual.global_position = coord.to_world_center()
	visual.setup(coord, kind, amount)
	view.entity_layer.add_child(visual)
	_visual_by_key[key] = visual


func _remove_visual_for_key(key: String) -> void:
	if not _visual_by_key.has(key):
		return
	var visual: Node = _visual_by_key[key]
	_visual_by_key.erase(key)
	if is_instance_valid(visual):
		visual.queue_free()


func _clear_all_visuals() -> void:
	for key: String in _visual_by_key.keys():
		var visual: Node = _visual_by_key[key]
		if is_instance_valid(visual):
			visual.queue_free()
	_visual_by_key.clear()


func _refresh_all_visuals() -> void:
	_clear_all_visuals()
	for key: String in _filth_by_key.keys():
		var coord: GridCoord = GridCoord.from_key(key)
		_sync_visual_for_coord(coord)
