class_name BuildOptionIcon
extends Control

enum Kind {
	TILE,
	FURNITURE,
}

@export var kind: Kind = Kind.TILE
@export var tile_type: CellData.TileType = CellData.TileType.FLOOR
@export var def_id: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 6.0
	offset_top = 6.0
	offset_right = -6.0
	offset_bottom = -6.0
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	match kind:
		Kind.TILE:
			BuildPreviewDrawer.draw_tile(self, rect, tile_type)
		Kind.FURNITURE:
			BuildPreviewDrawer.draw_furniture(self, rect, def_id)
