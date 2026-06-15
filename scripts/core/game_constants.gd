class_name GameConstants
extends RefCounted

const BASE_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

const TILE_SIZE: int = 32
const GRID_VISUAL_SIZE: Vector2i = Vector2i(24, 18)

const COLLISION_LAYER_TERRAIN: int = 1
const COLLISION_LAYER_FURNITURE: int = 2
const COLLISION_LAYER_UNITS: int = 3
const COLLISION_LAYER_ENEMIES: int = 4

# Debug/editor builds only: drag LMB to paint Floor in Build mode.
const DEBUG_DRAG_FLOOR_PAINT := true
