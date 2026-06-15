class_name NavPolygonBuilder
extends RefCounted

static func build_for_view(view_id: ViewIds.Id) -> NavigationPolygon:
	var navigation_polygon := NavigationPolygon.new()
	var tile_size: float = float(GameConstants.TILE_SIZE)
	var vertices := PackedVector2Array()
	var polygons: Array = []

	# Per-tile outlines overlap on shared edges and break make_polygons_from_outlines().
	# Build convex rectangle polygons directly with set_vertices() + add_polygon().
	for y in range(GameConstants.GRID_VISUAL_SIZE.y):
		var x: int = 0
		while x < GameConstants.GRID_VISUAL_SIZE.x:
			while x < GameConstants.GRID_VISUAL_SIZE.x and not _is_walkable(x, y, view_id):
				x += 1
			if x >= GameConstants.GRID_VISUAL_SIZE.x:
				break

			var run_start: int = x
			while x < GameConstants.GRID_VISUAL_SIZE.x and _is_walkable(x, y, view_id):
				x += 1

			var base_index: int = vertices.size()
			var top_left: Vector2 = Vector2(run_start, y) * tile_size
			var width: float = float(x - run_start) * tile_size
			vertices.append_array(PackedVector2Array([
				top_left,
				top_left + Vector2(width, 0.0),
				top_left + Vector2(width, tile_size),
				top_left + Vector2(0.0, tile_size),
			]))
			polygons.append(PackedInt32Array([
				base_index,
				base_index + 1,
				base_index + 2,
				base_index + 3,
			]))

	if vertices.is_empty():
		return navigation_polygon

	navigation_polygon.set_vertices(vertices)
	for polygon: PackedInt32Array in polygons:
		navigation_polygon.add_polygon(polygon)

	return navigation_polygon


static func _is_walkable(x: int, y: int, view_id: ViewIds.Id) -> bool:
	return NavService.is_walkable_for_unit(GridCoord.new(x, y, view_id))
