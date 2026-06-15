extends Node2D

@onready var world_root: Node2D = $WorldRoot
@onready var transition_overlay: ViewTransitionOverlay = $UI/ViewTransitionOverlay


func _ready() -> void:
	ViewManager.register_world_root(world_root)
	ViewManager.register_transition_overlay(transition_overlay)
	ViewManager.switch_to(ViewIds.Id.OUTSIDE)
	call_deferred("_bootstrap_world")


func _bootstrap_world() -> void:
	FurnitureService.refresh_all_visuals()
	NavService.rebuild_all_views()
	StaffService.ensure_innkeeper()
	_show_initial_briefing()


func _show_initial_briefing() -> void:
	if GameTimeManager.is_briefing():
		GameTimeManager.request_morning_briefing()
