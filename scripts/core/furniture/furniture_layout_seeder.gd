class_name FurnitureLayoutSeeder
extends RefCounted

const _PLACEMENTS: Array[Dictionary] = [
	{"view_id": ViewIds.Id.INN_F1, "def_id": "owner_bed", "x": 2, "y": 2, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "counter", "x": 8, "y": 12, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "table", "x": 14, "y": 9, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "chair", "x": 14, "y": 10, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "chair", "x": 15, "y": 10, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "bed", "x": 17, "y": 5, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "bed", "x": 20, "y": 5, "rotation": 0},
	{"view_id": ViewIds.Id.INN_F1, "def_id": "barrel", "x": 6, "y": 14, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "hearth", "x": 4, "y": 9, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "prep_table", "x": 8, "y": 9, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "cauldron", "x": 12, "y": 9, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "bread_oven", "x": 14, "y": 11, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "pantry_shelf", "x": 4, "y": 12, "rotation": 0},
	{"view_id": ViewIds.Id.INN_BASEMENT, "def_id": "pot_rack", "x": 8, "y": 12, "rotation": 0},
]


static func seed_defaults() -> void:
	for entry: Dictionary in _PLACEMENTS:
		_try_place(entry)


static func _try_place(entry: Dictionary) -> void:
	var view_id: ViewIds.Id = entry.get("view_id", ViewIds.Id.INN_F1) as ViewIds.Id
	var def_id: String = entry.get("def_id", "") as String
	var rotation: int = entry.get("rotation", 0) as int
	if def_id.is_empty():
		return
	var origin := GridCoord.new(
		entry.get("x", 0) as int,
		entry.get("y", 0) as int,
		view_id
	)
	if FurnitureService.can_place(origin, def_id, rotation):
		FurnitureService.place_furniture(origin, def_id, rotation)
