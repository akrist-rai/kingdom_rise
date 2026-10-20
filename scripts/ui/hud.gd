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
var help_t := 9.0
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

var prompt_key := ""        # context prompt, e.g. "F" + "CHALLENGE COMMANDER FU LING"
var prompt_text := ""
var prompt_t := 0.0
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
		seals[RANK_SEAL[i]] = badge_tex(i, Color("#9e1c26"), Color("#e9c46a"), "rank")
	seals["qin"] = badge_tex(0, Color("#9e1c26"), Color("#e9c46a"), "sun")
	seals["zhao"] = badge_tex(0, Color("#25427e"), Color("#e8ecff"), "cross")
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

## A heraldic badge: a heater shield with a metal border; rank chevrons (one per rank, a star
## over four, a crown for the general), or a house device ("sun" for the March, "cross" for
## the Crown). Pixel-drawn, then smoothed with two Scale2x passes like the seals.
static func badge_image(rank: int, field: Color, metal: Color, device: String) -> Image:
	var w := 20
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := (w - 1) * 0.5
	var inside := func(x: int, y: int, inset: float) -> bool:
		var hw := 9.5 - inset
		if y < inset or y > h - 1 - inset * 0.6:
			return false
		if y > 11:
			var k := (y - 11.0) / (h - 11.0 - inset * 0.6)
			hw *= sqrt(maxf(0.0, 1.0 - k * k * k))
		return absf(x - cx) <= hw
	for y in h:
		for x in w:
			if inside.call(x, y, 0.0):
				var c := metal.darkened(0.25)
				if inside.call(x, y, 1.0):
					c = metal
				if inside.call(x, y, 2.0):
					# the field, lit from the upper left
					c = field.lightened(0.12) if x + y < 14 else field
					if x > 12:
						c = field.darkened(0.12)
				img.set_pixel(x, y, c)
	var put := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a > 0.0:
			img.set_pixel(x, y, c)
	match device:
		"rank":
			if rank >= 5:
				# the general's crown
				for x in range(5, 15):
					put.call(x, 11, metal)
					put.call(x, 12, metal)
				for p in [5, 9, 10, 14]:
					for y in range(7, 11):
						put.call(p, y, metal)
				put.call(5, 6, metal)
				put.call(14, 6, metal)
				put.call(9, 5, metal)
				put.call(10, 5, metal)
				for x in range(6, 14):
					put.call(x, 14, metal.darkened(0.2))
			else:
				var n := mini(rank + 1, 4)
				for i in n:
					var y0 := 17 - i * 3
					for d in 6:
						put.call(int(cx) - d, y0 - 5 + d, metal)
						put.call(int(cx) + 1 + d, y0 - 5 + d, metal)
				if rank >= 4:
					for p in [Vector2i(9, 3), Vector2i(10, 3), Vector2i(8, 4), Vector2i(11, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(9, 5), Vector2i(10, 5)]:
						put.call(p.x, p.y, metal)
		"sun":
			for y in h:
				for x in w:
					var d := Vector2(x - cx, y - 10.5).length()
					if d < 3.2 or (d < 6.0 and int(round(atan2(y - 10.5, x - cx) / (PI / 4.0))) % 2 == 0 and d > 4.2):
						put.call(x, y, metal)
		"cross":
			for y in range(4, 20):
				put.call(9, y, metal)
				put.call(10, y, metal)
			for x in range(4, 16):
				put.call(x, 9, metal)
				put.call(x, 10, metal)
	return img

static func badge_tex(rank: int, field: Color, metal: Color, device: String) -> ImageTexture:
	var img := badge_image(rank, field, metal, device)
	var t := ImageTexture.create_from_image(scale2x(scale2x(img)))
	t.set_size_override(Vector2i(img.get_width(), img.get_height()))
	return t

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
func speed_lines(screen_pos: Vector2, dur: float, col: Color = Color(1.0, 0.97, 0.9, 0.35)) -> void:
	var seed := randi()
	lines_fx.append({"p": screen_pos, "t": 0.0, "dur": dur, "seed": seed, "col": col})

## A screen-wide brush stroke along the direction of a critical blow ("one-flash cut").
func ink_slash(screen_pos: Vector2, dir: Vector2) -> void:
	slashes.append({"p": screen_pos, "d": dir.normalized(), "t": 0.0})

## Full-screen character introduction (boss, officers).
func cutin(title: String, sub: String, frames_tex: Texture2D, col: Color, dur: float = 2.4) -> void:
	cut = {"title": title, "sub": sub, "tex": frames_tex, "col": col, "t": 0.0, "dur": dur}

## A context prompt shown near the bottom while it is refreshed every frame.
func prompt(key: String, text: String) -> void:
	prompt_key = key
	prompt_text = text
	prompt_t = 0.15

## The blade-lock tug of war: the marker moves toward whoever is winning.
func _draw_clash() -> void:
	if battle.clash.is_empty():
		return
	var push: float = battle.clash["push"]
	var cx := 320.0
	var y := 250.0
	var w := 200.0
	draw_rect(Rect2(cx - w * 0.5 - 2, y - 2, w + 4, 8), Color(0.02, 0.04, 0.06, 0.8))
	draw_rect(Rect2(cx - w * 0.5, y, w * push, 4), Color("#d8323a"))
	draw_rect(Rect2(cx - w * 0.5 + w * push, y, w * (1.0 - push), 4), Color("#3a5cc8"))
	draw_rect(Rect2(cx - w * 0.5 + w * push - 1.5, y - 4, 3, 12), Color(1.0, 0.95, 0.8))
	var pulse := 0.6 + 0.4 * sin(t * 18.0)
	Game.text(self, Vector2(cx, y - 8), "BLADE LOCK  -  MASH ATTACK", 8, Color(1.0, 0.92, 0.7, pulse), 1, 1)

## The General's Aura announcement: a red-gold banner.
func aura_banner() -> void:
	banner("GENERAL'S AURA", "YOUR PRESENCE SHAKES THE FIELD  -  ALLIES SURGE, ENEMIES FALTER", Color("#ffb347"), true, 2.6, "", true)

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
	var _h0 := Time.get_ticks_usec()
	_process_impl(delta)
	Prof.add("hud.process", Time.get_ticks_usec() - _h0)

func _process_impl(delta: float) -> void:
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	if get_tree().paused:
		rdt = delta
	rdt = minf(rdt, 0.1)
	t += rdt
	results_t += rdt
	flash = maxf(0.0, flash - rdt * 3.0)
	callout_t -= rdt
	prompt_t -= rdt
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
	if battle != null:
		_hud_alpha(rdt)
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
	if not seals.has(id):
		return
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
	var _d0 := Time.get_ticks_usec()
	_draw_impl()
	Prof.add("hud.draw", Time.get_ticks_usec() - _d0)

func _draw_impl() -> void:
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
		if not Game.command_view:
			_draw_markers()
		_draw_alerts()
		_draw_hints()
		_draw_prompt()
		_draw_clash()
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
	if help_on and not results_open:
		_draw_help_panel()
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
			var wdt := rng.randf_range(0.3, 1.2)
			var dir := Vector2.from_angle(a)
			var p0 := c + dir * r0
			var p1 := c + dir * 520.0
			var n := dir.orthogonal() * wdt
			draw_colored_polygon(PackedVector2Array([p0, p1 + n, p1 - n]), Color(col.r, col.g, col.b, col.a * (1.0 - k)))

func _draw_slashes() -> void:
	for sl in slashes:
		var k := float(sl["t"]) / 0.45
		var grow := clampf(float(sl["t"]) / 0.06, 0.0, 1.0)
		var d: Vector2 = sl["d"]
		var c: Vector2 = sl["p"]
		var ln := 900.0 * grow
		var th := 26.0 * (1.0 - k * 0.7)
		draw_set_transform(c - d * 450.0 + d * ln * 0.5, d.angle(), Vector2.ONE)
		draw_texture_rect(band, Rect2(Vector2(-ln * 0.5, -th * 0.25), Vector2(ln, th * 0.5)), false, Color(1.0, 0.86, 0.6, 0.35 * (1.0 - k)))
		draw_rect(Rect2(Vector2(-ln * 0.5, -1.0), Vector2(ln, 2.0)), Color(1.0, 0.55, 0.35, 0.8 * (1.0 - k)))
		draw_rect(Rect2(Vector2(-ln * 0.45, -0.5), Vector2(ln * 0.9, 1.0)), Color(1, 0.95, 0.9, 1.0 - k))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ minimal cinematic HUD
## A hairline bar: soft ink shadow, thin fill, a brighter leading edge.
func _line_bar(x: float, y: float, w: float, frac: float, col: Color, h: float = 2.0, a: float = 1.0, extra: float = 0.0, extra_col: Color = Color.WHITE) -> void:
	var f := clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(x - 1.0, y - 1.0, w + 2.0, h + 2.0), Color(0.01, 0.02, 0.04, 0.5 * a))
	draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.07 * a))
	if extra > 0.0:
		draw_rect(Rect2(x + w * f, y, w * clampf(extra, 0.0, 1.0 - f), h), Color(extra_col.r, extra_col.g, extra_col.b, extra_col.a * a))
	draw_rect(Rect2(x, y, w * f, h), Color(col.r, col.g, col.b, a))
	if f > 0.0 and f < 1.0:
		draw_rect(Rect2(x + w * f - 0.6, y - 0.6, 0.8, h + 1.2), Color(1.0, 0.97, 0.9, 0.8 * a))

