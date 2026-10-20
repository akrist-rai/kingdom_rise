class_name CampaignMap
extends Control
## The campaign war map, drawn like an old printed staff map (after the 1757 Weser campaign
## map): cream paper with fold creases, blue meandering rivers, hachured hills, italic place
## names, a water-lined coast, red (Qin) and blue (Zhao) army bars, dashed march routes, a
## legend, a scale of li and a graduated border. Battles are picked here.
## The geography is stylised Warring States China, not an accurate map.

signal march(battle_id: String)
signal back

const INK := Color("#221d28")
const SOFT := Color(0.13, 0.11, 0.16, 0.7)
const PAPER := Color(0.925, 0.9, 0.82)
const HALO := Color(0.93, 0.9, 0.82, 0.85)
const RIVER := Color("#3d74bb")
const RIVER_LT := Color(0.5, 0.66, 0.84, 0.9)
const SEA := Color(0.82, 0.87, 0.88, 0.55)
const QIN := Color("#c62a2f")
const ZHAO := Color("#2c4dae")
const REGION := Color(0.55, 0.2, 0.16, 0.45)
const OUTER := Rect2(8, 8, 624, 344)
const FRAME := Rect2(14, 14, 612, 332)

const NODES := [
	{"id": "snow_plains", "name": "I. The Snow Plains", "pos": Vector2(262, 118), "label_off": Vector2(-8, -12),
		"sub": "Qin against Zhao, in the depth of winter",
		"desc": ["A field battle on frozen ground. Start as a nameless", "foot soldier, rise through the ranks and take", "the head of the Zhao general, Heng Yao."],
		"state": "play"},
	{"id": "handan", "name": "II. Siege of Handan", "pos": Vector2(338, 152), "label_off": Vector2(8, 16),
		"sub": "Storm the palace city of Zhao",
		"desc": ["Ladders, rams and siege towers against the walls,", "then street fighting up to the palace gates."],
		"state": "soon"},
	{"id": "river", "name": "III. Battle on the Water", "pos": Vector2(300, 214), "label_off": Vector2(-10, 15),
		"sub": "War fleets on the Yellow River",
		"desc": ["Boarding actions between river fleets.", "Fight from deck to deck."],
		"state": "soon"},
]
const ECHOES := [
	{"id": "montgisard", "name": "Montgisard, 1177", "sub": "Echoes of other wars",
		"desc": ["A small army of knights charges a far", "larger one in a sandstorm."], "state": "sealed"},
	{"id": "sea_beast", "name": "The Sea Beast and the Dragon", "sub": "Echoes of other wars",
		"desc": ["A fleet caught between a sea monster", "and a dragon."], "state": "sealed"},
	{"id": "chariots", "name": "The Chariots of Assyria", "sub": "Echoes of other wars",
		"desc": ["Scythed war chariots and massed archers", "on the open plain."], "state": "sealed"},
]
const CITIES := [
	["Xianyang", Vector2(110, 205), 2, Vector2(0, 12)], ["Hangu Pass", Vector2(190, 212), 3, Vector2(0, 12)],
	["Handan", Vector2(338, 152), 4, Vector2(22, -7)], ["Jinyang", Vector2(232, 92), 1, Vector2(0, -6)],
	["Daliang", Vector2(340, 236), 2, Vector2(16, 10)], ["Xinzheng", Vector2(280, 252), 2, Vector2(0, 12)],
	["Linzi", Vector2(482, 166), 2, Vector2(0, 12)], ["Ji", Vector2(396, 62), 2, Vector2(10, 3)],
	["Ying", Vector2(298, 328), 2, Vector2(14, 3)], ["Shouchun", Vector2(424, 300), 1, Vector2(0, 11)],
	["Anyi", Vector2(240, 178), 1, Vector2(-14, 3)], ["Zhongmou", Vector2(364, 180), 1, Vector2(0, -5)],
]
const REGIONS := [["QIN", Vector2(96, 150)], ["ZHAO", Vector2(330, 100)], ["WEI", Vector2(380, 238)],
	["HAN", Vector2(300, 280)], ["CHU", Vector2(350, 306)], ["QI", Vector2(518, 170)], ["YAN", Vector2(410, 36)]]

