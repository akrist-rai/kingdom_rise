extends SceneTree
## Offline sprite baker: renders the KayKit (CC0) characters from the game's camera angle into
## sprite atlases, in 5 directions (the other 3 are mirrored at runtime), with a separate
## weapon layer so any body can carry any weapon.
##
##   godot --path . --script res://tools/bake_units.gd [-- --only=knight_2h] [--preview=<png>]
##
## Output: assets/units/<body>_<set>_<page>.png (+ weapon layers wpn_<set>_<loadout>_<page>.png)
## and assets/units/units.json describing every frame (atlas page, rect, foot anchor) plus the
## weapon-tip path of every attack (used to draw slash trails that follow the real swing).
##
## Team cloth is re-coloured to a pure green key so one bake serves every faction: the unit
## shader turns the key into the faction's colours (shaders/unit.gdshader).

const SRC := "res://art_src/kaykit_adventurers/"
const OUT := "res://assets/units/"
const R := 3.0                 # final pixels per world unit
const SS := 2                  # supersampling factor
const WU := 12.0               # world units per metre
const ELEV := 40.0             # camera elevation (degrees)
const CELL := 224              # final pixels per frame cell
const ANCHOR := Vector2(112, 152)   # foot point inside a cell (final pixels)
const GRID := 8                # cells per row / column in one render
const PAGE := 2048

## direction key -> model yaw (degrees). Screen east is +X, screen south is toward the camera.
const DIRS := [["e", 90.0], ["se", 45.0], ["s", 0.0], ["ne", 135.0], ["n", 180.0]]

const BODIES := {
	"knight": {"file": "Knight.glb", "team": [[0, 1], [2, 2]],
		"items": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "1H_Sword", "2H_Sword"]},
	"barbarian": {"file": "Barbarian.glb", "team": [[0, 1], [1, 1], [2, 2]],
		"items": ["1H_Axe_Offhand", "Barbarian_Round_Shield", "1H_Axe", "2H_Axe", "Mug"]},
	"rogue": {"file": "Rogue_Hooded.glb", "team": [[1, 1], [1, 2]], "neutral": [[0, 1]],
		"items": ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]},
}

## body -> animation sets baked for it (weapon layers are baked once per set, on the knight)
const BODY_SETS := {"knight": ["1h", "2h", "dual", "ranged"], "barbarian": ["2h"], "rogue": ["ranged", "dual"]}

## [key, animation, frames, loop]. "atk" entries are sampled around the swing (see _times).
const COMMON := [
	["walk", "Walking_A", 6, true], ["run", "Running_A", 8, true], ["hit", "Hit_A", 4, false],
	["death", "Death_A", 6, false], ["dodge", "Dodge_Forward", 4, false], ["blockhit", "Block_Hit", 3, false],
	["cheer", "Cheer", 4, true], ["kick", "Unarmed_Melee_Attack_Kick", 5, false], ["throw", "Throw", 5, false],
	["drink", "Use_Item", 4, false], ["standup", "Lie_StandUp", 4, false],
]
const SETS := {
	"1h": [["idle", "Idle", 4, true], ["block", "Blocking", 2, true],
		["a1", "1H_Melee_Attack_Slice_Diagonal", 7, "atk"], ["a2", "1H_Melee_Attack_Slice_Horizontal", 7, "atk"],
		["a3", "1H_Melee_Attack_Stab", 7, "atk"], ["a4", "1H_Melee_Attack_Chop", 7, "atk"]],
	"2h": [["idle", "2H_Melee_Idle", 4, true], ["block", "Blocking", 2, true],
		["a1", "2H_Melee_Attack_Slice", 7, "atk"], ["a2", "2H_Melee_Attack_Chop", 7, "atk"],
		["a3", "2H_Melee_Attack_Stab", 7, "atk"], ["a4", "2H_Melee_Attack_Spin", 8, false],
		["spin", "2H_Melee_Attack_Spinning", 4, true]],
	"dual": [["idle", "Idle", 4, true], ["block", "Blocking", 2, true],
		["a1", "Dualwield_Melee_Attack_Slice", 7, "atk"], ["a2", "Dualwield_Melee_Attack_Chop", 7, "atk"],
		["a3", "Dualwield_Melee_Attack_Stab", 7, "atk"]],
	"ranged": [["idle", "Idle", 4, true], ["block", "Blocking", 2, true],
		["aim", "2H_Ranged_Aiming", 2, true], ["shoot", "2H_Ranged_Shoot", 4, false], ["reload", "2H_Ranged_Reload", 4, false]],
}
## weapon loadouts per set: item names (from the KayKit models) or #custom meshes
const LOADOUTS := {
	"1h": {"sword": ["1H_Sword"], "sword_shield": ["1H_Sword", "Round_Shield"], "knife": ["Knife"]},
	"2h": {"greatsword": ["2H_Sword"], "axe": ["2H_Axe"], "hammer": ["#hammer"], "glaive": ["#glaive"],
		"spear": ["#spear"], "black_glaive": ["#black_glaive"]},
	"dual": {"daggers": ["Knife", "Knife_Offhand"]},
	"ranged": {"crossbow": ["2H_Crossbow"], "bow": ["#bow"]},
}
## weapon tip (handslot space) used to trace the swing path for trails
const TIP := {"1h": 1.35, "2h": 1.9, "dual": 0.95, "ranged": 0.6}

