extends Node

const SAVE_PATH := "user://inn_grid_save.json"
const SAVE_VERSION := 5

var current_paint_type: CellData.TileType = CellData.TileType.FLOOR

var _grids: Dictionary = {}


func _ready() -> void:
	_reset_grids()
	if not load_game():
		FurnitureLayoutSeeder.seed_defaults()


func get_grid(view_id: ViewIds.Id) -> BuildingGrid:
	if not _grids.has(view_id):
		_grids[view_id] = BuildingGrid.new(view_id)
	return _grids[view_id]


func set_cell(coord: GridCoord, cell: CellData) -> void:
	var grid: BuildingGrid = get_grid(coord.view_id)
	grid.set_cell(coord, cell)
	EventBus.grid_cell_changed.emit(coord.view_id, coord, cell)


func get_cell(coord: GridCoord) -> CellData:
	return get_grid(coord.view_id).get_cell(coord)


func is_walkable(coord: GridCoord) -> bool:
	return get_grid(coord.view_id).is_walkable(coord)


func can_build(coord: GridCoord) -> bool:
	if GridLayoutRules.blocks_build(coord):
		return false
	return get_grid(coord.view_id).can_build(coord)


func can_expand_to(coord: GridCoord, tile_type: CellData.TileType) -> bool:
	return get_grid(coord.view_id).can_expand_to(coord, tile_type)


func resolve_paint_preview_type(coord: GridCoord, tile_type: CellData.TileType) -> CellData.TileType:
	if tile_type == CellData.TileType.EMPTY and GridLayoutRules.is_inn_interior(coord):
		return CellData.TileType.WALL
	return tile_type


func can_paint_tile(coord: GridCoord, tile_type: CellData.TileType = current_paint_type) -> bool:
	return get_paint_block_reason(coord, tile_type) == ""


func get_paint_block_reason(coord: GridCoord, tile_type: CellData.TileType) -> String:
	var grid: BuildingGrid = get_grid(coord.view_id)
	if not grid.is_in_bounds(coord):
		return "맵 밖입니다."

	if tile_type == CellData.TileType.EMPTY:
		return GridLayoutRules.get_erase_block_reason(coord, grid.get_cell(coord))

	if tile_type == CellData.TileType.DOOR and coord.view_id == ViewIds.Id.INN_F1:
		return GridLayoutRules.get_paint_block_reason(coord, tile_type)

	var paint_reason: String = GridLayoutRules.get_paint_block_reason(coord, tile_type)
	if paint_reason != "":
		return paint_reason

	if GameModeManager.is_build_mode() and not grid.can_expand_to(coord, tile_type):
		return "기존 타일과 인접한 곳부터 확장해야 합니다."

	return ""


func paint_tile(coord: GridCoord, tile_type: CellData.TileType = current_paint_type) -> bool:
	var grid: BuildingGrid = get_grid(coord.view_id)
	if not grid.is_in_bounds(coord):
		return false

	var block_reason: String = get_paint_block_reason(coord, tile_type)
	if block_reason != "":
		EventBus.build_blocked.emit(coord, block_reason)
		return false

	if tile_type == CellData.TileType.EMPTY and GridLayoutRules.is_inn_interior(coord):
		tile_type = CellData.TileType.WALL
	elif tile_type == CellData.TileType.DOOR and coord.view_id == ViewIds.Id.INN_F1:
		return _relocate_inn_door(coord)

	grid.set_tile_type(coord, tile_type)
	var cell: CellData = grid.get_cell(coord)
	EventBus.grid_cell_changed.emit(coord.view_id, coord, cell)
	return true


func _relocate_inn_door(coord: GridCoord) -> bool:
	if coord.view_id != ViewIds.Id.INN_F1 or not GridLayoutRules.is_inn_perimeter(coord):
		return false

	var grid: BuildingGrid = get_grid(coord.view_id)
	var old_door: GridCoord = InnLayoutHelper.find_door_coord(coord.view_id)
	if old_door.is_in_bounds() and not old_door.equals(coord):
		grid.set_tile_type(old_door, CellData.TileType.WALL)
		EventBus.grid_cell_changed.emit(
			coord.view_id,
			old_door,
			grid.get_cell(old_door)
		)

	grid.set_tile_type(coord, CellData.TileType.DOOR)
	var cell: CellData = grid.get_cell(coord)
	EventBus.grid_cell_changed.emit(coord.view_id, coord, cell)
	return true


