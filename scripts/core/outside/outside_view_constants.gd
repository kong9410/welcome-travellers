class_name OutsideViewConstants
extends RefCounted

const WORLD_WIDTH: float = 1280.0
const WORLD_HEIGHT: float = 720.0
const GROUND_LINE_Y: float = 520.0
const INN_WORLD_X: float = WORLD_WIDTH * 0.5
const CAMERA_FOCUS_Y: float = 360.0
const VIEW_MARGIN: float = 48.0
const LEFT_GUEST_SPAWN_X: float = 96.0
const RIGHT_GUEST_SPAWN_X: float = WORLD_WIDTH - 96.0
const GUEST_EXIT_MARGIN: float = 72.0
const GUEST_WALK_Y: float = GROUND_LINE_Y
const QUEUE_START_OFFSET_X: float = 110.0
const QUEUE_SPACING: float = 36.0


static func default_camera_focus() -> Vector2:
	return Vector2(INN_WORLD_X, CAMERA_FOCUS_Y)


static func inn_door_position() -> Vector2:
	return Vector2(INN_WORLD_X, GUEST_WALK_Y)


static func guest_spawn_position(from_left: bool) -> Vector2:
	var spawn_x: float = LEFT_GUEST_SPAWN_X if from_left else RIGHT_GUEST_SPAWN_X
	return Vector2(spawn_x, GUEST_WALK_Y)


static func guest_exit_position(to_left: bool) -> Vector2:
	var exit_x: float = -GUEST_EXIT_MARGIN if to_left else WORLD_WIDTH + GUEST_EXIT_MARGIN
	return Vector2(exit_x, GUEST_WALK_Y)


static func outside_queue_position(index: int) -> Vector2:
	return inn_door_position() + Vector2(QUEUE_START_OFFSET_X + float(index) * QUEUE_SPACING, 0.0)


static func world_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(WORLD_WIDTH, WORLD_HEIGHT))
