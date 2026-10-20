class_name Hud
extends Control
## All in-battle UI, drawn by hand in the 640x360 pixel space.
## Style: lacquer red and gold, black ink brush strokes, carved stone rank seals.

var battle = null
var banners: Array = []
var popups: Array = []
var alerts: Array = []
var callout := ""
var callout_t := 0.0
var t := 0.0
var flash := 0.0
var help_t := 26.0
var help_on := false
var tips_shown := {}
var lines_fx: Array = []
var cut: Dictionary = {}
var slashes: Array = []
var last_chain := 0
var chain_pop := 0.0
var stamp: Dictionary = {}

var perk_open := false
var perk_choices: Array = []
var perk_hover := -1
var pause_open := false
var results_open := false
var results_t := 0.0
var results_victory := false
var auto_t := 0.0

var seals := {}
var swash: Texture2D
var band: Texture2D
var jitter := PackedInt32Array()
var fade_tex: Texture2D

const C_TEXT := Color("#f4ead8")
const C_DIM := Color("#a9a3b8")
const C_GOLD := Color("#ffd166")
const C_GOLD_D := Color("#c98a2e")
const C_RED := Color("#e5484d")
const C_INK := Color(0.05, 0.035, 0.06)
const C_LACQUER := Color("#8e1b22")
const C_HP := Color("#d63a36")
const C_STAM := Color("#6fd39a")
const C_SPIRIT := Color("#7fb4ff")
const RANK_SEAL := ["bing", "wu", "bai", "qian", "five_qian", "jiang"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Game.VIEW
	Game.style_popup.connect(_on_popup)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 512:
		jitter.append(rng.randi() % 3)
	_build_textures()

# ------------------------------------------------------------------ baked UI art
static func seal_image(ids: Array, red: Color = Color("#b3202a"), ink: Color = Color("#f7e9cf"), seed: int = 1) -> Image:
	var hgt := 4 + ids.size() * 16 + (ids.size() - 1) * 1
	var img := Image.create(20, hgt, false, Image.FORMAT_RGBA8)
	img.fill(red)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in ids.size():
		var g := Kanji.image(ids[i], ink)
		img.blend_rect(g, Rect2i(0, 0, 16, 16), Vector2i(2, 2 + i * 17))
	# carved-stone wear: chipped border, speckles, a darker inner rim
	for y in hgt:
		for x in 20:
			var edge := x == 0 or y == 0 or x == 19 or y == hgt - 1
			if edge and rng.randf() < 0.22:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif (x == 1 or y == 1 or x == 18 or y == hgt - 2) and img.get_pixel(x, y) == red:
				img.set_pixel(x, y, red.darkened(0.18))
			elif rng.randf() < 0.035:
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.darkened(0.25) if c == red else red.lightened(0.1))
	return img