var vp3: SubViewport
var vp2: SubViewport
var world: Node3D
var cam: Camera3D
var post_rect: TextureRect
var templates := {}        # body -> Node3D (team-keyed materials applied)
var parts := {}            # item name -> {mesh, xform, slot}
var holdout: ShaderMaterial
var meta := {"r": R, "anchor": [ANCHOR.x, ANCHOR.y], "dirs": [], "bodies": {}, "weapons": {}, "trails": {}, "anims": {}}
var only := ""

func _init() -> void:
	# also loaded as a helper library by bake_cavalry.gd: only bake when run as the main script
	if not ("res://tools/bake_units.gd" in OS.get_cmdline_args()):
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	_run.call_deferred()

# ------------------------------------------------------------------ loading
func _load(file: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(ProjectSettings.globalize_path(file), st)
	assert(err == OK, "cannot load " + file)
	return doc.generate_scene(st) as Node3D

func _each(n: Node, cb: Callable) -> void:
	cb.call(n)
	for c in n.get_children():
		_each(c, cb)

## Team tiles -> green key gradient; stray natural greens lose their green dominance.
func _key_texture(img: Image, team: Array, neutral: Array = []) -> Image:
	var out := img.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var w := out.get_width()
	var h := out.get_height()
	var tw := w / 8
	var th := h / 4
	var is_team := func(x: int, y: int) -> bool:
		for t in team:
			if x / tw == t[0] and y / th == t[1]:
				return true
		return false
	var is_neutral := func(x: int, y: int) -> bool:
		for t in neutral:
			if x / tw == t[0] and y / th == t[1]:
				return true
		return false
	for y in h:
		for x in w:
			var c := out.get_pixel(x, y)
			if is_team.call(x, y):
				var l := clampf(c.get_luminance() * 1.35 + 0.12, 0.25, 1.0)
				out.set_pixel(x, y, Color(0.0, l, 0.0, c.a))
			elif is_neutral.call(x, y):
				var l2 := c.get_luminance()
				out.set_pixel(x, y, Color(0.36 + l2 * 0.5, 0.26 + l2 * 0.42, 0.18 + l2 * 0.3, c.a))
			elif c.g > maxf(c.r, c.b) + 0.02:
				out.set_pixel(x, y, Color(c.r, maxf(c.r, c.b), c.b, c.a))
	return out

func _style(m: StandardMaterial3D) -> StandardMaterial3D:
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.roughness = 0.85
	m.metallic_specular = 0.25
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	return m

func _prepare(body: String) -> Node3D:
	var d: Dictionary = BODIES[body]
	var n := _load(SRC + d["file"])
	var keyed := {}
	_each(n, func(c):
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if m == null:
					continue
				if not keyed.has(m):
					var nm: StandardMaterial3D = m.duplicate()
					if nm.albedo_texture:
						nm.albedo_texture = ImageTexture.create_from_image(_key_texture(nm.albedo_texture.get_image(), d["team"], d.get("neutral", [])))
					keyed[m] = _style(nm)
				mi.mesh.surface_set_material(s, keyed[m])
	)
	return n

## Collect every weapon / shield mesh with its attachment transform, from all three models.
func _collect_parts() -> void:
	for body in BODIES.keys():
		var n: Node3D = templates[body]
		_each(n, func(c):
			if c is MeshInstance3D and c.get_parent() is BoneAttachment3D:
				var ba := c.get_parent() as BoneAttachment3D
				if String(c.name) in BODIES[body]["items"] and not parts.has(String(c.name)):
					parts[String(c.name)] = {"mesh": (c as MeshInstance3D).mesh, "xform": (c as Node3D).transform,
						"slot": "r" if ba.bone_name.ends_with(".r") else "l"}
		)
	for k in ["hammer", "glaive", "spear", "black_glaive", "bow"]:
		parts["#" + k] = _custom_weapon(k)

# ------------------------------------------------------------------ custom weapons (KayKit-like low poly)
func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return _style(m)

func _box(st: SurfaceTool, c: Vector3, s: Vector3, rot: float = 0.0) -> void:
	var hx := s * 0.5
	var corners := []
	for i in 8:
		var p := Vector3(hx.x * (1 if i & 1 else -1), hx.y * (1 if i & 2 else -1), hx.z * (1 if i & 4 else -1))
		corners.append(Basis(Vector3(0, 0, 1), rot) * p + c)
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var cc: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		var nrm := (b - a).cross(cc - a).normalized()
		for v in [a, b, cc, a, cc, d]:
			st.set_normal(-nrm)
			st.add_vertex(v)

func _cyl(st: SurfaceTool, y0: float, y1: float, r: float, sides: int = 6) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := ((p0 + p1) * 0.5).normalized()
		for v in [p0 + Vector3(0, y0, 0), p1 + Vector3(0, y1, 0), p1 + Vector3(0, y0, 0), p0 + Vector3(0, y0, 0), p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0)]:
			st.set_normal(n)
			st.add_vertex(v)

