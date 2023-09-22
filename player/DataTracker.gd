extends Label

@export var target: Node
@export var properties: Array[String] = []
@export_multiline var format_string: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var data := []
	for property in properties:
		data.push_back(target.get(property))
	text = format_string % data