func _build_textures() -> void:
	for i in RANK_SEAL.size():
		var id: String = RANK_SEAL[i]
		var ids := ["five", "qian"] if id == "five_qian" else [id]
		seals[id] = seal_tex(ids, Color("#b3202a"), Color("#f7e9cf"), i + 3)
	seals["qin"] = seal_tex(["qin"], Color("#b3202a"), Color("#ffd98a"), 11)
	seals["zhao"] = seal_tex(["zhao"], Color("#3a3f9e"), Color("#e8ecff"), 12)
	swash = ImageTexture.create_from_image(_brush_image(72, 26, 3))
	var fi := Image.create(120, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 120:
			var k := (1.0 - float(x) / 119.0) * clampf((1.0 - float(y) / 39.0) * 1.6, 0.0, 1.0)
			fi.set_pixel(x, y, Color(C_INK.r, C_INK.g, C_INK.b, k * k * (3.0 - 2.0 * k)))
	fade_tex = ImageTexture.create_from_image(fi)
	band = ImageTexture.create_from_image(_brush_image(640, 46, 9))

## A horizontal ink brush stroke: tapered ends, gently wobbling anti-aliased edges, and
## bristle streaks (each row of bristles has its own density and runs out at its own point,
## giving the dry-brush tail).
static func _brush_image(w: int, h: int, seed: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dens := PackedFloat32Array()
	var ends := PackedFloat32Array()
	for y in h:
		var r := rng.randf()
		dens.append(0.4 if r < 0.14 else rng.randf_range(0.82, 1.0))
		ends.append(1.0 - pow(rng.randf(), 2.0) * 0.22)
	var top := 0.0
	var bot := 0.0
	var vt := 0.0
	var vb := 0.0
	for x in w:
		var u := float(x) / (w - 1)
		var taper := sqrt(clampf(minf(u / 0.07, (1.0 - u) / 0.04), 0.0, 1.0))
		vt = clampf(vt + rng.randf_range(-0.12, 0.12), -0.3, 0.3)
		vb = clampf(vb + rng.randf_range(-0.12, 0.12), -0.3, 0.3)
		top = clampf(top + vt, -2.0, 2.0)
		bot = clampf(bot + vb, -2.0, 2.0)
		var half := (h * 0.5 - 2.0) * taper
		var cy := h * 0.5 - sin(u * PI) * 1.5
		for y in h:
			var dy := y + 0.5 - cy
			var cov := clampf(minf(dy - (-half + top), (half + bot) - dy) + 0.5, 0.0, 1.0)
			if cov <= 0.0:
				continue
			var a := cov * dens[y] * clampf((ends[y] - u) / 0.025, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return img

## Scale2x (EPX): doubles a pixel image, rounding off diagonal staircases.
static func scale2x(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var p := src.get_pixel(x, y)
			var a := src.get_pixel(x, maxi(y - 1, 0))
			var b := src.get_pixel(mini(x + 1, w - 1), y)
			var c := src.get_pixel(maxi(x - 1, 0), y)
			var d := src.get_pixel(x, mini(y + 1, h - 1))
			var e0 := p
			var e1 := p
			var e2 := p
			var e3 := p
			if c == a and c != d and a != b:
				e0 = a
			if a == b and a != c and b != d:
				e1 = b
			if d == c and d != b and c != a:
				e2 = c
			if b == d and b != a and d != c:
				e3 = d
			out.set_pixel(x * 2, y * 2, e0)
			out.set_pixel(x * 2 + 1, y * 2, e1)
			out.set_pixel(x * 2, y * 2 + 1, e2)
			out.set_pixel(x * 2 + 1, y * 2 + 1, e3)
	return out

## A seal texture: the pixel seal smoothed with two Scale2x passes; reports its 1x size.
static func seal_tex(ids: Array, red: Color, ink: Color, seed: int) -> ImageTexture:
	var img := seal_image(ids, red, ink, seed)
	var sz := Vector2i(img.get_width(), img.get_height())
	var t := ImageTexture.create_from_image(scale2x(scale2x(img)))
	t.set_size_override(sz)
	return t

# ------------------------------------------------------------------ API
func _on_popup(text: String, col: Color) -> void:
	popups.push_front({"s": text, "col": col, "t": 0.0})
	if popups.size() > 6:
		popups.pop_back()

func banner(title: String, sub: String, col: Color = C_GOLD, big: bool = false, dur: float = 3.0, seal: String = "", urgent: bool = false) -> void:
	var b := {"title": title, "sub": sub, "col": col, "t": 0.0, "dur": dur, "big": big, "seal": seal}
	if urgent:
		banners.push_front(b)
	else:
		banners.append(b)

func alert(text: String, col: Color = C_RED) -> void:
	alerts.append({"s": text, "col": col, "t": 0.0})
	if alerts.size() > 3:
		alerts.remove_at(0)

func skill_callout(name: String) -> void:
	if name == "":
		return
	callout = name
	callout_t = 1.0

func tip(key: String, text: String) -> void:
	if tips_shown.has(key) or Game.autotest:
		return
	tips_shown[key] = true
	alert(text, Color("#9fe8ff"))

func screen_flash(a: float) -> void:
	flash = maxf(flash, a)

## Manga speed lines converging on a screen point (used with impact frames).
func speed_lines(screen_pos: Vector2, dur: float, col: Color = Color(0.02, 0.01, 0.03)) -> void:
	var seed := randi()
	lines_fx.append({"p": screen_pos, "t": 0.0, "dur": dur, "seed": seed, "col": col})

## A screen-wide brush stroke along the direction of a critical blow ("one-flash cut").
func ink_slash(screen_pos: Vector2, dir: Vector2) -> void:
	slashes.append({"p": screen_pos, "d": dir.normalized(), "t": 0.0})

## Full-screen character introduction (boss, officers).
func cutin(title: String, sub: String, frames_tex: Texture2D, col: Color, dur: float = 2.4) -> void:
	cut = {"title": title, "sub": sub, "tex": frames_tex, "col": col, "t": 0.0, "dur": dur}

## The rank seal slams onto the screen.
func promote_stamp(rank: int) -> void:
	stamp = {"id": RANK_SEAL[rank], "t": 0.0, "dur": 3.4, "rank": rank}
	Sfx.play("boom", -6.0, 1.4)

func open_perks(choices: Array) -> void:
	if choices.is_empty():
		return
	perk_choices = choices
	perk_open = true
	auto_t = 0.0
	get_tree().paused = true

func show_results(victory: bool) -> void:
	results_open = true
	results_victory = victory
	results_t = 0.0

# ------------------------------------------------------------------ input + timers
func _process(delta: float) -> void:
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	if get_tree().paused:
		rdt = delta
	rdt = minf(rdt, 0.1)
	t += rdt
	results_t += rdt
	flash = maxf(0.0, flash - rdt * 3.0)
	callout_t -= rdt
	if not get_tree().paused:
		help_t -= rdt
	if not battle.possess:
		for b in banners.slice(0, 1):
			b["t"] = float(b["t"]) + rdt
	if banners.size() > 0 and float(banners[0]["t"]) > float(banners[0]["dur"]):
		banners.remove_at(0)
	for p in popups:
		p["t"] = float(p["t"]) + rdt
	popups = popups.filter(func(p): return float(p["t"]) < 1.6)
	for a in alerts:
		a["t"] = float(a["t"]) + rdt
	alerts = alerts.filter(func(a): return float(a["t"]) < 3.2)
	for l in lines_fx:
		l["t"] = float(l["t"]) + rdt
	for sl in slashes:
		sl["t"] = float(sl["t"]) + rdt
	slashes = slashes.filter(func(sl): return float(sl["t"]) < 0.45)
	if Game.chain_hits > last_chain:
		chain_pop = 1.0
	last_chain = Game.chain_hits
	chain_pop = maxf(0.0, chain_pop - rdt * 6.0)
	lines_fx = lines_fx.filter(func(l): return float(l["t"]) < float(l["dur"]))
	if not cut.is_empty():
		cut["t"] = float(cut["t"]) + rdt
		if battle and battle.atmos:
			battle.atmos.letterbox_target = 1.0 if float(cut["t"]) < float(cut["dur"]) - 0.3 else 0.0
		if float(cut["t"]) > float(cut["dur"]):
			cut = {}
	if not stamp.is_empty():
		stamp["t"] = float(stamp["t"]) + rdt
		if float(stamp["t"]) > float(stamp["dur"]):
			stamp = {}
	_handle_input(rdt)
	queue_redraw()

func _handle_input(rdt: float) -> void:
	if Input.is_action_just_pressed("help"):
		help_on = not help_on
	if results_open:
		if results_t < 1.0:
			return
		if Input.is_action_just_pressed("confirm"):
			battle.leave(false)
		elif Input.is_action_just_pressed("flask"):
			battle.leave(true)
		return
	if perk_open:
		auto_t += rdt
		var pick := -1
		if Input.is_action_just_pressed("order_follow"):
			pick = 0
		elif Input.is_action_just_pressed("order_charge"):
			pick = 1
		elif Input.is_action_just_pressed("order_hold"):
			pick = 2
		perk_hover = _perk_at(get_viewport().get_mouse_position())
		if Input.is_action_just_pressed("attack") and perk_hover >= 0:
			pick = perk_hover
		if Game.autotest and not Game.noauto and auto_t > 0.5:
			pick = 0
		if pick >= 0 and pick < perk_choices.size():
			_choose_perk(pick)
		return
	if Input.is_action_just_pressed("pause"):
		if battle.possess:
			return
		pause_open = not pause_open
		get_tree().paused = pause_open
		Sfx.play("ui", -6.0)
		return
	if pause_open:
		if Input.is_action_just_pressed("confirm"):
			pause_open = false
			get_tree().paused = false
		elif Input.is_action_just_pressed("flask"):
			get_tree().paused = false
			battle.leave(true)
		elif Input.is_action_just_pressed("cycle"):
			get_tree().paused = false
			battle.leave(false)

func _choose_perk(i: int) -> void:
	var id: String = perk_choices[i]
	Game.perks[id] = true
	perk_open = false
	get_tree().paused = false
	Sfx.play("pickup", -2.0)
	battle.on_perk_chosen(id)
	alert("LEGACY: " + Game.PERKS[id]["name"], C_GOLD)

func _perk_rect(i: int) -> Rect2:
	var w := 150.0
	var gap := 14.0
	var total := perk_choices.size() * w + (perk_choices.size() - 1) * gap
	return Rect2(320.0 - total * 0.5 + i * (w + gap), 122.0, w, 128.0)

func _perk_at(m: Vector2) -> int:
	for i in perk_choices.size():
		if _perk_rect(i).has_point(m):
			return i
	return -1

# ------------------------------------------------------------------ drawing helpers
func _t(pos: Vector2, s: String, sz: int = 8, col: Color = C_TEXT, align: int = 0) -> void:
	Game.text(self, pos, s, sz, col, align)

## Display-font text. scale 1 = 9px tall, 2 = 18px, 3 = 27px...
func _tt(pos: Vector2, s: String, col: Color, align: int = 1, scale: int = 1) -> void:
	Game.text(self, pos, s, 9 * scale, col, align, 1)

func _tt_width(s: String, scale: int = 1) -> float:
	return Game.text_w(s, 9 * scale, 1)

func _lines(pos: Vector2, s: String, sz: int, col: Color, align: int = 0, lh: float = 10.0) -> void:
	var y := pos.y
	for line in s.split("\n"):
		_t(Vector2(pos.x, y), line, sz, col, align)
		y += lh

## A brush-stroke bar: ink backing with ragged edges, three-tone fill, optional rally segment.
func _brush_bar(x: float, y: float, w: int, h: int, frac: float, col: Color, seed: int = 0, extra: float = 0.0, extra_col: Color = Color.WHITE) -> void:
	var fw := int(round(w * clampf(frac, 0.0, 1.0)))
	var ew := int(round(w * clampf(frac + extra, 0.0, 1.0)))
	var hi := col.lightened(0.35)
	var lo := col.darkened(0.35)
	for i in w:
		var taper := mini(mini(i, w - 1 - i), 3)
		var j1: int = jitter[(i + seed * 37) % 512]
		var j2: int = jitter[(i * 3 + seed * 11 + 7) % 512]
		var top := y - 1.0 + float(maxi(0, 2 - taper)) * 0.5 + (1.0 if j1 == 2 else 0.0)
		var bot := y + h + 1.0 - float(maxi(0, 2 - taper)) * 0.5 - (1.0 if j2 == 2 else 0.0)
		draw_rect(Rect2(x + i, top, 1, bot - top), Color(C_INK.r, C_INK.g, C_INK.b, 0.88))
		if i < fw:
			draw_rect(Rect2(x + i, y, 1, h), col)
			draw_rect(Rect2(x + i, y, 1, 1), hi)
			if h > 2:
				draw_rect(Rect2(x + i, y + h - 1, 1, 1), lo)
		elif i < ew:
			draw_rect(Rect2(x + i, y, 1, h), extra_col)

## A lacquered panel with gold corner brackets.
func _ornate(r: Rect2, a: float = 0.85) -> void:
	draw_rect(r, Color(0.07, 0.045, 0.06, a))
	draw_rect(r.grow(-2.0), Color(0.1, 0.06, 0.07, a * 0.6))
	draw_rect(r, Color(0.55, 0.38, 0.2, a), false, 1.0)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 1)), Color(0.7, 0.14, 0.16, a * 0.8))
	var g := Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, a)
	for c in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		var sx := 1.0 if c.x <= r.position.x else -1.0
		var sy := 1.0 if c.y <= r.position.y else -1.0
		draw_rect(Rect2(c.x if sx > 0.0 else c.x - 4.0, c.y, 5, 1), g)
		draw_rect(Rect2(c.x, c.y if sy > 0.0 else c.y - 4.0, 1, 5), g)
		draw_rect(Rect2(c.x + sx * 2.0, c.y + sy * 2.0, 1, 1), g)

