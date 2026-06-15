class_name StairRouter
extends RefCounted

static func get_linked_view(from_view_id: ViewIds.Id, tile_type: CellData.TileType) -> ViewIds.Id:
	match from_view_id:
		ViewIds.Id.OUTSIDE:
			if tile_type == CellData.TileType.DOOR:
				return ViewIds.Id.INN_F1
		ViewIds.Id.INN_F1:
			if tile_type == CellData.TileType.STAIRS_UP:
				return ViewIds.Id.INN_F2
			if tile_type == CellData.TileType.STAIRS_DOWN:
				return ViewIds.Id.INN_BASEMENT
		ViewIds.Id.INN_F2:
			if tile_type == CellData.TileType.STAIRS_UP:
				return ViewIds.Id.INN_F3
			if tile_type == CellData.TileType.STAIRS_DOWN:
				return ViewIds.Id.INN_F1
		ViewIds.Id.INN_F3:
			if tile_type == CellData.TileType.STAIRS_DOWN:
				return ViewIds.Id.INN_F2
		ViewIds.Id.INN_BASEMENT:
			if tile_type == CellData.TileType.STAIRS_UP:
				return ViewIds.Id.INN_F1
	return from_view_id


static func is_traversable(tile_type: CellData.TileType) -> bool:
	return tile_type in [
		CellData.TileType.DOOR,
		CellData.TileType.STAIRS_UP,
		CellData.TileType.STAIRS_DOWN,
	]
