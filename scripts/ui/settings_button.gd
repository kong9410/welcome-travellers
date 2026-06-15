extends Button

const RADIUS: float = 52.0
const ARC_SEGMENTS: int = 28

signal settings_requested


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(RADIUS, RADIUS)
	_apply_transparent_styles()
	pressed.connect(_on_pressed)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _apply_transparent_styles() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


func _has_point(point: Vector2) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.length_squared() <= RADIUS * RADIUS


func _draw() -> void:
	var bg: Color = DarkFantasyPalette.button_bg
	var border: Color = DarkFantasyPalette.button_border
	if is_hovered():
		bg = DarkFantasyPalette.button_bg_hover
		border = DarkFantasyPalette.button_border_hover
	if is_pressed():
		bg = DarkFantasyPalette.button_bg_pressed

	var points := PackedVector2Array([Vector2.ZERO])
	for index in range(ARC_SEGMENTS + 1):
		var angle: float = float(index) / float(ARC_SEGMENTS) * PI * 0.5
		points.append(Vector2(cos(angle), sin(angle)) * RADIUS)

	draw_colored_polygon(points, bg)
	draw_polyline(points, border, 1.5, true)


func _on_pressed() -> void:
	settings_requested.emit()