var t := 0.0
var sel := 0
var hover := -1
var content: Control
var overlay: Control
var rivers: Array = []       # [points, width]
var coast := PackedVector2Array()
var sea_lines: Array = []
var hills: Array = []        # [center, w, h]
var roads: Array = []
var trees: Array = []
var wall := PackedVector2Array()
var route_qin := PackedVector2Array()
var route_next := PackedVector2Array()
var route_zhao := PackedVector2Array()
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
	content.draw.connect(_draw_content)
	add_child(content)
	overlay = Control.new()
	overlay.size = Game.VIEW
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_build_geography()
	if Game.campaign.get("snow_plains", false):
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
			Vector2(214, 120), Vector2(210, 170), Vector2(212, 198), Vector2(240, 207), Vector2(290, 214), Vector2(338, 206),
			Vector2(372, 180), Vector2(405, 140), Vector2(430, 110), Vector2(451, 97)], 3.2, 1.3],
		[[Vector2(20, 214), Vector2(70, 210), Vector2(110, 206), Vector2(160, 207), Vector2(211, 199)], 2.2, 0.8],
		[[Vector2(255, 50), Vector2(246, 90), Vector2(236, 130), Vector2(222, 165), Vector2(213, 188)], 2.0, 0.75],
		[[Vector2(304, 116), Vector2(330, 128), Vector2(362, 136), Vector2(396, 126), Vector2(426, 110)], 2.0, 0.75],
		[[Vector2(250, 292), Vector2(300, 298), Vector2(350, 290), Vector2(400, 296), Vector2(450, 285), Vector2(496, 268)], 2.4, 0.85],
		[[Vector2(50, 262), Vector2(120, 268), Vector2(180, 276), Vector2(240, 300), Vector2(292, 322)], 2.2, 0.8],
	]
	for i in specs.size():
		rivers.append([meander(PackedVector2Array(specs[i][0]), specs[i][1], 11 + i * 7), specs[i][2]])
	# coastline (north to south), then the far side of the sea, off the map
	var cp := PackedVector2Array([Vector2(470, -40), Vector2(468, 20), Vector2(458, 62), Vector2(449, 94), Vector2(456, 114),
		Vector2(474, 128), Vector2(504, 140), Vector2(538, 150), Vector2(566, 160), Vector2(556, 178), Vector2(524, 190),
		Vector2(502, 206), Vector2(494, 228), Vector2(507, 256), Vector2(532, 286), Vector2(560, 320), Vector2(590, 400)])
	coast = meander(cp, 1.6, 5)
	var sea := coast.duplicate()
	sea.append(Vector2(760, 400))
	sea.append(Vector2(760, -40))
	sea_lines.append(sea)
	for k in range(1, 9):
		for poly in Geometry2D.offset_polygon(sea, -k * 2.7):
			sea_lines.append(poly)
	# hachured hill chains
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for chain in [[Vector2(302, 64), Vector2(297, 104), Vector2(292, 146), Vector2(287, 190)],
			[Vector2(46, 238), Vector2(100, 241), Vector2(150, 238), Vector2(196, 231)],
			[Vector2(150, 100), Vector2(170, 140)], [Vector2(486, 146), Vector2(520, 154)],
			[Vector2(250, 318), Vector2(230, 336)], [Vector2(60, 120), Vector2(60, 170)]]:
		var path := Painter.curve(PackedVector2Array(chain), 10)
		var dist := 0.0
		for i in range(1, path.size()):
			dist += path[i].distance_to(path[i - 1])
			if dist > 8.5:
				dist = 0.0
				hills.append([path[i] + Vector2(rng.randf_range(-3, 3), rng.randf_range(-2, 2)), rng.randf_range(8.0, 13.0), rng.randf_range(4.0, 6.5)])
				if rng.randf() < 0.5:
					hills.append([path[i] + Vector2(rng.randf_range(4, 8), rng.randf_range(4, 7)), rng.randf_range(6.0, 9.0), rng.randf_range(3.0, 4.5)])
	hills.sort_custom(func(a, b): return a[0].y < b[0].y)
	for c in [[Vector2(70, 285), 9], [Vector2(200, 318), 8], [Vector2(415, 88), 6], [Vector2(150, 300), 7]]:
		for i in int(c[1]):
			trees.append(c[0] + Vector2(rng.randf_range(-18, 18), rng.randf_range(-9, 9)))
	trees.sort_custom(func(a, b): return a.y < b.y)
	wall = meander(PackedVector2Array([Vector2(228, 70), Vector2(270, 63), Vector2(320, 60), Vector2(370, 50)]), 1.0, 3)
	for r in [[0, 1, 5, 4], [4, 6], [2, 5], [2, 7], [2, 3], [3, 10], [4, 11]]:
		var pts := PackedVector2Array()
		for ci in r:
			pts.append(CITIES[ci][1])
		roads.append(meander(pts, 0.8, 40 + r[0]))
	route_qin = Painter.curve(PackedVector2Array([Vector2(112, 202), Vector2(150, 206), Vector2(188, 208), Vector2(205, 188),
		Vector2(214, 158), Vector2(232, 136), Vector2(252, 124)]), 8)
	route_next = Painter.curve(PackedVector2Array([Vector2(270, 120), Vector2(300, 126), Vector2(326, 146), Vector2(330, 172),
		Vector2(312, 196), Vector2(302, 208)]), 8)
	route_zhao = Painter.curve(PackedVector2Array([Vector2(334, 146), Vector2(318, 128), Vector2(296, 118), Vector2(276, 116)]), 8)

