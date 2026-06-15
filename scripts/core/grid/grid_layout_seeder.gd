class_name GridLayoutSeeder
extends RefCounted

static func seed_all(grids: Dictionary) -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		if grids.has(view_id):
			seed_view(grids[view_id] as BuildingGrid)


static func seed_view(grid: BuildingGrid) -> void:
	match grid.view_id:
		ViewIds.Id.OUTSIDE:
			_seed_outside(grid)
		ViewIds.Id.INN_F1:
			_seed_inn_f1(grid)
		ViewIds.Id.INN_BASEMENT:
			_seed_inn_basement(grid)
		_:
			if GridLayoutRules.is_inn_view(grid.view_id):
				_seed_inn_shell(grid)


static func enforce_locked_cells(grids: Dictionary) -> void:
	if grids.has(ViewIds.Id.OUTSIDE):
		_enforce_outside(grids[ViewIds.Id.OUTSIDE] as BuildingGrid)
	for view_id: ViewIds.Id in [
		ViewIds.Id.INN_F1,
		ViewIds.Id.INN_F2,
		ViewIds.Id.INN_F3,
		ViewIds.Id.INN_BASEMENT,
	]:
		if grids.has(view_id):
			enforce_inn_walls(grids[view_id] as BuildingGrid)
	if grids.has(ViewIds.Id.INN_F1):
		_enforce_inn_door(grids[ViewIds.Id.INN_F1] as BuildingGrid)
		ensure_owner_room_floor(grids[ViewIds.Id.INN_F1] as BuildingGrid)


static func _seed_outside(grid: BuildingGrid) -> void:
	grid.clear()
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(size.y):
		for x in range(size.x):
			var coord := GridCoord.new(x, y, ViewIds.Id.OUTSIDE)
			if GridLayoutRules.is_outside_building_wall(coord):
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.WALL))
			elif GridLayoutRules.is_outside_building_door(coord):
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.DOOR))
			else:
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.OUTSIDE_GROUND))


static func _seed_inn_shell(grid: BuildingGrid) -> void:
	grid.clear()
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(size.y):
		for x in range(size.x):
			var coord := GridCoord.new(x, y, grid.view_id)
			grid.set_cell(coord, CellData.create_for_type(CellData.TileType.WALL))


static func _seed_inn_f1(grid: BuildingGrid) -> void:
	_seed_inn_shell(grid)
	grid.set_cell(
		GridLayoutRules.default_inn_door_coord(ViewIds.Id.INN_F1),
		CellData.create_for_type(CellData.TileType.DOOR)
	)
	seed_starter_inn_floors(grid)
	grid.set_cell(
		GridCoord.new(20, 14, ViewIds.Id.INN_F1),
		CellData.create_for_type(CellData.TileType.STAIRS_DOWN)
	)


static func _seed_inn_basement(grid: BuildingGrid) -> void:
	_seed_inn_shell(grid)
	seed_starter_basement_floors(grid)
	grid.set_cell(
		GridCoord.new(20, 14, ViewIds.Id.INN_BASEMENT),
		CellData.create_for_type(CellData.TileType.STAIRS_UP)
	)


static func seed_starter_inn_floors(grid: BuildingGrid) -> void:
	if grid.view_id != ViewIds.Id.INN_F1:
		return
	ensure_owner_room_floor(grid)
	_paint_floor_rect(grid, Rect2i(6, 8, 16, 9))
	_paint_floor_rect(grid, Rect2i(16, 4, 6, 4))


static func seed_starter_basement_floors(grid: BuildingGrid) -> void:
	if grid.view_id != ViewIds.Id.INN_BASEMENT:
		return
	_paint_floor_rect(grid, Rect2i(3, 6, 14, 8))


static func _paint_floor_rect(grid: BuildingGrid, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coord := GridCoord.new(x, y, grid.view_id)
			if not GridLayoutRules.is_inn_interior(coord):
				continue
			if GridLayoutRules.is_owner_room_cell(coord):
				continue
			grid.set_cell(coord, CellData.create_for_type(CellData.TileType.FLOOR))


static func enforce_inn_walls(grid: BuildingGrid) -> void:
	if not GridLayoutRules.is_inn_view(grid.view_id):
		return
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(size.y):
		for x in range(size.x):
			var coord := GridCoord.new(x, y, grid.view_id)
			if grid.get_cell(coord).is_empty():
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.WALL))


static func ensure_owner_room_floor(grid: BuildingGrid) -> void:
	if grid.view_id != ViewIds.Id.INN_F1:
		return
	for y in range(GridLayoutRules.OWNER_ROOM_SIZE.y):
		for x in range(GridLayoutRules.OWNER_ROOM_SIZE.x):
			var coord := GridCoord.new(
				GridLayoutRules.OWNER_ROOM_ORIGIN.x + x,
				GridLayoutRules.OWNER_ROOM_ORIGIN.y + y,
				ViewIds.Id.INN_F1
			)
			grid.set_cell(coord, CellData.create_for_type(CellData.TileType.FLOOR))


static func _enforce_outside(grid: BuildingGrid) -> void:
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	for y in range(size.y):
		for x in range(size.x):
			var coord := GridCoord.new(x, y, ViewIds.Id.OUTSIDE)
			if GridLayoutRules.is_outside_building_wall(coord):
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.WALL))
			elif GridLayoutRules.is_outside_building_door(coord):
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.DOOR))
			elif GridLayoutRules.is_map_border(coord):
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.OUTSIDE_GROUND))
			elif grid.get_cell(coord).is_empty():
				grid.set_cell(coord, CellData.create_for_type(CellData.TileType.OUTSIDE_GROUND))


static func _enforce_inn_door(grid: BuildingGrid) -> void:
	var door_coord: GridCoord = _find_door_coord(grid)
	if door_coord.is_in_bounds() and GridLayoutRules.is_inn_perimeter(door_coord):
		return

	for coord: GridCoord in grid.get_all_coords():
		if grid.get_cell(coord).tile_type == CellData.TileType.DOOR:
			grid.set_cell(coord, CellData.create_for_type(CellData.TileType.WALL))

	grid.set_cell(
		GridLayoutRules.default_inn_door_coord(ViewIds.Id.INN_F1),
		CellData.create_for_type(CellData.TileType.DOOR)
	)


static func _find_door_coord(grid: BuildingGrid) -> GridCoord:
	for coord: GridCoord in grid.get_all_coords():
		if grid.get_cell(coord).tile_type == CellData.TileType.DOOR:
			return coord
	return GridCoord.new(-1, -1, grid.view_id)
