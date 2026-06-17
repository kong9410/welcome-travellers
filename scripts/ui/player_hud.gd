extends Control

const FurnitureInfoHelper := preload("res://scripts/core/furniture/furniture_info_helper.gd")

@onready var time_panel: PanelContainer = $TimePanel
@onready var day_label: Label = $TimePanel/AlignCenter/CenterRow/DayLabel
@onready var gold_label: Label = $TopBar/MarginContainer/HBox/GoldRow/GoldLabel
@onready var top_bar_hbox: HBoxContainer = $TopBar/MarginContainer/HBox
@onready var star_rating: HudStarRating = $TopBar/MarginContainer/HBox/RatingRow/StarRating
@onready var rating_label: Label = $TopBar/MarginContainer/HBox/RatingRow/RatingLabel

@onready var time_label: Label = $TimePanel/AlignCenter/CenterRow/TimeLabel
@onready var guests_label: Label = $TimePanel/AlignCenter/CenterRow/GuestRow/GuestsLabel

@onready var view_tabs: VBoxContainer = $ViewSidebar/MarginContainer/ViewTabs

@onready var customer_panel: PanelContainer = $CustomerPanel
@onready var customer_title_label: Label = $CustomerPanel/MarginContainer/VBox/CustomerTitleLabel
@onready var customer_detail_label: Label = $CustomerPanel/MarginContainer/VBox/CustomerDetailLabel

@onready var notice_label: Label = $NoticeLabel

@onready var settings_button: Button = $SettingsButton
@onready var settings_menu: Control = $SettingsMenu

var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.35
const NOTICE_DURATION: float = 4.0
var _notice_timer: float = 0.0
var _time_control_panel: PanelContainer = null
var _pause_button: Button = null
var _speed_1x_button: Button = null
var _speed_2x_button: Button = null
var _speed_3x_button: Button = null
var _food_label: Label = null
var _market_button: Button = null
var _market_popup: PanelContainer = null
var _market_amount_label: Label = null
var _market_price_label: Label = null
var _market_pending_label: Label = null
var _market_accept_button: Button = null
var _market_shop_panel: VBoxContainer = null
var _market_orders_panel: VBoxContainer = null
var _market_orders_list: VBoxContainer = null
var _market_orders_empty_label: Label = null
var _editing_order_id: int = -1
var _editing_order_amount: int = MarketConstants.GRAIN_BATCH_SIZE
var _market_grain_amount: int = MarketConstants.GRAIN_BATCH_SIZE
var _business_hours_panel: PanelContainer = null
var _business_hours_open: bool = false
var _hours_current_label: Label = null
var _hours_scheduled_label: Label = null
var _hours_open_value_label: Label = null
var _hours_close_value_label: Label = null
var _end_service_button: Button = null
var _start_open_button: Button = null
var _market_payment_warning_popup: PanelContainer = null
var _market_payment_warning_dismissed: bool = false
var _furniture_panel: PanelContainer = null
var _furniture_title_label: Label = null
var _furniture_detail_label: Label = null
var _queue_summary_label: Label = null


func _ready() -> void:
	_build_business_hours_panel()
	_build_start_open_button()
	_build_market_payment_warning_popup()
	_build_time_controls()
	_build_queue_summary_ui()
	_build_food_display()
	_apply_passthrough_mouse_filters()
	_setup_time_panel_click()
	_build_market_ui()
	_build_furniture_panel()
	_build_view_tabs()
	_connect_signals()
	settings_button.settings_requested.connect(settings_menu.open_menu)
	_refresh_all()
	customer_panel.hide()
	if _furniture_panel:
		_furniture_panel.hide()
	notice_label.hide()


func _process(delta: float) -> void:
	if TableFoodService.selected_food != null and is_instance_valid(TableFoodService.selected_food):
		_update_food_panel(TableFoodService.selected_food)
	elif CustomerService.selected_customer != null and is_instance_valid(CustomerService.selected_customer):
		_update_customer_panel(CustomerService.selected_customer)
	elif StaffService.selected_staff != null and is_instance_valid(StaffService.selected_staff):
		_update_staff_panel(StaffService.selected_staff)
	elif FurnitureService.get_selected_instance() != null:
		_update_furniture_panel(FurnitureService.get_selected_instance())
	else:
		customer_panel.hide()
		if _furniture_panel:
			_furniture_panel.hide()

	if not _should_refresh_time_hud():
		return

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_update_time_labels()
		_update_queue_summary_label()

	if notice_label.visible:
		_notice_timer -= delta
		if _notice_timer <= 0.0:
			notice_label.hide()


