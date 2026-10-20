extends SceneTree
## Prints the node tree Godot generates for a glTF file.
## godot --path . --script res://tools/dump_tree.gd -- --file=<abs path>

func _init() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			path = a.substr(7)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(path, st)
	var n := doc.generate_scene(st)
	_dump(n, 0)
	var box := AABB()
	quit()

func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is BoneAttachment3D:
		extra = " bone=" + (n as BoneAttachment3D).bone_name
	if n is MeshInstance3D:
		var m := (n as MeshInstance3D).mesh
		extra = " aabb=" + str(m.get_aabb()) if m else ""
	if n is Skeleton3D:
		extra = " bones=%d" % (n as Skeleton3D).get_bone_count()
	print("  ".repeat(d) + n.name + " <" + n.get_class() + ">" + extra)
	for c in n.get_children():
		_dump(c, d + 1)
