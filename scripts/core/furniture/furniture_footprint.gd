class_name FurnitureFootprint
extends RefCounted

static func get_rotated_size(footprint: Vector2i, rotation_steps: int) -> Vector2i:
	var steps: int = posmod(rotation_steps, 4)
	if steps % 2 == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


static func get_occupied_cells(
	origin: GridCoord,
	footprint: Vector2i,
	rotation_steps: int
) -> Array[GridCoord]:
	var cells: Array[GridCoord] = []
	var size: Vector2i = get_rotated_size(footprint, rotation_steps)
	for local_y in range(size.y):
		for local_x in range(size.x):
			cells.append(GridCoord.new(origin.x + local_x, origin.y + local_y, origin.view_id))
	return cells
