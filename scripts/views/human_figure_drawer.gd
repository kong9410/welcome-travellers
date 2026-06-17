class_name HumanFigureDrawer
extends RefCounted

enum FacingDir {
	DOWN,
	UP,
	LEFT,
	RIGHT,
}

const FOOT_ANCHOR_Y: float = 10.0

class FigureStyle:
	var shirt_color: Color = DarkFantasyPalette.cloth_dark
	var pants_color: Color = DarkFantasyPalette.cloak
	var skin_color: Color = DarkFantasyPalette.skin
	var hair_color: Color = DarkFantasyPalette.hair
	var shoe_color: Color = DarkFantasyPalette.ash
	var accent_color: Color = DarkFantasyPalette.brass
	var outline_color: Color = DarkFantasyPalette.outline
	var has_apron: bool = false
	var has_cloak: bool = false
	var has_hat: bool = false
	var has_backpack: bool = false
	var has_headband: bool = false


static func style_for_innkeeper() -> FigureStyle:
	var style := FigureStyle.new()
	style.shirt_color = DarkFantasyPalette.wood_mid
	style.pants_color = DarkFantasyPalette.cloak
	style.skin_color = DarkFantasyPalette.skin
	style.hair_color = DarkFantasyPalette.hair
	style.accent_color = DarkFantasyPalette.apron
	style.has_apron = true
	return style


static func style_for_unit(team_id: EntityTeams.Id) -> FigureStyle:
	var style := FigureStyle.new()
	match team_id:
		EntityTeams.Id.PLAYER_GUARD:
			style.shirt_color = Color(0.24, 0.36, 0.52, 0.96)
			style.pants_color = DarkFantasyPalette.iron
			style.accent_color = DarkFantasyPalette.brass
			style.has_hat = true
		EntityTeams.Id.PLAYER_MERCENARY:
			style.shirt_color = Color(0.26, 0.42, 0.28, 0.96)
			style.pants_color = DarkFantasyPalette.wood_dark
			style.skin_color = DarkFantasyPalette.skin_shadow
			style.has_cloak = true
		EntityTeams.Id.ENEMY_BANDIT, EntityTeams.Id.ENEMY_RAIDER:
			style.shirt_color = Color(0.42, 0.16, 0.14, 0.96)
			style.pants_color = DarkFantasyPalette.ash
			style.skin_color = DarkFantasyPalette.skin_shadow
			style.has_headband = true
			style.accent_color = DarkFantasyPalette.blood
		_:
			style.shirt_color = DarkFantasyPalette.cloth_dark
			style.pants_color = DarkFantasyPalette.cloak
	return style


static func style_for_customer(
	persona: CustomerPersonas.Id,
	order_type: CustomerOrderTypes.Id
) -> FigureStyle:
	var style := FigureStyle.new()
	style.shirt_color = CustomerOrderTypes.color_for(order_type).darkened(0.08)

	match persona:
		CustomerPersonas.Id.MERCHANT:
			style.hair_color = DarkFantasyPalette.hair
			style.pants_color = DarkFantasyPalette.wood_dark
			style.has_hat = true
			style.accent_color = DarkFantasyPalette.brass
		CustomerPersonas.Id.NOBLE:
			style.hair_color = DarkFantasyPalette.brass.darkened(0.35)
			style.skin_color = DarkFantasyPalette.skin.lightened(0.06)
			style.pants_color = Color(0.20, 0.14, 0.28, 0.98)
			style.shirt_color = Color(0.38, 0.22, 0.42, 0.96)
			style.accent_color = DarkFantasyPalette.brass_bright
			style.has_hat = true
		CustomerPersonas.Id.MERCENARY:
			style.hair_color = DarkFantasyPalette.hair
			style.skin_color = DarkFantasyPalette.skin_shadow
			style.pants_color = DarkFantasyPalette.iron
			style.shirt_color = Color(0.24, 0.28, 0.24, 0.96)
			style.has_headband = true
		_:
			style.hair_color = DarkFantasyPalette.hair.lightened(0.08)
			style.pants_color = DarkFantasyPalette.cloak
			style.has_cloak = true
			style.has_backpack = true
			style.accent_color = style.shirt_color.lightened(0.12)

	return style


