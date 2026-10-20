class_name CampaignMap
extends Control
## The campaign map: the Warring States countryside painted from high above, in the style of
## illustrated bird's-eye maps. A patchwork of fields, forests and a snowy north (shader),
## then painted mountains, rivers and the sea, roads, villages, and the great walled city of
## Veyre burning under the Qin siege, with the Qin camps around it. Battles are picked here.
## The geography is stylised Warring States China, not an accurate map.

signal march(battle_id: String)
signal back

const INK := Color("#221d28")
const SOFT := Color(0.13, 0.11, 0.16, 0.7)
const PAPER := Color(0.925, 0.9, 0.82)
const HALO := Color(0.96, 0.93, 0.86, 0.9)
const RIVER := Color("#3f78b8")
const RIVER_DK := Color("#24406e")
const RIVER_LT := Color("#8fc0dc")
const SEA := Color("#2a4f78")
const SEA_LT := Color("#3f7c9a")
const FOAM := Color(0.86, 0.93, 0.95, 0.85)
const ROAD := Color("#e6d2a2")
const QIN := Color("#c62a2f")
const ZHAO := Color("#2c4dae")
const REGION := Color(0.32, 0.12, 0.12, 0.42)
const STONE := Color("#b9adbc")
const STONE_DK := Color("#5e5470")
const OUTER := Rect2(8, 8, 624, 344)
const FRAME := Rect2(14, 14, 612, 332)
const VEYRE := Rect2(305, 128, 68, 46)
const PALACE := Rect2(350, 137, 18, 16)
const AVE_Y := 151.0

const NODES := [
	{"id": "handan", "name": "I. The Siege of Veyre", "pos": Vector2(339, 151), "label_off": Vector2(0, 40), "ring": Vector2(46, 34),
		"sub": "Breach the Crown's last citadel",
		"desc": ["Ladders, siege towers and the ram against the walls,", "street fighting through the burning city, then the", "keep courtyard and Lord Aldric."],
		"state": "play"},
	{"id": "snow_plains", "name": "II. The Snow Plains", "pos": Vector2(222, 102), "label_off": Vector2(0, -13), "ring": Vector2(10, 10),
		"sub": "March against Crown, in the depth of winter",
		"desc": ["A field battle on frozen ground. Rise from a nameless", "foot soldier to general and take the head", "of the Crown's general, Aldric."],
		"state": "play"},
	{"id": "bellacourt", "name": "III. Bellacourt", "pos": Vector2(292, 216), "label_off": Vector2(-6, 16), "ring": Vector2(10, 10),
		"sub": "A mounted commander takes the walled burgh",
		"desc": ["Command eight companies through winding streets.", "Set formations, protect your bows, and take three wards."],
		"state": "play"},
]
const ECHOES := [
	{"id": "montgisard", "name": "Montgisard, 1177", "sub": "Echoes of other wars",
		"desc": ["A small army of knights charges a far", "larger one in a sandstorm."], "state": "sealed"},
	{"id": "sea_beast", "name": "The Sea Beast and the Dragon", "sub": "Echoes of other wars",
		"desc": ["A fleet caught between a sea monster", "and a dragon."], "state": "sealed"},
	{"id": "chariots", "name": "The Chariots of Assyria", "sub": "Echoes of other wars",
		"desc": ["Scythed war chariots and massed archers", "on the open plain."], "state": "sealed"},
]
## [name, position, size 1-3, label offset]; Veyre is drawn on its own.
const CITIES := [
	["Westhaven", Vector2(110, 205), 3, Vector2(0, 13)], ["Ash Pass", Vector2(190, 214), 1, Vector2(0, 12)],
	["Frosthold", Vector2(196, 66), 2, Vector2(0, 12)], ["Greyhaven", Vector2(352, 240), 3, Vector2(18, 10)],
	["Mirewatch", Vector2(270, 256), 2, Vector2(0, 12)], ["Eastmere", Vector2(470, 172), 3, Vector2(0, 13)],
	["Highgate", Vector2(396, 60), 2, Vector2(12, 3)], ["Hollow", Vector2(298, 326), 2, Vector2(16, 3)],
	["Southmere", Vector2(424, 300), 1, Vector2(0, 11)], ["Thornford", Vector2(214, 184), 1, Vector2(-14, 3)],
	["Rookhaven", Vector2(396, 206), 1, Vector2(0, 11)],
]
const REGIONS := [["MARCH", Vector2(86, 150)], ["CROWN", Vector2(330, 84)], ["GREYLAND", Vector2(390, 252)],
	["MIRE", Vector2(250, 290)], ["HOLLOW", Vector2(350, 318)], ["EASTERN REACH", Vector2(512, 196)], ["NORTH", Vector2(430, 34)]]

