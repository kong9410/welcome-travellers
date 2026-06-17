class_name GridInputController
extends Node

@export var enable_painting: bool = true

var _is_drag_painting_floor: bool = false
var _last_drag_coord: GridCoord = GridCoord.new(-1, -1, ViewIds.Id.OUTSIDE)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(enable_painting)


func _process(_delta: float) -> void:
	_update_hover()
	_update_drag_floor_paint()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_painting:
		return
	if _is_settings_menu_open():
		return
	if GameTimeManager.is_pre_open() or GameTimeManager.phase == GamePhases.Id.GAME_OVER:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_B:
				GameModeManager.toggle_mode()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_F:
				if GameModeManager.is_furniture_mode():
					GameModeManager.set_mode(GameModes.Id.PLAY)
				else:
					GameModeManager.enter_furniture_mode()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_N:
				DayNightManager.toggle_period()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_R and GameModeManager.is_furniture_mode():
				FurnitureService.rotate_preview()
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				_handle_left_click()
				if _can_drag_paint_floor():
					_is_drag_painting_floor = true
					_last_drag_coord = _get_active_coord()
			else:
				_is_drag_painting_floor = false
			get_viewport().set_input_as_handled()
			return
		if not mouse_event.pressed:
			return

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click()
			get_viewport().set_input_as_handled()


func _can_drag_paint_floor() -> bool:
	return (
		DebugService.is_active()
		and GameConstants.DEBUG_DRAG_FLOOR_PAINT
		and GameModeManager.is_build_mode()
		and GridService.current_paint_type == CellData.TileType.FLOOR
	)


func _update_drag_floor_paint() -> void:
	if not _is_drag_painting_floor:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_is_drag_painting_floor = false
		return
	if not _can_drag_paint_floor():
		_is_drag_painting_floor = false
		return

	var coord: GridCoord = _get_active_coord()
	if not coord.is_in_bounds():
		return
	if _last_drag_coord.equals(coord):
		return

	GridService.paint_tile(coord, CellData.TileType.FLOOR)
	_last_drag_coord = coord


func _handle_left_click() -> void:
	if ViewManager.current_view_id == ViewIds.Id.OUTSIDE:
		_handle_outside_left_click()
		return

	if GameModeManager.is_build_mode():
		_paint_at_mouse()
		return

	if GameModeManager.is_furniture_mode():
		var coord: GridCoord = _get_active_coord()
		if coord.is_in_bounds():
			if FurnitureService.is_removal_tool():
				FurnitureService.remove_at(coord)
			else:
				FurnitureService.place_furniture(coord)
		return

	if GameModeManager.is_play_mode():
		var world_position: Vector2 = _get_active_world_position()
		if TableFoodService.try_select_at(world_position, ViewManager.current_view_id):
			FurnitureService.clear_selection()
			CustomerService.clear_customer_selection()
			StaffService.clear_staff_selection()
			EntityService.clear_selection()
			return
		TableFoodService.clear_food_selection()
		StaffService.clear_staff_selection()
		if CustomerService.try_select_at(world_position, ViewManager.current_view_id):
			FurnitureService.clear_selection()
			EntityService.clear_selection()
			return
		CustomerService.clear_customer_selection()
		if StaffService.try_select_at(world_position, ViewManager.current_view_id):
			FurnitureService.clear_selection()
			EntityService.clear_selection()
			return
		StaffService.clear_staff_selection()
		if FurnitureService.try_select_at(world_position, ViewManager.current_view_id):
			EntityService.clear_selection()
			TableFoodService.clear_food_selection()
			CustomerService.clear_customer_selection()
			StaffService.clear_staff_selection()
			return
		if EntityService.try_select_at(world_position):
			FurnitureService.clear_selection()
			StaffService.clear_staff_selection()
			TableFoodService.clear_food_selection()
			return
		FurnitureService.clear_selection()
		StaffService.clear_staff_selection()
		EntityService.clear_selection()
		return

	var coord: GridCoord = _get_active_coord()
	if not coord.is_in_bounds():
		return
	GridService.try_traverse_tile(coord)


func _handle_right_click() -> void:
	if GameModeManager.is_build_mode():
		_erase_at_mouse()
		return

	if GameModeManager.is_furniture_mode():
		return

	if GameModeManager.is_play_mode():
		var world_position: Vector2 = _get_active_world_position()
		if EntityService.command_move_selected_to(world_position):
			return


func _handle_outside_left_click() -> void:
	var active_view: ViewRoot = ViewManager.get_view(ViewIds.Id.OUTSIDE)
	if active_view == null:
		return

	if GameModeManager.is_play_mode():
		var world_position: Vector2 = _get_active_world_position()
		if CustomerService.try_select_at(world_position, ViewIds.Id.OUTSIDE):
			TableFoodService.clear_food_selection()
			StaffService.clear_staff_selection()
			EntityService.clear_selection()
			return
		if EntityService.try_select_at(world_position):
			TableFoodService.clear_food_selection()
			CustomerService.clear_customer_selection()
			StaffService.clear_staff_selection()
			return
		CustomerService.clear_customer_selection()
		TableFoodService.clear_food_selection()
		StaffService.clear_staff_selection()
		EntityService.clear_selection()

	if active_view is OutsideViewRoot:
		(active_view as OutsideViewRoot).try_open_inn_door(_get_active_world_position())


func _update_hover() -> void:
	if ViewManager.current_view_id == ViewIds.Id.OUTSIDE:
		return

	var active_view: ViewRoot = ViewManager.get_view(ViewManager.current_view_id)
	if active_view == null:
		return

	var coord: GridCoord = GridService.coord_from_global(active_view, active_view.get_global_mouse_position())
	var cell: CellData = CellData.new()
	if coord.is_in_bounds():
		cell = GridService.get_cell(coord)
	EventBus.grid_hover_changed.emit(coord, cell)


func _paint_at_mouse() -> void:
	var coord: GridCoord = _get_active_coord()
	if not coord.is_in_bounds():
		return
	GridService.paint_tile(coord, GridService.current_paint_type)


func _erase_at_mouse() -> void:
	var coord: GridCoord = _get_active_coord()
	if not coord.is_in_bounds():
		return
	GridService.paint_tile(coord, CellData.TileType.EMPTY)


func _get_active_coord() -> GridCoord:
	var active_view: ViewRoot = ViewManager.get_view(ViewManager.current_view_id)
	if active_view == null:
		return GridCoord.new(-1, -1, ViewManager.current_view_id)
	return GridService.coord_from_global(active_view, active_view.get_global_mouse_position())


func _get_active_world_position() -> Vector2:
	var active_view: ViewRoot = ViewManager.get_view(ViewManager.current_view_id)
	if active_view == null:
		return Vector2.ZERO
	return active_view.get_global_mouse_position()


func _is_settings_menu_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group("settings_menu"):
		if node.has_method("is_open") and node.is_open():
			return true
	return false
