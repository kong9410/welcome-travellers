extends Control

@onready var current_view_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/CurrentViewLabel
@onready var mode_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ModeRow/ModeLabel
@onready var mode_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ModeRow/ModeButton
@onready var day_period_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/DayRow/DayPeriodLabel
@onready var day_period_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/DayRow/DayPeriodButton
@onready var economy_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/EconomyRow/EconomyLabel
@onready var game_day_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/GameDayRow/GameDayLabel
@onready var end_day_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/GameDayRow/EndDayButton
@onready var guest_count_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/GuestRow/GuestCountLabel
@onready var spawn_guest_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/GuestRow/SpawnGuestButton
@onready var queue_status_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/QueueStatusLabel
@onready var staff_clock_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/StaffRow/StaffClockLabel
@onready var staff_task_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/StaffRow/StaffTaskLabel
@onready var resolution_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ResolutionRow/ResolutionLabel
@onready var resolution_option: OptionButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ResolutionRow/ResolutionOption
@onready var cell_info_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/CellInfoLabel
@onready var paint_row: HBoxContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/PaintRow
@onready var paint_option: OptionButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/PaintRow/PaintOption
@onready var theme_row: HBoxContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ThemeRow
@onready var theme_option: OptionButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ThemeRow/ThemeOption
@onready var furniture_row: HBoxContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/FurnitureRow
@onready var furniture_option: OptionButton = $Panel/MarginContainer/ScrollContainer/VBoxContainer/FurnitureRow/FurnitureOption
@onready var save_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/SaveLoadRow/SaveButton
@onready var load_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/SaveLoadRow/LoadButton
@onready var clear_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/SaveLoadRow/ClearButton
@onready var view_buttons: HBoxContainer = $Panel/MarginContainer/ScrollContainer/VBoxContainer/ViewButtons
@onready var unit_info_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/UnitInfoLabel
@onready var customer_info_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/CustomerInfoLabel
@onready var spawn_bandit_button: Button = $Panel/MarginContainer/ScrollContainer/VBoxContainer/UnitRow/SpawnBanditButton
@onready var help_label: Label = $Panel/MarginContainer/ScrollContainer/VBoxContainer/HelpLabel

var _queue_status_timer: float = 0.0
const QUEUE_STATUS_REFRESH_INTERVAL: float = 0.25


