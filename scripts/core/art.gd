extends Node
## Art factory for the "painted poster" style. Every sprite is drawn as vector shapes
## (flat colours, cel shading, ink outlines) by the functions below, rendered once at
## startup into atlas pages at K times the world resolution, then sliced into textures
## whose reported size is the world size (so gameplay code is unaffected).

signal built

const K := 4.0
const OUT := Painter.INK
const INK := Painter.INK

const SKIN := [Color("#f6c39a"), Color("#d98b63"), Color("#9e5844")]
const HAIR := Color("#1d1420")
const PANTS := [Color("#3d3550"), Color("#272036")]
const BOOT := [Color("#3a2a2a"), Color("#1f1618")]
const LEATHER := [Color("#8a5a3a"), Color("#5e3a26")]
const WOOD := [Color("#c08453"), Color("#8a5733"), Color("#55331f")]
const STEEL := [Color("#f4f6ff"), Color("#b9c2dc"), Color("#6f7899")]
const GOLD := [Color("#ffe07a"), Color("#e2a234"), Color("#99601c")]
const SNOW := [Color("#fbf3e4"), Color("#e2d6ea"), Color("#a9a8d8")]

const PAL := {
	"qin": {
		"cloth": [Color("#e18357"), Color("#b5523d"), Color("#6b3734")],
		"armor": [Color("#b9b59a"), Color("#6e7d72"), Color("#3a514f")],
		"helm": [Color("#d3cfb2"), Color("#8b9a8c"), Color("#405e5c")],
		"trim": Color("#f6c34e"),
		"horse": [Color("#b37a50"), Color("#7e5236"), Color("#4a2e1f")],
		"mane": Color("#25171a"),
	},
	"zhao": {
		"cloth": [Color("#65a0a3"), Color("#376e78"), Color("#284b59")],
		"armor": [Color("#bdc9bb"), Color("#7c9a9b"), Color("#3c646e")],
		"helm": [Color("#b5c9be"), Color("#6c9799"), Color("#355c67")],
		"trim": Color("#f2f4ff"),
		"horse": [Color("#a4a2b4"), Color("#6c6a80"), Color("#3c3a4c")],
		"mane": Color("#1b1a26"),
	},
	"general": {
		"cloth": [Color("#b071f0"), Color("#7136c0"), Color("#3a1668")],
		"armor": [Color("#4a4260"), Color("#2b253d"), Color("#15111f")],
		"helm": [Color("#5a5274"), Color("#363050"), Color("#1a1626")],
		"trim": Color("#f6d27e"),
		"horse": [Color("#4a4658"), Color("#2c2a38"), Color("#17161e")],
		"mane": Color("#0e0d12"),
	},
}

const KINDS := {
	"infantry": {"helm": 0, "cape": 0, "heavy": false},
	"spear": {"helm": 1, "cape": 0, "heavy": false},
	"archer": {"helm": 4, "cape": 0, "heavy": false, "quiver": true},
	"heavy": {"helm": 5, "cape": 1, "heavy": true},
	"cavalry": {"helm": 1, "cape": 1, "heavy": false},
	"officer": {"helm": 3, "cape": 2, "heavy": false},
	"guard": {"helm": 5, "cape": 1, "heavy": true},
	"general": {"helm": 6, "cape": 2, "heavy": true, "fur": true},
}

var tex := {}            # misc textures by name
var units := {}          # "<faction>_<kind>" -> {walk:[], idle:[], hurt, broken, dead}
var weapons := {}        # weapon tex key -> {tex, pivot:Vector2, len:float}
var crowd := {}          # faction -> [textures]
var crowd_torch := {}    # faction -> torch-bearer texture
var ready_done := false
var gallery := false

var _jobs: Array = []
var _results := {}

func _ready() -> void:
	_build()

func _build() -> void:
	var t0 := Time.get_ticks_msec()
	_build_fx_images()
	_jobs.clear()
	# the soldiers, horses and crowds are baked sprite sheets now (UnitArt); the old vector
	# versions are only drawn for the debug gallery
	gallery = OS.get_cmdline_user_args().has("--gallery")
	if gallery:
		_queue_units()
		_queue_horses()
		_queue_crowd()
	ArtProps.queue_weapons(self)
	ArtProps.queue_props(self)
	# large portraits for the anime cut-ins (reported at unit size, drawn magnified)
	for pk in [["zhao_general", PAL["general"], KINDS["general"]], ["zhao_officer", PAL["zhao"], KINDS["officer"]]]:
		job("portrait_" + pk[0], Vector2(100, 120), _portrait.bind(pk[1], pk[2]), 1.4)
	job("hand", Vector2(3, 3), func(p: Painter): p.shape(Painter.circle(Vector2(1.5, 1.5), 1.05, 10), SKIN[0], SKIN[1]), 0.3)
	await _render_jobs()
	_assemble()
	ready_done = true
	print("[Art] built %d vector sprites in %d ms" % [_results.size(), Time.get_ticks_msec() - t0])
	built.emit()

## Queue a drawing: `fn(p: Painter)` draws inside a box of `size` world units.
## `outline` is the width (world units) of the bold ink silhouette added around the
## finished drawing on the GPU; 0 for things that should stay soft (flames).
func job(key: String, size: Vector2, fn: Callable, outline: float = 0.55) -> void:
	_jobs.append({"key": key, "size": size, "fn": fn, "outline": outline})

