extends Node3D

var time_accum := 0.0

@onready var legl: Node3D = $"LegL"
@onready var legr: Node3D = $"LegR"
@onready var arml: Node3D = $"ArmL"
@onready var arml_l: Node3D = $"ArmL/ArmLLower"
@onready var armr: Node3D = $"ArmR"
@onready var armr_l: Node3D = $"ArmR/ArmRLower"
@onready var head: Node3D = $"Head"

func _process(delta: float) -> void:
	var velocity: Vector3 = get_parent().get_parent().linear_velocity
	if get_parent().get_parent().is_on_floor():
		velocity.y = 0.0
	time_accum += 2.0 * delta * velocity.length()
	var rotamount: float = clamp(velocity.length() * 0.2, -0.6666, 0.6666)
	legl.rotation.x = sin(time_accum) * rotamount
	armr.rotation.x = sin(time_accum) * rotamount * 0.75
	armr_l.rotation.x = clamp(sin(time_accum + PI * 0.5) * rotamount * 0.5 + 0.25, 0.0, PI)
	legr.rotation.x = -sin(time_accum) * rotamount
	arml.rotation.x = -sin(time_accum) * rotamount * 0.75
	arml_l.rotation.x = clamp(sin(time_accum - PI * 0.5) * rotamount * 0.5 + 0.25, 0.0, PI)
	position.y =  + cos(time_accum * 2.0) * rotamount * 0.05
	head.position.y = 0.579 + position.y
	if velocity.is_zero_approx():
		time_accum = 0.0
