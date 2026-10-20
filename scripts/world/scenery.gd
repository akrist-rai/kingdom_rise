class_name Scenery
extends Node2D
## Places baked environment art (PropArt) in a battle:
##  - prop(): a tree / building / tent as a depth-sorted sprite in the world (optionally solid,
##    optionally swaying), with its cast shadow
##  - clutter(): grass, flowers, pebbles and path stones drawn flat on the ground in static
##    chunks (one batch per chunk, culled per chunk)
##  - every prop shadow is rendered once into a ground shadow map, so overlapping shadows merge
##    instead of stacking darker
## This node sits on the ground layer: above the ground and decals, under soldiers.

const CHUNK := 480.0
const SRES := 0.75            # shadow-map texels per world unit
const SHADOW_ALPHA := 0.34

var battle = null
var size := Vector2.ZERO
var origin := Vector2.ZERO
var chunks := {}
var clutter_root: Node2D
var shadow_vp: SubViewport
var shadow_root: Node2D
var shadow_spr: Sprite2D
var shadow_dirty := false
var sway_tree: ShaderMaterial
var sway_bush: ShaderMaterial
var sway_grass: ShaderMaterial
var still_mat: ShaderMaterial  # no sway: only used to carry the winter look (set_snow)
var snow := 0.0
var count := 0
var buildings: Array = []     # Building nodes: their see-through fade is checked here in one loop
var trees: Array = []         # [sprite, foot, half width, height]: fade when the player is behind

func setup(b, area: Rect2) -> void:
	battle = b
	origin = area.position
	size = area.size
	clutter_root = Node2D.new()
	add_child(clutter_root)
	shadow_vp = SubViewport.new()
	shadow_vp.size = Vector2i((area.size * SRES).ceil())
	shadow_vp.transparent_bg = true
	shadow_vp.disable_3d = true
	shadow_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	shadow_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	shadow_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(shadow_vp)
	shadow_root = Node2D.new()
	shadow_root.scale = Vector2(SRES, SRES)
	shadow_root.position = -origin * SRES
	shadow_vp.add_child(shadow_root)
	shadow_spr = Sprite2D.new()
	shadow_spr.texture = shadow_vp.get_texture()
	shadow_spr.centered = false
	shadow_spr.position = origin
	shadow_spr.scale = Vector2(1.0 / SRES, 1.0 / SRES)
	shadow_spr.modulate = Color(1, 1, 1, SHADOW_ALPHA)
	shadow_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(shadow_spr)
	var sh: Shader = load("res://shaders/prop_sway.gdshader")
	sway_tree = ShaderMaterial.new()
	sway_tree.shader = sh
	sway_tree.set_shader_parameter("amp", 5.0)
	sway_tree.set_shader_parameter("base", 0.35)
	sway_bush = ShaderMaterial.new()
	sway_bush.shader = sh
	sway_bush.set_shader_parameter("amp", 2.0)
	sway_bush.set_shader_parameter("base", 0.15)
	sway_grass = ShaderMaterial.new()
	sway_grass.shader = sh
	sway_grass.set_shader_parameter("amp", 2.5)
	sway_grass.set_shader_parameter("base", 0.0)
	still_mat = ShaderMaterial.new()
	still_mat.shader = sh
	still_mat.set_shader_parameter("amp", 0.0)

## Winter dressing: every prop and all ground clutter take the snow look (0 = summer).
func set_snow(k: float) -> void:
	snow = k
	for m in [sway_tree, sway_bush, sway_grass, still_mat]:
		m.set_shader_parameter("snow", k)
	clutter_root.material = still_mat if k > 0.0 else null

func _process(delta: float) -> void:
	if shadow_dirty:
		shadow_dirty = false
		shadow_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_follow_shadows()
	var p = battle.player if battle != null else null
	var pp := Vector2.INF
	if p != null and is_instance_valid(p):
		pp = p.global_position
	_fade_trees(pp, delta)
	for b in buildings:
		var want := 1.0
		if pp != Vector2.INF:
			var r: Rect2 = b.rect
			if pp.x > r.position.x - 4.0 and pp.x < r.end.x + 4.0 and pp.y < r.end.y and pp.y > r.position.y - b.height * 0.8:
				want = 0.38
		if b.modulate.a != want:
			b.modulate.a = move_toward(b.modulate.a, want, delta * 3.0)

