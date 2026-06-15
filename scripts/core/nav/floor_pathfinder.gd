class_name FloorPathfinder
extends RefCounted

static var _path_cache: Dictionary = {}
static var _path_cache_version: Dictionary = {}


static func invalidate_view(view_id: ViewIds.Id) -> void:
	_path_cache_version[view_id] = int(_path_cache_version.get(view_id, 0)) + 1
	var prefix: String = "%d|" % view_id
	for cache_key: String in _path_cache.keys():
		if cache_key.begins_with(prefix):
			_path_cache.erase(cache_key)


static func find_path(view_id: ViewIds.Id, from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	return _find_path(
		view_id,
		from_world,
		to_world,
		InnLayoutHelper.is_customer_walkable,
		_resolve_customer_coord
	)


static func find_floor_path(view_id: ViewIds.Id, from_world: Vector2, to_world: Vector2) -> Array[Vector2]:
	return _find_path(
		view_id,
		from_world,
		to_world,
		InnLayoutHelper.is_floor_walkable,
		_resolve_floor_coord
	)


static func _find_path(
	view_id: ViewIds.Id,
	from_world: Vector2,
	to_world: Vector2,
	is_walkable: Callable,
	resolve_coord: Callable
) -> Array[Vector2]:
	var start_coord: GridCoord = resolve_coord.call(view_id, from_world)
	var goal_coord: GridCoord = resolve_coord.call(view_id, to_world)
	if not start_coord.is_in_bounds() or not goal_coord.is_in_bounds():
		return []
	if start_coord.equals(goal_coord):
		return []

	var cache_key: String = "%d|%s|%s" % [view_id, start_coord.to_key(), goal_coord.to_key()]
	var cache_version: int = int(_path_cache_version.get(view_id, 0))
	if _path_cache.has(cache_key):
		var cached: Dictionary = _path_cache[cache_key] as Dictionary
		if int(cached.get("version", -1)) == cache_version:
			return (cached.get("path", []) as Array[Vector2]).duplicate()

	var came_from: Dictionary = {}
	var queue: Array[GridCoord] = [start_coord]
	came_from[start_coord.to_key()] = null

	while not queue.is_empty():
		var current: GridCoord = queue.pop_front()
		if current.equals(goal_coord):
			var path: Array[Vector2] = _reconstruct_path(start_coord, goal_coord, came_from)
			_path_cache[cache_key] = {
				"path": path,
				"version": cache_version,
			}
			return path.duplicate()

		for neighbor: GridCoord in _neighbors(current):
			var key: String = neighbor.to_key()
			if came_from.has(key):
				continue
			if not is_walkable.call(neighbor):
				continue
			came_from[key] = current
			queue.append(neighbor)

	return []


static func _resolve_customer_coord(view_id: ViewIds.Id, world_position: Vector2) -> GridCoord:
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if InnLayoutHelper.is_customer_walkable(coord):
		return coord
	var snapped: Vector2 = InnLayoutHelper.get_closest_customer_walkable_point(view_id, world_position)
	if snapped == Vector2.ZERO:
		return GridCoord.new(-1, -1, view_id)
	return GridCoord.from_local(view_id, snapped)


static func _resolve_floor_coord(view_id: ViewIds.Id, world_position: Vector2) -> GridCoord:
	var coord: GridCoord = GridCoord.from_local(view_id, world_position)
	if InnLayoutHelper.is_floor_walkable(coord):
		return coord
	var snapped: Vector2 = InnLayoutHelper.get_closest_floor_world_point(view_id, world_position)
	if snapped == Vector2.ZERO:
		return GridCoord.new(-1, -1, view_id)
	return GridCoord.from_local(view_id, snapped)


static func _neighbors(coord: GridCoord) -> Array[GridCoord]:
	return [
		GridCoord.new(coord.x + 1, coord.y, coord.view_id),
		GridCoord.new(coord.x - 1, coord.y, coord.view_id),
		GridCoord.new(coord.x, coord.y + 1, coord.view_id),
		GridCoord.new(coord.x, coord.y - 1, coord.view_id),
	]


static func _reconstruct_path(
	start: GridCoord,
	goal: GridCoord,
	came_from: Dictionary
) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var current: GridCoord = goal
	while not current.equals(start):
		path.push_front(current.to_world_center())
		var key: String = current.to_key()
		if not came_from.has(key):
			return []
		var parent: Variant = came_from[key]
		if parent == null:
			return []
		current = parent as GridCoord
	return path
