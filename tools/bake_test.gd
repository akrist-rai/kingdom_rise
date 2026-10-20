extends SceneTree
## Quick look-dev render: one character in several directions and poses.
## godot --path . --script res://tools/bake_test.gd -- --out=<dir>

var out_dir := "user://"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	_run.call_deferred()

func _load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(path), st)
	if err != OK:
		push_error("gltf load failed %s %d" % [path, err])
		return null
	return doc.generate_scene(st) as Node3D

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 640)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.66, 0.78)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.9)
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	var elev := 38.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--elev="):
			elev = float(a.substr(7))
	cam.rotation_degrees = Vector3(-elev, 0, 0)
	cam.position = Vector3(0, 1.0, 0) + cam.transform.basis.z * 20.0
	world.add_child(cam)
	cam.current = true
	var poses := [["Idle", 0.0], ["Running_A", 0.2], ["1H_Melee_Attack_Slice_Diagonal", 0.35], ["2H_Melee_Attack_Chop", 0.5], ["Hit_A", 0.2], ["Death_A", 1.2]]
	var dirs := [90.0, 45.0, 0.0, -45.0, -90.0]
	var chars: Array = []
	for i in poses.size():
		for j in dirs.size():
			var k := _load_glb("res://art_src/kaykit_adventurers/Knight.glb")
			world.add_child(k)
			k.position = Vector3((j - 2) * 2.2, 0, (i - 2.5) * 1.6)
			k.rotation_degrees.y = dirs[j]
			var ap := _find_anim(k)
			if ap:
				ap.play(poses[i][0])
				ap.seek(poses[i][1], true)
				ap.pause()
			chars.append(k)
	cam.size = 11.0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(out_dir + "/bake_test_%d.png" % int(elev))
	print("saved")
	quit()
