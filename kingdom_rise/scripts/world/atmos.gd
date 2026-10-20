class_name Atmos
extends Node
## Time of day, lighting and post-processing.
## The battle moves through Golden hour -> Sunset -> Dusk; the general's last phase turns the
## sky to Wrath (burning red-gold storm) and victory brings the light back.
## Owns the half-resolution light buffer (a SubViewport sharing the world, showing only
## canvas items on visibility layer 2) and the post shader that combines everything.

const KEYS := {
	"golden": {
		"ambient": Color(1.0, 0.95, 0.9), "light_gain": 1.3, "bloom": 0.35,
		"ray_col": Color(1.0, 0.8, 0.52), "ray": 0.2, "ray_dir": Vector2(-0.8, 0.6), "cloud": 0.2,
		"fog_col": Color(0.92, 0.88, 0.96), "fog": 0.14, "haze": 0.3,
		"shadow_tint": Color(0.84, 0.9, 1.1), "high_tint": Color(1.07, 1.0, 0.9), "sat": 1.12, "contrast": 1.08,
		"vignette": 0.45, "shadow_dir": Vector2(-0.78, 0.62), "shadow_len": 1.25, "shadow_alpha": 0.5,
		"shadow_col": Color(0.2, 0.22, 0.48),
		"sky_top": Color(0.24, 0.3, 0.58), "sky_mid": Color(0.6, 0.58, 0.78), "sky_low": Color(1.0, 0.82, 0.64),
		"sun_col": Color(1.0, 0.86, 0.6), "sun_y": -150.0, "stars": 0.0, "night": 0.0, "snow": 0.7,
		"pal_dark": Color(0.1, 0.09, 0.3), "pal_mid": Color(0.62, 0.46, 0.64), "pal_light": Color(1.0, 0.93, 0.74), "poster": 0.32, "cloud_tint": Color(0.42, 0.45, 0.92),
	},
	"sunset": {
		"ambient": Color(1.02, 0.84, 0.76), "light_gain": 1.6, "bloom": 0.6,
		"ray_col": Color(1.0, 0.58, 0.36), "ray": 0.3, "ray_dir": Vector2(-0.9, 0.44), "cloud": 0.16,
		"fog_col": Color(0.98, 0.74, 0.72), "fog": 0.18, "haze": 0.42,
		"shadow_tint": Color(0.74, 0.76, 1.12), "high_tint": Color(1.12, 0.96, 0.82), "sat": 1.18, "contrast": 1.12,
		"vignette": 0.5, "shadow_dir": Vector2(-0.9, 0.44), "shadow_len": 2.1, "shadow_alpha": 0.54,
		"shadow_col": Color(0.24, 0.16, 0.42),
		"sky_top": Color(0.2, 0.18, 0.44), "sky_mid": Color(0.82, 0.46, 0.58), "sky_low": Color(1.0, 0.62, 0.36),
		"sun_col": Color(1.0, 0.62, 0.34), "sun_y": -95.0, "stars": 0.15, "night": 0.2, "snow": 0.8,
		"pal_dark": Color(0.15, 0.06, 0.28), "pal_mid": Color(0.84, 0.36, 0.42), "pal_light": Color(1.0, 0.84, 0.52), "poster": 0.36, "cloud_tint": Color(0.5, 0.42, 0.9),
	},
	"dusk": {
		"ambient": Color(0.56, 0.57, 0.76), "light_gain": 2.3, "bloom": 0.9,
		"ray_col": Color(0.6, 0.7, 1.0), "ray": 0.05, "ray_dir": Vector2(-0.6, 0.8), "cloud": 0.05,
		"fog_col": Color(0.36, 0.38, 0.55), "fog": 0.22, "haze": 0.45,
		"shadow_tint": Color(0.86, 0.88, 1.06), "high_tint": Color(1.08, 1.0, 0.92), "sat": 0.92, "contrast": 1.12,
		"vignette": 0.6, "shadow_dir": Vector2(-0.6, 0.8), "shadow_len": 0.95, "shadow_alpha": 0.34,
		"shadow_col": Color(0.08, 0.08, 0.25),
		"sky_top": Color(0.05, 0.06, 0.18), "sky_mid": Color(0.24, 0.22, 0.46), "sky_low": Color(0.82, 0.44, 0.46),
		"sun_col": Color(0.95, 0.5, 0.45), "sun_y": -20.0, "stars": 1.0, "night": 1.0, "snow": 1.0,
		"pal_dark": Color(0.04, 0.05, 0.16), "pal_mid": Color(0.36, 0.38, 0.68), "pal_light": Color(0.92, 0.86, 0.98), "poster": 0.24, "cloud_tint": Color(0.6, 0.62, 0.9),
	},
	"wrath": {
		"ambient": Color(0.86, 0.56, 0.52), "light_gain": 1.9, "bloom": 0.85,
		"ray_col": Color(1.0, 0.55, 0.25), "ray": 0.38, "ray_dir": Vector2(0.1, 1.0), "cloud": 0.32,
		"fog_col": Color(0.62, 0.26, 0.26), "fog": 0.24, "haze": 0.5,
		"shadow_tint": Color(0.66, 0.58, 0.82), "high_tint": Color(1.12, 0.94, 0.76), "sat": 1.12, "contrast": 1.18,
		"vignette": 0.65, "shadow_dir": Vector2(0.1, 1.0), "shadow_len": 1.5, "shadow_alpha": 0.55,
		"shadow_col": Color(0.25, 0.04, 0.1),
		"sky_top": Color(0.14, 0.03, 0.07), "sky_mid": Color(0.62, 0.14, 0.12), "sky_low": Color(1.0, 0.58, 0.2),
		"sun_col": Color(1.0, 0.45, 0.2), "sun_y": -70.0, "stars": 0.0, "night": 0.7, "snow": 1.2,
		"pal_dark": Color(0.1, 0.03, 0.07), "pal_mid": Color(0.8, 0.34, 0.2), "pal_light": Color(1.0, 0.88, 0.52), "poster": 0.26, "cloud_tint": Color(0.7, 0.3, 0.4),
	},
	"victory": {
		"ambient": Color(1.06, 0.96, 0.86), "light_gain": 1.8, "bloom": 0.8,
		"ray_col": Color(1.0, 0.86, 0.58), "ray": 0.5, "ray_dir": Vector2(-0.7, 0.7), "cloud": 0.25,
		"fog_col": Color(0.98, 0.86, 0.8), "fog": 0.12, "haze": 0.35,
		"shadow_tint": Color(0.8, 0.84, 1.1), "high_tint": Color(1.1, 1.0, 0.86), "sat": 1.15, "contrast": 1.1,
		"vignette": 0.45, "shadow_dir": Vector2(-0.7, 0.7), "shadow_len": 1.8, "shadow_alpha": 0.52,
		"shadow_col": Color(0.24, 0.2, 0.46),
		"sky_top": Color(0.3, 0.34, 0.62), "sky_mid": Color(0.9, 0.62, 0.66), "sky_low": Color(1.0, 0.84, 0.56),
		"sun_col": Color(1.0, 0.88, 0.62), "sun_y": -110.0, "stars": 0.0, "night": 0.0, "snow": 0.2,
		"pal_dark": Color(0.12, 0.1, 0.32), "pal_mid": Color(0.74, 0.5, 0.6), "pal_light": Color(1.0, 0.94, 0.76), "poster": 0.3, "cloud_tint": Color(0.46, 0.5, 0.95),
	},
}

