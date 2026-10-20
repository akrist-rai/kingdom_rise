class_name Atmos
extends Node
## Time of day, lighting and post-processing.
## The battle moves through blue dawn -> ember dusk -> night; the general's last phase turns the
## sky to Wrath (burning red-gold storm) and victory brings the light back.
## Owns the half-resolution light buffer (a SubViewport sharing the world, showing only
## canvas items on visibility layer 2) and the post shader that combines everything.

## Times of day, in the blue-hour palette of the WLOP references: slate blue and teal with a
## peach glow on the horizon. Key names are kept from the first version of the game:
## "golden" is now blue dawn, "sunset" is ember dusk, "dusk" is night.
const KEYS := {
	"golden": {
		"ambient": Color(0.86, 0.92, 1.0), "light_gain": 1.5, "bloom": 0.4,
		"ray_col": Color(1.0, 0.8, 0.66), "ray": 0.16, "ray_dir": Vector2(-0.55, 0.84), "cloud": 0.18,
		"fog_col": Color(0.6, 0.7, 0.78), "fog": 0.26, "haze": 0.55,
		"shadow_tint": Color(0.86, 0.9, 1.1), "high_tint": Color(1.1, 1.0, 0.9), "sat": 1.04, "contrast": 1.1,
		"vignette": 0.5, "shadow_dir": Vector2(-0.55, 0.84), "shadow_len": 1.5, "shadow_alpha": 0.5,
		"shadow_col": Color(0.07, 0.08, 0.22),
		"sky_top": Color(0.13, 0.23, 0.31), "sky_mid": Color(0.45, 0.58, 0.67), "sky_low": Color(0.98, 0.72, 0.6),
		"sun_col": Color(1.0, 0.78, 0.64), "sun_y": -60.0, "stars": 0.0, "night": 0.15, "snow": 0.6,
		"pal_dark": Color(0.04, 0.07, 0.16), "pal_mid": Color(0.38, 0.43, 0.62), "pal_light": Color(0.98, 0.88, 0.8), "poster": 0.1, "cloud_tint": Color(0.52, 0.56, 0.86), "paper": 0.3, "tilt": 0.08,
	},
	"sunset": {
		"ambient": Color(0.98, 0.86, 0.84), "light_gain": 1.7, "bloom": 0.6,
		"ray_col": Color(1.0, 0.62, 0.46), "ray": 0.24, "ray_dir": Vector2(-0.9, 0.44), "cloud": 0.16,
		"fog_col": Color(0.74, 0.62, 0.64), "fog": 0.24, "haze": 0.55,
		"shadow_tint": Color(0.78, 0.88, 1.1), "high_tint": Color(1.12, 0.97, 0.86), "sat": 1.0, "contrast": 1.12,
		"vignette": 0.55, "shadow_dir": Vector2(-0.9, 0.44), "shadow_len": 2.1, "shadow_alpha": 0.54,
		"shadow_col": Color(0.06, 0.08, 0.18),
		"sky_top": Color(0.1, 0.17, 0.27), "sky_mid": Color(0.44, 0.48, 0.6), "sky_low": Color(1.0, 0.6, 0.48),
		"sun_col": Color(1.0, 0.62, 0.45), "sun_y": -40.0, "stars": 0.12, "night": 0.3, "snow": 0.75,
		"pal_dark": Color(0.05, 0.05, 0.14), "pal_mid": Color(0.46, 0.39, 0.58), "pal_light": Color(1.0, 0.8, 0.66), "poster": 0.1, "cloud_tint": Color(0.48, 0.46, 0.8), "paper": 0.3, "tilt": 0.08,
	},
	"dusk": {
		"ambient": Color(0.5, 0.6, 0.74), "light_gain": 2.3, "bloom": 0.85,
		"ray_col": Color(0.6, 0.72, 0.9), "ray": 0.04, "ray_dir": Vector2(-0.6, 0.8), "cloud": 0.05,
		"fog_col": Color(0.24, 0.34, 0.42), "fog": 0.26, "haze": 0.5,
		"shadow_tint": Color(0.86, 0.94, 1.06), "high_tint": Color(1.08, 1.0, 0.92), "sat": 0.9, "contrast": 1.12,
		"vignette": 0.6, "shadow_dir": Vector2(-0.6, 0.8), "shadow_len": 0.95, "shadow_alpha": 0.3,
		"shadow_col": Color(0.02, 0.06, 0.12),
		"sky_top": Color(0.03, 0.07, 0.12), "sky_mid": Color(0.14, 0.24, 0.33), "sky_low": Color(0.62, 0.46, 0.46),
		"sun_col": Color(0.9, 0.56, 0.48), "sun_y": -10.0, "stars": 1.0, "night": 1.0, "snow": 1.0,
		"pal_dark": Color(0.02, 0.03, 0.1), "pal_mid": Color(0.25, 0.3, 0.52), "pal_light": Color(0.9, 0.86, 0.9), "poster": 0.08, "cloud_tint": Color(0.6, 0.62, 0.9), "paper": 0.3, "tilt": 0.08,
	},
	"wrath": {
		"ambient": Color(0.86, 0.6, 0.56), "light_gain": 1.9, "bloom": 0.85,
		"ray_col": Color(1.0, 0.55, 0.3), "ray": 0.3, "ray_dir": Vector2(0.1, 1.0), "cloud": 0.3,
		"fog_col": Color(0.5, 0.26, 0.26), "fog": 0.26, "haze": 0.5,
		"shadow_tint": Color(0.62, 0.7, 0.86), "high_tint": Color(1.12, 0.94, 0.76), "sat": 1.08, "contrast": 1.18,
		"vignette": 0.65, "shadow_dir": Vector2(0.1, 1.0), "shadow_len": 1.5, "shadow_alpha": 0.5,
		"shadow_col": Color(0.12, 0.03, 0.08),
		"sky_top": Color(0.1, 0.04, 0.07), "sky_mid": Color(0.5, 0.16, 0.14), "sky_low": Color(1.0, 0.55, 0.26),
		"sun_col": Color(1.0, 0.45, 0.22), "sun_y": -60.0, "stars": 0.0, "night": 0.7, "snow": 1.2,
		"pal_dark": Color(0.06, 0.04, 0.08), "pal_mid": Color(0.66, 0.28, 0.2), "pal_light": Color(1.0, 0.82, 0.56), "poster": 0.08, "cloud_tint": Color(0.62, 0.32, 0.4), "paper": 0.3, "tilt": 0.08,
	},
	# The Siege of Handan: a deep blue-violet night, the city burning (fire-lit horizon,
	# salmon highlights, violet shadows).
	"siege": {
		"ambient": Color(1.02, 1.0, 0.95), "light_gain": 0.85, "bloom": 0.32,
		"ray_col": Color(1.0, 0.86, 0.6), "ray": 0.07, "ray_dir": Vector2(0.62, 0.78), "cloud": 0.08,
		"fog_col": Color(0.78, 0.84, 0.86), "fog": 0.035, "haze": 0.16,
		"shadow_tint": Color(0.86, 0.95, 1.08), "high_tint": Color(1.07, 1.0, 0.88), "sat": 0.98, "contrast": 1.06,
		"vignette": 0.23, "shadow_dir": Vector2(0.66, 0.3), "shadow_len": 1.4, "shadow_alpha": 0.3,
		"shadow_col": Color(0.08, 0.12, 0.2),
		"sky_top": Color(0.25, 0.47, 0.55), "sky_mid": Color(0.59, 0.72, 0.69), "sky_low": Color(0.98, 0.86, 0.62),
		"sun_col": Color(1.0, 0.9, 0.67), "sun_y": -80.0, "stars": 0.0, "night": 0.0, "snow": 0.03,
		"pal_dark": Color(0.08, 0.14, 0.2), "pal_mid": Color(0.5, 0.56, 0.42), "pal_light": Color(1.0, 0.94, 0.78), "poster": 0.0, "cloud_tint": Color(0.5, 0.58, 0.72), "paper": 0.22, "tilt": 0.06,
	},

	"victory": {
		"ambient": Color(1.04, 0.98, 0.94), "light_gain": 1.8, "bloom": 0.8,
		"ray_col": Color(1.0, 0.84, 0.68), "ray": 0.42, "ray_dir": Vector2(-0.7, 0.7), "cloud": 0.2,
		"fog_col": Color(0.8, 0.76, 0.76), "fog": 0.16, "haze": 0.4,
		"shadow_tint": Color(0.82, 0.92, 1.08), "high_tint": Color(1.1, 1.0, 0.9), "sat": 1.0, "contrast": 1.1,
		"vignette": 0.45, "shadow_dir": Vector2(-0.7, 0.7), "shadow_len": 1.8, "shadow_alpha": 0.45,
		"shadow_col": Color(0.06, 0.12, 0.22),
		"sky_top": Color(0.2, 0.3, 0.42), "sky_mid": Color(0.62, 0.66, 0.74), "sky_low": Color(1.0, 0.8, 0.64),
		"sun_col": Color(1.0, 0.84, 0.68), "sun_y": -90.0, "stars": 0.0, "night": 0.0, "snow": 0.2,
		"pal_dark": Color(0.05, 0.12, 0.2), "pal_mid": Color(0.5, 0.56, 0.64), "pal_light": Color(1.0, 0.92, 0.82), "poster": 0.08, "cloud_tint": Color(0.56, 0.66, 0.9), "paper": 0.3, "tilt": 0.08,
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
var base_key := ""          # a level can pin its own time of day (the siege is night)
var light_soft := 0.0       # smooth light falloff instead of flat pools (cities full of fires)
var wrath := 0.0
var wrath_target := 0.0
var victory := 0.0
var victory_target := 0.0

var lights: Array = []          # static lights: {pos, r, col, flick, night}
var ink := 0.0
var ink_target := 0.0
var impact_t := 0.0
var impact_dur := 0.0
var impact_uv := Vector2(0.5, 0.5)
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
	impact_uv = Vector2(0.5, 0.5)

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
	if base_key != "":
		base = KEYS[base_key]
	elif day < 0.5:
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
	var z := ct.x.x
	cam_center = (Game.VIEW * 0.5 - ct.origin) / z
	light_vp.canvas_transform = ct.scaled(Vector2(0.5, 0.5))
	var m: ShaderMaterial = post.material
	m.set_shader_parameter("cam", cam_center)
	m.set_shader_parameter("zoom", z)
	m.set_shader_parameter("ambient", _c3(cur["ambient"]))
	m.set_shader_parameter("light_gain", cur["light_gain"])
	m.set_shader_parameter("light_soft", light_soft)
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
	m.set_shader_parameter("horizon", _c3(cur["sky_low"]))
	m.set_shader_parameter("horizon_k", 0.3 * (1.0 - float(cur["night"]) * 0.6))
	m.set_shader_parameter("hurt", hurt)
	m.set_shader_parameter("ink", ink)
	var imp := clampf(impact_t / maxf(impact_dur, 0.001), 0.0, 1.0)
	m.set_shader_parameter("impact", imp * imp * (3.0 - 2.0 * imp))
	m.set_shader_parameter("impact_pos", impact_uv)
	m.set_shader_parameter("impact_invert", 1.0 if impact_t > impact_dur * 0.5 else 0.0)
	m.set_shader_parameter("ca", ca)
	m.set_shader_parameter("flash", flash)
	m.set_shader_parameter("flash_col", _c3(flash_col))
	m.set_shader_parameter("letterbox", letterbox)
	m.set_shader_parameter("blizzard", blizzard)
	m.set_shader_parameter("blur", blur)
	m.set_shader_parameter("paper", cur["paper"])
	m.set_shader_parameter("tilt", cur["tilt"] * (1.0 - float(Game.command_view)))
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
