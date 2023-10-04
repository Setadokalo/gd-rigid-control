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
	if node.name.ends_with("-fixed"):
		var size_request_str: String = node.name.trim_suffix("-fixed")
		var request_start = size_request_str.rfind("-") + 1
		size_request_str = size_request_str.substr(request_start)
		var size_request_split: PackedStringArray = size_request_str.split("x")
		if size_request_split.size() == 2:
			var size_request := Vector2.ZERO
			size_request.x = float(size_request_split[0])
			size_request.y = float(size_request_split[1])
			var new_mesh := QuadMesh.new()
			new_mesh.size = size_request * PIXEL_SCALE
			for surf_idx in new_mesh.get_surface_count():
				new_mesh.surface_set_material(surf_idx, fix_material(mesh.surface_get_material(surf_idx), ShadingType.BILLBOARD))
			node.mesh = new_mesh
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