## Soft dithered ink backing that fades out (for HUD readability without hard boxes).
func _ink_fade(r: Rect2, a: float = 0.55, flip: bool = false) -> void:
	var rect := r
	if flip:
		rect = Rect2(r.position + Vector2(r.size.x, 0), Vector2(-r.size.x, r.size.y))
	draw_texture_rect(fade_tex, rect, false, Color(1, 1, 1, a))

func _seal(id: String, pos: Vector2, scale: float = 1.0, a: float = 1.0) -> void:
	var tx: Texture2D = seals[id]
	draw_texture_rect(tx, Rect2(pos, tx.get_size() * scale), false, Color(1, 1, 1, a))

func _gourd(pos: Vector2, full: bool) -> void:
	var o := C_INK
	draw_rect(Rect2(pos + Vector2(1, 0), Vector2(3, 3)), o)
	draw_rect(Rect2(pos + Vector2(0, 3), Vector2(5, 5)), o)
	var c := Color("#e0413c") if full else Color("#3a2a33")
	draw_rect(Rect2(pos + Vector2(2, 1), Vector2(1, 1)), c)
	draw_rect(Rect2(pos + Vector2(1, 4), Vector2(3, 3)), c)
	if full:
		draw_rect(Rect2(pos + Vector2(1, 4), Vector2(1, 1)), Color("#ff9a8a"))
	draw_rect(Rect2(pos + Vector2(2, -1), Vector2(1, 1)), Color("#a7744c"))

# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if battle == null:
		return
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(1, 1, 1, flash * 0.35))
	_draw_speed_lines()
	_draw_slashes()
	var cinematic := not cut.is_empty()
	if not results_open and not cinematic:
		_draw_player()
		_draw_rank_style()
		_draw_battle_bar()
		_draw_boss()
		_draw_command()
		_draw_markers()
		_draw_alerts()
		_draw_hints()
	if not perk_open and not cinematic and not battle.possess:
		_draw_banner()
	if not stamp.is_empty() and not perk_open:
		_draw_stamp()
	if cinematic:
		_draw_cutin()
	if battle.possess:
		_draw_candidates()
		_draw_possess()
	if perk_open:
		_draw_perks()
	if pause_open:
		_draw_pause()
	if results_open:
		_draw_results()
	_draw_cursor()

