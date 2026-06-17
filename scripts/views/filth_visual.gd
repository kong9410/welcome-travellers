class_name FilthVisual
extends Node2D

const TRASH_DROP_HEIGHT: float = 20.0
const TRASH_DROP_SPEED: float = 72.0

var coord: GridCoord
var kind: FilthKinds.Id = FilthKinds.NO_FILTH
var amount: int = 1

var _drop_offset: float = 0.0


func _ready() -> void:
	TopdownDepthSort.apply_for_foot(self, TopdownDepthSort.FOOD_OFFSET)
	queue_redraw()


func setup(p_coord: GridCoord, p_kind: FilthKinds.Id, p_amount: int = 1) -> void:
	coord = p_coord.duplicate_coord() if p_coord != null else null
	kind = p_kind
	amount = maxi(p_amount, 1)
	if kind == FilthKinds.Id.TRASH:
		_drop_offset = -TRASH_DROP_HEIGHT
	else:
		_drop_offset = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _drop_offset >= 0.0:
		return
	_drop_offset = minf(_drop_offset + TRASH_DROP_SPEED * delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var texture: Texture2D = FoodItemSpriteDrawer.texture_for_filth(kind)
	if texture == null:
		return
	var canvas: CanvasItem = self
	var y_offset: float = FoodItemSpriteDrawer.DRAW_Y_OFFSET + _drop_offset
	FoodItemSpriteDrawer.draw_item(
		canvas,
		texture,
		FoodItemSpriteDrawer.FILTH_DRAW_SIZE,
		y_offset
	)