var cam: Camera2D
var light_vp: SubViewport
var post: ColorRect
var overlay: Node2D
var sky_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var snow_nodes: Array = []
var cur: Dictionary = {}

var day := 0.0
var day_target := 0.0
var wrath := 0.0
var wrath_target := 0.0
var victory := 0.0
var victory_target := 0.0

var lights: Array = []          # static lights: {pos, r, col, flick, night}
var ink := 0.0
var ink_target := 0.0
var impact_t := 0.0
var impact_dur := 0.0
var flash := 0.0
var flash_col := Color(1.0, 0.95, 0.9)
var ca := 0.0
var letterbox := 0.0
var letterbox_target := 0.0
var hurt := 0.0
var blizzard := 0.0
var lightning := false
var bolt_t := 3.0
var bolts: Array = []
var gusts: Array = []
var gust_t := 2.0
var blur := 0.0
var blur_target := 0.0
var time := 0.0
var cam_center := Vector2.ZERO

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	cur = KEYS["golden"].duplicate()

func setup(owner_node: Node, camera: Camera2D, post_layer: int = 5) -> void:
	cam = camera
	light_vp = SubViewport.new()
	light_vp.size = Vector2i(Game.VIEW * 0.5)
	light_vp.transparent_bg = true
	light_vp.disable_3d = true
	light_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	light_vp.canvas_cull_mask = 2
	light_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(light_vp)
	light_vp.world_2d = owner_node.get_viewport().world_2d
	# Overlay drawn before post-processing (so lightning gets graded and bloomed).
	var ol := CanvasLayer.new()
	ol.layer = post_layer - 1
	add_child(ol)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	ol.add_child(overlay)
	var cl := CanvasLayer.new()
	cl.layer = post_layer
	add_child(cl)
	post = ColorRect.new()
	post.size = Game.VIEW
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/post.gdshader")
	mat.set_shader_parameter("light_tex", light_vp.get_texture())
	post.material = mat
	cl.add_child(post)