func _connect_signals() -> void:
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.game_time_pause_changed.connect(_on_game_time_pause_changed)
	EventBus.game_time_speed_changed.connect(_on_game_time_speed_changed)
	EventBus.economy_changed.connect(_refresh_economy)
	EventBus.food_changed.connect(_on_food_changed)
	EventBus.reputation_changed.connect(_refresh_economy)
	EventBus.day_started.connect(_on_day_changed)
	EventBus.day_ended.connect(_on_day_changed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.game_hour_changed.connect(_on_game_hour_changed)
	EventBus.service_phase_changed.connect(_on_service_phase_changed)
	EventBus.business_hours_changed.connect(_on_business_hours_changed)
	EventBus.market_pending_changed.connect(_on_market_pending_changed)
	EventBus.market_delivered.connect(_on_market_delivered)
	EventBus.market_orders_cancelled.connect(_on_market_orders_cancelled)
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_selected.connect(_on_customer_selected)
	EventBus.staff_selected.connect(_on_staff_selected)
	EventBus.furniture_selected.connect(_on_furniture_selected)
	EventBus.customer_order_rejected.connect(_on_customer_order_rejected)
	EventBus.customer_reviewed.connect(_on_customer_reviewed)
	EventBus.group_outside_wait_notice.connect(_on_group_outside_wait_notice)
	EventBus.furniture_placed.connect(_on_customer_activity_changed)
	EventBus.furniture_removed.connect(_on_customer_activity_changed)
	EventBus.build_cost_spent.connect(_on_build_cost_spent)


func _apply_passthrough_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$TopBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$ViewSidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	customer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_ignore_recursive(self, ["Button"] as Array[String])


func _build_time_controls() -> void:
	_time_control_panel = PanelContainer.new()
	_time_control_panel.name = "TimeControlPanel"
	_time_control_panel.z_index = 2
	_time_control_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_control_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_time_control_panel.offset_left = -236.0
	_time_control_panel.offset_top = -56.0
	_time_control_panel.offset_right = -16.0
	_time_control_panel.offset_bottom = -16.0
	_time_control_panel.add_theme_stylebox_override("panel", _make_time_control_panel_style())
	add_child(_time_control_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	_time_control_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	_speed_1x_button = _create_time_control_button("1x")
	_speed_2x_button = _create_time_control_button("2x")
	_speed_3x_button = _create_time_control_button("3x")
	_pause_button = _create_time_control_button("정지")
	row.add_child(_speed_1x_button)
	row.add_child(_speed_2x_button)
	row.add_child(_speed_3x_button)
	row.add_child(_pause_button)

	_speed_1x_button.pressed.connect(_on_speed_1x_pressed)
	_speed_2x_button.pressed.connect(_on_speed_2x_pressed)
	_speed_3x_button.pressed.connect(_on_speed_3x_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)


func _build_queue_summary_ui() -> void:
	var align_center: CenterContainer = time_panel.get_node("AlignCenter")
	var center_row: HBoxContainer = align_center.get_node("CenterRow")
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	align_center.remove_child(center_row)
	vbox.add_child(center_row)
	_queue_summary_label = Label.new()
	_queue_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_queue_summary_label.add_theme_font_size_override("font_size", 11)
	_queue_summary_label.add_theme_color_override("font_color", Color(0.82, 0.74, 0.58, 0.95))
	_queue_summary_label.text = ""
	vbox.add_child(_queue_summary_label)
	align_center.add_child(vbox)
	time_panel.offset_bottom = 56.0


func _create_time_control_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(48.0, 28.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 11)
	return button


func _make_time_control_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.07, 0.88)
	style.border_color = Color(0.42, 0.32, 0.20, 0.88)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _build_business_hours_panel() -> void:
	_business_hours_panel = PanelContainer.new()
	_business_hours_panel.name = "BusinessHoursPanel"
	_business_hours_panel.z_index = 3
	_business_hours_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_business_hours_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_business_hours_panel.offset_left = -118.0
	_business_hours_panel.offset_top = 44.0
	_business_hours_panel.offset_right = 118.0
	_business_hours_panel.offset_bottom = 236.0
	_business_hours_panel.add_theme_stylebox_override("panel", _make_time_control_panel_style())
	_business_hours_panel.hide()
	add_child(_business_hours_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_business_hours_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	_hours_current_label = Label.new()
	_hours_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hours_current_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_hours_current_label)

	_hours_scheduled_label = Label.new()
	_hours_scheduled_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hours_scheduled_label.add_theme_font_size_override("font_size", 11)
	_hours_scheduled_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62, 1.0))
	column.add_child(_hours_scheduled_label)

	var note := Label.new()
	note.text = "시간 변경은 내일부터 적용"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.62, 0.58, 0.52, 1.0))
	column.add_child(note)

	column.add_child(_create_hours_scroll_row("시작", _on_open_hour_up_pressed, _on_open_hour_down_pressed, true))
	column.add_child(_create_hours_scroll_row("종료", _on_close_hour_up_pressed, _on_close_hour_down_pressed, false))

	_end_service_button = Button.new()
	_end_service_button.text = "영업 종료"
	_end_service_button.focus_mode = Control.FOCUS_NONE
	_end_service_button.custom_minimum_size = Vector2(0.0, 32.0)
	_end_service_button.pressed.connect(_on_end_service_pressed)
	column.add_child(_end_service_button)

	_update_business_hours_panel()


func _build_start_open_button() -> void:
	_start_open_button = Button.new()
	_start_open_button.name = "StartOpenButton"
	_start_open_button.text = "영업 시작"
	_start_open_button.z_index = 3
	_start_open_button.focus_mode = Control.FOCUS_NONE
	_start_open_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_start_open_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_start_open_button.offset_left = -72.0
	_start_open_button.offset_top = 44.0
	_start_open_button.offset_right = 72.0
	_start_open_button.offset_bottom = 80.0
	_start_open_button.add_theme_font_size_override("font_size", 13)
	_start_open_button.pressed.connect(_on_start_open_pressed)
	add_child(_start_open_button)
	_update_start_open_button()


