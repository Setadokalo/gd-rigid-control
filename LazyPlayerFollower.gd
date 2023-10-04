extends Node3D

signal pixel_offset(offs: Vector2)

@export var follow_distance := 10.0
@export var follow_velocity_modifier := 1.0
@export var follow_accel := 20.0
@export var follow_decel := 20.0

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
	event.get_rid()
	if event.is_action_pressed("rotate_cam_left"):
		rotate_view(-PI/2.0)
	if event.is_action_pressed("rotate_cam_right"):
		rotate_view(PI/2.0)

func _process(delta: float) -> void:
	var targetpos: Vector3 = target_node.global_position + target_node.get("linear_velocity") * follow_velocity_modifier
	var tvel = target_node.get("linear_velocity")
	if global_position.distance_to(targetpos) > follow_distance:
		_velocity = _velocity.lerp(
			(global_position.direction_to(targetpos) * tvel.length() * 1.5)
				.limit_length(max(tvel.length() * 1.5, 2.0)),
			delta * follow_accel * max(1.0, global_position.distance_to(targetpos) * 0.2))
	else:
		_velocity = _velocity.lerp(tvel * Vector3(1.0, 0.0, 1.0), delta * follow_decel)
	global_position += _velocity * delta
	
	targetpos = target_node.global_position
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
	# Lock all registered visual objects to the pixel grid of the camera
	for node in get_tree().get_nodes_in_group("pixel_lock"):
		apply_gridlock(node, global_transform.basis.x, global_transform.basis.y)
	# Lock camera to pixel intervals
	var offs = apply_gridlock($Camera3D, global_transform.basis.x, global_transform.basis.y)
	emit_signal("pixel_offset", offs)

const PIXEL_SNAP: float = 15.0 / 210.0

func apply_gridlock(node: Node3D, x_axis: Vector3, y_axis: Vector3) -> Vector2:
	if not node.has_meta("position_offset"):
		node.set_meta("position_offset", node.position)
	var cam_transform := node.global_transform
	cam_transform.origin = node.get_parent_node_3d().global_transform * node.get_meta("position_offset")
	var worldpos_x := cam_transform.origin.project(x_axis)
	var worldpos_y := cam_transform.origin.project(y_axis)
	
	var x_length := worldpos_x.length()
	var y_length := worldpos_y.length()
	
	var gx_length := snappedf(worldpos_x.length(), PIXEL_SNAP)
	var gy_length := snappedf(worldpos_y.length(), PIXEL_SNAP)
	
	var gx_offs := x_length - gx_length
	var gy_offs := y_length - gy_length
	if worldpos_x.angle_to(cam_transform.basis.x) > PI * 0.5:
		gx_offs = -gx_offs
	if worldpos_y.angle_to(cam_transform.basis.y) > PI * 0.5:
		gy_offs = -gy_offs
	
	var gridlocked_pos_x = worldpos_x.normalized() * gx_length
	var gridlocked_pos_y = worldpos_y.normalized() * gy_length
	cam_transform.origin = cam_transform.origin - worldpos_x + gridlocked_pos_x - worldpos_y + gridlocked_pos_y
	
	node.global_transform = cam_transform
	return Vector2(-gx_offs, gy_offs)
	
