class_name OutsideViewRoot
extends ViewRoot

@onready var outside_scroll_world: OutsideScrollWorld = $OutsideScrollWorld

var _grid_layers: Array[CanvasItem] = []


func _ready() -> void:
	super._ready()
	_collect_grid_layers()
	_set_grid_layers_visible(false)


func try_open_inn_door(global_position: Vector2) -> bool:
	if outside_scroll_world == null:
		return false
	return outside_scroll_world.try_open_inn_door(global_position)


func spawn_outside_customer_from_edge(
	target_position: Vector2 = Vector2.ZERO,
	spawn_side: int = -1,
	persona_id: int = -1
) -> OutsideCustomerEntity:
	if outside_scroll_world == null:
		return null
	return outside_scroll_world.spawn_outside_customer_from_edge(
		target_position,
		spawn_side,
		persona_id
	)


func get_scroll_bounds() -> Rect2:
	if outside_scroll_world:
		return outside_scroll_world.get_world_bounds()
	return OutsideViewConstants.world_bounds()


func _collect_grid_layers() -> void:
	_grid_layers.clear()
	for node_name: String in [
		"GridVisualizer",
		"GridCellRenderer",
		"StructureGhostRenderer",
		"FurnitureLayer",
		"FurnitureGhostRenderer",
		"TileMap",
		"EntityLayer",
		"NavigationRegion2D",
	]:
		var node: Node = get_node_or_null(node_name)
		if node is CanvasItem:
			_grid_layers.append(node as CanvasItem)


func _set_grid_layers_visible(is_visible: bool) -> void:
	for layer: CanvasItem in _grid_layers:
		layer.visible = is_visible
