class_name HudFoodIcon
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var outline := DarkFantasyPalette.outline
	var sack := Color(0.58, 0.42, 0.24, 0.98)
	var sack_light := Color(0.78, 0.58, 0.32, 0.98)
	var grain := Color(0.92, 0.76, 0.38, 0.98)
	var center: Vector2 = size * 0.5

	var sack_points := PackedVector2Array([
		center + Vector2(-7.0, -5.0),
		center + Vector2(7.0, -5.0),
		center + Vector2(8.0, 7.0),
		center + Vector2(4.0, 10.0),
		center + Vector2(-4.0, 10.0),
		center + Vector2(-8.0, 7.0),
	])
	draw_colored_polygon(sack_points, sack)
	draw_polyline(sack_points, outline, 1.2, true)
	draw_line(center + Vector2(-6.0, -2.0), center + Vector2(6.0, -2.0), outline, 1.0)
	draw_line(center + Vector2(-4.0, -5.0), center + Vector2(4.0, -9.0), sack_light, 2.0)
	draw_circle(center + Vector2(-2.5, 3.0), 2.0, grain)
	draw_circle(center + Vector2(2.5, 4.0), 2.0, grain.darkened(0.08))
