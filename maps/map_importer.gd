@tool
extends EditorScenePostImport

const COLLISION_MASK = 0b111

func _post_import(scene: Node) -> Object:
	iterate(scene)
	return scene # Remember to return the imported scene

# Recursive function that is called on every node
# (for demonstration purposes; EditorScenePostImport only requires a `_post_import(scene)` function).
func iterate(node: Node):
	if node != null:
		if node is StaticBody3D:
			print("Found body ", node.name)
			(node as StaticBody3D).collision_mask = COLLISION_MASK
		for child in node.get_children():
			iterate(child)
