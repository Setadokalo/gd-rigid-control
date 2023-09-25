extends SubViewportContainer

func _ready() -> void:
	await get_tree().process_frame
	DebugDraw2D.create_fps_graph("FPS").frame_time_mode = false
	DebugDraw2D.create_fps_graph("SPF").corner = DebugDrawGraph.POSITION_LEFT_TOP
