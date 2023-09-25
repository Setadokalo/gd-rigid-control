@tool
extends MultiMeshInstance3D

@export var bounds: Rect2:
	set(nb):
		bounds = nb
		place_grass()

func place_grass() -> void:
	for i in multimesh.instance_count:
		multimesh.set_instance_transform_2d(
			i,
			Transform2D(0.0, bounds.position + bounds.size * Vector2(randf(), randf()))
		)

func _ready() -> void:
	place_grass()