func result(key: String) -> Texture2D:
	return _results[key]

# ------------------------------------------------------------------ soft FX images
## Gradients and tiny particles are generated per pixel (at 4x for the sharp ones) rather
## than drawn as vectors.
func _soft(n: int, fn: Callable, world: Vector2i = Vector2i.ZERO) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			img.set_pixel(x, y, fn.call(d))
	var t := ImageTexture.create_from_image(img)
	if world != Vector2i.ZERO:
		t.set_size_override(world)
	return t

func _ellipse_tex(w: int, h: int, c: Color, s: int = 4) -> ImageTexture:
	var img := Image.create(w * s, h * s, false, Image.FORMAT_RGBA8)
	var rx := w * s * 0.5 - s * 0.4
	var ry := h * s * 0.5 - s * 0.4
	for y in h * s:
		for x in w * s:
			var q := Vector2((x + 0.5 - w * s * 0.5) / rx, (y + 0.5 - h * s * 0.5) / ry)
			var e := q.length()
			var a := clampf((1.0 - e) * rx / 1.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(w, h))
	return t

func _build_fx_images() -> void:
	tex["glow"] = _soft(64, func(d): return Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 2.0)), Vector2i(32, 32))
	tex["light"] = _soft(64, func(d):
		var a := pow(clampf(1.0 - d * d, 0.0, 1.0), 2.0)
		return Color(a, a, a, 1.0))
	tex["blob"] = _soft(32, func(d): return Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.5)), Vector2i(16, 16))
	tex["flake"] = _soft(20, func(d): return Color(1, 1, 1, clampf((1.0 - d) * 2.5, 0.0, 1.0)), Vector2i(5, 5))
	tex["ember"] = _soft(8, func(d): return Color(1, 1, 1, clampf((1.0 - d) * 3.0, 0.0, 1.0)), Vector2i(2, 2))
	var px := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	px.set_pixel(0, 0, Color.WHITE)
	tex["px"] = ImageTexture.create_from_image(px)
	# Flat navy contact shadows (the poster style uses solid shadow shapes, not soft blur).
	tex["shadow"] = _ellipse_tex(14, 5, Color(0.07, 0.07, 0.2, 0.5))
	tex["shadow_big"] = _ellipse_tex(26, 7, Color(0.07, 0.07, 0.2, 0.5))
	# Four-point star glint.
	var g := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var q := Vector2(x + 0.5 - 14.0, y + 0.5 - 14.0) / 14.0
			var star := 1.0 - (sqrt(absf(q.x)) + sqrt(absf(q.y)))
			var core := 1.0 - q.length() * 2.6
			g.set_pixel(x, y, Color(1, 1, 1, clampf(maxf(star * 3.0, core), 0.0, 1.0)))
	tex["glint"] = ImageTexture.create_from_image(g)
	tex["glint"].set_size_override(Vector2i(7, 7))
	# Pickup ring: a thin glowing ellipse.
	var r := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var q := Vector2((x + 0.5 - 32.0) / 28.0, (y + 0.5 - 16.0) / 12.0)
			var a := clampf(1.0 - absf(q.length() - 1.0) * 9.0, 0.0, 1.0)
			r.set_pixel(x, y, Color(1, 0.92, 0.55, a))
	tex["ring"] = ImageTexture.create_from_image(r)
	tex["ring"].set_size_override(Vector2i(16, 8))

