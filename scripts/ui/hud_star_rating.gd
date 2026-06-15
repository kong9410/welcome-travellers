class_name HudStarRating
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func set_rating(_value: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.38
	var filled := Color(0.96, 0.82, 0.18, 0.98)
	var outline := DarkFantasyPalette.outline
	var points := _star_points(center, radius)
	draw_colored_polygon(points, filled)
	draw_polyline(points, outline, 1.0, true)


static func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var angle: float = -PI * 0.5 + float(index) * PI / 5.0
		var dist: float = radius if index % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(angle), sin(angle)) * dist)
	return points