func _on_start_open_pressed() -> void:
	_close_business_hours_panel()
	_close_market_payment_warning()
	GameTimeManager.start_open_day()


func _update_start_open_button() -> void:
	if _start_open_button == null:
		return
	var should_show: bool = GameTimeManager.is_pre_open()
	var was_visible: bool = _start_open_button.visible
	_start_open_button.visible = should_show
	if should_show and not was_visible:
		_market_payment_warning_dismissed = false
		_try_show_market_payment_warning()


func _build_market_payment_warning_popup() -> void:
	_market_payment_warning_popup = PanelContainer.new()
	_market_payment_warning_popup.name = "MarketPaymentWarningPopup"
	_market_payment_warning_popup.z_index = 12
	_market_payment_warning_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_market_payment_warning_popup.set_anchors_preset(Control.PRESET_CENTER)
	_market_payment_warning_popup.offset_left = -210.0
	_market_payment_warning_popup.offset_top = -88.0
	_market_payment_warning_popup.offset_right = 210.0
	_market_payment_warning_popup.offset_bottom = 88.0
	_market_payment_warning_popup.add_theme_stylebox_override("panel", _make_time_control_panel_style())
	_market_payment_warning_popup.hide()
	add_child(_market_payment_warning_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_market_payment_warning_popup.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var title := Label.new()
	title.text = "시장 주문 결제 불가"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)

	var message := Label.new()
	message.name = "MessageLabel"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)

	var confirm_button := Button.new()
	confirm_button.text = "확인"
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.custom_minimum_size = Vector2(0.0, 32.0)
	confirm_button.pressed.connect(_close_market_payment_warning)
	column.add_child(confirm_button)


func _try_show_market_payment_warning() -> void:
	if not GameTimeManager.is_pre_open():
		return
	if not MarketService.has_unaffordable_pending():
		return
	_show_market_payment_warning(false)


func _show_market_payment_warning(force: bool) -> void:
	if _market_payment_warning_popup == null:
		return
	if not force and _market_payment_warning_dismissed:
		return
	if not MarketService.has_unaffordable_pending():
		return
	var message_label: Label = _market_payment_warning_popup.find_child("MessageLabel", true, false) as Label
	if message_label != null:
		message_label.text = (
			"영업 시작 시 시장 주문 결제에 골드가 부족하면 예약이 취소됩니다.\n"
			+ "보유 %d골드 · 필요 %d골드"
			% [EconomyManager.gold, MarketService.get_pending_cost()]
		)
	_market_payment_warning_popup.show()


func _close_market_payment_warning() -> void:
	_market_payment_warning_dismissed = true
	if _market_payment_warning_popup != null:
		_market_payment_warning_popup.hide()


func _setup_time_panel_click() -> void:
	var align: CenterContainer = time_panel.get_node("AlignCenter") as CenterContainer
	align.custom_minimum_size = Vector2(360.0, 40.0)
	align.mouse_filter = Control.MOUSE_FILTER_STOP
	if not align.gui_input.is_connected(_on_time_panel_gui_input):
		align.gui_input.connect(_on_time_panel_gui_input)


func _create_hours_scroll_row(
	label_text: String,
	up_handler: Callable,
	down_handler: Callable,
	is_open_row: bool
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var caption := Label.new()
	caption.text = label_text
	caption.custom_minimum_size = Vector2(28.0, 0.0)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)

	var up_button := _create_time_control_button("▲")
	up_button.custom_minimum_size = Vector2(32.0, 28.0)
	up_button.pressed.connect(up_handler)
	row.add_child(up_button)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(52.0, 28.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value_label)

	var down_button := _create_time_control_button("▼")
	down_button.custom_minimum_size = Vector2(32.0, 28.0)
	down_button.pressed.connect(down_handler)
	row.add_child(down_button)

	if is_open_row:
		_hours_open_value_label = value_label
	else:
		_hours_close_value_label = value_label
	return row


func _build_food_display() -> void:
	var food_row := HBoxContainer.new()
	food_row.name = "FoodRow"
	food_row.alignment = BoxContainer.ALIGNMENT_CENTER
	food_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	food_row.add_theme_constant_override("separation", 6)
	top_bar_hbox.add_child(food_row)

	var food_icon := HudFoodIcon.new()
	food_icon.custom_minimum_size = Vector2(22.0, 22.0)
	food_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	food_row.add_child(food_icon)

	_food_label = Label.new()
	_food_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	food_row.add_child(_food_label)
	_update_food_label()


