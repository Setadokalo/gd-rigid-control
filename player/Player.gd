class_name Player
extends RigidBody3D


const SPEED := 5.0
const JUMP_VELOCITY := 4.5

const ROT_LIMIT: float = PI / 2.0 - 0.01
const HEAD_ROT_LIMIT := deg_to_rad(30)

@export var jump_strength := 4.0

@export var snap_length := 0.2

@onready var spawn_point := global_position
# references to children, using a child node export var
# so the references aren't fragile
@onready var _head: Node3D = $References.head
@onready var _fps_camera: Camera3D = $References.fps_camera
@onready var _tps_camera: Camera3D = $References.tps_camera
@onready var _death_player: AnimationPlayer = $References.death_player
@onready var _smoothing_nodes: Array[Smoothing] = $References.smoothing_nodes


## Get the gravity from the project settings to be synced with RigidBody nodes.
#var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var velocity := Vector3()

var _mouse_motion := Vector2()
var _is_on_floor := false
var _jump_grace := 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().root.physics_object_picking = true
	Globals.player = self

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_motion += event.relative
	else:
		if event.is_action_pressed("toggle_perspective"):
			if _fps_camera.current:
				_tps_camera.current = true
			else:
				_fps_camera.current = true

func _process(_delta: float):
	get_tree().root.warp_mouse(get_tree().root.size / 2.0)
	var cam_rot: float = _head.rotation.x - deg_to_rad(_mouse_motion.y * 0.1)
	cam_rot = clamp(cam_rot, -ROT_LIMIT, ROT_LIMIT)
	_fps_camera.rotation.x = cam_rot
	_head.rotation.x = cam_rot
	_mouse_motion.y = 0.0
	_head.rotation.y -= deg_to_rad(_mouse_motion.x * 0.1)
	_fps_camera.rotation.y = rotation.y + _head.rotation.y
	_mouse_motion.x = 0.0
	
	var space_state := get_world_3d().direct_space_state
	var mousepos: Vector2 = get_viewport().size * 0.5

	var origin := _fps_camera.global_position
	var end := origin + _fps_camera.project_ray_normal(mousepos) * 150.0
	# layer that selectable objects lie on
	const SELECTABLE_MASK := 0b1000_0000_0000_0000_0000_0000
	# layer that occluding objects lie on
	const OCCLUDING_MASK := 0b0001
	var query := PhysicsRayQueryParameters3D.create(origin, end, SELECTABLE_MASK | OCCLUDING_MASK)
	query.collide_with_areas = true
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		if result.collider.collision_mask & SELECTABLE_MASK != 0:
			result.collider.is_hovered_this_frame()

