class_name OutsideInnBuildingRenderer
extends Node2D

signal door_clicked

@export var tier: InnExteriorTiers.Tier = InnExteriorTiers.Tier.SMALL_INN

var door_rect: Rect2 = Rect2()

var _current_hour: float = float(GameClock.SHIFT_START_HOUR)


func _ready() -> void:
	z_index = 4
	position = Vector2(
		OutsideViewConstants.INN_WORLD_X,
		OutsideViewConstants.GROUND_LINE_Y
	)
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	set_process(true)


func _process(_delta: float) -> void:
	if ViewManager.current_view_id != ViewIds.Id.OUTSIDE:
		return
	queue_redraw()


func try_handle_door_click(global_position: Vector2) -> bool:
	if not door_rect.has_area():
		return false
	var local_position: Vector2 = to_local(global_position)
	if door_rect.has_point(local_position):
		door_clicked.emit()
		return true
	return false


func get_door_global_rect() -> Rect2:
	return Rect2(to_global(door_rect.position), door_rect.size)


func _draw() -> void:
	var spec: InnExteriorTiers.TierSpec = InnExteriorTiers.spec_for(tier)
	var body_size: Vector2 = spec.body_size
	var origin := Vector2(-body_size.x * 0.5, -body_size.y)

	_draw_building(origin, body_size, spec)
	_update_door_rect(origin, body_size)


func _draw_building(origin: Vector2, body_size: Vector2, spec: InnExteriorTiers.TierSpec) -> void:
	var colors: Dictionary = _building_colors()
	var body_color: Color = colors.get("body", Color.WHITE) as Color
	var trim: Color = colors.get("trim", Color.WHITE) as Color
	var roof: Color = colors.get("roof", Color.WHITE) as Color
	var window_glow := _window_glow_color()
	var line_width: float = maxf(2.0, body_size.x * 0.008)

	draw_rect(Rect2(origin, body_size), body_color)

	var roof_base_y: float = origin.y
	var roof_peak_y: float = roof_base_y - spec.roof_peak_height
	var roof_half_width: float = body_size.x * 0.58
	var roof_center_x: float = origin.x + body_size.x * 0.5
	var roof_points := PackedVector2Array([
		Vector2(roof_center_x - roof_half_width, roof_base_y),
		Vector2(roof_center_x, roof_peak_y),
		Vector2(roof_center_x + roof_half_width, roof_base_y),
	])
	draw_colored_polygon(roof_points, roof)
	draw_line(
		Vector2(roof_center_x - roof_half_width, roof_base_y),
		Vector2(roof_center_x + roof_half_width, roof_base_y),
		trim,
		line_width
	)

	if spec.has_chimney:
		var chimney_w: float = body_size.x * 0.125
		var chimney_h: float = body_size.y * 0.333
		var chimney_rect := Rect2(
			origin.x + body_size.x * 0.72,
			roof_peak_y + body_size.y * 0.044,
			chimney_w,
			chimney_h
		)
		draw_rect(chimney_rect, colors.get("chimney", trim) as Color)

	var door_width: float = body_size.x * 0.229
	var door_height: float = body_size.y * 0.472
	var door_origin := Vector2(
		origin.x + body_size.x * 0.5 - door_width * 0.5,
		origin.y + body_size.y - door_height
	)
	draw_rect(Rect2(door_origin, Vector2(door_width, door_height)), colors.get("door_frame", trim) as Color)
	draw_rect(
		Rect2(
			door_origin + Vector2(door_width * 0.12, door_height * 0.09),
			Vector2(door_width * 0.76, door_height * 0.82)
		),
		colors.get("door", trim) as Color
	)

	var window_width: float = body_size.x * 0.146
	var window_height: float = body_size.y * 0.222
	var window_y: float = origin.y + body_size.y * 0.34
	for window_index: int in spec.window_count:
		var slot: float = float(window_index + 1) / float(spec.window_count + 1)
		var window_x: float = origin.x + body_size.x * slot - window_width * 0.5
		draw_rect(Rect2(window_x, window_y, window_width, window_height), trim)
		if window_glow.a > 0.02:
			draw_rect(
				Rect2(
					window_x + window_width * 0.12,
					window_y + window_height * 0.12,
					window_width * 0.76,
					window_height * 0.76
				),
				window_glow
			)

	var foundation_h: float = maxf(4.0, body_size.y * 0.022)
	draw_rect(
		Rect2(origin.x - body_size.x * 0.04, -foundation_h * 0.5, body_size.x * 1.08, foundation_h),
		colors.get("foundation", trim) as Color
	)


func _update_door_rect(origin: Vector2, body_size: Vector2) -> void:
	var door_width: float = body_size.x * 0.292
	var door_height: float = body_size.y * 0.556
	door_rect = Rect2(
		Vector2(
			origin.x + body_size.x * 0.5 - door_width * 0.5,
			origin.y + body_size.y - door_height
		),
		Vector2(door_width, door_height)
	)


func _building_colors() -> Dictionary:
	var phase: OutsideSkyState.Phase = OutsideSkyState.phase_for_hour(_current_hour)
	match phase:
		OutsideSkyState.Phase.DAY:
			return {
				"body": Color(0.62, 0.48, 0.34, 0.98),
				"trim": Color(0.48, 0.34, 0.22, 0.96),
				"roof": Color(0.42, 0.28, 0.20, 0.98),
				"chimney": Color(0.52, 0.40, 0.32, 0.98),
				"door_frame": Color(0.38, 0.26, 0.16, 0.98),
				"door": Color(0.52, 0.36, 0.22, 0.96),
				"foundation": Color(0.36, 0.30, 0.24, 0.90),
			}
		OutsideSkyState.Phase.SUNSET:
			return {
				"body": Color(0.48, 0.36, 0.26, 0.98),
				"trim": Color(0.34, 0.24, 0.16, 0.96),
				"roof": Color(0.30, 0.20, 0.14, 0.98),
				"chimney": Color(0.40, 0.30, 0.22, 0.98),
				"door_frame": Color(0.28, 0.18, 0.12, 0.98),
				"door": Color(0.40, 0.28, 0.18, 0.96),
				"foundation": Color(0.24, 0.20, 0.16, 0.90),
			}
		_:
			return {
				"body": Color(0.22, 0.18, 0.16, 0.98),
				"trim": Color(0.16, 0.13, 0.11, 0.96),
				"roof": Color(0.14, 0.12, 0.11, 0.98),
				"chimney": Color(0.18, 0.15, 0.13, 0.98),
				"door_frame": Color(0.14, 0.10, 0.08, 0.98),
				"door": Color(0.20, 0.14, 0.10, 0.96),
				"foundation": Color(0.12, 0.10, 0.09, 0.90),
			}


func _window_glow_color() -> Color:
	var phase: OutsideSkyState.Phase = OutsideSkyState.phase_for_hour(_current_hour)
	if phase == OutsideSkyState.Phase.NIGHT:
		return Color(0.96, 0.72, 0.32, 0.82)
	if phase == OutsideSkyState.Phase.SUNSET:
		return Color(0.92, 0.58, 0.22, 0.55)
	return Color(0.78, 0.86, 0.96, 0.35)


func _on_game_hour_changed(hour: float) -> void:
	_current_hour = hour
	queue_redraw()