func _ta(pos: Vector2, s: String, sz: int, col: Color, a: float, align: int = 0, kind: int = 0) -> void:
	Game.text(self, pos, s, sz, Color(col.r, col.g, col.b, col.a * a), align, kind)

var hud_a := 1.0
var combat_t := 0.0
var vit_a := 0.0
var hp_chip := 1.0
var hp_last := 1.0
var chip_hold := 0.0
var obj_last := ""
var obj_t := 0.0
var xp_last := 0.0
var xp_t := 0.0
var style_a := 0.0
var prompt_a := 0.0

func _objective_text() -> String:
	var lc = battle.level_ctl
	if lc == null:
		return "BREAK THE ENEMY LINE"
	match int(lc.phase):
		1:
			return "BREAK THE GATE"
		2:
			return "TAKE THE WARDS"
	return "REACH THE KEEP"

func _hud_alpha(rdt: float) -> void:
	var p = battle.player
	var fighting := false
	var hurt := false
	if p != null and is_instance_valid(p) and not p.dead:
		hurt = p.hp < p.max_hp * 0.98 or p.stamina < p.max_stamina * 0.98
		if p.state == Unit.St.ATTACK or p.hp < p.max_hp * 0.5 or Game.aura_active() or battle.duel:
			fighting = true
		else:
			for e in battle.query(p.global_position, 150.0):
				if e.faction != p.faction and not e.dead and not e.spectator:
					fighting = true
					break
		var f: float = clampf(p.hp / p.max_hp, 0.0, 1.0)
		if f < hp_last - 0.001:
			chip_hold = 0.5
		hp_last = f
		chip_hold -= rdt
		if f >= hp_chip:
			hp_chip = f
		elif chip_hold <= 0.0:
			hp_chip = move_toward(hp_chip, f, rdt * 0.7)
	if fighting:
		combat_t = 3.0
	combat_t -= rdt
	hud_a = move_toward(hud_a, 1.0 if combat_t > 0.0 else 0.0, rdt * (5.0 if combat_t > 0.0 else 0.7))
	vit_a = move_toward(vit_a, 1.0 if (combat_t > 0.0 or hurt) else 0.22, rdt * (5.0 if combat_t > 0.0 else 0.8))
	var obj := _objective_text()
	if obj != obj_last:
		obj_last = obj
		obj_t = 6.5
	obj_t -= rdt
	if Game.xp != xp_last:
		xp_last = Game.xp
		xp_t = 2.2
	xp_t -= rdt
	style_a = move_toward(style_a, 1.0 if Game.style > 70.0 else 0.0, rdt * 3.0)
	prompt_a = move_toward(prompt_a, 1.0 if prompt_t > 0.0 else 0.0, rdt * 8.0)

