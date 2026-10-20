extends SceneTree
## Offline baker for cavalry: the Quaternius horse (CC0) with a saddle and a team-keyed saddle
## cloth, and the KayKit knight riding (lower body from the seated pose, upper body from the
## attack animations), in the same camera, light and outline as tools/bake_units.gd.
##   godot --path . --script res://tools/bake_cavalry.gd
## Adds to assets/units/units.json: bodies "horse" and "rider_<set>", weapons "wpn_rider_<set>_<w>",
## and "saddle": per horse frame, the saddle point (pixels from the hooves anchor).

const ADV := "res://art_src/kaykit_adventurers/"
const HORSE := "res://art_src/quaternius_horse/horse1.glb"
const OUT := "res://assets/units/"
const R := 3.0
const SS := 2
const WU := 12.0
const ELEV := 40.0
const CELL := 224
const ANCHOR := Vector2(112, 160)
const GRID := 8
const PAGE := 2048
const DIRS := [["e", 90.0], ["se", 45.0], ["s", 0.0], ["ne", 135.0], ["n", 180.0]]
const HORSE_BACK := 1.75      # saddle height in metres (the KayKit knight is about 2.5 m)
const SUN_DIR := Vector3(0.66, -0.86, 0.3)

const HORSE_ANIMS := [["idle", "Idle", 2, true], ["walk", "Walk", 6, true], ["gallop", "Gallop", 6, true],
	["hit", "Idle_HitReact_Left", 3, false], ["death", "Death", 5, false]]
const RIDER_SETS := {
	"1h": [["ride", "Sit_Chair_Idle", 2, true], ["a1", "1H_Melee_Attack_Slice_Diagonal", 7, "atk"],
		["a2", "1H_Melee_Attack_Chop", 7, "atk"], ["a3", "1H_Melee_Attack_Stab", 7, "atk"], ["hit", "Hit_A", 3, false]],
	"2h": [["ride", "Sit_Chair_Idle", 2, true], ["a1", "2H_Melee_Attack_Slice", 7, "atk"],
		["a2", "2H_Melee_Attack_Chop", 7, "atk"], ["a3", "2H_Melee_Attack_Stab", 7, "atk"], ["hit", "Hit_A", 3, false]],
	"ranged": [["ride", "Sit_Chair_Idle", 2, true], ["aim", "2H_Ranged_Aiming", 2, true], ["shoot", "2H_Ranged_Shoot", 4, false],
		["a1", "2H_Melee_Attack_Slice", 7, "atk"], ["hit", "Hit_A", 3, false]],
}
const LOADOUTS := {
	"1h": {"sword": ["1H_Sword"], "sword_shield": ["1H_Sword", "Round_Shield"], "knife": ["Knife"]},
	"2h": {"greatsword": ["2H_Sword"], "axe": ["2H_Axe"], "hammer": ["#hammer"], "glaive": ["#glaive"],
		"spear": ["#spear"], "black_glaive": ["#black_glaive"]},
	"ranged": {"crossbow": ["2H_Crossbow"], "bow": ["#bow"]},
}
const LEG_BONES := ["hips", "upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r"]

var units: Object      # an instance of bake_units.gd, used for its helpers
var vp3: SubViewport
var vp2: SubViewport
var world: Node3D
var cam: Camera3D
var post: TextureRect
var holdout: ShaderMaterial
var meta := {}
var horse_tpl: Node3D
var horse_scale := 1.0
var sit_pose := {}

func _init() -> void:
	_run.call_deferred()

func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(path), st) == OK)
	return doc.generate_scene(st) as Node3D

func _each(n: Node, cb: Callable) -> void:
	cb.call(n)
	for c in n.get_children():
		_each(c, cb)