## Pixel crosshair (the OS cursor is hidden while fighting).
func _draw_cursor() -> void:
	var menu: bool = perk_open or pause_open or results_open or battle.possess or Game.autotest
	var want := Input.MOUSE_MODE_VISIBLE if menu else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if menu:
		return
	var m := get_viewport().get_mouse_position().floor()
	var c := Color(1.0, 0.95, 0.85, 0.95)
	var o := Color(0.05, 0.04, 0.08, 0.9)
	var arms: Array[Rect2] = []
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var a: Vector2 = m + d * 2.0
		var b: Vector2 = m + d * 3.0
		arms.append(Rect2(a.min(b), Vector2(2, 1) if d.y == 0.0 else Vector2(1, 2)))
	for r in arms:
		draw_rect(r.grow(1.0), o)
	draw_rect(Rect2(m - Vector2(1, 1), Vector2(3, 3)), o)
	for r in arms:
		draw_rect(r, c)
	draw_rect(Rect2(m, Vector2(1, 1)), Color(1, 0.3, 0.25))

func _draw_speed_lines() -> void:
	for l in lines_fx:
		var k := float(l["t"]) / float(l["dur"])
		var c: Vector2 = l["p"]
		var col: Color = l["col"]
		var rng := RandomNumberGenerator.new()
		rng.seed = int(l["seed"])
		for i in 46:
			var a := rng.randf() * TAU
			var r0 := rng.randf_range(70.0, 150.0) * (1.0 - k * 0.3)
			var wdt := rng.randf_range(1.0, 4.0)
			var dir := Vector2.from_angle(a)
			var p0 := c + dir * r0
			var p1 := c + dir * 520.0
			var n := dir.orthogonal() * wdt
			draw_colored_polygon(PackedVector2Array([p0, p1 + n, p1 - n]), Color(col.r, col.g, col.b, 0.9 * (1.0 - k)))

