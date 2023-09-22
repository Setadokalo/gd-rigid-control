extends Node3D


@export var follow: Node3D:
	set(val):
		if val == null:
			printerr("Invalid follow target for LazyFollow node")
		follow = val
@export var follow_interpolate := true
@export var position_follow_speed: float = 10.0
@export var rotation_follow_speed: float = 10.0

@export var position_offset := Vector3()

func _ready():
	if follow == null:
		printerr("Invalid follow target for LazyFollow node")

func _process(delta: float):
	if follow == null: # can't track what doesn't exist
		return
	if not follow_interpolate:
		global_transform = follow.global_transform
		global_position += position_offset
		return
	# lerp weight
	var p_l_fac = clamp(delta * position_follow_speed, 0.0, 1.0)
	var r_l_fac = clamp(delta * rotation_follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(
		(follow.global_position + position_offset), 
		p_l_fac
	)
	
	global_rotation = interpolate_camera(global_rotation, follow.global_rotation, r_l_fac)


func _slerpf(f: float, t: float, w: float) -> float:
	w = clampf(w, 0.0, 1.0)
	f = wrapf(f, -PI, PI)
	t = wrapf(t, -PI, PI)
	if abs(t - f) > PI:
		if f>t:
			return lerp(f, t + 2*PI, w)
		else:
			return lerp(f + 2*PI, t, w)
	else:
		return lerp(f, t, w)

func interpolate_camera(rot_f: Vector3, rot_t: Vector3, fac: float) -> Vector3:
	return Vector3(
		_slerpf(rot_f.x, rot_t.x, fac),
		_slerpf(rot_f.y, rot_t.y, fac),
		_slerpf(rot_f.z, rot_t.z, fac)
	)
