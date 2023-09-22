@tool
extends PhysicsBody3D

@export var size := Vector3(1.0, 1.0, 1.0):
	set(v):
		size = v
		if get_node_or_null("Smoothing/MeshInstance3D") != null:
			$CollisionShape3D.shape.size = size
			$Smoothing/MeshInstance3D.mesh.size = size

@export var material: Material = StandardMaterial3D.new():
	set(v):
		material = v
		if get_node_or_null("Smoothing/MeshInstance3D") != null:
			$Smoothing/MeshInstance3D.material_override = v

func _ready() -> void:
	$CollisionShape3D.shape = $CollisionShape3D.shape.duplicate()
	$Smoothing/MeshInstance3D.mesh = $Smoothing/MeshInstance3D.mesh.duplicate()
	$Smoothing/MeshInstance3D.material_override = $Smoothing/MeshInstance3D.material_override.duplicate()
	
	$CollisionShape3D.shape.size = size
	$Smoothing/MeshInstance3D.mesh.size = size
	$Smoothing/MeshInstance3D.material_override = material
