class_name TopdownTileDrawer
extends RefCounted

const EDGE_WIDTH: float = 1.0
const FLOOR_TEXTURE: Texture2D = preload("res://assets/tiles/floor.png")
const WALL_TEXTURE: Texture2D = preload("res://assets/tiles/walls.png")
const WALL_TEXTURE_TILE_SIZE: float = 64.0


static func draw_tile(
	canvas: CanvasItem,
	rect: Rect2,
	tile_type: CellData.TileType,
	view_id = null,
	coord = null
) -> void:
	var resolved_view_id: ViewIds.Id = (
		view_id as ViewIds.Id
		if view_id != null
		else ViewManager.current_view_id
	)
	var theme: InteriorTheme = ThemeService.get_theme_for_view(resolved_view_id)
	var base_color: Color = theme.get_color_for_tile_type(tile_type)

	match tile_type:
		CellData.TileType.EMPTY:
			_draw_erase(canvas, rect)
		CellData.TileType.FLOOR:
			_draw_floor(canvas, rect, base_color)
		CellData.TileType.WALL:
			_draw_wall(canvas, rect, base_color, TopdownWallRules.rule_for(coord, tile_type))
		CellData.TileType.DOOR:
			_draw_door(canvas, rect, base_color, TopdownWallRules.rule_for(coord, tile_type))
		CellData.TileType.STAIRS_UP:
			_draw_stairs(canvas, rect, base_color, true)
		CellData.TileType.STAIRS_DOWN:
			_draw_stairs(canvas, rect, base_color, false)
		CellData.TileType.OUTSIDE_GROUND:
			_draw_outside_ground(canvas, rect, base_color)
		_:
			_draw_floor(canvas, rect, base_color)


static func _draw_floor(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	if FLOOR_TEXTURE != null:
		canvas.draw_texture_rect(FLOOR_TEXTURE, rect, false)
		return

	var top_color: Color = color.lightened(0.16)
	var lower_color: Color = color.darkened(0.06)
	var bevel: float = maxf(2.0, rect.size.y * 0.10)

	canvas.draw_rect(rect, top_color, true)
	canvas.draw_rect(Rect2(rect.position.x, rect.end.y - bevel, rect.size.x, bevel), lower_color, true)
	canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color.lightened(0.30), EDGE_WIDTH)
	canvas.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, DarkFantasyPalette.outline_soft, EDGE_WIDTH)
	canvas.draw_rect(rect, DarkFantasyPalette.outline_soft, false, EDGE_WIDTH)

	var plank_count: int = 3
	var plank_width: float = rect.size.x / float(plank_count)
	for index in range(1, plank_count):
		var x: float = rect.position.x + plank_width * float(index)
		canvas.draw_line(
			Vector2(x, rect.position.y + bevel),
			Vector2(x, rect.end.y - bevel * 0.65),
			DarkFantasyPalette.outline_soft,
			EDGE_WIDTH
		)


