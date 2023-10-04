extends DirectionalLight3D

signal fast_forward_state_changed(new_state: bool)

var fast_forward = false

@export var color_ramp := Gradient.new()
@export var bg_color_ramp := Gradient.new()
@export var day_length := 120.0

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fast_forward"):
		fast_forward_state_changed.emit(true)
		fast_forward = true
	elif event.is_action_released("fast_forward"):
		fast_forward_state_changed.emit(false)
		fast_forward = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rotation.x += delta / day_length * (60.0 if fast_forward else 1.0)
	light_color = color_ramp.sample(absf(cos(rotation.x)))
	get_parent().environment.background_color = bg_color_ramp.sample(sin(rotation.x) * -0.5 + 0.5)
	var light_fade = clamp((global_transform.basis.z.y + 0.25) * 4.0, 0.0, 1.0)
	light_energy = light_fade
	light_fade = clamp(($Moon.global_transform.basis.z.y + 0.25) * 4.0, 0.0, 1.0)
	$Moon.light_energy = light_fade
