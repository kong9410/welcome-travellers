class_name FurnitureVisual
extends Node2D

var _instance: FurnitureInstance
var _definition: FurnitureDefinition


func setup(instance: FurnitureInstance, definition: FurnitureDefinition) -> void:
	_instance = instance
	_definition = definition
	position = instance.origin.to_world()
	_update_depth_sort()
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
	BuildPreviewDrawer.draw_furniture(
		self,
		Rect2(Vector2.ZERO, pixel_size),
		_definition.def_id,
		_instance.rotation_steps
	)


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
