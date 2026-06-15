class_name OutsideParallaxLayer
extends Node2D

enum LayerKind {
	FAR_MOUNTAINS,
	MID_FOREST,
}

@export var layer_kind: LayerKind = LayerKind.FAR_MOUNTAINS
@export var parallax_strength: float = 0.35
@export var base_y: float = 430.0
@export var layer_width: float = OutsideViewConstants.WORLD_WIDTH

var _base_x: float = 0.0


func _ready() -> void:
	_base_x = position.x
	set_process(true)


func _process(_delta: float) -> void:
	if ViewManager.current_view_id != ViewIds.Id.OUTSIDE:
		return

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var camera_offset: float = camera.global_position.x - OutsideViewConstants.INN_WORLD_X
	position.x = _base_x + camera_offset * (1.0 - parallax_strength)
	queue_redraw()


func _draw() -> void:
	match layer_kind:
		LayerKind.FAR_MOUNTAINS:
			_draw_mountains()
		LayerKind.MID_FOREST:
			_draw_forest()


func _draw_mountains() -> void:
	var silhouette := Color(0.04, 0.05, 0.06, 0.98)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12001
	var start_x: float = -120.0
	var end_x: float = layer_width + 120.0
	var step: float = 140.0
	var x: float = start_x
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(start_x, base_y + 40.0),
	])

	while x <= end_x:
		var peak_height: float = rng.randf_range(70.0, 150.0)
		var mid_x: float = x + step * 0.5
		points.append(Vector2(mid_x - step * 0.22, base_y + 40.0 - peak_height * 0.55))
		points.append(Vector2(mid_x, base_y + 40.0 - peak_height))
		points.append(Vector2(mid_x + step * 0.22, base_y + 40.0 - peak_height * 0.62))
		points.append(Vector2(x + step, base_y + 40.0 - rng.randf_range(20.0, 60.0)))
		x += step

	points.append(Vector2(end_x, base_y + 40.0))
	draw_colored_polygon(points, silhouette)


func _draw_forest() -> void:
	var trunk := Color(0.03, 0.04, 0.05, 0.98)
	var canopy := Color(0.05, 0.06, 0.07, 0.98)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33007
	var x: float = -40.0

	while x < layer_width + 40.0:
		var tree_width: float = rng.randf_range(26.0, 42.0)
		var tree_height: float = rng.randf_range(48.0, 92.0)
		var tree_x: float = x + rng.randf_range(-8.0, 8.0)
		var ground_y: float = base_y + rng.randf_range(-4.0, 8.0)

		draw_rect(
			Rect2(tree_x + tree_width * 0.42, ground_y - tree_height * 0.35, tree_width * 0.16, tree_height * 0.35),
			trunk
		)
		var crown := PackedVector2Array([
			Vector2(tree_x, ground_y - tree_height * 0.28),
			Vector2(tree_x + tree_width * 0.5, ground_y - tree_height),
			Vector2(tree_x + tree_width, ground_y - tree_height * 0.24),
		])
		draw_colored_polygon(crown, canopy)
		x += rng.randf_range(34.0, 58.0)
