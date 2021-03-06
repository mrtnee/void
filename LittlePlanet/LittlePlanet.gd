tool
extends Spatial

const Utils = preload("res://utils.gd")

export(bool) var update = false setget set_update
export(bool) var _preserve_shape = false
export(float, 1, 1000) var _radius: float = 1
export(int, 2, 500) var _resolution: int = 10
export(OpenSimplexNoise) var _noise: OpenSimplexNoise = null
export(Material) var _material: Material = null

# Class variables
var _initial_size

var _face_directions = [Vector3.UP, Vector3.DOWN, Vector3.LEFT,
	Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]

func _ready():
	remove_all_children($Faces)
	_initial_size = 2
	create_planet_mesh()


func create_planet_mesh():
	for face_dir in _face_directions:
		$Faces.add_child(PlanetFace.new(_radius, _resolution,
			face_dir, _noise, _material, _initial_size))


func set_update(_newVal):
	remove_all_children($Faces)
	_initial_size = 2
	if not _preserve_shape:
		_noise.seed = randi()
	create_planet_mesh()

func remove_all_children(node: Node = self):
	for n in node.get_children():
		node.remove_child(n)
		n.queue_free()

func transform_vertex(v: Vector3) -> Vector3:
	v = Utils.to_unit_sphere(v)
	var elevation = (_noise.get_noise_3dv(v * _noise.period * _noise.octaves) + 1) * 0.5
	return v * _radius * (1 + 2*elevation)
