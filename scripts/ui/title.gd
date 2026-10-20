class_name TitleScreen
extends Node2D
## The cover: a live diorama built from the same baked art as the battles. In the golden hour
## the March's columns wind up the road toward Veyre, banners swaying, past the camp and the
## mill, under far blue mountains; a quiet editorial title sits over it on the left.
signal start_game
signal open_map
signal start_commander

var t := 0.0
var help := false
var hover := -1
const CREAM := Color("#f3e6c4")
const INK := Color("#141b1d")
const GOLD := Color("#e7c27a")
const S := 0.42                      # diorama scale: screen pixels per world unit
const ROAD_A := Vector2(470.0, 900.0)
const ROAD_B := Vector2(900.0, 720.0)
const ROAD_C := Vector2(1010.0, 556.0)
const MENU := [["ENTER", "MARCH TO BATTLE"], ["3", "COMMAND BELLACOURT"], ["M", "CAMPAIGN ATLAS"]]
const MENU_Y := 262.0

var dio: Node2D
var world: Node2D
var shadows: Node2D
var overlay: Node2D
var ui: Node2D
var soldiers: Array = []             # {node, body, wpn, s, lane, ph, sheet, wsheet, dir, banner}
var motes: Array = []
var clouds: Array = []
var fxt := {}
var hazes := {}
var glow: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	Game.command_view = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("horn", -12.0, 0.8)
	for n in ["smoke_2", "smoke_3"]:
		fxt[n] = load("res://assets/fx/%s.png" % n)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.45))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 128
	glow = gt
	_build()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	overlay.queue_redraw()
	ui.queue_redraw()
	_march(delta)
	# a slow push in, drifting toward the city
	var k := minf(t / 40.0, 1.0)
	dio.scale = Vector2.ONE * S * (1.0 + 0.05 * k)
	dio.position = Vector2(-4.0 - 18.0 * k, -2.0 - 10.0 * k)
	if OS.get_cmdline_user_args().has("--test-chapter3-entry") and t > 0.8 and not has_meta("entry_test"):
		set_meta("entry_test", true)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_3
		key.pressed = true
		Input.parse_input_event(key)
	var mp := get_viewport().get_mouse_position()
	hover = -1
	for i in MENU.size():
		if _item_rect(i).has_point(mp):
			hover = i
	if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack"):
		if t > 0.5:
			if Input.is_action_just_pressed("attack") and hover == 1:
				start_commander.emit()
			elif Input.is_action_just_pressed("attack") and hover == 2:
				open_map.emit()
			else:
				start_game.emit()
	if Input.is_action_just_pressed("help"):
		help = not help
	if OS.get_cmdline_user_args().has("--autostart") and t > 1 and not has_meta("started"):
		set_meta("started", true)
		start_game.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			open_map.emit()
		elif event.physical_keycode == KEY_3:
			start_commander.emit()

func _item_rect(i: int) -> Rect2:
	return Rect2(26.0, MENU_Y + i * 20.0 - 13.0, 220.0, 18.0)

