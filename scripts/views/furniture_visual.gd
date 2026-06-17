class_name FurnitureVisual
extends Node2D

var _instance: FurnitureInstance
var _definition: FurnitureDefinition
var is_selected: bool = false


func setup(instance: FurnitureInstance, definition: FurnitureDefinition) -> void:
	_instance = instance
	_definition = definition
	position = instance.origin.to_world()
	_update_depth_sort()
	queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func _draw() -> void:
	if _instance == null or _definition == null:
		return

	var tile_size: float = float(GameConstants.TILE_SIZE)
	var size: Vector2i = FurnitureFootprint.get_rotated_size(
		_definition.footprint,
		_instance.rotation_steps
	)
	var pixel_size := Vector2(size) * tile_size
	var draw_rect := Rect2(Vector2.ZERO, pixel_size)
	BuildPreviewDrawer.draw_furniture(
		self,
		draw_rect,
		_definition.def_id,
		_instance.rotation_steps
	)
	if is_selected:
		_draw_selection_highlight(draw_rect)


func _draw_selection_highlight(rect: Rect2) -> void:
	match _definition.def_id:
		"chair", "waiting_chair":
			var center := rect.get_center() + Vector2(0.0, TopdownFurnitureDrawer.CHAIR_DRAW_Y_OFFSET)
			draw_arc(center, 16.0, 0.0, TAU, 32, DarkFantasyPalette.brass_bright.darkened(0.18), 1.5)
			draw_arc(center, 13.0, 0.0, TAU, 28, DarkFantasyPalette.brass_bright, 2.5)
		_:
			var outline := rect.grow(-1.0)
			draw_rect(outline.grow(2.0), DarkFantasyPalette.brass_bright.darkened(0.22), false, 1.5)
			draw_rect(outline, DarkFantasyPalette.brass_bright, false, 2.5)


func _update_depth_sort() -> void:
	if _instance == null or _definition == null:
		return

	var tile_size: float = float(GameConstants.TILE_SIZE)
	var size: Vector2i = FurnitureFootprint.get_rotated_size(
		_definition.footprint,
		_instance.rotation_steps
	)
	TopdownDepthSort.apply_for_rect(
		self,
		Rect2(position, Vector2(size) * tile_size),
		TopdownDepthSort.FURNITURE_OFFSET
	)