static func _draw_wall(canvas: CanvasItem, rect: Rect2, color: Color, rules: Dictionary = {}) -> void:
	if WALL_TEXTURE != null:
		_draw_wall_texture(canvas, rect, rules)
		return

	var cap_height: float = rect.size.y * 0.34
	var connects_west: bool = rules.get("connects_west", false)
	var connects_east: bool = rules.get("connects_east", false)
	var has_adjacent_floor: bool = rules.get("has_adjacent_floor", true)
	var draw_front_face: bool = rules.get("draw_front_face", true)
	var draw_left_face: bool = rules.get("draw_left_face", false)
	var draw_right_face: bool = rules.get("draw_right_face", false)
	var draw_back_lip: bool = rules.get("draw_back_lip", false)
	var draw_front_left_corner: bool = rules.get("draw_front_left_corner", false)
	var draw_front_right_corner: bool = rules.get("draw_front_right_corner", false)
	var draw_back_left_corner: bool = rules.get("draw_back_left_corner", false)
	var draw_back_right_corner: bool = rules.get("draw_back_right_corner", false)
	var draw_top_edge: bool = rules.get("draw_top_edge", true)
	var draw_left_edge: bool = rules.get("draw_left_edge", true)
	var draw_right_edge: bool = rules.get("draw_right_edge", true)
	var cap_extend_left: float = EDGE_WIDTH if connects_west else 0.0
	var cap_extend_right: float = EDGE_WIDTH if connects_east else 0.0
	var cap_rect := Rect2(
		rect.position.x - cap_extend_left,
		rect.position.y,
		rect.size.x + cap_extend_left + cap_extend_right,
		cap_height + 1.0
	)

	canvas.draw_rect(cap_rect, color.lightened(0.20), true)
	if not has_adjacent_floor:
		canvas.draw_rect(cap_rect, color.darkened(0.10), true)
		canvas.draw_rect(cap_rect, DarkFantasyPalette.outline_soft, false, EDGE_WIDTH)
		return

	_draw_cap_trim(
		canvas,
		rect,
		cap_height,
		color,
		draw_back_left_corner,
		draw_back_right_corner
	)
	if draw_top_edge:
		canvas.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), color.lightened(0.34), EDGE_WIDTH)
	if draw_back_lip:
		var lip_rect := Rect2(rect.position.x, rect.position.y, rect.size.x, maxf(2.0, cap_height * 0.24))
		canvas.draw_rect(lip_rect, color.lightened(0.30), true)

	if draw_front_face:
		var face_rect := Rect2(rect.position.x, rect.position.y + cap_height, rect.size.x, rect.size.y - cap_height)
		var left_shade := Rect2(face_rect.position, Vector2(face_rect.size.x * 0.18, face_rect.size.y))
		canvas.draw_rect(face_rect, color.darkened(0.03), true)
		if draw_left_edge:
			canvas.draw_rect(left_shade, color.darkened(0.13), true)
		canvas.draw_line(
			Vector2(rect.position.x, rect.position.y + cap_height),
			Vector2(rect.end.x, rect.position.y + cap_height),
			DarkFantasyPalette.outline_soft,
			EDGE_WIDTH
		)
		_draw_stone_courses(canvas, face_rect, draw_left_edge, draw_right_edge)
		canvas.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, DarkFantasyPalette.outline, EDGE_WIDTH)
	else:
		var shadow_rect := Rect2(rect.position.x, rect.position.y + cap_height, rect.size.x, rect.size.y * 0.12)
		canvas.draw_rect(shadow_rect, color.darkened(0.12), true)

	if draw_left_face:
		var side_width: float = rect.size.x * 0.22
		var side_rect := Rect2(rect.position.x, rect.position.y + cap_height * 0.28, side_width, rect.size.y - cap_height * 0.28)
		canvas.draw_rect(side_rect, color.darkened(0.16), true)
		canvas.draw_line(side_rect.position, Vector2(side_rect.position.x, side_rect.end.y), DarkFantasyPalette.outline, EDGE_WIDTH)
		canvas.draw_line(Vector2(side_rect.end.x, side_rect.position.y), side_rect.end, DarkFantasyPalette.outline_soft, EDGE_WIDTH)

	if draw_right_face:
		var side_width: float = rect.size.x * 0.22
		var side_rect := Rect2(rect.end.x - side_width, rect.position.y + cap_height * 0.28, side_width, rect.size.y - cap_height * 0.28)
		canvas.draw_rect(side_rect, color.darkened(0.07), true)
		canvas.draw_line(Vector2(side_rect.end.x, side_rect.position.y), side_rect.end, DarkFantasyPalette.outline, EDGE_WIDTH)
		canvas.draw_line(side_rect.position, Vector2(side_rect.position.x, side_rect.end.y), DarkFantasyPalette.outline_soft, EDGE_WIDTH)

	if draw_left_edge:
		canvas.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), DarkFantasyPalette.outline, EDGE_WIDTH)
	if draw_right_edge:
		canvas.draw_line(Vector2(rect.end.x, rect.position.y), rect.end, DarkFantasyPalette.outline, EDGE_WIDTH)

	_draw_corner_posts(
		canvas,
		rect,
		cap_height,
		color,
		draw_front_left_corner,
		draw_front_right_corner,
		draw_back_left_corner,
		draw_back_right_corner
	)


static func _draw_wall_texture(canvas: CanvasItem, rect: Rect2, rules: Dictionary = {}) -> void:
	var source_cell: Vector2i = _wall_texture_source_cell(rules)
	var source_rect := Rect2(
		Vector2(source_cell) * WALL_TEXTURE_TILE_SIZE,
		Vector2.ONE * WALL_TEXTURE_TILE_SIZE
	)
	canvas.draw_texture_rect_region(WALL_TEXTURE, rect, source_rect)