# ------------------------------------------------------------------ the diorama
func _build() -> void:
	dio = Node2D.new()
	dio.scale = Vector2.ONE * S
	add_child(dio)
	var g := ColorRect.new()
	g.position = Vector2(-120.0, 240.0)
	g.size = Vector2(1800.0, 760.0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/title_ground.gdshader")
	gm.set_shader_parameter("origin", g.position)
	gm.set_shader_parameter("road_a", ROAD_A)
	gm.set_shader_parameter("road_b", ROAD_B)
	gm.set_shader_parameter("road_c", ROAD_C)
	g.material = gm
	dio.add_child(g)
	var clutter := Node2D.new()
	dio.add_child(clutter)
	shadows = Node2D.new()
	shadows.modulate = Color(1, 1, 1, 0.34)
	dio.add_child(shadows)
	world = Node2D.new()
	world.y_sort_enabled = true
	dio.add_child(world)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	ui = Node2D.new()
	ui.draw.connect(_draw_ui)
	add_child(ui)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# the far forest under the hills: a hazy band across the whole valley, then nearer woods
	for i in 150:
		var p := Vector2(rng.randf_range(-120.0, 1750.0), rng.randf_range(300.0, 400.0))
		_prop(["pine_1", "pine_2", "pine_4", "oak_2", "oak_4"][rng.randi() % 5], p, rng.randf_range(0.34, 0.48), rng.randf() < 0.5, Color.WHITE, false, 0.55 - (p.y - 300.0) / 100.0 * 0.15)
	for i in 60:
		var p := Vector2(rng.randf_range(-80.0, 760.0), rng.randf_range(400.0, 470.0))
		_prop(["pine_1", "pine_2", "pine_4", "oak_2", "oak_4"][rng.randi() % 5], p, rng.randf_range(0.42, 0.6), rng.randf() < 0.5, Color.WHITE, false, 0.32)
	for i in 26:
		var p := Vector2(rng.randf_range(1380.0, 1720.0), rng.randf_range(420.0, 520.0))
		_prop(["pine_2", "pine_3", "oak_1", "oak_3"][rng.randi() % 4], p, rng.randf_range(0.5, 0.7), rng.randf() < 0.5, Color.WHITE, true, 0.22)
	# Veyre: the keep on its rise, its town and the curtain wall with the gate on the road
	_prop("castle_blue", Vector2(1110, 512), 0.5, false, Color.WHITE, true, 0.14)
	_prop("tower_b_blue", Vector2(905, 515), 0.55, false)
	_prop("church_blue", Vector2(1270, 520), 0.5, true)
	_prop("tower_a_blue", Vector2(1345, 528), 0.5, false)
	for x in [960.0, 1190.0, 1230.0, 860.0]:
		_prop(["house_a_blue", "house_b_blue"][rng.randi() % 2], Vector2(x, 530 + rng.randf_range(-6, 6)), 0.42, rng.randf() < 0.5)
	var x := 760.0
	while x < 1430.0:
		if absf(x - ROAD_C.x) < 40.0:
			_prop("wall_gate", Vector2(ROAD_C.x, 560), 0.62, false)
		else:
			_prop("wall_seg", Vector2(x, 562), 0.62, false)
		x += 120.0 * 0.62
	_prop("tower_a_blue", Vector2(752, 572), 0.62, false)
	_prop("tower_a_blue", Vector2(1440, 572), 0.62, true)
	for fx in [870.0, 1150.0, 1300.0]:
		_prop("flag_blue", Vector2(fx, 548), 0.55, false)
	# the mill and its fields on the left
	_prop("windmill_blue", Vector2(300, 560), 0.6, false)
	for i in 7:
		_prop("grain", Vector2(160 + i * 52 + rng.randf_range(-8, 8), 600 + (i % 2) * 26), 0.5, rng.randf() < 0.5)
	# woods flanking the road
	for i in 34:
		var p := Vector2(rng.randf_range(560.0, 760.0), rng.randf_range(520.0, 640.0))
		_prop(["oak_1", "oak_2", "oak_3", "oak_5", "pine_1"][rng.randi() % 5], p, rng.randf_range(0.6, 0.85), rng.randf() < 0.5)
	for i in 18:
		var p := Vector2(rng.randf_range(1180.0, 1560.0), rng.randf_range(620.0, 760.0))
		_prop(["oak_1", "oak_3", "oak_4", "oak_2", "pine_2"][rng.randi() % 5], p, rng.randf_range(0.7, 0.95), rng.randf() < 0.5)
	# the March's camp in the foreground
	for c in [["tent", Vector2(200, 760)], ["tent_b", Vector2(300, 790)], ["tent", Vector2(120, 830)], ["tent_b", Vector2(380, 860)],
			["cart", Vector2(420, 780)], ["barrel", Vector2(250, 820)], ["crates_long", Vector2(170, 880)], ["flag_red", Vector2(345, 760)],
			["flag_red", Vector2(80, 760)], ["weaponrack", Vector2(450, 840)], ["sack", Vector2(230, 840)]]:
		_prop(c[0], c[1], 0.75, rng.randf() < 0.5)
	# rocks and brush along the verges, big oaks framing the foreground
	for i in 24:
		var p := Vector2(rng.randf_range(420.0, 1500.0), rng.randf_range(650.0, 900.0))
		if _road_d(p) < 60.0:
			continue
		_prop(["bush_2", "rock_1", "rock_2", "boulder_1", "bush_2"][rng.randi() % 5], p, rng.randf_range(0.6, 0.9), rng.randf() < 0.5)
	_prop("oak_1", Vector2(-10, 930), 1.7, false, Color(0.62, 0.62, 0.66))
	_prop("oak_3", Vector2(1560, 950), 1.9, true, Color(0.6, 0.6, 0.66))
	_prop("oak_5", Vector2(1450, 990), 1.5, false, Color(0.55, 0.55, 0.6))
	# grass, flowers and pebbles over the meadow
	clutter.draw.connect(func():
		var r2 := RandomNumberGenerator.new()
		r2.seed = 9
		var names := ["grass_1", "grass_2", "grass_3", "grass_4", "flowers_1", "flowers_2", "clover_1", "pebble_1", "pebble_2"]
		for i in 900:
			var p := Vector2(r2.randf_range(-100.0, 1650.0), r2.randf_range(440.0, 960.0))
			if _road_d(p) < 34.0:
				continue
			var nm: String = names[r2.randi() % names.size()]
			if not PropArt.regions.has(nm):
				continue
			var rg: Rect2 = PropArt.regions[nm]
			var a := PropArt.anchor(nm)
			var k := r2.randf_range(0.7, 1.1) / PropArt.R
			var hz := clampf((p.y - 440.0) / 300.0, 0.0, 1.0)
			clutter.draw_texture_rect_region(PropArt.atlas, Rect2(p - a * k, rg.size * k), rg, Color(1.0, 1.0, 1.0, 0.5 + 0.5 * hz)))
	# the column on the road
	_muster(rng)
	for i in 70:
		motes.append([Vector2(randf_range(0, 640), randf_range(0, 360)), randf_range(0.0, TAU), randf_range(0.4, 1.2)])
	for i in 9:
		clouds.append([randf_range(-100, 700), randf_range(14, 120), randf_range(0.6, 1.4), randf_range(3.0, 8.0)])

func _prop(name: String, pos: Vector2, s: float, flip: bool, mod: Color = Color.WHITE, shadow := true, haze := 0.0) -> void:
	if not PropArt.has(name):
		return
	var spr := Sprite2D.new()
	if haze > 0.0:
		if not hazes.has(haze):
			var hm := ShaderMaterial.new()
			hm.shader = load("res://shaders/haze.gdshader")
			hm.set_shader_parameter("haze_col", Color("#cfd8d0"))
			hm.set_shader_parameter("amount", haze)
			hazes[haze] = hm
		spr.material = hazes[haze]
	spr.texture = PropArt.tex(name)
	spr.centered = false
	spr.flip_h = flip
	var a := PropArt.anchor(name)
	spr.offset = Vector2(-(float(spr.texture.get_width()) - a.x) if flip else -a.x, -a.y)
	spr.scale = Vector2(s, s) / PropArt.R
	spr.position = pos
	spr.modulate = mod
	world.add_child(spr)
	var st := PropArt.shadow_tex(name)
	if shadow and st != null:
		var sh := Sprite2D.new()
		sh.texture = st
		sh.centered = false
		sh.offset = -PropArt.shadow_anchor(name)
		sh.scale = Vector2(s, s) / PropArt.R
		sh.position = pos
		shadows.add_child(sh)

func _road(s: float) -> Vector2:
	return ROAD_A.lerp(ROAD_B, s).lerp(ROAD_B.lerp(ROAD_C, s), s)

func _road_d(p: Vector2) -> float:
	var d := 1e9
	for i in 25:
		d = minf(d, p.distance_to(_road(i / 24.0)))
	return d

## The army on the march: files four abreast, a banner every few ranks.
func _muster(rng: RandomNumberGenerator) -> void:
	var kits := [["spear", "spear"], ["spear", "spear"], ["infantry", "sword_shield"], ["heavy", "axe"], ["archer", "bow"]]
	var ranks := 30
	for r in ranks:
		var kit: Array = kits[(r / 3) % kits.size()]
		for lane in 4:
			var n := Node2D.new()
			world.add_child(n)
			var body := Sprite2D.new()
			var wpn := Sprite2D.new()
			for sp in [body, wpn]:
				sp.centered = false
				sp.region_enabled = true
				sp.material = UnitArt.materials.get("march")
				sp.scale = Vector2.ONE / UnitArt.R
				n.add_child(sp)
			var banner: Node2D = null
			if lane == 1 and r % 5 == 2:
				banner = Node2D.new()
				banner.set_meta("ph", rng.randf() * TAU)
				banner.draw.connect(_draw_banner.bind(banner))
				n.add_child(banner)
			soldiers.append({"node": n, "body": body, "wpn": wpn, "s": float(r) / ranks, "lane": lane - 1.5,
				"ph": rng.randf() * 6.0, "sheet": UnitArt.body_sheet(kit[0], kit[1]), "wsheet": UnitArt.weapon_sheet(kit[1]),
				"banner": banner, "j": Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))})

