class_name GridCoord
extends RefCounted

var x: int
var y: int
var view_id: ViewIds.Id


func _init(cell_x: int = 0, cell_y: int = 0, cell_view_id: ViewIds.Id = ViewIds.Id.OUTSIDE) -> void:
	x = cell_x
	y = cell_y
	view_id = cell_view_id


func to_key() -> String:
	return "%d:%d:%d" % [view_id, x, y]


static func from_key(key: String) -> GridCoord:
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 3:
		return GridCoord.new()
	return GridCoord.new(int(parts[1]), int(parts[2]), int(parts[0]) as ViewIds.Id)


func to_world() -> Vector2:
	return Vector2(x, y) * GameConstants.TILE_SIZE


func to_world_center() -> Vector2:
	return to_world() + Vector2.ONE * GameConstants.TILE_SIZE * 0.5


static func from_local(view_id: ViewIds.Id, local_position: Vector2) -> GridCoord:
	var tile_size: float = float(GameConstants.TILE_SIZE)
	return GridCoord.new(
		int(floor(local_position.x / tile_size)),
		int(floor(local_position.y / tile_size)),
		view_id
	)


func is_in_bounds() -> bool:
	return (
		x >= 0
		and y >= 0
		and x < GameConstants.GRID_VISUAL_SIZE.x
		and y < GameConstants.GRID_VISUAL_SIZE.y
	)


func duplicate_coord() -> GridCoord:
	return GridCoord.new(x, y, view_id)


func equals(other: GridCoord) -> bool:
	return other != null and x == other.x and y == other.y and view_id == other.view_id


func to_label() -> String:
	return "(%d, %d) @ %s" % [x, y, ViewIds.label_for(view_id)]
