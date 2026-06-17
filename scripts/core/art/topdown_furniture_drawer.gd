class_name TopdownFurnitureDrawer
extends RefCounted

const EDGE_WIDTH: float = 1.25
const CHAIR_TEXTURE: Texture2D = preload("res://assets/chair_directions.png")
const CHAIR_DIRECTION_COLUMNS: int = 4
const CHAIR_TEXTURE_CONTENT_HEIGHT_RATIO: float = 0.48
const CHAIR_DRAW_Y_OFFSET: float = 4.0


static func draw_furniture(
	canvas: CanvasItem,
	rect: Rect2,
	def_id: String,
	rotation_steps: int = 0
) -> void:
	var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
	var steps: int = posmod(rotation_steps, 4)
	var rotated_footprint: Vector2i = FurnitureFootprint.get_rotated_size(
		definition.footprint,
		steps
	)
	var scale: float = minf(
		rect.size.x / maxf(float(rotated_footprint.x), 1.0),
		rect.size.y / maxf(float(rotated_footprint.y), 1.0)
	)
	var art_size: Vector2 = Vector2(definition.footprint) * scale
	var center: Vector2 = rect.get_center()
	var local_rect := Rect2(-art_size * 0.5, art_size)
	var uses_chair_texture: bool = (
		def_id in ["chair", "waiting_chair"] and CHAIR_TEXTURE != null
	)
	var draw_rotation: float = 0.0 if uses_chair_texture else steps * PI * 0.5

	canvas.draw_set_transform(center, draw_rotation, Vector2.ONE)
	_draw_shape(canvas, local_rect, def_id, definition.placeholder_color, steps)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_shape(
	canvas: CanvasItem,
	rect: Rect2,
	def_id: String,
	color: Color,
	rotation_steps: int = 0
) -> void:
	match def_id:
		"chair", "waiting_chair":
			_draw_chair(canvas, rect, color, rotation_steps)
		"table":
			_draw_table(canvas, rect, color)
		"bed":
			_draw_bed(canvas, rect, color)
		"owner_bed":
			_draw_bed(canvas, rect, color)
		"counter":
			_draw_counter(canvas, rect, color)
		"barrel":
			_draw_barrel(canvas, rect, color)
		"room_door":
			_draw_room_door(canvas, rect, color)
		"hearth":
			_draw_hearth(canvas, rect, color)
		"prep_table":
			_draw_prep_table(canvas, rect, color)
		"cauldron":
			_draw_cauldron(canvas, rect, color)
		"pantry_shelf":
			_draw_pantry_shelf(canvas, rect, color)
		"pot_rack":
			_draw_pot_rack(canvas, rect, color)
		"bread_oven":
			_draw_bread_oven(canvas, rect, color)
		_:
			_draw_box(canvas, _inset(rect, 0.12, 0.18, 0.12, 0.12), color, rect.size.y * 0.24)


static func _draw_table(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.06, 0.18, 0.06, 0.20)
	_draw_box(canvas, body, color, rect.size.y * 0.22)
	_draw_legs(canvas, body, color.darkened(0.30), rect.size.x * 0.07)


static func _draw_chair(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	rotation_steps: int = 0
) -> void:
	if CHAIR_TEXTURE != null:
		var frame_index: int = _chair_texture_frame_index(rotation_steps)
		var source_rect: Rect2 = _chair_texture_source_rect(frame_index)
		var aspect: float = source_rect.size.y / maxf(source_rect.size.x, 1.0)
		var draw_width: float = rect.size.x
		var draw_height: float = draw_width * aspect
		if draw_height > rect.size.y:
			draw_height = rect.size.y
			draw_width = draw_height / aspect
		var draw_rect := Rect2(
			rect.position.x + (rect.size.x - draw_width) * 0.5,
			rect.end.y - draw_height + CHAIR_DRAW_Y_OFFSET,
			draw_width,
			draw_height
		)
		canvas.draw_texture_rect_region(CHAIR_TEXTURE, draw_rect, source_rect)
		return

	var back := _inset(rect, 0.14, 0.06, 0.14, 0.62)
	var seat := _inset(rect, 0.16, 0.34, 0.16, 0.16)
	_draw_box(canvas, back, color.darkened(0.05), rect.size.y * 0.18)
	_draw_box(canvas, seat, color.lightened(0.10), rect.size.y * 0.18)
	_draw_legs(canvas, seat, color.darkened(0.32), rect.size.x * 0.08)


static func _chair_texture_source_rect(frame_index: int) -> Rect2:
	var tex_size: Vector2 = CHAIR_TEXTURE.get_size()
	var cell_width: float = tex_size.x / float(CHAIR_DIRECTION_COLUMNS)
	var content_height: float = tex_size.y * CHAIR_TEXTURE_CONTENT_HEIGHT_RATIO
	return Rect2(
		Vector2(float(frame_index) * cell_width, 0.0),
		Vector2(cell_width, content_height)
	)