func _draw_slashes() -> void:
	for sl in slashes:
		var k := float(sl["t"]) / 0.45
		var grow := clampf(float(sl["t"]) / 0.06, 0.0, 1.0)
		var d: Vector2 = sl["d"]
		var c: Vector2 = sl["p"]
		var ln := 900.0 * grow
		var th := 26.0 * (1.0 - k * 0.7)
		draw_set_transform(c - d * 450.0 + d * ln * 0.5, d.angle(), Vector2.ONE)
		draw_texture_rect(band, Rect2(Vector2(-ln * 0.5, -th * 0.5), Vector2(ln, th)), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.9 * (1.0 - k)))
		draw_rect(Rect2(Vector2(-ln * 0.5, -1.0), Vector2(ln, 2.0)), Color(0.95, 0.15, 0.12, 1.0 - k))
		draw_rect(Rect2(Vector2(-ln * 0.45, -0.5), Vector2(ln * 0.9, 1.0)), Color(1, 0.95, 0.9, 1.0 - k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_player() -> void:
	var p = battle.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	_ink_fade(Rect2(0, 0, 250, 90), 0.7)
	var sid: String = RANK_SEAL[Game.rank]
	_seal(sid, Vector2(7, 7))
	var x := 32.0
	_t(Vector2(x, 13), p.uname, 8, C_GOLD)
	_t(Vector2(x + Game.text_w(p.uname, 8) + 5, 13), p.kind_label(), 8, C_DIM)
	var hpf: float = p.hp / p.max_hp
	_brush_bar(x, 17, 150, 5, hpf, C_HP, 1, clampf(p.rally / p.max_hp, 0.0, 1.0 - hpf), Color("#ff9b4a"))
	_t(Vector2(x + 155, 23), str(int(ceil(p.hp))), 8, C_TEXT)
	var sw := int(118.0 * clampf(p.max_stamina / 100.0, 0.7, 1.4))
	_brush_bar(x, 26, sw, 3, p.stamina / p.max_stamina, C_STAM, 2)
	var ready: bool = p.spirit >= p.weapon.skill_cost
	var scol := C_SPIRIT.lerp(Color.WHITE, 0.35 + 0.35 * sin(t * 8.0)) if ready else C_SPIRIT
	_brush_bar(x, 32, 100, 3, p.spirit / Unit.MAX_SPIRIT, scol, 3)
	var mark: float = x + 100.0 * p.weapon.skill_cost / Unit.MAX_SPIRIT
	draw_rect(Rect2(mark, 31, 1, 5), Color(1, 1, 1, 0.6))
	for i in p.max_flasks:
		_gourd(Vector2(x + i * 8.0, 39), i < p.flasks)
	_t(Vector2(x + p.max_flasks * 8.0 + 3, 46), "R", 8, C_DIM)
	var wd: Dictionary = Art.weapons[p.weapon.tex_key]
	var tx: Texture2D = wd["tex"]
	var wy := 56.0
	draw_texture(tx, Vector2(8, wy - tx.get_height() * 0.5).floor())
	_t(Vector2(12 + tx.get_width(), wy + 3), p.weapon.display_name(), 8, C_GOLD)
	_t(Vector2(8, wy + 14), "E  %s" % p.weapon.skill_name, 8, Color("#bcd6ff") if ready else C_DIM)
	if p.weapon.clip > 0:
		var s := "RELOADING" if p.reload_t > 0.0 else "BOLTS %d/%d" % [p.ammo, p.weapon.clip]
		_t(Vector2(x + 120, 46), s, 8, C_DIM)

func _draw_rank_style() -> void:
	_ink_fade(Rect2(400, 0, 240, 110), 0.65, true)
	_tt(Vector2(632, 13), Game.rank_name(), C_GOLD, 2)
	var nx := Game.next_rank_xp()
	_brush_bar(522, 17, 110, 2, Game.rank_progress(), Color("#f2c14e"), 4)
	if nx > 0:
		_t(Vector2(632, 30), "%d / %d" % [int(Game.xp), int(nx)], 8, C_DIM, 2)
	var tier := Game.style_tier()
	var td: Dictionary = Game.STYLE_TIERS[tier]
	var col: Color = td["col"]
	if Game.style > 1.0:
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (tier * 0.3)
		var pop := clampf(Game.style_hold * 1.5, 0.0, 1.0)
		draw_texture_rect(swash, Rect2(Vector2(556, 38), Vector2(82, 32)), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.9))
		draw_texture_rect(swash, Rect2(Vector2(566, 56), Vector2(64, 8)), false, Color(col.r, col.g, col.b, 0.55 + pop * 0.4))
		var letter: String = td["n"]
		_tt(Vector2(604, 66) + shake, letter, col, 1, 3)
		_t(Vector2(632, 78), td["name"], 8, col, 2)
		_brush_bar(572, 81, 60, 2, Game.style_frac(), col, 5)
		_t(Vector2(632, 92), "XP X%.1f" % Game.style_mult(), 8, C_DIM, 2)
	var y := 104.0
	if Game.chain_hits >= 3:
		var sc := 2 if Game.chain_hits >= 10 else 1
		var s := "%d" % Game.chain_hits
		var pop := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * chain_pop * 2.0
		_tt(Vector2(608, y + 6) + pop, s, Color(1.0, 0.96, 0.85).lerp(Color("#ff5a4a"), clampf(Game.chain_hits / 40.0, 0.0, 1.0)), 2, sc)
		_t(Vector2(632, y + 4), "HITS", 8, C_DIM, 2)
		y += 12.0 + sc * 6.0
	for p in popups:
		var a := clampf(1.6 - float(p["t"]), 0.0, 1.0)
		var c: Color = p["col"]
		var slide := (1.0 - clampf(float(p["t"]) * 8.0, 0.0, 1.0)) * 12.0
		_t(Vector2(632 + slide, y), p["s"], 8, Color(c.r, c.g, c.b, a), 2)
		y += 9.0

func _draw_battle_bar() -> void:
	var a: float = battle.army_strength(0)
	var e: float = battle.army_strength(1)
	var frac := a / maxf(1.0, a + e)
	var r := Rect2(236, 8, 168, 5)
	draw_rect(r.grow(2.0), C_INK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color("#c8343b"))
	draw_rect(Rect2(r.position, Vector2(r.size.x * frac, 1)), Color("#ff7a6b"))
	draw_rect(Rect2(r.position + Vector2(r.size.x * frac, 0), Vector2(r.size.x * (1.0 - frac), r.size.y)), Color("#4b4fb8"))
	draw_rect(Rect2(r.position + Vector2(r.size.x * frac, 0), Vector2(r.size.x * (1.0 - frac), 1)), Color("#8f93ff"))
	var nx := r.position.x + r.size.x * frac
	draw_colored_polygon(PackedVector2Array([Vector2(nx - 3, 4), Vector2(nx + 3, 4), Vector2(nx, 8)]), C_GOLD)
	draw_rect(Rect2(nx, 8, 1, 5), C_GOLD)
	_seal("qin", Vector2(212, 2), 1.0)
	_seal("zhao", Vector2(408, 2), 1.0)
	_t(Vector2(238, 24), "%d" % int(a), 8, Color("#ff9a8a"))
	_t(Vector2(402, 24), "%d" % int(e), 8, Color("#b4b6ff"), 2)
	var m: float = battle.morale[0]
	var mc := Color("#7bd389") if m > 50 else (Color("#ffd166") if m > 25 else Color("#e5484d"))
	_t(Vector2(320, 24), "MORALE", 8, C_DIM, 1)
	_brush_bar(285, 27, 70, 2, m / 100.0, mc, 6)

func _draw_boss() -> void:
	var b = battle.boss
	if b == null or not is_instance_valid(b) or b.dead:
		return
	var y := 334.0
	draw_texture_rect(band, Rect2(140, 316, 360, 34), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.7))
	_tt(Vector2(320, y - 4), b.uname, Color("#e9d8ff"), 1)
	_t(Vector2(320 + _tt_width(b.uname) * 0.5 + 6, y - 4), "GENERAL OF ZHAO", 8, C_DIM)
	_brush_bar(170, y + 1, 300, 5, b.hp / b.max_hp, Color("#a3202c"), 7)
	_brush_bar(170, y + 9, 300, 2, b.stance / b.max_stance, Color("#ffd23f"), 8)
	for i in 2:
		var px := 170.0 + 300.0 * (0.6 if i == 0 else 0.3)
		draw_rect(Rect2(px, y - 1, 1, 8), Color(1, 0.9, 0.7, 0.7))

func _draw_command() -> void:
	var r := Game.rank
	if r < 1:
		return
	var y := 352.0
	var n: int = battle.squad.size()
	var x := 8.0
	draw_texture_rect(band, Rect2(0, 340, 420, 20), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.5))
	_t(Vector2(x, y), "SQUAD %d/%d" % [n, Game.squad_size()], 8, C_TEXT)
	x += 70.0
	if r >= 2:
		var o: String = battle.squad_order
		for pair in [["1", "FOLLOW"], ["2", "CHARGE"], ["3", "HOLD"]]:
			var on: bool = pair[1].to_lower() == o
			if on:
				draw_rect(Rect2(x - 2, y - 8, Game.text_w(pair[0] + " " + pair[1], 8) + 4, 10), Color(0.55, 0.1, 0.12, 0.8))
			_t(Vector2(x, y), pair[0] + " " + pair[1], 8, C_GOLD if on else C_DIM)
			x += 50.0
	if r >= 3:
		var wc: float = battle.war_cry_cd
		var vc: float = battle.volley_cd
		_t(Vector2(x + 4, y), "G WAR CRY" if wc <= 0.0 else "G %ds" % int(ceil(wc)), 8, Color("#ff8a80") if wc <= 0.0 else C_DIM)
		_t(Vector2(x + 74, y), "V VOLLEY" if vc <= 0.0 else "V %ds" % int(ceil(vc)), 8, C_GOLD if vc <= 0.0 else C_DIM)

