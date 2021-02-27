extends MeshInstance
class_name PlanetFace

const Utils = preload("res://utils.gd")

var _radius: float
var _noise: OpenSimplexNoise
var _resolution: int
var _face_normal: Vector3
var _material: Material
var _start_offset: Vector3
var _vert_spacing_u: Vector3
var _vert_spacing_v: Vector3
var _size: float
var _start_uv: Vector2

func _init(radius, resolution, face_normal, noise, material, size):
	_radius = radius
	_resolution = resolution
	_face_normal = face_normal
	_noise = noise
	_material = material
	_size = size
	
	_start_offset = Utils.rotate_into_direction(Vector3(_size/2, 0, -_size/2), face_normal)
	_vert_spacing_u = Utils.rotate_into_direction(Vector3(0, 0, _size/(_resolution-1)), face_normal)
	_vert_spacing_v = Utils.rotate_into_direction(Vector3(_size/(_resolution-1), 0, 0), face_normal)
	
	_start_uv = Vector2(0, 0)

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
	var start_coords := _face_normal + _start_offset
	
	# Generate vertices and indices simultaneously
	var indices_idx := 0
	for y in range(_resolution):
		var vert_coords = start_coords
		vert_coords += -y * _vert_spacing_v
		
		var uv := _start_uv + Vector2(0, -y * (_size / (_resolution - 1)))
		
		for x in range(_resolution):
			var i := y * _resolution + x
			
			verts[i] = transform_vertex(vert_coords)
			uvs[i] = uv
			
			if (x != _resolution - 1 && y != _resolution - 1):
				indices[indices_idx] = i
				indices[indices_idx+1] = i + 1
				indices[indices_idx+2] = i + _resolution
				indices[indices_idx+3] = i + 1
				indices[indices_idx+4] = i + _resolution + 1
				indices[indices_idx+5] = i + _resolution
				indices_idx += 6
			
			# move the vert_coords along the z-axis and increment indices_idx
			vert_coords += _vert_spacing_u
			# move the uv vector
			uv.x += _size / (_resolution - 1)
	
	# Set normals.
	for i in range(0, indices.size(), 3):
		var vertexIdx1 = indices[i]
		var vertexIdx2 = indices[i+1]
		var vertexIdx3 = indices[i+2]

		var v1 = verts[vertexIdx1]
		var v2 = verts[vertexIdx2]
		var v3 = verts[vertexIdx3]
		
		# calculate normal for this face
		var norm: Vector3 = -(v2 - v1).normalized().cross((v3 - v1).normalized()).normalized()
		normals[vertexIdx1] = norm
		normals[vertexIdx2] = norm
		normals[vertexIdx3] = norm
	
	# Assign array to mesh array.
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = indices
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	
	# Create mesh surface from mesh array and assign it to our MeshInstance's mesh.
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
#	array_mesh.regen_normalmaps()
	self.mesh = array_mesh
	self.mesh.surface_set_material(0, _material)
#	self.create_trimesh_collision()
	self.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_DOUBLE_SIDED

func transform_vertex(v: Vector3) -> Vector3:
	v = Utils.to_unit_sphere(v)
	var elevation = (_noise.get_noise_3dv(v * _noise.period * _noise.octaves) + 1) * 0.5
	return v * _radius * (1 + 2*elevation)
