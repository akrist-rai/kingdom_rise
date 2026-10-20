extends SceneTree
## Contact sheet of baked unit frames, composited with the runtime shader.
## godot --path . --script res://tools/preview_units.gd -- --body=knight_1h --wpn=wpn_1h_sword_shield --out=<png> [--anims=idle,run,a1]

const DIR8 := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const MIRROR := {"sw": "se", "w": "e", "nw": "ne"}

func _init() -> void:
	_run.call_deferred()

func _arg(name: String, def: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return def

func _pages(entry: Dictionary) -> Array:
	var out: Array = []
	for f in entry["pages"]:
		out.append(ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/units/" + f))))
	return out

func _run() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/units.json"))
	var body_key := _arg("body", "knight_1h")
	var wpn_key := _arg("wpn", "")
	var body: Dictionary = meta["bodies"][body_key]
	var wpn = meta["weapons"].get(wpn_key, null)
	var bp := _pages(body)
	var wp: Array = _pages(wpn) if wpn != null else []
	var anims := _arg("anims", "idle,run,walk,a1,a2,a3,a4,hit,death,dodge,block,kick").split(",")
	var cell := Vector2(76, 84)
	var sz := Vector2i(int(cell.x * 8 * 2), int(cell.y * anims.size()))
	var vp := SubViewport.new()
	vp.size = sz
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.48, 0.55, 0.36)
	bg.size = Vector2(sz)
	vp.add_child(bg)
	var sh: Shader = load("res://shaders/unit.gdshader")
	var mats: Array = []
	for f in 2:
		var m := ShaderMaterial.new()
		m.shader = sh
		if f == 1:
			m.set_shader_parameter("team_hi", Color(0.5, 0.78, 0.92))
			m.set_shader_parameter("team_mid", Color(0.16, 0.42, 0.62))
			m.set_shader_parameter("team_lo", Color(0.05, 0.12, 0.25))
			m.set_shader_parameter("steel_tint", Vector3(0.9, 0.97, 1.07))
		else:
			m.set_shader_parameter("steel_tint", Vector3(1.05, 0.98, 0.9))
		mats.append(m)
	var r: float = meta["r"]
	for row in anims.size():
		var ak: String = anims[row]
		for half in 2:
			for di in 8:
				var d: String = DIR8[di]
				var src: String = MIRROR.get(d, d)
				var flip := MIRROR.has(d)
				var key := "%s/%s" % [ak, src]
				if not body["anims"].has(key):
					continue
				var frames: Array = body["anims"][key]
				var fi := int(frames.size() * 0.5) if half == 1 else 0
				if ak in ["a1", "a2", "a3", "a4"] and half == 1:
					fi = 3
				var foot := Vector2((half * 8 + di + 0.5) * cell.x, (row + 0.82) * cell.y)
				for layer in 2:
					var src_meta: Dictionary = body if layer == 0 else (wpn if wpn != null else {})
					if src_meta.is_empty():
						continue
					var fr = src_meta["anims"][key][fi]
					if fr == null:
						continue
					var s := Sprite2D.new()
					s.texture = (bp if layer == 0 else wp)[int(fr[0])]
					s.region_enabled = true
					s.region_rect = Rect2(fr[1], fr[2], fr[3], fr[4])
					s.centered = false
					s.flip_h = flip
					var ax: float = fr[5]
					if flip:
						ax = float(fr[3]) - ax
					s.offset = Vector2(-ax, -float(fr[6]))
					s.scale = Vector2(0.75, 0.75)
					s.position = foot
					s.material = mats[(row + di) % 2]
					vp.add_child(s)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_arg("out"))
	print("saved")
	quit()