## Trees in front of the player turn see-through, so a melee behind a pine stays readable.
func _fade_trees(pp: Vector2, delta: float) -> void:
	var vr: Rect2 = Battle.view
	for tr in trees:
		var spr: Sprite2D = tr[0]
		var foot: Vector2 = tr[1]
		if not vr.has_point(foot):
			continue
		var want := 1.0
		if pp != Vector2.INF and absf(pp.x - foot.x) < tr[2] and pp.y < foot.y - 2.0 and pp.y > foot.y - tr[3]:
			want = 0.35
		if spr.modulate.a != want:
			spr.modulate.a = move_toward(spr.modulate.a, want, delta * 4.0)

## A depth-sorted prop. opts: scale, flip, sway ("tree" | "bush" | "grass"), shadow (bool),
## solid (Rect2 relative to the foot, or true for the baked footprint), mod (Color), parent.
func prop(name: String, pos: Vector2, opts: Dictionary = {}) -> Sprite2D:
	if not PropArt.has(name):
		return null
	var s: float = opts.get("scale", 1.0)
	var spr := Sprite2D.new()
	spr.texture = PropArt.tex(name)
	spr.centered = false
	spr.offset = -PropArt.anchor(name)
	spr.scale = Vector2(s, s) / PropArt.R
	spr.position = pos
	spr.flip_h = opts.get("flip", false)
	if spr.flip_h:
		spr.offset.x = -(float(spr.texture.get_width()) - PropArt.anchor(name).x)
	if opts.has("mod"):
		spr.modulate = opts["mod"]
	match opts.get("sway", ""):
		"tree":
			spr.material = sway_tree
			var tsz := spr.texture.get_size() * s / PropArt.R
			trees.append([spr, pos, tsz.x * 0.42, tsz.y * 0.9])
		"bush":
			spr.material = sway_bush
		"grass":
			spr.material = sway_grass
		_:
			if snow > 0.0:
				spr.material = still_mat
	var parent: Node = opts.get("parent", battle.world)
	parent.add_child(spr)
	if opts.get("shadow", true):
		add_shadow(name, pos, s, spr.flip_h)
	var solid = opts.get("solid", null)
	if solid != null and battle.terrain != null:
		var r: Rect2
		if solid is Rect2:
			r = Rect2(pos + solid.position * s, solid.size * s)
		else:
			var f := PropArt.foot(name) * s
			r = Rect2(pos - Vector2(f.x * 0.5, f.y * 0.5), f)
		battle.terrain.add(r, opts.get("tag", ""))
	count += 1
	return spr

func add_shadow(name: String, pos: Vector2, s: float = 1.0, flip: bool = false) -> void:
	var st := PropArt.shadow_tex(name)
	if st == null:
		return
	var sh := Sprite2D.new()
	sh.texture = st
	sh.centered = false
	sh.offset = -PropArt.shadow_anchor(name)
	sh.scale = Vector2(s, s) / PropArt.R
	sh.position = pos
	if flip:
		# the sun does not flip: mirror the shadow's anchor but keep it falling the same way
		sh.flip_h = false
	shadow_root.add_child(sh)
	shadow_dirty = true

## A sprite of a baked prop (siege engines), team-coloured with the unit shader; anchored at the
## model's ground origin. Its shadow follows it on the ground layer.
var dyn_shadows: Array = []    # [shadow sprite, node it follows]

func engine_sprite(host: Node2D, name: String, palette: String = "march") -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.material = UnitArt.materials.get(palette)
	s.scale = Vector2.ONE / PropArt.R
	host.add_child(s)
	set_frame(s, name)
	var st := PropArt.shadow_tex(name)
	if st:
		var sh := Sprite2D.new()
		sh.texture = st
		sh.centered = false
		sh.offset = -PropArt.shadow_anchor(name)
		sh.scale = Vector2.ONE / PropArt.R
		sh.modulate = Color(1, 1, 1, SHADOW_ALPHA * 1.2)
		add_child(sh)
		dyn_shadows.append([sh, host])
	return s

func set_frame(s: Sprite2D, name: String) -> void:
	if not PropArt.has(name):
		return
	var t := PropArt.tex(name)
	if s.texture != t:
		s.texture = t
		s.offset = -PropArt.anchor(name)

