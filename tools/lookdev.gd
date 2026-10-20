extends SceneTree
## Look-dev: knights under several lighting / shading setups (one row each), to pick the
## bake look. godot --path . --script res://tools/lookdev.gd -- --out=<png>

const ELEV := 40.0

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
	doc.append_from_file(ProjectSettings.globalize_path(path), st)
	return doc.generate_scene(st) as Node3D

func _each(n: Node, cb: Callable) -> void:
	cb.call(n)
	for c in n.get_children():
		_each(c, cb)

func _setup_row(world: Node3D, row: int, mode: int, cam: Camera3D) -> void:
	var anims := [["Idle", 0.0], ["Running_A", 0.3], ["1H_Melee_Attack_Slice_Diagonal", 0.45], ["2H_Melee_Attack_Chop", 0.6]]
	var dirs := [0.0, 45.0, 90.0, 135.0, 180.0]
	var col := 0
	for a in anims:
		for d in dirs:
			if col >= 10:
				break
			var k := _load("res://art_src/kaykit_adventurers/Knight.glb")
			_each(k, func(n):
				if n is MeshInstance3D:
					var nm := String(n.name)
					if nm in ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword", "Knight_Cape"]:
						n.visible = false
					var mi := n as MeshInstance3D
					for s in mi.mesh.get_surface_count():
						var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
						if m:
							m = m.duplicate()
							match mode:
								1:
									m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
									m.specular_mode = BaseMaterial3D.SPECULAR_TOON
								2:
									m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
									m.rim_enabled = true
									m.rim = 0.6
									m.rim_tint = 0.4
								3:
									m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
									m.rim_enabled = true
									m.rim = 0.5
									m.roughness = 0.9
							mi.set_surface_override_material(s, m)
			)
			k.rotation_degrees.y = d
			var sp := Vector2(80 + col * 160, 110 + row * 200)
			var o := cam.project_ray_origin(sp)
			var nrm := cam.project_ray_normal(sp)
			var t := -o.y / nrm.y
			k.position = o + nrm * t
			world.add_child(k)
			var ap: AnimationPlayer = k.get_node("AnimationPlayer")
			ap.play(a[0])
			ap.seek(a[1], true)
			ap.pause()
			col += 1

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1600, 800)
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.42)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.7, 0.84)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.85
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.95, 0.86)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-ELEV, 0, 0)
	cam.size = 800.0 / 36.0   # 36 px per metre (= 3 px per world unit at 12 wu / m)
	cam.position = cam.transform.basis.z * 40.0
	world.add_child(cam)
	cam.current = true
	await process_frame
	for row in 4:
		_setup_row(world, row, row, cam)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_arg("out"))
	quit()