func _build_market_ui() -> void:
	_market_button = Button.new()
	_market_button.name = "MarketButton"
	_market_button.text = "시장"
	_market_button.focus_mode = Control.FOCUS_NONE
	_market_button.custom_minimum_size = Vector2(72.0, 36.0)
	_market_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_market_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_market_button.offset_left = 16.0
	_market_button.offset_top = -56.0
	_market_button.offset_right = 88.0
	_market_button.offset_bottom = -20.0
	_market_button.pressed.connect(_on_market_button_pressed)
	add_child(_market_button)

	_market_popup = PanelContainer.new()
	_market_popup.name = "MarketPopup"
	_market_popup.z_index = 10
	_market_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_market_popup.set_anchors_preset(Control.PRESET_CENTER)
	_market_popup.offset_left = -190.0
	_market_popup.offset_top = -118.0
	_market_popup.offset_right = 190.0
	_market_popup.offset_bottom = 118.0
	_market_popup.add_theme_stylebox_override("panel", _make_time_control_panel_style())
	_market_popup.hide()
	add_child(_market_popup)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_market_popup.add_child(margin)

	var root_column := VBoxContainer.new()
	root_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_column.add_theme_constant_override("separation", 0)
	margin.add_child(root_column)

	_market_shop_panel = _build_market_shop_panel()
	root_column.add_child(_market_shop_panel)

	_market_orders_panel = _build_market_orders_panel()
	_market_orders_panel.hide()
	root_column.add_child(_market_orders_panel)

	_update_market_labels()


func _build_furniture_panel() -> void:
	_furniture_panel = PanelContainer.new()
	_furniture_panel.name = "FurniturePanel"
	_furniture_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furniture_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_furniture_panel.offset_left = 16.0
	_furniture_panel.offset_top = -184.0
	_furniture_panel.offset_right = 288.0
	_furniture_panel.offset_bottom = -64.0
	_furniture_panel.add_theme_stylebox_override("panel", _make_time_control_panel_style())
	add_child(_furniture_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 7)
	_furniture_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	_furniture_title_label = Label.new()
	_furniture_title_label.text = "가구"
	column.add_child(_furniture_title_label)

	_furniture_detail_label = Label.new()
	_furniture_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_furniture_detail_label.text = ""
	column.add_child(_furniture_detail_label)

	_furniture_panel.hide()


func _build_market_shop_panel() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "시장"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	var item_label := Label.new()
	item_label.text = "곡물 · 영업 시작 시 결제 및 배송"
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 11)
	item_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60, 1.0))
	column.add_child(item_label)

	var amount_row := HBoxContainer.new()
	amount_row.alignment = BoxContainer.ALIGNMENT_CENTER
	amount_row.add_theme_constant_override("separation", 8)
	column.add_child(amount_row)

	var minus_button := Button.new()
	minus_button.text = "-10"
	minus_button.focus_mode = Control.FOCUS_NONE
	minus_button.custom_minimum_size = Vector2(54.0, 30.0)
	minus_button.pressed.connect(_on_market_minus_pressed)
	amount_row.add_child(minus_button)

	_market_amount_label = Label.new()
	_market_amount_label.custom_minimum_size = Vector2(96.0, 30.0)
	_market_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_row.add_child(_market_amount_label)

	var plus_button := Button.new()
	plus_button.text = "+10"
	plus_button.focus_mode = Control.FOCUS_NONE
	plus_button.custom_minimum_size = Vector2(54.0, 30.0)
	plus_button.pressed.connect(_on_market_plus_pressed)
	amount_row.add_child(plus_button)

	_market_price_label = Label.new()
	_market_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_market_price_label)

	_market_pending_label = Label.new()
	_market_pending_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_pending_label.add_theme_font_size_override("font_size", 11)
	_market_pending_label.add_theme_color_override("font_color", Color(0.78, 0.72, 0.55, 1.0))
	_market_pending_label.hide()
	column.add_child(_market_pending_label)

	var orders_button := Button.new()
	orders_button.text = "주문내역"
	orders_button.focus_mode = Control.FOCUS_NONE
	orders_button.custom_minimum_size = Vector2(0.0, 30.0)
	orders_button.pressed.connect(_show_market_orders_view)
	column.add_child(orders_button)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	column.add_child(action_row)

	var cancel_button := Button.new()
	cancel_button.text = "닫기"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.custom_minimum_size = Vector2(72.0, 32.0)
	cancel_button.pressed.connect(_close_market_popup)
	action_row.add_child(cancel_button)

	_market_accept_button = Button.new()
	_market_accept_button.text = "주문"
	_market_accept_button.focus_mode = Control.FOCUS_NONE
	_market_accept_button.custom_minimum_size = Vector2(72.0, 32.0)
	_market_accept_button.pressed.connect(_on_market_accept_pressed)
	action_row.add_child(_market_accept_button)

	return column


func _build_market_orders_panel() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "주문 내역"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 150.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_market_orders_list = VBoxContainer.new()
	_market_orders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_orders_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_market_orders_list)

	_market_orders_empty_label = Label.new()
	_market_orders_empty_label.text = "예약 중인 주문이 없습니다."
	_market_orders_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_market_orders_empty_label.add_theme_font_size_override("font_size", 12)
	_market_orders_empty_label.add_theme_color_override("font_color", Color(0.68, 0.64, 0.58, 1.0))
	column.add_child(_market_orders_empty_label)

	var back_button := Button.new()
	back_button.text = "뒤로"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.custom_minimum_size = Vector2(0.0, 32.0)
	back_button.pressed.connect(_show_market_shop_view)
	column.add_child(back_button)

	return column


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
	for interactive_class: String in interactive_classes:
		if control.is_class(interactive_class):
			return true
	return false


