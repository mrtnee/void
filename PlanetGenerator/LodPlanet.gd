tool
extends Spatial

const Utils = preload("res://utils.gd")

# Export class variables
export(bool) var process_in_editor = false
export(bool) var update = false setget set_update
export(float, 1, 1000) var _radius: float = 1
export(int, 0, 8) var _max_depth: int
export(int, 2, 32) var _resolution: int = 2
export(int, 1, 500) var _base_lod_range: int = 1
export(OpenSimplexNoise) var _noise = null
export(ShaderMaterial) var _material = null

# Node references
var _player: Spatial

# Class variables
var _initial_size
var _lod_ranges
var _lodplanet: LodPlanet
var _chunks := {}
var _unready_chunks := {}

onready var _thread := Thread.new()


func _ready():
	remove_all_children($Meshes)
	_initial_size = 2
	_player = get_node("../Player")
	
	construct_lod_ranges()
	construct_planet()
	delete_inactive_chunks($Meshes)
	create_planet_mesh()

func _process(_delta):
	if (Engine.is_editor_hint() and !process_in_editor):
		return
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
	_unready_chunks = {}
	_lodplanet = LodPlanet.new()
	_lodplanet.children.append(construct_face(Vector3.UP, 0, 0, 0, 1))
	_lodplanet.children.append(construct_face(Vector3.DOWN, 0, 0, 0, 2))
	_lodplanet.children.append(construct_face(Vector3.RIGHT, 0, 0, 0, 3))
	_lodplanet.children.append(construct_face(Vector3.LEFT, 0, 0, 0, 4))
	_lodplanet.children.append(construct_face(Vector3.BACK, 0, 0, 0, 5))
	_lodplanet.children.append(construct_face(Vector3.FORWARD, 0, 0, 0, 6))


func create_planet_mesh():
	for quad in _unready_chunks.values():
		if !_thread:
			_thread = Thread.new()
		
		if !_thread.is_active():
			_unready_chunks.erase(quad.hashcode)
			_thread.start(self, 'create_quad_mesh', [_thread, quad.hashcode, quad])
	
	for quad in _chunks.values():
		quad.active = false
	
	for quad in _unready_chunks.values():
		quad.active = false


func create_quad_mesh(arr):
	var thread: Thread = arr[0]
	var key: int = arr[1]
	var quad: Quad = arr[2]
	
	var face := TerrainFace.new(_radius, _resolution, quad.face_normal, \
		_noise, _material, quad.pos_u, quad.pos_v, size_at_depth(quad.depth))
	quad.data = face
	quad.add_child(face)
	
	call_deferred('quad_mesh_created', key, quad, thread)


func quad_mesh_created(key: int, quad: Quad, thread: Thread):
	if !_chunks.has(key):
		$Meshes.add_child(quad)
		_chunks[key] = quad
	thread.wait_to_finish()


# This function creates faces, defines their sizes, positions and levels of detail,
# however this function does not construct the meshes
# pos_u, pos_v: positions on unit cube
func construct_face(face_normal: Vector3, pos_u: float, pos_v: float, depth: int, hashcode: int) -> Quad:
	# check if chunk already exists
	var quad: Quad = \
		_chunks[hashcode] if _chunks.has(hashcode) else \
		Quad.new(pos_u, pos_v, depth, hashcode, face_normal)
	
	# calculate distance from player to center of chunk
	var distance_to_player = calculate_distance_to_player(pos_u, pos_v, face_normal)

	# curr_lod is based on depth
	var target_lod = get_lod_from_distance(distance_to_player)
	var curr_lod = get_lod_at_depth(depth)
	
	if curr_lod <= target_lod:
		# if lod's are equal add the quad to unready chunks
		if !_chunks.has(quad.hashcode) and !_unready_chunks.has(quad.hashcode):
			_unready_chunks[quad.hashcode] = quad
		quad.active = true
	else:
		# Otherwise add four children, each shifted in appropriate direciton
		var offset = size_at_depth(depth) / 4
		quad.child_nw = construct_face(face_normal, pos_u - offset, pos_v + offset, depth + 1, hashcode * 10 + 0)
		quad.child_ne = construct_face(face_normal, pos_u + offset, pos_v + offset, depth + 1, hashcode * 10 + 1)
		quad.child_se = construct_face(face_normal, pos_u + offset, pos_v - offset, depth + 1, hashcode * 10 + 2)
		quad.child_sw = construct_face(face_normal, pos_u - offset, pos_v - offset, depth + 1, hashcode * 10 + 3)
	
	return quad


# pos_v corresponds to x-axis, pos_u corresponds to z-axis
func calculate_distance_to_player(pos_u: float, pos_v: float, face_normal: Vector3) -> float:
	var player_translation := _player.translation
	var planet_translation := translation
	
	# calculate chunk center's local position (according to planet center)
	var chunk_pos := Utils.to_unit_sphere(Vector3(pos_v, 1, pos_u))
	chunk_pos = Utils.rotate_into_direction(chunk_pos, face_normal)
	
	# Add elevation from noise to the position.
	var elevation = (_noise.get_noise_3dv(chunk_pos * _noise.period * _noise.octaves) + 1) * 0.5
	chunk_pos = chunk_pos * _radius * (1 + elevation)
	
#	var chunk_pos := Vector3(pos_v, 1, pos_u).normalized() * _radius
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
	remove_all_children($Meshes)
	_chunks = {}
	_initial_size = 2
	_noise.seed = randi()
	if !_player:
		print("Player not attached")
		_player = get_node("../Player")
	
	construct_lod_ranges()
	construct_planet()
	delete_inactive_chunks($Meshes)
	create_planet_mesh()

func delete_inactive_chunks(node: Node = self):
	var inactive_chunks = {}
	
	# find all inactive chunks
	for key in _chunks.keys():
		if !_chunks[key].active:
			inactive_chunks[key] = _chunks[key]
	
	# remove them
	for key in inactive_chunks.keys():
		_chunks.erase(key)
		node.remove_child(inactive_chunks[key])
		inactive_chunks[key].queue_free()
	
	# do the same for unready inactive chunks
	var inactive_unready_chunks = {}
	for key in _unready_chunks.keys():
		if !_unready_chunks[key].active:
			inactive_unready_chunks[key] = _unready_chunks[key]
	
	for key in inactive_unready_chunks.keys():
		_unready_chunks.erase(key)

func remove_all_children(node: Node = self):
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
	var child_nw: Quad
	var child_ne: Quad
	var child_se: Quad
	var child_sw: Quad
	
	var data = null
	var depth: int
	var pos_u: float
	var pos_v: float
	var hashcode: int
	var active: bool = true
	var face_normal: Vector3
	
	func _init(_pos_u: float, _pos_v: float, _depth: int, _hashcode, _face_normal: Vector3):
		self.depth = _depth
		self.pos_u = _pos_u
		self.pos_v = _pos_v
		self.hashcode = _hashcode
		self.face_normal = _face_normal