## Vitals: slim bars at the lower left. The white chip trails damage; they sink back when calm.
func _draw_player() -> void:
	var p = battle.player
	if p == null or not is_instance_valid(p) or p.dead:
		return
	var a := vit_a
	var x := 22.0
	var y := 336.0
	var w := 132.0
	var f: float = clampf(p.hp / p.max_hp, 0.0, 1.0)
	var low := f < 0.3
	var pulse := (0.5 + 0.5 * sin(t * 9.0)) if low else 0.0
	draw_rect(Rect2(x - 1.5, y - 1.5, w + 3.0, 6.0), Color(0.01, 0.02, 0.04, 0.6 * a))
	draw_rect(Rect2(x, y, w, 3.0), Color(1, 1, 1, 0.06 * a))
	draw_rect(Rect2(x, y, w * clampf(hp_chip, 0.0, 1.0), 3.0), Color(1.0, 0.94, 0.86, 0.85 * a))
	if p.rally > 0.0:
		draw_rect(Rect2(x + w * f, y, w * clampf(p.rally / p.max_hp, 0.0, 1.0 - f), 3.0), Color(1.0, 0.62, 0.25, 0.7 * a))
	var hc := Color("#e5553f").lerp(Color("#ff2a2a"), pulse * 0.6)
	draw_rect(Rect2(x, y, w * f, 3.0), Color(hc.r, hc.g, hc.b, a))
	draw_rect(Rect2(x, y, w * f, 1.0), Color(1.0, 0.75, 0.62, 0.55 * a))
	# stamina (grey-gold) and spirit (five beads)
	var sf: float = clampf(p.stamina / p.max_stamina, 0.0, 1.0)
	var sc := Color("#e8d9a6") if p.stamina > 0.0 else Color("#ff5a4a")
	draw_rect(Rect2(x - 1.0, y + 5.0, w * 0.72 + 2.0, 3.0), Color(0.01, 0.02, 0.04, 0.5 * a))
	draw_rect(Rect2(x, y + 6.0, w * 0.72 * sf, 1.2), Color(sc.r, sc.g, sc.b, 0.9 * a))
	var sp: float = p.spirit / Unit.MAX_SPIRIT
	var ready_skill: bool = p.spirit >= p.weapon.skill_cost
	for i in 5:
		var c := Vector2(x + 2.0 + i * 6.0, y - 6.0)
		var fill := clampf(sp * 5.0 - i, 0.0, 1.0)
		var dia := PackedVector2Array([c + Vector2(0, -2), c + Vector2(2, 0), c + Vector2(0, 2), c + Vector2(-2, 0)])
		draw_colored_polygon(dia, Color(0.02, 0.03, 0.05, 0.6 * a))
		if fill > 0.05:
			var dc := Color("#9fd8ff") if not ready_skill else Color("#fff1b8")
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1.4 * fill), c + Vector2(1.4 * fill, 0), c + Vector2(0, 1.4 * fill), c + Vector2(-1.4 * fill, 0)]), Color(dc.r, dc.g, dc.b, a))
	# flasks
	for i in p.max_flasks:
		var c := Vector2(x + w + 8.0 + i * 6.0, y + 1.5)
		draw_circle(c, 2.0, Color(0.02, 0.03, 0.05, 0.6 * a))
		draw_circle(c, 1.3, Color("#ff8a5c") if i < p.flasks else Color(0.4, 0.38, 0.36, 0.5), true)
	if Game.aura_ready():
		_ta(Vector2(x + 36.0, y - 3.0), "X  AURA", 5, C_GOLD, 0.6 + 0.4 * sin(t * 5.0))
	elif Game.aura_active():
		_line_bar(x, y + 10.0, w, Game.aura_t / Game.AURA_DUR, C_GOLD, 1.0, a)
	# weapon and skill, lower right
	var wa := maxf(vit_a, 0.3)
	_ta(Vector2(618, 340), p.weapon.display_name(), 6, C_TEXT, wa * 0.85, 2)
	var sk_col := Color("#fff1b8") if ready_skill else C_DIM
	_ta(Vector2(618, 349), "E  " + p.weapon.skill_name, 5, sk_col, wa * (1.0 if ready_skill else 0.6), 2)
	if p.weapon.clip > 0:
		_ta(Vector2(618, 331), "RELOADING" if p.reload_t > 0 else "%d / %d" % [p.ammo, p.weapon.clip], 5, C_DIM, wa, 2)