func _march(delta: float) -> void:
	for so in soldiers:
		var s: float = fposmod(float(so["s"]) + delta * 0.022, 1.0)
		so["s"] = s
		var p := _road(s)
		var ahead := _road(minf(s + 0.01, 1.0)) - _road(maxf(s - 0.01, 0.0))
		var side := ahead.normalized().orthogonal()
		var width := lerpf(1.0, 0.55, s)
		var n: Node2D = so["node"]
		n.position = p + side * float(so["lane"]) * 11.0 * width + so["j"]
		var fade := smoothstep(0.0, 0.05, s) * (1.0 - smoothstep(0.9, 0.99, s))
		n.modulate = Color(1, 1, 1, fade)
		var dir8 := UnitArt.dir_index(ahead)
		var dk: Array = UnitArt.DIR8[dir8]
		var fl: Array = UnitArt.frames(so["sheet"], "walk", dk[0])
		if fl.is_empty():
			continue
		var fi := int(t * 7.5 + float(so["ph"])) % fl.size()
		_frame(so["body"], fl[fi], dk[1])
		var wl: Array = UnitArt.frames(so["wsheet"], "walk", dk[0])
		_frame(so["wpn"], wl[fi] if fi < wl.size() else null, dk[1])
		if so["banner"] != null:
			so["banner"].queue_redraw()