var t := 0.0
var sel := 0
var hover := -1
var content: Control
var land: ColorRect
var static_layer: Control
var dyn_layer: Control
var overlay: Control
var rivers: Array = []       # [points, width]
var coast := PackedVector2Array()
var sea_lines: Array = []
var peaks: Array = []        # [base centre, width, height, snowy]
var roads: Array = []
var houses: Array = []       # [pos, roof colour, size]
var wall := PackedVector2Array()
var route_qin := PackedVector2Array()
var route_next := PackedVector2Array()
var route_zhao := PackedVector2Array()
var city_roofs: Array = []   # [rect, colour] tiny roofs inside Veyre
var fires: Array = []        # burning spots in Veyre
var camps: Array = []        # Qin tents around Veyre
var flash := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Game.VIEW
	var paper := ColorRect.new()
	paper.size = Game.VIEW
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/map_paper.gdshader")
	mat.set_shader_parameter("size", Game.VIEW)
	paper.material = mat
	add_child(paper)
	content = Control.new()
	content.position = FRAME.position
	content.size = FRAME.size
	content.clip_contents = true
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	land = ColorRect.new()
	land.size = FRAME.size
	land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm := ShaderMaterial.new()
	lm.shader = load("res://shaders/map_land.gdshader")
	lm.set_shader_parameter("size", FRAME.size)
	lm.set_shader_parameter("origin", FRAME.position)
	land.material = lm
	content.add_child(land)
	static_layer = Control.new()
	static_layer.size = FRAME.size
	static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_layer.draw.connect(_draw_static)
	content.add_child(static_layer)
	dyn_layer = Control.new()
	dyn_layer.size = FRAME.size
	dyn_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dyn_layer.draw.connect(_draw_dynamic)
	content.add_child(dyn_layer)
	overlay = Control.new()
	overlay.size = Game.VIEW
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_build_geography()
	if Game.campaign.get("handan", false):
		sel = 1
	Sfx.boss_mode = false

# ------------------------------------------------------------------ geography
## Resamples a smooth path and pushes it sideways with a few sines, like a meandering river.
static func meander(ctrl: PackedVector2Array, amp: float, seed: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var c := Painter.curve(ctrl, 8)
	var out := PackedVector2Array()
	var s := 0.0
	for i in c.size():
		if i > 0:
			s += c[i].distance_to(c[i - 1])
		var d := (c[mini(i + 1, c.size() - 1)] - c[maxi(i - 1, 0)]).normalized()
		var k: float = sin(s * 0.16 + ph[0]) * 0.45 + sin(s * 0.41 + ph[1]) * 0.3 + sin(s * 0.95 + ph[2]) * 0.17 + sin(s * 2.2 + ph[0] * 2.0) * 0.12
		var fade := clampf(minf(i, c.size() - 1 - i) / 6.0, 0.0, 1.0)
		out.append(c[i] + d.orthogonal() * k * amp * fade)
	return out

func _build_geography() -> void:
	var specs := [
		[[Vector2(28, 160), Vector2(55, 110), Vector2(80, 60), Vector2(110, 34), Vector2(160, 26), Vector2(205, 34), Vector2(216, 70),
			Vector2(214, 120), Vector2(206, 170), Vector2(212, 198), Vector2(240, 207), Vector2(290, 214), Vector2(338, 206),
			Vector2(380, 184), Vector2(410, 146), Vector2(432, 112), Vector2(451, 97)], 3.4, 1.4],
		[[Vector2(20, 214), Vector2(70, 210), Vector2(110, 206), Vector2(160, 208), Vector2(207, 199)], 2.2, 0.8],
		[[Vector2(250, 40), Vector2(240, 80), Vector2(228, 124), Vector2(216, 160), Vector2(209, 188)], 2.0, 0.75],
		[[Vector2(300, 104), Vector2(330, 116), Vector2(362, 122), Vector2(398, 114), Vector2(430, 104)], 2.0, 0.75],
		[[Vector2(250, 292), Vector2(300, 298), Vector2(350, 290), Vector2(400, 296), Vector2(450, 285), Vector2(496, 268)], 2.4, 0.85],
		[[Vector2(50, 262), Vector2(120, 268), Vector2(180, 276), Vector2(240, 300), Vector2(292, 322)], 2.2, 0.8],
	]
	for i in specs.size():
		rivers.append([meander(PackedVector2Array(specs[i][0]), specs[i][1], 11 + i * 7), specs[i][2]])
	var cp := PackedVector2Array([Vector2(470, -40), Vector2(468, 20), Vector2(458, 62), Vector2(449, 94), Vector2(456, 114),
		Vector2(474, 128), Vector2(504, 140), Vector2(538, 150), Vector2(566, 160), Vector2(556, 178), Vector2(524, 190),
		Vector2(502, 206), Vector2(494, 228), Vector2(507, 256), Vector2(532, 286), Vector2(560, 320), Vector2(590, 400)])
	coast = meander(cp, 1.6, 5)
	var sea := coast.duplicate()
	sea.append(Vector2(760, 400))
	sea.append(Vector2(760, -40))
	sea_lines.append(sea)
	for k in range(1, 7):
		for poly in Geometry2D.offset_polygon(sea, -k * 3.2):
			sea_lines.append(poly)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# mountain chains: the Taihang between the snow plains and Veyre, the Qinling in the west
	for chain in [[[Vector2(288, 44), Vector2(280, 84), Vector2(270, 124), Vector2(258, 166), Vector2(246, 196)], 1.0],
			[[Vector2(40, 236), Vector2(96, 242), Vector2(150, 240), Vector2(196, 232)], 1.0],
			[[Vector2(130, 92), Vector2(160, 140)], 0.8], [[Vector2(484, 150), Vector2(520, 158)], 0.7],
			[[Vector2(246, 316), Vector2(226, 338)], 0.7], [[Vector2(52, 112), Vector2(56, 176)], 0.9],
			[[Vector2(330, 36), Vector2(372, 28)], 0.8]]:
		var path := Painter.curve(PackedVector2Array(chain[0]), 10)
		var sc: float = chain[1]
		var dist := 0.0
		for i in range(1, path.size()):
			dist += path[i].distance_to(path[i - 1])
			if dist > 8.0:
				dist = 0.0
				for k in 2:
					var pc := path[i] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-3, 5) + k * 4.0)
					var w := rng.randf_range(14.0, 24.0) * sc * (1.0 if k == 0 else 0.62)
					peaks.append([pc, w, w * rng.randf_range(0.6, 0.95), pc.y < 150.0 or rng.randf() < 0.3])
	peaks.sort_custom(func(a, b): return a[0].y < b[0].y)
	wall = meander(PackedVector2Array([Vector2(296, 52), Vector2(330, 48), Vector2(376, 40), Vector2(420, 44)]), 1.0, 3)
	var cpos: Array = []
	for c in CITIES:
		cpos.append(c[1])
	var hd := VEYRE.get_center()
	for r in [[cpos[0], cpos[1], Vector2(240, 204), hd], [hd, cpos[3]], [hd, cpos[6]], [hd, cpos[5]], [cpos[3], cpos[4]], [cpos[1], cpos[9], cpos[2]],
			[cpos[3], cpos[8]], [cpos[4], cpos[7]], [hd, Vector2(250, 118), cpos[2]]]:
		roads.append(meander(PackedVector2Array(r), 0.9, 40 + int(r[0].x)))
	# villages and hamlets: little clusters of houses
	for c in CITIES:
		_village(c[1], 3 + int(c[2]) * 4, 3.0 + int(c[2]) * 2.2, rng)
	for i in 34:
		var rd: PackedVector2Array = roads[rng.randi() % roads.size()]
		var p := rd[rng.randi() % rd.size()] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5))
		if not _in_sea(p) and not VEYRE.grow(16.0).has_point(p):
			_village(p, rng.randi_range(2, 5), 3.0, rng)
	houses.sort_custom(func(a, b): return a[0].y < b[0].y)
	# Veyre: blocks of roofs between the streets, the palace in the east quarter
	var rcol := [Color("#4b5684"), Color("#3f6270"), Color("#6a5068"), Color("#55607e")]
	var y := VEYRE.position.y + 4.0
	while y < VEYRE.end.y - 4.0:
		var x := VEYRE.position.x + 4.0
		while x < VEYRE.end.x - 4.0:
			var r := Rect2(x, y, rng.randf_range(2.6, 4.2), rng.randf_range(2.0, 2.8))
			var in_palace := PALACE.grow(1.0).intersects(r)
			var on_street := absf(r.get_center().y - AVE_Y) < 2.6 or fmod(r.get_center().x - VEYRE.position.x, 14.0) < 1.6
			if not in_palace and not on_street:
				city_roofs.append([r, rcol[rng.randi() % rcol.size()]])
			x += r.size.x + 0.9
		y += 3.6
	for i in 9:
		fires.append(Vector2(rng.randf_range(VEYRE.position.x + 4.0, VEYRE.end.x - 10.0), rng.randf_range(VEYRE.position.y + 4.0, VEYRE.end.y - 4.0)))
	for i in 26:
		var a := rng.randf_range(PI * 0.55, PI * 1.45)
		var cpt := hd + Vector2(cos(a) * rng.randf_range(45.0, 56.0), sin(a) * rng.randf_range(33.0, 42.0))
		camps.append(cpt)
	route_qin = Painter.curve(PackedVector2Array([Vector2(112, 202), Vector2(150, 208), Vector2(190, 212), Vector2(236, 210),
		Vector2(270, 198), Vector2(292, 182), Vector2(304, 166)]), 8)
	route_next = Painter.curve(PackedVector2Array([Vector2(312, 136), Vector2(296, 120), Vector2(264, 110), Vector2(236, 104)]), 8)
	route_zhao = Painter.curve(PackedVector2Array([Vector2(392, 68), Vector2(380, 92), Vector2(364, 112), Vector2(352, 126)]), 8)