## Rank progress as a hairline along the top edge (lit when you earn XP); the style rank
## appears at the right only while you are fighting with style.
func _draw_rank_style() -> void:
	var xa := clampf(xp_t, 0.0, 1.0)
	if xa > 0.0 or Game.command_view:
		var aa := maxf(xa, 0.5 if Game.command_view else 0.0)
		draw_rect(Rect2(0, 0, 640, 1.0), Color(0, 0, 0, 0.35 * aa))
		draw_rect(Rect2(0, 0, 640 * Game.rank_progress(), 1.0), Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.9 * aa))
		_ta(Vector2(320, 12), Game.rank_name(), 5, C_GOLD, aa * 0.9, 1, 1)
	if style_a > 0.01:
		var td: Dictionary = Game.STYLE_TIERS[Game.style_tier()]
		var col: Color = td["col"]
		var x := 616.0
		var y := 128.0
		_ta(Vector2(x, y), td["n"], 16, col, style_a, 2, 1)
		_ta(Vector2(x, y + 12.0), td["name"], 5, C_TEXT, style_a * 0.85, 2)
		_line_bar(x - 54.0, y + 16.0, 54.0, Game.style_frac(), col, 1.0, style_a)
		if Game.chain_hits >= 3:
			var s := 1.0 + chain_pop * 0.25
			_ta(Vector2(x, y + 30.0), "%d HITS" % Game.chain_hits, int(6 * s), C_TEXT, style_a, 2)

## The objective, when it changes (or in command view): a quiet line at the top with the
## balance of the two armies under it.
func _draw_battle_bar() -> void:
	var a := clampf(obj_t / 0.8, 0.0, 1.0) * clampf(obj_t, 0.0, 1.0)
	if Game.command_view:
		a = 1.0
	if a <= 0.01:
		return
	var y := 26.0
	var obj := obj_last
	var w := Game.text_w(obj, 7, 1)
	_rule_pair(Vector2(320, y - 4.0), w * 0.5 + 10.0, 40.0, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.6 * a))
	_ta(Vector2(320, y), obj, 7, C_TEXT, a, 1, 1)
	var al: float = battle.army_strength(0)
	var en: float = battle.army_strength(1)
	var frac := al / maxf(1.0, al + en)
	var bw := 150.0
	var bx := 320.0 - bw * 0.5
	draw_rect(Rect2(bx, y + 7.0, bw, 1.5), Color(Color("#3f78a3"), 0.85 * a))
	draw_rect(Rect2(bx, y + 7.0, bw * frac, 1.5), Color(Color("#d9573f"), 0.95 * a))
	draw_rect(Rect2(bx + bw * frac - 0.5, y + 5.0, 1.0, 5.5), Color(1, 1, 1, 0.9 * a))
	if battle.tactics != null and Game.command_view:
		for i in battle.tactics.objectives.size():
			var ob = battle.tactics.objectives[i]
			var c := Vector2(303 + i * 17, y + 19.0)
			var col := Color("#e2b878") if ob["owner"] == 0 else Color("#73aaae") if ob["owner"] == 1 else Color(0.9, 0.86, 0.69, 0.45)
			draw_polyline(PackedVector2Array([c + Vector2(0, -2.5), c + Vector2(2.5, 0), c + Vector2(0, 2.5), c + Vector2(-2.5, 0), c + Vector2(0, -2.5)]), col, 1.0, true)
		_ta(Vector2(620, 20), "MORALE %d" % int(battle.morale[0]), 5, C_DIM, 0.9, 2)