func _draw_markers() -> void:
	var cam = battle.cam
	var center: Vector2 = cam.get_screen_center_position()
	var targets: Array = []
	for o in battle.officers_alive:
		if is_instance_valid(o) and not o.dead:
			targets.append([o, Color("#ff9a3d"), "OFFICER"])
	if battle.boss != null and is_instance_valid(battle.boss) and not battle.boss.dead:
		targets.append([battle.boss, Color("#ff3d5a"), "GENERAL"])
	for tg in targets:
		var u = tg[0]
		var sp: Vector2 = u.global_position - center + Game.VIEW * 0.5
		var inner := Rect2(Vector2(14, 40), Game.VIEW - Vector2(28, 76))
		if inner.has_point(sp):
			continue
		var c := Game.VIEW * 0.5
		var dir := (sp - c).normalized()
		var k := 1e9
		if absf(dir.x) > 0.001:
			k = minf(k, (inner.size.x * 0.5) / absf(dir.x))
		if absf(dir.y) > 0.001:
			k = minf(k, (inner.size.y * 0.5) / absf(dir.y))
		var ep := c + dir * k
		var col: Color = tg[1]
		var pulse := 1.0 + 0.2 * sin(t * 6.0)
		var pts := PackedVector2Array([ep + dir * 7.0 * pulse, ep + dir.orthogonal() * 4.5, ep - dir.orthogonal() * 4.5])
		draw_colored_polygon(pts, C_INK)
		draw_colored_polygon(PackedVector2Array([ep + dir * 5.0 * pulse, ep + dir.orthogonal() * 3.0, ep - dir.orthogonal() * 3.0]), col)
		var dist := int(u.global_position.distance_to(center) / 10.0)
		var lp := ep - dir * 12.0 + Vector2(0, 3)
		lp.x = clampf(lp.x, 44.0, 596.0)
		_t(lp, "%s %dM" % [tg[2], dist], 8, col, 1)

func _draw_alerts() -> void:
	var y := 112.0
	for a in alerts:
		var al := clampf(3.2 - float(a["t"]), 0.0, 1.0)
		var c: Color = a["col"]
		var w := Game.text_w(a["s"], 8)
		draw_texture_rect(band, Rect2(320.0 - w * 0.5 - 16.0, y - 10.0, w + 32.0, 13.0), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.6 * al))
		_t(Vector2(320, y), a["s"], 8, Color(c.r, c.g, c.b, al), 1)
		y += 13.0
	if callout_t > 0.0:
		var al := clampf(callout_t * 2.0, 0.0, 1.0)
		var slide := (1.0 - clampf((1.0 - callout_t) * 8.0, 0.0, 1.0)) * 30.0
		var w := _tt_width(callout, 2)
		draw_texture_rect(band, Rect2(320.0 - w * 0.5 - 30.0, 248.0, w + 60.0, 22.0), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.65 * al))
		_tt(Vector2(320 - slide, 266), callout, Color(0.75, 0.88, 1.0, al), 1, 2)

func _draw_hints() -> void:
	if battle.possess:
		return
	if help_t > 0.0 or help_on:
		var a := 1.0 if help_on else clampf(help_t / 2.0, 0.0, 1.0)
		draw_texture_rect(band, Rect2(80, 298, 480, 30), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.7 * a))
		_t(Vector2(320, 310), "WASD MOVE   LMB ATTACK   RMB HEAVY (HOLD)   SPACE DASH   SHIFT GUARD (TAP=PARRY)", 8, Color(0.95, 0.92, 0.85, a), 1)
		_t(Vector2(320, 321), "E SKILL   R FLASK   F PICK UP   WHITE GLINT=PARRY  RED GLINT=DODGE   ESC PAUSE", 8, Color(0.75, 0.72, 0.8, a), 1)

func _draw_banner() -> void:
	if banners.is_empty():
		return
	var b: Dictionary = banners[0]
	var bt: float = b["t"]
	var dur: float = b["dur"]
	var a := clampf(bt / 0.2, 0.0, 1.0) * clampf((dur - bt) / 0.4, 0.0, 1.0)
	var big: bool = b["big"]
	var y := 130.0 if not battle.possess else 86.0
	var h := 50.0 if big else 38.0
	var grow := clampf(bt / 0.18, 0.0, 1.0)
	var bw := 640.0 * (0.4 + 0.6 * (1.0 - (1.0 - grow) * (1.0 - grow)))
	draw_texture_rect(band, Rect2(320.0 - bw * 0.5, y - h * 0.5 - 6.0, bw, h), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.82 * a))
	draw_rect(Rect2(320.0 - bw * 0.42, y + h * 0.5 - 8.0, bw * 0.84, 1), Color(0.75, 0.15, 0.15, 0.7 * a))
	var col: Color = b["col"]
	var slide := (1.0 - clampf(bt / 0.22, 0.0, 1.0)) * 24.0
	var title: String = b["title"]
	var sc := 3 if big else 2
	if _tt_width(title, sc) > 600.0:
		sc -= 1
	_tt(Vector2(320 + slide, y + (8.0 if big else 5.0)), title, Color(col.r, col.g, col.b, a), 1, sc)
	_t(Vector2(320 - slide, y + (19.0 if big else 15.0)), b["sub"], 8, Color(0.92, 0.9, 0.95, a), 1)

func _draw_stamp() -> void:
	var st: float = stamp["t"]
	var dur: float = stamp["dur"]
	var a := clampf((dur - st) / 0.5, 0.0, 1.0)
	var k := clampf(st / 0.14, 0.0, 1.0)
	var sc := lerpf(4.5, 2.0, k * k)
	var id: String = stamp["id"]
	var tx: Texture2D = seals[id]
	var sz: Vector2 = tx.get_size() * sc
	var c := Vector2(320, 214)
	if k >= 1.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 26:
			var ang := rng.randf() * TAU
			var r := rng.randf_range(26.0, 54.0) * minf(1.0, (st - 0.14) * 10.0 + 0.6)
			var s := rng.randf_range(1.0, 3.0)
			draw_rect(Rect2(c + Vector2.from_angle(ang) * r * Vector2(1.0, 0.8), Vector2(s, s)), Color(0.62, 0.08, 0.1, 0.85 * a))
	draw_texture_rect(tx, Rect2(c - sz * 0.5 + Vector2(2, 2), sz), false, Color(0, 0, 0, 0.4 * a))
	draw_texture_rect(tx, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, a))

