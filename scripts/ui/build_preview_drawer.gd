class_name BuildPreviewDrawer
extends RefCounted

static func draw_tile(
	canvas: CanvasItem,
	rect: Rect2,
	tile_type: CellData.TileType,
	view_id = null,
	coord = null
) -> void:
	TopdownTileDrawer.draw_tile(canvas, rect, tile_type, view_id, coord)


static func draw_furniture(
	canvas: CanvasItem,
	rect: Rect2,
	def_id: String,
	rotation_steps: int = 0
) -> void:
	TopdownFurnitureDrawer.draw_furniture(canvas, rect, def_id, rotation_steps)


static func _draw_furniture_shape(
	canvas: CanvasItem,
	rect: Rect2,
	def_id: String,
	placeholder_color: Color
) -> void:
	match def_id:
		"hearth":
			_draw_hearth(canvas, rect)
		"prep_table":
			_draw_prep_table(canvas, rect)
		"cauldron":
			_draw_cauldron(canvas, rect)
		"pantry_shelf":
			_draw_pantry_shelf(canvas, rect)
		"pot_rack":
			_draw_pot_rack(canvas, rect)
		"bread_oven":
			_draw_bread_oven(canvas, rect)
		"barrel":
			_draw_barrel(canvas, rect)
		"chair":
			_draw_chair(canvas, rect, placeholder_color)
		"table":
			_draw_table(canvas, rect, placeholder_color)
		"bed":
			_draw_bed(canvas, rect, placeholder_color)
		"counter":
			_draw_counter(canvas, rect, placeholder_color)
		"room_door":
			_draw_room_door(canvas, rect, placeholder_color)
		_:
			_draw_default_furniture(canvas, rect, placeholder_color)


static func _draw_erase_icon(canvas: CanvasItem, rect: Rect2) -> void:
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


static func _draw_floor_icon(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.0)
	var plank_count: int = 3
	var plank_width: float = rect.size.x / float(plank_count)
	for index in range(1, plank_count):
		var x: float = rect.position.x + plank_width * float(index)
		canvas.draw_line(
			Vector2(x, rect.position.y + rect.size.y * 0.12),
			Vector2(x, rect.position.y + rect.size.y * 0.88),
			DarkFantasyPalette.outline_soft,
			1.0
		)


static func _draw_wall_icon(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.0)

	var inset := rect.grow(-maxf(1.0, rect.size.x * 0.05))
	var row_count: int = 3
	var row_height: float = inset.size.y / float(row_count)
	var gap: float = maxf(1.0, inset.size.x * 0.08)
	var block_width: float = inset.size.x * 0.42
	var block_height: float = row_height * 0.76
	var row_inset_y: float = row_height * 0.12
	var right_edge: float = inset.position.x + inset.size.x

	for row in range(row_count):
		var y: float = inset.position.y + row_height * float(row) + row_inset_y
		var x: float = inset.position.x + (row % 2) * (block_width + gap) * 0.5
		while x < right_edge - 0.5:
			var draw_width: float = minf(block_width, right_edge - x)
			if draw_width <= 0.5:
				break
			canvas.draw_rect(
				Rect2(x, y, draw_width, block_height),
				DarkFantasyPalette.outline_soft,
				true
			)
			x += block_width + gap


static func _draw_door_icon(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var frame := rect.grow(-rect.size.x * 0.08)
	canvas.draw_rect(frame, DarkFantasyPalette.wood_dark, true)
	var panel := frame.grow(-frame.size.x * 0.14)
	canvas.draw_rect(panel, color, true)
	canvas.draw_rect(panel, DarkFantasyPalette.outline, false, 1.0)
	canvas.draw_circle(
		panel.position + Vector2(panel.size.x * 0.78, panel.size.y * 0.52),
		maxf(panel.size.x * 0.05, 1.5),
		DarkFantasyPalette.brass
	)


static func _draw_stairs_icon(canvas: CanvasItem, rect: Rect2, color: Color, going_up: bool) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect.grow(-rect.size.x * 0.10), DarkFantasyPalette.brass_bright.lightened(0.35), false, 1.5)
	var step_count: int = 3
	var step_height: float = rect.size.y * 0.16
	for index in range(step_count):
		var y: float
		if going_up:
			y = rect.position.y + rect.size.y * 0.18 + step_height * float(index)
		else:
			y = rect.position.y + rect.size.y * 0.82 - step_height * float(index + 1)
		canvas.draw_line(
			Vector2(rect.position.x + rect.size.x * 0.16, y),
			Vector2(rect.position.x + rect.size.x * 0.84, y),
			DarkFantasyPalette.brass_bright.lightened(0.42),
			1.5
		)
	var center := rect.get_center()
	var arrow_size: float = minf(rect.size.x, rect.size.y) * 0.18
	var tip_y: float = center.y - arrow_size if going_up else center.y + arrow_size
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(center.x, tip_y),
			Vector2(center.x - arrow_size, center.y),
			Vector2(center.x + arrow_size, center.y),
		]),
		DarkFantasyPalette.brass_bright.lightened(0.48)
	)