func _village(c: Vector2, n: int, spread: float, rng: RandomNumberGenerator) -> void:
	var roofs := [Color("#9a3a2c"), Color("#7a3a3a"), Color("#4c5a7c"), Color("#5e4a64"), Color("#a25a32")]
	for i in n:
		var p := c + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread * 0.7, spread * 0.7))
		if _in_sea(p):
			continue
		houses.append([p, roofs[rng.randi() % roofs.size()], rng.randf_range(2.2, 3.4)])

func _in_sea(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, sea_lines[0])

# ------------------------------------------------------------------ input / update
func _all_nodes() -> Array:
	return NODES + ECHOES

func _node_rect(i: int) -> Rect2:
	if i < NODES.size():
		var ring: Vector2 = NODES[i]["ring"]
		return Rect2(NODES[i]["pos"] - ring, ring * 2.0)
	return Rect2(Vector2(498, 244 + (i - NODES.size()) * 16), Vector2(118, 14))

func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 2.0)
	(land.material as ShaderMaterial).set_shader_parameter("time", t)
	var m := get_local_mouse_position()
	hover = -1
	for i in _all_nodes().size():
		if _node_rect(i).has_point(m - (FRAME.position if i < NODES.size() else Vector2.ZERO)):
			hover = i
	var n := _all_nodes().size()
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_down"):
		sel = (sel + 1) % n
		Sfx.play("drum", -12.0, 1.6)
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_up"):
		sel = (sel - 1 + n) % n
		Sfx.play("drum", -12.0, 1.6)
	if Input.is_action_just_pressed("pause"):
		back.emit()
	if Input.is_action_just_pressed("confirm"):
		_choose(sel)
	if OS.get_cmdline_user_args().has("--autostart") and t > 1.0 and not has_meta("started"):
		set_meta("started", true)
		_choose(0)
	dyn_layer.queue_redraw()
	overlay.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and hover >= 0 and hover != sel:
		sel = hover
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hover >= 0:
		sel = hover
		_choose(hover)

func _choose(i: int) -> void:
	var nd: Dictionary = _all_nodes()[i]
	if nd["state"] == "play":
		Sfx.play("horn_short", -2.0)
		march.emit(nd["id"])
	else:
		flash = 1.0
		Sfx.play("drum", -6.0, 0.7)

