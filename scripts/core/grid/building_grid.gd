class_name BuildingGrid
extends RefCounted

var view_id: ViewIds.Id
var _cells: Dictionary = {}


func _init(p_view_id: ViewIds.Id) -> void:
	view_id = p_view_id


func is_in_bounds(coord: GridCoord) -> bool:
	return (
		coord.view_id == view_id
		and coord.x >= 0
		and coord.y >= 0
		and coord.x < GameConstants.GRID_VISUAL_SIZE.x
		and coord.y < GameConstants.GRID_VISUAL_SIZE.y
	)


func set_cell(coord: GridCoord, cell: CellData) -> void:
	if coord.view_id != view_id:
		push_warning("BuildingGrid: coord view mismatch.")
		return
	if cell.is_empty():
		remove_cell(coord)
		return
	_cells[coord.to_key()] = cell.duplicate_cell()


func remove_cell(coord: GridCoord) -> void:
	_cells.erase(coord.to_key())


func get_cell(coord: GridCoord) -> CellData:
	var key: String = coord.to_key()
	if _cells.has(key):
		return (_cells[key] as CellData).duplicate_cell()
	return CellData.new()


func has_cell(coord: GridCoord) -> bool:
	return _cells.has(coord.to_key())


func has_any_owned() -> bool:
	for key: String in _cells.keys():
		if (_cells[key] as CellData).is_owned:
			return true
	return false


func has_adjacent_owned(coord: GridCoord) -> bool:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]
	for offset: Vector2i in offsets:
		var neighbor := GridCoord.new(coord.x + offset.x, coord.y + offset.y, view_id)
		if get_cell(neighbor).is_owned:
			return true
	return false


func can_expand_to(coord: GridCoord, tile_type: CellData.TileType) -> bool:
	if not is_in_bounds(coord):
		return false
	if tile_type == CellData.TileType.EMPTY:
		return has_cell(coord)
	if not can_build(coord):
		return false
	if not has_any_owned():
		return true
	return has_adjacent_owned(coord)


func is_walkable(coord: GridCoord) -> bool:
	if not is_in_bounds(coord):
		return false
	return get_cell(coord).is_walkable


func can_build(coord: GridCoord) -> bool:
	if not is_in_bounds(coord):
		return false
	var cell: CellData = get_cell(coord)
	if GridLayoutRules.is_inn_interior(coord) and cell.tile_type == CellData.TileType.WALL:
		return true
	return cell.is_buildable or cell.is_empty()


func set_tile_type(coord: GridCoord, tile_type: CellData.TileType) -> void:
	set_cell(coord, CellData.create_for_type(tile_type))


func clear() -> void:
	_cells.clear()


func get_all_coords() -> Array[GridCoord]:
	var coords: Array[GridCoord] = []
	for key: String in _cells.keys():
		coords.append(GridCoord.from_key(key))
	return coords


func to_dict() -> Dictionary:
	var cells_dict: Dictionary = {}
	for key: String in _cells.keys():
		cells_dict[key] = (_cells[key] as CellData).to_dict()
	return {
		"view_id": view_id,
		"cells": cells_dict,
	}


static func from_dict(data: Dictionary) -> BuildingGrid:
	var grid := BuildingGrid.new(data.get("view_id", ViewIds.Id.OUTSIDE))
	var cells: Dictionary = data.get("cells", {})
	for key: String in cells.keys():
		grid._cells[key] = CellData.from_dict(cells[key])
	return grid
