extends SceneTree
## Contact sheet of every glTF/GLB in a folder, rendered at the game's camera angle.
## godot --path . --script res://tools/preview_models.gd -- --dir=<abs dir> --out=<png> [--filter=text]

func _init() -> void:
	_run.call_deferred()

func _arg(name: String, def: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st) as Node3D

func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var stack := [[n, xf]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		for c in node.get_children():
			stack.append([c, t])
	return box

func _run() -> void:
	var dir := _arg("dir")
	var out := _arg("out")
	var filt := _arg("filter")
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if (f.ends_with(".gltf") or f.ends_with(".glb")) and (filt == "" or f.contains(filt)):
			files.append(f)
	files.sort()
	var cols := 8
	var cell := 200
	var rows := int(ceil(files.size() / float(cols)))
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * cell, rows * cell)
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-38, 0, 0)
	world.add_child(cam)
	cam.current = true
	# lay models on a grid in camera-aligned screen space, each scaled to fit its cell
	var spacing := 4.0
	cam.size = rows * spacing
	var right := cam.transform.basis.x
	var up := cam.transform.basis.y
	var i := 0
	for f in files:
		var m := _load(dir + "/" + f)
		if m == null:
			continue
		var box := _aabb(m, Transform3D.IDENTITY)
		var s := 3.0 / maxf(0.001, maxf(box.size.x, maxf(box.size.y, box.size.z)))
		m.scale = Vector3(s, s, s)
		var cx := (i % cols - (cols - 1) * 0.5) * spacing
		var cy := -((i / cols) - (rows - 1) * 0.5) * spacing
		var center := right * cx + up * cy
		m.position = center - (box.get_center() * s)
		world.add_child(m)
		print("%d %s %s" % [i, f, str(box.size)])
		i += 1
	cam.position = cam.transform.basis.z * 60.0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	quit()
