extends VideoStreamPlayer

@export_file("*.tscn") var main_scene_path: String = "res://main.tscn"

@export var must_play_entire_splash := true

# Called when the node enters the scene tree for the first time.
@onready var should_be_resizable: bool = get_tree().root.unresizable

func _ready() -> void:
	get_tree().root.unresizable = true
	var rq = ResourceLoader.load_threaded_request(main_scene_path, "", true)

var _prev_img: Image
func _process(delta: float) -> void:
	var img = get_video_texture().get_image()
	if img.get_pixel(0, 0).a == 0 and $TextureRect.texture == null:
		$TextureRect.texture = ImageTexture.create_from_image(_prev_img)
	else:
		_prev_img = img
	if not (is_playing() and must_play_entire_splash) and ResourceLoader.load_threaded_get_status(main_scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		_on_finished_loading(ResourceLoader.load_threaded_get(main_scene_path))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):
		get_tree().reload_current_scene()

func _on_finished_playing() -> void:
	print("Loading scene now, setting resizable to ", not should_be_resizable)
	get_tree().create_timer(2.0).timeout.connect(func():
		get_tree().create_tween().tween_property($TextureProgressBar, ^"modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0)
	)


func _on_finished_loading(scene: PackedScene) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self, ^"modulate", Color(0.0, 0.0, 0.0, 1.0), 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_packed(scene))
