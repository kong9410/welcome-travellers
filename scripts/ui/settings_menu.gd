extends Control

@onready var continue_button: Button = $Panel/MarginContainer/VBox/ContinueButton
@onready var save_button: Button = $Panel/MarginContainer/VBox/SaveButton
@onready var load_button: Button = $Panel/MarginContainer/VBox/LoadButton
@onready var quit_button: Button = $Panel/MarginContainer/VBox/QuitButton
@onready var build_toolbar: Control = get_node("../BuildToolbar")


func _ready() -> void:
	add_to_group("settings_menu")
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func is_open() -> bool:
	return visible


func open_menu() -> void:
	if visible:
		return
	show()
	GameTimeManager.set_time_paused(true)


func _on_continue_pressed() -> void:
	_close_menu()


func _on_save_pressed() -> void:
	GridService.save_game()


func _on_load_pressed() -> void:
	GridService.load_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_menu() -> void:
	hide()
	if not _should_keep_paused():
		GameTimeManager.set_time_paused(false)


func _should_keep_paused() -> bool:
	if build_toolbar != null and build_toolbar.has_method("is_menu_open"):
		return build_toolbar.is_menu_open()
	return false
