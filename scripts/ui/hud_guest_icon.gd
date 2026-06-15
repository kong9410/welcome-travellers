class_name HudGuestIcon
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var skin := DarkFantasyPalette.skin
	var shirt := DarkFantasyPalette.cloth_dark
	var outline := DarkFantasyPalette.outline

	draw_circle(center + Vector2(0, -5.5), 3.6, skin, true)
	draw_arc(center + Vector2(0, -5.5), 3.6, 0.0, TAU, 14, outline, 1.0, true)
	draw_rect(Rect2(center.x - 4.0, center.y - 1.0, 8.0, 7.5), shirt, true)
	draw_rect(Rect2(center.x - 4.0, center.y - 1.0, 8.0, 7.5), outline, false, 1.0)
	draw_rect(Rect2(center.x - 2.8, center.y + 6.0, 2.4, 4.0), DarkFantasyPalette.cloak, true)
	draw_rect(Rect2(center.x + 0.4, center.y + 6.0, 2.4, 4.0), DarkFantasyPalette.cloak, true)
