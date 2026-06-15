extends Control

@onready var day_label: Label = $TimePanel/AlignCenter/CenterRow/DayLabel
@onready var gold_label: Label = $TopBar/MarginContainer/HBox/GoldRow/GoldLabel
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


func _ready() -> void:
	_apply_passthrough_mouse_filters()
	_build_view_tabs()
	_connect_signals()
	settings_button.settings_requested.connect(settings_menu.open_menu)
	_refresh_all()
	customer_panel.hide()
	notice_label.hide()


func _process(delta: float) -> void:
	if CustomerService.selected_customer != null and is_instance_valid(CustomerService.selected_customer):
		_update_customer_panel(CustomerService.selected_customer)

	if not GameTimeManager.is_running():
		return

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL
		_update_time_labels()

	if notice_label.visible:
		_notice_timer -= delta
		if _notice_timer <= 0.0:
			notice_label.hide()


func _connect_signals() -> void:
	EventBus.view_changed.connect(_on_view_changed)
	EventBus.game_time_pause_changed.connect(_on_game_time_pause_changed)
	EventBus.economy_changed.connect(_refresh_economy)
	EventBus.reputation_changed.connect(_refresh_economy)
	EventBus.day_started.connect(_on_day_changed)
	EventBus.day_ended.connect(_on_day_changed)
	EventBus.morning_briefing_requested.connect(_on_day_changed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.game_hour_changed.connect(_update_time_labels)
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_selected.connect(_on_customer_selected)
	EventBus.customer_reviewed.connect(_on_customer_reviewed)
	EventBus.furniture_placed.connect(_on_customer_activity_changed)
	EventBus.furniture_removed.connect(_on_customer_activity_changed)


func _apply_passthrough_mouse_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$TopBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$TimePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ViewSidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	customer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_ignore_recursive(self, ["Button"] as Array[String])


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
	_refresh_economy()
	_update_guests_label()
	_update_customer_panel(CustomerService.selected_customer)
	_update_view_tab_states(ViewManager.current_view_id)


func _update_day_label() -> void:
	var phase_text: String = GamePhases.label_for(GameTimeManager.phase)
	day_label.text = "%d일차 · %s" % [GameTimeManager.current_day, phase_text]


func _update_time_labels() -> void:
	if not GameTimeManager.is_running():
		time_label.text = "--:--"
		return
	if GameTimeManager.time_paused:
		time_label.text = "⏸ %s" % GameClock.get_time_label()
		return
	time_label.text = GameClock.get_time_label()


func _refresh_economy(_unused = null) -> void:
	gold_label.text = str(EconomyManager.gold)
	var rating_10: float = ReputationManager.average_rating * 2.0
	star_rating.set_rating(rating_10)
	rating_label.text = "%.2f/10" % rating_10


func _update_guests_label() -> void:
	guests_label.text = str(CustomerService.get_active_count())


func _update_customer_panel(customer: CustomerEntity) -> void:
	if customer == null or not is_instance_valid(customer):
		customer_panel.hide()
		return
	customer_panel.show()
	customer_title_label.text = customer.customer_id
	customer_detail_label.text = customer.get_status_panel_text()


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


func _on_view_tab_pressed(view_id: ViewIds.Id) -> void:
	ViewManager.switch_to(view_id)


func _on_view_changed(_previous_view_id: ViewIds.Id, next_view_id: ViewIds.Id) -> void:
	_update_view_tab_states(next_view_id)


func _on_game_time_pause_changed(_paused: bool) -> void:
	_update_time_labels()


func _on_day_changed(_unused = null) -> void:
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


func _on_customer_selected(customer: CustomerEntity) -> void:
	_update_customer_panel(customer)


func _on_customer_reviewed(_customer: CustomerEntity, rating: float, comment: String) -> void:
	_update_guests_label()
	_show_notice("리뷰 %.1f — %s" % [rating, comment])