static func _draw_outside_ground_icon(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline_soft, false, 1.0)
	for index in range(4):
		var x: float = rect.position.x + rect.size.x * (0.18 + float(index) * 0.18)
		var y: float = rect.position.y + rect.size.y * (0.22 + float(index % 2) * 0.34)
		canvas.draw_circle(
			Vector2(x, y),
			maxf(rect.size.x * 0.05, 1.0),
			DarkFantasyPalette.herb.darkened(0.08)
		)


static func _draw_default_furniture(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.5)


static func _draw_chair(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var wood: Color = color.darkened(0.14)
	var wood_dark: Color = color.darkened(0.30)
	var cushion: Color = color.lightened(0.12)
	var leg_size: float = maxf(minf(rect.size.x, rect.size.y) * 0.11, 1.5)

	# 등받이 (위쪽 두꺼운 나무판)
	var back := Rect2(
		rect.position.x + rect.size.x * 0.12,
		rect.position.y + rect.size.y * 0.06,
		rect.size.x * 0.76,
		rect.size.y * 0.24
	)
	canvas.draw_rect(back, wood, true)
	canvas.draw_rect(back, wood_dark, false, 1.5)
	for slat_index in range(3):
		var slat_x: float = back.position.x + back.size.x * (0.20 + float(slat_index) * 0.30)
		canvas.draw_line(
			Vector2(slat_x, back.position.y + back.size.y * 0.18),
			Vector2(slat_x, back.position.y + back.size.y * 0.82),
			wood_dark,
			1.0
		)

	# 좌석
	var seat := Rect2(
		rect.position.x + rect.size.x * 0.14,
		rect.position.y + rect.size.y * 0.28,
		rect.size.x * 0.72,
		rect.size.y * 0.54
	)
	canvas.draw_rect(seat, wood, true)
	canvas.draw_rect(
		Rect2(
			seat.position.x + seat.size.x * 0.08,
			seat.position.y + seat.size.y * 0.08,
			seat.size.x * 0.84,
			seat.size.y * 0.84
		),
		cushion,
		true
	)
	canvas.draw_rect(seat, wood_dark, false, 1.5)

	# 다리 네 개
	var leg_offsets: Array[Vector2] = [
		Vector2(0.12, 0.24),
		Vector2(0.76, 0.24),
		Vector2(0.10, 0.78),
		Vector2(0.78, 0.78),
	]
	for offset: Vector2 in leg_offsets:
		var leg_pos := rect.position + Vector2(rect.size.x * offset.x, rect.size.y * offset.y)
		canvas.draw_rect(Rect2(leg_pos, Vector2(leg_size, leg_size * 0.9)), wood_dark, true)

	# 좌석 앞쪽 곡선 느낌 (식탁 쪽)
	canvas.draw_line(
		seat.position + Vector2(seat.size.x * 0.12, seat.size.y * 0.92),
		seat.position + Vector2(seat.size.x * 0.88, seat.size.y * 0.92),
		wood_dark,
		1.0
	)


static func _draw_table(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var top := Rect2(
		rect.position.x + rect.size.x * 0.06,
		rect.position.y + rect.size.y * 0.28,
		rect.size.x * 0.88,
		rect.size.y * 0.44
	)
	canvas.draw_rect(top, color, true)
	canvas.draw_rect(top, DarkFantasyPalette.outline, false, 1.0)
	for leg_x in [0.16, 0.78]:
		canvas.draw_rect(
			Rect2(
				rect.position.x + rect.size.x * leg_x,
				rect.position.y + rect.size.y * 0.68,
				rect.size.x * 0.08,
				rect.size.y * 0.20
			),
			color.darkened(0.18),
			true
		)


static func _draw_bed(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var frame := Rect2(
		rect.position.x + rect.size.x * 0.06,
		rect.position.y + rect.size.y * 0.30,
		rect.size.x * 0.88,
		rect.size.y * 0.48
	)
	canvas.draw_rect(frame, color.darkened(0.12), true)
	canvas.draw_rect(frame, DarkFantasyPalette.outline, false, 1.0)
	canvas.draw_rect(
		Rect2(frame.position.x, frame.position.y, frame.size.x * 0.24, frame.size.y),
		color.lightened(0.12),
		true
	)
	canvas.draw_rect(
		Rect2(
			frame.position.x + frame.size.x * 0.28,
			frame.position.y + frame.size.y * 0.12,
			frame.size.x * 0.64,
			frame.size.y * 0.76
		),
		color,
		true
	)


static func _draw_counter(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var top := Rect2(
		rect.position.x + rect.size.x * 0.04,
		rect.position.y + rect.size.y * 0.24,
		rect.size.x * 0.92,
		rect.size.y * 0.36
	)
	canvas.draw_rect(top, color, true)
	canvas.draw_rect(top, DarkFantasyPalette.outline, false, 1.0)
	canvas.draw_rect(
		Rect2(
			rect.position.x + rect.size.x * 0.04,
			rect.position.y + rect.size.y * 0.58,
			rect.size.x * 0.92,
			rect.size.y * 0.24
		),
		color.darkened(0.14),
		true
	)


static func _draw_room_door(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var frame := rect.grow(-rect.size.x * 0.10)
	canvas.draw_rect(frame, DarkFantasyPalette.wood_dark, true)
	var panel := frame.grow(-frame.size.x * 0.18)
	canvas.draw_rect(panel, color, true)
	canvas.draw_line(
		panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.12),
		panel.position + Vector2(panel.size.x * 0.5, panel.size.y * 0.88),
		DarkFantasyPalette.outline_soft,
		1.0
	)
	canvas.draw_circle(
		panel.position + Vector2(panel.size.x * 0.78, panel.size.y * 0.54),
		maxf(panel.size.x * 0.05, 1.5),
		DarkFantasyPalette.brass
	)


static func _draw_hearth(canvas: CanvasItem, rect: Rect2) -> void:
	var stone := DarkFantasyPalette.stone_mid
	var ash_color := DarkFantasyPalette.ash
	var fire_outer := DarkFantasyPalette.ember
	var fire_inner := DarkFantasyPalette.flame

	canvas.draw_rect(rect, stone, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.5)

	var opening := Rect2(
		rect.position.x + rect.size.x * 0.18,
		rect.position.y + rect.size.y * 0.28,
		rect.size.x * 0.64,
		rect.size.y * 0.52
	)
	canvas.draw_rect(opening, ash_color, true)
	canvas.draw_circle(opening.get_center(), minf(opening.size.x, opening.size.y) * 0.28, fire_outer)
	canvas.draw_circle(opening.get_center(), minf(opening.size.x, opening.size.y) * 0.16, fire_inner)
	canvas.draw_rect(
		Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y * 0.14),
		DarkFantasyPalette.stone_dark,
		true
	)


static func _draw_prep_table(canvas: CanvasItem, rect: Rect2) -> void:
	var wood := DarkFantasyPalette.wood_light
	var edge := DarkFantasyPalette.wood_dark
	var stain := DarkFantasyPalette.wood_mid.darkened(0.12)

	canvas.draw_rect(rect, wood, true)
	canvas.draw_rect(rect, edge, false, 1.5)

	var block_count: int = 3
	var block_width: float = rect.size.x / float(block_count)
	for index in range(block_count):
		var x: float = rect.position.x + block_width * float(index)
		canvas.draw_line(
			Vector2(x, rect.position.y + rect.size.y * 0.12),
			Vector2(x, rect.position.y + rect.size.y * 0.88),
			stain,
			1.0
		)
	canvas.draw_rect(
		Rect2(
			rect.position.x + rect.size.x * 0.72,
			rect.position.y + rect.size.y * 0.18,
			rect.size.x * 0.08,
			rect.size.y * 0.52
		),
		DarkFantasyPalette.iron_rim,
		true
	)


static func _draw_cauldron(canvas: CanvasItem, rect: Rect2) -> void:
	var iron_color := DarkFantasyPalette.iron
	var rim := DarkFantasyPalette.iron_rim
	var broth := DarkFantasyPalette.stew
	var center := rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.34

	canvas.draw_line(
		Vector2(center.x - radius * 0.9, center.y - radius * 1.1),
		Vector2(center.x + radius * 0.9, center.y - radius * 1.1),
		DarkFantasyPalette.wood_dark,
		1.5
	)
	canvas.draw_circle(center, radius, iron_color)
	canvas.draw_arc(center, radius, 0.0, TAU, 24, rim, 1.5, true)
	canvas.draw_circle(center, radius * 0.72, broth)


static func _draw_pantry_shelf(canvas: CanvasItem, rect: Rect2) -> void:
	var frame := DarkFantasyPalette.wood_mid
	var shelf := DarkFantasyPalette.wood_light

	canvas.draw_rect(rect, frame, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.5)

	for row in range(3):
		var y: float = rect.position.y + rect.size.y * (0.22 + float(row) * 0.26)
		canvas.draw_line(
			Vector2(rect.position.x, y),
			Vector2(rect.position.x + rect.size.x, y),
			shelf,
			2.0
		)
		var jar_x: float = rect.position.x + rect.size.x * (0.22 + float(row % 2) * 0.28)
		canvas.draw_rect(
			Rect2(jar_x, y - rect.size.y * 0.12, rect.size.x * 0.14, rect.size.y * 0.12),
			DarkFantasyPalette.brass,
			true
		)
		canvas.draw_rect(
			Rect2(
				jar_x + rect.size.x * 0.34,
				y - rect.size.y * 0.10,
				rect.size.x * 0.12,
				rect.size.y * 0.10
			),
			DarkFantasyPalette.wood_dark,
			true
		)


static func _draw_pot_rack(canvas: CanvasItem, rect: Rect2) -> void:
	var beam := DarkFantasyPalette.wood_mid
	var hook := DarkFantasyPalette.iron
	var pot := DarkFantasyPalette.iron_rim

	canvas.draw_rect(rect, DarkFantasyPalette.wood_dark.darkened(0.08), true)
	canvas.draw_rect(
		Rect2(rect.position.x, rect.position.y + rect.size.y * 0.08, rect.size.x, rect.size.y * 0.10),
		beam,
		true
	)

	var pot_count: int = 3
	for index in range(pot_count):
		var x: float = rect.position.x + rect.size.x * (0.18 + float(index) * 0.28)
		var hook_top := Vector2(x, rect.position.y + rect.size.y * 0.13)
		var hook_bottom := Vector2(x, rect.position.y + rect.size.y * 0.42)
		canvas.draw_line(hook_top, hook_bottom, hook, 1.5)
		canvas.draw_circle(Vector2(x, rect.position.y + rect.size.y * 0.56), rect.size.y * 0.12, pot)


static func _draw_bread_oven(canvas: CanvasItem, rect: Rect2) -> void:
	var stone := DarkFantasyPalette.stone_mid
	var dome := DarkFantasyPalette.stone_dark
	var mouth := DarkFantasyPalette.ash
	var ember_color := DarkFantasyPalette.ember

	canvas.draw_rect(rect, stone, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.5)

	var arch_center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.58)
	var arch_radius: float = minf(rect.size.x, rect.size.y) * 0.28
	canvas.draw_arc(arch_center, arch_radius, PI, TAU, 20, dome, 3.0, true)
	canvas.draw_arc(arch_center, arch_radius * 0.72, PI, TAU, 16, mouth, 1.5, true)
	canvas.draw_circle(
		arch_center + Vector2(0.0, arch_radius * 0.18),
		arch_radius * 0.18,
		ember_color
	)


static func _draw_barrel(canvas: CanvasItem, rect: Rect2) -> void:
	var wood := DarkFantasyPalette.wood_mid
	var band := DarkFantasyPalette.iron
	var center := rect.get_center()
	var radius: float = minf(rect.size.x, rect.size.y) * 0.36

	canvas.draw_circle(center, radius, wood)
	canvas.draw_arc(center, radius, 0.0, TAU, 24, band, 1.5, true)
	canvas.draw_line(
		Vector2(center.x - radius, center.y),
		Vector2(center.x + radius, center.y),
		band,
		1.5
	)