func _frame(sp: Sprite2D, fr, flip: bool) -> void:
	if fr == null:
		sp.visible = false
		return
	sp.visible = true
	sp.texture = fr["tex"]
	sp.region_rect = fr["rect"]
	sp.flip_h = flip
	sp.offset = Vector2(-(float(fr["w"]) - float(fr["ax"])) if flip else -float(fr["ax"]), -float(fr["ay"]))

func _draw_banner(b: Node2D) -> void:
	var ph: float = b.get_meta("ph")
	var top := Vector2(5, -62)
	b.draw_line(Vector2(5, -6), top, Color("#2a1a10"), 2.4, true)
	b.draw_circle(top + Vector2(0, -2), 2.2, Color("#f0c860"))
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		var w := sin(t * 3.6 - k * 3.2 + ph) * 3.0 * k
		up.append(top + Vector2(k * 30.0, 3.0 + w))
		lo.append(top + Vector2(k * 30.0, 22.0 - k * 3.0 + w))
	for i in 6:
		var sh := 0.8 + 0.2 * cos(t * 3.6 - (i + 0.5) / 6.0 * 3.2 + ph - 0.6)
		b.draw_colored_polygon(PackedVector2Array([up[i], up[i + 1], lo[i + 1], lo[i]]), Color(0.78 * sh, 0.2 * sh, 0.16 * sh))
	b.draw_polyline(up, Color(1.0, 0.7, 0.5, 0.8), 1.0, true)
	b.draw_circle((up[2] + lo[2]) * 0.5, 4.0, Color("#e8c060"))

