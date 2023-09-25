extends Node3D

@export var follow_distance := 10.0
@export var follow_accel := 20.0
@export var follow_decel := 20.0
@export var follow_max_speed := 3.0

@export var target_node: Node3D

var _velocity := Vector3()

var _oldtween: Tween
@onready var _cur_rotation_target := rotation
@onready var _cur_rotation := rotation

func _apply_rotation(progress: float, start: Vector3, target: Vector3) -> void:
	_cur_rotation = lerp(start, target, progress)
	rotation = _cur_rotation

func rotate_view(amount: float) -> void:
	if _oldtween:
		_oldtween.kill()
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	_cur_rotation_target += Vector3(0.0, amount, 0.0)
	var mtween = tween.tween_method(_apply_rotation.bindv([_cur_rotation, _cur_rotation_target]), 0.0, 1.0, 0.5)
	mtween.set_ease(Tween.EASE_IN_OUT)
	mtween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func(): 
		_cur_rotation_target = Vector3(
			fmod(_cur_rotation_target.x + PI, 2.0 * PI) - PI,
			fmod(_cur_rotation_target.y + PI, 2.0 * PI) - PI,
			fmod(_cur_rotation_target.z + PI, 2.0 * PI) - PI
		)
		_cur_rotation = Vector3(
			fmod(_cur_rotation.x + PI, 2.0 * PI) - PI,
			fmod(_cur_rotation.y + PI, 2.0 * PI) - PI,
			fmod(_cur_rotation.z + PI, 2.0 * PI) - PI
		)
	)
	_oldtween = tween

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_cam_left"):
		rotate_view(-PI/2.0)
	if event.is_action_pressed("rotate_cam_right"):
		rotate_view(PI/2.0)

func _process(delta: float) -> void:
	var targetpos := target_node.global_position
	if global_position.distance_to(targetpos) > follow_distance:
		_velocity = _velocity.lerp(global_position.direction_to(targetpos) * follow_max_speed, delta * follow_accel)
		var tvel = target_node.get("linear_velocity")
		if tvel != null:
			_velocity = _velocity.limit_length(max(tvel.length(), 2.0))
	else:
		_velocity = _velocity.lerp(Vector3.ZERO, delta * follow_decel)
	global_position += _velocity * delta
	
	if $Camera3D.projection == Camera3D.PROJECTION_PERSPECTIVE:
		$RayCast3D.position = $Camera3D.position
		var localized = $RayCast3D.global_transform.inverse() * targetpos
		$RayCast3D.target_position = localized
	else:
		var screenpos = $Camera3D.project_position($Camera3D.unproject_position(targetpos), 0.0)
		$RayCast3D.global_position = screenpos
		
		var localized = $RayCast3D.global_transform.inverse() * targetpos
		$RayCast3D.target_position = localized
	$RayCast3D.force_shapecast_update()
	while $RayCast3D.is_colliding():
		for c_idx in $RayCast3D.get_collision_count():
			$RayCast3D.get_collider(c_idx).inform_occluding()
			var ray_dir = ($RayCast3D.get_collision_point(c_idx) - $RayCast3D.global_position).normalized()
			$RayCast3D.global_position = $RayCast3D.get_collision_point(c_idx) + ray_dir * 0.35
			var localized = $RayCast3D.global_transform.inverse() * targetpos
			$RayCast3D.target_position = localized
		$RayCast3D.force_shapecast_update()
