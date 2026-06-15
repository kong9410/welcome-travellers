class_name GridLayoutRules
extends RefCounted

const _DoorKinds := preload("res://scripts/core/door/door_kinds.gd")

const OUTSIDE_BUILDING_ORIGIN := Vector2i(8, 5)
const OUTSIDE_BUILDING_SIZE := Vector2i(8, 7)
const DEFAULT_INN_DOOR := Vector2i(12, 17)
const OWNER_ROOM_ORIGIN := Vector2i(2, 2)
const OWNER_ROOM_SIZE := Vector2i(3, 2)


static func is_map_border(coord: GridCoord) -> bool:
	var size: Vector2i = GameConstants.GRID_VISUAL_SIZE
	return (
		coord.x == 0
		or coord.y == 0
		or coord.x == size.x - 1
		or coord.y == size.y - 1
	)


static func is_owner_room_cell(coord: GridCoord) -> bool:
	if coord.view_id != ViewIds.Id.INN_F1:
		return false
	var local := Vector2i(coord.x, coord.y) - OWNER_ROOM_ORIGIN
	return (
		local.x >= 0
		and local.y >= 0
		and local.x < OWNER_ROOM_SIZE.x
		and local.y < OWNER_ROOM_SIZE.y
	)


static func is_owner_room_locked(coord: GridCoord) -> bool:
	return is_owner_room_cell(coord)


static func is_inn_view(view_id: ViewIds.Id) -> bool:
	return view_id in [
		ViewIds.Id.INN_F1,
		ViewIds.Id.INN_F2,
		ViewIds.Id.INN_F3,
		ViewIds.Id.INN_BASEMENT,
	]


static func is_inn_perimeter(coord: GridCoord) -> bool:
	return is_inn_view(coord.view_id) and is_map_border(coord)


static func is_inn_interior(coord: GridCoord) -> bool:
	if not is_inn_view(coord.view_id):
		return false
	return not is_map_border(coord)


static func is_outside_building_rect(coord: GridCoord) -> bool:
	if coord.view_id != ViewIds.Id.OUTSIDE:
		return false
	var local := Vector2i(coord.x, coord.y) - OUTSIDE_BUILDING_ORIGIN
	return (
		local.x >= 0
		and local.y >= 0
		and local.x < OUTSIDE_BUILDING_SIZE.x
		and local.y < OUTSIDE_BUILDING_SIZE.y
	)


static func is_outside_building_wall(coord: GridCoord) -> bool:
	if not is_outside_building_rect(coord):
		return false
	var local := Vector2i(coord.x, coord.y) - OUTSIDE_BUILDING_ORIGIN
	var on_edge: bool = (
		local.x == 0
		or local.y == 0
		or local.x == OUTSIDE_BUILDING_SIZE.x - 1
		or local.y == OUTSIDE_BUILDING_SIZE.y - 1
	)
	if not on_edge:
		return false
	return not is_outside_building_door(coord)


static func is_outside_building_door(coord: GridCoord) -> bool:
	if coord.view_id != ViewIds.Id.OUTSIDE:
		return false
	var door_x: int = OUTSIDE_BUILDING_ORIGIN.x + OUTSIDE_BUILDING_SIZE.x / 2
	var door_y: int = OUTSIDE_BUILDING_ORIGIN.y + OUTSIDE_BUILDING_SIZE.y - 1
	return coord.x == door_x and coord.y == door_y


static func is_outside_building_interior(coord: GridCoord) -> bool:
	return is_outside_building_rect(coord) and not is_outside_building_wall(coord) and not is_outside_building_door(coord)


static func is_outside_locked(coord: GridCoord) -> bool:
	if coord.view_id != ViewIds.Id.OUTSIDE:
		return false
	if is_map_border(coord):
		return true
	if is_outside_building_wall(coord):
		return true
	if is_outside_building_door(coord):
		return true
	return false


static func blocks_build(coord: GridCoord) -> bool:
	if is_outside_locked(coord):
		return true
	if is_owner_room_locked(coord):
		return true
	if is_inn_perimeter(coord):
		return true
	return false


static func get_paint_block_reason(coord: GridCoord, tile_type: CellData.TileType) -> String:
	if is_outside_locked(coord):
		return "이 지형은 변경할 수 없습니다."

	if is_owner_room_locked(coord):
		return "주인 방은 변경할 수 없습니다."

	if is_inn_perimeter(coord):
		if coord.view_id == ViewIds.Id.INN_F1 and tile_type == CellData.TileType.DOOR:
			return ""
		return "외벽은 변경할 수 없습니다. 테두리에 입구 문을 칠해 입구를 옮기세요."

	if tile_type == CellData.TileType.DOOR:
		if coord.view_id == ViewIds.Id.INN_F1:
			return "입구 문은 여관 외벽(건설 모드)에 칠하세요."
		if coord.view_id != ViewIds.Id.OUTSIDE:
			return "입구 문은 건물 외벽 타일입니다. 내부 방문은 가구 모드에서 배치하세요."

	return ""


static func get_erase_block_reason(coord: GridCoord, cell: CellData) -> String:
	if is_outside_locked(coord):
		return "이 지형은 변경할 수 없습니다."

	if is_owner_room_locked(coord):
		return "주인 방은 변경할 수 없습니다."

	if is_inn_perimeter(coord):
		if cell.tile_type == CellData.TileType.DOOR:
			return "입구 문은 지울 수 없습니다. 다른 테두리 칸에 입구 문을 칠해 옮기세요."
		return "외벽은 변경할 수 없습니다."

	return ""


static func is_structural_door_cell(cell: CellData) -> bool:
	return _DoorKinds.is_structural_door_cell(cell)


static func get_interior_door_block_reason(origin: GridCoord, def_id: String) -> String:
	if not _DoorKinds.is_interior_door_def(def_id):
		return ""
	if not is_inn_view(origin.view_id):
		return "방문은 여관 내부에만 배치할 수 있습니다."
	if is_owner_room_cell(origin):
		return "주인 방은 변경할 수 없습니다."
	var cell: CellData = GridService.get_cell(origin)
	if cell.tile_type != CellData.TileType.FLOOR:
		return "방문은 벽 구멍의 바닥 타일에 배치하세요."
	if not _has_adjacent_wall(origin):
		return "방문은 벽 타일에 인접해야 합니다."
	return ""


static func _has_adjacent_wall(coord: GridCoord) -> bool:
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, coord.view_id)
		if GridService.get_cell(neighbor).tile_type == CellData.TileType.WALL:
			return true
	return false


static func default_inn_door_coord(view_id: ViewIds.Id = ViewIds.Id.INN_F1) -> GridCoord:
	return GridCoord.new(DEFAULT_INN_DOOR.x, DEFAULT_INN_DOOR.y, view_id)