static func resolve_facing_dir(facing: Vector2) -> FacingDir:
	if facing.length_squared() < 0.0001:
		return FacingDir.DOWN
	var direction := facing.normalized()
	if absf(direction.x) > absf(direction.y):
		return FacingDir.RIGHT if direction.x > 0.0 else FacingDir.LEFT
	return FacingDir.DOWN if direction.y > 0.0 else FacingDir.UP


static func draw(
	canvas: CanvasItem,
	facing: Vector2,
	style: FigureStyle,
	selected: bool = false,
	group_highlighted: bool = false
) -> void:
	var facing_dir: FacingDir = resolve_facing_dir(facing)
	var figure_offset := Vector2(0.0, -FOOT_ANCHOR_Y)
	_draw_shadow(canvas)

	match facing_dir:
		FacingDir.DOWN:
			canvas.draw_set_transform(figure_offset, 0.0, Vector2.ONE)
			_draw_front(canvas, style)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		FacingDir.UP:
			canvas.draw_set_transform(figure_offset, 0.0, Vector2.ONE)
			_draw_back(canvas, style)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		FacingDir.RIGHT:
			_draw_side(canvas, style, false, figure_offset)
		FacingDir.LEFT:
			_draw_side(canvas, style, true, figure_offset)

	if group_highlighted:
		_draw_group_ring(canvas)
	if selected:
		_draw_selection_ring(canvas)


static func _draw_front(canvas: CanvasItem, style: FigureStyle) -> void:
	if style.has_cloak:
		canvas.draw_circle(Vector2(0.0, 1.0), 8.5, style.shirt_color.darkened(0.18), true)

	if style.has_backpack:
		canvas.draw_rect(Rect2(-5.0, -1.0, 4.0, 7.0), style.accent_color.darkened(0.22), true)
		canvas.draw_rect(Rect2(-5.0, -1.0, 4.0, 7.0), style.outline_color, false, 1.0)

	_draw_limb(canvas, Vector2(-6.0, 2.0), Vector2(3.0, 6.0), style.shirt_color.darkened(0.12))
	_draw_limb(canvas, Vector2(3.0, 2.0), Vector2(3.0, 6.0), style.shirt_color.darkened(0.12))
	canvas.draw_circle(Vector2(0.0, 2.0), 6.2, style.shirt_color, true)
	canvas.draw_arc(Vector2(0.0, 2.0), 6.2, 0.0, TAU, 24, style.outline_color, 1.5, true)

	if style.has_apron:
		canvas.draw_rect(Rect2(-4.5, -1.0, 9.0, 9.0), style.accent_color, true)
		canvas.draw_line(Vector2(0.0, -1.0), Vector2(0.0, -5.0), style.accent_color.darkened(0.08), 1.5)
		canvas.draw_rect(Rect2(-4.5, -1.0, 9.0, 9.0), style.outline_color, false, 1.0)

	_draw_limb(canvas, Vector2(-2.8, 7.0), Vector2(2.4, 3.0), style.pants_color)
	_draw_limb(canvas, Vector2(0.4, 7.0), Vector2(2.4, 3.0), style.pants_color)
	canvas.draw_circle(Vector2(-2.0, 10.0), 1.6, style.shoe_color, true)
	canvas.draw_circle(Vector2(2.0, 10.0), 1.6, style.shoe_color, true)

	canvas.draw_circle(Vector2(0.0, -4.5), 4.4, style.skin_color, true)
	canvas.draw_arc(Vector2(0.0, -4.5), 4.4, 0.0, TAU, 20, style.outline_color, 1.5, true)
	_draw_hair_front(canvas, style)
	_draw_face_front(canvas, style)
	_draw_hat_front(canvas, style)

	if style.has_headband:
		canvas.draw_rect(Rect2(-4.2, -7.2, 8.4, 1.6), DarkFantasyPalette.blood, true)


