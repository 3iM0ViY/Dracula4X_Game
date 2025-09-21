extends Resource
class_name TileMeshData

@export var mesh : PackedScene
@export var shader_override : ShaderMaterial
@export var color : Color
@export var type : Tile.biome_type

## This is used by world_gen to keep track of which index this tile has in the tiles array
var index = 0