## A flat blade: polygon in the XY plane extruded along Z.
func _blade(st: SurfaceTool, pts: PackedVector2Array, depth: float) -> void:
	var tris := Geometry2D.triangulate_polygon(pts)
	for side in [-1.0, 1.0]:
		for i in range(0, tris.size(), 3):
			var idx := [tris[i], tris[i + 1], tris[i + 2]] if side > 0 else [tris[i], tris[i + 2], tris[i + 1]]
			for j in idx:
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(Vector3(pts[j].x, pts[j].y, depth * 0.5 * side))
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var n := Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		for v in [Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5),
				Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(a.x, a.y, depth * 0.5)]:
			st.set_normal(n)
			st.add_vertex(v)

func _custom_weapon(kind: String) -> Dictionary:
	var mesh := ArrayMesh.new()
	var wood := Color("#8a5a3c")
	var steel := Color("#b8c0cc")
	var dark := Color("#3a3446")
	var gold := Color("#e0b44c")
	var surf := func(col: Color, fn: Callable, rough: float = 0.8, metal: float = 0.0):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		fn.call(st)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(col, rough, metal))
	var slot := "r"
	match kind:
		"spear":
			surf.call(wood, func(st): _cyl(st, -0.9, 2.1, 0.04))
			surf.call(steel, func(st): _blade(st, PackedVector2Array([Vector2(0, 2.05), Vector2(0.09, 2.25), Vector2(0, 2.62), Vector2(-0.09, 2.25)]), 0.05), 0.4, 0.5)
			surf.call(Color("#c23b2f"), func(st): _box(st, Vector3(0, 2.0, 0), Vector3(0.13, 0.08, 0.13)))
		"glaive", "black_glaive":
			var shaft := wood if kind == "glaive" else dark
			var blade := steel if kind == "glaive" else Color("#5b4d7a")
			surf.call(shaft, func(st): _cyl(st, -0.7, 1.75, 0.045))
			surf.call(blade, func(st): _blade(st, PackedVector2Array([Vector2(-0.05, 1.7), Vector2(0.08, 1.72), Vector2(0.2, 1.95),
				Vector2(0.22, 2.2), Vector2(0.1, 2.45), Vector2(0.02, 2.3), Vector2(-0.07, 2.0)]), 0.05), 0.4, 0.5)
			surf.call(gold if kind == "black_glaive" else Color("#c23b2f"), func(st): _box(st, Vector3(0, 1.68, 0), Vector3(0.14, 0.09, 0.14)))
		"hammer":
			surf.call(wood, func(st): _cyl(st, -0.45, 1.45, 0.045))
			surf.call(Color("#8d95a3"), func(st):
				_box(st, Vector3(0, 1.5, 0), Vector3(0.5, 0.26, 0.26))
				_box(st, Vector3(0, 1.72, 0), Vector3(0.1, 0.24, 0.1)), 0.5, 0.4)
			surf.call(dark, func(st): _box(st, Vector3(0, 1.36, 0), Vector3(0.12, 0.1, 0.12)))
		"bow":
			slot = "l"
			var pts := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				var y := lerpf(-0.75, 0.75, t)
				pts.append(Vector2(0.18 * (1.0 - pow((y / 0.75), 2.0)) - 0.02, y))
			for i in range(12, -1, -1):
				var t := float(i) / 12.0
				var y := lerpf(-0.75, 0.75, t)
				pts.append(Vector2(0.18 * (1.0 - pow((y / 0.75), 2.0)) + 0.04, y))
			surf.call(wood, func(st): _blade(st, pts, 0.06))
			surf.call(Color("#efe6d2"), func(st): _box(st, Vector3(-0.03, 0, 0), Vector3(0.012, 1.5, 0.012)))
	# KayKit slots point the weapon along +Y; the bow is held upright across the off hand
	var xf := Transform3D.IDENTITY
	if kind == "bow":
		xf = Transform3D(Basis(Vector3(0, 0, 1), 0.0), Vector3.ZERO)
	return {"mesh": mesh, "xform": xf, "slot": slot}

