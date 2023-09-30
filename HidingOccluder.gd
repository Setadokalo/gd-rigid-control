extends CSGBox3D

@export var fade_speed := 5.0
@export_exp_easing("attenuation") var fade_curve := 1.0

var _fade_level := 0.0
var _fade_frames := 0

func _ready() -> void:
	await get_tree().process_frame
	crawl_children_make_unique(self)


func crawl_children_make_unique(node) -> void:
	node.material = node.material.duplicate()
	node.material.set_shader_parameter("fade", pow(_fade_level, fade_curve))
	for child in node.get_children():
		if child.get("material") is ShaderMaterial:
			crawl_children_make_unique(child)


func _process(delta: float) -> void:
	if _fade_frames > 0:
		_fade_frames -= 1
	if _fade_frames == 0:
		_fade_level = clamp(_fade_level - delta * fade_speed, 0.0, 1.0)
	else:
		_fade_level = clamp(_fade_level + delta * fade_speed, 0.0, 1.0)
	crawl_children(self)

func crawl_children(node) -> void:
	node.material.set_shader_parameter("fade", pow(_fade_level, fade_curve))
	for child in node.get_children():
		if child.get("material") is ShaderMaterial:
			crawl_children(child)

func inform_occluding() -> void:
	_fade_frames = 2