func _follow_shadows() -> void:
	for e in dyn_shadows:
		var n = e[1]
		if is_instance_valid(n):
			e[0].global_position = n.global_position
			e[0].visible = n.visible
		elif is_instance_valid(e[0]):
			e[0].queue_free()

## Flat ground clutter, drawn from the shared atlas.
func clutter(name: String, pos: Vector2, s: float = 1.0, flip: bool = false, mod: Color = Color.WHITE) -> void:
	if not PropArt.regions.has(name):
		return
	var key := Vector2i(int(floor(pos.x / CHUNK)), int(floor(pos.y / CHUNK)))
	var ch: ClutterChunk = chunks.get(key)
	if ch == null:
		ch = ClutterChunk.new()
		ch.tex = PropArt.atlas
		ch.use_parent_material = true
		clutter_root.add_child(ch)
		chunks[key] = ch
	var rg: Rect2 = PropArt.regions[name]
	var a := PropArt.anchor(name)
	var k := s / PropArt.R
	var dest := Rect2(pos - a * k, rg.size * k)
	if flip:
		dest = Rect2(pos - Vector2(rg.size.x - a.x, a.y) * k, rg.size * k)
	ch.items.append([rg, dest, flip, mod])
	ch.queue_redraw()
	count += 1

## Scatters clutter over a rectangle. `avoid(p) -> bool` rejects points (roads, walls...).
func scatter(rect: Rect2, n: int, names: Array, rng: RandomNumberGenerator, avoid: Callable = Callable(), sc: Vector2 = Vector2(0.8, 1.25), mod: Color = Color.WHITE) -> void:
	for i in n:
		var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if avoid.is_valid() and avoid.call(p):
			continue
		clutter(names[rng.randi() % names.size()], p, rng.randf_range(sc.x, sc.y), rng.randf() < 0.5, mod)

## Natural-looking clutter: clumps of several pieces around random centres, thinning out
## toward each clump's edge.
func scatter_clumps(rect: Rect2, clumps: int, per: Vector2i, radius: float, names: Array, rng: RandomNumberGenerator, avoid: Callable = Callable(), sc: Vector2 = Vector2(0.8, 1.2), mod: Color = Color.WHITE) -> void:
	for i in clumps:
		var c := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		if avoid.is_valid() and avoid.call(c):
			continue
		var main: String = names[rng.randi() % names.size()]
		for k in rng.randi_range(per.x, per.y):
			var a := rng.randf() * TAU
			var r := radius * sqrt(rng.randf())
			var p := c + Vector2(cos(a) * r, sin(a) * r * 0.6)
			var n: String = main if rng.randf() < 0.7 else names[rng.randi() % names.size()]
			var shade := rng.randf_range(0.82, 1.0)
			clutter(n, p, rng.randf_range(sc.x, sc.y) * (1.0 - r / radius * 0.3), rng.randf() < 0.5, Color(mod.r * shade, mod.g * shade, mod.b * shade, mod.a))

## A baked building standing on a city lot (rect = its footprint, y-sorted by the lot's south
## edge). Drop-in for SiegeProps.House: same rect / fh / charred / burning fields; it fades when
## the player walks behind it.
class Building extends Node2D:
	var battle = null
	var rect := Rect2()
	var fh := 40.0
	var charred := 0.0
	var burning := false
	var glow := 1.0
	var spr: Sprite2D
	var height := 60.0

	func setup(b, r: Rect2, prop_name: String, sc: Scenery) -> void:
		battle = b
		rect = r
		position = Vector2(r.get_center().x, r.end.y)
		var f := PropArt.foot(prop_name)
		var s := (r.size.x + 4.0) / maxf(8.0, f.x)
		spr = Sprite2D.new()
		spr.texture = PropArt.tex(prop_name)
		spr.centered = false
		spr.offset = -PropArt.anchor(prop_name)
		spr.scale = Vector2(s, s) / PropArt.R
		spr.position = Vector2(0, -r.size.y * 0.5)
		add_child(spr)
		height = float(PropArt.info[prop_name]["top"]) * s
		fh = height * 0.45
		sc.add_shadow(prop_name, Vector2(r.get_center().x, r.get_center().y), s)
		set_process(false)
		sc.buildings.append(self)

	func queue_redraw_house() -> void:
		var k := 1.0 - charred * 0.55
		spr.self_modulate = Color(k, k * 0.95, k * 0.92)

	func roof_point() -> Vector2:
		return Vector2(rect.get_center().x, rect.get_center().y - height * 0.7)

	func _process(delta: float) -> void:
		var want := 1.0
		var p = battle.player if battle != null else null
		if p != null and is_instance_valid(p):
			var zone := Rect2(rect.position.x - 4.0, rect.position.y - height * 0.8, rect.size.x + 8.0, rect.size.y + height * 0.8)
			if zone.has_point(p.global_position):
				want = 0.38
		modulate.a = move_toward(modulate.a, want, delta * 3.0)