# ------------------------------------------------------------------ input / update
func _all_nodes() -> Array:
	return NODES + ECHOES

func _node_rect(i: int) -> Rect2:
	if i < NODES.size():
		return Rect2(NODES[i]["pos"] - Vector2(10, 10), Vector2(20, 20))
	return Rect2(Vector2(498, 244 + (i - NODES.size()) * 16), Vector2(118, 14))

func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 2.0)
	var m := get_local_mouse_position()
	hover = -1
	for i in _all_nodes().size():
		if _node_rect(i).has_point(m):
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
	content.queue_redraw()
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

# ------------------------------------------------------------------ map body
func _draw_content() -> void:
	var ci := content
	ci.draw_set_transform(-FRAME.position)
	# sea: tint, then water lining parallel to the coast
	ci.draw_colored_polygon(sea_lines[0], SEA)
	for i in range(1, sea_lines.size()):
		var poly: PackedVector2Array = sea_lines[i].duplicate()
		poly.append(poly[0])
		ci.draw_polyline(poly, Color(0.25, 0.42, 0.6, 0.5 - i * 0.045), 0.45, true)
	ci.draw_polyline(coast, INK, 0.9, true)
	# lakes
	for lk in [[Vector2(334, 318), 13.0, 5.0], [Vector2(392, 206), 8.0, 4.0]]:
		var e := Painter.ellipse(lk[0], lk[1], lk[2], 24)
		ci.draw_colored_polygon(e, Color(0.62, 0.74, 0.86, 0.8))
		for k in 3:
			var y: float = lk[0].y - lk[2] * 0.5 + k * lk[2] * 0.5
			ci.draw_line(Vector2(lk[0].x - lk[1] * 0.6, y), Vector2(lk[0].x + lk[1] * 0.6, y), Color(0.25, 0.42, 0.62, 0.6), 0.4, true)
		e.append(e[0])
		ci.draw_polyline(e, RIVER, 0.7, true)
	# hills: arched outline with hachures on the shadow (east) side
	for h in hills:
		var c: Vector2 = h[0]
		var w: float = h[1]
		var hh: float = h[2]
		var arch := PackedVector2Array()
		for i in 11:
			var a := PI + PI * i / 10.0
			arch.append(c + Vector2(cos(a) * w * 0.5, sin(a) * hh))
		ci.draw_polyline(arch, SOFT, 0.7, true)
		for k in 5:
			var x := c.x + w * (0.02 + k * 0.1)
			var u := (x - c.x) / (w * 0.5)
			var top := c.y - sqrt(maxf(0.0, 1.0 - u * u)) * hh
			ci.draw_line(Vector2(x, top + 0.8), Vector2(x + 0.6, c.y - 0.2), Color(SOFT.r, SOFT.g, SOFT.b, 0.5), 0.45, true)
	# forests
	for tp in trees:
		ci.draw_line(tp, tp + Vector2(0, 2.4), SOFT, 0.5, true)
		var cr := Painter.circle(tp + Vector2(0, -0.6), 1.6, 10)
		ci.draw_colored_polygon(cr, Color(0.36, 0.42, 0.3, 0.35))
		cr.append(cr[0])
		ci.draw_polyline(cr, SOFT, 0.5, true)
	# the Zhao wall: a crenellated line
	ci.draw_polyline(wall, INK, 0.8, true)
	for i in range(0, wall.size() - 1, 3):
		var d := (wall[i + 1] - wall[i]).normalized()
		ci.draw_line(wall[i], wall[i] - d.orthogonal() * 1.6, INK, 0.7, true)
	# rivers: a bold blue line with a thin parallel line
	for r in rivers:
		var pts: PackedVector2Array = r[0]
		var w: float = r[1]
		ci.draw_polyline(pts, RIVER, w, true)
		var par := PackedVector2Array()
		for i in pts.size():
			var d := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
			par.append(pts[i] + d.orthogonal() * (w + 0.8))
		ci.draw_polyline(par, RIVER_LT, 0.45, true)
	# roads
	for rd in roads:
		ci.draw_polyline(rd, Color(INK.r, INK.g, INK.b, 0.75), 0.55, true)
	# region names in widely spaced capitals
	for rg in REGIONS:
		var s := " ".join(Array(str(rg[0]).split("")))
		Game.text(ci, rg[1], s, 11, REGION, 1, 1, false)
	# small italic labels
	_label(ci, Vector2(150, 74), "Ordos", 6, SOFT)
	_label(ci, Vector2(318, 196), "Taihang Shan", 5, SOFT)
	_label(ci, Vector2(122, 232), "Qinling", 5, SOFT)
	_label(ci, Vector2(300, 52), "Wall of Zhao", 5, SOFT)
	_label(ci, Vector2(262, 222), "Huang He", 6, RIVER)
	_label(ci, Vector2(70, 224), "Wei", 5, RIVER)
	_label(ci, Vector2(380, 288), "Huai", 5, RIVER)
	_label(ci, Vector2(590, 120), "Eastern Sea", 7, Color(0.2, 0.36, 0.55, 0.8))
	# cities
	for c in CITIES:
		var p: Vector2 = c[1]
		match int(c[2]):
			1:
				ci.draw_circle(p, 1.4, INK)
			2:
				ci.draw_arc(p, 2.6, 0.0, TAU, 20, INK, 0.7, true)
				ci.draw_rect(Rect2(p - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), INK)
			3:
				for sx in [-2.2, 2.2]:
					ci.draw_rect(Rect2(p + Vector2(sx - 1.0, -2.0), Vector2(2.0, 4.0)), INK)
				ci.draw_line(p + Vector2(-1.2, 0), p + Vector2(1.2, 0), INK, 0.6, true)
			4:
				# walled palace city
				var r := Rect2(p - Vector2(5, 4), Vector2(10, 8))
				ci.draw_rect(r, Color(0.75, 0.62, 0.48, 0.6))
				ci.draw_rect(r, INK, false, 0.9)
				for k in 5:
					ci.draw_rect(Rect2(r.position + Vector2(k * 2.2, -1.2), Vector2(1.1, 1.2)), INK)
				ci.draw_rect(Rect2(p - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), QIN.darkened(0.3))
		_label(ci, p + c[3], c[0], 6 if int(c[2]) >= 2 else 5, INK, 1, 3)
	# march routes (drawn in over the first seconds)
	var k := clampf((t - 0.3) / 2.2, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	_dashed(ci, route_qin, QIN, 1.0, 3.5, 2.0, k)
	if k >= 1.0:
		_arrow_head(ci, route_qin[route_qin.size() - 1], route_qin[route_qin.size() - 1] - route_qin[route_qin.size() - 3], QIN, 4.5)
		var won: bool = Game.campaign.get("snow_plains", false)
		var k2 := clampf((t - 2.6) / 1.6, 0.0, 1.0)
		_dashed(ci, route_next, Color(QIN.r, QIN.g, QIN.b, 0.85 if won else 0.4), 0.8, 2.0, 2.2, k2)
		_dashed(ci, route_zhao, Color(ZHAO.r, ZHAO.g, ZHAO.b, 0.85), 0.9, 3.0, 2.0, k2)
		if k2 >= 1.0:
			_arrow_head(ci, route_zhao[route_zhao.size() - 1], route_zhao[route_zhao.size() - 1] - route_zhao[route_zhao.size() - 3], ZHAO, 4.0)
	# army bars (formations, like a printed order-of-battle map)
	var pop := clampf((t - 0.8) / 0.6, 0.0, 1.0)
	if pop > 0.0:
		var sp: Vector2 = NODES[0]["pos"]
		for i in 3:
			_bar(ci, sp + Vector2(-12, -2 + i * 4) + Vector2(0, (1.0 - pop) * -6), 1.2, QIN)
			_bar(ci, sp + Vector2(12, -6 + i * 4) + Vector2(0, (1.0 - pop) * -6), 1.2, ZHAO)
		_label(ci, sp + Vector2(-24, 10), "Qin vanguard", 5, QIN.darkened(0.2), 1)
		_label(ci, sp + Vector2(26, 6), "Heng Yao", 5, ZHAO.darkened(0.2), 1)
		var hp: Vector2 = NODES[1]["pos"]
		_bar(ci, hp + Vector2(0, 8), 0.0, ZHAO, 12.0)
		_bar(ci, hp + Vector2(-9, 0), PI * 0.5, ZHAO, 10.0)
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
		var playable: bool = nd["state"] == "play"
		var col := QIN.darkened(0.15) if playable else Color(INK.r, INK.g, INK.b, 0.75)
		if i == sel:
			var pr := 9.0 + sin(t * 4.0) * 1.2
			ci.draw_arc(p, pr, 0.0, TAU, 40, Color(QIN.r, QIN.g, QIN.b, 0.85), 1.0, true)
			ci.draw_arc(p, pr + 2.4, 0.0, TAU, 40, Color(QIN.r, QIN.g, QIN.b, 0.35), 0.6, true)
		ci.draw_circle(p, 6.0, Color(PAPER.r, PAPER.g, PAPER.b, 0.75))
		_swords(ci, p, col, 0.9)
		var lp: Vector2 = p + nd["label_off"]
		Game.text(ci, lp, nd["name"], 6, QIN.darkened(0.35) if playable else INK, 1, 0, true, HALO)
		if nd["id"] == "snow_plains" and Game.campaign.get("snow_plains", false):
			Game.text(ci, lp + Vector2(0, -9), "victory", 5, QIN, 1, 3, true, HALO)
	ci.draw_set_transform(Vector2.ZERO)

# ------------------------------------------------------------------ frame, legend, cards
func _draw_overlay() -> void:
	var ci := overlay
	# graduated border: alternating black and white bars between two rules
	ci.draw_rect(OUTER, INK, false, 1.0)
	ci.draw_rect(FRAME, INK, false, 0.8)
	var seg := 12.0
	var x := OUTER.position.x
	var i := 0
	while x < OUTER.end.x - 0.5:
		var w := minf(seg, OUTER.end.x - x)
		if i % 2 == 0:
			ci.draw_rect(Rect2(x, OUTER.position.y, w, FRAME.position.y - OUTER.position.y), INK)
			ci.draw_rect(Rect2(x, FRAME.end.y, w, OUTER.end.y - FRAME.end.y), INK)
		x += seg
		i += 1
	var y := OUTER.position.y
	i = 0
	while y < OUTER.end.y - 0.5:
		var h := minf(seg, OUTER.end.y - y)
		if i % 2 == 1:
			ci.draw_rect(Rect2(OUTER.position.x, y, FRAME.position.x - OUTER.position.x, h), INK)
			ci.draw_rect(Rect2(FRAME.end.x, y, OUTER.end.x - FRAME.end.x, h), INK)
		y += seg
		i += 1
	ci.draw_rect(FRAME.grow(-2.0), Color(INK.r, INK.g, INK.b, 0.6), false, 0.4)
	# title cartouche
	var cr := Rect2(22, 22, 176, 44)
	_slip(ci, cr)
	Game.text(ci, Vector2(cr.get_center().x, cr.position.y + 19), "THE CONQUEST OF ZHAO", 7, INK, 1, 1, false)
	Game.text(ci, Vector2(cr.get_center().x, cr.position.y + 33), "Campaign map of the Qin army. Chapter I", 5, SOFT, 1, 3, false)
	# legend
	var lr := Rect2(500, 22, 118, 78)
	_slip(ci, lr)
	Game.text(ci, Vector2(lr.position.x + 8, lr.position.y + 12), "Legend", 6, INK, 0, 3, false)
	var ly := lr.position.y + 22.0
	_bar(ci, Vector2(lr.position.x + 14, ly), 0.0, QIN)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "Army of Qin", 5, QIN.darkened(0.3), 0, 3, false)
	ly += 10.0
	_bar(ci, Vector2(lr.position.x + 14, ly), 0.0, ZHAO)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "Army of Zhao", 5, ZHAO.darkened(0.3), 0, 3, false)
	ly += 10.0
	_dashed(ci, PackedVector2Array([Vector2(lr.position.x + 8, ly), Vector2(lr.position.x + 20, ly)]), QIN, 1.0, 3.0, 1.6)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "March of Qin", 5, INK, 0, 3, false)
	ly += 10.0
	_swords(ci, Vector2(lr.position.x + 14, ly), INK, 0.6)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "Battle", 5, INK, 0, 3, false)
	ly += 10.0
	ci.draw_arc(Vector2(lr.position.x + 14, ly), 2.6, 0.0, TAU, 20, INK, 0.7, true)
	ci.draw_rect(Rect2(Vector2(lr.position.x + 12.9, ly - 1.1), Vector2(2.2, 2.2)), INK)
	Game.text(ci, Vector2(lr.position.x + 24, ly + 2.5), "Capital", 5, INK, 0, 3, false)
	# compass
	var cc := Vector2(600, 196)
	for k in 8:
		var a := k * PI * 0.25 - PI * 0.5
		var r := 11.0 if k % 2 == 0 else 6.0
		var tip := cc + Vector2.from_angle(a) * r
		var l := cc + Vector2.from_angle(a - 0.5) * 2.2
		var rr := cc + Vector2.from_angle(a + 0.5) * 2.2
		ci.draw_colored_polygon(PackedVector2Array([cc, l, tip]), INK)
		ci.draw_colored_polygon(PackedVector2Array([cc, tip, rr]), Color(PAPER.r, PAPER.g, PAPER.b, 0.9))
		ci.draw_polyline(PackedVector2Array([l, tip, rr]), INK, 0.4, true)
	Game.text(ci, cc + Vector2(0, -13), "N", 6, INK, 1, 1, false)
	# scale of li
	var sx := 352.0
	var sy := 328.0
	for k in 4:
		var r := Rect2(sx + k * 22.0, sy, 22.0, 2.6)
		if k % 2 == 0:
			ci.draw_rect(r, INK)
		ci.draw_rect(r, INK, false, 0.5)
		Game.text(ci, Vector2(sx + k * 22.0, sy - 2.0), str(k * 100), 4, INK, 1, 3, false)
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
	# info card for the selected battle
	_card(ci)
	Game.text(ci, Vector2(616, 340), "Arrows or mouse: choose.  Enter or click: march.  Esc: back", 5, SOFT, 2, 3, true, HALO)

func _slip(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(1.5, 1.5), r.size), Color(0.1, 0.07, 0.05, 0.18))
	ci.draw_rect(r, Color(0.95, 0.92, 0.84))
	ci.draw_rect(r, INK, false, 0.8)
	ci.draw_rect(r.grow(-2.0), Color(INK.r, INK.g, INK.b, 0.5), false, 0.4)

func _wax(ci: CanvasItem, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for k in 14:
		var a := k * TAU / 14.0
		pts.append(c + Vector2.from_angle(a) * r * (1.0 + 0.12 * sin(a * 5.0 + c.x)))
	ci.draw_colored_polygon(pts, Color("#8e1d22"))
	ci.draw_circle(c, r * 0.55, Color("#b3302e"))

func _card(ci: CanvasItem) -> void:
	var nd: Dictionary = _all_nodes()[sel]
	var r := Rect2(22, 252, 206, 74)
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