# ------------------------------------------------------------------ drawing helpers
func _label(ci: CanvasItem, pos: Vector2, s: String, sz: int, col: Color, align: int = 1, kind: int = 3) -> void:
	Game.text(ci, pos, s, sz, col, align, kind, true, HALO)

func _dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float, upto: float = 1.0) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var limit := total * upto
	var s := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var l := a.distance_to(b)
		var u := 0.0
		while u < l:
			var gs := s + u
			if gs > limit:
				return
			var ph := fmod(gs, dash + gap)
			var step := minf(l - u, (dash - ph) if ph < dash else (dash + gap - ph))
			if ph < dash:
				ci.draw_line(a.lerp(b, u / l), a.lerp(b, (u + step) / l), col, w, true)
			u += maxf(step, 0.01)
		s += l

func _arrow_head(ci: CanvasItem, tip: Vector2, dir: Vector2, col: Color, sz: float = 4.0) -> void:
	var d := dir.normalized()
	var n := d.orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * sz + n * sz * 0.5, tip - d * sz * 0.7, tip - d * sz - n * sz * 0.5]), col)

func _bar(ci: CanvasItem, c: Vector2, ang: float, col: Color, w: float = 9.0, h: float = 2.6) -> void:
	var pts := PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
	var xf := Transform2D(ang, c)
	var p := xf * pts
	ci.draw_colored_polygon(p, col)
	p.append(p[0])
	ci.draw_polyline(p, col.darkened(0.45), 0.5, true)

func _swords(ci: CanvasItem, c: Vector2, col: Color, s: float = 1.0) -> void:
	for sg in [-1.0, 1.0]:
		var a := c + Vector2(-4.5 * sg, -4.5) * s
		var b := c + Vector2(4.5 * sg, 4.5) * s
		ci.draw_line(a, b, col, 1.1 * s, true)
		var hd := (b - a).normalized()
		var hn := hd.orthogonal()
		ci.draw_line(b - hd * 2.0 * s + hn * 1.8 * s, b - hd * 2.0 * s - hn * 1.8 * s, col, 1.0 * s, true)

func _river_line(ci: CanvasItem, pts: PackedVector2Array, w: float) -> void:
	ci.draw_polyline(pts, RIVER_DK, w + 1.2, true)
	ci.draw_polyline(pts, RIVER, w, true)
	var hi := PackedVector2Array()
	for i in pts.size():
		var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		hi.append(pts[i] - d.orthogonal() * w * 0.22)
	ci.draw_polyline(hi, RIVER_LT, maxf(0.4, w * 0.3), true)

## A painted mountain: lit west face, violet east face, snow on the peak, ridge strokes.
func _peak(ci: CanvasItem, c: Vector2, w: float, h: float, snowy: bool) -> void:
	var sk := fmod(c.x * 0.37 + c.y * 0.13, 1.0) - 0.5
	var top := c + Vector2(w * (0.04 + sk * 0.2), -h)
	var l := c + Vector2(-w * 0.5, 0)
	var r := c + Vector2(w * 0.5, 0)
	var mid := c + Vector2(w * (0.1 + sk * 0.1), 0)
	var sl := top.lerp(l, 0.45) + Vector2(-w * 0.05, -h * 0.06)       # shoulders break the outline
	var sr := top.lerp(r, 0.4) + Vector2(w * 0.06, -h * 0.1)
	# foothills: a soft violet-olive skirt
	ci.draw_colored_polygon(Painter.ellipse(c + Vector2(w * 0.1, 0.5), w * 0.62, h * 0.18, 18), Color(0.3, 0.3, 0.32, 0.35))
	ci.draw_colored_polygon(PackedVector2Array([l, sl, top, mid]), Color("#d2b796"))
	ci.draw_colored_polygon(PackedVector2Array([l + Vector2(w * 0.12, 0), sl.lerp(top, 0.3) + Vector2(1, 2), mid]), Color("#b89a80"))
	ci.draw_colored_polygon(PackedVector2Array([mid, top, sr, r]), Color("#5a4e7e"))
	ci.draw_colored_polygon(PackedVector2Array([mid + Vector2(w * 0.08, 0), sr.lerp(top, 0.4) + Vector2(1, 3), r]), Color("#4a3f6e"))
	for k in 2:
		var a := top.lerp(sr, 0.35 + k * 0.4)
		ci.draw_line(a, a + Vector2(-w * 0.07, h * 0.3), Color("#3c3260"), 0.45, true)
	if snowy:
		var s := 0.36
		ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(sl, s * 1.4), top.lerp(sl, s) + Vector2(w * 0.07, 1.2), top.lerp(mid, s * 0.6)]), Color("#f6f4fb"))
		ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(mid, s * 0.6), top.lerp(sr, s * 1.3)]), Color("#aeacd6"))
	ci.draw_polyline(PackedVector2Array([l, sl, top, sr, r]), Color(0.16, 0.12, 0.24, 0.5), 0.5, true)

func _house(ci: CanvasItem, p: Vector2, roof: Color, s: float) -> void:
	ci.draw_rect(Rect2(p + Vector2(0.6, 0.4), Vector2(s, s * 0.7)), Color(0.1, 0.06, 0.16, 0.3))
	ci.draw_rect(Rect2(p + Vector2(0, s * 0.18), Vector2(s, s * 0.5)), Color("#efe2c8"))
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.4, s * 0.2), p + Vector2(s * 0.2, -s * 0.25), p + Vector2(s * 0.8, -s * 0.25), p + Vector2(s + 0.4, s * 0.2)]), roof)
	ci.draw_line(p + Vector2(s * 0.2, -s * 0.25), p + Vector2(s * 0.8, -s * 0.25), roof.lightened(0.3), 0.4)

