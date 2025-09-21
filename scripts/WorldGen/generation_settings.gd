extends Resource
class_name GenerationSettings

enum shape {HEXAGONAL, RECTANGULAR, DIAMOND, CIRCLE}

@export_category("Tiles")
@export var tiles : Array[TileMeshData]
@export var biome_weights : Array[float]
@export var tile_size : float = 1 #Scalar for different size tiles, leave at 1 if not using your own mesh
@export var debug = false

@export_category("Generation")
@export var map_seed : int
@export var map_shape : shape = shape.HEXAGONAL
@export_range(0, 99, 1) var radius: int = 5
@export var biome_noise : FastNoiseLite

@export_category("Hills")
@export var modify_height = true
@export_range(0.1, 1.0) var hill_height = 0.5
@export_range(0.0, 1.0) var heightmap_treshold = 0.6
@export var heightmap_noise : FastNoiseLite

@export_category("Water/Ocean")
@export var create_water = true
@export var ocean_tile : TileMeshData
@export var ocean_noise : FastNoiseLite
@export_range(-1.0, -0.1) var ocean_height = -0.4
@export_range(0.0, 1.0) var ocean_treshold : float

@export_category("Villages")
@export var spawn_villages = true
@export var map_edge_buffer = 2
@export_range(1, 99) var spacing = 6
