tool
extends Spatial

export(bool) var generateFaces = false setget generate_faces
export(float) var radius = 1
export(int, 2, 150) var resolution = 20 setget change_resolution
export(OpenSimplexNoise) var noise
export(ShaderMaterial) var material

func _ready():
	if (!Engine.is_editor_hint()):
		generate_terrain_faces()
		print("Hi")

func generate_faces(newVal):
	if (Engine.is_editor_hint()):
		if (newVal == true):
			delete_children()
			generate_terrain_faces()
			generateFaces = false

func change_resolution(newVal):
	if (Engine.is_editor_hint()):
		delete_children()
		generate_terrain_faces()
		resolution = newVal

func generate_terrain_faces():
	print(noise == null)
	if noise != null:
		print("Generating faces!")
		noise.seed = randi()
		add_child(TerrainFace.new(radius, resolution, Vector3(0, 1, 0), noise, material, 0, 0, 2))
		add_child(TerrainFace.new(radius, resolution, Vector3(0, -1, 0), noise, material, 0, 0, 2))
		add_child(TerrainFace.new(radius, resolution, Vector3(1, 0, 0), noise, material, 0, 0, 2))
		add_child(TerrainFace.new(radius, resolution, Vector3(-1, 0, 0), noise, material, 0, 0, 2))
		add_child(TerrainFace.new(radius, resolution, Vector3(0, 0, 1), noise, material, 0, 0, 2))
		add_child(TerrainFace.new(radius, resolution, Vector3(0, 0, -1), noise, material, 0, 0, 2))

func delete_children():
	for n in get_children():
		remove_child(n)
		n.queue_free()
