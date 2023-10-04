extends RichTextLabel

@export var target: Node
@export var properties: Array[String] = []
@export_multiline var format_string: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not target:
		text = "[Target not initialized]"
		return
	var data := []
	data.resize(properties.size())
	for p_idx in properties.size():
		data[p_idx] = target.get(properties[p_idx])
	text = format_string % data