# ------------------------------------------------------------------ the map body
func _draw_static() -> void:
	var ci := static_layer
	ci.draw_set_transform(-FRAME.position)
	# the sea: deep blue, lighter shallows, foam along the shore and painted wave strokes
	ci.draw_colored_polygon(sea_lines[0], SEA)
	for i in range(sea_lines.size() - 1, 0, -1):
		var k := float(i) / sea_lines.size()
		ci.draw_colored_polygon(sea_lines[i], SEA.lerp(SEA_LT, 0.0) if i > 1 else SEA)
	var shallow := Geometry2D.offset_polygon(sea_lines[0], -7.0)
	for sp in shallow:
		var band := Geometry2D.clip_polygons(sea_lines[0], sp)
		for bp in band:
			if not Geometry2D.triangulate_polygon(bp).is_empty():
				ci.draw_colored_polygon(bp, SEA_LT)
	var foam := coast.duplicate()
	ci.draw_polyline(foam, FOAM, 1.4, true)
	for i in range(2, 5):
		var poly: PackedVector2Array = sea_lines[i].duplicate()
		ci.draw_polyline(poly, Color(0.78, 0.9, 0.95, 0.28 - i * 0.04), 0.5, true)
	var wrng := RandomNumberGenerator.new()
	wrng.seed = 9
	for i in 70:
		var wp := Vector2(wrng.randf_range(450, 640), wrng.randf_range(0, 360))
		if Geometry2D.is_point_in_polygon(wp, sea_lines[0]) and not Geometry2D.is_point_in_polygon(wp + Vector2(-12, 0), PackedVector2Array()):
			var wv := PackedVector2Array([wp, wp + Vector2(2.5, -1.2), wp + Vector2(5, 0)])
			ci.draw_polyline(wv, Color(0.8, 0.9, 0.96, 0.45), 0.5, true)
	# lakes
	for lk in [[Vector2(334, 318), 13.0, 5.0], [Vector2(400, 214), 8.0, 4.0]]:
		var e := Painter.ellipse(lk[0], lk[1], lk[2], 24)
		ci.draw_colored_polygon(e, RIVER_DK)
		ci.draw_colored_polygon(Painter.ellipse(lk[0], lk[1] - 1.2, lk[2] - 1.0, 24), RIVER)
		ci.draw_colored_polygon(Painter.ellipse(lk[0] + Vector2(-2, -1), lk[1] * 0.4, lk[2] * 0.3, 16), RIVER_LT)
	# roads: pale dusty tracks
	for rd in roads:
		ci.draw_polyline(rd, Color(0.36, 0.26, 0.2, 0.35), 1.6, true)
		ci.draw_polyline(rd, ROAD, 0.9, true)
	# rivers
	for r in rivers:
		_river_line(ci, r[0], r[1])
	# the wall of Zhao
	ci.draw_polyline(wall, Color(0.2, 0.16, 0.26, 0.6), 2.4, true)
	ci.draw_polyline(wall, STONE, 1.4, true)
	for i in range(0, wall.size() - 1, 3):
		var d := (wall[i + 1] - wall[i]).normalized()
		ci.draw_rect(Rect2(wall[i] - d.orthogonal() * 1.4 - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), STONE_DK)
	# villages
	for h in houses:
		_house(ci, h[0], h[1], h[2])
	# Veyre
	_draw_handan(ci)
	# mountains (back to front)
	for pk in peaks:
		_peak(ci, pk[0], pk[1], pk[2], pk[3])
	# region names in widely spaced capitals
	for rg in REGIONS:
		var s := " ".join(Array(str(rg[0]).split("")))
		Game.text(ci, rg[1], s, 11, REGION, 1, 1, false)
	_label(ci, Vector2(150, 74), "Ordos", 6, SOFT)
	_label(ci, Vector2(244, 150), "Taihang Shan", 5, SOFT)
	_label(ci, Vector2(122, 230), "Qinling", 5, SOFT)
	_label(ci, Vector2(356, 38), "Wall of Zhao", 5, SOFT)
	_label(ci, Vector2(428, 150), "Huang He", 6, RIVER_DK)
	_label(ci, Vector2(70, 222), "Wei", 5, RIVER_DK)
	_label(ci, Vector2(380, 288), "Huai", 5, RIVER_DK)
	_label(ci, Vector2(590, 120), "Eastern Sea", 7, Color(0.86, 0.94, 0.98, 0.85))
	for c in CITIES:
		_label(ci, c[1] + c[3], c[0], 6 if int(c[2]) >= 2 else 5, INK, 1, 3)
	Game.text(ci, Vector2(VEYRE.get_center().x, VEYRE.position.y - 8.0), "VEYRE", 8, Color("#5a1814"), 1, 1, true, HALO)
	ci.draw_set_transform(Vector2.ZERO)