func add_light(pos: Vector2, r: float, col: Color, flick: float = 0.0, night_only: bool = false) -> Dictionary:
	var l := {"pos": pos, "r": r, "col": col, "flick": flick, "night": night_only, "ph": randf() * 10.0}
	lights.append(l)
	return l

# ------------------------------------------------------------------ effects API
func impact_frame(dur: float = 0.12) -> void:
	impact_t = dur
	impact_dur = dur

func do_flash(a: float, col: Color = Color(1.0, 0.95, 0.9)) -> void:
	flash = maxf(flash, a)
	flash_col = col

func aberrate(a: float) -> void:
	ca = maxf(ca, a)

func sun_shadow() -> Vector2:
	var d: Vector2 = cur["shadow_dir"]
	return d.normalized() * float(cur["shadow_len"])

func night() -> float:
	return float(cur["night"])

# ------------------------------------------------------------------ update
static func _lerp_v(a, b, t: float):
	if a is Color:
		return (a as Color).lerp(b, t)
	if a is Vector2:
		return (a as Vector2).lerp(b, t)
	return lerpf(a, b, t)

static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var o := {}
	for k in a.keys():
		o[k] = _lerp_v(a[k], b[k], t)
	return o

func _process(delta: float) -> void:
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	if get_tree().paused:
		rdt = delta
	rdt = minf(rdt, 0.1)
	time += rdt
	day = move_toward(day, day_target, rdt * 0.02)
	wrath = move_toward(wrath, wrath_target, rdt * 0.4)
	victory = move_toward(victory, victory_target, rdt * 0.25)
	var base: Dictionary
	if day < 0.5:
		base = blend(KEYS["golden"], KEYS["sunset"], smoothstep(0.0, 1.0, day * 2.0))
	else:
		base = blend(KEYS["sunset"], KEYS["dusk"], smoothstep(0.0, 1.0, (day - 0.5) * 2.0))
	base = blend(base, KEYS["wrath"], smoothstep(0.0, 1.0, wrath))
	cur = blend(base, KEYS["victory"], smoothstep(0.0, 1.0, victory))
	ink = move_toward(ink, ink_target, rdt * 2.5)
	impact_t = maxf(0.0, impact_t - rdt)
	flash = maxf(0.0, flash - rdt * 3.5)
	ca = maxf(0.0, ca - rdt * 12.0)
	letterbox = move_toward(letterbox, letterbox_target, rdt * 4.0)
	blur = move_toward(blur, blur_target, rdt * 4.0)
	_gusts(rdt)
	_lightning(rdt)
	_apply()

func _lightning(rdt: float) -> void:
	for b in bolts:
		b["t"] = float(b["t"]) - rdt
	bolts = bolts.filter(func(b): return float(b["t"]) > 0.0)
	if not lightning:
		return
	bolt_t -= rdt
	if bolt_t <= 0.0:
		bolt_t = randf_range(2.5, 6.0)
		var x := randf_range(60.0, Game.VIEW.x - 60.0)
		var pts := PackedVector2Array([Vector2(x + randf_range(-40, 40), -10)])
		var y := -10.0
		var px := pts[0].x
		while y < Game.VIEW.y * randf_range(0.35, 0.8):
			y += randf_range(10, 24)
			px += randf_range(-18, 18)
			pts.append(Vector2(px, y))
		bolts.append({"pts": pts, "t": 0.22})
		do_flash(0.55, Color(1.0, 0.85, 0.75))
		aberrate(3.0)
		Sfx.play("boom", -4.0, randf_range(0.7, 0.9))

## Occasional wind gusts: fast streaks of blown snow across the screen.
func _gusts(rdt: float) -> void:
	for g in gusts:
		g["x"] = float(g["x"]) + float(g["v"]) * rdt
	gusts = gusts.filter(func(g): return float(g["x"]) < Game.VIEW.x + 200.0)
	gust_t -= rdt
	if gust_t <= 0.0:
		gust_t = randf_range(3.0, 7.0) / (1.0 + blizzard * 2.0)
		var y0 := randf_range(30.0, Game.VIEW.y - 60.0)
		for i in randi_range(10, 22):
			gusts.append({"x": randf_range(-400.0, -40.0), "y": y0 + randf_range(-40.0, 40.0), "v": randf_range(380.0, 620.0),
				"l": randf_range(10.0, 34.0), "a": randf_range(0.25, 0.6)})