# ------------------------------------------------------------------ atlas rendering
const OUTLINE_SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha;
uniform float radius = 1.6;
uniform vec4 ink : source_color = vec4(0.04, 0.08, 0.11, 1.0);
uniform vec4 rim_col : source_color = vec4(1.0, 0.86, 0.74, 1.0);
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float m = 0.0;
	for (int i = 0; i < 16; i++) {
		float a = float(i) * 0.3927;
		vec2 d = vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE;
		m = max(m, texture(TEXTURE, UV + d * radius).a);
		m = max(m, texture(TEXTURE, UV + d * radius * 0.5).a);
	}
	// rim light: the top edge of the shape catches the low sky light behind the armies
	vec2 px = TEXTURE_PIXEL_SIZE * max(radius * 0.7, 1.0);
	float above = min(texture(TEXTURE, UV + vec2(0.0, -px.y)).a, texture(TEXTURE, UV + vec2(-px.x * 0.7, -px.y * 0.7)).a);
	float rim = smoothstep(0.6, 0.9, src.a) * (1.0 - smoothstep(0.2, 0.6, above));
	vec3 col = mix(src.rgb, rim_col.rgb * src.a, rim * 0.8);
	float o = smoothstep(0.1, 0.55, m) * ink.a;
	COLOR = vec4(col + ink.rgb * o * (1.0 - src.a), src.a + o * (1.0 - src.a));
}
"""

func _render_jobs() -> void:
	var page_w := 2048
	var page_h := 2048
	var pad := 4
	# Group by outline width (each page gets one outline radius), tallest first.
	var groups := {}
	for j in _jobs:
		var ow: float = j["outline"]
		if not groups.has(ow):
			groups[ow] = []
		groups[ow].append(j)
	var pages: Array = []
	for ow in groups.keys():
		var order: Array = groups[ow]
		order.sort_custom(func(a, b): return a["size"].y > b["size"].y)
		var cur: Array = []
		var x := 0
		var y := 0
		var row_h := 0
		for j in order:
			var w := int(ceil(j["size"].x * K)) + pad * 2
			var h := int(ceil(j["size"].y * K)) + pad * 2
			if x + w > page_w:
				x = 0
				y += row_h
				row_h = 0
			if y + h > page_h:
				pages.append({"items": cur, "h": y + row_h, "outline": ow})
				cur = []
				x = 0
				y = 0
				row_h = 0
			cur.append({"job": j, "pos": Vector2i(x + pad, y + pad)})
			x += w
			row_h = maxi(row_h, h)
		pages.append({"items": cur, "h": y + row_h, "outline": ow})
	var outline_shader := Shader.new()
	outline_shader.code = OUTLINE_SHADER
	var vps: Array = []
	for pg in pages:
		var size := Vector2i(page_w, maxi(16, int(pg["h"])))
		var vp := SubViewport.new()
		vp.size = size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		var node := Node2D.new()
		var items: Array = pg["items"]
		node.draw.connect(func():
			var pt := Painter.new(node)
			for it in items:
				node.draw_set_transform(Vector2(it["pos"]), 0.0, Vector2(K, K))
				pt.xf = Transform2D.IDENTITY
				pt.tint = Color(1, 1, 1, 1)
				pt.ink_w = 0.4
				pt.ink_col = INK
				pt.light = Vector2(0.75, -0.6)
				it["job"]["fn"].call(pt)
		)
		vp.add_child(node)
		add_child(vp)
		var out := vp
		if float(pg["outline"]) > 0.0:
			# Second pass: dilate the alpha into a bold ink silhouette behind the drawing.
			var vp2 := SubViewport.new()
			vp2.size = size
			vp2.transparent_bg = true
			vp2.disable_3d = true
			vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
			var tr := TextureRect.new()
			tr.texture = vp.get_texture()
			tr.size = Vector2(size)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var mat := ShaderMaterial.new()
			mat.shader = outline_shader
			mat.set_shader_parameter("radius", float(pg["outline"]) * K)
			mat.set_shader_parameter("ink", INK)
			tr.material = mat
			vp2.add_child(tr)
			add_child(vp2)
			out = vp2
		vps.append([vp, out])
	# The outline pass reads the first pass, so it renders one frame later.
	await RenderingServer.frame_post_draw
	for v in vps:
		if v[1] != v[0]:
			v[1].render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	for i in pages.size():
		var img: Image = vps[i][1].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if OS.get_cmdline_user_args().has("--dumpatlas"):
			img.save_png("user://atlas_%d.png" % i)
		for it in pages[i]["items"]:
			var j: Dictionary = it["job"]
			var sz := Vector2i(int(ceil(j["size"].x * K)), int(ceil(j["size"].y * K)))
			var sub := img.get_region(Rect2i(it["pos"], sz))
			_unpremultiply(sub)
			sub.generate_mipmaps()
			var t := ImageTexture.create_from_image(sub)
			t.set_size_override(Vector2i(j["size"]))
			_results[j["key"]] = t
		vps[i][0].queue_free()
		if vps[i][1] != vps[i][0]:
			vps[i][1].queue_free()

## The viewport stores premultiplied colour at anti-aliased edges; undo it to avoid dark fringes.
func _unpremultiply(img: Image) -> void:
	var data := img.get_data()
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a > 0 and a < 255:
			var k := 255.0 / a
			data[i] = mini(255, int(data[i] * k))
			data[i + 1] = mini(255, int(data[i + 1] * k))
			data[i + 2] = mini(255, int(data[i + 2] * k))
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, data)

func _assemble() -> void:
	for k in _results.keys():
		var key: String = k
		if key.begins_with("unit/") or key.begins_with("crowd/") or key.begins_with("wpn/"):
			continue
		tex[key] = _results[key]
	for fac in ["qin", "zhao"] if gallery else []:
		for kind in KINDS.keys():
			if kind == "general" and fac == "qin":
				continue
			var base := "unit/%s_%s/" % [fac, kind]
			var d := {"walk": [], "idle": []}
			for f in (4 if kind == "cavalry" else 8):
				d["walk"].append(_results[base + "walk%d" % f])
			for f in 2:
				d["idle"].append(_results[base + "idle%d" % f])
			d["hurt"] = _results[base + "hurt"]
			d["broken"] = _results[base + "broken"]
			d["dead"] = _results[base + "dead"]
			units[fac + "_" + kind] = d
		var arr := []
		for v in 4:
			arr.append(_results["crowd/%s_%d" % [fac, v]])
		crowd[fac] = arr
		crowd_torch[fac] = _results["crowd/%s_torch" % fac]
	for kind in RIDER_KINDS if gallery else []:
		var base := "unit/qin_%s_m/" % kind
		var d := {"walk": [], "idle": []}
		for f in 4:
			d["walk"].append(_results[base + "walk%d" % f])
		for f in 2:
			d["idle"].append(_results[base + "idle%d" % f])
		d["hurt"] = _results[base + "hurt"]
		d["broken"] = _results[base + "broken"]
		d["dead"] = _results["unit/qin_cavalry/dead"]
		units["qin_%s_m" % kind] = d
	ArtProps.assemble_weapons(self)
	for k in ["portrait_zhao_general", "portrait_zhao_officer"]:
		tex[k].set_size_override(Vector2i(20, 24))

# ------------------------------------------------------------------ soldiers
func _queue_units() -> void:
	for fac in ["qin", "zhao"]:
		for kind in KINDS.keys():
			if kind == "general" and fac == "qin":
				continue
			var pal: Dictionary = PAL["general"] if kind == "general" else PAL[fac]
			var o: Dictionary = KINDS[kind]
			var base := "unit/%s_%s/" % [fac, kind]
			if kind == "cavalry":
				for f in 4:
					job(base + "walk%d" % f, Vector2(34, 34), _cav.bind(pal, o, f, true))
				for f in 2:
					job(base + "idle%d" % f, Vector2(34, 34), _cav.bind(pal, o, f, false))
				job(base + "hurt", Vector2(34, 34), _cav.bind(pal, o, 0, false))
				job(base + "broken", Vector2(34, 34), _cav.bind(pal, o, 1, false))
				job(base + "dead", Vector2(34, 22), _cav_dead.bind(pal))
			else:
				for f in 8:
					job(base + "walk%d" % f, Vector2(20, 24), _soldier.bind(pal, o, "walk", f))
				for f in 2:
					job(base + "idle%d" % f, Vector2(20, 24), _soldier.bind(pal, o, "idle", f))
				job(base + "hurt", Vector2(20, 24), _soldier.bind(pal, o, "hurt", 0))
				job(base + "broken", Vector2(20, 24), _soldier.bind(pal, o, "broken", 0))
				job(base + "dead", Vector2(24, 20), _soldier_dead.bind(pal, o))

## Riderless horses (left behind by fallen cavalry) and Qin soldiers of every kind on
## horseback, for when the player mounts one.
const RIDER_KINDS := ["infantry", "spear", "archer", "heavy", "officer"]

func _queue_horses() -> void:
	for fac in ["qin", "zhao"]:
		for f in 4:
			job("horse_%s_walk%d" % [fac, f], Vector2(34, 34), _horse_only.bind(PAL[fac], f, true))
		for f in 2:
			job("horse_%s_idle%d" % [fac, f], Vector2(34, 34), _horse_only.bind(PAL[fac], f, false))
	for kind in RIDER_KINDS:
		var o: Dictionary = KINDS[kind]
		var base := "unit/qin_%s_m/" % kind
		for f in 4:
			job(base + "walk%d" % f, Vector2(34, 34), _cav.bind(PAL["qin"], o, f, true))
		for f in 2:
			job(base + "idle%d" % f, Vector2(34, 34), _cav.bind(PAL["qin"], o, f, false))
		job(base + "hurt", Vector2(34, 34), _cav.bind(PAL["qin"], o, 0, false))
		job(base + "broken", Vector2(34, 34), _cav.bind(PAL["qin"], o, 1, false))

func _horse_only(p: Painter, pal: Dictionary, f: int, gallop: bool) -> void:
	draw_horse(p, pal, f, gallop)

func _soldier(p: Painter, pal: Dictionary, o: Dictionary, pose: String, f: int) -> void:
	draw_soldier(p, pal, o, pose, f)

func _portrait(p: Painter, pal: Dictionary, o: Dictionary) -> void:
	p.xf = Transform2D(0.0, Vector2(5, 5), 0.0, Vector2.ZERO)
	p.ink_w = 1.1
	p.light = Vector2(3.2, -2.6)
	draw_soldier(p, pal, o, "idle", 0)

func _soldier_dead(p: Painter, pal: Dictionary, o: Dictionary) -> void:
	# Lying on the ground, head to the left.
	p.xf = Transform2D(-PI * 0.5, Vector2(-1.0, 23.6))
	p.tint = Color(0.86, 0.84, 0.92)
	draw_soldier(p, pal, o, "dead", 0)

## Draws a soldier facing right in a 20x24 box, feet at y ~22.6.
func draw_soldier(p: Painter, pal: Dictionary, o: Dictionary, pose: String, f: int) -> void:
	var cl: Array = pal["cloth"]
	var ar: Array = pal["armor"]
	var trim: Color = pal["trim"]
	var heavy: bool = o.get("heavy", false)
	var swing := 0.0
	var bob := 0.0
	var lean := 0.0
	var front_a := 0.12
	var back_a := -0.1
	match pose:
		"walk":
			swing = sin(f * TAU / 8.0) * 0.68
			bob = cos(f * TAU / 4.0) * 0.35
			lean = 0.07
			front_a = swing
			back_a = -swing
		"idle":
			bob = [0.0, 0.3][f % 2]
		"hurt":
			lean = -0.28
			front_a = 0.3
			back_a = -0.05
		"dead":
			front_a = 0.05
			back_a = -0.05
	var hip := Vector2(10.0, 15.6 + bob)
	var mounted := pose == "mounted"
	var kneel := pose == "broken"
	var base_xf := p.xf
	# --- cape (behind)
	var cape: int = o.get("cape", 0)
	var up_xf := base_xf * Transform2D(lean, hip) * Transform2D(0.0, -hip)
	if kneel:
		up_xf = base_xf * Transform2D(0.2, hip + Vector2(0, 3.0)) * Transform2D(0.0, -hip)
	if cape > 0:
		p.xf = up_xf
		var clen := 8.5 if cape == 1 else 11.5
		var sway := (0.6 if f % 2 == 0 else -0.2)
		var cp := Painter.blob(PackedVector2Array([Vector2(7.4, 8.9), Vector2(10.0, 9.0), Vector2(8.4, 12.0),
			Vector2(6.8 + sway, 9.0 + clen), Vector2(3.6 + sway, 9.6 + clen), Vector2(5.2, 12.5)]), 3)
		p.shape(cp, cl[1], cl[2])
	# --- quiver
	if o.get("quiver", false):
		p.xf = up_xf
		var q := Painter.rotated(Painter.rect(6.2, 8.5, 1.9, 6.2), Vector2(7.1, 11.5), -0.35)
		p.shape(q, LEATHER[0], LEATHER[1])
		for k in 3:
			var fp := Vector2(5.9 + k * 0.7, 7.9 - k * 0.2)
			p.line(fp, fp + Vector2(0.3, 1.3), Color("#f3ead8"), 0.7)
	# --- back arm (behind the body)
	p.xf = up_xf
	if not kneel:
		p.shape(Painter.capsule(Vector2(8.1, 10.0), Vector2(7.2, 13.6), 0.95), cl[2], Color(0, 0, 0, 0))
	# --- legs
	p.xf = base_xf
	if kneel:
		_kneel_legs(p, hip + Vector2(0, 2.4))
	elif not mounted:
		_leg(p, hip + Vector2(-0.9, 0.0), back_a, PANTS[1], BOOT[1], true)
		_leg(p, hip + Vector2(0.9, 0.0), front_a, PANTS[0], BOOT[0], false)
	# --- upper body (skirt, torso, arms, head)
	p.xf = up_xf
	if kneel:
		p.xf = base_xf * Transform2D(0.2, hip + Vector2(0, 2.4)) * Transform2D(0.0, -hip)
	var x0 := 6.9 if heavy else 7.3
	var x1 := 13.1 if heavy else 12.7
	var skirt := PackedVector2Array([Vector2(x0 + 0.2, 13.9), Vector2(x1 - 0.1, 13.9), Vector2(x1 + 0.7, 17.8), Vector2(x0 - 0.6, 17.8)])
	if mounted:
		skirt = PackedVector2Array([Vector2(x0 + 0.2, 13.9), Vector2(x1 - 0.1, 13.9), Vector2(x1 + 0.4, 16.0), Vector2(x0 - 0.3, 16.0)])
	p.shape(skirt, ar[1] if heavy else cl[1], ar[2] if heavy else cl[2])
	if not heavy:
		p.line(Vector2(10.2, 14.4), Vector2(10.4, 17.6), cl[2], 0.45)
	var torso := PackedVector2Array([Vector2(x0 + 0.1, 8.9), Vector2(x1 - 0.4, 8.9), Vector2(x1 + 0.1, 10.5),
		Vector2(x1 - 0.2, 14.3), Vector2(x0 + 0.3, 14.3), Vector2(x0 - 0.2, 10.4)])
	p.shape(torso, ar[0], ar[1], Color(0, 0, 0, 0), true, 1.3)
	# lamellar plates laced with coloured cord
	for yy in [10.9, 12.6]:
		p.line(Vector2(x0 + 0.3, yy), Vector2(x1 - 0.3, yy), ar[2], 0.45)
		p.line(Vector2(x0 + 0.6, yy + 0.45), Vector2(x1 - 0.6, yy + 0.45), cl[1], 0.3)
	for xx in [x0 + 1.6, x0 + 3.4]:
		p.line(Vector2(xx, 9.4), Vector2(xx, 13.4), ar[1].darkened(0.15), 0.3)
	# scarf / collar and belt
	p.shape(PackedVector2Array([Vector2(9.0, 8.5), Vector2(12.2, 8.5), Vector2(11.0, 10.6)]), cl[0], cl[1])
	p.shape(Painter.rect(x0 + 0.1, 13.6, x1 - x0 - 0.2, 1.1), LEATHER[1], Color(0, 0, 0, 0))
	p.shape(Painter.rect(10.3, 13.5, 1.2, 1.3), trim, Color(0, 0, 0, 0))
	if o.get("fur", false):
		p.shape(Painter.blob(PackedVector2Array([Vector2(7.6, 8.4), Vector2(10.0, 7.6), Vector2(12.8, 8.2), Vector2(13.0, 9.6), Vector2(10.0, 10.0), Vector2(7.4, 9.7)]), 3),
			Color("#f2eef6"), Color("#b9b2c8"))
	if heavy or o.get("helm", 0) == 3:
		p.shape(Painter.blob(PackedVector2Array([Vector2(10.9, 8.5), Vector2(13.4, 8.6), Vector2(14.4, 10.4), Vector2(11.3, 11.1)]), 2), ar[0], ar[2])
	# front upper arm (the fist is a separate sprite that rides on the weapon grip)
	p.shape(Painter.capsule(Vector2(12.0, 9.9), Vector2(13.3, 11.9), 1.0), cl[1], cl[2])
	if pose == "dead" or kneel:
		p.shape(Painter.capsule(Vector2(13.3, 11.9), Vector2(14.0, 13.6), 0.85), cl[1], cl[2])
		p.shape(Painter.circle(Vector2(14.1, 13.9), 0.9, 8), SKIN[0], SKIN[1])
	# --- head
	var c := Vector2(10.9, 5.5)
	p.shape(Painter.rect(9.9, 7.6, 1.6, 1.6), SKIN[1], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)
	var head := Painter.circle(c, 2.95, 16)
	p.fill(head, HAIR)
	for poly in Geometry2D.intersect_polygons(head, Painter.circle(c + Vector2(0.8, 0.4), 2.6, 16)):
		p.fill(poly, SKIN[0])
	for poly in Geometry2D.intersect_polygons(head, Painter.circle(c + Vector2(-0.7, 1.6), 2.2, 12)):
		p.fill(poly, Color(SKIN[1].r, SKIN[1].g, SKIN[1].b, 0.6))
	p.ink(head)
	var eye := c + Vector2(1.55, 0.75)
	if pose == "hurt" or pose == "dead" or kneel:
		p.line(eye + Vector2(-0.5, -0.1), eye + Vector2(0.45, 0.25), INK, 0.5)
	else:
		p.fill(Painter.rect(eye.x - 0.3, eye.y - 0.5, 0.65, 0.95), INK)
		p.line(eye + Vector2(-0.7, -0.95), eye + Vector2(0.55, -0.6), INK, 0.4)
	p.line(c + Vector2(2.4, 1.9), c + Vector2(1.6, 2.1), SKIN[2], 0.35)
	_helm(p, o.get("helm", 0), c, pal, f)
	p.xf = base_xf

func _leg(p: Painter, hip: Vector2, ang: float, pc: Color, bc: Color, back: bool) -> void:
	var knee := hip + Vector2(0, 3.5).rotated(-ang)
	var bend := 0.25 if back and ang < -0.1 else 0.0
	var ankle := knee + Vector2(0, 3.4).rotated(-ang + bend)
	p.shape(Painter.limb(hip, knee, 1.15, 1.0), pc, pc.darkened(0.3), Color(0, 0, 0, 0), true, 0.8)
	p.shape(Painter.limb(knee, ankle + Vector2(0, -1.0), 1.0, 0.95), pc, pc.darkened(0.3), Color(0, 0, 0, 0), true, 0.8)
	var foot := PackedVector2Array([ankle + Vector2(-1.0, -1.6), ankle + Vector2(1.0, -1.6), ankle + Vector2(1.3, -0.5),
		ankle + Vector2(2.5, 0.2), ankle + Vector2(2.5, 0.8), ankle + Vector2(-1.1, 0.8)])
	p.shape(foot, bc, bc.darkened(0.4))

func _kneel_legs(p: Painter, hip: Vector2) -> void:
	# back leg: knee on the ground behind; front leg: thigh forward, shin down
	var bk := hip + Vector2(-1.8, 2.6)
	p.shape(Painter.limb(hip + Vector2(-0.6, 0), bk, 1.1, 1.0), PANTS[1], PANTS[1].darkened(0.3))
	p.shape(Painter.limb(bk, bk + Vector2(-3.4, 0.6), 1.0, 0.9), PANTS[1], PANTS[1].darkened(0.3))
	p.shape(PackedVector2Array([bk + Vector2(-3.4, -0.4), bk + Vector2(-5.2, 0.0), bk + Vector2(-5.2, 1.2), bk + Vector2(-3.2, 1.4)]), BOOT[1], BOOT[1].darkened(0.4))
	var fk := hip + Vector2(3.0, -0.2)
	p.shape(Painter.limb(hip + Vector2(0.6, 0), fk, 1.15, 1.05), PANTS[0], PANTS[0].darkened(0.3))
	var fa := fk + Vector2(0.2, 4.6)
	p.shape(Painter.limb(fk, fa + Vector2(0, -1.0), 1.0, 0.95), PANTS[0], PANTS[0].darkened(0.3))
	p.shape(PackedVector2Array([fa + Vector2(-1.0, -1.5), fa + Vector2(1.0, -1.5), fa + Vector2(2.4, 0.2), fa + Vector2(2.4, 0.8), fa + Vector2(-1.1, 0.8)]), BOOT[0], BOOT[0].darkened(0.4))

func _helm(p: Painter, style: int, c: Vector2, pal: Dictionary, f: int) -> void:
	var steel: Array = pal["helm"]
	var cloth: Array = pal["cloth"]
	# Nasal helms, kettle hats and enclosed bascinets; bold shapes survive battle zoom.
	if style == 4:
		p.shape(PackedVector2Array([c+Vector2(-3.1,1),c+Vector2(-3,-2),c+Vector2(0,-3.7),c+Vector2(3.1,-1),c+Vector2(2.2,0.6)]),cloth[1],cloth[2])
		return
	var helmet := PackedVector2Array([c+Vector2(-3.2,1),c+Vector2(-3.0,-1.5),c+Vector2(-1,-3.4),c+Vector2(1.9,-3.0),c+Vector2(3.1,-0.8),c+Vector2(3.1,1)])
	p.shape(helmet,steel[0],steel[1],Color(0,0,0,0),true,0.9)
	p.line(c+Vector2(-2.7,0.7),c+Vector2(3.7,0.7),steel[2],0.7)
	if style in [5,6]:
		p.shape(PackedVector2Array([c+Vector2(-2.4,0),c+Vector2(3.3,0),c+Vector2(2.7,4),c+Vector2(-1.7,3.3)]),steel[1],steel[2])
		p.line(c+Vector2(0,1.2),c+Vector2(3,1.2),INK,0.65)
		for j in 3:
			p.line(c+Vector2(0.3+j*0.8,2.0),c+Vector2(0.3+j*0.8,3.1),INK,0.25)
	else:
		p.line(c+Vector2(2.5,0),c+Vector2(2.7,3),steel[0],0.7)
		p.shape(Painter.rect(c.x-3,c.y+0.4,1.7,3.7),steel[1],steel[2])
	if style in [3,6]:
		p.shape(PackedVector2Array([c+Vector2(-1,-3),c+Vector2(-3,-5),c+Vector2(-6.8,-4.5),c+Vector2(-8,-2),c+Vector2(-3,-2.7)]),cloth[0],cloth[2])
	if style == 1:
		p.line(c+Vector2(0,-3),c+Vector2(0,-0.2),pal["trim"],0.55)

func _cav(p: Painter, pal: Dictionary, o: Dictionary, f: int, gallop: bool) -> void:
	draw_horse(p, pal, f, gallop)
	var base := p.xf
	p.xf = base * Transform2D(0.0, Vector2(6, 1))
	draw_soldier(p, pal, o, "mounted", f)
	p.xf = base
	# rider's leg hanging over the horse's flank
	p.shape(Painter.limb(Vector2(16.6, 17.0), Vector2(17.4, 22.2), 1.1, 0.95), PANTS[0], PANTS[1])
	p.shape(PackedVector2Array([Vector2(16.4, 21.6), Vector2(18.4, 21.6), Vector2(19.6, 22.8), Vector2(16.4, 23.2)]), BOOT[0], BOOT[1])

func _cav_dead(p: Painter, pal: Dictionary) -> void:
	p.tint = Color(0.82, 0.8, 0.88)
	p.xf = Transform2D(PI, Vector2(34, 30))
	draw_horse(p, pal, 0, false)

func draw_horse(p: Painter, pal: Dictionary, f: int, gallop: bool) -> void:
	var hc: Array = pal["horse"]
	var mane: Color = pal["mane"]
	var cl: Array = pal["cloth"]
	var o := 8.0
	var legs := [[10.0, 10.0], [12.0, 12.0], [21.0, 21.0], [23.0, 23.0]]
	if gallop:
		match f % 4:
			0: legs = [[10.0, 6.0], [12.0, 8.0], [21.0, 26.0], [23.0, 28.0]]
			1: legs = [[10.0, 11.0], [12.0, 13.0], [21.0, 21.0], [23.0, 22.0]]
			2: legs = [[10.0, 14.0], [12.0, 16.0], [21.0, 18.0], [23.0, 20.0]]
			3: legs = [[10.0, 9.0], [12.0, 11.0], [21.0, 23.0], [23.0, 24.0]]
	elif f % 2 == 1:
		legs[2] = [21.0, 22.0]
	# far legs first (darker)
	for i in [0, 2]:
		_horse_leg(p, Vector2(legs[i][0], 15.0 + o), Vector2(legs[i][1], 23.0 + o), hc[2])
	var sw := 0.8 if f % 2 == 0 else -0.4
	var tail := Painter.stroke(Painter.curve(PackedVector2Array([Vector2(8.6, 10.2 + o), Vector2(6.0 + sw, 13.0 + o), Vector2(5.0 + sw, 18.0 + o)])), 1.3, 0.4)
	p.shape(tail, mane, Color(0, 0, 0, 0))
	var body := Painter.blob(PackedVector2Array([Vector2(8.4, 11.0 + o), Vector2(12.0, 9.0 + o), Vector2(18.0, 9.2 + o), Vector2(22.8, 8.6 + o),
		Vector2(24.6, 12.0 + o), Vector2(22.0, 16.4 + o), Vector2(16.0, 16.8 + o), Vector2(10.0, 16.4 + o), Vector2(7.8, 14.0 + o)]), 3)
	p.shape(body, hc[0], hc[2], Color(0, 0, 0, 0), true, 1.4)
	var neck := PackedVector2Array([Vector2(20.8, 10.6 + o), Vector2(23.4, 4.0 + o), Vector2(26.2, 3.0 + o), Vector2(25.4, 8.0 + o), Vector2(24.6, 12.4 + o)])
	p.shape(neck, hc[0], hc[2])
	var head := Painter.blob(PackedVector2Array([Vector2(24.2, 2.6 + o), Vector2(27.0, 2.2 + o), Vector2(31.6, 6.0 + o), Vector2(31.2, 7.8 + o),
		Vector2(28.2, 7.6 + o), Vector2(25.4, 6.0 + o)]), 3)
	p.shape(head, hc[0], hc[1])
	p.shape(PackedVector2Array([Vector2(24.8, 2.8 + o), Vector2(25.4, 0.2 + o), Vector2(26.4, 2.4 + o)]), hc[1], hc[2])
	p.fill(Painter.circle(Vector2(27.2, 4.0 + o), 0.45, 6), INK)
	var mn := Painter.stroke(Painter.curve(PackedVector2Array([Vector2(24.6, 2.6 + o), Vector2(22.8, 5.6 + o), Vector2(21.2, 9.6 + o)])), 0.9, 1.2)
	p.shape(mn, mane, Color(0, 0, 0, 0))
	# saddle cloth + saddle
	var sc := PackedVector2Array([Vector2(12.0, 9.4 + o), Vector2(19.6, 9.4 + o), Vector2(20.2, 14.6 + o), Vector2(11.6, 14.6 + o)])
	p.shape(sc, cl[1], cl[2])
	p.line(Vector2(11.8, 14.0 + o), Vector2(20.1, 14.0 + o), pal["trim"], 0.7)
	p.shape(PackedVector2Array([Vector2(13.0, 8.4 + o), Vector2(18.8, 8.4 + o), Vector2(18.4, 10.4 + o), Vector2(13.4, 10.4 + o)]), LEATHER[0], LEATHER[1])
	for i in [1, 3]:
		_horse_leg(p, Vector2(legs[i][0], 15.0 + o), Vector2(legs[i][1], 23.0 + o), hc[1])

func _horse_leg(p: Painter, top: Vector2, bot: Vector2, c: Color) -> void:
	var knee := top.lerp(bot, 0.5) + Vector2(0.6 if bot.x < top.x else -0.4, 0.0)
	p.shape(Painter.limb(top, knee, 1.3, 0.8), c, c.darkened(0.3))
	p.shape(Painter.limb(knee, bot, 0.8, 0.65), c, c.darkened(0.3))
	p.shape(Painter.rect(bot.x - 0.9, bot.y - 0.2, 2.0, 1.0), Color("#1c1616"), Color(0, 0, 0, 0))

# ------------------------------------------------------------------ crowds (tiny figures)
func _queue_crowd() -> void:
	for fac in ["qin", "zhao"]:
		for v in 4:
			job("crowd/%s_%d" % [fac, v], Vector2(9, 18), _crowd_fig.bind(PAL[fac], v, false), 0.4)
		job("crowd/%s_torch" % fac, Vector2(9, 20), _crowd_fig.bind(PAL[fac], 0, true), 0.4)

func _crowd_fig(p: Painter, pal: Dictionary, v: int, torch: bool) -> void:
	p.ink_w = 0.35
	var cl: Array = pal["cloth"]
	var ar: Array = pal["armor"]
	var hm: Array = pal["helm"]
	var oy := 2.0 if torch else 0.0
	if torch:
		p.line(Vector2(6.2, 3.0), Vector2(6.2, 17.0), WOOD[2], 0.6)
		p.shape(Painter.blob(PackedVector2Array([Vector2(6.2, -0.2), Vector2(7.4, 2.0), Vector2(6.2, 3.4), Vector2(5.0, 2.0)]), 2), Color("#ffd65c"), Color("#ff7a2a"))
	elif v == 3:
		p.line(Vector2(6.4, 0.5), Vector2(6.4, 15.0), WOOD[2], 0.55)
		p.shape(PackedVector2Array([Vector2(6.6, 1.0), Vector2(9.0, 1.4), Vector2(8.6, 5.6), Vector2(6.6, 5.2)]), cl[0], cl[1])
	else:
		p.line(Vector2(6.4, 0.6), Vector2(6.4, 15.0), WOOD[2], 0.55)
		p.shape(PackedVector2Array([Vector2(6.4, -0.6), Vector2(7.0, 1.4), Vector2(5.8, 1.4)]), STEEL[0], STEEL[2])
	p.shape(Painter.rect(2.0, 13.6 + oy, 1.4, 3.0), PANTS[1], Color(0, 0, 0, 0))
	p.shape(Painter.rect(4.6, 13.6 + oy, 1.4, 3.0), PANTS[0], Color(0, 0, 0, 0))
	var body := PackedVector2Array([Vector2(1.8, 7.9 + oy), Vector2(6.6, 7.9 + oy), Vector2(6.9, 14.4 + oy), Vector2(1.5, 14.4 + oy)])
	p.shape(body, cl[1] if v == 1 else ar[0], cl[2] if v == 1 else ar[2])
	p.line(Vector2(2.0, 12.4 + oy), Vector2(6.6, 12.4 + oy), cl[0], 0.9)
	p.shape(Painter.circle(Vector2(4.2, 6.0 + oy), 1.7, 10), SKIN[1], SKIN[2])
	p.shape(Painter.ellipse(Vector2(4.1, 5.4 + oy), 2.0, 1.6, 10, PI, TAU), hm[0], hm[2])
