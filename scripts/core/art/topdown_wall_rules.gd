class_name TopdownWallRules
extends RefCounted

const FLOOR_NORTH: int = 1 << 0
const FLOOR_SOUTH: int = 1 << 1
const FLOOR_WEST: int = 1 << 2
const FLOOR_EAST: int = 1 << 3
const FLOOR_NORTH_WEST: int = 1 << 4
const FLOOR_NORTH_EAST: int = 1 << 5
const FLOOR_SOUTH_WEST: int = 1 << 6
const FLOOR_SOUTH_EAST: int = 1 << 7


static func rule_for(coord, tile_type: CellData.TileType) -> Dictionary:
	if coord == null or not (coord is GridCoord):
		return _default_rule()

	var grid_coord: GridCoord = coord as GridCoord
	var north := GridCoord.new(grid_coord.x, grid_coord.y - 1, grid_coord.view_id)
	var south := GridCoord.new(grid_coord.x, grid_coord.y + 1, grid_coord.view_id)
	var west := GridCoord.new(grid_coord.x - 1, grid_coord.y, grid_coord.view_id)
	var east := GridCoord.new(grid_coord.x + 1, grid_coord.y, grid_coord.view_id)
	var north_west := GridCoord.new(grid_coord.x - 1, grid_coord.y - 1, grid_coord.view_id)
	var north_east := GridCoord.new(grid_coord.x + 1, grid_coord.y - 1, grid_coord.view_id)
	var south_west := GridCoord.new(grid_coord.x - 1, grid_coord.y + 1, grid_coord.view_id)
	var south_east := GridCoord.new(grid_coord.x + 1, grid_coord.y + 1, grid_coord.view_id)

	var connects_north: bool = _is_wall_like(GridService.get_cell(north).tile_type)
	var connects_south: bool = _is_wall_like(GridService.get_cell(south).tile_type)
	var connects_west: bool = _is_wall_like(GridService.get_cell(west).tile_type)
	var connects_east: bool = _is_wall_like(GridService.get_cell(east).tile_type)
	var floor_north: bool = _is_floor_like(GridService.get_cell(north).tile_type)
	var floor_south: bool = _is_floor_like(GridService.get_cell(south).tile_type)
	var floor_west: bool = _is_floor_like(GridService.get_cell(west).tile_type)
	var floor_east: bool = _is_floor_like(GridService.get_cell(east).tile_type)
	var floor_north_west: bool = _is_floor_like(GridService.get_cell(north_west).tile_type)
	var floor_north_east: bool = _is_floor_like(GridService.get_cell(north_east).tile_type)
	var floor_south_west: bool = _is_floor_like(GridService.get_cell(south_west).tile_type)
	var floor_south_east: bool = _is_floor_like(GridService.get_cell(south_east).tile_type)
	var floor_mask: int = _make_floor_mask(
		floor_north,
		floor_south,
		floor_west,
		floor_east,
		floor_north_west,
		floor_north_east,
		floor_south_west,
		floor_south_east
	)
	var has_adjacent_floor: bool = (
		floor_north
		or floor_south
		or floor_west
		or floor_east
		or floor_north_west
		or floor_north_east
		or floor_south_west
		or floor_south_east
	)

	return {
		"connects_north": connects_north,
		"connects_south": connects_south,
		"connects_west": connects_west,
		"connects_east": connects_east,
		"floor_mask": floor_mask,
		"has_adjacent_floor": has_adjacent_floor,
		"draw_front_face": floor_south or floor_south_west or floor_south_east,
		"draw_left_face": floor_west or floor_north_west or floor_south_west,
		"draw_right_face": floor_east or floor_north_east or floor_south_east,
		"draw_back_lip": floor_north or floor_north_west or floor_north_east,
		"draw_front_left_corner": floor_south_west or (floor_south and floor_west),
		"draw_front_right_corner": floor_south_east or (floor_south and floor_east),
		"draw_back_left_corner": floor_north_west or (floor_north and floor_west),
		"draw_back_right_corner": floor_north_east or (floor_north and floor_east),
		"draw_top_edge": has_adjacent_floor and (not connects_north or floor_north or floor_north_west or floor_north_east),
		"draw_left_edge": has_adjacent_floor and (not connects_west or floor_west or floor_north_west or floor_south_west),
		"draw_right_edge": has_adjacent_floor and (not connects_east or floor_east or floor_north_east or floor_south_east),
		"variant": _variant_name(floor_mask, has_adjacent_floor),
	}


static func _default_rule() -> Dictionary:
	return {
		"connects_north": false,
		"connects_south": false,
		"connects_west": false,
		"connects_east": false,
		"floor_mask": FLOOR_SOUTH,
		"has_adjacent_floor": true,
		"draw_front_face": true,
		"draw_left_face": true,
		"draw_right_face": true,
		"draw_back_lip": false,
		"draw_front_left_corner": true,
		"draw_front_right_corner": true,
		"draw_back_left_corner": false,
		"draw_back_right_corner": false,
		"draw_top_edge": true,
		"draw_left_edge": true,
		"draw_right_edge": true,
		"variant": "front",
	}


static func _is_wall_like(tile_type: CellData.TileType) -> bool:
	return tile_type in [
		CellData.TileType.WALL,
		CellData.TileType.DOOR,
	]


static func _is_floor_like(tile_type: CellData.TileType) -> bool:
	return tile_type in [
		CellData.TileType.FLOOR,
		CellData.TileType.DOOR,
		CellData.TileType.STAIRS_UP,
		CellData.TileType.STAIRS_DOWN,
		CellData.TileType.OUTSIDE_GROUND,
	]


static func _make_floor_mask(
	north: bool,
	south: bool,
	west: bool,
	east: bool,
	north_west: bool,
	north_east: bool,
	south_west: bool,
	south_east: bool
) -> int:
	var mask: int = 0
	if north:
		mask |= FLOOR_NORTH
	if south:
		mask |= FLOOR_SOUTH
	if west:
		mask |= FLOOR_WEST
	if east:
		mask |= FLOOR_EAST
	if north_west:
		mask |= FLOOR_NORTH_WEST
	if north_east:
		mask |= FLOOR_NORTH_EAST
	if south_west:
		mask |= FLOOR_SOUTH_WEST
	if south_east:
		mask |= FLOOR_SOUTH_EAST
	return mask


static func _variant_name(floor_mask: int, has_adjacent_floor: bool) -> String:
	if not has_adjacent_floor:
		return "cap_only"
	var cardinal_count: int = 0
	for bit: int in [FLOOR_NORTH, FLOOR_SOUTH, FLOOR_WEST, FLOOR_EAST]:
		if (floor_mask & bit) != 0:
			cardinal_count += 1
	if cardinal_count >= 3:
		return "junction"
	if cardinal_count == 2:
		if (
			((floor_mask & FLOOR_NORTH) != 0 and (floor_mask & FLOOR_SOUTH) != 0)
			or ((floor_mask & FLOOR_WEST) != 0 and (floor_mask & FLOOR_EAST) != 0)
		):
			return "straight"
		return "corner"
	if cardinal_count == 1:
		return "edge"
	return "diagonal"