func try_traverse_tile(coord: GridCoord) -> bool:
	var cell: CellData = get_cell(coord)
	if not StairRouter.is_traversable(cell.tile_type):
		return false

	var target_view_id: ViewIds.Id = StairRouter.get_linked_view(coord.view_id, cell.tile_type)
	if target_view_id == coord.view_id:
		return false

	ViewManager.switch_to(target_view_id)
	return true


func coord_from_global(view: ViewRoot, global_position: Vector2) -> GridCoord:
	var local_position: Vector2 = view.to_local(global_position)
	var coord := GridCoord.from_local(view.view_id, local_position)
	if not coord.is_in_bounds():
		return GridCoord.new(-1, -1, view.view_id)
	return coord


func export_save_data() -> Dictionary:
	var grids_data: Dictionary = {}
	for view_id: ViewIds.Id in _grids.keys():
		grids_data[str(view_id)] = (_grids[view_id] as BuildingGrid).to_dict()
	return {
		"version": SAVE_VERSION,
		"grids": grids_data,
		"view_themes": ThemeService.export_save_data(),
		"game_mode": GameModeManager.current_mode,
		"day_period": DayNightManager.current_period,
		"furniture": FurnitureService.export_save_data(),
		"game_time": GameTimeManager.export_save_data(),
		"economy": EconomyManager.export_save_data(),
		"reputation": ReputationManager.export_save_data(),
		"game_clock": GameClock.export_save_data(),
	}


func import_save_data(data: Dictionary) -> void:
	_grids.clear()
	var grids_data: Dictionary = data.get("grids", {})
	for key: String in grids_data.keys():
		var view_id: ViewIds.Id = int(key) as ViewIds.Id
		_grids[view_id] = BuildingGrid.from_dict(grids_data[key])
	for view_id: ViewIds.Id in ViewIds.all():
		if not _grids.has(view_id):
			_grids[view_id] = BuildingGrid.new(view_id)

	if data.has("view_themes"):
		ThemeService.import_save_data(data.get("view_themes", {}))

	var version: int = data.get("version", 1)
	if version >= 2:
		GameModeManager.set_mode(data.get("game_mode", GameModes.Id.PLAY), true)
		DayNightManager.set_period(data.get("day_period", DayPeriods.Id.DAY), true)
	if version >= 3 and data.has("furniture"):
		FurnitureService.import_save_data(data.get("furniture", {}))
	elif version < 3:
		FurnitureService.clear_all(false)
	else:
		FurnitureService.clear_all(false)
	if version >= 4:
		if data.has("game_time"):
			GameTimeManager.import_save_data(data.get("game_time", {}))
		if data.has("economy"):
			EconomyManager.import_save_data(data.get("economy", {}))
		if data.has("reputation"):
			ReputationManager.import_save_data(data.get("reputation", {}))
	if version >= 5 and data.has("game_clock"):
		GameClock.import_save_data(data.get("game_clock", {}))

	GridLayoutSeeder.enforce_locked_cells(_grids)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GridService: failed to open save file.")
		return false
	file.store_string(JSON.stringify(export_save_data(), "\t"))
	EventBus.grid_saved.emit()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GridService: failed to read save file.")
		return false

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GridService: invalid save data.")
		return false

	import_save_data(parsed)
	if not FurnitureService.has_any_instances():
		FurnitureLayoutSeeder.seed_defaults()
	EventBus.grid_loaded.emit()
	if GameTimeManager.is_briefing():
		GameTimeManager.call_deferred("request_morning_briefing")
	elif GameTimeManager.is_running():
		EventBus.day_started.emit(GameTimeManager.current_day)
	return true


func clear_all_grids() -> void:
	_reset_grids()
	ThemeService.reset_to_defaults()
	FurnitureService.clear_all(false)
	FurnitureLayoutSeeder.seed_defaults()
	EntityService.clear_all()
	CustomerService.despawn_all()
	if StaffService.innkeeper != null and is_instance_valid(StaffService.innkeeper):
		StaffService.innkeeper.queue_free()
	StaffService.innkeeper = null
	EconomyManager.reset_to_defaults()
	ReputationManager.reset_to_defaults()
	GameTimeManager.current_day = 1
	GameTimeManager.phase = GamePhases.Id.BRIEFING
	GameModeManager.set_mode(GameModes.Id.PLAY)
	DayNightManager.set_period(DayPeriods.Id.DAY)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	EventBus.grid_loaded.emit()
	GameTimeManager.request_morning_briefing()


func _reset_grids() -> void:
	_grids.clear()
	for view_id: ViewIds.Id in ViewIds.all():
		_grids[view_id] = BuildingGrid.new(view_id)
	GridLayoutSeeder.seed_all(_grids)