# ------------------------------------------------------------------ scene
const POST_SHADER := """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D src : filter_linear;
uniform vec2 src_px;
uniform float radius = 2.4;
uniform vec4 ink : source_color = vec4(0.06, 0.05, 0.08, 1.0);
void fragment() {
	// 2x2 box downsample of the premultiplied supersampled render
	vec4 c = texture(src, UV);
	float m = 0.0;
	for (int i = 0; i < 16; i++) {
		float a = float(i) * 0.3927;
		vec2 d = vec2(cos(a), sin(a)) * src_px;
		m = max(m, texture(src, UV + d * radius).a);
		m = max(m, texture(src, UV + d * radius * 0.55).a);
	}
	float o = smoothstep(0.08, 0.6, m) * ink.a;
	vec4 p = vec4(c.rgb + ink.rgb * o * (1.0 - c.a), c.a + o * (1.0 - c.a));
	vec3 straight = p.a > 0.003 ? p.rgb / p.a : ink.rgb;
	COLOR = vec4(straight, p.a);
}
"""

const HOLDOUT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_always, cull_back;
void fragment() { ALBEDO = vec3(0.0); ALPHA = 0.0; }
"""

func _setup_scene() -> void:
	var full := GRID * CELL * SS
	vp3 = SubViewport.new()
	vp3.size = Vector2i(full, full)
	vp3.transparent_bg = true
	vp3.msaa_3d = Viewport.MSAA_4X
	vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp3)
	world = Node3D.new()
	vp3.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.7, 0.84)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.86)
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(fill)
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
	post_rect = TextureRect.new()
	post_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	post_rect.size = Vector2(vp2.size)
	post_rect.texture = vp3.get_texture()
	post_rect.stretch_mode = TextureRect.STRETCH_SCALE
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = POST_SHADER
	var pm := ShaderMaterial.new()
	pm.shader = sh
	pm.set_shader_parameter("src", vp3.get_texture())
	pm.set_shader_parameter("src_px", Vector2.ONE / Vector2(vp3.size))
	pm.set_shader_parameter("radius", 2.4)
	post_rect.material = pm
	vp2.add_child(post_rect)
	var hs := Shader.new()
	hs.code = HOLDOUT_SHADER
	holdout = ShaderMaterial.new()
	holdout.shader = hs
	holdout.render_priority = -50

## Ground point under a cell's anchor.
func _cell_ground(i: int) -> Vector3:
	var cx := i % GRID
	var cy := i / GRID
	var sp := (Vector2(cx * CELL, cy * CELL) + ANCHOR) * SS
	var o := cam.project_ray_origin(sp)
	var n := cam.project_ray_normal(sp)
	return o + n * (-o.y / n.y)

# ------------------------------------------------------------------ frame timing
func _anim_len(ap: AnimationPlayer, name: String) -> float:
	return ap.get_animation(name).length

## Speed of a bone over the animation (metres / second), sampled at 60 Hz.
func _bone_track(inst: Node3D, ap: AnimationPlayer, anim: String, bone: String) -> Array:
	var skel: Skeleton3D = inst.get_node("Rig/Skeleton3D")
	var bi := skel.find_bone(bone)
	var len := _anim_len(ap, anim)
	var out: Array = []
	ap.play(anim)
	var t := 0.0
	while t <= len + 0.0001:
		ap.seek(t, true)
		out.append([t, (skel.global_transform * skel.get_bone_global_pose(bi)).origin])
		t += 1.0 / 60.0
	return out

func _swing_times(inst: Node3D, ap: AnimationPlayer, anim: String, bone: String) -> Dictionary:
	var tr := _bone_track(inst, ap, anim, bone)
	var sp: Array = []
	var mx := 0.0
	var imx := 0
	for i in range(1, tr.size()):
		var v: float = (tr[i][1] - tr[i - 1][1]).length() * 60.0
		sp.append(v)
		if v > mx:
			mx = v
			imx = i - 1
	var s0 := imx
	while s0 > 0 and sp[s0 - 1] > mx * 0.35:
		s0 -= 1
	var s1 := imx
	while s1 < sp.size() - 1 and sp[s1 + 1] > mx * 0.35:
		s1 += 1
	var len := _anim_len(ap, anim)
	return {"start": tr[s0][0], "peak": tr[imx][0], "end": tr[mini(s1 + 1, tr.size() - 1)][0], "len": len}

func _times(inst: Node3D, ap: AnimationPlayer, e: Array, set_name: String) -> Array:
	var anim: String = e[1]
	var n: int = e[2]
	var len := _anim_len(ap, anim)
	var mode = e[3]
	var out: Array = []
	if typeof(mode) == TYPE_STRING and mode == "atk":
		var bone := "handslot.r"
		var s := _swing_times(inst, ap, anim, bone)
		var ts: float = s["start"]
		var tp: float = s["peak"]
		var te: float = s["end"]
		out = [ts * 0.15, ts * 0.6, ts, tp, te, te + (len - te) * 0.35, te + (len - te) * 0.75]
		meta["anims"]["%s/%s" % [set_name, e[0]]] = {"len": len, "windup": 3, "active": 2, "swing": [ts, tp, te]}
	elif e[0] == "kick" or e[0] == "throw":
		var bone := "toes.r" if e[0] == "kick" else "handslot.r"
		var s := _swing_times(inst, ap, anim, bone)
		var ts: float = s["start"]
		var te: float = s["end"]
		out = [ts * 0.3, ts, s["peak"], te, te + (len - te) * 0.5]
		meta["anims"]["%s/%s" % [set_name, e[0]]] = {"len": len, "windup": 2, "active": 2, "swing": [ts, s["peak"], te]}
	elif e[0] == "standup":
		for i in n:
			out.append(lerpf(0.25, len * 0.92, float(i) / (n - 1)))
	elif e[0] == "death":
		for i in n:
			out.append(len * pow(float(i) / (n - 1), 0.8) * 0.98)
	else:
		var loop: bool = typeof(mode) == TYPE_BOOL and mode
		for i in n:
			out.append(len * float(i) / (n if loop else maxi(1, n - 1)) * (1.0 if loop else 0.97))
	return out

# ------------------------------------------------------------------ rendering
func _render() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp2.get_texture().get_image()

func _show_items(inst: Node3D, names: Array) -> void:
	var items: Dictionary = inst.get_meta("items", {})
	for k in items.keys():
		(items[k] as Node3D).visible = k in names

func _make_instance(body: String) -> Node3D:
	var inst: Node3D = templates[body].duplicate()
	world.add_child(inst)
	var items := {}
	var bas := {}
	var drop: Array = []
	_each(inst, func(c):
		if c is BoneAttachment3D:
			bas[(c as BoneAttachment3D).bone_name] = c
		if c is MeshInstance3D and String(c.name) in BODIES[body]["items"]:
			drop.append(c)
	)
	for c in drop:
		c.get_parent().remove_child(c)
		c.free()
	# attach every weapon part (hidden) so loadouts can be switched without re-instancing
	for pn in parts.keys():
		var p: Dictionary = parts[pn]
		var mi := MeshInstance3D.new()
		mi.name = pn.replace("#", "C_")
		mi.mesh = p["mesh"]
		mi.transform = p["xform"]
		mi.visible = false
		# weapons draw after the depth-only body holdout, so the body hides what is behind it
		for s in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if sm:
				var tm: BaseMaterial3D = sm.duplicate()
				tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				tm.render_priority = 20
				mi.set_surface_override_material(s, tm)
		var ba: Node = bas["handslot." + p["slot"]]
		ba.add_child(mi)
		items[_part_node_name(pn)] = mi
	inst.set_meta("items", items)
	var body_meshes: Array = []
	for c in inst.get_node("Rig/Skeleton3D").get_children():
		if c is MeshInstance3D:
			body_meshes.append(c)
		elif c is BoneAttachment3D:
			for m in c.get_children():
				if m is MeshInstance3D and not (m in items.values()):
					body_meshes.append(m)
	inst.set_meta("body", body_meshes)
	return inst

func _part_node_name(pn: String) -> String:
	return pn.replace("#", "C_")

func _bake_set(body: String, set_name: String, insts: Array) -> void:
	var entries: Array = SETS[set_name] + COMMON
	var ap0: AnimationPlayer = insts[0].get_node("AnimationPlayer")
	var frames: Array = []          # [anim_key, dir, index, time, anim_name]
	var anim_index := {}
	for e in entries:
		var times := _times(insts[0], ap0, e, set_name)
		anim_index[e[0]] = times.size()
		for d in DIRS:
			for i in times.size():
				frames.append([e[0], d[0], i, times[i], e[1], d[1]])
	var weapon_bake: bool = body == "knight"
	var loadouts: Dictionary = LOADOUTS[set_name] if weapon_bake else {}
	var body_imgs: Array = []
	var wpn_imgs := {}
	for lk in loadouts.keys():
		wpn_imgs[lk] = []
	var per := GRID * GRID
	var b := 0
	while b < frames.size():
		var batch := frames.slice(b, mini(b + per, frames.size()))
		for i in insts.size():
			var inst: Node3D = insts[i]
			inst.visible = i < batch.size()
			if i >= batch.size():
				continue
			var f: Array = batch[i]
			inst.position = _cell_ground(i)
			inst.rotation_degrees = Vector3(0, f[5], 0)
			var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
			ap.play(f[4])
			ap.seek(f[3], true)
			ap.pause()
			_show_items(inst, [])
			for m in inst.get_meta("body"):
				(m as MeshInstance3D).material_override = null
		var img: Image = await _render()
		_slice(img, batch.size(), body_imgs)
		for lk in loadouts.keys():
			var names: Array = loadouts[lk].map(func(x): return _part_node_name(x))
			for i in batch.size():
				var inst: Node3D = insts[i]
				_show_items(inst, names)
				for m in inst.get_meta("body"):
					(m as MeshInstance3D).material_override = holdout
			var wimg: Image = await _render()
			_slice(wimg, batch.size(), wpn_imgs[lk])
		b += per
		print("  %s_%s: %d / %d frames" % [body, set_name, mini(b, frames.size()), frames.size()])
	_pack("%s_%s" % [body, set_name], frames, body_imgs, meta["bodies"])
	for lk in loadouts.keys():
		_pack("wpn_%s_%s" % [set_name, lk], frames, wpn_imgs[lk], meta["weapons"])
	if weapon_bake:
		_trails(insts[0], set_name, entries)

func _slice(img: Image, n: int, out: Array) -> void:
	for i in n:
		var cx := i % GRID
		var cy := i / GRID
		var cell := img.get_region(Rect2i(cx * CELL, cy * CELL, CELL, CELL))
		var used := cell.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			out.append(null)
			continue
		out.append([cell.get_region(used), used.position])

## Shelf-packs frames into 2048 pages; records [page, x, y, w, h, ax, ay] per frame.
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
		rects[i] = [pages.size(), x + 1, y + 1, im.get_width(), im.get_height(), ANCHOR.x - off.x, ANCHOR.y - off.y]
		x += w
		row = maxi(row, h)
	# crop the last page to its used height
	var last_h := mini(PAGE, y + row + 2)
	pages.append(page.get_region(Rect2i(0, 0, PAGE, maxi(16, last_h))))
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
	print("  packed %s: %d frames on %d page(s)" % [name, frames.size(), pages.size()])

## Weapon-tip paths of each attack in every direction, in final pixels relative to the foot.
func _trails(inst: Node3D, set_name: String, entries: Array) -> void:
	var ap: AnimationPlayer = inst.get_node("AnimationPlayer")
	var skel: Skeleton3D = inst.get_node("Rig/Skeleton3D")
	var bi := skel.find_bone("handslot.r")
	inst.position = _cell_ground(0)
	for e in entries:
		var info = meta["anims"].get("%s/%s" % [set_name, e[0]])
		if info == null:
			continue
		var sw: Array = info["swing"]
		var t0: float = sw[0] - (sw[2] - sw[0]) * 0.25
		var t1: float = sw[2]
		for d in DIRS:
			inst.rotation_degrees = Vector3(0, d[1], 0)
			var pts: Array = []
			for k in 12:
				var t := lerpf(t0, t1, k / 11.0)
				ap.play(e[1])
				ap.seek(t, true)
				var g := skel.global_transform * skel.get_bone_global_pose(bi)
				var tip := g * Vector3(0, TIP[set_name], 0)
				var sp := cam.unproject_position(tip) / SS - ANCHOR
				pts.append([snappedf(sp.x, 0.1), snappedf(sp.y, 0.1)])
			meta["trails"]["%s/%s/%s" % [set_name, e[0], d[0]]] = pts

# ------------------------------------------------------------------ main
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var old := ProjectSettings.globalize_path(OUT + "units.json")
	if only != "" and FileAccess.file_exists(old):
		meta = JSON.parse_string(FileAccess.get_file_as_string(old))
	meta["dirs"] = DIRS.map(func(d): return d[0])
	meta["r"] = R
	meta["anchor"] = [ANCHOR.x, ANCHOR.y]
	_setup_scene()
	for body in BODIES.keys():
		templates[body] = _prepare(body)
	_collect_parts()
	print("[bake] parts: ", parts.keys())
	var t0 := Time.get_ticks_msec()
	for body in BODY_SETS.keys():
		var insts: Array = []
		for i in GRID * GRID:
			insts.append(_make_instance(body))
		for set_name in BODY_SETS[body]:
			if only != "" and only != "%s_%s" % [body, set_name]:
				continue
			print("[bake] %s / %s" % [body, set_name])
			await _bake_set(body, set_name, insts)
		for inst in insts:
			inst.queue_free()
		await process_frame
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "units.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("[bake] done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()