## The walled capital of Zhao: moat, walls with corner towers and gates, roofs between the
## streets, and the palace with its golden hall.
func _draw_handan(ci: CanvasItem) -> void:
	var r := VEYRE
	ci.draw_rect(r.grow(5.0), Color(0.1, 0.06, 0.18, 0.25))
	ci.draw_rect(r.grow(3.4), RIVER_DK)
	ci.draw_rect(r.grow(2.6), RIVER)
	ci.draw_rect(r.grow(1.2), Color("#8a7e8e"))
	ci.draw_rect(r, Color("#a39aa6"))
	# streets
	ci.draw_rect(Rect2(r.position.x, AVE_Y - 1.4, r.size.x, 2.8), Color("#d8c8b0"))
	var x := r.position.x + 14.0
	while x < r.end.x - 2.0:
		ci.draw_rect(Rect2(x - 0.6, r.position.y, 1.2, r.size.y), Color("#cbbca6"))
		x += 14.0
	for rr in city_roofs:
		var rc: Rect2 = rr[0]
		ci.draw_rect(Rect2(rc.position + Vector2(0.4, 0.4), rc.size), Color(0.06, 0.04, 0.1, 0.4))
		ci.draw_rect(rc, rr[1])
		ci.draw_line(Vector2(rc.position.x, rc.get_center().y), Vector2(rc.end.x, rc.get_center().y), Color(rr[1]).lightened(0.25), 0.35)
	# palace: red walls, golden double roof
	var pr := PALACE
	ci.draw_rect(pr.grow(0.8), Color("#7e2420"))
	ci.draw_rect(pr, Color("#c9bfc6"))
	ci.draw_rect(Rect2(pr.position + Vector2(3, 3), Vector2(10, 7)), Color("#6c4718"))
	ci.draw_rect(Rect2(pr.position + Vector2(3.6, 3.4), Vector2(8.8, 5.6)), Color("#d9a845"))
	ci.draw_line(pr.position + Vector2(4, 6.2), pr.position + Vector2(12, 6.2), Color("#f6d886"), 0.6)
	# walls, crenellations, corner towers, gates
	ci.draw_rect(r, Color("#3c3448"), false, 2.0)
	ci.draw_rect(r, STONE, false, 1.2)
	for k in int(r.size.x / 2.4):
		ci.draw_rect(Rect2(r.position.x + k * 2.4, r.position.y - 1.4, 1.1, 0.9), STONE_DK)
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		ci.draw_rect(Rect2(c - Vector2(2.6, 2.6), Vector2(5.2, 5.2)), Color("#3c3448"))
		ci.draw_rect(Rect2(c - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), STONE)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-2.6, -0.6), c + Vector2(0, -3.6), c + Vector2(2.6, -0.6)]), Color("#4b5684"))
	for g in [Vector2(r.position.x, AVE_Y), Vector2(r.end.x, AVE_Y), Vector2(r.get_center().x, r.end.y), Vector2(r.get_center().x, r.position.y)]:
		ci.draw_rect(Rect2(g - Vector2(3.2, 2.4), Vector2(6.4, 4.8)), Color("#3c3448"))
		ci.draw_rect(Rect2(g - Vector2(2.6, 1.8), Vector2(5.2, 3.6)), Color("#8a7e8e"))
		ci.draw_colored_polygon(PackedVector2Array([g + Vector2(-3.4, -1.0), g + Vector2(-1.6, -3.6), g + Vector2(1.6, -3.6), g + Vector2(3.4, -1.0)]), Color("#3f6270"))
	# the Qin siege lines: a palisade around the west and south, and the camps
	var hd := r.get_center()
	var arc := PackedVector2Array()
	for i in 25:
		var a := lerpf(PI * 0.45, PI * 1.55, i / 24.0)
		arc.append(hd + Vector2(cos(a) * 42.0, sin(a) * 31.0))
	_dashed(ci, arc, Color("#5a3a24"), 0.8, 1.6, 0.8)
	for cp in camps:
		ci.draw_colored_polygon(PackedVector2Array([cp + Vector2(-1.8, 1.0), cp + Vector2(0, -1.6), cp + Vector2(1.8, 1.0)]), Color("#d8cdb8"))
		ci.draw_line(cp + Vector2(0, -1.6), cp + Vector2(0.9, 1.0), QIN.darkened(0.2), 0.5)