func _draw_boss() -> void:
	var b = battle.duel_foe if (battle.duel and battle.duel_foe != null and is_instance_valid(battle.duel_foe)) else battle.boss
	if b == null or not is_instance_valid(b) or b.dead:
		return
	var y := 330.0
	var w := 260.0
	var x := 320.0 - w * 0.5
	var title := "WARDEN OF VEYRE" if b.is_boss else "CROWN COMMANDER"
	_ta(Vector2(320, y - 6.0), b.uname, 8, Color("#f3e6ff"), 1.0, 1, 1)
	_ta(Vector2(320, y + 14.0), title, 4, C_DIM, 0.9, 1)
	_line_bar(x, y, w, b.hp / b.max_hp, Color("#c4313c"), 2.5)
	_line_bar(x + 50.0, y + 5.0, w - 100.0, b.stance / b.max_stance, Color("#ffd23f"), 1.0)
	if b.is_boss:
		for i in 2:
			var px := x + w * (0.6 if i == 0 else 0.3)
			draw_rect(Rect2(px, y - 2, 0.8, 6.5), Color(1, 0.9, 0.7, 0.7))

func _draw_command() -> void:
	var d = battle.tactics
	if d == null or battle.duel or not Game.command_view:
		return
	var col := C_GOLD
	var label := "%d / %s / %s" % [battle.squad.size(), d.FORMS[d.formation], str(battle.squad_order).to_upper()]
	_ta(Vector2(320, 337), label, 5, col, 0.95, 1)
	draw_style_box(_minimal_plate(Color(0.06, 0.1, 0.12, 0.9)), Rect2(182, 267, 276, 56))
	for i in 3:
		var c := Vector2(226 + i * 94, 287)
		var color := C_GOLD if i == d.formation else C_DIM
		if i == d.formation:
			draw_line(c + Vector2(-34, 31), c + Vector2(34, 31), C_GOLD, 1.0)
		for j in 9:
			var pt := Vector2.ZERO
			if i == 0:
				pt = Vector2((j % 5 - 2) * 6, (j / 5) * 7 - 5)
			elif i == 1:
				pt = Vector2((j % 2 * 2 - 1) * ceilf(j / 2.0) * 4, ceilf(j / 2.0) * 4 - 8)
			else:
				pt = Vector2((j % 3 - 1) * 6, (j / 3 - 1) * 6)
			draw_circle(c + pt, 1.4, color)
		_ta(c + Vector2(0, 21), str(4 + i) + " / " + d.FORMS[i], 5, color, 1.0, 1)
	_ta(Vector2(320, 253), "COMMAND  /  TIME SLOWED", 7, C_GOLD, 1.0, 1, 1)
	_ta(Vector2(320, 263), ["FRONTAL PROTECTION", "ADVANCE ATTACK BONUS", "STRONG FRONTAL DEFENCE"][d.formation], 4, C_TEXT, 0.9, 1)
	_ta(Vector2(320, 52), "RIGHT CLICK  PLACE FORMATION     WASD  PAN     1 / 2 / 3  ORDERS     TAB  RETURN", 5, C_TEXT, 1.0, 1)
	_draw_tactical_map()

func _draw_markers() -> void:
	var cam = battle.cam
	var targets: Array = []
	for o in battle.officers_alive:
		if is_instance_valid(o) and not o.dead:
			targets.append([o, Color("#ff9a3d"), "OFFICER"])
	if battle.boss != null and is_instance_valid(battle.boss) and not battle.boss.dead:
		targets.append([battle.boss, Color("#ff3d5a"), "GENERAL"])
	if battle.level_ctl != null:
		targets.append_array(battle.level_ctl.markers())
	for tg in targets:
		var wp: Vector2 = tg[0] if tg[0] is Vector2 else tg[0].global_position
		var sp: Vector2 = cam.world_to_screen(wp)
		var inner := Rect2(Vector2(24, 40), Game.VIEW - Vector2(48, 96))
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
		var pulse := 0.75 + 0.25 * sin(t * 4.0)
		var n := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([ep + dir * 5.0, ep + n * 2.6 - dir * 1.0, ep - n * 2.6 - dir * 1.0]), Color(col.r, col.g, col.b, 0.8 * pulse))
		var dist := int(wp.distance_to(cam.get_screen_center_position()) / 10.0)
		var lp := ep - dir * 11.0 + Vector2(0, 2)
		lp.x = clampf(lp.x, 44.0, 596.0)
		_ta(lp, "%s  %d" % [tg[2], dist], 4, col, 0.75, 1)

