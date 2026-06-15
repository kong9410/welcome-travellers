class_name ViewRoot
extends Node2D

@export var view_id: ViewIds.Id = ViewIds.Id.OUTSIDE
@export var background_color: Color = DarkFantasyPalette.view_inn_f1_bg

@onready var terrain_tile_map: TileMapLayer = $TileMap/TerrainTileMap
@onready var furniture_layer: Node2D = $FurnitureLayer
@onready var entity_layer: Node2D = $EntityLayer
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var grid_visualizer: GridVisualizer = $GridVisualizer
@onready var grid_cell_renderer: GridCellRenderer = $GridCellRenderer
@onready var structure_ghost_renderer: StructureGhostRenderer = $StructureGhostRenderer
@onready var furniture_ghost_renderer: FurnitureGhostRenderer = $FurnitureGhostRenderer


func _ready() -> void:
	_configure_depth_sorted_layers()
	if grid_visualizer:
		grid_visualizer.background_color = background_color
		grid_visualizer.queue_redraw()
	if grid_cell_renderer:
		grid_cell_renderer.view_id = view_id
	if structure_ghost_renderer:
		structure_ghost_renderer.view_id = view_id
	if furniture_ghost_renderer:
		furniture_ghost_renderer.view_id = view_id


func _configure_depth_sorted_layers() -> void:
	if furniture_layer:
		furniture_layer.z_index = 3
		furniture_layer.y_sort_enabled = true
	if entity_layer:
		entity_layer.z_index = 3
		entity_layer.y_sort_enabled = true
