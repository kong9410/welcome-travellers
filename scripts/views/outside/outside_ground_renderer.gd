class_name OutsideGroundRenderer
extends Node2D

const WORLD_WIDTH: float = OutsideViewConstants.WORLD_WIDTH
const GROUND_Y: float = OutsideViewConstants.GROUND_LINE_Y

var _current_hour: float = float(GameClock.SHIFT_START_HOUR)


func _ready() -> void:
	z_index = 1
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	set_process(true)


func _process(_delta: float) -> void:
	if ViewManager.current_view_id != ViewIds.Id.OUTSIDE:
		return
	queue_redraw()


func _draw() -> void:
	var phase: OutsideSkyState.Phase = OutsideSkyState.phase_for_hour(_current_hour)
	var ground_top: Color
	var ground_bottom: Color
	var grass_color: Color

	match phase:
		OutsideSkyState.Phase.DAY:
			ground_top = Color(0.42, 0.58, 0.32, 1.0)
			ground_bottom = Color(0.34, 0.48, 0.26, 1.0)
			grass_color = Color(0.28, 0.42, 0.20, 0.65)
		OutsideSkyState.Phase.SUNSET:
			ground_top = Color(0.32, 0.42, 0.24, 1.0)
			ground_bottom = Color(0.24, 0.32, 0.18, 1.0)
			grass_color = Color(0.22, 0.32, 0.16, 0.55)
		_:
			ground_top = Color(0.14, 0.18, 0.12, 1.0)
			ground_bottom = Color(0.10, 0.12, 0.08, 1.0)
			grass_color = Color(0.12, 0.16, 0.10, 0.45)

	draw_rect(Rect2(0.0, GROUND_Y, WORLD_WIDTH, 200.0), ground_top)
	draw_rect(Rect2(0.0, GROUND_Y + 18.0, WORLD_WIDTH, 120.0), ground_bottom)

	var rng := RandomNumberGenerator.new()
	rng.seed = 44011
	for _grass_index: int in 160:
		var grass_x: float = rng.randf_range(0.0, WORLD_WIDTH)
		var grass_y: float = GROUND_Y + rng.randf_range(2.0, 16.0)
		draw_line(
			Vector2(grass_x, grass_y),
			Vector2(grass_x + rng.randf_range(-2.0, 2.0), grass_y - rng.randf_range(4.0, 10.0)),
			grass_color,
			1.0
		)


func _on_game_hour_changed(hour: float) -> void:
	_current_hour = hour
	queue_redraw()
