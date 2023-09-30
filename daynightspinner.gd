extends DirectionalLight3D

@export var color_ramp := Gradient.new()
@export var bg_color_ramp := Gradient.new()
@export var day_length := 120.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("fast_forward"):
		$Panel.visible = true
		rotation.x += delta / day_length * 60.0
	else:
		$Panel.visible = false
		rotation.x += delta / day_length
	light_color = color_ramp.sample(absf(cos(rotation.x)))
	get_parent().environment.background_color = bg_color_ramp.sample(sin(rotation.x) * -0.5 + 0.5)
