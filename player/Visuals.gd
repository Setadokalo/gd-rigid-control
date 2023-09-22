extends Node3D

var time_accum := 0.0

@onready var legl: Node3D = $"LegL"
@onready var legr: Node3D = $"LegR"
@onready var arml: Node3D = $"ArmL"
@onready var armr: Node3D = $"ArmR"
@onready var head: Node3D = $"../../Head"

func _process(delta: float) -> void:
	var velocity: Vector3 = get_parent().get_parent().linear_velocity
	time_accum += 2.0 * delta * velocity.length()
	var rotamount: float = clamp(velocity.length() * 0.2, -0.6666, 0.6666)
	legl.rotation.x = sin(time_accum) * rotamount
	armr.rotation.x = sin(time_accum) * rotamount
	legr.rotation.x = -sin(time_accum) * rotamount
	arml.rotation.x = -sin(time_accum) * rotamount
	position.y =  + cos(time_accum * 2.0) * rotamount * 0.05
	head.position.y = 0.579 + position.y
	if velocity.is_zero_approx():
		time_accum = 0.0
