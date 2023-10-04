class_name Player
extends RigidBody3D

signal died

const RUN_SPEED := 8.0
const WALK_SPEED := 3.0
const WALK_ANIM_SPEED := 3.5
const JUMP_VELOCITY := 4.5

const ROT_LIMIT: float = PI / 2.0 - 0.01
const HEAD_ROT_LIMIT: float = deg_to_rad(30)

const ISOMETRIC_MODE: bool = true

@export var jump_strength := 4.0

@export var snap_length := 0.2

@export var kbm_lock_sprint := false
@export var joy_lock_sprint := true


@onready var spawn_point := global_position
# references to children, using a child node export var
# so the references aren't fragile
@onready var _death_player: AnimationPlayer = $References.death_player
@onready var _smoothing_nodes: Array[Smoothing] = $References.smoothing_nodes
@onready var _run_smoke: GPUParticles3D = $References.run_smoke
@onready var _stop_smoke: GPUParticles3D = $References.stop_smoke
@onready var _jump_smoke: GPUParticles3D = $References.jump_smoke

var velocity := Vector3()
var running := false

var _mouse_motion := Vector2()
var _is_on_floor := false
var _jump_grace := 0.0

func _ready():
	get_tree().root.physics_object_picking = true
	Engine.time_scale = 1.0
	Globals.player = self

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_motion += event.relative
	if event.is_action_pressed("sprint_kb") or event.is_action_pressed("sprint_ctrlr"):
		running = true
	if event.is_action_released("sprint_kb"):
		running = kbm_lock_sprint
	if event.is_action_released("sprint_ctrlr"):
		running = joy_lock_sprint

func _process(_delta: float):
	var space_state := get_world_3d().direct_space_state
	var mousepos: Vector2 = get_viewport().get_mouse_position()

	var origin := get_viewport().get_camera_3d().global_position
	var end := origin + get_viewport().get_camera_3d().project_ray_normal(mousepos) * 150.0
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

func get_input_dir() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var facing_z: Vector3 
	if not ISOMETRIC_MODE:
		var vec_to_cam := cam.global_position - global_position
		vec_to_cam.y = 0.0
		facing_z = vec_to_cam.normalized()
	else:
		facing_z = (cam.global_transform.basis.z * Vector3(1.0, 0.0, 1.0)).normalized()
	var facing_y := Vector3.UP
	var facing_x := facing_z.rotated(facing_y, PI/2.0)
	var facing_dir := Basis(facing_x, facing_y, facing_z)

	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
#	input_dir = input_dir.normalized() * input_dir.length_squared()
	return (facing_dir * Vector3(input_dir.x, 0, input_dir.y)).limit_length()