func _physics_process(delta: float) -> void:
	velocity = linear_velocity
	# animation
	_is_on_floor = is_on_floor()
	# rotate the body to keep the _head from having an unnatural angle.
	if _head.rotation.y > HEAD_ROT_LIMIT:
		rotation.y += _head.rotation.y - HEAD_ROT_LIMIT
		_head.rotation.y = HEAD_ROT_LIMIT
	elif _head.rotation.y < -HEAD_ROT_LIMIT:
		rotation.y += _head.rotation.y + HEAD_ROT_LIMIT
		_head.rotation.y = -HEAD_ROT_LIMIT
	# rotate the body towards linear_velocity
	if not (linear_velocity * Vector3(1.0, 0.0, 1.0)).is_zero_approx():
		# how much the head is rotated along with the player
		var head_rot := _head.rotation.y + rotation.y
		rotation.y = lerp_angle(
			rotation.y, 
			Vector3.FORWARD.signed_angle_to(linear_velocity * Vector3(1, 0, 1), Vector3.UP), 
			clamp(delta * linear_velocity.length(), 0.0, 1.0)
		)
		# restore the head's "global" (to the parent) rotation
		_head.rotation.y = head_rot - rotation.y
	
	# object interaction
	
	if Input.is_action_just_pressed("activate"):
		var space_state := get_world_3d().direct_space_state
		var mousepos: Vector2 = get_viewport().size * 0.5

		var origin := _fps_camera.global_position
		var end := origin + _fps_camera.project_ray_normal(mousepos) * 150.0
		# layer that selectable objects lie on
		const SELECTABLE_MASK := 0b1000_0000_0000_0000_0000_0000
		# layer that occluding objects lie on
		const OCCLUDING_MASK := 0b0001
		var query := PhysicsRayQueryParameters3D.create(origin, end, SELECTABLE_MASK | OCCLUDING_MASK)
		query.collide_with_areas = true
		
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			if result.collider.collision_mask & SELECTABLE_MASK != 0:
				result.collider.activate(self, (result.position - origin).length())
	
	# physics
	_jump_grace -= delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jump_grace = 0.1
		apply_central_impulse(Vector3(0.0, jump_strength * mass, 0.0))

	var facing_dir := transform.basis.rotated(Vector3.UP, _head.rotation.y)

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (facing_dir * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_factor := 4.0
	if direction and not is_on_floor() \
		and (direction * SPEED).length_squared() > (linear_velocity * Vector3(1.0, 0.0, 1.0)).length_squared():
		speed_factor = 0.5
	# deceleration
	elif not direction:
		speed_factor = 2.0 if is_on_floor() else 0.5
	var old_y := velocity.y
	velocity = velocity.lerp(direction * SPEED, clamp(speed_factor * SPEED * delta, 0.0, 1.0))
	velocity.y = old_y
	var velocity_error = velocity - linear_velocity
	velocity_error.y = 0.0
	var correction_impulse = velocity_error * delta * mass * 40.0
	apply_central_impulse(correction_impulse)
	if linear_velocity.y > 0.0:
		physics_material_override.friction = 0.1
	else:
		physics_material_override.friction = 0.0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var gravity = Vector3.ZERO
	var fl_nml = floor_normal()
	if fl_nml != Vector3.ZERO:
		gravity = state.total_gravity.length() * -fl_nml * state.step * 0.05
	else:
		gravity = state.total_gravity * state.step
	velocity += gravity
	linear_velocity += gravity
	
	if snap_length > 0.0 and  is_on_floor() and _jump_grace <= 0.0:
		var collision: KinematicCollision3D = move_and_collide(
			Vector3(0.0, -snap_length, 0.0), 
			true, 
			0.001, 
			true
		)
		if collision:
			global_position += collision.get_travel()
	# Handle stairs
	if is_on_floor():
		try_stair_teleport(state.step, state.total_gravity)

func is_on_floor() -> bool:
	if $FloorCast.is_colliding():
		for col_idx in $FloorCast.get_collision_count():
			var col_nml: Vector3 = $FloorCast.get_collision_normal(col_idx)
			if col_nml.angle_to(global_transform.basis.y) < deg_to_rad(30.0):
				return true
	return false

func floor_normal() -> Vector3:
	if $FloorCast.is_colliding():
		for col_idx in $FloorCast.get_collision_count():
			var col_nml: Vector3 = $FloorCast.get_collision_normal(col_idx)
			if col_nml.angle_to(global_transform.basis.y) < deg_to_rad(30.0):
				return col_nml
	return Vector3.ZERO

#func wall_normal(vel: Vector3, delta: float) -> Vector3:
#	$WallCast.target_position = vel * delta
#	$WallCast.force_shapecast_update()
#	if $WallCast.is_colliding():
#		var nml_total = Vector3.ZERO
#		for col_idx in $WallCast.get_collision_count():
#			nml_total += $WallCast.get_collision_normal(col_idx)
#		return (nml_total / float($WallCast.get_collision_count())).normalized()
#	return Vector3.ZERO

const STAIR_LENGTH: float = 0.1
const STAIR_HEIGHT: float = 0.35

func try_stair_teleport(delta: float, gravity: Vector3) -> void:
	var facing_dir := transform.basis.rotated(Vector3.UP, _head.rotation.y)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (facing_dir * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var step_test_vel = velocity + direction * STAIR_LENGTH * 2.0
	var move_rslts = KinematicCollision3D.new()
	if not test_move(global_transform, step_test_vel * delta, move_rslts):
		return
	var stair_cast: ShapeCast3D = $StairCast
	# first see how high we can step without hitting a ceiling
	stair_cast.position = Vector3.ZERO
	stair_cast.target_position = Vector3(0.0, STAIR_HEIGHT, 0.0)
	stair_cast.force_shapecast_update()
	# clamp is probably unnecessary but I'm not chancing it
	var eff_max_step: float = STAIR_HEIGHT * clampf(stair_cast.get_closest_collision_safe_fraction(), 0.0, 1.0)
	stair_cast.global_position.y += eff_max_step
	# see how far forward we can step
	var sdepth_max: Vector3 = ((step_test_vel * Vector3(1.0, 0.0, 1.0)) * delta)
	stair_cast.target_position = sdepth_max
	stair_cast.force_shapecast_update()
	var step_forward_dist: Vector3 = sdepth_max * clampf(stair_cast.get_closest_collision_safe_fraction(), 0.0, 1.0)
	if step_forward_dist.length() < STAIR_LENGTH - 0.18:
		return
	stair_cast.global_position += step_forward_dist
	# step back down to the ground
	stair_cast.target_position = Vector3(0.0, -STAIR_HEIGHT, 0.0)
	stair_cast.force_shapecast_update()
	var step_down_dist: float = -STAIR_HEIGHT * clampf(stair_cast.get_closest_collision_safe_fraction(), 0.0, 1.0)
	
	var is_floor = false
	var total_normal = Vector3.ZERO
	for col_idx in stair_cast.get_collision_count():
		if stair_cast.get_collision_normal(col_idx).angle_to(Vector3.UP) < deg_to_rad(30.0):
			is_floor = true
			break
		total_normal += stair_cast.get_collision_normal(col_idx)
	if not is_floor:
		is_floor = (total_normal / float(stair_cast.get_collision_count())).normalized().angle_to(Vector3.UP) < deg_to_rad(30.0)
	
	var step_height: float = stair_cast.position.y + step_down_dist
	if is_floor and step_height > STAIR_HEIGHT / 8.0:
		print(step_height)
		global_position.y += step_height - gravity.y * delta * 0.5
	

func die() -> void:
	global_position = spawn_point
	global_rotation = Vector3(0.0, 0.0, 0.0)
	_death_player.play("death_flash")


func _on_entered_death_collider(body: Node3D) -> void:
	print(body.name, " entered collision")
	if body == self:
		die()

func teleport(dest: Vector3) -> void:
	global_position = dest
	for node in _smoothing_nodes:
		node.teleport()

# Old implementation, works bad
#
#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#var delta := state.step
	#_jump_grace -= delta
	#linear_velocity = state.linear_velocity
	## Add the gravity.
	##if not is_on_floor():
	#linear_velocity.y -= gravity * delta
#
	## Handle Jump.
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#_is_on_floor = false
		#_jump_grace = 0.1
		#linear_velocity.y = JUMP_VELOCITY
#
	#var facing_dir := transform.basis.rotated(Vector3.UP, _head.rotation.y)
#
	## Get the input direction and handle the movement/deceleration.
	#var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	#var direction := (facing_dir * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	#var speed_factor := 4.0
	#if direction and not is_on_floor() \
		#and (direction * SPEED).length_squared() > (linear_velocity * Vector3(1.0, 0.0, 1.0)).length_squared():
		#speed_factor = 1.0
	## deceleration
	#elif not direction:
		#speed_factor = 2.0 if is_on_floor() else 0.5
	#var old_y := linear_velocity.y
	#linear_velocity = linear_velocity.lerp(direction * SPEED, clamp(speed_factor * SPEED * delta, 0.0, 1.0))
	#linear_velocity.y = old_y
	## if we were on the floor last frame snap to the floor this frame
	#if is_on_floor():
		#var collision: KinematicCollision3D = move_and_collide(
			#Vector3(0.0, -0.2, 0.0), 
			#true, 
			#0.001, 
			#true
		#)
		#if collision:
			#state.transform.origin += collision.get_travel()
		#else:
			#_is_on_floor = false
	#elif _jump_grace <= 0.0:
		## test for floor collision
		#_is_on_floor = false
		#var collision: KinematicCollision3D = move_and_collide(
			#Vector3(0.0, -gravity * delta, 0.0), 
			#true, 
			#0.001, 
			#true,
			#5)
		#if collision:
			#for cidx in collision.get_collision_count():
				#if collision.get_normal(cidx).angle_to(Vector3.UP) < deg_to_rad(30.0):
					#_is_on_floor = true
		#state.linear_velocity = linear_velocity
