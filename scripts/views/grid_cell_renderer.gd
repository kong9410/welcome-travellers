class_name GridCellRenderer
extends Node2D

@export var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE


func _ready() -> void:
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)
	EventBus.grid_loaded.connect(_refresh)
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)
	EventBus.view_theme_changed.connect(_on_view_theme_changed)
	EventBus.filth_changed.connect(_on_filth_changed)
	queue_redraw()


func _on_grid_cell_changed(changed_view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	if changed_view_id == view_id:
		queue_redraw()


func _on_view_theme_changed(changed_view_id: ViewIds.Id, _theme_id: String) -> void:
	if changed_view_id == view_id:
		queue_redraw()


func _refresh() -> void:
	queue_redraw()


func _on_debug_mode_changed(_enabled: bool) -> void:
	queue_redraw()


func _on_filth_changed(changed_view_id: ViewIds.Id) -> void:
	if changed_view_id == view_id:
		queue_redraw()


func _draw() -> void:
	var grid: BuildingGrid = GridService.get_grid(view_id)
	var tile_size: float = float(GameConstants.TILE_SIZE)

	for y in range(GameConstants.GRID_VISUAL_SIZE.y):
		for x in range(GameConstants.GRID_VISUAL_SIZE.x):
			var coord := GridCoord.new(x, y, view_id)
			var cell: CellData = grid.get_cell(coord)
			if cell.is_empty():
				continue

			var tile_rect := Rect2(
				Vector2(coord.x, coord.y) * tile_size,
				Vector2.ONE * tile_size
			)
			BuildPreviewDrawer.draw_tile(self, tile_rect, cell.tile_type, view_id, coord)

	if DebugService.is_active():
		_draw_room_region_overlay(tile_size)


func _draw_room_region_overlay(tile_size: float) -> void:
	var font: Font = ThemeDB.fallback_font
	for region_id in range(1, RoomRegionService.get_region_count(view_id) + 1):
		var color: Color = _region_debug_color(region_id)
		var coords: Array[GridCoord] = RoomRegionService.get_region_coords(view_id, region_id)
		for coord: GridCoord in coords:
			var tile_rect := Rect2(
				Vector2(coord.x, coord.y) * tile_size,
				Vector2.ONE * tile_size
			)
			draw_rect(tile_rect, color, true)
			draw_rect(tile_rect, color.darkened(0.35), false, 1.0)

			var label_position: Vector2 = tile_rect.position + Vector2(4.0, 13.0)
			draw_string(
				font,
				label_position,
				str(region_id),
				HORIZONTAL_ALIGNMENT_LEFT,
				tile_size,
				10,
				Color(1.0, 1.0, 1.0, 0.92)
			)


func _region_debug_color(region_id: int) -> Color:
	var hue: float = fmod(float(region_id) * 0.173, 1.0)
	var color: Color = Color.from_hsv(hue, 0.58, 0.92, 0.26)
	return color
