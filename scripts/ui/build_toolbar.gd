extends Control

enum SubMenuKind {
	NONE,
	STRUCTURE,
	FURNITURE,
}

const MAIN_BUTTON_SIZE: float = 64.0
const CATEGORY_BUTTON_SIZE: float = 56.0
const OPTION_BUTTON_SIZE: float = 48.0

@onready var tooltip_label: Label = $Anchor/TooltipPanel/MarginContainer/TooltipLabel
@onready var tooltip_panel: PanelContainer = $Anchor/TooltipPanel
@onready var submenu_row: HBoxContainer = $Anchor/VBox/SubMenuRow
@onready var main_button: Button = $Anchor/VBox/MainRow/MainButton
@onready var structure_button: Button = $Anchor/VBox/MainRow/StructureButton
@onready var furniture_button: Button = $Anchor/VBox/MainRow/FurnitureButton

var _menu_open: bool = false
var _active_submenu: SubMenuKind = SubMenuKind.NONE
var _selected_option_button: Button = null
var _paused_for_build_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	submenu_row.mouse_filter = Control.MOUSE_FILTER_STOP
	submenu_row.mouse_exited.connect(_hide_tooltip)
	_apply_button_styles()
	for button: Button in [main_button, structure_button, furniture_button]:
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	main_button.pressed.connect(_on_main_button_pressed)
	structure_button.pressed.connect(_on_structure_button_pressed)
	furniture_button.pressed.connect(_on_furniture_button_pressed)
	_reset_closed_ui()
	EventBus.game_mode_changed.connect(_on_game_mode_changed)
	EventBus.day_ended.connect(_on_day_phase_changed)
	EventBus.service_phase_changed.connect(_on_day_phase_changed)
	EventBus.day_started.connect(_update_main_button_enabled)
	_update_main_button_enabled()


func _apply_button_styles() -> void:
	_style_circle_button(main_button, MAIN_BUTTON_SIZE, 14)
	_style_circle_button(structure_button, CATEGORY_BUTTON_SIZE, 12)
	_style_circle_button(furniture_button, CATEGORY_BUTTON_SIZE, 12)


func _style_circle_button(button: Button, size: float, font_size: int) -> void:
	button.custom_minimum_size = Vector2(size, size)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	var radius: int = int(size * 0.5)
	button.add_theme_stylebox_override("normal", _make_circle_style(
		DarkFantasyPalette.button_bg,
		DarkFantasyPalette.button_border,
		radius
	))
	button.add_theme_stylebox_override("hover", _make_circle_style(
		DarkFantasyPalette.button_bg_hover,
		DarkFantasyPalette.button_border_hover,
		radius
	))
	button.add_theme_stylebox_override("pressed", _make_circle_style(
		DarkFantasyPalette.button_bg_pressed,
		DarkFantasyPalette.button_border,
		radius
	))
	button.add_theme_stylebox_override("disabled", _make_circle_style(
		DarkFantasyPalette.button_bg_pressed.darkened(0.06),
		DarkFantasyPalette.button_border.darkened(0.18),
		radius
	))


func _make_circle_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style


func is_menu_open() -> bool:
	return _menu_open


func _open_menu() -> void:
	if not GameTimeManager.can_prepare_inn():
		return
	_menu_open = true
	_paused_for_build_menu = GameTimeManager.is_simulation_active()
	if _paused_for_build_menu:
		GameTimeManager.set_time_paused(true)
	main_button.text = "✕"
	structure_button.show()
	furniture_button.show()
	_show_submenu(SubMenuKind.STRUCTURE)


func _reset_closed_ui() -> void:
	_menu_open = false
	_active_submenu = SubMenuKind.NONE
	_clear_submenu()
	_hide_tooltip()
	main_button.text = "건설"
	structure_button.hide()
	furniture_button.hide()
	structure_button.disabled = false
	furniture_button.disabled = false
	submenu_row.hide()


func _close_menu(unpause: bool = true) -> void:
	var was_open: bool = _menu_open
	var resume_time: bool = unpause and was_open and _paused_for_build_menu
	_paused_for_build_menu = false
	_reset_closed_ui()
	if GameModeManager.current_mode != GameModes.Id.PLAY:
		GameModeManager.set_mode(GameModes.Id.PLAY)
	if resume_time:
		GameTimeManager.set_time_paused(false)


func _show_submenu(kind: SubMenuKind) -> void:
	_active_submenu = kind
	_clear_submenu()
	_hide_tooltip()
	submenu_row.show()
	structure_button.disabled = kind == SubMenuKind.STRUCTURE
	furniture_button.disabled = kind == SubMenuKind.FURNITURE

	match kind:
		SubMenuKind.STRUCTURE:
			GameModeManager.set_mode(GameModes.Id.BUILD)
			_populate_structure_options()
		SubMenuKind.FURNITURE:
			GameModeManager.set_mode(GameModes.Id.FURNITURE)
			_populate_furniture_options()
		_:
			submenu_row.hide()