static func _wall_texture_source_cell(rules: Dictionary = {}) -> Vector2i:
	var floor_mask: int = int(rules.get("floor_mask", 0))
	var floor_north: bool = (floor_mask & TopdownWallRules.FLOOR_NORTH) != 0
	var floor_south: bool = (floor_mask & TopdownWallRules.FLOOR_SOUTH) != 0
	var floor_west: bool = (floor_mask & TopdownWallRules.FLOOR_WEST) != 0
	var floor_east: bool = (floor_mask & TopdownWallRules.FLOOR_EAST) != 0

	# 3x3 sheet: NW N NE / W center E / SW S SE
	if not (floor_north or floor_south or floor_west or floor_east):
		return Vector2i(1, 1)
	if floor_north and floor_west:
		return Vector2i(0, 0)
	if floor_north and floor_east:
		return Vector2i(2, 0)
	if floor_south and floor_west:
		return Vector2i(0, 2)
	if floor_south and floor_east:
		return Vector2i(2, 2)
	if floor_north:
		return Vector2i(1, 0)
	if floor_south:
		return Vector2i(1, 2)
	if floor_west:
		return Vector2i(0, 1)
	if floor_east:
		return Vector2i(2, 1)
	return Vector2i(1, 1)


static func _draw_door(canvas: CanvasItem, rect: Rect2, color: Color, rules: Dictionary = {}) -> void:
	_draw_wall(canvas, rect, DarkFantasyPalette.wall_stone, rules)
	if not rules.get("has_adjacent_floor", true) or not rules.get("draw_front_face", true):
		return
	var cap_height: float = rect.size.y * 0.34
	var door_width: float = rect.size.x * 0.46
	var door_height: float = rect.size.y * 0.58
	var door_rect := Rect2(
		rect.position.x + rect.size.x * 0.5 - door_width * 0.5,
		rect.end.y - door_height,
		door_width,
		door_height
	)
	var inner := door_rect.grow(-maxf(1.0, rect.size.x * 0.06))

	canvas.draw_rect(door_rect, DarkFantasyPalette.wood_dark, true)
	canvas.draw_rect(inner, color.lightened(0.08), true)
	canvas.draw_line(
		Vector2(inner.position.x + inner.size.x * 0.5, inner.position.y + cap_height * 0.12),
		Vector2(inner.position.x + inner.size.x * 0.5, inner.end.y),
		color.darkened(0.18),
		EDGE_WIDTH
	)
	canvas.draw_circle(
		inner.position + Vector2(inner.size.x * 0.78, inner.size.y * 0.55),
		maxf(1.3, rect.size.x * 0.045),
		DarkFantasyPalette.brass_bright
	)
	canvas.draw_rect(door_rect, DarkFantasyPalette.outline, false, EDGE_WIDTH)


static func _draw_stairs(canvas: CanvasItem, rect: Rect2, color: Color, going_up: bool) -> void:
	_draw_floor(canvas, rect, color)
	var inset := rect.grow(-rect.size.x * 0.12)
	var step_count: int = 4
	var step_gap: float = inset.size.y / float(step_count + 1)
	var line_color: Color = DarkFantasyPalette.brass_bright.lightened(0.20)
	for index in range(step_count):
		var y: float
		if going_up:
			y = inset.position.y + step_gap * float(index + 1)
		else:
			y = inset.end.y - step_gap * float(index + 1)
		var taper: float = float(index) * rect.size.x * 0.035
		canvas.draw_line(
			Vector2(inset.position.x + taper, y),
			Vector2(inset.end.x - taper, y),
			line_color,
			1.5
		)
	var arrow_dir: float = -1.0 if going_up else 1.0
	var center := rect.get_center() + Vector2(0.0, arrow_dir * rect.size.y * 0.18)
	var arrow_size: float = rect.size.x * 0.13
	canvas.draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(0.0, arrow_dir * arrow_size),
			center + Vector2(-arrow_size, -arrow_dir * arrow_size * 0.35),
			center + Vector2(arrow_size, -arrow_dir * arrow_size * 0.35),
		]),
		line_color
	)


