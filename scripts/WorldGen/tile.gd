extends Node3D
class_name Tile

enum biome_type {Grassland, Forest, Desert, Ocean, Tundra, Mountain}
var biome : String
var mesh_data : TileMeshData
var pos_data : PositionData

var neighbors = []
var placeable = true

var occupier : Unit
var debug_label : Label3D
