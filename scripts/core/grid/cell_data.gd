class_name CellData
extends RefCounted

enum TileType {
	EMPTY,
	OUTSIDE_GROUND,
	FLOOR,
	WALL,
	DOOR,
	STAIRS_UP,
	STAIRS_DOWN,
}

const TYPE_LABELS: Dictionary = {
	TileType.EMPTY: "지우기",
	TileType.OUTSIDE_GROUND: "야외 바닥",
	TileType.FLOOR: "바닥",
	TileType.WALL: "벽",
	TileType.DOOR: "입구 문",
	TileType.STAIRS_UP: "위층 계단",
	TileType.STAIRS_DOWN: "아래층 계단",
}

static func debug_color_for(tile_type: TileType) -> Color:
	match tile_type:
		TileType.OUTSIDE_GROUND:
			return DarkFantasyPalette.outside_moss
		TileType.FLOOR:
			return DarkFantasyPalette.floor_wood
		TileType.WALL:
			return DarkFantasyPalette.wall_stone
		TileType.DOOR:
			return DarkFantasyPalette.door_oak
		TileType.STAIRS_UP:
			return DarkFantasyPalette.stairs_up
		TileType.STAIRS_DOWN:
			return DarkFantasyPalette.stairs_down
		_:
			return Color(1.0, 0.0, 1.0, 0.5)


var tile_type: TileType = TileType.EMPTY
var is_owned: bool = false
var is_walkable: bool = false
var is_buildable: bool = false


func _init(
	p_tile_type: TileType = TileType.EMPTY,
	p_is_owned: bool = false,
	p_is_walkable: bool = false,
	p_is_buildable: bool = false
) -> void:
	tile_type = p_tile_type
	is_owned = p_is_owned
	is_walkable = p_is_walkable
	is_buildable = p_is_buildable


static func label_for(tile_type: TileType) -> String:
	return TYPE_LABELS.get(tile_type, "Unknown")


static func create_for_type(tile_type: TileType) -> CellData:
	match tile_type:
		TileType.EMPTY:
			return CellData.new(TileType.EMPTY, false, false, true)
		TileType.OUTSIDE_GROUND:
			return CellData.new(TileType.OUTSIDE_GROUND, true, true, false)
		TileType.FLOOR:
			return CellData.new(TileType.FLOOR, true, true, false)
		TileType.WALL:
			return CellData.new(TileType.WALL, true, false, false)
		TileType.DOOR:
			return CellData.new(TileType.DOOR, true, true, false)
		TileType.STAIRS_UP:
			return CellData.new(TileType.STAIRS_UP, true, true, false)
		TileType.STAIRS_DOWN:
			return CellData.new(TileType.STAIRS_DOWN, true, true, false)
		_:
			return CellData.new()


static func paintable_types() -> Array[TileType]:
	var result: Array[TileType] = []
	for option: Dictionary in build_paint_options():
		result.append(option["tile_type"] as TileType)
	return result


static func build_paint_options() -> Array[Dictionary]:
	return [
		{"tile_type": TileType.FLOOR, "label": "바닥 (지형)"},
		{"tile_type": TileType.WALL, "label": "벽 (지형)"},
		{"tile_type": TileType.DOOR, "label": "입구 문 (외벽)"},
		{"tile_type": TileType.STAIRS_UP, "label": "위층 계단 (연결)"},
		{"tile_type": TileType.STAIRS_DOWN, "label": "아래층 계단 (연결)"},
		{"tile_type": TileType.EMPTY, "label": "지우기"},
	] as Array[Dictionary]


func duplicate_cell() -> CellData:
	return CellData.new(tile_type, is_owned, is_walkable, is_buildable)


func is_empty() -> bool:
	return tile_type == TileType.EMPTY


func to_dict() -> Dictionary:
	return {
		"tile_type": tile_type,
		"is_owned": is_owned,
		"is_walkable": is_walkable,
		"is_buildable": is_buildable,
	}


static func from_dict(data: Dictionary) -> CellData:
	return CellData.new(
		data.get("tile_type", TileType.EMPTY),
		data.get("is_owned", false),
		data.get("is_walkable", false),
		data.get("is_buildable", false)
	)
