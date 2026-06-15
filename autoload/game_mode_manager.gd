extends Node

var current_mode: GameModes.Id = GameModes.Id.PLAY


func _ready() -> void:
	set_mode(GameModes.Id.PLAY, false)


func set_mode(mode: GameModes.Id, emit_signal: bool = true) -> void:
	if mode == current_mode and emit_signal:
		return
	var previous_mode: GameModes.Id = current_mode
	current_mode = mode
	if emit_signal:
		EventBus.game_mode_changed.emit(previous_mode, current_mode)


func cycle_mode() -> void:
	match current_mode:
		GameModes.Id.PLAY:
			set_mode(GameModes.Id.BUILD)
		GameModes.Id.BUILD:
			set_mode(GameModes.Id.FURNITURE)
		GameModes.Id.FURNITURE:
			set_mode(GameModes.Id.PLAY)


func toggle_mode() -> void:
	if current_mode == GameModes.Id.PLAY:
		set_mode(GameModes.Id.BUILD)
	elif current_mode == GameModes.Id.BUILD:
		set_mode(GameModes.Id.PLAY)
	else:
		set_mode(GameModes.Id.PLAY)


func enter_furniture_mode() -> void:
	set_mode(GameModes.Id.FURNITURE)


func is_build_mode() -> bool:
	return current_mode == GameModes.Id.BUILD


func is_furniture_mode() -> bool:
	return current_mode == GameModes.Id.FURNITURE


func is_play_mode() -> bool:
	return current_mode == GameModes.Id.PLAY
