@tool
extends EditorScenePostImport

# Called right after the scene is imported and gets the root node.
func _post_import(scene: Node) -> Object:
	iterate(scene)
	return scene # Remember to return the imported scene

func iterate(node: Node):
	if node != null:
		if node.name.ends_with("-noimp"):
			node.get_parent().remove_child(node)
			node.queue_free()
			return
		if node.get("mesh") is Mesh:
			var mesh: Mesh = node.get("mesh")
			for surf_idx in mesh.get_surface_count():
				mesh.surface_set_material(surf_idx, fix_material(mesh.surface_get_material(surf_idx)))
		for child in node.get_children():
			iterate(child)

func fix_material(old_mat: BaseMaterial3D) -> ShaderMaterial:
	var new_mat: ShaderMaterial = ShaderMaterial.new()
	new_mat.shader = preload("res://pixel_lighting.gdshader")
	new_mat.set_shader_parameter("color", old_mat.albedo_color)
	new_mat.set_shader_parameter("emission", old_mat.emission)
	new_mat.set_shader_parameter("albedo_texture", old_mat.albedo_texture)
	return new_mat
