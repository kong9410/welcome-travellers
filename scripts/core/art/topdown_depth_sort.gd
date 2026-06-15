class_name TopdownDepthSort
extends RefCounted

const FURNITURE_OFFSET: int = 0
const FOOD_OFFSET: int = 48
const ENTITY_OFFSET: int = 8

const MIN_Z: int = -4096
const MAX_Z: int = 4096


static func key_for_y(sort_y: float, offset: int = 0) -> int:
	return clampi(int(round(sort_y)) + offset, MIN_Z, MAX_Z)


static func apply_for_y(item: CanvasItem, sort_y: float, offset: int = 0) -> void:
	if item == null:
		return
	item.z_index = key_for_y(sort_y, offset)


static func apply_for_foot(item: Node2D, offset: int = ENTITY_OFFSET) -> void:
	if item == null:
		return
	apply_for_y(item, item.position.y, offset)


static func apply_for_actor(item: Node2D, view_id: ViewIds.Id, offset: int = ENTITY_OFFSET) -> void:
	if item == null:
		return
	apply_for_y(item, _actor_sort_y(item, view_id), offset)


static func apply_for_rect(item: CanvasItem, rect: Rect2, offset: int = FURNITURE_OFFSET) -> void:
	apply_for_y(item, rect.end.y, offset)


static func _actor_sort_y(item: Node2D, view_id: ViewIds.Id) -> float:
	var sort_y: float = item.position.y
	var coord: GridCoord = GridCoord.from_local(view_id, item.position)
	var instance: FurnitureInstance = FurnitureService.get_instance_at(coord)
	if instance == null:
		return sort_y
	if not FurnitureCatalog.allows_customer_on_tile(instance.def_id):
		return sort_y

	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(instance.def_id)
	var size: Vector2i = FurnitureFootprint.get_rotated_size(
		definition.footprint,
		instance.rotation_steps
	)
	var furniture_bottom_y: float = instance.origin.to_world().y + float(size.y * GameConstants.TILE_SIZE)
	return maxf(sort_y, furniture_bottom_y)