func _draw_dynamic() -> void:
	var ci := dyn_layer
	ci.draw_set_transform(-FRAME.position)
	# Veyre burns: flickering fires and smoke drifting north-east
	var won: bool = Game.campaign.get("handan", false)
	for i in fires.size():
		var f: Vector2 = fires[i]
		var fl := 0.75 + 0.25 * sin(t * 7.0 + i * 1.7) * sin(t * 11.0 + i)
		ci.draw_circle(f, 3.2 * fl, Color(1.0, 0.45, 0.12, 0.35))
		ci.draw_circle(f, 1.6 * fl, Color(1.0, 0.7, 0.3, 0.9))
		ci.draw_circle(f, 0.7, Color(1.0, 0.95, 0.7))
		for k in 5:
			var ph := fmod(t * 0.12 + k * 0.2 + i * 0.13, 1.0)
			var sp := f + Vector2(ph * 22.0 + sin(t + k) * 1.5, -ph * 26.0)
			ci.draw_circle(sp, 1.4 + ph * 4.5, Color(0.3, 0.24, 0.32, 0.32 * (1.0 - ph)))
	# camp fires around the siege lines
	for i in camps.size():
		if i % 3 == 0:
			var cp: Vector2 = camps[i] + Vector2(2.4, 0.4)
			ci.draw_circle(cp, 0.9 + 0.3 * sin(t * 9.0 + i), Color(1.0, 0.62, 0.25))
	# march routes (drawn in over the first seconds)
	var k := clampf((t - 0.3) / 2.2, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	_dashed(ci, route_qin, QIN, 1.2, 3.5, 2.0, k)
	if k >= 1.0:
		_arrow_head(ci, route_qin[route_qin.size() - 1], route_qin[route_qin.size() - 1] - route_qin[route_qin.size() - 3], QIN, 5.0)
		var k2 := clampf((t - 2.6) / 1.6, 0.0, 1.0)
		_dashed(ci, route_next, Color(QIN.r, QIN.g, QIN.b, 0.9 if won else 0.45), 0.9, 2.0, 2.2, k2)
		_dashed(ci, route_zhao, Color(ZHAO.r, ZHAO.g, ZHAO.b, 0.9), 1.0, 3.0, 2.0, k2)
		if k2 >= 1.0:
			_arrow_head(ci, route_zhao[route_zhao.size() - 1], route_zhao[route_zhao.size() - 1] - route_zhao[route_zhao.size() - 3], ZHAO, 4.0)
			if won:
				_arrow_head(ci, route_next[route_next.size() - 1], route_next[route_next.size() - 1] - route_next[route_next.size() - 3], QIN, 4.0)
	# army formations
	var pop := clampf((t - 0.8) / 0.6, 0.0, 1.0)
	if pop > 0.0:
		var lift := Vector2(0, (1.0 - pop) * -6.0)
		for i in 4:
			_bar(ci, Vector2(290, 136 + i * 6) + lift, PI * 0.5, QIN, 8.0)
		for i in 3:
			_bar(ci, Vector2(326 + i * 10, 184) + lift, 0.0, QIN, 8.0)
		_label(ci, Vector2(276, 160) + lift, "March host", 5, QIN.darkened(0.25), 1)
		_bar(ci, Vector2(382, 98) + lift, 0.5, ZHAO, 9.0)
		_bar(ci, Vector2(388, 92) + lift, 0.5, ZHAO, 9.0)
		_label(ci, Vector2(404, 104) + lift, "Crown relief", 5, ZHAO.darkened(0.25), 0)
		var sp: Vector2 = NODES[1]["pos"]
		for i in 3:
			_bar(ci, sp + Vector2(12, -4 + i * 4) + lift, 1.2, ZHAO)
		var rp: Vector2 = NODES[2]["pos"]
		for i in 3:
			var bp := rp + Vector2(-10 + i * 6, -5 + (i % 2) * 2)
			var hull := PackedVector2Array([bp + Vector2(-2.6, 0), bp + Vector2(2.6, 0), bp + Vector2(1.6, 1.4), bp + Vector2(-1.8, 1.4)])
			ci.draw_colored_polygon(hull, QIN if i < 2 else ZHAO)
			ci.draw_line(bp, bp + Vector2(0, -2.6), INK, 0.4, true)
	# battle markers
	for i in NODES.size():
		var nd: Dictionary = NODES[i]
		var p: Vector2 = nd["pos"]
		var ring: Vector2 = nd["ring"]
		var playable: bool = nd["state"] == "play"
		var col := QIN.darkened(0.15) if playable else Color(INK.r, INK.g, INK.b, 0.75)
		if i == sel:
			var pr := 1.0 + sin(t * 4.0) * 0.06
			var e := Painter.ellipse(p, ring.x * pr, ring.y * pr, 48)
			e.append(e[0])
			ci.draw_polyline(e, Color(1.0, 0.86, 0.5, 0.9), 1.6, true)
			ci.draw_polyline(e, Color(QIN.r, QIN.g, QIN.b, 0.9), 0.8, true)
		if nd["id"] != "handan":
			ci.draw_circle(p, 6.0, Color(PAPER.r, PAPER.g, PAPER.b, 0.85))
			_swords(ci, p, col, 0.9)
		var lp: Vector2 = p + nd["label_off"]
		Game.text(ci, lp, nd["name"], 6, QIN.darkened(0.35) if playable else INK, 1, 0, true, HALO)
		if Game.campaign.get(nd["id"], false):
			Game.text(ci, lp + Vector2(0, -9), "victory", 5, QIN, 1, 3, true, HALO)
	ci.draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ frame, legend, cards
func _draw_overlay() -> void:
	var ci := overlay
	# frame: a dark lacquer border with a thin gold rule
	ci.draw_rect(OUTER, Color("#1c1626"), false, 1.0)
	var bw := FRAME.position.x - OUTER.position.x
	for r in [Rect2(OUTER.position, Vector2(OUTER.size.x, bw)), Rect2(Vector2(OUTER.position.x, FRAME.end.y), Vector2(OUTER.size.x, bw)),
			Rect2(OUTER.position, Vector2(bw, OUTER.size.y)), Rect2(Vector2(FRAME.end.x, OUTER.position.y), Vector2(bw, OUTER.size.y))]:
		ci.draw_rect(r, Color("#241c30"))
	ci.draw_rect(FRAME, Color("#c9a24a"), false, 0.8)
	ci.draw_rect(OUTER.grow(-1.5), Color(0.79, 0.64, 0.29, 0.5), false, 0.4)
	for c in [OUTER.position, Vector2(OUTER.end.x, OUTER.position.y), OUTER.end, Vector2(OUTER.position.x, OUTER.end.y)]:
		ci.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color("#b3202a"))
	# title cartouche
	var cr := Rect2(22, 22, 176, 44)
	_slip(ci, cr)
	Game.text(ci, Vector2(cr.get_center().x, cr.position.y + 19), "THE BORDER KINGDOMS", 7, INK, 1, 1, false)
	Game.text(ci, Vector2(cr.get_center().x, cr.position.y + 33), "Campaign map of the Qin army", 5, SOFT, 1, 3, false)
	# legend
	var lr := Rect2(500, 22, 118, 78)
	_slip(ci, lr)
	Game.text(ci, Vector2(lr.position.x + 8, lr.position.y + 12), "Legend", 6, INK, 0, 3, false)
	var ly := lr.position.y + 22.0
	_bar(ci, Vector2(lr.position.x + 14, ly), 0.0, QIN)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "The March", 5, QIN.darkened(0.3), 0, 3, false)
	ly += 10.0
	_bar(ci, Vector2(lr.position.x + 14, ly), 0.0, ZHAO)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "The Crown", 5, ZHAO.darkened(0.3), 0, 3, false)
	ly += 10.0
	_dashed(ci, PackedVector2Array([Vector2(lr.position.x + 8, ly), Vector2(lr.position.x + 20, ly)]), QIN, 1.0, 3.0, 1.6)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "March of Qin", 5, INK, 0, 3, false)
	ly += 10.0
	_swords(ci, Vector2(lr.position.x + 14, ly), INK, 0.6)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "Battle", 5, INK, 0, 3, false)
	ly += 10.0
	ci.draw_circle(Vector2(lr.position.x + 14, ly), 2.0, Color(1.0, 0.55, 0.2))
	ci.draw_circle(Vector2(lr.position.x + 14, ly), 0.9, Color(1.0, 0.92, 0.6))
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "City burning", 5, INK, 0, 3, false)
	# compass rose
	var cc := Vector2(600, 196)
	ci.draw_circle(cc, 13.0, Color(0.95, 0.92, 0.84, 0.75))
	ci.draw_arc(cc, 13.0, 0.0, TAU, 40, Color("#c9a24a"), 0.8, true)
	for k in 8:
		var a := k * PI * 0.25 - PI * 0.5
		var r := 11.0 if k % 2 == 0 else 6.0
		var tip := cc + Vector2.from_angle(a) * r
		var l := cc + Vector2.from_angle(a - 0.5) * 2.2
		var rr := cc + Vector2.from_angle(a + 0.5) * 2.2
		ci.draw_colored_polygon(PackedVector2Array([cc, l, tip]), QIN.darkened(0.2) if k == 0 else INK)
		ci.draw_colored_polygon(PackedVector2Array([cc, tip, rr]), Color(PAPER.r, PAPER.g, PAPER.b, 0.9))
		ci.draw_polyline(PackedVector2Array([l, tip, rr]), INK, 0.4, true)
	Game.text(ci, cc + Vector2(0, -15), "N", 6, Color(0.96, 0.92, 0.82), 1, 1, true, INK)
	# scale of li
	var sx := 352.0
	var sy := 330.0
	var sr := Rect2(sx - 6.0, sy - 9.0, 100.0, 24.0)
	_slip(ci, sr)
	for k in 4:
		var r := Rect2(sx + k * 22.0, sy, 22.0, 2.6)
		if k % 2 == 0:
			ci.draw_rect(r, INK)
		ci.draw_rect(r, INK, false, 0.5)
	Game.text(ci, Vector2(sx, sy - 2.0), "0", 4, INK, 1, 3, false)
	Game.text(ci, Vector2(sx + 88.0, sy - 2.0), "400", 4, INK, 1, 3, false)
	Game.text(ci, Vector2(sx + 44.0, sy + 11.0), "Scale of li", 5, INK, 1, 3, false)
	# echoes slip (battles from other wars), pinned over the sea
	var er := Rect2(494, 224, 126, 72)
	_slip(ci, er)
	Game.text(ci, Vector2(er.position.x + 8, er.position.y + 13), "Echoes of other wars", 6, INK, 0, 3, false)
	for j in ECHOES.size():
		var idx := NODES.size() + j
		var rr := _node_rect(idx)
		if idx == sel:
			ci.draw_rect(rr.grow(0.5), Color(QIN.r, QIN.g, QIN.b, 0.16))
			ci.draw_rect(rr.grow(0.5), Color(QIN.r, QIN.g, QIN.b, 0.7), false, 0.6)
		var nm: String = ECHOES[j]["name"]
		Game.text(ci, rr.position + Vector2(13, 9.5), nm, 5, INK, 0, 3, false)
		_wax(ci, rr.position + Vector2(6, 7), 3.6)
	_card(ci)
	Game.text(ci, Vector2(616, 340), "Arrows or mouse: choose.  Enter or click: march.  Esc: back", 5, Color(0.96, 0.92, 0.84), 2, 3, true, INK)