func _draw_alerts() -> void:
	if alerts.is_empty() or Game.command_view:
		return
	var al = alerts[-1]
	var a := clampf(3.2 - float(al["t"]), 0.0, 1.0) * clampf(float(al["t"]) / 0.15, 0.0, 1.0)
	var text := str(al["s"])
	var size := 5
	while Game.text_w(text, size) > 420 and size > 3:
		size -= 1
	var w := Game.text_w(text, size) + 30.0
	_soft_band_w(316.0, w, 11.0, 0.45 * a)
	var col: Color = al["col"]
	_ta(Vector2(320, 319), text, size, col.lerp(C_TEXT, 0.35), a, 1)

func _soft_band_w(cy: float, w: float, h: float, a: float) -> void:
	var c0 := Color(0.01, 0.02, 0.04, 0.0)
	var c1 := Color(0.01, 0.02, 0.04, a)
	var x0 := 320.0 - w * 0.5
	var x1 := 320.0 + w * 0.5
	draw_polygon(PackedVector2Array([Vector2(x0 - 30, cy - h * 0.5), Vector2(x0, cy - h * 0.5), Vector2(x1, cy - h * 0.5), Vector2(x1 + 30, cy - h * 0.5),
		Vector2(x1 + 30, cy + h * 0.5), Vector2(x1, cy + h * 0.5), Vector2(x0, cy + h * 0.5), Vector2(x0 - 30, cy + h * 0.5)]),
		PackedColorArray([c0, c1, c1, c0, c0, c1, c1, c0]))

func _rule_pair(c: Vector2, gap: float, len: float, col: Color) -> void:
	draw_rect(Rect2(c.x - gap - len, c.y, len, 0.6), col)
	draw_rect(Rect2(c.x + gap, c.y, len, 0.6), col)
	draw_rect(Rect2(c.x - gap - 1.5, c.y - 0.8, 1.5, 2.2), col)
	draw_rect(Rect2(c.x + gap, c.y - 0.8, 1.5, 2.2), col)

## A soft, horizontal ink band (dark in the middle, fading at both ends and edges).
func _soft_band(cy: float, h: float, a: float) -> void:
	var c0 := Color(0.01, 0.03, 0.05, 0.0)
	var c1 := Color(0.01, 0.03, 0.05, a)
	for half: float in [-1.0, 1.0]:
		var y0 := cy
		var y1: float = cy + half * h * 0.5
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(320, y0), Vector2(640, y0), Vector2(640, y1), Vector2(320, y1), Vector2(0, y1)]),
			PackedColorArray([c0, c1, c0, c0, c0, c0]))

func _draw_hints() -> void:
	if help_on or Game.command_view or help_t <= 0.0:
		return
	var a := clampf(help_t, 0.0, 1.0) * clampf((9.0 - help_t) / 1.0, 0.0, 1.0) * 0.75
	_ta(Vector2(320, 300), "WASD  MOVE      CLICK  ATTACK      RIGHT CLICK  HEAVY      SPACE  DASH      SHIFT  GUARD      H  CONTROLS", 4, C_TEXT, a, 1)

## Context prompt (pick up, mount, challenge) floating over your soldier.
func _draw_prompt() -> void:
	if prompt_a <= 0.01 or battle.possess or battle.player == null or not is_instance_valid(battle.player):
		return
	var sp: Vector2 = _to_screen(battle.player.global_position + Vector2(0, -44))
	var a := prompt_a
	var w := Game.text_w(prompt_text, 5) + 18.0
	var x := sp.x - w * 0.5
	var y := sp.y - 6.0
	draw_rect(Rect2(x, y - 6, w, 10), Color(0.02, 0.03, 0.05, 0.6 * a))
	draw_rect(Rect2(x + 2, y - 5, 9, 8), Color(0.96, 0.9, 0.78, a))
	Game.text(self, Vector2(x + 6.5, y + 1.5), prompt_key, 5, Color(0.05, 0.06, 0.08, a), 1, 0, false)
	_ta(Vector2(x + 14, y + 1.5), prompt_text, 5, C_TEXT, a)

func _draw_help_panel() -> void:
	draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.02, 0.04, 0.06, 0.8))
	_ta(Vector2(320, 46), "FIELD MANUAL", 12, C_GOLD, 1.0, 1, 1)
	_rule_pair(Vector2(320, 54), 70.0, 60.0, Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.6))
	var rows = [
		["WASD", "Move  /  pan the camera in command view"],
		["LEFT / RIGHT MOUSE", "Light attack  /  heavy attack (hold to charge)"],
		["LIGHT, LIGHT, HEAVY", "Weapon finisher"],
		["SPACE", "Dash (invincible for an instant)"],
		["SHIFT", "Guard  /  tap just before a blow lands to parry"],
		["E  /  R", "Weapon skill (spends spirit)  /  drink a flask"],
		["F  /  C  /  T", "Interact, mount or duel  /  kick  /  throw your weapon"],
		["X  /  G  /  V", "General's aura  /  war cry  /  arrow volley (rank unlocks)"],
		["TAB", "Command view: time slows, right click places your formation"],
		["1 / 2 / 3", "Follow  /  advance to cursor  /  hold position"],
		["Q  /  4 / 5 / 6", "Cycle formation  /  line, wedge, square"],
		["SCROLL  /  F6", "Combat zoom  /  army density"],
		["BACKSPACE", "Choose another soldier after you fall (Enter takes him)"],
		["ESC  /  F2  /  F11", "Pause  /  low graphics  /  fullscreen"]]
	for i in rows.size():
		var y := 80 + i * 17
		_ta(Vector2(300, y), rows[i][0], 5, C_GOLD, 1.0, 2)
		Game.text(self, Vector2(316, y), rows[i][1], 5, C_TEXT, 0, 2, false)
	_ta(Vector2(320, 334), "H  CLOSE", 5, C_DIM, 1.0, 1)

