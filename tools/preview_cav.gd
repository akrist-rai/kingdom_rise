extends SceneTree
## Cavalry contact sheet: horse + rider + weapon at the baked saddle points, runtime shader.
## godot --path . --script res://tools/preview_cav.gd -- --set=2h --wpn=spear --out=<png>

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

func _spr(parent: Node, pages: Array, fr, flip: bool, pos: Vector2, mat: Material) -> void:
	if fr == null:
		return
	var s := Sprite2D.new()
	s.texture = pages[int(fr[0])]
	s.region_enabled = true
	s.region_rect = Rect2(fr[1], fr[2], fr[3], fr[4])
	s.centered = false
	s.flip_h = flip
	var ax: float = fr[5]
	if flip:
		ax = float(fr[3]) - ax
	s.offset = Vector2(-ax, -float(fr[6]))
	s.scale = Vector2(0.75, 0.75)
	s.position = pos
	s.material = mat
	parent.add_child(s)

func _run() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/units.json"))
	var set_name := _arg("set", "2h")
	var horse: Dictionary = meta["bodies"]["horse"]
	var rider: Dictionary = meta["bodies"]["rider_" + set_name]
	var wpn: Dictionary = meta["weapons"]["wpn_rider_%s_%s" % [set_name, _arg("wpn", "spear")]]
	var hp := _pages(horse)
	var rp := _pages(rider)
	var wp := _pages(wpn)
	var rows := [["idle", "ride"], ["gallop", "ride"], ["gallop", "a1"], ["walk", "a3"], ["idle", "a2"], ["death", "hit"]]
	var cell := Vector2(80, 80)
	var vp := SubViewport.new()
	vp.size = Vector2i(int(cell.x * 16), int(cell.y * rows.size()))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.48, 0.55, 0.36)
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/unit.gdshader")
	for ri in rows.size():
		var ha: String = rows[ri][0]
		var ra: String = rows[ri][1]
		for col in 16:
			var di := col % 8
			var d: String = DIR8[di]
			var src: String = MIRROR.get(d, d)
			var flip := MIRROR.has(d)
			var hf: Array = horse["anims"][ha + "/" + src]
			var hi := (col / 8) * (hf.size() / 2)
			var foot := Vector2((col + 0.5) * cell.x, (ri + 0.85) * cell.y)
			_spr(vp, hp, hf[hi], flip, foot, mat)
			if ha == "death":
				continue
			var sp: Array = meta["saddle"][ha + "/" + src][hi]
			var seat := foot + Vector2(-sp[0] if flip else sp[0], sp[1]) * 0.75
			var rf: Array = rider["anims"][ra + "/" + src]
			var rfi := mini(3, rf.size() - 1) if ra.begins_with("a") and col >= 8 else 0
			_spr(vp, rp, rf[rfi], flip, seat, mat)
			_spr(vp, wp, wpn["anims"][ra + "/" + src][rfi], flip, seat, mat)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_arg("out"))
	print("saved")
	quit()
