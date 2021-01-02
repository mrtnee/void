tool
extends Spatial

# Export class variables
export(bool) var update = false setget set_update
export(float, 1, 1000) var _radius: float = 1
export(int, 0, 8) var _max_depth: int setget set_max_depth
export(int, 1, 32) var _resolution: int = 2
export(int, 1, 100) var _base_lod_range: int = 1
export(OpenSimplexNoise) var _noise = null
export(ShaderMaterial) var _material = null

# Node references
var _player: Spatial

# Class variables
var _initial_size
var _lod_ranges
var _lodplanet: LodPlanet
var _chunks = {}


func _ready():
	remove_children($Meshes)
	_initial_size = 2
	_player = get_node("../Player")
	
	construct_lod_ranges()
	construct_planet()
	delete_inactive_chunks($Meshes)
	create_planet_mesh()

func _process(delta):
#	if (!Engine.is_editor_hint()):
	construct_planet()
	delete_inactive_chunks($Meshes)
	create_planet_mesh()

# Constructs level of detail distribution used in the CDLOD paper
func construct_lod_ranges():
	_lod_ranges = [0, _base_lod_range]
	for i in range(2, _max_depth+1):
		_lod_ranges.append(2 * _lod_ranges[i-1])
#	print(_lod_ranges) <- It works


# Creates all the faces, but does not create the meshes.
func construct_planet():
	_lodplanet = LodPlanet.new()
	_lodplanet.children.append(create_face(Vector3(0, 1, 0), 0, 0, 0, 1))


func create_planet_mesh():
#	for quad in _lodplanet.children:
#		create_quad_mesh(quad)
	for key in _chunks.keys():
		create_quad_mesh2(_chunks[key])
		_chunks[key].active = false


func create_quad_mesh(quad: Quad):
	if quad.is_leaf:
		var face := TerrainFace.new(_radius, _resolution, Vector3(0, 1, 0), \
			_noise, _material, quad.pos_u, quad.pos_v, size_at_depth(quad.depth))
		quad.data = face
		$Meshes.add_child(face)
	else:
		create_quad_mesh(quad.child_nw)
		create_quad_mesh(quad.child_ne)
		create_quad_mesh(quad.child_se)
		create_quad_mesh(quad.child_sw)


func create_quad_mesh2(quad: Quad):
	if quad.has_mesh:
		return
	
	var face := TerrainFace.new(_radius, _resolution, Vector3(0, 1, 0), \
		_noise, _material, quad.pos_u, quad.pos_v, size_at_depth(quad.depth))
	quad.data = face
	quad.add_child(face)
	$Meshes.add_child(quad)


# This function creates faces, defines their sizes, positions and levels of detail,
# however this function does not construct the meshes
# pos_u, pos_v: positions on unit cube
func create_face(up_vec: Vector3, pos_u: float, pos_v: float, depth: int, hashcode: int) -> Quad:
	# check if chunk already exists
	var quad: Quad
	if _chunks.has(hashcode):
		quad = _chunks[hashcode]
		quad.has_mesh = true
	else:
		quad = Quad.new(pos_u, pos_v, depth, hashcode)
	
	# calculate distance from player to center of chunk
	var distance_to_player = calculate_distance_to_player(pos_u, pos_v)
#	print(distance_to_player)
	
	var target_lod = get_lod_from_distance(distance_to_player)	# target lod for this quad
#	print(target_lod)
	var curr_lod = get_lod_at_depth(depth)	# lod of this quad (based on depth)
#	print(curr_lod)
	
	if curr_lod <= target_lod or depth == _max_depth:
		# if lod's are equal create a quad and return it
		if !_chunks.has(quad.hashcode):
			_chunks[quad.hashcode] = quad
		quad.active = true
		return quad
	# TODO: make it possible for the quad to be seperable into 4 smaller quads if their
	# LODs aren't equal, right now that is not possible
