extends Camera2D

const PAN_SPEED: float = 460.0
const ZOOM_MIN: float = 0.55
const ZOOM_MAX: float = 2.4
const ZOOM_STEP: float = 1.12
const VIEW_MARGIN: float = 48.0

var _view_changed_connected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	make_current()
	zoom = Vector2.ONE
	if not _view_changed_connected:
		EventBus.view_changed.connect(_on_view_changed)
		_view_changed_connected = true


func _process(delta: float) -> void:
	if _is_settings_menu_open():
		return
	var move_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if ViewManager.current_view_id == ViewIds.Id.OUTSIDE:
		if move_input != Vector2.ZERO:
			_center_on_active_view()
		return
	if move_input == Vector2.ZERO:
		return

	global_position += move_input.normalized() * PAN_SPEED * delta / zoom.x
	_clamp_to_active_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if (
			ViewManager.current_view_id == ViewIds.Id.OUTSIDE
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		):
			_center_on_active_view()
			get_viewport().set_input_as_handled()
			return

		var zoom_factor: float = 1.0
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_factor = ZOOM_STEP
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_factor = 1.0 / ZOOM_STEP
			_:
				return

		_apply_zoom(zoom_factor, event.position)
		get_viewport().set_input_as_handled()


func _on_view_changed(_previous_view_id: ViewIds.Id, _next_view_id: ViewIds.Id) -> void:
	_center_on_active_view()


func _center_on_active_view() -> void:
	var active_view: ViewRoot = ViewManager.get_view(ViewManager.current_view_id)
	if active_view == null:
		return

	if ViewManager.current_view_id == ViewIds.Id.OUTSIDE:
		zoom = Vector2.ONE
		global_position = active_view.global_position + OutsideViewConstants.default_camera_focus()
		return

	global_position = TopdownViewBounds.focus_point(active_view)


func _apply_zoom(factor: float, mouse_screen_position: Vector2) -> void:
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var mouse_world_before: Vector2 = _screen_to_world(mouse_screen_position)
	zoom = Vector2.ONE * new_zoom
	var mouse_world_after: Vector2 = _screen_to_world(mouse_screen_position)
	global_position += mouse_world_before - mouse_world_after
	_clamp_to_active_view()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	return viewport.get_canvas_transform().affine_inverse() * screen_position


func _clamp_to_active_view() -> void:
	var active_view: ViewRoot = ViewManager.get_view(ViewManager.current_view_id)
	if active_view == null:
		return

	if ViewManager.current_view_id == ViewIds.Id.OUTSIDE:
		_clamp_to_outside_view(active_view)
		return

	var view_rect := TopdownViewBounds.visual_rect(active_view)
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view := viewport_size * 0.5 / zoom.x

	var min_position := view_rect.position + half_view - Vector2.ONE * VIEW_MARGIN
	var max_position := view_rect.end - half_view + Vector2.ONE * VIEW_MARGIN
	var view_center := view_rect.get_center()

	global_position.x = _clamp_axis(global_position.x, min_position.x, max_position.x, view_center.x)
	global_position.y = _clamp_axis(global_position.y, min_position.y, max_position.y, view_center.y)


func _clamp_to_outside_view(active_view: ViewRoot) -> void:
	var focus := active_view.global_position + OutsideViewConstants.default_camera_focus()
	global_position.x = focus.x
	global_position.y = focus.y


static func _clamp_axis(value: float, min_value: float, max_value: float, center_value: float) -> float:
	if min_value <= max_value:
		return clampf(value, min_value, max_value)
	var slack: float = (min_value - max_value) * 0.5 + VIEW_MARGIN
	return clampf(value, center_value - slack, center_value + slack)


func _is_settings_menu_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group("settings_menu"):
		if node.has_method("is_open") and node.is_open():
			return true
	return false