func _build_view_tabs() -> void:
	for view_id: ViewIds.Id in [ViewIds.Id.OUTSIDE, ViewIds.Id.INN_F1, ViewIds.Id.INN_F2]:
		var button := Button.new()
		button.text = _short_view_label(view_id)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(44, 32)
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(_on_view_tab_pressed.bind(view_id))
		view_tabs.add_child(button)
	_update_view_tab_states(ViewManager.current_view_id)


func _short_view_label(view_id: ViewIds.Id) -> String:
	match view_id:
		ViewIds.Id.OUTSIDE:
			return "야외"
		ViewIds.Id.INN_F1:
			return "1층"
		ViewIds.Id.INN_F2:
			return "2층"
		_:
			return ViewIds.label_for(view_id)


func _refresh_all() -> void:
	_update_day_label()
	_update_time_labels()
	_update_business_hours_panel()
	_update_start_open_button()
	_update_time_control_buttons()
	_refresh_economy()
	_update_food_label()
	_update_guests_label()
	_update_queue_summary_label()
	_update_customer_panel(CustomerService.selected_customer)
	_update_view_tab_states(ViewManager.current_view_id)


func _update_day_label() -> void:
	day_label.text = "%s · %s" % [
		GameTimeManager.get_calendar_label(),
		GameTimeManager.get_service_status_label(),
	]


func _update_time_labels() -> void:
	if GameTimeManager.is_pre_open():
		time_label.text = "%s 예정" % GameClock.format_hour(GameClock.active_open_hour)
		return
	if GameTimeManager.phase not in [GamePhases.Id.OPEN, GamePhases.Id.CLOSING]:
		time_label.text = "--:--"
		return
	if GameTimeManager.time_paused:
		time_label.text = "⏸ %s" % GameClock.get_time_label()
		return
	if GameTimeManager.phase == GamePhases.Id.CLOSING:
		time_label.text = "%s · 마감" % GameClock.get_time_label()
		return
	time_label.text = "%s · %.0fx" % [GameClock.get_time_label(), GameTimeManager.time_scale]


func _should_refresh_time_hud() -> bool:
	return (
		GameTimeManager.is_simulation_active()
		or GameTimeManager.phase in [GamePhases.Id.OPEN, GamePhases.Id.CLOSING]
	)


func _update_business_hours_panel() -> void:
	if _hours_current_label == null:
		return
	_hours_current_label.text = "현재 영업 %s" % GameClock.get_hours_label()
	var scheduled_label: String = GameClock.get_scheduled_hours_label()
	if scheduled_label == GameClock.get_hours_label():
		_hours_scheduled_label.text = "내일 적용 %s" % scheduled_label
	else:
		_hours_scheduled_label.text = "내일 적용 %s (변경됨)" % scheduled_label
	if _hours_open_value_label != null:
		_hours_open_value_label.text = GameClock.format_hour(GameClock.scheduled_open_hour)
	if _hours_close_value_label != null:
		_hours_close_value_label.text = GameClock.format_hour(GameClock.scheduled_close_hour)
	if _end_service_button != null:
		_end_service_button.visible = GameTimeManager.phase == GamePhases.Id.OPEN
		_end_service_button.disabled = GameTimeManager.phase != GamePhases.Id.OPEN


func _toggle_business_hours_panel() -> void:
	_business_hours_open = not _business_hours_open
	if _business_hours_panel != null:
		_business_hours_panel.visible = _business_hours_open
	if _business_hours_open:
		_close_market_popup()
		_update_business_hours_panel()


func _close_business_hours_panel() -> void:
	_business_hours_open = false
	if _business_hours_panel != null:
		_business_hours_panel.hide()


func _update_time_control_buttons() -> void:
	if _time_control_panel == null:
		return
	var show_controls: bool = GameTimeManager.phase in [
		GamePhases.Id.OPEN,
		GamePhases.Id.CLOSING,
	]
	_time_control_panel.visible = show_controls
	if not show_controls:
		return
	_speed_1x_button.disabled = not GameTimeManager.time_paused and is_equal_approx(GameTimeManager.time_scale, 1.0)
	_speed_2x_button.disabled = not GameTimeManager.time_paused and is_equal_approx(GameTimeManager.time_scale, 2.0)
	_speed_3x_button.disabled = not GameTimeManager.time_paused and is_equal_approx(GameTimeManager.time_scale, 3.0)
	_pause_button.disabled = GameTimeManager.time_paused
	_pause_button.text = "정지"


func _refresh_economy(_unused = null) -> void:
	gold_label.text = str(EconomyManager.gold)
	var rating_10: float = ReputationManager.average_rating * 2.0
	star_rating.set_rating(rating_10)
	rating_label.text = "%.2f/10" % rating_10
	_update_market_labels()


func _update_food_label() -> void:
	if _food_label == null:
		return
	var text: String = str(FoodStorage.food)
	if MarketService.pending_grain > 0:
		text += " (+%d)" % MarketService.pending_grain
	_food_label.text = text