func _draw_cutin() -> void:
	var ct: float = cut["t"]
	var dur: float = cut["dur"]
	var a := clampf(ct / 0.15, 0.0, 1.0) * clampf((dur - ct) / 0.3, 0.0, 1.0)
	var col: Color = cut["col"]
	var slide := (1.0 - clampf(ct / 0.25, 0.0, 1.0))
	var y0 := 104.0
	var y1 := 256.0
	var pts := PackedVector2Array([Vector2(-20 - slide * 400, y0 + 10), Vector2(660 - slide * 400, y0 - 10),
		Vector2(660 - slide * 400, y1 - 10), Vector2(-20 - slide * 400, y1 + 10)])
	draw_colored_polygon(pts, Color(col.r * 0.25, col.g * 0.08, col.b * 0.12, 0.92 * a))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var yy := rng.randf_range(y0, y1)
		var ln := rng.randf_range(80, 300)
		var xx := fmod(rng.randf() * 900.0 + ct * 900.0 * rng.randf_range(0.6, 1.4), 900.0) - 150.0
		draw_rect(Rect2(xx, yy, ln, 1), Color(col.r, col.g * 0.6, col.b * 0.6, 0.35 * a))
	var sun := Vector2(450, 182)
	draw_circle(sun, 64.0, Color(col.r * 0.8, col.g * 0.2, col.b * 0.2, 0.55 * a))
	draw_circle(sun, 48.0, Color(col.r, col.g * 0.35, col.b * 0.3, 0.65 * a))
	var tx: Texture2D = cut["tex"]
	if tx:
		var sc := 5.0
		var ts := tx.get_size() * sc
		var pos := Vector2(450.0 + slide * 200.0 - ts.x * 0.5, 252.0 - ts.y)
		draw_texture_rect(tx, Rect2(pos + Vector2(6, 2), ts), false, Color(1.0, 0.3, 0.25, 0.7 * a))
		draw_texture_rect(tx, Rect2(pos + Vector2(-4, 3), ts), false, Color(0.05, 0.03, 0.08, 0.8 * a))
		draw_texture_rect(tx, Rect2(pos, ts), false, Color(1, 1, 1, a))
	draw_rect(Rect2(0, y0 - 12, 640, 2), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.8 * a))
	draw_rect(Rect2(0, y1 + 10, 640, 2), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.8 * a))
	var tslide := (1.0 - clampf((ct - 0.15) / 0.3, 0.0, 1.0)) * -60.0
	_t(Vector2(60 + tslide, 144), cut["sub"], 8, Color(0.95, 0.85, 0.85, a), 0)
	_tt(Vector2(56 + tslide, 192), cut["title"], Color(1.0, 0.92, 0.78, a), 0, 4)
	draw_rect(Rect2(60 + tslide, 200, 180, 1), Color(0.85, 0.15, 0.15, a))

func _to_screen(p: Vector2) -> Vector2:
	return p - battle.cam.get_screen_center_position() + Game.VIEW * 0.5

## Candidate bodies are drawn here (above the ink filter) so the gold highlight stays visible.
func _draw_candidates() -> void:
	for i in battle.cands.size():
		var u = battle.cands[i]
		if not is_instance_valid(u) or u.dead:
			continue
		var sel: bool = i == battle.cand_sel
		var sp := _to_screen(u.global_position).floor()
		var col := Color("#d8262e") if sel else Color(0.1, 0.08, 0.1, 0.8)
		draw_set_transform(sp, 0.0, Vector2(1.0, 0.6))
		draw_arc(Vector2.ZERO, 11.0 if sel else 8.0, 0.0, TAU, 24, col, 1.5 if sel else 1.0)
		if sel:
			draw_arc(Vector2.ZERO, 15.0 + sin(t * 12.0), 0.0, TAU, 24, Color(0.85, 0.15, 0.15, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var tp := sp + Vector2(0, -32 + sin(t * 6.0) * 1.5)
		if sel:
			draw_colored_polygon(PackedVector2Array([tp + Vector2(-5, -5), tp + Vector2(5, -5), tp + Vector2(0, 1)]), col)
			_t(tp + Vector2(0, -8), u.uname, 8, Color(0.1, 0.06, 0.08), 1)
		else:
			draw_rect(Rect2(tp + Vector2(-1, -2), Vector2(3, 3)), col)

func _draw_possess() -> void:
	_tt(Vector2(320, 34), "YOU HAVE FALLEN", Color("#c8202a"), 1, 3)
	_t(Vector2(320, 48), "YOUR WILL PASSES TO ANOTHER SOLDIER ON THE FIELD", 8, Color(0.15, 0.1, 0.12), 1)
	if battle.cands.is_empty():
		return
	var u = battle.cands[clampi(battle.cand_sel, 0, battle.cands.size() - 1)]
	if not is_instance_valid(u):
		return
	var r := Rect2(176, 262, 288, 82)
	_ornate(r, 0.92)
	_tt(Vector2(186, 278), u.uname, C_GOLD, 0)
	_t(Vector2(454, 276), u.kind_label() + (" (SQUAD)" if u.in_squad else ""), 8, C_DIM, 2)
	var wd: Dictionary = Art.weapons[u.weapon.tex_key]
	var tx: Texture2D = wd["tex"]
	draw_texture(tx, Vector2(186, 286))
	_t(Vector2(190 + tx.get_width(), 293), u.weapon.display_name() + "   " + u.weapon.scaling_text(), 8, C_TEXT)
	_t(Vector2(186, 306), u.weapon.desc, 8, C_DIM)
	_t(Vector2(186, 318), "VIG %d  END %d  STR %d  DEX %d   HP %d%%" % [u.vig, u.endu, u.stren, u.dex, int(u.hp / u.max_hp * 100.0)], 8, C_TEXT)
	_t(Vector2(186, 330), "SKILL: " + u.weapon.skill_name, 8, Color("#bcd6ff"))
	var left := maxf(0.0, 7.0 - battle.possess_t)
	draw_texture_rect(band, Rect2(110, 346, 420, 14), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.8))
	_t(Vector2(320, 356), "CLICK / SPACE: TAKE THIS BODY    TAB / Q: NEXT    (%d)" % int(ceil(left)), 8, C_TEXT, 1)

func _draw_perks() -> void:
	draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.03, 0.015, 0.04, 0.75))
	_tt(Vector2(320, 90), "CHOOSE A LEGACY", C_GOLD, 1, 2)
	_t(Vector2(320, 104), "IT STAYS WITH YOU IN EVERY BODY YOU TAKE", 8, C_DIM, 1)
	for i in perk_choices.size():
		var r := _perk_rect(i)
		var id: String = perk_choices[i]
		var pd: Dictionary = Game.PERKS[id]
		var hov := i == perk_hover
		var lift := -3.0 if hov else 0.0
		r.position.y += lift
		_ornate(r, 0.95)
		if hov:
			draw_rect(r.grow(2.0), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.6 + 0.3 * sin(t * 6.0)), false, 1.0)
		var sid: String = RANK_SEAL[mini(Game.rank, RANK_SEAL.size() - 1)]
		_seal(sid, Vector2(r.get_center().x - 10, r.position.y + 10), 1.0, 0.9)
		_t(Vector2(r.position.x + 8, r.position.y + 16), "%d" % (i + 1), 8, C_DIM)
		var nm: String = pd["name"]
		_tt(Vector2(r.get_center().x, r.position.y + 50), nm, C_GOLD, 1, 1)
		_lines(Vector2(r.get_center().x, r.position.y + 72), pd["desc"], 8, C_TEXT, 1, 11.0)
	_t(Vector2(320, 270), "PRESS 1 / 2 / 3 OR CLICK", 8, C_DIM, 1)

