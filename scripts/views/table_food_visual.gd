class_name TableFoodVisual
extends Node2D


func _ready() -> void:
	TopdownDepthSort.apply_for_foot(self, TopdownDepthSort.FOOD_OFFSET)
	queue_redraw()


func _draw() -> void:
	var plate := DarkFantasyPalette.plate
	var rim := DarkFantasyPalette.iron_rim
	var meal := DarkFantasyPalette.stew
	var garnish := DarkFantasyPalette.herb

	draw_circle(Vector2.ZERO, 8.0, plate, true)
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, rim, 1.5, true)
	draw_circle(Vector2(-1.0, 1.0), 5.0, meal, true)
	draw_circle(Vector2(3.0, -2.0), 2.0, garnish, true)
