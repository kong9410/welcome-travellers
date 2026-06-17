extends Node

const _DoorKinds := preload("res://scripts/core/door/door_kinds.gd")

const NO_REGION: int = -1

const _CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var _region_by_coord_key: Dictionary = {}
var _coords_by_region_key: Dictionary = {}
var _region_count_by_view: Dictionary = {}
var _dirty_views: Dictionary = {}


func _ready() -> void:
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)
	EventBus.grid_loaded.connect(_on_grid_loaded)
	EventBus.furniture_placed.connect(_on_furniture_changed)
	EventBus.furniture_removed.connect(_on_furniture_changed)
	EventBus.furniture_loaded.connect(_on_furniture_loaded)
	for view_id: ViewIds.Id in ViewIds.all():
		_mark_dirty(view_id)


func rebuild_all_regions() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		rebuild_regions(view_id)


func rebuild_regions(view_id: ViewIds.Id) -> void:
	_clear_view_regions(view_id)

	var grid: BuildingGrid = GridService.get_grid(view_id)
	var visited: Dictionary = {}
	var next_region_id: int = 1

	for coord: GridCoord in grid.get_all_coords():
		if visited.has(coord.to_key()):
			continue
		if not _is_region_floor(grid, coord):
			continue

		var region_coords: Array[GridCoord] = _collect_region(grid, coord, visited)
		if region_coords.is_empty():
			continue

		var region_key: String = _make_region_key(view_id, next_region_id)
		_coords_by_region_key[region_key] = region_coords
		for region_coord: GridCoord in region_coords:
			_region_by_coord_key[region_coord.to_key()] = next_region_id
		next_region_id += 1

	_region_count_by_view[view_id] = next_region_id - 1
	_dirty_views.erase(view_id)


func get_region_id_at(coord: GridCoord) -> int:
	if coord == null or not coord.is_in_bounds():
		return NO_REGION
	_rebuild_if_dirty(coord.view_id)
	return int(_region_by_coord_key.get(coord.to_key(), NO_REGION))


func get_region_id_for_world_position(view_id: ViewIds.Id, world_position: Vector2) -> int:
	return get_region_id_at(GridCoord.from_local(view_id, world_position))


func get_region_id_for_furniture(instance: FurnitureInstance) -> int:
	if instance == null:
		return NO_REGION
	var best_region_id: int = NO_REGION
	for coord: GridCoord in instance.get_occupied_cells():
		var region_id: int = get_region_id_at(coord)
		if region_id != NO_REGION:
			return region_id

		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, coord.view_id)
			region_id = get_region_id_at(neighbor)
			if region_id != NO_REGION:
				best_region_id = region_id
				break
		if best_region_id != NO_REGION:
			break
	return best_region_id


func get_region_coords(view_id: ViewIds.Id, region_id: int) -> Array[GridCoord]:
	_rebuild_if_dirty(view_id)
	var region_key: String = _make_region_key(view_id, region_id)
	var coords: Array[GridCoord] = []
	for coord: GridCoord in _coords_by_region_key.get(region_key, []):
		coords.append(coord.duplicate_coord())
	return coords


func get_region_count(view_id: ViewIds.Id) -> int:
	_rebuild_if_dirty(view_id)
	return int(_region_count_by_view.get(view_id, 0))


func _collect_region(
	grid: BuildingGrid,
	start: GridCoord,
	visited: Dictionary
) -> Array[GridCoord]:
	var result: Array[GridCoord] = []
	var queue: Array[GridCoord] = [start]
	visited[start.to_key()] = true

	while not queue.is_empty():
		var coord: GridCoord = queue.pop_front()
		result.append(coord.duplicate_coord())

		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, coord.view_id)
			var key: String = neighbor.to_key()
			if visited.has(key):
				continue
			if not _is_region_floor(grid, neighbor):
				continue
			visited[key] = true
			queue.append(neighbor)

	return result


func _is_region_floor(grid: BuildingGrid, coord: GridCoord) -> bool:
	if not grid.is_in_bounds(coord):
		return false
	if grid.get_cell(coord).tile_type != CellData.TileType.FLOOR:
		return false
	var door_instance: FurnitureInstance = FurnitureService.get_instance_at(coord)
	if door_instance != null and _DoorKinds.is_interior_door_def(door_instance.def_id):
		return false
	return true


func _rebuild_if_dirty(view_id: ViewIds.Id) -> void:
	if _dirty_views.has(view_id):
		rebuild_regions(view_id)


func _mark_dirty(view_id: ViewIds.Id) -> void:
	_dirty_views[view_id] = true


func _clear_view_regions(view_id: ViewIds.Id) -> void:
	for coord_key: String in _region_by_coord_key.keys():
		var coord: GridCoord = GridCoord.from_key(coord_key)
		if coord.view_id == view_id:
			_region_by_coord_key.erase(coord_key)

	for region_key: String in _coords_by_region_key.keys():
		if region_key.begins_with("%d:" % view_id):
			_coords_by_region_key.erase(region_key)

	_region_count_by_view.erase(view_id)


func _make_region_key(view_id: ViewIds.Id, region_id: int) -> String:
	return "%d:%d" % [view_id, region_id]


func _on_grid_cell_changed(view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	_mark_dirty(view_id)


func _on_grid_loaded() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		_mark_dirty(view_id)


func _on_furniture_changed(instance: FurnitureInstance) -> void:
	if instance == null:
		return
	_mark_dirty(instance.origin.view_id)


func _on_furniture_loaded() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		_mark_dirty(view_id)
