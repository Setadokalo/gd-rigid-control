@tool
extends EditorScenePostImport

# Called right after the scene is imported and gets the root node.
func _post_import(scene: Node) -> Object:
	iterate(scene)
	return scene # Remember to return the imported scene

const PIXEL_SCALE: float = 0.00961538461538461538

func iterate(node: Node):
	if node != null:
		if node.get("mesh") is Mesh:
			try_fix(node)
		for child in node.get_children():
			iterate(child)

func try_fix(node: Node):
	var mesh: Mesh = node.get("mesh")
	# special flag indicating a mesh should be fixed in size to the screen
	if node.name.ends_with("-fixed"):
		var size_request_str: String = node.name.trim_suffix("-fixed")
		var request_start = size_request_str.rfind("-") + 1
		size_request_str = size_request_str.substr(request_start)
		var size_request_split: PackedStringArray = size_request_str.split("x")
		if size_request_split.size() == 2:
			var size_request := Vector2.ZERO
			size_request.x = float(size_request_split[0])
			size_request.y = float(size_request_split[1])
			attach_to_bone(node, size_request)
			return
		else:
			printerr("invalid mesh name for fixed operation")
	for surf_idx in mesh.get_surface_count():
		mesh.surface_set_material(surf_idx, fix_material(mesh.surface_get_material(surf_idx)))

enum ShadingType {
	CAVITY,
	# not implemented
	NO_CAVITY,
	BILLBOARD
}

func attach_to_bone(node: Node, size_request: Vector2):
	if not node.mesh is ArrayMesh:
		printerr("Cannot attach non-arraymesh to bone")
		return null
	var mesh: ArrayMesh = node.mesh
	var bone: int = -1
	
	if mesh.get_surface_count() == 0:
		return
	
	var fmt = mesh.surface_get_format(0)
	if fmt & (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS) != (Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS):
		return
	var data = mesh.surface_get_arrays(0)
	var bones = data[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
	
	var max_found_weight = 0
	for w_idx in weights.size():
		if weights[w_idx] > weights[max_found_weight]:
			max_found_weight = w_idx
	bone = bones[max_found_weight]
	print("Binding to ", node.skin.get_bind_name(bone))
	
	var new_mesh := QuadMesh.new()
	new_mesh.size = size_request * PIXEL_SCALE * 1.0
	for surf_idx in new_mesh.get_surface_count():
		new_mesh.surface_set_material(surf_idx, fix_material(mesh.surface_get_material(surf_idx), ShadingType.BILLBOARD))
	node.mesh = new_mesh
	var bone_position = node.get_node(node.skeleton).get_bone_global_rest(bone).origin + node.get_node(node.skeleton).get_parent().position
	var avg_position := Vector3()
	for vert in data[Mesh.ARRAY_VERTEX]:
		print(vert)
		avg_position += vert
	avg_position = avg_position / float(data[Mesh.ARRAY_VERTEX].size())
	print(avg_position)
	print(bone_position)
	var offset = avg_position - bone_position
	
	var bone_parent := BoneAttachment3D.new()
	node.get_parent().add_child(bone_parent)
	bone_parent.bone_idx = bone
	bone_parent.owner = bone_parent.get_parent().get_parent().get_parent()
	bone_parent.name = "Attachment" + node.name
	node.get_parent().remove_child(node)
	bone_parent.add_child(node)
	node.position = offset
	node.add_to_group("pixel_lock", true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func fix_material(old_mat: BaseMaterial3D, shading := ShadingType.CAVITY) -> ShaderMaterial:
	var new_mat: ShaderMaterial = ShaderMaterial.new()
	if shading == ShadingType.CAVITY:
		new_mat.shader = preload("res://assets/pixel_cavity.gdshader")
	elif shading == ShadingType.BILLBOARD:
		new_mat.shader = preload("res://assets/pixel_no_cavity.gdshader")
	else:
		printerr("not implemented")
		new_mat.shader = preload("res://assets/pixel_cavity.gdshader")
	new_mat.set_shader_parameter("color", old_mat.albedo_color)
	new_mat.set_shader_parameter("emission", old_mat.emission)
	new_mat.set_shader_parameter("albedo_texture", old_mat.albedo_texture)
	return new_mat
