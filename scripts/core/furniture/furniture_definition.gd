class_name FurnitureDefinition
extends Resource

@export var def_id: String = ""
@export var display_name: String = ""
@export var footprint: Vector2i = Vector2i(1, 1)
@export var blocks_movement: bool = true
@export var blocks_build: bool = true
@export var category: String = "misc"
@export var required_tile_type: CellData.TileType = CellData.TileType.FLOOR
@export var placeholder_color: Color = Color(0.72, 0.58, 0.42, 0.92)