# ------------------------------------------------------------------ sky, light, type
func _draw() -> void:
	# golden-hour sky: deep teal overhead warming to cream and peach at the horizon
	var top := Color("#3d6a78")
	var mid := Color("#9cc0c0")
	var low := Color("#f3d9a6")
	var cols := PackedColorArray([top, top, mid, mid])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(640, 0), Vector2(640, 80), Vector2(0, 80)]), cols)
	draw_polygon(PackedVector2Array([Vector2(0, 80), Vector2(640, 80), Vector2(640, 170), Vector2(0, 170)]), PackedColorArray([mid, mid, low, low]))
	# the low sun behind the city
	draw_texture_rect(glow, Rect2(Vector2(470, 84) - Vector2(260, 170), Vector2(520, 340)), false, Color(1.0, 0.84, 0.56, 0.6))
	draw_texture_rect(glow, Rect2(Vector2(470, 92) - Vector2(46, 46), Vector2(92, 92)), false, Color(1.0, 0.96, 0.84, 0.95))
	# far ranges: layered ridges, paler and bluer with distance
	var ridges := [[Color("#9fb7bd"), 92.0, 26.0, 0.011, 3.0], [Color("#88a3a3"), 104.0, 20.0, 0.017, 7.0], [Color("#768f86"), 114.0, 12.0, 0.026, 11.0]]
	for rd in ridges:
		var pts := PackedVector2Array([Vector2(0, 200)])
		for i in 65:
			var x := i * 10.0
			var y: float = rd[1] - (sin(x * rd[3] + rd[4]) * 0.6 + sin(x * rd[3] * 2.3 + rd[4] * 1.7) * 0.3 + sin(x * rd[3] * 5.1) * 0.1) * rd[2]
			pts.append(Vector2(x, y))
		pts.append(Vector2(640, 200))
		draw_colored_polygon(pts, rd[0])
	# drifting clouds
	for c in clouds:
		var x := fposmod(float(c[0]) + t * float(c[3]), 820.0) - 120.0
		var tx: Texture2D = fxt["smoke_2"] if int(c[1]) % 2 == 0 else fxt["smoke_3"]
		var w := 170.0 * float(c[2])
		draw_texture_rect(tx, Rect2(Vector2(x, float(c[1])) - Vector2(w, w * 0.28) * 0.5, Vector2(w, w * 0.28)), false, Color(1.0, 0.95, 0.86, 0.5))

func _draw_overlay() -> void:
	# warm light pouring over the scene from the sun side, and pollen drifting in it
	overlay.draw_texture_rect(glow, Rect2(Vector2(200, -160), Vector2(620, 480)), false, Color(1.0, 0.8, 0.5, 0.16))
	for m in motes:
		var p: Vector2 = m[0]
		var x := fposmod(p.x + t * 9.0 * float(m[2]) + sin(t * 0.7 + float(m[1])) * 12.0, 660.0) - 10.0
		var y := fposmod(p.y + sin(t * 0.5 + float(m[1])) * 10.0 - t * 3.0, 380.0) - 10.0
		var a := 0.25 + 0.25 * sin(t * 2.0 + float(m[1]))
		overlay.draw_circle(Vector2(x, y), 0.7 * float(m[2]), Color(1.0, 0.92, 0.7, a))
	# a dark wash on the left so the type reads, and a vignette
	var c0 := Color(INK.r, INK.g, INK.b, 0.82)
	var c1 := Color(INK.r, INK.g, INK.b, 0.0)
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(360, 0), Vector2(360, 360), Vector2(0, 360)]), PackedColorArray([c0, c1, c1, c0]))
	var v0 := Color(0, 0, 0, 0.0)
	var v1 := Color(0.02, 0.02, 0.04, 0.45)
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 300), Vector2(640, 300), Vector2(640, 360), Vector2(0, 360)]), PackedColorArray([v0, v0, v1, v1]))
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(640, 0), Vector2(640, 40), Vector2(0, 40)]), PackedColorArray([v1, v1, v0, v0]))
	# letterbox
	var lb := clampf(t / 1.2, 0.0, 1.0)
	overlay.draw_rect(Rect2(0, 0, 640, 14.0 * lb), Color(0.01, 0.01, 0.02))
	overlay.draw_rect(Rect2(0, 360 - 14.0 * lb, 640, 14.0 * lb), Color(0.01, 0.01, 0.02))

