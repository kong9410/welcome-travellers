class_name InteriorTheme
extends Resource

@export var theme_id: String = "rustic"
@export var display_name: String = "Rustic"
@export var floor_color: Color = DarkFantasyPalette.floor_wood
@export var wall_color: Color = DarkFantasyPalette.wall_stone
@export var door_color: Color = DarkFantasyPalette.door_oak
@export var preferred_guest_tags: PackedStringArray = PackedStringArray(["merchant", "traveler"])


func get_color_for_tile_type(tile_type: CellData.TileType) -> Color:
	match tile_type:
		CellData.TileType.FLOOR:
			return floor_color
		CellData.TileType.OUTSIDE_GROUND:
			return DarkFantasyPalette.outside_moss
		CellData.TileType.WALL:
			return wall_color
		CellData.TileType.DOOR:
			return door_color
		CellData.TileType.STAIRS_UP:
			return DarkFantasyPalette.stairs_up
		CellData.TileType.STAIRS_DOWN:
			return DarkFantasyPalette.stairs_down
		_:
			return CellData.debug_color_for(tile_type)
