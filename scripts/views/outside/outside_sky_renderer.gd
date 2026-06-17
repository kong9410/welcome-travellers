class_name OutsideSkyRenderer
extends Node2D

const GRADIENT_STEPS: int = 40

var _current_hour: float = float(GameClock.DEFAULT_OPEN_HOUR)


func _ready() -> void:
	z_index = -20
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	EventBus.view_changed.connect(_on_view_changed)
	_current_hour = GameClock.current_hour
	set_process(true)


func _process(_delta: float) -> void:
	if ViewManager.current_view_id != ViewIds.Id.OUTSIDE:
		visible = false
		return
	visible = true

	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera:
		global_position = camera.global_position
	queue_redraw()


func _draw() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size / camera.zoom
	var half_size: Vector2 = viewport_size * 0.5
	var draw_rect := Rect2(-half_size, viewport_size)
	var palette: Dictionary = OutsideSkyState.palette_for_hour(_current_hour)

	_draw_three_band_gradient(
		draw_rect,
		palette.get("top", Color(0.1, 0.12, 0.16)),
		palette.get("mid", Color(0.18, 0.18, 0.20)),
		palette.get("horizon", Color(0.28, 0.26, 0.22))
	)
	_draw_clouds(draw_rect, palette)
	_draw_celestial_bodies(draw_rect, palette)


func _draw_three_band_gradient(rect: Rect2, top: Color, mid: Color, horizon: Color) -> void:
	var step_height: float = rect.size.y / float(GRADIENT_STEPS)
	for step_index: int in GRADIENT_STEPS:
		var t: float = float(step_index) / float(GRADIENT_STEPS - 1)
		var color: Color = top.lerp(mid, clampf(t * 1.8, 0.0, 1.0))
		if t > 0.45:
			color = mid.lerp(horizon, clampf((t - 0.45) / 0.55, 0.0, 1.0))
		draw_rect(
			Rect2(
				rect.position.x,
				rect.position.y + step_height * float(step_index),
				rect.size.x,
				step_height + 1.0
			),
			color
		)


func _draw_clouds(rect: Rect2, palette: Dictionary) -> void:
	var cloud_strength: float = palette.get("cloud_strength", 0.0) as float
	if cloud_strength <= 0.02:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 55123
	var cloud_color := Color(1.0, 1.0, 1.0, 0.72 * cloud_strength)
	var shadow_color := Color(0.88, 0.90, 0.94, 0.28 * cloud_strength)

	for _cloud_index: int in 7:
		var center := Vector2(
			rect.position.x + rng.randf_range(0.04, 0.96) * rect.size.x,
			rect.position.y + rng.randf_range(0.08, 0.38) * rect.size.y
		)
		var base_radius: float = rng.randf_range(28.0, 52.0)
		for puff_index: int in 4:
			var offset := Vector2(
				rng.randf_range(-base_radius * 0.9, base_radius * 0.9),
				rng.randf_range(-base_radius * 0.35, base_radius * 0.35)
			)
			var radius: float = base_radius * rng.randf_range(0.55, 1.0)
			draw_circle(center + offset + Vector2(2.0, 3.0), radius, shadow_color)
			draw_circle(center + offset, radius, cloud_color)


func _draw_celestial_bodies(rect: Rect2, palette: Dictionary) -> void:
	var celestial: Dictionary = OutsideSkyState.sun_disk_for_hour(_current_hour)
	var horizon_y: float = rect.position.y + rect.size.y * 0.58
	var center_x: float = rect.position.x + rect.size.x * 0.72

	if celestial.get("show_sun", false):
		var progress: float = celestial.get("sunset_progress", 0.0) as float
		var day_y: float = rect.position.y + rect.size.y * 0.14
		var sun_y: float = lerpf(day_y, horizon_y + 18.0, progress)
		var sun_color: Color = celestial.get("sun_color", Color.WHITE) as Color
		if progress <= 0.01:
			draw_circle(Vector2(center_x, sun_y), 30.0, sun_color * Color(1.0, 1.0, 1.0, 0.35))
		draw_circle(Vector2(center_x, sun_y), 22.0, sun_color)

	if celestial.get("show_moon", false):
		var moon_color: Color = celestial.get("moon_color", Color.WHITE) as Color
		var moon_center := Vector2(rect.position.x + rect.size.x * 0.72, rect.position.y + rect.size.y * 0.16)
		draw_circle(moon_center, 16.0, moon_color)
		draw_circle(moon_center + Vector2(6.0, -3.0), 14.0, palette.get("top", Color.BLACK) as Color)

	var star_strength: float = palette.get("star_strength", 0.0) as float
	if star_strength <= 0.01:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for _star_index: int in 48:
		var star_position := Vector2(
			rect.position.x + rng.randf_range(0.05, 0.95) * rect.size.x,
			rect.position.y + rng.randf_range(0.04, 0.42) * rect.size.y
		)
		var alpha: float = rng.randf_range(0.25, 0.95) * star_strength
		draw_circle(star_position, rng.randf_range(0.8, 1.8), Color(0.92, 0.94, 0.98, alpha))


func _on_game_hour_changed(hour: float) -> void:
	_current_hour = hour
	queue_redraw()


func _on_view_changed(_previous_view_id: ViewIds.Id, _next_view_id: ViewIds.Id) -> void:
	queue_redraw()
