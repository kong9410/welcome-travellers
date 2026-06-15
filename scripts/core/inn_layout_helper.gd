class_name InnLayoutHelper
extends RefCounted

const _CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

enum StandSide {
	FRONT,
	BACK,
	ANY,
}

static func find_tile(view_id: ViewIds.Id, tile_type: CellData.TileType) -> GridCoord:
	var grid: BuildingGrid = GridService.get_grid(view_id)
	for coord: GridCoord in grid.get_all_coords():
		if grid.get_cell(coord).tile_type == tile_type:
			return coord
	return GridCoord.new(-1, -1, view_id)


static func find_door_coord(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> GridCoord:
	return find_tile(view_id, CellData.TileType.DOOR)


static func has_door(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	return find_door_coord(view_id).is_in_bounds()


static func is_floor_walkable(coord: GridCoord) -> bool:
	if not NavService.is_walkable_for_unit(coord):
		return false
	return GridService.get_cell(coord).tile_type == CellData.TileType.FLOOR


static func is_customer_walkable(coord: GridCoord) -> bool:
	if not coord.is_in_bounds():
		return false
	if GridService.get_cell(coord).tile_type != CellData.TileType.FLOOR:
		return false
	return FurnitureService.can_customer_stand_at(coord)


static func get_furniture_customer_position(instance: FurnitureInstance) -> Vector2:
	var cells: Array[GridCoord] = instance.get_occupied_cells()
	if cells.is_empty():
		return Vector2.ZERO
	if cells.size() == 1:
		return cells[0].to_world_center()
	return _instance_world_center(instance)


static func exact_customer_world_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if is_customer_walkable(coord):
		return coord.to_world_center()
	return get_closest_customer_walkable_point(view_id, world_position)


static func get_closest_customer_walkable_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var origin: GridCoord = GridCoord.from_local(view_id, world_position)
	if is_customer_walkable(origin):
		return origin.to_world_center()

	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for radius in range(1, max(size.x, size.y)):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var coord := GridCoord.new(origin.x + offset_x, origin.y + offset_y, view_id)
				if is_customer_walkable(coord):
					return coord.to_world_center()
	return Vector2.ZERO


static func find_entry_coord(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> GridCoord:
	var door_coord: GridCoord = find_door_coord(view_id)
	if not door_coord.is_in_bounds():
		return GridCoord.new(-1, -1, view_id)

	var inward_offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
	]
	for offset: Vector2i in inward_offsets:
		var entry_coord := GridCoord.new(door_coord.x + offset.x, door_coord.y + offset.y, view_id)
		if is_floor_walkable(entry_coord):
			return entry_coord
	return GridCoord.new(-1, -1, view_id)


static func find_entry_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	var entry_coord: GridCoord = find_entry_coord(view_id)
	if entry_coord.is_in_bounds():
		return entry_coord.to_world_center()
	return Vector2.ZERO


static func find_exit_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	return find_entry_position(view_id)


static func snap_to_floor_world(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var snapped: Vector2 = get_closest_floor_world_point(view_id, world_position)
	if snapped != Vector2.ZERO:
		return snapped
	return world_position


static func get_closest_floor_world_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var origin: GridCoord = GridCoord.from_local(view_id, world_position)
	if is_floor_walkable(origin):
		return origin.to_world_center()

	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for radius in range(1, max(size.x, size.y)):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var coord := GridCoord.new(origin.x + offset_x, origin.y + offset_y, view_id)
				if is_floor_walkable(coord):
					return coord.to_world_center()
	return Vector2.ZERO


static func exact_floor_world_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if is_floor_walkable(coord):
		return coord.to_world_center()
	return get_closest_floor_world_point(view_id, world_position)


static func find_counter_customer_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	return _find_furniture_stand_position(view_id, "service", StandSide.FRONT)


static func find_kitchen_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	var patrol_points: Array[Vector2] = get_kitchen_patrol_points(view_id)
	if not patrol_points.is_empty():
		return patrol_points[0]
	return find_interior_fallback_position(view_id)


static func get_kitchen_patrol_points(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	var seen: Dictionary = {}

	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		var definition: FurnitureDefinition = FurnitureCatalog.get_definition(instance.def_id)
		if definition.category != "kitchen":
			continue
		for coord: GridCoord in instance.get_occupied_cells():
			for offset: Vector2i in _CARDINAL_OFFSETS:
				var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
				var key: String = neighbor.to_key()
				if seen.has(key):
					continue
				if not is_floor_walkable(neighbor):
					continue
				seen[key] = true
				candidates.append(neighbor.to_world_center())

	if candidates.is_empty():
		return []

	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.x < b.x if absf(a.x - b.x) > 0.01 else a.y < b.y
	)

	if candidates.size() == 1:
		var lone: Vector2 = candidates[0]
		var lone_coord: GridCoord = GridCoord.from_local(view_id, lone)
		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(lone_coord.x + offset.x, lone_coord.y + offset.y, view_id)
			if is_floor_walkable(neighbor):
				candidates.append(neighbor.to_world_center())
				break

	var max_points: int = mini(candidates.size(), 4)
	return candidates.slice(0, max_points) as Array[Vector2]


const MAX_COUNTER_QUEUE_SLOTS: int = 8


static func get_counter_queue_position(view_id: ViewIds.Id, queue_index: int) -> Vector2:
	return get_counter_queue_position_at(view_id, queue_index, {})


static func get_counter_queue_position_at(
	view_id: ViewIds.Id,
	queue_index: int,
	reserved_coords: Dictionary
) -> Vector2:
	var layout: Dictionary = _get_counter_queue_layout(view_id)
	if layout.is_empty():
		return Vector2.ZERO

	var front_coord: GridCoord = _resolve_customer_queue_coord(view_id, layout["front"] as Vector2)
	if not front_coord.is_in_bounds():
		return Vector2.ZERO

	var step_grid: Vector2i = layout.get("step_grid", Vector2i(0, 1))
	var slot_coord: GridCoord = _find_unique_queue_coord(
		view_id,
		front_coord,
		step_grid,
		queue_index,
		reserved_coords
	)
	if not slot_coord.is_in_bounds():
		return Vector2.ZERO
	return slot_coord.to_world_center()


static func invalidate_counter_queue_cache(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> void:
	_counter_queue_layout_cache.erase(view_id)
	_invalidate_customer_reachability_cache(view_id)
	FloorPathfinder.invalidate_view(view_id)


static var _counter_queue_layout_cache: Dictionary = {}
static var _customer_reachability_cache: Dictionary = {}


static func prepare_counter_queue_layout(view_id: ViewIds.Id, queue_size: int) -> void:
	var needed_slots: int = maxi(MAX_COUNTER_QUEUE_SLOTS, queue_size)
	if _counter_queue_layout_cache.has(view_id):
		var cached_path: Variant = (_counter_queue_layout_cache[view_id] as Dictionary).get("path_coords")
		if cached_path is Array and (cached_path as Array).size() >= needed_slots:
			return
	_rebuild_counter_queue_layout(view_id, needed_slots)


static func _get_counter_queue_layout(view_id: ViewIds.Id) -> Dictionary:
	if not _counter_queue_layout_cache.has(view_id):
		_rebuild_counter_queue_layout(view_id, MAX_COUNTER_QUEUE_SLOTS)
	return _counter_queue_layout_cache.get(view_id, {}) as Dictionary


static func _rebuild_counter_queue_layout(view_id: ViewIds.Id, min_slots: int) -> void:
	var front_position: Vector2 = find_counter_customer_position(view_id)
	if front_position == Vector2.ZERO:
		_counter_queue_layout_cache.erase(view_id)
		return

	var front_coord: GridCoord = _resolve_customer_queue_coord(view_id, front_position)
	if not front_coord.is_in_bounds():
		_counter_queue_layout_cache.erase(view_id)
		return

	var step_grid: Vector2i = _choose_queue_step_grid(view_id, front_coord)
	var path_coords: Array[GridCoord] = _build_queue_path_coords(
		view_id,
		front_coord,
		step_grid,
		min_slots
	)
	if path_coords.is_empty():
		_counter_queue_layout_cache.erase(view_id)
		return

	var slots: Array[Vector2] = []
	for coord: GridCoord in path_coords:
		slots.append(exact_customer_world_point(view_id, coord.to_world_center()))

	var layout := {
		"front": slots[0],
		"step": Vector2(step_grid) * float(GameConstants.TILE_SIZE),
		"step_grid": step_grid,
		"path_coords": path_coords,
		"slots": slots,
	}
	_counter_queue_layout_cache[view_id] = layout


static func _resolve_customer_queue_coord(view_id: ViewIds.Id, world_position: Vector2) -> GridCoord:
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if is_customer_walkable(coord):
		return coord
	var snapped: Vector2 = get_closest_customer_walkable_point(view_id, world_position)
	if snapped == Vector2.ZERO:
		return GridCoord.new(-1, -1, view_id)
	return GridCoord.from_local(view_id, snapped)


static func _choose_queue_step_grid(view_id: ViewIds.Id, front_coord: GridCoord) -> Vector2i:
	var entry_coord: GridCoord = find_entry_coord(view_id)
	var preferred_step := Vector2i.ZERO
	var staff_position: Vector2 = find_counter_position(view_id)
	if staff_position != Vector2.ZERO:
		var staff_coord: GridCoord = GridCoord.from_local(view_id, staff_position)
		preferred_step = _quantize_to_cardinal(Vector2i(
			front_coord.x - staff_coord.x,
			front_coord.y - staff_coord.y
		))

	var best_step: Vector2i = Vector2i(0, 1)
	var best_score: float = -INF
	for offset: Vector2i in _CARDINAL_OFFSETS:
		var score: float = _score_queue_direction(view_id, front_coord, offset, entry_coord)
		if preferred_step != Vector2i.ZERO and offset == preferred_step:
			score += 30.0
		if score > best_score:
			best_score = score
			best_step = offset
	return best_step


static func _score_queue_direction(
	view_id: ViewIds.Id,
	start_coord: GridCoord,
	step: Vector2i,
	entry_coord: GridCoord
) -> float:
	var score: float = 0.0
	var depth: int = 0
	var min_width: float = INF
	var current: GridCoord = start_coord

	for _index in range(1, MAX_COUNTER_QUEUE_SLOTS):
		current = GridCoord.new(current.x + step.x, current.y + step.y, view_id)
		if not is_customer_walkable(current):
			break
		if not _is_customer_coord_reachable_from(view_id, start_coord, current):
			break
		depth += 1
		var lane_width: int = _queue_lane_width_at(view_id, current, step)
		min_width = minf(min_width, float(lane_width))
		score += 8.0
		score += float(lane_width) * 4.0

	if depth == 0:
		return -INF

	score += float(depth) * 10.0
	if min_width <= 1.0:
		score -= 35.0
	elif min_width >= 3.0:
		score += 20.0

	if entry_coord.is_in_bounds() and _is_customer_coord_reachable_from(view_id, entry_coord, start_coord):
		score += 18.0

	return score


static func _queue_lane_width_at(view_id: ViewIds.Id, coord: GridCoord, step: Vector2i) -> int:
	var lateral: Vector2i = Vector2i(-step.y, step.x)
	var width: int = 0
	for multiplier: int in [-1, 0, 1]:
		var check := GridCoord.new(
			coord.x + lateral.x * multiplier,
			coord.y + lateral.y * multiplier,
			view_id
		)
		if is_customer_walkable(check):
			width += 1
	return width


static func _can_use_queue_coord(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	coord: GridCoord
) -> bool:
	if not is_customer_walkable(coord):
		return false
	var entry_coord: GridCoord = find_entry_coord(view_id)
	if entry_coord.is_in_bounds():
		return _is_customer_coord_reachable_from(view_id, entry_coord, coord)
	return _is_customer_coord_reachable_from(view_id, front_coord, coord)


static func _build_queue_path_coords(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	primary_step: Vector2i,
	max_slots: int
) -> Array[GridCoord]:
	var path: Array[GridCoord] = []
	if not _can_use_queue_coord(view_id, front_coord, front_coord):
		return path

	path.append(front_coord)
	var current: GridCoord = front_coord

	while path.size() < max_slots:
		var next_coord := GridCoord.new(
			current.x + primary_step.x,
			current.y + primary_step.y,
			view_id
		)
		if not _can_use_queue_coord(view_id, front_coord, next_coord):
			break
		path.append(next_coord)
		current = next_coord

	if path.size() >= max_slots:
		return path

	var turn_step: Vector2i = _choose_queue_turn_step(view_id, front_coord, current, primary_step)
	if turn_step == Vector2i.ZERO:
		return path

	while path.size() < max_slots:
		var next_coord := GridCoord.new(
			current.x + turn_step.x,
			current.y + turn_step.y,
			view_id
		)
		if not _can_use_queue_coord(view_id, front_coord, next_coord):
			break
		path.append(next_coord)
		current = next_coord

	if path.size() >= max_slots:
		return path

	var return_step: Vector2i = -primary_step
	while path.size() < max_slots:
		var next_coord := GridCoord.new(
			current.x + return_step.x,
			current.y + return_step.y,
			view_id
		)
		if not _can_use_queue_coord(view_id, front_coord, next_coord):
			break
		path.append(next_coord)
		current = next_coord

	return path


static func _choose_queue_turn_step(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	corner_coord: GridCoord,
	primary_step: Vector2i
) -> Vector2i:
	var lateral_left: Vector2i = Vector2i(-primary_step.y, primary_step.x)
	var lateral_right: Vector2i = Vector2i(primary_step.y, -primary_step.x)
	var entry_coord: GridCoord = find_entry_coord(view_id)

	var best_step: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	for turn_step: Vector2i in [lateral_left, lateral_right]:
		var score: float = _score_queue_turn_leg(
			view_id,
			front_coord,
			corner_coord,
			turn_step,
			entry_coord
		)
		if score > best_score:
			best_score = score
			best_step = turn_step
	return best_step


static func _score_queue_turn_leg(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	corner_coord: GridCoord,
	turn_step: Vector2i,
	entry_coord: GridCoord
) -> float:
	var first_coord := GridCoord.new(
		corner_coord.x + turn_step.x,
		corner_coord.y + turn_step.y,
		view_id
	)
	if not _can_use_queue_coord(view_id, front_coord, first_coord):
		return -INF

	var score: float = 0.0
	var depth: int = 0
	var min_width: float = INF
	var current: GridCoord = corner_coord
	for _index in range(1, MAX_COUNTER_QUEUE_SLOTS):
		current = GridCoord.new(current.x + turn_step.x, current.y + turn_step.y, view_id)
		if not _can_use_queue_coord(view_id, front_coord, current):
			break
		depth += 1
		var lane_width: int = _queue_lane_width_at(view_id, current, turn_step)
		min_width = minf(min_width, float(lane_width))
		score += 8.0
		score += float(lane_width) * 4.0

	if depth == 0:
		return -INF

	score += float(depth) * 10.0
	if min_width <= 1.0:
		score -= 35.0
	elif min_width >= 3.0:
		score += 20.0

	if entry_coord.is_in_bounds():
		var entry_dir: Vector2i = _quantize_to_cardinal(Vector2i(
			entry_coord.x - corner_coord.x,
			entry_coord.y - corner_coord.y
		))
		if entry_dir == turn_step:
			score += 15.0

	return score


static func _queue_path_slot_count(queue_index: int) -> int:
	return maxi(MAX_COUNTER_QUEUE_SLOTS, queue_index + 1)


static func _get_queue_path_coords(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	step_grid: Vector2i,
	queue_index: int = -1
) -> Array[GridCoord]:
	var min_slots: int = MAX_COUNTER_QUEUE_SLOTS if queue_index < 0 else _queue_path_slot_count(queue_index)
	prepare_counter_queue_layout(view_id, min_slots)
	var layout: Dictionary = _get_counter_queue_layout(view_id)
	if layout.is_empty():
		return []
	var cached_path: Variant = layout.get("path_coords")
	if cached_path is Array:
		return cached_path as Array[GridCoord]
	return []


static func _find_unique_queue_coord(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	step_grid: Vector2i,
	queue_index: int,
	reserved_coords: Dictionary
) -> GridCoord:
	for candidate: GridCoord in _queue_coord_candidates(view_id, front_coord, step_grid, queue_index):
		if _is_available_queue_coord(candidate, reserved_coords):
			return candidate
	return GridCoord.new(-1, -1, view_id)


static func _queue_coord_for_index(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	step_grid: Vector2i,
	queue_index: int
) -> GridCoord:
	var path_coords: Array[GridCoord] = _get_queue_path_coords(
		view_id,
		front_coord,
		step_grid,
		queue_index
	)
	if queue_index < path_coords.size():
		return path_coords[queue_index]

	var working_path: Array[GridCoord] = path_coords.duplicate()
	var extend_step: Vector2i = _queue_path_extend_step(working_path, step_grid)
	var current: GridCoord = working_path[working_path.size() - 1]
	for _index in range(working_path.size(), _queue_path_slot_count(queue_index) + 1):
		current = GridCoord.new(
			current.x + extend_step.x,
			current.y + extend_step.y,
			view_id
		)
		if not _can_use_queue_coord(view_id, front_coord, current):
			break
		working_path.append(current)
		if queue_index < working_path.size():
			return working_path[queue_index]

	return GridCoord.new(-1, -1, view_id)


static func _queue_coord_candidates(
	view_id: ViewIds.Id,
	front_coord: GridCoord,
	step_grid: Vector2i,
	queue_index: int
) -> Array[GridCoord]:
	var path_coords: Array[GridCoord] = _get_queue_path_coords(
		view_id,
		front_coord,
		step_grid,
		queue_index
	)
	var candidates: Array[GridCoord] = []
	if path_coords.is_empty():
		return candidates

	for path_index in range(queue_index, path_coords.size()):
		candidates.append(path_coords[path_index])

	if queue_index < path_coords.size():
		return _dedupe_coords(candidates)

	var extend_step: Vector2i = _queue_path_extend_step(path_coords, step_grid)
	var spill_coord: GridCoord = path_coords[path_coords.size() - 1]
	for _spill_index in range(1, MAX_COUNTER_QUEUE_SLOTS):
		spill_coord = GridCoord.new(
			spill_coord.x + extend_step.x,
			spill_coord.y + extend_step.y,
			view_id
		)
		if _can_use_queue_coord(view_id, front_coord, spill_coord):
			candidates.append(spill_coord)

	return _dedupe_coords(candidates)


static func _queue_path_extend_step(path_coords: Array[GridCoord], primary_step: Vector2i) -> Vector2i:
	if path_coords.size() >= 2:
		var previous: GridCoord = path_coords[path_coords.size() - 2]
		var last: GridCoord = path_coords[path_coords.size() - 1]
		return Vector2i(last.x - previous.x, last.y - previous.y)
	return primary_step


static func _is_available_queue_coord(coord: GridCoord, reserved_coords: Dictionary) -> bool:
	if not coord.is_in_bounds() or not is_customer_walkable(coord):
		return false
	return not reserved_coords.has(coord.to_key())


static func _dedupe_coords(coords: Array[GridCoord]) -> Array[GridCoord]:
	var seen: Dictionary = {}
	var result: Array[GridCoord] = []
	for coord: GridCoord in coords:
		var key: String = coord.to_key()
		if seen.has(key):
			continue
		seen[key] = true
		result.append(coord)
	return result


static func _is_customer_coord_reachable_from(
	view_id: ViewIds.Id,
	start: GridCoord,
	target: GridCoord
) -> bool:
	if start.equals(target):
		return true
	return _customer_reachability_lookup(view_id, start).has(target.to_key())


static func _customer_reachability_lookup(view_id: ViewIds.Id, start: GridCoord) -> Dictionary:
	var cache_key: String = "%d|%s" % [view_id, start.to_key()]
	if _customer_reachability_cache.has(cache_key):
		return _customer_reachability_cache[cache_key] as Dictionary

	var reachable: Dictionary = {}
	var queue: Array[GridCoord] = [start]
	reachable[start.to_key()] = true

	while not queue.is_empty():
		var coord: GridCoord = queue.pop_front()
		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
			var key: String = neighbor.to_key()
			if reachable.has(key):
				continue
			if not is_customer_walkable(neighbor):
				continue
			reachable[key] = true
			queue.append(neighbor)

	_customer_reachability_cache[cache_key] = reachable
	return reachable


static func _invalidate_customer_reachability_cache(view_id: ViewIds.Id) -> void:
	var prefix: String = "%d|" % view_id
	for cache_key: String in _customer_reachability_cache.keys():
		if cache_key.begins_with(prefix):
			_customer_reachability_cache.erase(cache_key)


static func _quantize_to_cardinal(delta: Vector2i) -> Vector2i:
	if delta == Vector2i.ZERO:
		return Vector2i.ZERO
	if abs(delta.x) >= abs(delta.y):
		return Vector2i(signi(delta.x), 0)
	return Vector2i(0, signi(delta.y))


static func get_instance_by_id(view_id: ViewIds.Id, instance_id: String) -> FurnitureInstance:
	if instance_id == "":
		return null
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		if instance.instance_id == instance_id:
			return instance
	return null


static func chair_has_table(view_id: ViewIds.Id, chair_instance_id: String) -> bool:
	var chair: FurnitureInstance = get_instance_by_id(view_id, chair_instance_id)
	if chair == null:
		return false
	return _instance_has_adjacent_table(view_id, chair)


static func get_table_serve_position(view_id: ViewIds.Id, chair_instance_id: String) -> Vector2:
	var chair: FurnitureInstance = get_instance_by_id(view_id, chair_instance_id)
	if chair == null:
		return Vector2.ZERO
	var table: FurnitureInstance = _find_adjacent_table_for_instance(view_id, chair)
	if table == null:
		return Vector2.ZERO
	return get_furniture_customer_position(table)


static func get_table_food_position(view_id: ViewIds.Id, chair_instance_id: String) -> Vector2:
	var chair: FurnitureInstance = get_instance_by_id(view_id, chair_instance_id)
	if chair == null:
		return Vector2.ZERO
	var table: FurnitureInstance = _find_adjacent_table_for_instance(view_id, chair)
	if table == null:
		return Vector2.ZERO

	var chair_center: Vector2 = _instance_world_center(chair)
	var table_cells: Array[GridCoord] = table.get_occupied_cells()
	if table_cells.is_empty():
		return Vector2.ZERO

	var best_cell: GridCoord = table_cells[0]
	var best_distance: float = INF
	for cell: GridCoord in table_cells:
		var distance: float = chair_center.distance_squared_to(cell.to_world_center())
		if distance < best_distance:
			best_distance = distance
			best_cell = cell
	return best_cell.to_world_center()


static func find_available_chair(
	view_id: ViewIds.Id,
	reserved_instance_ids: Dictionary = {},
	approach_from: Vector2 = Vector2.ZERO
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		if instance.def_id != "chair":
			continue
		if reserved_instance_ids.has(instance.instance_id):
			continue
		if not _instance_has_adjacent_table(view_id, instance):
			continue
		var stand_position: Vector2 = get_furniture_customer_position(instance)
		if stand_position == Vector2.ZERO:
			continue
		var score: float = 0.0
		if approach_from != Vector2.ZERO:
			score -= approach_from.distance_to(stand_position)
		if score > best_score:
			best_score = score
			best = {
				"instance_id": instance.instance_id,
				"position": stand_position,
			}
	return best


static func find_available_bed(
	view_id: ViewIds.Id,
	reserved_instance_ids: Dictionary = {},
	approach_from: Vector2 = Vector2.ZERO
) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		if instance.def_id != "bed":
			continue
		if reserved_instance_ids.has(instance.instance_id):
			continue
		var stand_position: Vector2 = get_furniture_customer_position(instance)
		if stand_position == Vector2.ZERO:
			continue
		var score: float = 0.0
		if approach_from != Vector2.ZERO:
			score -= approach_from.distance_to(stand_position)
		if score > best_score:
			best_score = score
			best = {
				"instance_id": instance.instance_id,
				"position": stand_position,
			}
	return best


static func get_clean_position(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	if world_position == Vector2.ZERO:
		return Vector2.ZERO
	var snapped: Vector2 = exact_floor_world_point(view_id, world_position)
	if snapped != Vector2.ZERO:
		return snapped
	return get_closest_floor_world_point(view_id, world_position)


static func is_near_world_position(
	world_position: Vector2,
	target_position: Vector2,
	tolerance: float = 18.0
) -> bool:
	if target_position == Vector2.ZERO:
		return false
	return world_position.distance_to(target_position) <= tolerance


static func find_seat_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1, prefer_lodging: bool = false) -> Vector2:
	var preferred_categories: Array[String]
	if prefer_lodging:
		preferred_categories = ["lodging", "seating"] as Array[String]
	else:
		preferred_categories = ["seating", "lodging"] as Array[String]
	for category: String in preferred_categories:
		for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
			var definition: FurnitureDefinition = FurnitureCatalog.get_definition(instance.def_id)
			if definition.category != category:
				continue
			var stand_position: Vector2 = _find_stand_position_for_instance(view_id, instance)
			if stand_position != Vector2.ZERO:
				return stand_position

	return _random_reachable_floor_position(view_id)


static func has_service_space(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	if not has_door(view_id):
		return false
	if not find_entry_coord(view_id).is_in_bounds():
		return false
	return has_interior_floor(view_id)


static func has_interior_floor(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> bool:
	var grid: BuildingGrid = GridService.get_grid(view_id)
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var coord := GridCoord.new(x, y, view_id)
			var cell: CellData = grid.get_cell(coord)
			if cell.tile_type == CellData.TileType.FLOOR and cell.is_walkable:
				return true
	return false


static func _random_reachable_floor_position(view_id: ViewIds.Id) -> Vector2:
	var entry_coord: GridCoord = find_entry_coord(view_id)
	var candidates: Array[GridCoord] = []
	if entry_coord.is_in_bounds():
		candidates = _floor_coords_reachable_from(view_id, entry_coord)
	else:
		candidates = _all_interior_floor_coords(view_id)
	if candidates.is_empty():
		return Vector2.ZERO
	return candidates[randi() % candidates.size()].to_world_center()


static func _all_interior_floor_coords(view_id: ViewIds.Id) -> Array[GridCoord]:
	var result: Array[GridCoord] = []
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var coord := GridCoord.new(x, y, view_id)
			if is_floor_walkable(coord):
				result.append(coord)
	return result


static func _floor_coords_reachable_from(view_id: ViewIds.Id, start: GridCoord) -> Array[GridCoord]:
	var visited: Dictionary = {}
	var queue: Array[GridCoord] = [start]
	var reachable: Array[GridCoord] = []
	visited[start.to_key()] = true

	while not queue.is_empty():
		var coord: GridCoord = queue.pop_front()
		reachable.append(coord)
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
			var key: String = neighbor.to_key()
			if visited.has(key):
				continue
			if not is_floor_walkable(neighbor):
				continue
			visited[key] = true
			queue.append(neighbor)
	return reachable


static func find_counter_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	return _find_furniture_stand_position(view_id, "service", StandSide.BACK)


static func find_owner_room_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	var owner_bed_position: Vector2 = _find_furniture_stand_position(view_id, "owner_room")
	if owner_bed_position != Vector2.ZERO:
		return owner_bed_position
	if view_id != ViewIds.Id.INN_F1:
		return Vector2.ZERO
	var rest_coord := GridCoord.new(
		GridLayoutRules.OWNER_ROOM_ORIGIN.x + 1,
		GridLayoutRules.OWNER_ROOM_ORIGIN.y + 1,
		view_id
	)
	if is_floor_walkable(rest_coord):
		return rest_coord.to_world_center()
	return Vector2.ZERO


static func find_interior_fallback_position(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> Vector2:
	return _random_reachable_floor_position(view_id)


static func _find_furniture_stand_position(
	view_id: ViewIds.Id,
	category: String,
	side: StandSide = StandSide.ANY
) -> Vector2:
	for instance: FurnitureInstance in FurnitureService.get_instances(view_id):
		var definition: FurnitureDefinition = FurnitureCatalog.get_definition(instance.def_id)
		if definition.category != category:
			continue
		var stand_position: Vector2 = find_stand_position_for_instance(view_id, instance, side)
		if stand_position != Vector2.ZERO:
			return stand_position
	return Vector2.ZERO


static func find_stand_position_for_instance(
	view_id: ViewIds.Id,
	instance: FurnitureInstance,
	side: StandSide = StandSide.FRONT,
	approach_from: Vector2 = Vector2.ZERO
) -> Vector2:
	var best_position: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	var furniture_center: Vector2 = _instance_world_center(instance)
	var front_vector: Vector2 = _furniture_front_vector(instance.rotation_steps)
	var entry_coord: GridCoord = find_entry_coord(view_id)

	for coord: GridCoord in instance.get_occupied_cells():
		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
			if not is_floor_walkable(neighbor):
				continue

			var neighbor_position: Vector2 = neighbor.to_world_center()
			var outward: Vector2 = (neighbor_position - furniture_center).normalized()
			var score: float = 0.0

			match side:
				StandSide.FRONT:
					if outward.dot(front_vector) > 0.55:
						score += 100.0
					elif outward.dot(front_vector) < -0.55:
						score -= 80.0
				StandSide.BACK:
					if outward.dot(front_vector) < -0.55:
						score += 100.0
					elif outward.dot(front_vector) > 0.55:
						score -= 80.0
				StandSide.ANY:
					score += 0.0

			if entry_coord.is_in_bounds() and _is_coord_reachable_from(view_id, entry_coord, neighbor):
				score += 40.0

			if approach_from != Vector2.ZERO:
				score -= approach_from.distance_to(neighbor_position) * 0.05

			if score > best_score:
				best_score = score
				best_position = neighbor_position

	return best_position


static func _furniture_front_vector(rotation_steps: int) -> Vector2:
	match posmod(rotation_steps, 4):
		0:
			return Vector2(0.0, 1.0)
		1:
			return Vector2(-1.0, 0.0)
		2:
			return Vector2(0.0, -1.0)
		_:
			return Vector2(1.0, 0.0)


static func _instance_world_center(instance: FurnitureInstance) -> Vector2:
	var cells: Array[GridCoord] = instance.get_occupied_cells()
	if cells.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for coord: GridCoord in cells:
		sum += coord.to_world_center()
	return sum / float(cells.size())


static func _is_coord_reachable_from(
	view_id: ViewIds.Id,
	start: GridCoord,
	target: GridCoord
) -> bool:
	if start.equals(target):
		return true
	for coord: GridCoord in _floor_coords_reachable_from(view_id, start):
		if coord.equals(target):
			return true
	return false


static func _find_stand_position_for_instance(view_id: ViewIds.Id, instance: FurnitureInstance) -> Vector2:
	return find_stand_position_for_instance(view_id, instance, StandSide.FRONT)


static func _instance_has_adjacent_table(view_id: ViewIds.Id, instance: FurnitureInstance) -> bool:
	return _find_adjacent_table_for_instance(view_id, instance) != null


static func _find_adjacent_table_for_instance(
	view_id: ViewIds.Id,
	instance: FurnitureInstance
) -> FurnitureInstance:
	for coord: GridCoord in instance.get_occupied_cells():
		for offset: Vector2i in _CARDINAL_OFFSETS:
			var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
			var neighbor_instance: FurnitureInstance = FurnitureService.get_instance_at(neighbor)
			if neighbor_instance != null and neighbor_instance.def_id == "table":
				return neighbor_instance
	return null
