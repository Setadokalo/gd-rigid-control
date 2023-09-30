extends Node

func _ready() -> void:
	await get_tree().process_frame
	var spf = DebugDraw2D.create_fps_graph("SPF")
	spf.offset = Vector2i(2, 2)
	spf.size = Vector2i(96, 48)
	spf.text_size = 6
	spf.show_text_flags = DebugDrawGraph.TEXT_ALL & (~DebugDrawGraph.TEXT_CURRENT)
