extends ReflectionProbe

func _process(delta: float) -> void:
	var cam_pos: Vector3 = get_viewport().get_camera_3d().global_transform.origin
	var cam_offs = cam_pos - global_transform.origin
	origin_offset = cam_offs
	origin_offset.z = origin_offset.z
	
