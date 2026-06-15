class_name HudCoinStackIcon
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 22)


func _draw() -> void:
	var face := DarkFantasyPalette.brass_bright
	var rim := DarkFantasyPalette.brass
	var shadow := DarkFantasyPalette.outline
	var center: Vector2 = size * 0.5
	var offsets: Array[Vector2] = [
		center + Vector2(-6, 0),
		center + Vector2(0, -2),
		center + Vector2(-3, 3),
	]
	var radius: float = 5.2
	for index in range(offsets.size()):
		var coin_center: Vector2 = offsets[index]
		draw_circle(coin_center, radius, shadow, true)
		draw_arc(coin_center, radius, 0.0, TAU, 18, rim, 1.2, true)
		draw_circle(coin_center, radius * 0.82, face, true)
		draw_arc(coin_center, radius * 0.82, -0.35, 2.1, 8, face.lightened(0.18), 1.0, true)
