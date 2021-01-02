extends Spatial
class_name TerrainFace

var radius
var mesh_instance
var noise
var resolution
var up_vector
var material
var shift_u
var shift_v
var size
var displacement_vector: Vector3

func _init(_radius, _resolution, _face_up, _noise, _material, _shift_u, _shift_v, _size):
	self.radius = _radius
	self.resolution = _resolution
	self.up_vector = _face_up
	self.noise = _noise
	self.material = _material
	self.shift_u = _shift_u
	self.shift_v = _shift_v
	self.size = _size
	

func _ready():
	generate_face()

func generate_face():
	var plane_mesh = PlaneMesh.new()
	
	plane_mesh.size = Vector2(size, size)
	plane_mesh.subdivide_depth = self.resolution
	plane_mesh.subdivide_width = self.resolution
	
	plane_mesh.material = self.material
	
	var surface_tool = SurfaceTool.new()
	var data_tool = MeshDataTool.new()
	surface_tool.create_from(plane_mesh, 0)
	var array_plane = surface_tool.commit()
	var error = data_tool.create_from_surface(array_plane, 0)
	
	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		
		vertex.x += shift_v
		vertex.z += shift_u
		
		vertex = vertex + Vector3(0, 1, 0)
		
		# Let's first rotate the vertices
		if up_vector.y == -1:
			vertex = vertex.rotated(Vector3(1, 0, 0), deg2rad(180))
		elif up_vector.z == 1:
			vertex = vertex.rotated(Vector3(1, 0, 0), deg2rad(-90))
		elif up_vector.z == -1:
			vertex = vertex.rotated(Vector3(1, 0, 0), deg2rad(90))
		elif up_vector.x == 1:
			vertex = vertex.rotated(Vector3(0, 0, 1), deg2rad(-90))
		elif up_vector.x == -1:
			vertex = vertex.rotated(Vector3(0, 0, 1), deg2rad(90))
		
		# Now let's transform the vertices such, that they form a unit circle
		vertex = vertex.normalized()
		
		var elevation = (noise.get_noise_3dv(vertex * noise.period * noise.octaves) + 1) * 0.5
		
#		data_tool.set_vertex(i, vertex * self.radius * (1 + elevation))
		data_tool.set_vertex(i, vertex * self.radius)
	
	for s in range(array_plane.get_surface_count()):
		array_plane.surface_remove(s)
	
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals()
	
	mesh_instance = MeshInstance.new()
	mesh_instance.mesh = surface_tool.commit()
	mesh_instance.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	
	mesh_instance.create_trimesh_collision()
	
#	if up_vector.y == -1:
#		mesh_instance.rotate_x(deg2rad(180))
#	elif up_vector.z == 1:
#		mesh_instance.rotate_x(deg2rad(-90))
#	elif up_vector.z == -1:
#		mesh_instance.rotate_x(deg2rad(90))
#	elif up_vector.x == 1:
#		mesh_instance.rotate_z(deg2rad(-90))
#	elif up_vector.x == -1:
#		mesh_instance.rotate_z(deg2rad(90))
	
	add_child(mesh_instance)
	