static func _draw_outside_ground(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	_draw_floor(canvas, rect, color.lightened(0.10))
	for index in range(3):
		var x: float = rect.position.x + rect.size.x * (0.22 + float(index) * 0.22)
		var y: float = rect.position.y + rect.size.y * (0.30 + float(index % 2) * 0.28)
		canvas.draw_line(
			Vector2(x, y + rect.size.y * 0.10),
			Vector2(x + rect.size.x * 0.04, y),
			DarkFantasyPalette.herb.lightened(0.10),
			EDGE_WIDTH
		)


static func _draw_erase(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, DarkFantasyPalette.erase_bg, true)
	canvas.draw_rect(rect, DarkFantasyPalette.panel_border, false, 1.5)
	var inset: float = rect.size.x * 0.22
	canvas.draw_line(
		rect.position + Vector2(inset, inset),
		rect.position + rect.size - Vector2(inset, inset),
		DarkFantasyPalette.erase_mark,
		2.0
	)
	canvas.draw_line(
		rect.position + Vector2(rect.size.x - inset, inset),
		rect.position + Vector2(inset, rect.size.y - inset),
		DarkFantasyPalette.erase_mark,
		2.0
	)


static func _draw_stone_courses(
	canvas: CanvasItem,
	rect: Rect2,
	draw_left_edge: bool = true,
	draw_right_edge: bool = true
) -> void:
	var row_count: int = 2
	var row_height: float = rect.size.y / float(row_count)
	for row in range(row_count):
		var y: float = rect.position.y + row_height * float(row + 1)
		canvas.draw_line(
			Vector2(rect.position.x + rect.size.x * 0.08, y),
			Vector2(rect.end.x - rect.size.x * 0.08, y),
			DarkFantasyPalette.outline_soft,
			EDGE_WIDTH
		)
		var seam_x: float = rect.position.x + rect.size.x * (0.36 if row % 2 == 0 else 0.64)
		if (draw_left_edge or seam_x > rect.position.x + rect.size.x * 0.22) and (draw_right_edge or seam_x < rect.end.x - rect.size.x * 0.22):
			canvas.draw_line(
				Vector2(seam_x, y - row_height * 0.76),
				Vector2(seam_x, y - row_height * 0.12),
				DarkFantasyPalette.outline_soft,
				EDGE_WIDTH
			)


static func _draw_cap_trim(
	canvas: CanvasItem,
	rect: Rect2,
	cap_height: float,
	color: Color,
	draw_back_left_corner: bool,
	draw_back_right_corner: bool
) -> void:
	var trim_color: Color = color.lightened(0.32)
	var inset: float = rect.size.x * 0.12
	var y: float = rect.position.y + cap_height * 0.48
	canvas.draw_line(
		Vector2(rect.position.x + inset, y),
		Vector2(rect.end.x - inset, y),
		color.darkened(0.05),
		EDGE_WIDTH
	)
	if draw_back_left_corner:
		canvas.draw_line(
			rect.position + Vector2(2.0, 2.0),
			rect.position + Vector2(inset, cap_height * 0.70),
			trim_color,
			EDGE_WIDTH
		)
	if draw_back_right_corner:
		canvas.draw_line(
			Vector2(rect.end.x - 2.0, rect.position.y + 2.0),
			Vector2(rect.end.x - inset, rect.position.y + cap_height * 0.70),
			trim_color,
			EDGE_WIDTH
		)


static func _draw_corner_posts(
	canvas: CanvasItem,
	rect: Rect2,
	cap_height: float,
	color: Color,
	front_left: bool,
	front_right: bool,
	back_left: bool,
	back_right: bool
) -> void:
	var post_size: float = maxf(3.0, rect.size.x * 0.12)
	var post_color: Color = color.darkened(0.22)
	var highlight: Color = color.lightened(0.18)
	if front_left:
		_draw_post(canvas, Rect2(rect.position.x, rect.end.y - post_size * 1.7, post_size, post_size * 1.7), post_color, highlight)
	if front_right:
		_draw_post(canvas, Rect2(rect.end.x - post_size, rect.end.y - post_size * 1.7, post_size, post_size * 1.7), post_color, highlight)
	if back_left:
		_draw_post(canvas, Rect2(rect.position.x, rect.position.y + cap_height * 0.18, post_size, post_size * 1.35), post_color, highlight)
	if back_right:
		_draw_post(canvas, Rect2(rect.end.x - post_size, rect.position.y + cap_height * 0.18, post_size, post_size * 1.35), post_color, highlight)


static func _draw_post(canvas: CanvasItem, rect: Rect2, color: Color, highlight: Color) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * 0.32, rect.size.y)), highlight, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, EDGE_WIDTH)
