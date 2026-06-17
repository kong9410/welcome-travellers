class_name StructureGhostRenderer
extends Node2D

@export var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE

var _origin: GridCoord = GridCoord.new(-1, -1, ViewIds.Id.OUTSIDE)
var _can_paint: bool = false
var _paint_type: CellData.TileType = CellData.TileType.FLOOR


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 2
	set_process(true)
	EventBus.game_mode_changed.connect(_on_refresh)
	EventBus.view_changed.connect(_on_refresh)
	EventBus.view_theme_changed.connect(_on_view_theme_changed)


func _process(_delta: float) -> void:
	if not _should_draw():
		if _origin.x >= 0:
			_origin = GridCoord.new(-1, -1, view_id)
			queue_redraw()
		return

	var active_view: ViewRoot = ViewManager.get_view(view_id)
	if active_view == null:
		return

	var coord: GridCoord = GridService.coord_from_global(
		active_view,
		active_view.get_global_mouse_position()
	)
	var paint_type: CellData.TileType = GridService.current_paint_type
	var can_paint: bool = GridService.can_paint_tile(coord, paint_type)

	if (
		not coord.equals(_origin)
		or can_paint != _can_paint
		or paint_type != _paint_type
	):
		_origin = coord
		_can_paint = can_paint
		_paint_type = paint_type
		queue_redraw()


func _draw() -> void:
	if not _should_draw() or not _origin.is_in_bounds():
		return

	var tile_size: float = float(GameConstants.TILE_SIZE)
	var tile_rect := Rect2(_origin.to_world(), Vector2.ONE * tile_size)
	var preview_type: CellData.TileType = GridService.resolve_paint_preview_type(
		_origin,
		_paint_type
	)

	if _can_paint:
		modulate = Color(0.82, 0.72, 0.58, 0.52)
	else:
		modulate = Color(0.62, 0.22, 0.18, 0.48)

	BuildPreviewDrawer.draw_tile(self, tile_rect, preview_type, view_id, _origin)
	modulate = Color.WHITE


func _should_draw() -> bool:
	return GameModeManager.is_build_mode() and ViewManager.current_view_id == view_id


func _on_refresh(_a = null, _b = null) -> void:
	queue_redraw()


func _on_view_theme_changed(changed_view_id: ViewIds.Id, _theme_id: String) -> void:
	if changed_view_id == view_id:
		queue_redraw()