static func _draw_back(canvas: CanvasItem, style: FigureStyle) -> void:
	if style.has_cloak:
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(8.0, 0.0),
				Vector2(6.0, 9.0),
				Vector2(-6.0, 9.0),
			]),
			style.shirt_color.darkened(0.20)
		)

	if style.has_backpack:
		canvas.draw_rect(Rect2(-4.5, -2.0, 9.0, 8.0), style.accent_color.darkened(0.18), true)
		canvas.draw_rect(Rect2(-4.5, -2.0, 9.0, 8.0), style.outline_color, false, 1.0)
		canvas.draw_line(Vector2(-2.0, -2.0), Vector2(-2.0, -6.0), style.accent_color.darkened(0.28), 1.5)
		canvas.draw_line(Vector2(2.0, -2.0), Vector2(2.0, -6.0), style.accent_color.darkened(0.28), 1.5)

	canvas.draw_rect(Rect2(-6.5, 0.0, 13.0, 8.0), style.shirt_color.darkened(0.06), true)
	canvas.draw_rect(Rect2(-6.5, 0.0, 13.0, 8.0), style.outline_color, false, 1.5)
	canvas.draw_line(Vector2(-6.0, 1.5), Vector2(6.0, 1.5), style.shirt_color.darkened(0.16), 1.5)

	if style.has_apron:
		canvas.draw_rect(Rect2(-3.0, 2.0, 6.0, 5.0), style.accent_color.darkened(0.10), true)
		canvas.draw_line(Vector2(-1.5, 2.0), Vector2(-1.5, -4.0), style.accent_color.darkened(0.12), 1.2)
		canvas.draw_line(Vector2(1.5, 2.0), Vector2(1.5, -4.0), style.accent_color.darkened(0.12), 1.2)

	_draw_limb(canvas, Vector2(-3.0, 7.0), Vector2(2.5, 3.2), style.pants_color)
	_draw_limb(canvas, Vector2(0.5, 7.0), Vector2(2.5, 3.2), style.pants_color)
	canvas.draw_circle(Vector2(-1.8, 10.0), 1.6, style.shoe_color, true)
	canvas.draw_circle(Vector2(1.8, 10.0), 1.6, style.shoe_color, true)

	canvas.draw_circle(Vector2(0.0, -4.0), 4.6, style.hair_color, true)
	canvas.draw_arc(Vector2(0.0, -4.0), 4.6, 0.0, TAU, 20, style.outline_color, 1.5, true)
	canvas.draw_arc(Vector2(0.0, -3.5), 3.8, PI * 0.15, PI * 0.85, 10, style.hair_color.darkened(0.12), 2.0, true)

	if style.has_hat:
		canvas.draw_rect(Rect2(-5.0, -8.0, 10.0, 2.4), style.accent_color.darkened(0.12), true)
		canvas.draw_arc(Vector2(0.0, -6.5), 3.8, PI, TAU, 14, style.accent_color.darkened(0.18), 2.0, true)

	if style.has_headband:
		canvas.draw_rect(Rect2(-4.0, -6.8, 8.0, 1.4), DarkFantasyPalette.blood, true)


