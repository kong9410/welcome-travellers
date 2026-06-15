class_name SettingsGearIcon
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.34
	var tooth_len: float = radius * 0.34
	var tooth_width: float = radius * 0.22
	var gear_color: Color = DarkFantasyPalette.brass_bright
	var outline: Color = DarkFantasyPalette.outline

	for index in range(8):
		var angle: float = float(index) * TAU / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		var tooth_center: Vector2 = center + dir * (radius + tooth_len * 0.42)
		var tangent := Vector2(-dir.y, dir.x)
		var half_width: Vector2 = tangent * tooth_width * 0.5
		var half_depth: Vector2 = dir * tooth_len * 0.5
		draw_colored_polygon(
			PackedVector2Array([
				tooth_center - half_width - half_depth,
				tooth_center + half_width - half_depth,
				tooth_center + half_width + half_depth,
				tooth_center - half_width + half_depth,
			]),
			gear_color
		)

	draw_circle(center, radius, gear_color, true)
	draw_arc(center, radius, 0.0, TAU, 24, outline, 1.0, true)
	draw_circle(center, radius * 0.38, DarkFantasyPalette.button_bg, true)
	draw_arc(center, radius * 0.38, 0.0, TAU, 18, outline, 1.0, true)