## Title cards: Cinzel caps between two hairlines, easing in and drifting up.
func _draw_banner() -> void:
	if banners.is_empty() or Game.command_view:
		return
	var b = banners[0]
	var bt := float(b["t"])
	var dur := float(b["dur"])
	var a := clampf(bt / 0.5, 0.0, 1.0) * clampf((dur - bt) / 0.7, 0.0, 1.0)
	var title := str(b["title"])
	var big: bool = b["big"]
	var sz := 15 if big else 10
	while Game.text_w(title, sz, 1) > 540 and sz > 6:
		sz -= 1
	var rise := (1.0 - clampf(bt / 0.6, 0.0, 1.0)) * 6.0
	var y := 92.0 + rise
	var tw := Game.text_w(title, sz, 1)
	if big:
		_soft_band(y - 5.0, 46.0, 0.35 * a)
	var col: Color = b["col"]
	_rule_pair(Vector2(320, y - Game.text_size(sz, 1) * 0.42), tw * 0.5 + 14.0, 46.0 * a, Color(col.r, col.g, col.b, 0.7 * a))
	Game.text(self, Vector2(320, y), title, sz, Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, a), 1, 1)
	if str(b["sub"]) != "":
		_ta(Vector2(320, y + 13.0), str(b["sub"]), 4 if big else 4, col.lerp(C_TEXT, 0.5), a * 0.9, 1)

func _draw_stamp() -> void:
	if stamp.is_empty():
		return
	# the new rank's badge drops in over the promotion banner (which carries the words)
	var st: float = stamp["t"]
	var a := clampf(st / 0.12, 0.0, 1.0) * clampf((float(stamp["dur"]) - st) / 0.5, 0.0, 1.0)
	var tx: Texture2D = seals.get(stamp["id"])
	if tx == null:
		return
	var k := clampf(st / 0.22, 0.0, 1.0)
	var sc := lerpf(3.4, 1.6, 1.0 - (1.0 - k) * (1.0 - k)) + sin(minf(st, 0.5) * TAU * 2.0) * 0.08 * (1.0 - k)
	var sz := tx.get_size() * sc
	var c := Vector2(320, 150)
	draw_texture_rect(tx, Rect2(c - sz * 0.5 + Vector2(1.5, 2.0), sz), false, Color(0, 0, 0, 0.45 * a))
	draw_texture_rect(tx, Rect2(c - sz * 0.5, sz), false, Color(1, 1, 1, a))
	# a glint sweeping across once it lands
	var g := clampf((st - 0.3) / 0.35, 0.0, 1.0)
	if g > 0.0 and g < 1.0:
		var gx := c.x - sz.x * 0.5 + sz.x * g
		draw_line(Vector2(gx - 3.0, c.y - sz.y * 0.45), Vector2(gx + 3.0, c.y + sz.y * 0.45), Color(1.0, 0.97, 0.85, 0.7 * a * sin(g * PI)), 1.6)

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
	draw_colored_polygon(pts, Color(0.04, 0.08, 0.11, 0.94 * a))
	draw_rect(Rect2(0, y0 + 2, 640, 1), Color(col.r, col.g, col.b, 0.5 * a))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var yy := rng.randf_range(y0, y1)
		var ln := rng.randf_range(80, 300)
		var xx := fmod(rng.randf() * 900.0 + ct * 900.0 * rng.randf_range(0.6, 1.4), 900.0) - 150.0
		draw_rect(Rect2(xx, yy, ln, 1), Color(col.r, col.g * 0.6, col.b * 0.6, 0.35 * a))
	var sun := Vector2(450, 182)
	draw_circle(sun, 64.0, Color(0.95, 0.62, 0.5, 0.35 * a))
	draw_circle(sun, 48.0, Color(col.r, col.g * 0.45, col.b * 0.4, 0.7 * a))
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
	return battle.cam.world_to_screen(p)

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
	_t(Vector2(320, 356), "CLICK / SPACE: TAKE THIS BODY    BACKSPACE: NEXT    (%d)" % int(ceil(left)), 8, C_TEXT, 1)

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
		# long names step down a size so they stay inside the card
		var fsz := 9
		while Game.text_w(nm, fsz, 1) > r.size.x - 14.0 and fsz > 5:
			fsz -= 1
		Game.text(self, Vector2(r.get_center().x, r.position.y + 50), nm, fsz, C_GOLD, 1, 1)
		_lines(Vector2(r.get_center().x, r.position.y + 72), pd["desc"], 8, C_TEXT, 1, 11.0)
	_t(Vector2(320, 270), "PRESS 1 / 2 / 3 OR CLICK", 8, C_DIM, 1)

