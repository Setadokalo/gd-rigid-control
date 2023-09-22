extends TextureProgressBar

var growing := true

func _process(delta: float) -> void:
	var val_offs = delta * 180.0 * get_growth_factor(value)
	if value >= 360.0 or growing == false:
		growing = false
		value -= val_offs
	if value <= 0.0:
		growing = true
	if growing:
		value += val_offs
	radial_initial_angle += delta * 360.0


func get_growth_factor(val: float) -> float:
	var nml = val / 180.0
	return sin((nml - 0.5) * PI) * 0.5 + 1.0