func _slip(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size), Color(0.08, 0.04, 0.12, 0.35))
	ci.draw_rect(r, Color(0.96, 0.93, 0.85))
	ci.draw_rect(r, INK, false, 0.8)
	ci.draw_rect(r.grow(-2.0), Color(0.79, 0.64, 0.29, 0.8), false, 0.5)

func _wax(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := k * TAU / 14.0
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + 0.12 * sin(a * 5.0 + c.x)))
	ci.draw_colored_polygon(pts, Color("#8e1d22"))
	ci.draw_circle(c, r * 0.55, Color("#b3302e"))

func _card(ci: CanvasItem) -> void:
	var nd: Dictionary = _all_nodes()[sel]
	var r := Rect2(22, 252, 214, 74)
	var shake := sin(t * 60.0) * flash * 2.0
	r.position.x += shake
	_slip(ci, r)
	ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), QIN if nd["state"] == "play" else Color(0.4, 0.36, 0.42))
	Game.text(ci, r.position + Vector2(10, 14), nd["name"], 7, INK, 0, 1, false)
	Game.text(ci, r.position + Vector2(10, 25), nd["sub"], 5, SOFT, 0, 3, false)
	var desc: Array = nd["desc"]
	for i in desc.size():
		Game.text(ci, r.position + Vector2(10, 36 + i * 8), desc[i], 5, INK, 0, 2, false)
	var status := ""
	var sc := INK
	match nd["state"]:
		"play":
			status = "ENTER: MARCH" if not Game.campaign.get(nd["id"], false) else "VICTORY.  ENTER: FIGHT AGAIN"
			sc = QIN.darkened(0.2)
		"soon":
			status = "IN PREPARATION"
		"sealed":
			status = "SEALED"
	Game.text(ci, Vector2(r.end.x - 8, r.end.y - 6), status, 6, sc, 2, 0, false)