func _anim_player(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer

func _skel(n: Node) -> Skeleton3D:
	return n.find_child("Skeleton3D", true, false) as Skeleton3D

# ------------------------------------------------------------------ scene (same look as the unit bake)
func _setup() -> void:
	var full := GRID * CELL * SS
	vp3 = SubViewport.new()
	vp3.size = Vector2i(full, full)
	vp3.transparent_bg = true
	vp3.msaa_3d = Viewport.MSAA_4X
	vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp3)
	world = Node3D.new()
	vp3.add_child(world)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.7, 0.84)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	we.environment = e
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.86)
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-52, -40, 0)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(fill)
	fill.rotation_degrees = Vector3(-20, 150, 0)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-ELEV, 0, 0)
	cam.size = float(full) / (R * WU * SS)
	cam.position = cam.transform.basis.z * 60.0
	cam.near = 1.0
	cam.far = 200.0
	world.add_child(cam)
	cam.current = true
	vp2 = SubViewport.new()
	vp2.size = Vector2i(GRID * CELL, GRID * CELL)
	vp2.transparent_bg = true
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp2)
	post = TextureRect.new()
	post.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	post.size = Vector2(vp2.size)
	post.texture = vp3.get_texture()
	post.stretch_mode = TextureRect.STRETCH_SCALE
	var sh := Shader.new()
	sh.code = units.POST_SHADER
	var pm := ShaderMaterial.new()
	pm.shader = sh
	pm.set_shader_parameter("src", vp3.get_texture())
	pm.set_shader_parameter("src_px", Vector2.ONE / Vector2(vp3.size))
	pm.set_shader_parameter("radius", 2.4)
	post.material = pm
	vp2.add_child(post)
	var hs := Shader.new()
	hs.code = units.HOLDOUT_SHADER
	holdout = ShaderMaterial.new()
	holdout.shader = hs
	holdout.render_priority = -50

func _cell_ground(i: int) -> Vector3:
	var sp := (Vector2((i % GRID) * CELL, (i / GRID) * CELL) + ANCHOR) * SS
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	return o + n * (-o.y / n.y)

func _render() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp2.get_texture().get_image()

# ------------------------------------------------------------------ horse
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return units._style(m)

## Saddle (leather) and a saddle cloth in the team key colour, built around the horse's back.
func _saddle_meshes() -> Array:
	var cloth := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	units._box(st, Vector3(0, -0.05, 0), Vector3(0.62, 0.06, 0.78))
	units._box(st, Vector3(0.33, -0.22, 0), Vector3(0.04, 0.38, 0.72))
	units._box(st, Vector3(-0.33, -0.22, 0), Vector3(0.04, 0.38, 0.72))
	st.commit(cloth)
	cloth.surface_set_material(0, _mat(Color(0.0, 0.62, 0.0)))
	var saddle := ArrayMesh.new()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	units._box(st2, Vector3(0, 0.03, 0), Vector3(0.44, 0.1, 0.5))
	units._box(st2, Vector3(0, 0.12, 0.2), Vector3(0.36, 0.12, 0.08))
	units._box(st2, Vector3(0, 0.1, -0.22), Vector3(0.4, 0.1, 0.06))
	st2.commit(saddle)
	saddle.surface_set_material(0, _mat(Color("#6b4128")))
	return [cloth, saddle]

func _make_horse() -> Node3D:
	var h: Node3D = horse_tpl.duplicate()
	h.scale = Vector3.ONE * horse_scale
	world.add_child(h)
	var meshes := _saddle_meshes()
	var items: Array = []
	for m in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		world.add_child(mi)
		items.append(mi)
	h.set_meta("saddle", items)
	return h

## Where the rider sits: midway along the back, on top of the saddle (world space).
func _saddle_xform(h: Node3D) -> Transform3D:
	var sk := _skel(h)
	var a := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Back"))).origin
	var b := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Torso2"))).origin
	var c := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Torso"))).origin
	var mid := (a + b) * 0.5
	mid.y = maxf(maxf(a.y, b.y), c.y)
	var fwd := (b - a)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.001 else Vector3.BACK
	var basis := Basis.looking_at(-fwd, Vector3.UP)
	return Transform3D(basis, mid + Vector3(0, 0.06, 0))

func _place_saddle(h: Node3D) -> void:
	var xf := _saddle_xform(h)
	for mi in h.get_meta("saddle"):
		(mi as Node3D).global_transform = xf
		(mi as Node3D).visible = h.visible

# ------------------------------------------------------------------ rider
func _pose_rider(r: Node3D, anim: String, t: float) -> void:
	var ap := _anim_player(r)
	ap.play(anim)
	ap.seek(t, true)
	ap.pause()
	var sk := _skel(r)
	for bn in LEG_BONES:
		var i := sk.find_bone(bn)
		if sit_pose.has(bn):
			sk.set_bone_pose_rotation(i, sit_pose[bn][0])
			if bn == "hips":
				sk.set_bone_pose_position(i, sit_pose[bn][1])

func _hips_world(r: Node3D) -> Vector3:
	var sk := _skel(r)
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("hips"))).origin