func _apply() -> void:
	if cam == null or post == null:
		return
	post.visible = not Game.low_gfx
	light_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED if Game.low_gfx else SubViewport.UPDATE_ALWAYS
	var ct := cam.get_viewport().get_canvas_transform()
	cam_center = Game.VIEW * 0.5 - ct.origin
	light_vp.canvas_transform = ct.scaled(Vector2(0.5, 0.5))
	var m: ShaderMaterial = post.material
	m.set_shader_parameter("cam", cam_center)
	m.set_shader_parameter("ambient", _c3(cur["ambient"]))
	m.set_shader_parameter("light_gain", cur["light_gain"])
	m.set_shader_parameter("bloom", cur["bloom"])
	m.set_shader_parameter("ray_col", _c3(cur["ray_col"]))
	m.set_shader_parameter("ray_strength", cur["ray"])
	m.set_shader_parameter("ray_dir", cur["ray_dir"])
	m.set_shader_parameter("cloud_shadow", cur["cloud"])
	m.set_shader_parameter("fog_col", _c3(cur["fog_col"]))
	m.set_shader_parameter("fog_density", cur["fog"])
	m.set_shader_parameter("haze", cur["haze"])
	m.set_shader_parameter("shadow_tint", _c3(cur["shadow_tint"]))
	m.set_shader_parameter("high_tint", _c3(cur["high_tint"]))
	m.set_shader_parameter("saturation", cur["sat"])
	m.set_shader_parameter("contrast", cur["contrast"])
	m.set_shader_parameter("vignette", cur["vignette"])
	m.set_shader_parameter("pal_dark", _c3(cur["pal_dark"]))
	m.set_shader_parameter("pal_mid", _c3(cur["pal_mid"]))
	m.set_shader_parameter("pal_light", _c3(cur["pal_light"]))
	m.set_shader_parameter("poster", cur["poster"])
	m.set_shader_parameter("cloud_tint", _c3(cur["cloud_tint"]))
	m.set_shader_parameter("hurt", hurt)
	m.set_shader_parameter("ink", ink)
	var imp := 1.0 if impact_t > 0.0 else 0.0
	m.set_shader_parameter("impact", imp)
	m.set_shader_parameter("impact_invert", 1.0 if impact_t > impact_dur * 0.5 else 0.0)
	m.set_shader_parameter("ca", ca)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("flash_col", _c3(flash_col))
	m.set_shader_parameter("letterbox", letterbox)
	m.set_shader_parameter("blizzard", blizzard)
	m.set_shader_parameter("blur", blur)
	if sky_mat:
		sky_mat.set_shader_parameter("cam", cam_center)
		sky_mat.set_shader_parameter("sky_top", _c3(cur["sky_top"]))
		sky_mat.set_shader_parameter("sky_mid", _c3(cur["sky_mid"]))
		sky_mat.set_shader_parameter("sky_low", _c3(cur["sky_low"]))
		sky_mat.set_shader_parameter("sun_col", _c3(cur["sun_col"]))
		sky_mat.set_shader_parameter("sun_y", cur["sun_y"])
		sky_mat.set_shader_parameter("stars", cur["stars"])
		sky_mat.set_shader_parameter("storm", wrath)
	if ground_mat:
		ground_mat.set_shader_parameter("sky_a", _c3(cur["sky_mid"]))
		ground_mat.set_shader_parameter("sky_b", _c3(cur["sky_low"]))
	var snow_k: float = float(cur["snow"]) + blizzard
	for s in snow_nodes:
		if is_instance_valid(s):
			s.speed_scale = 0.8 + snow_k * 0.6
			s.modulate.a = clampf(snow_k, 0.15, 1.0)
	overlay.queue_redraw()

func _c3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

func _draw_overlay() -> void:
	for g in gusts:
		var x: float = g["x"]
		var y: float = float(g["y"]) + sin(x * 0.02) * 4.0
		overlay.draw_rect(Rect2(Vector2(x, y).floor(), Vector2(float(g["l"]), 1)), Color(1, 1, 1, float(g["a"])))
	for b in bolts:
		var k := float(b["t"]) / 0.22
		var pts: PackedVector2Array = b["pts"]
		overlay.draw_polyline(pts, Color(0.75, 0.6, 1.0, 0.5 * k), 4.0)
		overlay.draw_polyline(pts, Color(1.0, 0.97, 0.9, k), 1.0)
