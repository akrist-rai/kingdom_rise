extends SceneTree
## Prints skeleton bones (name, parent, rest origin) of a glTF/GLB.
func _init() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(path, st)
	var n := doc.generate_scene(st)
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_rest(i)
		print("%d %s parent=%d pos=%s" % [i, sk.get_bone_name(i), sk.get_bone_parent(i), str(g.origin.snapped(Vector3.ONE * 0.01))])
	print("skeleton xform ", sk.global_transform if sk.is_inside_tree() else sk.transform)
	var p: Node = sk.get_parent()
	while p:
		if p is Node3D:
			print("parent ", p.name, " scale ", (p as Node3D).scale, " pos ", (p as Node3D).position, " rot ", (p as Node3D).rotation_degrees)
		p = p.get_parent()
	quit()