# ------------------------------------------------------------------ bake
func _bake_horse(horses: Array) -> void:
	var frames: Array = []
	var ap0 := _anim_player(horses[0])
	for e in HORSE_ANIMS:
		var len: float = ap0.get_animation(e[1]).length
		var n: int = e[2]
		for d in DIRS:
			for i in n:
				var t: float = len * float(i) / (n if e[3] else maxi(1, n - 1)) * (1.0 if e[3] else 0.97)
				frames.append([e[0], d[0], i, t, e[1], d[1]])
	var imgs: Array = []
	var saddle_pts := {}
	var per := GRID * GRID
	var b := 0
	while b < frames.size():
		var batch := frames.slice(b, mini(b + per, frames.size()))
		for i in horses.size():
			var h: Node3D = horses[i]
			h.visible = i < batch.size()
			if h.visible:
				var f: Array = batch[i]
				h.position = _cell_ground(i)
				h.rotation_degrees = Vector3(0, f[5], 0)
				var ap := _anim_player(h)
				ap.play(f[4])
				ap.seek(f[3], true)
				ap.pause()
			_place_saddle(h)
		for i in batch.size():
			var f: Array = batch[i]
			var sp := cam.unproject_position(_saddle_xform(horses[i]).origin) / SS - (Vector2((i % GRID) * CELL, (i / GRID) * CELL) + ANCHOR)
			var key := "%s/%s" % [f[0], f[1]]
			if not saddle_pts.has(key):
				saddle_pts[key] = []
			saddle_pts[key].append([snappedf(sp.x, 0.1), snappedf(sp.y, 0.1)])
		var img: Image = await _render()
		units._slice(img, batch.size(), imgs)
		b += per
	_pack("horse", frames, imgs, meta["bodies"])
	meta["saddle"] = saddle_pts
	print("  horse: %d frames" % frames.size())

func _bake_rider(set_name: String, riders: Array, horses: Array) -> void:
	var entries: Array = RIDER_SETS[set_name]
	var ap0 := _anim_player(riders[0])
	var frames: Array = []
	for e in entries:
		var times: Array = units._times(riders[0], ap0, e, "rider_" + set_name)
		for d in DIRS:
			for i in times.size():
				frames.append([e[0], d[0], i, times[i], e[1], d[1]])
	var loadouts: Dictionary = LOADOUTS[set_name]
	var body_imgs: Array = []
	var wpn_imgs := {}
	for lk in loadouts.keys():
		wpn_imgs[lk] = []
	var per := GRID * GRID
	var b := 0
	while b < frames.size():
		var batch := frames.slice(b, mini(b + per, frames.size()))
		for i in riders.size():
			var r: Node3D = riders[i]
			var h: Node3D = horses[i]
			r.visible = i < batch.size()
			h.visible = r.visible
			if not r.visible:
				_place_saddle(h)
				continue
			var f: Array = batch[i]
			# the horse stands in its idle pose as a depth holdout (hides the rider's far leg)
			h.position = _cell_ground(i)
			h.rotation_degrees = Vector3(0, f[5], 0)
			var hap := _anim_player(h)
			hap.play("Idle")
			hap.seek(0.0, true)
			hap.pause()
			_place_saddle(h)
			r.rotation_degrees = Vector3(0, f[5], 0)
			r.position = Vector3.ZERO
			_pose_rider(r, f[4], f[3])
			# seat the hips on the saddle; the sprite is anchored at the hips
			var seat := _saddle_xform(h).origin
			r.position += seat - _hips_world(r) + Vector3(0, 0.02, 0)
			units._show_items(r, [])
			for m in r.get_meta("body"):
				(m as MeshInstance3D).material_override = null
			_set_horse_holdout(h, true)
		var img: Image = await _render()
		_slice_hips(img, batch, riders, body_imgs)
		for lk in loadouts.keys():
			var names: Array = loadouts[lk].map(func(x): return units._part_node_name(x))
			for i in batch.size():
				units._show_items(riders[i], names)
				for m in riders[i].get_meta("body"):
					(m as MeshInstance3D).material_override = holdout
			var wimg: Image = await _render()
			_slice_hips(wimg, batch, riders, wpn_imgs[lk])
		b += per
	_pack("rider_" + set_name, frames, body_imgs, meta["bodies"])
	for lk in loadouts.keys():
		_pack("wpn_rider_%s_%s" % [set_name, lk], frames, wpn_imgs[lk], meta["weapons"])
	for h in horses:
		_set_horse_holdout(h, false)
	print("  rider_%s: %d frames" % [set_name, frames.size()])

func _set_horse_holdout(h: Node3D, on: bool) -> void:
	_each(h, func(c):
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = holdout if on else null
	)
	for mi in h.get_meta("saddle"):
		(mi as MeshInstance3D).material_override = holdout if on else null