#	elif curr_lod < target_lod:
#		return null
	else:
		# otherwise, create a new quad and assign it four children
		quad.is_leaf = false
		
		# calculate offset of children's center in respect to current quad's center
		var offset = size_at_depth(depth) / 4
		quad.child_nw = create_face(up_vec, pos_u - offset, pos_v + offset, depth + 1, hashcode * 10 + 0)
		quad.child_ne = create_face(up_vec, pos_u + offset, pos_v + offset, depth + 1, hashcode * 10 + 1)
		quad.child_se = create_face(up_vec, pos_u + offset, pos_v - offset, depth + 1, hashcode * 10 + 2)
		quad.child_sw = create_face(up_vec, pos_u - offset, pos_v - offset, depth + 1, hashcode * 10 + 3)
		
		if (quad.has_any_null_child()):
			
			quad.is_leaf = true
			if !_chunks.has(quad.hashcode):
				_chunks[quad.hashcode] = quad
			quad.active = true
		
		return quad


# pos_v corresponds to x-axis, pos_u corresponds to z-axis
func calculate_distance_to_player(pos_u: float, pos_v: float) -> float:
	var player_translation := _player.translation
	var planet_translation := translation
	
	# calculate chunk center's local position (according to planet center)
	var chunk_pos := Vector3(pos_v, 1, pos_u).normalized() * _radius
	# now add the planet's trnslation to get chunk's global position
	chunk_pos += planet_translation
	
	return chunk_pos.distance_to(player_translation)


# Returns appropriate LOD for given distance
func get_lod_from_distance(dist: float) -> int:
	for lod in range(len(_lod_ranges)):
		if dist < _lod_ranges[lod]:
			return lod - 1
	return len(_lod_ranges) - 1


# Returns lod level for certain quadtree depth
func get_lod_at_depth(depth: int) -> int:
	return len(_lod_ranges) - 1 - depth


func size_at_depth(depth: int) -> float:
	return _initial_size / pow(2, depth)


func set_update(_newVal):
	remove_children($Meshes)
	_chunks = {}
	_initial_size = 2
	_noise.seed = randi()
	if _player != null:
		print(_lod_ranges)
	else:
		print("Player not attached")
		_player = get_node("../Player")
	construct_lod_ranges()
	construct_planet()
	delete_inactive_chunks($Meshes)
	create_planet_mesh()

func set_max_depth(newval):
	_max_depth = newval
	construct_lod_ranges()

func delete_inactive_chunks(node: Node = self):
	var inactive_chunks = {}
	
	for key in _chunks.keys():
		if !_chunks[key].active:
			inactive_chunks[key] = _chunks[key]
	
	for key in inactive_chunks.keys():
		_chunks.erase(key)
		node.remove_child(inactive_chunks[key])
		inactive_chunks[key].queue_free()
	
#	for n in node.get_children():
#		if !_chunks[n.hashcode].active:
#			_chunks.erase(n.hashcode)
#			node.remove_child(n)
#			n.queue_free()

func remove_children(node: Node = self):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()


###
# Inner classes
###
class LodPlanet:
	
	var children = []
	
	func _init():
		pass


class Quad extends Spatial:
	var child_nw: Quad	# north-western 
	var child_ne: Quad	# north-eastern
	var child_se: Quad	# south-easter
	var child_sw: Quad	# south-western
	
	var children = []
	
	var data = null
	var depth: int
	var pos_u: float
	var pos_v: float
	var is_leaf: bool = true
	var hashcode: int
	var active: bool = true
	var has_mesh: bool = false
	
	func _init(_pos_u: float, _pos_v: float, _depth: int, _hashcode):
		self.depth = _depth
		self.pos_u = _pos_u
		self.pos_v = _pos_v
		self.hashcode = _hashcode
	
	func has_any_null_child() -> bool:
		return child_nw == null or child_ne == null or child_se == null or child_sw == null
