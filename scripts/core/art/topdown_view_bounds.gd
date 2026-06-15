class_name TopdownViewBounds
extends RefCounted

# Extra visual room for 3/4 top-down sprites that rise above their logical tile.
const TOP_OVERDRAW: float = 28.0
const SIDE_OVERDRAW: float = 16.0
const BOTTOM_OVERDRAW: float = 12.0


static func grid_pixel_size() -> Vector2:
	return Vector2(GameConstants.GRID_VISUAL_SIZE) * float(GameConstants.TILE_SIZE)


static func logical_rect(view: ViewRoot) -> Rect2:
	return Rect2(view.global_position, grid_pixel_size())


static func visual_rect(view: ViewRoot) -> Rect2:
	var logical: Rect2 = logical_rect(view)
	return Rect2(
		logical.position - Vector2(SIDE_OVERDRAW, TOP_OVERDRAW),
		logical.size + Vector2(SIDE_OVERDRAW * 2.0, TOP_OVERDRAW + BOTTOM_OVERDRAW)
	)


static func focus_point(view: ViewRoot) -> Vector2:
	return visual_rect(view).get_center()
