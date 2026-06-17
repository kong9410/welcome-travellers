extends Node2D

@onready var world_root: Node2D = $WorldRoot
@onready var transition_overlay: ViewTransitionOverlay = $UI/ViewTransitionOverlay


func _ready() -> void:
	ViewManager.register_world_root(world_root)
	ViewManager.register_transition_overlay(transition_overlay)
	ViewManager.switch_to(ViewIds.Id.INN_F1)
	call_deferred("_bootstrap_world")


func _bootstrap_world() -> void:
	FurnitureService.refresh_all_visuals()
	NavService.rebuild_all_views()
	StaffService.ensure_innkeeper()