## Slices rider cells; the anchor stored for each frame is the rider's hips, not the hooves.
func _slice_hips(img: Image, batch: Array, riders: Array, out: Array) -> void:
	for i in batch.size():
		var cx := i % GRID
		var cy := i / GRID
		var cell := img.get_region(Rect2i(cx * CELL, cy * CELL, CELL, CELL))
		var used := cell.get_used_rect()
		if used.size.x <= 0:
			out.append(null)
			continue
		var hp := cam.unproject_position(_hips_world(riders[i])) / SS - Vector2(cx * CELL, cy * CELL)
		out.append([cell.get_region(used), used.position, hp])

func _pack(name: String, frames: Array, imgs: Array, dest: Dictionary) -> void:
	var order: Array = []
	for i in imgs.size():
		if imgs[i] != null:
			order.append(i)
	order.sort_custom(func(a, b): return imgs[a][0].get_height() > imgs[b][0].get_height())
	var pages: Array = []
	var page := Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
	var x := 0
	var y := 0
	var row := 0
	var rects := {}
	for i in order:
		var im: Image = imgs[i][0]
		var w := im.get_width() + 2
		var h := im.get_height() + 2
		if x + w > PAGE:
			x = 0
			y += row
			row = 0
		if y + h > PAGE:
			pages.append(page)
			page = Image.create(PAGE, PAGE, false, Image.FORMAT_RGBA8)
			x = 0
			y = 0
			row = 0
		page.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x + 1, y + 1))
		var off: Vector2i = imgs[i][1]
		var anchor: Vector2 = imgs[i][2] if imgs[i].size() > 2 else ANCHOR
		rects[i] = [pages.size(), x + 1, y + 1, im.get_width(), im.get_height(), snappedf(anchor.x - off.x, 0.1), snappedf(anchor.y - off.y, 0.1)]
		x += w
		row = maxi(row, h)
	pages.append(page.get_region(Rect2i(0, 0, PAGE, maxi(16, mini(PAGE, y + row + 2)))))
	var files: Array = []
	for p in pages.size():
		var fn := "%s_%d.png" % [name, p]
		pages[p].save_png(ProjectSettings.globalize_path(OUT + fn))
		files.append(fn)
	var anims := {}
	for i in frames.size():
		var f: Array = frames[i]
		var key := "%s/%s" % [f[0], f[1]]
		if not anims.has(key):
			anims[key] = []
		anims[key].append(rects.get(i, null))
	dest[name] = {"pages": files, "anims": anims}

func _run() -> void:
	units = load("res://tools/bake_units.gd").new()
	meta = JSON.parse_string(FileAccess.get_file_as_string(OUT + "units.json"))
	_setup()
	# the rider is the knight, with the shared weapon parts
	units.world = world
	units.templates = {}
	for body in units.BODIES.keys():
		units.templates[body] = units._prepare(body)
	units._collect_parts()
	units.meta = meta
	# horse template and scale
	horse_tpl = _load(HORSE)
	var probe: Node3D = horse_tpl.duplicate()
	world.add_child(probe)
	var ap := _anim_player(probe)
	ap.play("Idle")
	ap.seek(0.0, true)
	await process_frame
	var back_y := _saddle_xform(probe).origin.y
	horse_scale = HORSE_BACK / maxf(0.01, back_y)
	probe.queue_free()
	_each(horse_tpl, func(c):
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as BaseMaterial3D
				if m:
					mi.mesh.surface_set_material(s, units._style(m.duplicate()))
	)
	# seated leg pose
	var probe_r: Node3D = units._make_instance("knight")
	var rap := _anim_player(probe_r)
	rap.play("Sit_Chair_Idle")
	rap.seek(0.5, true)
	var sk := _skel(probe_r)
	for bn in LEG_BONES:
		var i := sk.find_bone(bn)
		sit_pose[bn] = [sk.get_bone_pose_rotation(i), sk.get_bone_pose_position(i)]
	probe_r.queue_free()
	var horses: Array = []
	for i in GRID * GRID:
		horses.append(_make_horse())
	print("[cavalry] horse scale %.3f" % horse_scale)
	await _bake_horse(horses)
	var riders: Array = []
	for i in GRID * GRID:
		riders.append(units._make_instance("knight"))
	for set_name in RIDER_SETS.keys():
		await _bake_rider(set_name, riders, horses)
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "units.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("[cavalry] done")
	quit()