static func _draw_side(canvas: CanvasItem, style: FigureStyle, flip: bool, origin: Vector2 = Vector2.ZERO) -> void:
	var mirror: float = -1.0 if flip else 1.0
	canvas.draw_set_transform(origin, 0.0, Vector2(mirror, 1.0))

	if style.has_cloak:
		canvas.draw_colored_polygon(
			PackedVector2Array([
				Vector2(-2.0, 1.0),
				Vector2(4.0, 0.0),
				Vector2(2.0, 9.0),
				Vector2(-6.0, 8.0),
			]),
			style.shirt_color.darkened(0.18)
		)

	if style.has_backpack:
		canvas.draw_rect(Rect2(-7.0, -1.0, 5.0, 8.0), style.accent_color.darkened(0.20), true)
		canvas.draw_rect(Rect2(-7.0, -1.0, 5.0, 8.0), style.outline_color, false, 1.0)

	canvas.draw_circle(Vector2(-0.5, 2.5), 5.5, style.shirt_color, true)
	canvas.draw_arc(Vector2(-0.5, 2.5), 5.5, 0.0, TAU, 20, style.outline_color, 1.5, true)
	_draw_limb(canvas, Vector2(2.0, 2.0), Vector2(2.5, 6.0), style.shirt_color.darkened(0.10))
	_draw_limb(canvas, Vector2(-4.0, 3.0), Vector2(2.0, 5.0), style.shirt_color.darkened(0.18))

	if style.has_apron:
		canvas.draw_rect(Rect2(-3.0, 0.0, 5.0, 8.0), style.accent_color, true)
		canvas.draw_line(Vector2(-1.0, 0.0), Vector2(-1.0, -4.5), style.accent_color.darkened(0.08), 1.2)
		canvas.draw_rect(Rect2(-3.0, 0.0, 5.0, 8.0), style.outline_color, false, 1.0)

	_draw_limb(canvas, Vector2(0.5, 7.0), Vector2(2.2, 3.0), style.pants_color)
	_draw_limb(canvas, Vector2(-2.5, 8.0), Vector2(2.0, 2.6), style.pants_color.darkened(0.08))
	canvas.draw_circle(Vector2(1.5, 10.0), 1.5, style.shoe_color, true)
	canvas.draw_circle(Vector2(-1.0, 10.5), 1.4, style.shoe_color.darkened(0.08), true)

	canvas.draw_circle(Vector2(0.5, -4.5), 4.2, style.skin_color, true)
	canvas.draw_arc(Vector2(0.5, -4.5), 4.2, 0.0, TAU, 18, style.outline_color, 1.5, true)
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(4.0, -4.8),
			Vector2(5.2, -4.0),
			Vector2(4.4, -3.2),
		]),
		style.skin_color.darkened(0.08)
	)
	canvas.draw_circle(Vector2(1.5, -5.0), 0.7, DarkFantasyPalette.hair, true)
	canvas.draw_arc(Vector2(2.0, -3.2), 1.0, 0.2 * PI, 0.75 * PI, 6, DarkFantasyPalette.blood.darkened(0.12), 1.0, true)

	canvas.draw_arc(Vector2(-1.0, -5.0), 4.5, PI * 0.55, PI * 1.45, 12, style.hair_color, 3.0, true)
	canvas.draw_circle(Vector2(-2.5, -5.5), 1.6, style.hair_color, true)

	if style.has_hat:
		canvas.draw_rect(Rect2(-4.0, -8.5, 9.0, 2.0), style.accent_color, true)
		canvas.draw_circle(Vector2(0.5, -6.8), 3.2, style.accent_color.darkened(0.08), true)

	if style.has_headband:
		canvas.draw_rect(Rect2(-2.0, -7.0, 5.0, 1.4), DarkFantasyPalette.blood, true)

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_shadow(canvas: CanvasItem) -> void:
	canvas.draw_colored_polygon(
		PackedVector2Array([
			Vector2(-7.0, 0.0),
			Vector2(7.0, 0.0),
			Vector2(5.0, 2.5),
			Vector2(-5.0, 2.5),
		]),
		DarkFantasyPalette.outline_soft
	)


static func _draw_selection_ring(canvas: CanvasItem) -> void:
	canvas.draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 28, DarkFantasyPalette.brass_bright, 2.0)
	canvas.draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, DarkFantasyPalette.brass_bright.darkened(0.18), 1.0)


static func _draw_group_ring(canvas: CanvasItem) -> void:
	canvas.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 32, Color(0.35, 0.82, 1.0, 0.95), 2.0)


static func _draw_limb(canvas: CanvasItem, position: Vector2, size: Vector2, color: Color) -> void:
	var rect := Rect2(position, size)
	canvas.draw_rect(rect, color, true)
	canvas.draw_rect(rect, DarkFantasyPalette.outline, false, 1.0)


static func _draw_hair_front(canvas: CanvasItem, style: FigureStyle) -> void:
	canvas.draw_arc(Vector2(0.0, -5.0), 4.8, PI * 1.05, TAU * 1.02, 14, style.hair_color, 3.0, true)
	canvas.draw_circle(Vector2(-3.0, -5.5), 1.4, style.hair_color, true)
	canvas.draw_circle(Vector2(3.0, -5.5), 1.4, style.hair_color, true)


static func _draw_face_front(canvas: CanvasItem, style: FigureStyle) -> void:
	var eye_y: float = -4.8
	canvas.draw_circle(Vector2(-1.5, eye_y), 0.7, DarkFantasyPalette.hair, true)
	canvas.draw_circle(Vector2(1.5, eye_y), 0.7, DarkFantasyPalette.hair, true)
	canvas.draw_arc(Vector2(0.0, -3.4), 1.2, 0.15 * PI, 0.85 * PI, 8, DarkFantasyPalette.blood.darkened(0.12), 1.0, true)


static func _draw_hat_front(canvas: CanvasItem, style: FigureStyle) -> void:
	if not style.has_hat:
		return
	canvas.draw_rect(Rect2(-5.5, -8.8, 11.0, 2.2), style.accent_color, true)
	canvas.draw_circle(Vector2(0.0, -7.0), 3.6, style.accent_color.darkened(0.08), true)
	canvas.draw_arc(Vector2(0.0, -7.0), 3.6, 0.0, TAU, 16, style.outline_color, 1.0, true)
