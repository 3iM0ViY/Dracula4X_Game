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

func extract_biome(file_name: String) -> Dictionary:
	var regex := RegEx.new()

	# 1. Ocean tiles (pure water)
	regex.compile("^hex_water")
	if regex.search(file_name):
		return {
			"biome": "ocean",
			"base_biome": "water"
		}

	# 2. Coast tiles (biome + water)
	regex.compile("^hex_(forest|rock|sand)_water")
	var coast_result = regex.search(file_name)
	if coast_result:
		return {
			"biome": "coast",
			"base_biome": coast_result.get_string(1)  # forest/rock/sand
		}

	# 3. Normal land biomes
	regex.compile("^hex_(forest|rock|sand)")
	var land_result = regex.search(file_name)
	if land_result:
		return {
			"biome": land_result.get_string(1),
			"base_biome": land_result.get_string(1)
		}

	# 4. Fallback
	return {
		"biome": "unknown",
		"base_biome": "unknown"
	}


func extract_metadata(file_name: String) -> Dictionary:
	var biome_info = extract_biome(file_name)
	var biome = biome_info["biome"]
	var base_biome = biome_info["base_biome"]
	# specialize coast
	if biome == "coast":
		biome = "coast_" + base_biome

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

const BIOME_COMPATIBILITY = {
	"forest": ["forest", "coast_forest", "rock", "sand"],   # forest може переходити в sand чи rock
	"sand": ["sand", "rock", "forest", "coast_sand"],
	"rock": ["rock", "forest", "sand", "coast_rock"],
	"coast_forest": ["forest", "coast_forest", "ocean"],
	"coast_rock": ["rock", "coast_rock", "ocean"],
	"coast_sand": ["sand", "coast_sand", "ocean"],
	"ocean": ["ocean", "coast_forest", "coast_rock", "coast_sand"]
}


var tile_scene_cache = {}  # Cache loaded GLB scenes

func are_sockets_compatible(side_a: int, side_b: int) -> bool:
	return side_a == side_b  # For roads and water, 1 must match 1

func are_tiles_compatible(tile_a: Dictionary, side_a: int, tile_b: Dictionary, side_b: int) -> bool:
	var roads_match = tile_a["roads"][side_a] == tile_b["roads"][side_b]
	var water_match = tile_a["water"][side_a] == tile_b["water"][side_b]

	var biome_a = tile_a["biome"]
	var biome_b = tile_b["biome"]
	var biome_match = BIOME_COMPATIBILITY.has(biome_a) and biome_b in BIOME_COMPATIBILITY[biome_a]

	return roads_match and water_match and biome_match

func rotate_sockets(sockets: Array, rotation: int) -> Array:
	var steps = rotation % 6
	return sockets.slice(steps) + sockets.slice(0, steps)


const BIOME_WEIGHTS = {
	"ocean": 6,
	"forest": 3,
	"sand": 4,
	"rock": 3,
	"coast_forest": 1,
	"coast_sand": 1,
	"coast_rock": 1
}

func choose_weighted(options: Array) -> String:
	var total = 0
	for opt in options:
		total += BIOME_WEIGHTS.get(opt, 1)
	var pick = randi() % total
	var cumulative = 0
	for opt in options:
		cumulative += BIOME_WEIGHTS.get(opt, 1)
		if pick < cumulative:
			return opt
	return options[0] # fallback

func hex_neighbors(x: int, y: int, cols: int, rows: int) -> Array:
	var neighbors = []
	var even = y % 2 == 0

	# offsets for flat-top hex
	var offsets = [
		Vector2(+1, 0),  # east
		Vector2(-1, 0),  # west
		Vector2(0, -1),  # north-west / north-east
		Vector2(+1, -1),
		Vector2(0, +1),  # south-west / south-east
		Vector2(+1, +1)
	]

	if even:
		offsets = [
			Vector2(+1, 0), Vector2(-1, 0),
			Vector2(-1, -1), Vector2(0, -1),
			Vector2(-1, +1), Vector2(0, +1)
		]

	for o in offsets:
		var nx = x + o.x
		var ny = y + o.y
		if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
			neighbors.append(Vector2(nx, ny))

	return neighbors


func fix_coasts(biome_grid: Array, cols: int, rows: int) -> void:
	var oceanish = ["ocean", "coast_forest", "coast_sand", "coast_rock"]
	for y in range(rows):
		for x in range(cols):
			var cell = biome_grid[y][x]
			if "coast_forest" in cell or "coast_sand" in cell or "coast_rock" in cell or "ocean" in cell:
				var neighbors = hex_neighbors(x, y, cols, rows)
				var ocean_count = 0
				for n in neighbors:
					var ncell = biome_grid[n.y][n.x]
					# count if any neighbor is ocean-like
					for b in ncell:
						if b in oceanish:
							ocean_count += 1
							break
				# If 5 or more neighbors are ocean-like, replace coast with base biome
				if ocean_count >= 5:
					var new_cell = []
					for b in cell:
						if b not in oceanish:
							new_cell.append(b)
					if new_cell.size() > 0:
						biome_grid[y][x] = new_cell