func _update_market_labels() -> void:
	if _market_amount_label == null or _market_price_label == null:
		return
	var total_price: int = _get_market_total_price()
	_market_amount_label.text = "곡물 %d" % _market_grain_amount
	_market_price_label.text = "%d개당 %d골드 · 주문 %d골드" % [
		MarketConstants.GRAIN_BATCH_SIZE,
		MarketConstants.GRAIN_BATCH_PRICE,
		total_price,
	]
	if _market_pending_label != null:
		if MarketService.pending_grain > 0:
			_market_pending_label.text = (
				"배송 예정: 곡물 %d (결제 %d골드)"
				% [MarketService.pending_grain, MarketService.get_pending_cost()]
			)
			_market_pending_label.show()
		else:
			_market_pending_label.hide()
	if _market_accept_button != null:
		_market_accept_button.disabled = false


func _get_market_total_price() -> int:
	return MarketService.get_order_price(_market_grain_amount)


func _update_guests_label() -> void:
	guests_label.text = str(CustomerService.get_active_count())


func _update_queue_summary_label() -> void:
	if _queue_summary_label == null:
		return
	if not _should_refresh_time_hud():
		_queue_summary_label.text = ""
		return
	_queue_summary_label.text = CustomerService.get_player_queue_summary()


func _update_furniture_panel(instance: FurnitureInstance) -> void:
	if instance == null:
		if _furniture_panel:
			_furniture_panel.hide()
		return
	if _furniture_panel:
		_furniture_panel.show()
	customer_panel.hide()
	_furniture_title_label.text = FurnitureInfoHelper.get_panel_title(instance)
	_furniture_detail_label.text = FurnitureInfoHelper.get_panel_text(instance)


