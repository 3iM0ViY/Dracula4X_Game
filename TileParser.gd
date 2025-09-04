extends Node
var regex = RegEx.new()

var tile_metadata = {}

# Road patterns mapped by letter
const ROAD_PATTERNS = {
	"A": [1, 0, 0, 0, 0, 0],  # single road
	"B": [1, 0, 0, 1, 0, 0],  # opposite pair
	"C": [1, 1, 0, 0, 0, 0],  # adjacent pair
	"D": [1, 0, 1, 0, 0, 0],  # one skipped
	"E": [1, 1, 0, 1, 0, 0],  # fork (two adjacent + opposite)
	"F": [1, 0, 0, 1, 0, 1],  # triangle (every other side)
	"G": [1, 0, 1, 0, 1, 0],  # three-point star
	"H": [1, 1, 1, 0, 0, 0],  # three consecutive
	"I": [1, 1, 1, 0, 1, 0],  # four roads, 3 + 1
	"J": [1, 1, 0, 1, 1, 0],  # four roads, two-gap-two
	"K": [1, 1, 1, 1, 0, 0],  # four consecutive
	"L": [0, 1, 1, 1, 1, 1],  # five roads (all but one)
	"M": [1, 1, 1, 1, 1, 1],  # all sides
}
const WATER_PATTERNS = {
	"A": [1, 1, 1, 0, 0, 1],  # 4 sides water
	"B": [0, 0, 1, 1, 1, 0],  # 3 consecutive water
	"C": [0, 0, 1, 1, 1, 0],  # visually different, but same adjacency
	"D": [0, 0, 0, 1, 1, 0],  # 2 opposite water sides
}
const BIOME_PATTERNS = {
	"forest": "forest",
	"rock": "rock",
	"sand": "sand",
	"coast": "coast",
	"ocean": "ocean",
}


# Generic extractor
func extract_with_regex(file_name: String, pattern: String, lookup: Dictionary, default_value) -> Variant:
	var regex := RegEx.new()
	regex.compile(pattern)
	var result = regex.search(file_name)
	if result:
		var key = result.get_string(1)
		if lookup.has(key):
			return lookup[key]
	return default_value


func extract_metadata(file_name: String) -> Dictionary:
	#var biome = "forest"  # We're only handling forest for now
	#var detailed = file_name.find("_detail") != -1
	#var roads = [0, 0, 0, 0, 0, 0]  # Default: no roads
	#var waters = [0, 0, 0, 0, 0, 0]  # Default: no water

	
	var biome = extract_with_regex(
		file_name,
		"hex_(forest|rock|sand|coast|ocean)",
		BIOME_PATTERNS,
		"unknown"
	)

	var roads = extract_with_regex(
		file_name,
		"road([A-M])",
		ROAD_PATTERNS,
		[0, 0, 0, 0, 0, 0]
	)

	var water = extract_with_regex(
		file_name,
		"water([A-D])",
		WATER_PATTERNS,
		[0, 0, 0, 0, 0, 0]
	)

	var detailed = file_name.find("_detail") != -1

	return {
		"biome": biome,
		"detailed": detailed,
		"roads": roads,
		"water": water
	}


func parse_tiles(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		push_error("Failed to open directory: " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb"):
			var meta = extract_metadata(file_name)
			if meta:
				tile_metadata[file_name] = meta
		file_name = dir.get_next()
	dir.list_dir_end()


func print_metadata():
	for key in tile_metadata.keys():
		print(key, " -> ", tile_metadata[key])



const TILE_RADIUS = 1.15  # Adjust based on your model scale
const TILE_HEIGHT = 0.0  # If tiles are flat, keep at 0


var tile_scene_cache = {}  # Cache loaded GLB scenes

func place_random_tiles(cols: int, rows: int):
	var keys = tile_metadata.keys()
	for y in range(rows):
		for x in range(cols):
			var file_name = keys[randi() % keys.size()]
			var scene = load_tile_scene(file_name)
			if scene:
				var instance = scene.instantiate()
				var pos = hex_to_world(x, y)
				instance.position = pos
				add_child(instance)

func load_tile_scene(file_name: String) -> PackedScene:
	if tile_scene_cache.has(file_name):
		return tile_scene_cache[file_name]
	var scene = load("res://models/hexes/" + file_name)
	if scene:
		tile_scene_cache[file_name] = scene
	return scene

func hex_to_world(q: int, r: int) -> Vector3:
	var x = TILE_RADIUS * sqrt(3) * (q + r * 0.5) #q is the column (horizontal); 
	#r is the row (vertical); sqrt(3) scales the horizontal spacing correctly for flat-top hexes
	var z = TILE_RADIUS * 3.0/2.0 * r #3/2 scales the vertical spacing so rows don’t overlap
	return Vector3(x, TILE_HEIGHT, z)


func _ready():
	parse_tiles("res://models/hexes/")
	print_metadata()
	place_random_tiles(10, 10)