class ClutterChunk extends Node2D:
	var tex: Texture2D
	var items: Array = []
	func _draw() -> void:
		for it in items:
			var d: Rect2 = it[1]
			if it[2]:
				d = Rect2(d.position + Vector2(d.size.x, 0), Vector2(-d.size.x, d.size.y))
			draw_texture_rect_region(tex, d, it[0], it[3])

## A war banner on a tall pole: a swallowtail of cloth rippling in the wind, shaded in its
## folds, with a gold finial and the army's device. Drawn (not baked) so the cloth faces the
## camera and moves; cheap enough for dozens, and it stops redrawing off screen.
class WarBanner extends Node2D:
	var col := Color("#b8282a")
	var height := 56.0
	var t := 0.0
	var ph := 0.0

	func _process(delta: float) -> void:
		t += delta
		if Battle.view.grow(80.0).has_point(position):
			queue_redraw()

	func _draw() -> void:
		var top := Vector2(0, -height)
		# pole shadow and pole
		draw_line(Vector2.ZERO, Vector2(14, 5), Color(0.05, 0.05, 0.1, 0.25), 2.4, true)
		draw_line(Vector2(0.6, 0), top, Color("#2a1a10"), 2.6, true)
		draw_line(Vector2(-0.5, 0), top, Color("#7a5434"), 0.9, true)
		draw_line(top + Vector2(-1.5, 3), top + Vector2(25, 3), Color("#2a1a10"), 1.6, true)
		draw_circle(top + Vector2(0, -2), 2.4, Color("#3a2410"))
		draw_circle(top + Vector2(-0.4, -2.5), 1.6, Color("#f0c860"))
		var up := PackedVector2Array()
		var lo := PackedVector2Array()
		var n := 7
		for i in n + 1:
			var k := float(i) / n
			var w := sin(t * 3.8 - k * 3.4 + ph) * 3.0 * k
			up.append(top + Vector2(k * 34.0, 3.0 + w))
			lo.append(top + Vector2(k * 34.0, 25.0 - k * 4.0 + w + sin(t * 2.7 - k * 2.0 + ph) * 1.2 * k))
		for i in n:
			var sh := 0.78 + 0.22 * cos(t * 3.8 - (i + 0.5) / n * 3.4 + ph - 0.6)
			var c := Color(col.r * sh, col.g * sh, col.b * sh)
			if i == n - 1:
				var mid := (up[n] + lo[n]) * 0.5 - Vector2(3.4, 0)
				draw_colored_polygon(PackedVector2Array([up[i], up[n], mid]), c)
				draw_colored_polygon(PackedVector2Array([up[i], mid, lo[i]]), c)
				draw_colored_polygon(PackedVector2Array([lo[i], mid, lo[n]]), c)
			else:
				draw_colored_polygon(PackedVector2Array([up[i], up[i + 1], lo[i + 1], lo[i]]), c)
		draw_polyline(up, Color(col.lightened(0.4), 0.9), 1.0, true)
		var dc := (up[2] + lo[2]) * 0.5
		draw_circle(dc, 4.4, Color("#e8c060"))
		draw_circle(dc, 3.0, col.darkened(0.3))

## Plants a war banner in the world (y-sorted with the soldiers).
func banner(pos: Vector2, col: Color, h: float = 56.0) -> WarBanner:
	var wb := WarBanner.new()
	wb.position = pos
	wb.col = col
	wb.height = h
	wb.ph = randf() * TAU
	battle.world.add_child(wb)
	return wb