func _draw_ui() -> void:
	var a := clampf((t - 0.3) / 1.0, 0.0, 1.0)
	var c := Color(CREAM.r, CREAM.g, CREAM.b, a)
	var g := Color(GOLD.r, GOLD.g, GOLD.b, a)
	Game.text(ui, Vector2(32, 66), "A FIELD CHRONICLE   -   CHAPTER I", 4, Color(g.r, g.g, g.b, a * 0.85), 0, 0, false)
	Game.text(ui, Vector2(29, 116), "GOLDEN", 30, c, 0, 1, true)
	Game.text(ui, Vector2(29, 163), "MARCH", 30, c, 0, 1, true)
	var lw := 150.0 * clampf((t - 0.6) / 0.8, 0.0, 1.0)
	ui.draw_rect(Rect2(32, 178, lw, 0.8), g)
	ui.draw_rect(Rect2(32 + lw, 177.2, 2.4, 2.4), g)
	Game.text(ui, Vector2(32, 198), "THE SIEGE OF VEYRE", 7, c, 0, 0, false)
	Game.text(ui, Vector2(32, 214), "Lead the line. Break the crown.", 6, Color(c.r, c.g, c.b, a * 0.75), 0, 2, false)
	for i in MENU.size():
		var y := MENU_Y + i * 20.0
		var on := hover == i or (hover < 0 and i == 0)
		var k := 1.0 if on else 0.0
		var x := 34.0 + k * 6.0
		if on:
			ui.draw_rect(Rect2(26, y - 9.0, 3.0, 3.0), g)
			ui.draw_rect(Rect2(x - 2.0, y + 3.0, Game.text_w(MENU[i][1], 7) + 4.0, 0.6), Color(g.r, g.g, g.b, a * 0.6))
		Game.text(ui, Vector2(x, y), MENU[i][1], 7, c if on else Color(c.r, c.g, c.b, a * 0.62), 0, 0, false)
		Game.text(ui, Vector2(x + Game.text_w(MENU[i][1], 7) + 8.0, y), MENU[i][0], 4, Color(g.r, g.g, g.b, a * (0.9 if on else 0.45)), 0, 0, false)
	Game.text(ui, Vector2(32, 336), "H  CONTROLS     F11  FULLSCREEN", 4, Color(c.r, c.g, c.b, a * 0.5), 0, 0, false)
	if help:
		ui.draw_rect(Rect2(300, 226, 316, 76), Color(INK.r, INK.g, INK.b, 0.9))
		ui.draw_rect(Rect2(300, 226, 316, 0.8), g)
		Game.text(ui, Vector2(314, 244), "WASD MOVE / CLICK ATTACK / SPACE DASH", 5, CREAM, 0, 0, false)
		Game.text(ui, Vector2(314, 258), "TAB COMMAND / RIGHT CLICK PLACE / Q FORMATION", 5, CREAM, 0, 0, false)
		Game.text(ui, Vector2(314, 272), "1 FOLLOW / 2 ADVANCE / 3 HOLD", 5, CREAM, 0, 0, false)
		Game.text(ui, Vector2(314, 286), "E SKILL / R HEAL / F INTERACT / H IN-GAME HELP", 5, CREAM, 0, 0, false)