func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.03, 0.015, 0.04, 0.82))
	_ornate(Rect2(90, 22, 460, 322), 0.9)
	_tt(Vector2(320, 50), "PAUSED", C_GOLD, 1, 3)
	var lines := [
		["MOVE", "WASD / LEFT STICK"], ["AIM", "MOUSE / RIGHT STICK"],
		["LIGHT ATTACK", "LMB / RB  - CHAIN FOR COMBOS"], ["HEAVY ATTACK", "RMB / RT  - HOLD TO CHARGE"],
		["DASH", "SPACE / B - INVINCIBLE, ATTACK AFTER = LUNGE"], ["GUARD", "SHIFT / LB - TAP JUST BEFORE A HIT TO PARRY"],
		["GUARD COUNTER", "HEAVY RIGHT AFTER BLOCKING"], ["WEAPON SKILL", "E / LT - COSTS SPIRIT (BLUE BAR)"],
		["CRITICAL", "ATTACK AN ENEMY KNEELING AFTER STANCE BREAK OR PARRY"], ["FLASK", "R / X - HEALS 45%"],
		["PICK UP WEAPON", "F / Y"], ["ORDERS (100-MAN+)", "1 FOLLOW  2 CHARGE TO CURSOR  3 HOLD"],
		["WAR CRY / VOLLEY", "G / V (1000-MAN+)"], ["GLINTS", "WHITE = PARRY OR BLOCK IT.  RED = DODGE IT"],
		["RALLY", "ORANGE HP RETURNS IF YOU HIT BACK FAST"],
	]
	var y := 74.0
	for l in lines:
		_t(Vector2(222, y), l[0], 8, C_GOLD, 2)
		_t(Vector2(232, y), l[1], 8, C_TEXT)
		y += 14.0
	var perks := ""
	for k in Game.perks.keys():
		perks += Game.PERKS[k]["name"] + "   "
	_t(Vector2(320, y + 6), "LEGACY: " + (perks if perks != "" else "NONE YET"), 8, C_DIM, 1)
	_t(Vector2(320, 322), "F2: LOW GRAPHICS %s   (TURNS OFF LIGHTING, BLOOM AND SHADOWS FOR SLOW PCS)" % ("ON" if Game.low_gfx else "OFF"), 8, C_DIM, 1)
	_t(Vector2(320, 334), "ENTER: RESUME     R: RESTART BATTLE     Q: QUIT TO TITLE", 8, C_TEXT, 1)

func _draw_results() -> void:
	var a := clampf(results_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.03, 0.015, 0.04, 0.82 * a))
	var s: Dictionary = Game.stats
	var col := C_GOLD if results_victory else C_RED
	var title := "VICTORY" if results_victory else "DEFEAT"
	draw_texture_rect(band, Rect2(60, 36, 520, 66), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.9 * a))
	_tt(Vector2(320, 84), title, Color(col.r, col.g, col.b, a), 1, 5)
	_t(Vector2(320, 112), "THE GENERAL'S HEAD IS TAKEN. QIN HOLDS THE SNOW PLAINS." if results_victory else "THE ARMY BREAKS AND FLEES INTO THE SNOW.", 8, Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, a), 1)
	var sid: String = RANK_SEAL[Game.rank]
	var k := clampf((results_t - 0.5) / 0.15, 0.0, 1.0)
	if k > 0.0:
		var tx: Texture2D = seals[sid]
		var sz: Vector2 = tx.get_size() * lerpf(4.0, 2.0, k)
		draw_texture_rect(tx, Rect2(Vector2(110, 186) - sz * 0.5, sz), false, Color(1, 1, 1, k))
		_tt(Vector2(110, 238), Game.rank_name(), C_GOLD, 1, 1)
	_ornate(Rect2(220, 128, 330, 140), 0.85 * a)
	var rows := [
		["ENEMIES SLAIN", str(s["kills"])], ["OFFICERS SLAIN", str(s["officers"])],
		["CRITICAL HITS", str(s["crits"])], ["PARRIES", str(s["parries"])],
		["CLOSE CALLS", str(s["dodges"])], ["BODIES USED", str(s["bodies"])],
		["BEST STYLE", Game.STYLE_TIERS[s["best_style"]]["name"]], ["TIME", "%d:%02d" % [int(s["time"]) / 60, int(s["time"]) % 60]],
	]
	var y := 150.0
	for i in rows.size():
		var rk := clampf((results_t - 0.6 - i * 0.08) / 0.2, 0.0, 1.0)
		_t(Vector2(372, y), rows[i][0], 8, Color(C_DIM.r, C_DIM.g, C_DIM.b, rk), 2)
		_t(Vector2(388, y), rows[i][1], 8, Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, rk))
		y += 14.0
	if results_t > 1.2:
		_t(Vector2(320, 304), "ENTER: TITLE SCREEN     R: FIGHT AGAIN", 8, C_TEXT, 1)
