class_name FurnitureGhostRenderer
extends Node2D

@export var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE

var _origin: GridCoord = GridCoord.new(-1, -1, ViewIds.Id.OUTSIDE)
var _can_place: bool = false
var _hover_instance: FurnitureInstance = null


func _ready() -> void:
	z_index = 2
	set_process(true)
	EventBus.game_mode_changed.connect(_on_refresh)
	EventBus.view_changed.connect(_on_refresh)
	EventBus.furniture_catalog_changed.connect(_on_refresh)


func _process(_delta: float) -> void:
	if not _should_draw():
		if _origin.x >= 0:
			_origin = GridCoord.new(-1, -1, view_id)
			_hover_instance = null
			queue_redraw()
		return

	var active_view: ViewRoot = ViewManager.get_view(view_id)
	if active_view == null:
		return

	var coord: GridCoord = GridService.coord_from_global(
		active_view,
		active_view.get_global_mouse_position()
	)
	var can_place: bool = false
	var hover_instance: FurnitureInstance = null

	if FurnitureService.is_removal_tool():
		hover_instance = FurnitureService.get_instance_at(coord)
	else:
		can_place = FurnitureService.can_place(
			coord,
			FurnitureService.current_def_id,
			FurnitureService.current_rotation
		)

	if (
		not coord.equals(_origin)
		or can_place != _can_place
		or hover_instance != _hover_instance
	):
		_origin = coord
		_can_place = can_place
		_hover_instance = hover_instance
		queue_redraw()


func _draw() -> void:
	if not _should_draw() or not _origin.is_in_bounds():
		return

	var tile_size: float = float(GameConstants.TILE_SIZE)

	if FurnitureService.is_removal_tool():
		_draw_removal_preview(tile_size)
		return

	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(FurnitureService.current_def_id)
	var size: Vector2i = FurnitureFootprint.get_rotated_size(
		definition.footprint,
		FurnitureService.current_rotation
	)
	var pixel_size := Vector2(size) * tile_size
	var draw_rect := Rect2(_origin.to_world(), pixel_size)

	if _can_place:
		modulate = Color(0.82, 0.72, 0.58, 0.52)
	else:
		modulate = Color(0.62, 0.22, 0.18, 0.48)

	BuildPreviewDrawer.draw_furniture(
		self,
		draw_rect,
		FurnitureService.current_def_id,
		FurnitureService.current_rotation
	)
	modulate = Color.WHITE


func _draw_removal_preview(tile_size: float) -> void:
	var tile_rect := Rect2(_origin.to_world(), Vector2.ONE * tile_size)
	if _hover_instance == null:
		BuildPreviewDrawer.draw_tile(self, tile_rect, CellData.TileType.EMPTY)
		return

	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(_hover_instance.def_id)
	var size: Vector2i = FurnitureFootprint.get_rotated_size(
		definition.footprint,
		_hover_instance.rotation_steps
	)
	var draw_rect := Rect2(_hover_instance.origin.to_world(), Vector2(size) * tile_size)

	modulate = Color(0.72, 0.18, 0.14, 0.68)
	BuildPreviewDrawer.draw_furniture(
		self,
		draw_rect,
		_hover_instance.def_id,
		_hover_instance.rotation_steps
	)
	modulate = Color.WHITE

	var inset: float = minf(draw_rect.size.x, draw_rect.size.y) * 0.18
	draw_line(
		draw_rect.position + Vector2(inset, inset),
		draw_rect.position + draw_rect.size - Vector2(inset, inset),
		DarkFantasyPalette.erase_mark,
		2.5
	)
	draw_line(
		draw_rect.position + Vector2(draw_rect.size.x - inset, inset),
		draw_rect.position + Vector2(inset, draw_rect.size.y - inset),
		DarkFantasyPalette.erase_mark,
		2.5
	)


func _should_draw() -> bool:
	return GameModeManager.is_furniture_mode() and ViewManager.current_view_id == view_id


func _on_refresh(_a = null, _b = null) -> void:
	queue_redraw()