func _draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO,Game.VIEW),Color(0.05,0.12,0.12,0.85))
	draw_style_box(_minimal_plate(Color(0.08,0.16,0.16,0.97)),Rect2(157,83,326,195))
	_ta(Vector2(320,112),"THE FIELD IS STILL",12,C_TEXT,1.0,1)
	_ta(Vector2(320,131),"PAUSED",5,C_DIM,1.0,1)
	var rows=[["ENTER / ESC","RESUME"],["R","RESTART BATTLE"],["BACKSPACE","CAMPAIGN ATLAS"],["H","FIELD MANUAL"],["F2","LOW GRAPHICS: "+("ON" if Game.low_gfx else "OFF")],["F6","CHANGE ARMY DENSITY"]]
	for i in rows.size():
		_ta(Vector2(179,157+i*17),rows[i][0],5,C_GOLD,1.0)
		_ta(Vector2(460,157+i*17),rows[i][1],5,C_TEXT,1.0,2)

func _draw_results() -> void:
	var a := clampf(results_t / 0.6, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.03, 0.015, 0.04, 0.82 * a))
	var s: Dictionary = Game.stats
	var col := C_GOLD if results_victory else C_RED
	var title := "VICTORY" if results_victory else "DEFEAT"
	draw_texture_rect(band, Rect2(60, 36, 520, 66), false, Color(C_INK.r, C_INK.g, C_INK.b, 0.9 * a))
	_tt(Vector2(320, 84), title, Color(col.r, col.g, col.b, a), 1, 5)
	var siege: bool = battle.level == "siege"
	var line := ""
	if results_victory:
		line = "THE GENERAL'S HEAD IS TAKEN. VEYRE FALLS TO THE MARCH." if siege else "THE GENERAL'S HEAD IS TAKEN. THE MARCH HOLDS THE SNOW PLAINS."
	else:
		line = "THE ASSAULT BREAKS AGAINST THE WALLS OF HANDAN." if siege else "THE ARMY BREAKS AND FLEES INTO THE SNOW."
	_t(Vector2(320, 112), line, 8, Color(C_TEXT.r, C_TEXT.g, C_TEXT.b, a), 1)
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

func _minimal_plate(color: Color) -> StyleBoxFlat:
	var st=StyleBoxFlat.new()
	st.bg_color=color
	st.set_corner_radius_all(3)
	return st

func _draw_tactical_map() -> void:
	var r=Rect2(16,76,142,181)
	draw_style_box(_minimal_plate(Color(0.08,0.16,0.16,0.92)),r)
	_ta(Vector2(27,90),"VEYRE / BATTLE ATLAS",5,C_GOLD,1.0)
	var area=Rect2(24,98,126,142)
	draw_rect(area,Color("#777f60"))
	var k=Vector2(area.size.x/Battle.W,area.size.y/(Battle.BOT-Battle.TOP))
	if battle.level_ctl!=null:
		for block in SiegeLevel.BLOCKS + [SiegeLevel.HALL]:
			var p = area.position + Vector2(block.position.x,block.position.y-Battle.TOP)*k
			draw_rect(Rect2(p,block.size*k),Color("#3e5551"))
		var canal = SiegeLevel.CANAL
		draw_rect(Rect2(area.position+Vector2(canal.position.x,canal.position.y-Battle.TOP)*k,canal.size*k),Color("#507777"))
		for y in [SiegeLevel.GROUND_Y,SiegeLevel.INNER_Y,SiegeLevel.TERRACE_Y0]:
			var sy=area.position.y+(y-Battle.TOP)*k.y
			draw_line(Vector2(area.position.x,sy),Vector2(area.end.x,sy),Color("#d6c79b"),1.4)
		draw_line(area.position+Vector2(63,0),area.position+Vector2(63,area.size.y),Color("#bcb48a"),3)
	for u in battle.units:
		var q=area.position+Vector2(u.position.x,u.position.y-Battle.TOP)*k
		if area.has_point(q):
			draw_circle(q,0.65,Color("#eeaf73") if u.faction==0 else Color("#9ec8c6"))
	if battle.player!=null:
		var q=area.position+Vector2(battle.player.position.x,battle.player.position.y-Battle.TOP)*k
		draw_arc(q,3.5,0,TAU,12,C_TEXT,0.8,true)
	var camera_rect=Rect2(battle.cam.get_screen_center_position()-Game.VIEW*0.5/battle.cam.cur_zoom,Game.VIEW/battle.cam.cur_zoom)
	var rp=area.position+Vector2(camera_rect.position.x,camera_rect.position.y-Battle.TOP)*k
	draw_rect(Rect2(rp,camera_rect.size*k).intersection(area),Color(C_TEXT,0.6),false,0.6)
	_ta(Vector2(27,249),"%d ALLIES   /   %d ENEMIES" % battle.alive,4,C_TEXT,0.85)