static func _chair_texture_frame_index(rotation_steps: int) -> int:
	# Sheet order: N, S, W, E — matches rotation_steps back direction.
	match posmod(rotation_steps, 4):
		0:
			return 0
		1:
			return 2
		2:
			return 1
		_:
			return 3


static func _draw_bed(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var frame := _inset(rect, 0.05, 0.20, 0.05, 0.12)
	_draw_box(canvas, frame, color.darkened(0.12), rect.size.y * 0.22)
	var mattress := _inset(frame, 0.05, 0.06, 0.05, 0.18)
	canvas.draw_rect(mattress, color.lightened(0.18), true)
	canvas.draw_rect(mattress, DarkFantasyPalette.outline_soft, false, EDGE_WIDTH)
	var pillow := Rect2(
		mattress.position.x + mattress.size.x * 0.06,
		mattress.position.y + mattress.size.y * 0.08,
		mattress.size.x * 0.22,
		mattress.size.y * 0.72
	)
	canvas.draw_rect(pillow, Color(0.72, 0.68, 0.62, 0.96), true)
	canvas.draw_rect(pillow, DarkFantasyPalette.outline_soft, false, EDGE_WIDTH)


static func _draw_counter(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.04, 0.18, 0.04, 0.18)
	_draw_box(canvas, body, color, rect.size.y * 0.30)
	var shelf_y: float = body.position.y + body.size.y * 0.66
	canvas.draw_line(
		Vector2(body.position.x + body.size.x * 0.06, shelf_y),
		Vector2(body.end.x - body.size.x * 0.06, shelf_y),
		color.darkened(0.32),
		EDGE_WIDTH
	)


static func _draw_barrel(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.18, 0.14, 0.18, 0.10)
	var band: Color = DarkFantasyPalette.iron_rim
	_draw_ellipse(canvas, body, color)
	_draw_ellipse_outline(canvas, body, color.darkened(0.34))
	canvas.draw_line(
		Vector2(body.position.x + body.size.x * 0.18, body.position.y + body.size.y * 0.34),
		Vector2(body.end.x - body.size.x * 0.18, body.position.y + body.size.y * 0.34),
		band,
		EDGE_WIDTH
	)
	canvas.draw_line(
		Vector2(body.position.x + body.size.x * 0.18, body.position.y + body.size.y * 0.66),
		Vector2(body.end.x - body.size.x * 0.18, body.position.y + body.size.y * 0.66),
		band,
		EDGE_WIDTH
	)


static func _draw_room_door(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var door := _inset(rect, 0.20, 0.08, 0.20, 0.08)
	_draw_box(canvas, door, color, rect.size.y * 0.18)
	canvas.draw_line(
		Vector2(door.position.x + door.size.x * 0.5, door.position.y + door.size.y * 0.16),
		Vector2(door.position.x + door.size.x * 0.5, door.end.y - door.size.y * 0.12),
		color.darkened(0.24),
		EDGE_WIDTH
	)
	canvas.draw_circle(
		door.position + Vector2(door.size.x * 0.78, door.size.y * 0.55),
		maxf(1.4, rect.size.x * 0.045),
		DarkFantasyPalette.brass_bright
	)


static func _draw_hearth(canvas: CanvasItem, rect: Rect2, _color: Color) -> void:
	var body := _inset(rect, 0.06, 0.16, 0.06, 0.14)
	_draw_box(canvas, body, DarkFantasyPalette.stone_mid, rect.size.y * 0.25)
	var mouth := _inset(body, 0.28, 0.42, 0.28, 0.16)
	canvas.draw_rect(mouth, DarkFantasyPalette.ash, true)
	canvas.draw_circle(mouth.get_center(), minf(mouth.size.x, mouth.size.y) * 0.35, DarkFantasyPalette.flame)


static func _draw_prep_table(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.06, 0.20, 0.06, 0.20)
	_draw_box(canvas, body, color.lightened(0.05), rect.size.y * 0.20)
	var board := _inset(body, 0.20, 0.20, 0.20, 0.38)
	canvas.draw_rect(board, DarkFantasyPalette.wood_light, true)
	canvas.draw_rect(board, DarkFantasyPalette.outline_soft, false, EDGE_WIDTH)


static func _draw_cauldron(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var pot := _inset(rect, 0.15, 0.24, 0.15, 0.10)
	_draw_ellipse(canvas, pot, color.darkened(0.04))
	_draw_ellipse_outline(canvas, pot, DarkFantasyPalette.outline)
	var inner := _inset(pot, 0.16, 0.12, 0.16, 0.55)
	_draw_ellipse(canvas, inner, DarkFantasyPalette.stew)
	canvas.draw_arc(pot.get_center(), pot.size.x * 0.46, PI * 1.08, PI * 1.92, 16, DarkFantasyPalette.iron_rim, EDGE_WIDTH)


static func _draw_pantry_shelf(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.06, 0.10, 0.06, 0.12)
	_draw_box(canvas, body, color, rect.size.y * 0.24)
	for shelf_index in range(2):
		var y: float = body.position.y + body.size.y * (0.38 + float(shelf_index) * 0.28)
		canvas.draw_line(Vector2(body.position.x + 2.0, y), Vector2(body.end.x - 2.0, y), color.darkened(0.32), EDGE_WIDTH)
	for item_index in range(4):
		var x: float = body.position.x + body.size.x * (0.18 + float(item_index) * 0.18)
		canvas.draw_circle(Vector2(x, body.position.y + body.size.y * 0.28), maxf(1.8, rect.size.x * 0.035), DarkFantasyPalette.herb)


static func _draw_pot_rack(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var rail_y: float = rect.position.y + rect.size.y * 0.28
	canvas.draw_line(
		Vector2(rect.position.x + rect.size.x * 0.10, rail_y),
		Vector2(rect.end.x - rect.size.x * 0.10, rail_y),
		color.lightened(0.10),
		2.0
	)
	for index in range(3):
		var x: float = rect.position.x + rect.size.x * (0.24 + float(index) * 0.25)
		canvas.draw_line(Vector2(x, rail_y), Vector2(x, rail_y + rect.size.y * 0.22), DarkFantasyPalette.iron_rim, EDGE_WIDTH)
		_draw_ellipse(
			canvas,
			Rect2(x - rect.size.x * 0.06, rail_y + rect.size.y * 0.20, rect.size.x * 0.12, rect.size.y * 0.22),
			DarkFantasyPalette.iron
		)


static func _draw_bread_oven(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var body := _inset(rect, 0.07, 0.14, 0.07, 0.12)
	_draw_box(canvas, body, color, rect.size.y * 0.28)
	var mouth := _inset(body, 0.30, 0.38, 0.30, 0.16)
	_draw_ellipse(canvas, mouth, DarkFantasyPalette.ash)
	canvas.draw_arc(mouth.get_center(), mouth.size.x * 0.48, PI, TAU, 18, DarkFantasyPalette.outline, EDGE_WIDTH)


static func _draw_box(canvas: CanvasItem, rect: Rect2, color: Color, face_height: float) -> void:
	var face: float = clampf(face_height, 2.0, rect.size.y * 0.45)
	var top := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - face))
	var front := Rect2(rect.position.x, top.end.y, rect.size.x, face)
	canvas.draw_rect(top, color.lightened(0.13), true)
	canvas.draw_rect(front, color.darkened(0.10), true)
	canvas.draw_rect(Rect2(front.position, Vector2(front.size.x * 0.18, front.size.y)), color.darkened(0.22), true)
	canvas.draw_line(top.position, Vector2(top.end.x, top.position.y), color.lightened(0.28), EDGE_WIDTH)
	canvas.draw_line(front.position, Vector2(front.end.x, front.position.y), DarkFantasyPalette.outline_soft, EDGE_WIDTH)
	canvas.draw_rect(Rect2(rect.position, rect.size), DarkFantasyPalette.outline, false, EDGE_WIDTH)


static func _draw_legs(canvas: CanvasItem, rect: Rect2, color: Color, leg_size: float) -> void:
	var leg := maxf(1.5, leg_size)
	var leg_offsets: Array[Vector2] = [
		Vector2(0.12, 0.68),
		Vector2(0.78, 0.68),
		Vector2(0.12, 0.88),
		Vector2(0.78, 0.88),
	]
	for offset: Vector2 in leg_offsets:
		canvas.draw_rect(
			Rect2(rect.position + Vector2(rect.size.x * offset.x, rect.size.y * offset.y), Vector2(leg, leg * 1.5)),
			color,
			true
		)


static func _draw_ellipse(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_colored_polygon(_ellipse_points(rect), color)


static func _draw_ellipse_outline(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var points: PackedVector2Array = _ellipse_points(rect)
	for index in range(points.size()):
		canvas.draw_line(points[index], points[(index + 1) % points.size()], color, EDGE_WIDTH)


static func _ellipse_points(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var center: Vector2 = rect.get_center()
	var radius: Vector2 = rect.size * 0.5
	for index in range(18):
		var angle: float = TAU * float(index) / 18.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


static func _inset(rect: Rect2, left: float, top: float, right: float, bottom: float) -> Rect2:
	return Rect2(
		rect.position.x + rect.size.x * left,
		rect.position.y + rect.size.y * top,
		rect.size.x * (1.0 - left - right),
		rect.size.y * (1.0 - top - bottom)
	)