func _clear_submenu() -> void:
	_selected_option_button = null
	for child: Node in submenu_row.get_children():
		child.queue_free()


func _populate_structure_options() -> void:
	for option: Dictionary in CellData.build_paint_options():
		var tile_type: CellData.TileType = option["tile_type"] as CellData.TileType
		var label: String = option["label"] as String
		var button := _create_tile_option_button(tile_type, _format_tile_option_label(tile_type, label))
		button.pressed.connect(_on_structure_option_pressed.bind(tile_type, button))
		submenu_row.add_child(button)
		if tile_type == GridService.current_paint_type:
			_highlight_option_button(button)


func _populate_furniture_options() -> void:
	var remove_button := _create_tile_option_button(CellData.TileType.EMPTY, "가구 제거")
	remove_button.pressed.connect(_on_furniture_remove_pressed.bind(remove_button))
	submenu_row.add_child(remove_button)
	if FurnitureService.is_removal_tool():
		_highlight_option_button(remove_button)

	for def_id: String in FurnitureCatalog.playable_def_ids():
		var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
		var button := _create_furniture_option_button(
			def_id,
			_format_furniture_option_label(def_id, definition.display_name)
		)
		button.pressed.connect(_on_furniture_option_pressed.bind(def_id, button))
		submenu_row.add_child(button)
		if def_id == FurnitureService.current_def_id:
			_highlight_option_button(button)


func _create_tile_option_button(tile_type: CellData.TileType, tooltip: String) -> Button:
	var button := _create_option_button(tooltip)
	var icon := BuildOptionIcon.new()
	icon.kind = BuildOptionIcon.Kind.TILE
	icon.tile_type = tile_type
	button.add_child(icon)
	return button


func _create_furniture_option_button(def_id: String, tooltip: String) -> Button:
	var button := _create_option_button(tooltip)
	var icon := BuildOptionIcon.new()
	icon.kind = BuildOptionIcon.Kind.FURNITURE
	icon.def_id = def_id
	button.add_child(icon)
	return button


func _create_option_button(tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_circle_button(button, OPTION_BUTTON_SIZE, 11)
	button.mouse_entered.connect(_on_option_hover.bind(tooltip))
	return button


func _format_tile_option_label(tile_type: CellData.TileType, label: String) -> String:
	var cost: int = GridService.get_tile_build_cost(tile_type)
	if cost <= 0:
		return label
	return "%s · %d골드" % [label, cost]


func _format_furniture_option_label(def_id: String, label: String) -> String:
	var cost: int = FurnitureCatalog.build_cost_for(def_id)
	if cost <= 0:
		return label
	return "%s · %d골드" % [label, cost]


func _highlight_option_button(button: Button) -> void:
	if _selected_option_button != null and _selected_option_button != button:
		_style_circle_button(_selected_option_button, OPTION_BUTTON_SIZE, 11)
	_selected_option_button = button
	var radius: int = int(OPTION_BUTTON_SIZE * 0.5)
	button.add_theme_stylebox_override("normal", _make_circle_style(
		DarkFantasyPalette.button_selected_bg,
		DarkFantasyPalette.button_selected_border,
		radius
	))


func _on_structure_option_pressed(tile_type: CellData.TileType, button: Button) -> void:
	GridService.current_paint_type = tile_type
	GameModeManager.set_mode(GameModes.Id.BUILD)
	_highlight_option_button(button)


func _on_furniture_option_pressed(def_id: String, button: Button) -> void:
	FurnitureService.set_current_def(def_id)
	GameModeManager.set_mode(GameModes.Id.FURNITURE)
	_highlight_option_button(button)


func _on_furniture_remove_pressed(button: Button) -> void:
	FurnitureService.set_removal_tool()
	GameModeManager.set_mode(GameModes.Id.FURNITURE)
	_highlight_option_button(button)


func _on_option_hover(tooltip: String) -> void:
	tooltip_label.text = tooltip
	tooltip_panel.show()


func _hide_tooltip() -> void:
	tooltip_panel.hide()


func _on_main_button_pressed() -> void:
	if _menu_open:
		_close_menu()
	else:
		_open_menu()


func _on_structure_button_pressed() -> void:
	_show_submenu(SubMenuKind.STRUCTURE)


func _on_furniture_button_pressed() -> void:
	_show_submenu(SubMenuKind.FURNITURE)


func _on_game_mode_changed(_previous_mode: int, next_mode: int) -> void:
	if next_mode == GameModes.Id.PLAY and _menu_open:
		_close_menu()


func _on_day_phase_changed(_unused = null, _unused2 = null) -> void:
	if _menu_open:
		_close_menu()
	_update_main_button_enabled()


func _update_main_button_enabled(_unused = null) -> void:
	main_button.disabled = not GameTimeManager.can_prepare_inn()
