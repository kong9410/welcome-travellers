extends Node

var current_view_id: ViewIds.Id = ViewIds.Id.OUTSIDE

var _views: Dictionary = {}
var _world_root: Node2D
var _transition_overlay: ViewTransitionOverlay


func register_world_root(world_root: Node2D) -> void:
	_world_root = world_root
	_views.clear()
	for child: Node in world_root.get_children():
		if child is ViewRoot:
			var view: ViewRoot = child as ViewRoot
			_views[view.view_id] = view
			view.visible = false


func register_transition_overlay(overlay: ViewTransitionOverlay) -> void:
	_transition_overlay = overlay


func get_view(view_id: ViewIds.Id) -> ViewRoot:
	return _views.get(view_id)


func switch_to(view_id: ViewIds.Id) -> void:
	if not _views.has(view_id):
		push_warning("ViewManager: unregistered view %d" % view_id)
		return

	var active_view: ViewRoot = get_view(view_id)
	if view_id == current_view_id and active_view != null and active_view.visible:
		return

	if not _any_view_visible() or _transition_overlay == null or _transition_overlay.is_busy():
		_apply_view_switch(view_id)
		return

	_transition_overlay.play_transition(func() -> void:
		_apply_view_switch(view_id)
	)


func _any_view_visible() -> bool:
	for view: ViewRoot in _views.values():
		if view.visible:
			return true
	return false


func _apply_view_switch(view_id: ViewIds.Id) -> void:
	var previous_view_id: ViewIds.Id = current_view_id
	if previous_view_id != view_id:
		_set_view_visible(previous_view_id, false)
	current_view_id = view_id
	_set_view_visible(current_view_id, true)
	EventBus.view_changed.emit(previous_view_id, current_view_id)


func _set_view_visible(view_id: ViewIds.Id, is_visible: bool) -> void:
	var view: ViewRoot = get_view(view_id)
	if view:
		view.visible = is_visible
