static func to_unit_sphere(v: Vector3) -> Vector3:
	var vs := Vector3()
	vs.x = v.x * sqrt(1 - pow(v.y, 2)/2.0 - pow(v.z, 2)/2.0 + pow(v.y * v.z, 2)/3.0)
	vs.y = v.y * sqrt(1 - pow(v.x, 2)/2.0 - pow(v.z, 2)/2.0 + pow(v.x * v.z, 2)/3.0)
	vs.z = v.z * sqrt(1 - pow(v.x, 2)/2.0 - pow(v.y, 2)/2.0 + pow(v.x * v.y, 2)/3.0)
	return vs

static func rotate_into_direction(vec: Vector3, dir: Vector3) -> Vector3:
	if dir.y == -1:
		return vec.rotated(Vector3(1, 0, 0), deg2rad(180))
	elif dir.z == 1:
		return vec.rotated(Vector3(1, 0, 0), deg2rad(90))
	elif dir.z == -1:
		return vec.rotated(Vector3(1, 0, 0), deg2rad(-90))
	elif dir.x == 1:
		return vec.rotated(Vector3(0, 0, 1), deg2rad(-90))
	elif dir.x == -1:
		return vec.rotated(Vector3(0, 0, 1), deg2rad(90))
	else:
		return vec