func _physics_process(delta: float) -> void:
	var old_vel = linear_velocity
	velocity = linear_velocity
	var flat_vel = velocity * Vector3(1.0, 0.0, 1.0)
	
	# physics
	_jump_grace -= delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_jump_grace = 0.1
		apply_central_impulse(Vector3(0.0, jump_strength * mass, 0.0))
		$SmoothedVisuals/AnimationTree.set("parameters/jumpshot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	var direction = get_input_dir()
	
	if direction.is_zero_approx() and velocity.length_squared() < (WALK_SPEED * WALK_SPEED):
		running = Input.is_action_pressed("sprint_ctrlr") or Input.is_action_pressed("sprint_kb")
	
	var target_speed = RUN_SPEED if running else WALK_SPEED
	
	var speed_factor := 2.0
	
	if direction and not is_on_floor() \
		and (direction * target_speed).length_squared() > (flat_vel).length_squared():
		speed_factor = 1.5
	# deceleration
	elif not direction:
		speed_factor = 2.0 if is_on_floor() else 0.5
	var old_y := velocity.y
	velocity = velocity.lerp(direction * target_speed, clamp(speed_factor * target_speed * delta, 0.0, 1.0))
	velocity.y = old_y
	var velocity_error = velocity - linear_velocity
	velocity_error.y = 0.0
	var correction_impulse = velocity_error * delta * mass * 40.0
	apply_central_impulse(correction_impulse)
	if linear_velocity.y > 0.0:
		physics_material_override.friction = 0.1
	else:
		physics_material_override.friction = 0.0
	
	# rotate towards velocity
	
	_is_on_floor = is_on_floor()
	if flat_vel.length_squared() > 0.1:
		global_transform.basis = global_transform.basis.slerp(
			global_transform.looking_at(position + flat_vel).basis, 
			delta * flat_vel.length() * 4.0
		)
	
	# update animation
	
	if not is_on_floor():
		if $SmoothedVisuals/AnimationTree.get("parameters/jumptrans/current_state") != "airborne":
			$SmoothedVisuals/AnimationTree.set("parameters/jumptrans/transition_request", "airborne") 
	else:
		if $SmoothedVisuals/AnimationTree.get("parameters/jumptrans/current_state") != "grounded":
			$SmoothedVisuals/AnimationTree.set("parameters/jumptrans/transition_request", "grounded") 
	
	var flat_local_vel := (velocity * global_transform.basis) * Vector3(1.0, 0.0, -1.0)
	# walk speed as a fraction of run speed
	const WR := WALK_ANIM_SPEED/RUN_SPEED
	# movement speed
	var m := flat_local_vel.length()
	# movement speed as a fraction of walking speed
	var mw := clampf(m/WALK_ANIM_SPEED, 0.0, 1.0)
	# movement speed as a fraction of running speed
	var mr := m/RUN_SPEED
	# idle blends from full influence to zero influence when moving at 25% walking speed
	$SmoothedVisuals/AnimationTree.set(
		"parameters/idleblend/blend_amount", 
		clampf(mw * 4.0, 0.0, 1.0)
	)
	# walk animation speeds up as movement speed goes from 25% to 100% walk speed
	$SmoothedVisuals/AnimationTree.set(
		"parameters/walkspeed/scale", 
		clampf((mw-0.25)*1.33333333, 0.0, 1.0) * 0.75 + 0.25
	)
	# run animation blends in as movement speed goes from walk speed to run speed
	$SmoothedVisuals/AnimationTree.set(
		"parameters/runblend/blend_amount", 
		clampf((mr - WR)/(1.0-WR), 0.0, 1.0)
	)
	$SmoothedVisuals/AnimationTree.set(
		"parameters/jumpblend/blend_amount", 
		1.0 if is_on_floor() else 0.0
	)
	_run_smoke.emitting = is_on_floor() and velocity.length() > WALK_SPEED * 1.5
	_stop_smoke.emitting = is_on_floor() and old_vel.length() - velocity.length() > 0.5
	_jump_smoke.emitting = _jump_grace > 0.0
	# player exclusive logic
	
	# object interaction
	
	if Input.is_action_just_pressed("activate"):
		var space_state := get_world_3d().direct_space_state
		var camera: Camera3D = get_viewport().get_camera_3d()
		var mousepos: Vector2 = get_viewport().get_mouse_position()
		var origin := camera.global_position
		var end := origin + camera.project_ray_normal(mousepos) * 150.0
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
	

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var gravity = Vector3.ZERO
	var fl_nml = floor_normal()
	if fl_nml != Vector3.ZERO:
		gravity = state.total_gravity.length() * -fl_nml * state.step * 0.25
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

const STAIR_LENGTH: float = 0.1
const STAIR_HEIGHT: float = 0.75

func try_stair_teleport(delta: float, gravity: Vector3) -> void:
	var direction := get_input_dir()
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

func teleport(dest: Vector3) -> void:
	global_position = dest
	for node in _smoothing_nodes:
		node.teleport()

func die() -> void:
	global_position = spawn_point
	global_rotation = Vector3(0.0, 0.0, 0.0)
	died.emit()