func _ready() -> void:
	_apply_passthrough_mouse_filters()
	visible = DebugService.is_active()
	_build_view_buttons()
	_build_resolution_options()
	_build_paint_options()
	_build_theme_options()
	_build_furniture_options()
	_update_current_view_label(ViewManager.current_view_id)
	_update_mode_label(GameModeManager.current_mode)
	_update_day_period_label(DayNightManager.current_period)
	_update_economy_labels()
	_update_game_day_label()
	_update_guest_count()
	_update_queue_status()
	_update_staff_labels()
	_update_resolution_label(DisplayManager.current_preset)
	_update_cell_info(GridCoord.new(), CellData.new())
	_update_unit_info(null)
	_update_customer_info(null)
	_update_mode_controls_visibility()

	EventBus.view_changed.connect(_on_view_changed)
	EventBus.resolution_changed.connect(_on_resolution_changed)
	EventBus.grid_hover_changed.connect(_on_grid_hover_changed)
	EventBus.grid_saved.connect(_on_grid_saved)
	EventBus.grid_loaded.connect(_on_grid_loaded)
	EventBus.game_mode_changed.connect(_on_game_mode_changed)
	EventBus.day_period_changed.connect(_on_day_period_changed)
	EventBus.build_blocked.connect(_on_build_blocked)
	EventBus.furniture_placement_blocked.connect(_on_furniture_blocked)
	EventBus.furniture_placed.connect(_on_furniture_changed)
	EventBus.furniture_removed.connect(_on_furniture_changed)
	EventBus.view_theme_changed.connect(_on_view_theme_changed)
	EventBus.entity_selected.connect(_on_entity_selected)
	EventBus.customer_selected.connect(_on_customer_selected)
	EventBus.economy_changed.connect(_on_economy_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.day_started.connect(_on_game_day_changed)
	EventBus.day_ended.connect(_on_game_day_changed)
	EventBus.morning_briefing_requested.connect(_on_game_day_changed)
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_reviewed.connect(_on_customer_reviewed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	EventBus.staff_task_changed.connect(_on_staff_task_changed)
	EventBus.debug_mode_changed.connect(_on_debug_mode_changed)

	mode_button.pressed.connect(_on_mode_button_pressed)
	day_period_button.pressed.connect(_on_day_period_button_pressed)
	end_day_button.pressed.connect(_on_end_day_pressed)
	spawn_guest_button.pressed.connect(_on_spawn_guest_pressed)
	spawn_bandit_button.pressed.connect(_on_spawn_bandit_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	clear_button.pressed.connect(_on_clear_pressed)


func _process(delta: float) -> void:
	if CustomerService.selected_customer != null and is_instance_valid(CustomerService.selected_customer):
		_update_customer_info(CustomerService.selected_customer)
	if not DebugService.is_active():
		return
	_queue_status_timer -= delta
	if _queue_status_timer <= 0.0:
		_queue_status_timer = QUEUE_STATUS_REFRESH_INTERVAL
		_update_queue_status()


func _apply_passthrough_mouse_filters() -> void:
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_ignore_recursive(
		$Panel,
		["Button", "OptionButton", "ScrollContainer"] as Array[String]
	)


func _set_mouse_ignore_recursive(node: Node, interactive_classes: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Control:
			var control := child as Control
			if _is_interactive_control(control, interactive_classes):
				control.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_ignore_recursive(child, interactive_classes)


func _is_interactive_control(control: Control, interactive_classes: Array[String]) -> bool:
	if control is ScrollContainer:
		return true
	for interactive_class: String in interactive_classes:
		if control.is_class(interactive_class):
			return true
	return false


func _build_view_buttons() -> void:
	for view_id: ViewIds.Id in ViewIds.all():
		var button := Button.new()
		button.text = ViewIds.label_for(view_id)
		button.pressed.connect(_on_view_button_pressed.bind(view_id))
		view_buttons.add_child(button)


func _build_resolution_options() -> void:
	resolution_option.clear()
	for preset: ResolutionPresets.Id in ResolutionPresets.all():
		resolution_option.add_item(ResolutionPresets.label_for(preset), preset)
		if preset == DisplayManager.current_preset:
			resolution_option.select(resolution_option.item_count - 1)
	resolution_option.item_selected.connect(_on_resolution_option_selected)


func _build_paint_options() -> void:
	paint_option.clear()
	for option: Dictionary in CellData.build_paint_options():
		var tile_type: CellData.TileType = option["tile_type"] as CellData.TileType
		paint_option.add_item(option["label"], tile_type)
		if tile_type == GridService.current_paint_type:
			paint_option.select(paint_option.item_count - 1)
	paint_option.item_selected.connect(_on_paint_option_selected)


func _build_theme_options() -> void:
	theme_option.clear()
	var theme_ids: Array[String] = InteriorThemeCatalog.all_theme_ids()
	for index in range(theme_ids.size()):
		var theme_id: String = theme_ids[index]
		var theme: InteriorTheme = InteriorThemeCatalog.get_theme(theme_id)
		theme_option.add_item(theme.display_name, index)
		if theme_id == ThemeService.get_theme_id_for_view(ViewManager.current_view_id):
			theme_option.select(theme_option.item_count - 1)
	theme_option.item_selected.connect(_on_theme_option_selected)


func _build_furniture_options() -> void:
	furniture_option.clear()
	var def_ids: Array[String] = FurnitureCatalog.playable_def_ids()
	for index in range(def_ids.size()):
		var def_id: String = def_ids[index]
		var definition: FurnitureDefinition = FurnitureCatalog.get_definition(def_id)
		furniture_option.add_item(definition.display_name, index)
		if def_id == FurnitureService.current_def_id:
			furniture_option.select(furniture_option.item_count - 1)
	furniture_option.item_selected.connect(_on_furniture_option_selected)


func _furniture_id_from_index(index: int) -> String:
	var def_ids: Array[String] = FurnitureCatalog.playable_def_ids()
	if index < 0 or index >= def_ids.size():
		return def_ids[0]
	return def_ids[index]


func _sync_theme_option() -> void:
	var current_theme_id: String = ThemeService.get_theme_id_for_view(ViewManager.current_view_id)
	for index in range(theme_option.item_count):
		var theme_id: String = _theme_id_from_index(index)
		if theme_id == current_theme_id:
			theme_option.select(index)
			break


func _theme_id_from_index(index: int) -> String:
	var ids: Array[String] = InteriorThemeCatalog.all_theme_ids()
	if index < 0 or index >= ids.size():
		return InteriorThemeCatalog.all_theme_ids()[0]
	return ids[index]


func _on_view_button_pressed(view_id: ViewIds.Id) -> void:
	ViewManager.switch_to(view_id)


func _on_mode_button_pressed() -> void:
	GameModeManager.cycle_mode()


func _on_end_day_pressed() -> void:
	if GameTimeManager.is_running():
		GameTimeManager.end_day()


func _on_spawn_guest_pressed() -> void:
	if not GameTimeManager.is_running():
		help_label.text = "먼저 아침 브리핑에서 하루를 시작하세요."
		return
	if not InnLayoutHelper.has_door(ViewIds.Id.INN_F1):
		help_label.text = "건설: 여관 1층 외벽에 입구 문(외벽 슬롯)을 칠하세요."
		return
	if InnLayoutHelper.find_entry_position(ViewIds.Id.INN_F1) == Vector2.ZERO:
		help_label.text = "건설: 입구 문 안쪽에 바닥을 칠해 손님이 들어올 수 있게 하세요."
		return
	if not InnLayoutHelper.has_interior_floor(ViewIds.Id.INN_F1):
		help_label.text = "건설: 여관 1층 내부에 바닥을 칠하세요."
		return
	CustomerService.spawn_customer()


func _on_economy_changed() -> void:
	_update_economy_labels()


func _on_reputation_changed() -> void:
	_update_economy_labels()


func _on_game_day_changed(_unused = null) -> void:
	_update_game_day_label()


func _on_customer_spawned(customer: CustomerEntity) -> void:
	_update_guest_count()
	_update_queue_status()
	if is_instance_valid(customer) and not customer.finished.is_connected(_on_customer_finished):
		customer.finished.connect(_on_customer_finished)


func _on_customer_finished(_customer: CustomerEntity) -> void:
	_update_guest_count()
	_update_queue_status()
	_update_customer_info(CustomerService.selected_customer)


func _on_customer_reviewed(_customer: CustomerEntity, rating: float, comment: String) -> void:
	_update_guest_count()
	help_label.text = "리뷰: %.1f — %s" % [rating, comment]


func _on_game_over(reason: String) -> void:
	_update_game_day_label()
	end_day_button.disabled = true
	help_label.text = reason


func _on_game_hour_changed(_hour: float) -> void:
	_update_staff_labels()


func _on_staff_task_changed(_task: int) -> void:
	_update_staff_labels()
	_update_queue_status()


func _on_day_period_button_pressed() -> void:
	DayNightManager.toggle_period()


func _on_resolution_option_selected(index: int) -> void:
	var preset: ResolutionPresets.Id = resolution_option.get_item_id(index) as ResolutionPresets.Id
	DisplayManager.apply_preset(preset)


func _on_paint_option_selected(index: int) -> void:
	GridService.current_paint_type = paint_option.get_item_id(index) as CellData.TileType


func _on_theme_option_selected(index: int) -> void:
	var theme_id: String = _theme_id_from_index(index)
	ThemeService.set_theme_for_view(ViewManager.current_view_id, theme_id)


func _on_furniture_option_selected(index: int) -> void:
	FurnitureService.set_current_def(_furniture_id_from_index(index))


func _on_save_pressed() -> void:
	GridService.save_game()


func _on_load_pressed() -> void:
	GridService.load_game()


func _on_clear_pressed() -> void:
	GridService.clear_all_grids()


func _on_spawn_bandit_pressed() -> void:
	var spawn_position: Vector2 = EntityService.default_invasion_route.spawn_world_position
	EntityService.spawn_unit(ViewIds.Id.OUTSIDE, spawn_position, EntityTeams.Id.ENEMY_BANDIT)


func _on_entity_selected(unit: UnitEntity) -> void:
	if unit != null:
		CustomerService.clear_customer_selection()
	_update_unit_info(unit)


func _on_customer_selected(customer: CustomerEntity) -> void:
	if customer != null:
		EntityService.clear_selection()
		_update_unit_info(null)
	_update_customer_info(customer)


func _on_view_changed(_previous_view_id: ViewIds.Id, next_view_id: ViewIds.Id) -> void:
	CustomerService.clear_customer_selection()
	_update_current_view_label(next_view_id)
	_sync_theme_option()


func _on_resolution_changed(preset: ResolutionPresets.Id) -> void:
	_update_resolution_label(preset)
	_sync_resolution_option(preset)


func _on_game_mode_changed(_previous_mode: int, next_mode: int) -> void:
	_update_mode_label(next_mode as GameModes.Id)
	_update_mode_controls_visibility()


func _on_day_period_changed(_previous_period: int, next_period: int) -> void:
	_update_day_period_label(next_period as DayPeriods.Id)


func _on_view_theme_changed(view_id: ViewIds.Id, _theme_id: String) -> void:
	if view_id == ViewManager.current_view_id:
		_sync_theme_option()


func _on_grid_hover_changed(coord: GridCoord, cell: CellData) -> void:
	_update_cell_info(coord, cell)


func _on_build_blocked(_coord: GridCoord, reason: String) -> void:
	help_label.text = reason


func _on_furniture_blocked(_origin: GridCoord, reason: String) -> void:
	help_label.text = reason


func _on_furniture_changed(_instance: FurnitureInstance = null) -> void:
	if GameModeManager.current_mode == GameModes.Id.FURNITURE:
		_update_mode_controls_visibility()
	_update_queue_status()


func _on_grid_saved() -> void:
	help_label.text = "저장 완료: user://inn_grid_save.json"


func _on_grid_loaded() -> void:
	help_label.text = "불러오기 완료."
	_update_mode_label(GameModeManager.current_mode)
	_update_day_period_label(DayNightManager.current_period)
	_update_economy_labels()
	_update_game_day_label()
	_update_guest_count()
	_update_staff_labels()
	end_day_button.disabled = GameTimeManager.phase == GamePhases.Id.GAME_OVER
	_sync_theme_option()
	_update_mode_controls_visibility()


func _update_economy_labels() -> void:
	economy_label.text = "골드: %d | 대출: %d | 평점: %.1f" % [
		EconomyManager.gold,
		EconomyManager.loan_balance,
		ReputationManager.average_rating,
	]


func _update_game_day_label() -> void:
	var phase_label: String = GamePhases.label_for(GameTimeManager.phase)
	game_day_label.text = "여관 %d일차 (%s)" % [GameTimeManager.current_day, phase_label]
	end_day_button.disabled = not GameTimeManager.is_running()


func _update_guest_count() -> void:
	guest_count_label.text = "손님: %d명" % CustomerService.get_active_count()


func _update_queue_status() -> void:
	if queue_status_label == null:
		return
	if not DebugService.is_active():
		queue_status_label.visible = false
		return
	queue_status_label.visible = true
	queue_status_label.text = CustomerService.get_debug_queue_status_text()
	queue_status_label.add_theme_font_size_override("font_size", 10)


func _update_staff_labels() -> void:
	var shift_text: String = "근무 중" if GameClock.is_work_hours() else "퇴근"
	staff_clock_label.text = "시간: %s (%s)" % [GameClock.get_time_label(), shift_text]
	var keeper: InnkeeperEntity = StaffService.get_innkeeper()
	if keeper == null:
		staff_task_label.text = "여관주인: 없음"
		return
	staff_task_label.text = "여관주인: %s" % StaffTasks.label_for(keeper.current_task)


func _update_current_view_label(view_id: ViewIds.Id) -> void:
	current_view_label.text = "현재 층: %s" % ViewIds.label_for(view_id)


func _update_mode_label(mode: GameModes.Id) -> void:
	mode_label.text = "모드: %s" % GameModes.label_for(mode)


func _update_day_period_label(period: DayPeriods.Id) -> void:
	day_period_label.text = DayPeriods.label_for(period)


func _update_resolution_label(preset: ResolutionPresets.Id) -> void:
	var window_size: Vector2i = DisplayManager.get_current_window_size()
	resolution_label.text = "해상도: %s (%dx%d)" % [
		ResolutionPresets.label_for(preset),
		window_size.x,
		window_size.y,
	]


func _update_mode_controls_visibility() -> void:
	var mode: GameModes.Id = GameModeManager.current_mode
	paint_row.visible = mode == GameModes.Id.BUILD
	theme_row.visible = mode == GameModes.Id.BUILD
	furniture_row.visible = mode == GameModes.Id.FURNITURE

	match mode:
		GameModes.Id.BUILD:
			if DebugService.is_active() and GameConstants.DEBUG_DRAG_FLOOR_PAINT:
				help_label.text = "건설: 바닥 드래그(LMB 길게) | LMB/RMB 칠하기/지우기 | 외벽에 입구 문"
			else:
				help_label.text = "건설: LMB 칠하기 | RMB 지우기 | 입구 문은 외벽에 칠하기"
		GameModes.Id.FURNITURE:
			help_label.text = (
				"가구: LMB 배치 | RMB 제거 | R 회전 | F 종료\n"
				+ KitchenUpgradeService.get_kitchen_summary(ViewIds.Id.INN_F1)
			)
		_:
			help_label.text = "플레이: 손님 클릭=상태 확인 | 여관주인 08–22 근무 | B/F 건설·가구 | F3 디버그"


func _on_debug_mode_changed(active: bool) -> void:
	visible = active
	if active:
		_update_queue_status()
		_update_mode_controls_visibility()


func _update_unit_info(unit: UnitEntity) -> void:
	if unit == null:
		unit_info_label.text = "유닛: 선택 없음"
		return
	unit_info_label.text = "유닛: %s | %s | 위치:(%.0f, %.0f)" % [
		unit.entity_id,
		EntityTeams.label_for(unit.team_id),
		unit.global_position.x,
		unit.global_position.y,
	]


func _update_customer_info(customer: CustomerEntity) -> void:
	if customer_info_label == null:
		return
	if customer == null or not is_instance_valid(customer):
		customer_info_label.text = "손님: 선택 없음 (클릭하여 확인)"
		return
	customer_info_label.text = customer.get_status_panel_text()


func _update_cell_info(coord: GridCoord, cell: CellData) -> void:
	if not coord.is_in_bounds():
		cell_info_label.text = "칸: (그리드 밖)"
		return

	var walkable_text := "가능" if cell.is_walkable else "불가"
	var expand_text := "가능" if GridService.can_expand_to(coord, GridService.current_paint_type) else "불가"
	var furniture: FurnitureInstance = FurnitureService.get_instance_at(coord)
	var furniture_text := "없음"
	if furniture != null:
		furniture_text = FurnitureCatalog.get_definition(furniture.def_id).display_name

	cell_info_label.text = "칸: %s | %s | 이동:%s 확장:%s | 가구:%s" % [
		coord.to_label(),
		CellData.label_for(cell.tile_type),
		walkable_text,
		expand_text,
		furniture_text,
	]


func _sync_resolution_option(preset: ResolutionPresets.Id) -> void:
	for index in range(resolution_option.item_count):
		if resolution_option.get_item_id(index) == preset:
			resolution_option.select(index)
			break
