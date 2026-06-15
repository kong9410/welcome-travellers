class_name GridCellRenderer
extends Node2D

@export var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE


func _ready() -> void:
	EventBus.grid_cell_changed.connect(_on_grid_cell_changed)
	EventBus.grid_loaded.connect(_refresh)
	EventBus.view_theme_changed.connect(_on_view_theme_changed)
	queue_redraw()


func _on_grid_cell_changed(changed_view_id: ViewIds.Id, _coord: GridCoord, _cell: CellData) -> void:
	if changed_view_id == view_id:
		queue_redraw()


func _on_view_theme_changed(changed_view_id: ViewIds.Id, _theme_id: String) -> void:
	if changed_view_id == view_id:
		queue_redraw()


func _refresh() -> void:
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
