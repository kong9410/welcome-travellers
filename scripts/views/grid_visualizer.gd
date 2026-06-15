class_name GridVisualizer
extends Node2D

@export var grid_size: Vector2i = GameConstants.GRID_VISUAL_SIZE
@export var background_color: Color = DarkFantasyPalette.grid_bg
@export var grid_line_color: Color = DarkFantasyPalette.grid_line
@export var border_color: Color = DarkFantasyPalette.grid_border


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var tile_size: float = float(GameConstants.TILE_SIZE)
	var pixel_size := Vector2(grid_size) * tile_size

	draw_rect(Rect2(Vector2.ZERO, pixel_size), background_color, true)
	draw_rect(Rect2(Vector2.ZERO, pixel_size), border_color, false, 2.0)

	for x in range(grid_size.x + 1):
		var line_x: float = x * tile_size
		draw_line(Vector2(line_x, 0.0), Vector2(line_x, pixel_size.y), grid_line_color, 1.0)

	for y in range(grid_size.y + 1):
		var line_y: float = y * tile_size
		draw_line(Vector2(0.0, line_y), Vector2(pixel_size.x, line_y), grid_line_color, 1.0)
