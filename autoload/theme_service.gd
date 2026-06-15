extends Node

const DEFAULT_THEME_ID := "rustic"

var _view_theme_ids: Dictionary = {}


func _ready() -> void:
	_reset_defaults()


func _reset_defaults() -> void:
	_view_theme_ids.clear()
	for view_id: ViewIds.Id in ViewIds.all():
		_view_theme_ids[view_id] = _default_theme_for_view(view_id)


func _default_theme_for_view(view_id: ViewIds.Id) -> String:
	if view_id == ViewIds.Id.INN_BASEMENT:
		return "cellar"
	return DEFAULT_THEME_ID


func get_theme_for_view(view_id: ViewIds.Id) -> InteriorTheme:
	var theme_id: String = _view_theme_ids.get(view_id, DEFAULT_THEME_ID)
	return InteriorThemeCatalog.get_theme(theme_id)


func get_theme_id_for_view(view_id: ViewIds.Id) -> String:
	return _view_theme_ids.get(view_id, DEFAULT_THEME_ID)


func set_theme_for_view(view_id: ViewIds.Id, theme_id: String) -> void:
	_view_theme_ids[view_id] = theme_id
	EventBus.view_theme_changed.emit(view_id, theme_id)


func reset_to_defaults() -> void:
	_reset_defaults()


func export_save_data() -> Dictionary:
	var themes: Dictionary = {}
	for view_id: ViewIds.Id in _view_theme_ids.keys():
		themes[str(view_id)] = _view_theme_ids[view_id]
	return themes


func import_save_data(data: Dictionary) -> void:
	_view_theme_ids.clear()
	for key: String in data.keys():
		var view_id: ViewIds.Id = int(key) as ViewIds.Id
		_view_theme_ids[view_id] = data[key]
	for view_id: ViewIds.Id in ViewIds.all():
		if not _view_theme_ids.has(view_id):
			_view_theme_ids[view_id] = _default_theme_for_view(view_id)
