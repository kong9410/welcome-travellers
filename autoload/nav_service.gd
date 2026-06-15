extends Node

var _map_synced: Dictionary = {}


func _ready() -> void:
	NavigationServer2D.map_changed.connect(_on_navigation_map_changed)
	EventBus.grid_cell_changed.connect(_on_grid_changed)
	EventBus.grid_loaded.connect(_on_grid_loaded)
	EventBus.furniture_placed.connect(_on_furniture_changed)
	EventBus.furniture_removed.connect(_on_furniture_changed)
	EventBus.furniture_loaded.connect(_on_furniture_loaded)


func is_walkable_for_unit(coord: GridCoord) -> bool:
	if not coord.is_in_bounds():
		return false
	if not GridService.is_walkable(coord):
		return false
	if FurnitureService.blocks_movement_at(coord):
		return false
	return true


func is_walkable_world(view_id: ViewIds.Id, world_position: Vector2) -> bool:
	var coord := GridCoord.from_local(view_id, world_position)
	return is_walkable_for_unit(coord)


func is_map_synchronized(view_id: ViewIds.Id) -> bool:
	return _map_synced.get(view_id, false)


func get_closest_walkable_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	var navigation_map: RID = _get_navigation_map(view_id)
	if is_map_synchronized(view_id) and navigation_map.is_valid():
		return NavigationServer2D.map_get_closest_point(navigation_map, world_position)
	return _fallback_walkable_point(view_id, world_position)


func rebuild_view(view_id: ViewIds.Id) -> void:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null or view.navigation_region == null:
		return

	_map_synced[view_id] = false
	view.navigation_region.navigation_polygon = NavPolygonBuilder.build_for_view(view_id)
	EventBus.navigation_rebuilt.emit(view_id)


func rebuild_all_views() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		rebuild_view(view_id)


func _fallback_walkable_point(view_id: ViewIds.Id, world_position: Vector2) -> Vector2:
	if is_walkable_world(view_id, world_position):
		return world_position

	var origin := GridCoord.from_local(view_id, world_position)
	if is_walkable_for_unit(origin):
		return origin.to_world_center()

	for radius in range(1, 10):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				if abs(offset_x) != radius and abs(offset_y) != radius:
					continue
				var coord := GridCoord.new(origin.x + offset_x, origin.y + offset_y, view_id)
				if is_walkable_for_unit(coord):
					return coord.to_world_center()

	return world_position if is_walkable_world(view_id, world_position) else Vector2.ZERO


func _get_navigation_map(view_id: ViewIds.Id) -> RID:
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null or view.navigation_region == null:
		return RID()
	return view.navigation_region.get_navigation_map()


func _mark_map_ready_for_rid(map_rid: RID) -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		if _get_navigation_map(view_id) == map_rid:
			if _map_synced.get(view_id, false):
				return
			_map_synced[view_id] = true
			EventBus.navigation_map_ready.emit(view_id)


func _on_navigation_map_changed(map_rid: RID) -> void:
	_mark_map_ready_for_rid(map_rid)


func _on_grid_changed(changed_view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	rebuild_view(changed_view_id)


func _on_grid_loaded() -> void:
	rebuild_all_views()


func _on_furniture_changed(instance: FurnitureInstance) -> void:
	rebuild_view(instance.origin.view_id)


func _on_furniture_loaded() -> void:
	rebuild_all_views()
