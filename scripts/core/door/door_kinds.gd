class_name DoorKinds
extends RefCounted

# Interior passages: furniture on FLOOR inside a wall opening (room ↔ hallway).
const INTERIOR_FURNITURE_DEF_ID: String = "room_door"


static func is_structural_door_cell(cell: CellData) -> bool:
	return cell.tile_type == CellData.TileType.DOOR


static func is_interior_door_def(def_id: String) -> bool:
	return def_id == INTERIOR_FURNITURE_DEF_ID