func _update_customer_panel(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		if (
			(StaffService.selected_staff == null or not is_instance_valid(StaffService.selected_staff))
			and (TableFoodService.selected_food == null or not is_instance_valid(TableFoodService.selected_food))
			and FurnitureService.get_selected_instance() == null
		):
			customer_panel.hide()
		return
	customer_panel.show()
	if _furniture_panel:
		_furniture_panel.hide()
	customer_title_label.text = customer.get_panel_title()
	customer_detail_label.text = customer.get_status_panel_text()


func _update_staff_panel(staff: InnkeeperEntity) -> void:
	if staff == null or not is_instance_valid(staff):
		if (
			(CustomerService.selected_customer == null or not is_instance_valid(CustomerService.selected_customer))
			and (TableFoodService.selected_food == null or not is_instance_valid(TableFoodService.selected_food))
			and FurnitureService.get_selected_instance() == null
		):
			customer_panel.hide()
		return
	customer_panel.show()
	if _furniture_panel:
		_furniture_panel.hide()
	customer_title_label.text = "여관주인"
	customer_detail_label.text = staff.get_status_panel_text()


func _update_food_panel(food: TableFoodVisual) -> void:
	if food == null or not is_instance_valid(food):
		if (
			(CustomerService.selected_customer == null or not is_instance_valid(CustomerService.selected_customer))
			and (StaffService.selected_staff == null or not is_instance_valid(StaffService.selected_staff))
			and FurnitureService.get_selected_instance() == null
		):
			customer_panel.hide()
		return
	customer_panel.show()
	if _furniture_panel:
		_furniture_panel.hide()
	customer_title_label.text = food.get_status_panel_title()
	customer_detail_label.text = food.get_status_panel_text()


func _update_view_tab_states(view_id: ViewIds.Id) -> void:
	var tab_index: int = 0
	for child: Node in view_tabs.get_children():
		if child is Button:
			var button := child as Button
			var bound_id: ViewIds.Id = [ViewIds.Id.OUTSIDE, ViewIds.Id.INN_F1, ViewIds.Id.INN_F2][tab_index]
			button.disabled = bound_id == view_id
			tab_index += 1


func _show_notice(text: String) -> void:
	notice_label.text = text
	notice_label.show()
	_notice_timer = NOTICE_DURATION


func _show_build_cost_text(view_id: ViewIds.Id, world_position: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var view: ViewRoot = ViewManager.get_view(view_id)
	if view == null:
		return
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return

	var label := Label.new()
	label.text = "-%d" % amount
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var global_world_position: Vector2 = view.global_position + world_position
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * global_world_position
	label.position = screen_position + Vector2(-32.0, -34.0)
	label.custom_minimum_size = Vector2(64.0, 18.0)
	label.z_index = 120
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.18, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.finished.connect(label.queue_free)


func _on_view_tab_pressed(view_id: ViewIds.Id) -> void:
	ViewManager.switch_to(view_id)


func _on_view_changed(_previous_view_id: ViewIds.Id, next_view_id: ViewIds.Id) -> void:
	_update_view_tab_states(next_view_id)


func _on_build_cost_spent(view_id: ViewIds.Id, world_position: Vector2, amount: int) -> void:
	_show_build_cost_text(view_id, world_position, amount)


func _on_game_time_pause_changed(_paused: bool) -> void:
	_update_time_labels()
	_update_time_control_buttons()


func _on_game_time_speed_changed(_speed: float) -> void:
	_update_time_labels()
	_update_time_control_buttons()


func _on_food_changed(_amount: int) -> void:
	_update_food_label()


func _on_game_hour_changed(_hour: float) -> void:
	_update_day_label()
	_update_time_labels()
	_update_business_hours_panel()


func _on_service_phase_changed(_previous_phase: GamePhases.Id, next_phase: GamePhases.Id) -> void:
	if next_phase != GamePhases.Id.PRE_OPEN:
		_market_payment_warning_dismissed = false
		_close_market_payment_warning()
	_update_day_label()
	_update_time_labels()
	_update_business_hours_panel()
	_update_start_open_button()
	_update_time_control_buttons()


func _on_business_hours_changed() -> void:
	_update_business_hours_panel()


func _on_time_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_business_hours_panel()
			get_viewport().set_input_as_handled()


func _on_open_hour_up_pressed() -> void:
	if GameClock.adjust_scheduled_open(1):
		_update_business_hours_panel()


func _on_open_hour_down_pressed() -> void:
	if GameClock.adjust_scheduled_open(-1):
		_update_business_hours_panel()


func _on_close_hour_up_pressed() -> void:
	if GameClock.adjust_scheduled_close(1):
		_update_business_hours_panel()


func _on_close_hour_down_pressed() -> void:
	if GameClock.adjust_scheduled_close(-1):
		_update_business_hours_panel()


func _on_end_service_pressed() -> void:
	if GameTimeManager.phase != GamePhases.Id.OPEN:
		return
	_close_business_hours_panel()
	GameTimeManager.end_day()


func _on_day_changed(_unused = null, _unused2 = null) -> void:
	_close_business_hours_panel()
	_refresh_all()


func _on_game_over(_reason: String) -> void:
	_refresh_all()
	_show_notice(_reason)


func _on_customer_spawned(customer: CustomerEntity) -> void:
	_on_customer_activity_changed()
	if is_instance_valid(customer) and not customer.finished.is_connected(_on_customer_finished):
		customer.finished.connect(_on_customer_finished)


func _on_customer_finished(_customer: CustomerEntity) -> void:
	_on_customer_activity_changed()
	_update_customer_panel(CustomerService.selected_customer)


func _on_customer_activity_changed(_unused = null) -> void:
	_update_guests_label()
	_update_queue_summary_label()


func _on_customer_selected(customer: CustomerEntity) -> void:
	_update_customer_panel(customer)


func _on_staff_selected(staff: InnkeeperEntity) -> void:
	_update_staff_panel(staff)


func _on_furniture_selected(instance: FurnitureInstance) -> void:
	_update_furniture_panel(instance)


func _on_customer_order_rejected(customer: CustomerEntity, reason: String) -> void:
	var customer_label: String = CustomerService.get_customer_display_label(customer)
	_show_notice("%s 퇴장: %s" % [customer_label, reason])


func _on_group_outside_wait_notice(
	group_size: int,
	outside_wait_count: int,
	leader_label: String
) -> void:
	_show_notice(
		"%s · %d인 일행 중 %d명 야외 대기" % [leader_label, group_size, outside_wait_count]
	)
	_update_queue_summary_label()


func _on_customer_reviewed(_customer: CustomerEntity, rating: float, comment: String) -> void:
	_update_guests_label()
	_show_notice("리뷰 %.1f — %s" % [rating, comment])


func _on_speed_1x_pressed() -> void:
	GameTimeManager.set_time_scale(1.0)


func _on_speed_2x_pressed() -> void:
	GameTimeManager.set_time_scale(2.0)

func _on_speed_3x_pressed() -> void:
	GameTimeManager.set_time_scale(3.0)


func _on_pause_pressed() -> void:
	GameTimeManager.set_time_paused(true)


func _on_market_button_pressed() -> void:
	_close_business_hours_panel()
	_market_grain_amount = MarketConstants.GRAIN_BATCH_SIZE
	_editing_order_id = -1
	_show_market_shop_view()
	_update_market_labels()
	_market_popup.show()


func _show_market_shop_view() -> void:
	_editing_order_id = -1
	if _market_shop_panel != null:
		_market_shop_panel.show()
	if _market_orders_panel != null:
		_market_orders_panel.hide()
	if _market_popup != null:
		_market_popup.offset_top = -118.0
		_market_popup.offset_bottom = 118.0
	_update_market_labels()


func _show_market_orders_view() -> void:
	_editing_order_id = -1
	if _market_shop_panel != null:
		_market_shop_panel.hide()
	if _market_orders_panel != null:
		_market_orders_panel.show()
	if _market_popup != null:
		_market_popup.offset_top = -168.0
		_market_popup.offset_bottom = 168.0
	_refresh_market_orders_list()


func _refresh_market_orders_list() -> void:
	if _market_orders_list == null:
		return
	for child: Node in _market_orders_list.get_children():
		child.queue_free()
	var orders: Array[Dictionary] = MarketService.get_pending_orders()
	if _market_orders_empty_label != null:
		_market_orders_empty_label.visible = orders.is_empty()
	for order: Dictionary in orders:
		var order_id: int = int(order.get("id", -1))
		var grain: int = int(order.get("grain", 0))
		if order_id < 0 or grain <= 0:
			continue
		if order_id == _editing_order_id:
			_market_orders_list.add_child(_create_market_order_edit_row(order_id, _editing_order_amount))
		else:
			_market_orders_list.add_child(_create_market_order_view_row(order_id, grain))


func _create_market_order_view_row(order_id: int, grain: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var info := Label.new()
	info.text = "곡물 %d · %d골드" % [grain, MarketService.get_order_price(grain)]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(info)

	var edit_button := Button.new()
	edit_button.text = "✎"
	edit_button.focus_mode = Control.FOCUS_NONE
	edit_button.custom_minimum_size = Vector2(32.0, 28.0)
	edit_button.pressed.connect(_on_market_order_edit_pressed.bind(order_id, grain))
	row.add_child(edit_button)

	var cancel_button := Button.new()
	cancel_button.text = "✕"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.custom_minimum_size = Vector2(32.0, 28.0)
	cancel_button.pressed.connect(_on_market_order_cancel_pressed.bind(order_id))
	row.add_child(cancel_button)

	return row


func _create_market_order_edit_row(order_id: int, grain: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var minus_button := Button.new()
	minus_button.text = "-10"
	minus_button.focus_mode = Control.FOCUS_NONE
	minus_button.custom_minimum_size = Vector2(44.0, 28.0)
	minus_button.pressed.connect(_on_market_order_edit_minus_pressed.bind(order_id))
	row.add_child(minus_button)

	var amount_label := Label.new()
	amount_label.text = "곡물 %d" % grain
	amount_label.custom_minimum_size = Vector2(88.0, 28.0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(amount_label)

	var plus_button := Button.new()
	plus_button.text = "+10"
	plus_button.focus_mode = Control.FOCUS_NONE
	plus_button.custom_minimum_size = Vector2(44.0, 28.0)
	plus_button.pressed.connect(_on_market_order_edit_plus_pressed.bind(order_id))
	row.add_child(plus_button)

	var save_button := Button.new()
	save_button.text = "저장"
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.custom_minimum_size = Vector2(44.0, 28.0)
	save_button.pressed.connect(_on_market_order_edit_save_pressed.bind(order_id))
	row.add_child(save_button)

	return row


func _on_market_order_edit_pressed(order_id: int, grain: int) -> void:
	_editing_order_id = order_id
	_editing_order_amount = grain
	_refresh_market_orders_list()


func _on_market_order_edit_minus_pressed(order_id: int) -> void:
	if order_id != _editing_order_id:
		return
	_editing_order_amount = maxi(
		MarketConstants.GRAIN_BATCH_SIZE,
		_editing_order_amount - MarketConstants.GRAIN_BATCH_SIZE
	)
	_refresh_market_orders_list()


func _on_market_order_edit_plus_pressed(order_id: int) -> void:
	if order_id != _editing_order_id:
		return
	_editing_order_amount += MarketConstants.GRAIN_BATCH_SIZE
	_refresh_market_orders_list()


func _on_market_order_edit_save_pressed(order_id: int) -> void:
	if order_id != _editing_order_id:
		return
	if not MarketService.update_order(order_id, _editing_order_amount):
		return
	_editing_order_id = -1
	_show_notice("주문 수량이 변경되었습니다.")
	_refresh_market_orders_list()
	_update_market_labels()
	if GameTimeManager.is_pre_open() and MarketService.has_unaffordable_pending():
		_market_payment_warning_dismissed = false
		_try_show_market_payment_warning()


func _on_market_order_cancel_pressed(order_id: int) -> void:
	if _editing_order_id == order_id:
		_editing_order_id = -1
	MarketService.cancel_order(order_id)


func _close_market_popup() -> void:
	_editing_order_id = -1
	_show_market_shop_view()
	if _market_popup != null:
		_market_popup.hide()


func _on_market_minus_pressed() -> void:
	_market_grain_amount = maxi(
		MarketConstants.GRAIN_BATCH_SIZE,
		_market_grain_amount - MarketConstants.GRAIN_BATCH_SIZE
	)
	_update_market_labels()


func _on_market_plus_pressed() -> void:
	_market_grain_amount += MarketConstants.GRAIN_BATCH_SIZE
	_update_market_labels()


func _on_market_accept_pressed() -> void:
	if not MarketService.place_grain_order(_market_grain_amount):
		return
	_show_notice("곡물 %d개 주문 · 영업 시작 시 결제 및 배송" % _market_grain_amount)
	_update_food_label()
	_update_market_labels()
	_close_market_popup()
	if GameTimeManager.is_pre_open() and MarketService.has_unaffordable_pending():
		_market_payment_warning_dismissed = false
		_try_show_market_payment_warning()


func _on_market_pending_changed(_pending_grain: int) -> void:
	_update_food_label()
	_update_market_labels()
	if _market_orders_panel != null and _market_orders_panel.visible:
		_refresh_market_orders_list()


func _on_market_delivered(amount: int) -> void:
	if amount <= 0:
		return
	_update_food_label()
	_show_notice("곡물 %d개가 배송되었습니다." % amount)


func _on_market_orders_cancelled(cancelled_grain: int, reason: String) -> void:
	if cancelled_grain <= 0:
		return
	_editing_order_id = -1
	_update_food_label()
	_update_market_labels()
	if _market_orders_panel != null and _market_orders_panel.visible:
		_refresh_market_orders_list()
	if reason == "manual":
		_show_notice("시장 예약 %d개가 취소되었습니다." % cancelled_grain)
	else:
		_show_notice("골드 부족으로 시장 예약 %d개가 취소되었습니다." % cancelled_grain)
