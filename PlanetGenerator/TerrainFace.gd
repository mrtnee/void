extends MeshInstance
class_name TerrainFace

const Utils = preload("res://utils.gd")

var _radius: float
var _noise: OpenSimplexNoise
var _resolution: int
var _face_normal: Vector3
var _material: Material
var _shift_u: float
var _shift_v: float
var _shift: Vector3
var _start_offset: Vector3
var _vert_spacing_u: Vector3
var _vert_spacing_v: Vector3
var _size: float
var _start_uv: Vector2

func _init(radius, resolution, face_normal, noise, material, shift_u, shift_v, size):
	_radius = radius
	_resolution = resolution
	_face_normal = face_normal
	_noise = noise
	_material = material
	_shift_u = shift_u
	_shift_v = shift_v
	_size = size
	
	_shift = Utils.rotate_into_direction(Vector3(_shift_v, 0, _shift_u), face_normal)
	_start_offset = Utils.rotate_into_direction(Vector3(_size/2, 0, -_size/2), face_normal)
	_vert_spacing_u = Utils.rotate_into_direction(Vector3(0, 0, _size/(_resolution-1)), face_normal)
	_vert_spacing_v = Utils.rotate_into_direction(Vector3(_size/(_resolution-1), 0, 0), face_normal)
	
	_start_uv = Vector2(shift_v - _size/2, shift_u + _size/2)

func _ready():
	generate_face()

func generate_face():
	var array_mesh := ArrayMesh.new()
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	
	# Initialize arrays.
	var verts := PoolVector3Array()
	var normals := PoolVector3Array()
	var indices := PoolIntArray()
	var uvs := PoolVector2Array()
	verts.resize(_resolution*_resolution)
	normals.resize(_resolution*_resolution)
	indices.resize(int(pow(_resolution - 1, 2)) * 2 * 3)
	uvs.resize(_resolution*_resolution)
	
	# this is a vector containing vertex coordinates
	var start_coords := _face_normal + _shift + _start_offset
	
	# Generate vertices and indices simultaneously
	var indices_idx := 0
	for i in range(_resolution-1):
		var vert_coords = start_coords
		vert_coords += -i * _vert_spacing_v
		
		var uv := _start_uv + Vector2(0, -i * (_size / (_resolution - 1)))
		
		for j in range(_resolution-1):
			verts[i*_resolution + j] = transform_vertex(vert_coords)
			# TODO: properly calculate vertex normals
			normals[i*_resolution + j] = transform_vertex(vert_coords)
			uvs[i*_resolution + j] = uv
			indices[indices_idx] = i * _resolution + j
			indices[indices_idx+1] = i * _resolution + j + 1
			indices[indices_idx+2] = (i+1) * _resolution + j
			indices[indices_idx+3] = (i+1) * _resolution + j
			indices[indices_idx+4] = i * _resolution + j + 1
			indices[indices_idx+5] = (i+1) * _resolution + j + 1
			
			# move the vert_coords along the z-axis and increment indices_idx
			vert_coords += _vert_spacing_u
			indices_idx += 6
			
			# move the uv vector
			uv.x += _size / (_resolution - 1)
		
		# now add the vertex in the last column that we left out
		verts[(i+1)*_resolution - 1] = transform_vertex(vert_coords)
		normals[(i+1)*_resolution - 1] = transform_vertex(vert_coords)
		uvs[(i+1)*_resolution - 1] = uv
	
	# add the last row of vertices
	start_coords -= (_resolution-1) * _vert_spacing_v
	var uv := _start_uv + Vector2(0, _size)
	for j in range(_resolution):
		verts[(_resolution - 1)*_resolution + j] = transform_vertex(start_coords)
		normals[(_resolution - 1)*_resolution + j] = transform_vertex(start_coords)
		uvs[(_resolution - 1) * _resolution + j] = uv
		uv.x += _size / (_resolution - 1)
		start_coords += _vert_spacing_u
	
	# Assign array to mesh array.
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = indices
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	
	# Create mesh surface from mesh array and assign it to our MeshInstance's mesh.
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	array_mesh.regen_normalmaps()
	self.mesh = array_mesh
	self.mesh.surface_set_material(0, _material)
	self.create_trimesh_collision()
	self.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF

func transform_vertex(v: Vector3) -> Vector3:
	v = Utils.to_unit_sphere(v)
	var elevation = (_noise.get_noise_3dv(v * _noise.period * _noise.octaves) + 1) * 0.5
	return v * _radius * (1 + elevation)
