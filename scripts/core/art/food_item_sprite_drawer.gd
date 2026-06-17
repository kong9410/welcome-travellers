class_name FoodItemSpriteDrawer
extends RefCounted

const BREAD_TEXTURE: Texture2D = preload("res://assets/bread.png")
const MEAL_TEXTURE: Texture2D = preload("res://assets/meal.png")
const EMPTY_BOWL_TEXTURE: Texture2D = preload("res://assets/empty bowl.png")
const TRASH_TEXTURE: Texture2D = preload("res://assets/trash.png")

const FOOD_DRAW_SIZE: float = 24.0
const FILTH_DRAW_SIZE: float = 22.0
const DRAW_Y_OFFSET: float = 3.0


static func texture_for_food_type(food_type: String) -> Texture2D:
	match food_type:
		"bread":
			return BREAD_TEXTURE
		"basic":
			return MEAL_TEXTURE
		_:
			return MEAL_TEXTURE


static func texture_for_filth(kind: FilthKinds.Id) -> Texture2D:
	match kind:
		FilthKinds.Id.FOOD_SCRAP:
			return EMPTY_BOWL_TEXTURE
		FilthKinds.Id.TRASH:
			return TRASH_TEXTURE
		_:
			return null


static func draw_item(
	canvas: CanvasItem,
	texture: Texture2D,
	draw_size: float = FOOD_DRAW_SIZE,
	y_offset: float = DRAW_Y_OFFSET
) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale: float = draw_size / maxf(tex_size.x, tex_size.y)
	var scaled_size: Vector2 = tex_size * scale
	var draw_rect := Rect2(
		Vector2(-scaled_size.x * 0.5, -scaled_size.y + y_offset),
		scaled_size
	)
	canvas.draw_texture_rect(texture, draw_rect, false)