# --- примітивний WFC для біомів ---
func wfc_generate(cols: int, rows: int):
	# 1. створюємо сітку з усіма можливими біомами
	var all_biomes = BIOME_COMPATIBILITY.keys()
	var grid = []
	for y in range(rows):
		grid.append([])
		for x in range(cols):
			grid[y].append(all_biomes.duplicate())  # кожна клітинка починає з усіх біомів
	
	# 2. поки є незаколапсовані клітинки
	while true:
		var cell = find_lowest_entropy_cell(grid)
		if cell == null:
			break  # всі клітинки вже заколапсовані
		var x = cell.x
		var y = cell.y
		var possibilities = grid[y][x]
		# 3. випадково вибираємо біом
		#var chosen = possibilities[randi() % possibilities.size()]
#		# Біом по вазі
		var chosen = choose_weighted(possibilities)
		grid[y][x] = [chosen]
		
		# 4. поширюємо на сусідів
		propagate(grid, x, y, chosen, cols, rows)
	
	# повертаємо готову сітку біомів
	return grid

# знаходить клітинку з найменшою кількістю варіантів (>1)
func find_lowest_entropy_cell(grid: Array):
	var best = null
	var best_size = 9999
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var options = grid[y][x]
			if options.size() > 1 and options.size() < best_size:
				best_size = options.size()
				best = Vector2(x, y)
	return best

# поширює обмеження на сусідів
func propagate(grid: Array, x: int, y: int, chosen: String, cols: int, rows: int):
	var neighbors = [
		Vector2(x+1, y),
		Vector2(x-1, y),
		Vector2(x, y+1),
		Vector2(x, y-1)
	]
	for n in neighbors:
		if n.x >= 0 and n.x < cols and n.y >= 0 and n.y < rows:
			var options = grid[n.y][n.x]
			var allowed = BIOME_COMPATIBILITY[chosen]
			var filtered = []
			for opt in options:
				if opt in allowed:
					filtered.append(opt)
			if filtered.size() > 0: # щоб не було пустих клітинок
				grid[n.y][n.x] = filtered

# --- заміна place_random_tiles ---
func place_tiles_wfc(cols: int, rows: int):
	var biome_grid = wfc_generate(cols, rows)

	# фінальна сітка, де зберігаємо обраний біом як String
	var final_grid = []
	for y in range(rows):
		final_grid.append([])
		for x in range(cols):
			var cell = biome_grid[y][x]
			if cell.size() == 0:
				print("empty cell")
				final_grid[y].append("ocean") # fallback
				continue
			var biome = choose_weighted(cell)
			final_grid[y].append(biome)

	fix_coasts(final_grid, cols, rows)

	# малюємо
	for y in range(rows):
		for x in range(cols):
			var biome = final_grid[y][x]
			var file_name = find_first_tile_for_biome(biome)
			if file_name:
				var scene = load_tile_scene(file_name)
				if scene:
					var instance = scene.instantiate()
					var pos = hex_to_world(x, y, biome)
					instance.position = pos
					add_child(instance)


# знаходить файл для біому
func find_first_tile_for_biome(biome: String) -> String:
	for key in tile_metadata.keys():
		if tile_metadata[key]["biome"] == biome:
			return key
	return "null"

func load_tile_scene(file_name: String) -> PackedScene:
	if tile_scene_cache.has(file_name):
		return tile_scene_cache[file_name]
	var scene = load("res://models/hexes/" + file_name)
	if scene:
		tile_scene_cache[file_name] = scene
	return scene

func hex_to_world(q: int, r: int, biome: String) -> Vector3:
	var x = TILE_RADIUS * sqrt(3) * (q + r * 0.5) #q is the column (horizontal); 
	#r is the row (vertical); sqrt(3) scales the horizontal spacing correctly for flat-top hexes
	var z = TILE_RADIUS * 3.0/2.0 * r #3/2 scales the vertical spacing so rows don’t overlap
	var y = TILE_HEIGHT
	
	match biome:
		"forest":
			y += randf_range(-0.2, 0.4)
		"sand":
			y += randf_range(-0.1, 0.3)
		"rock":
			y += randf_range(0.0, 0.9)
		_:
			y = TILE_HEIGHT  # coast/ocean stay flat

	return Vector3(x, y, z)


func _ready():
	parse_tiles("res://models/hexes/")
	print_metadata()
	place_tiles_wfc(50, 50)
