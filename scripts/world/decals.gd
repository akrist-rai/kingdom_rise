class_name Decals
extends Node2D
## Persistent ground layer: footprints, blood, fallen soldiers and arrows accumulate
## over the whole battle. It is an offscreen SubViewport that is never cleared;
## new marks are painted into it only on the frames they appear.

var vp: SubViewport
var painter: Node2D
var ops: Array = []
var size := Vector2.ZERO
var RES := 2.0   # decal texels per world unit (sharp at 2x display scale; lower on big maps)

func setup(sz: Vector2) -> void:
	size = sz
	vp = SubViewport.new()
	vp.size = Vector2i(sz * RES)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(vp)
	painter = Node2D.new()
	painter.scale = Vector2(RES, RES)
	painter.draw.connect(_paint)
	vp.add_child(painter)
	var spr := Sprite2D.new()
	spr.texture = vp.get_texture()
	spr.centered = false
	spr.scale = Vector2(1.0 / RES, 1.0 / RES)
	add_child(spr)

func _process(_delta: float) -> void:
	if ops.size() > 0:
		painter.queue_redraw()
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

func _paint() -> void:
	for op in ops:
		match op[0]:
			"fp":
				painter.draw_set_transform(op[1] + Vector2(1.0, 0.5), 0.0, Vector2(1.0, 0.5))
				painter.draw_circle(Vector2.ZERO, 1.0, Color(0.3, 0.32, 0.62, 0.28))
				painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"blood":
				var p: Vector2 = op[1]
				var r: float = op[2]
				painter.draw_set_transform(p, 0.0, Vector2(1.0, 0.6))
				painter.draw_circle(Vector2.ZERO, r, Color(0.42, 0.04, 0.09, 0.72))
				painter.draw_circle(Vector2(r * 0.6, r * 0.3), r * 0.55, Color(0.36, 0.03, 0.08, 0.6))
				painter.draw_circle(Vector2(-r * 0.7, -r * 0.2), r * 0.4, Color(0.5, 0.06, 0.1, 0.6))
				painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"drop":
				painter.draw_circle(op[1] + Vector2(0.5, 0.5), 0.6, Color(0.55, 0.05, 0.1, 0.85))
			"tex":
				var t: Texture2D = op[1]
				var p: Vector2 = op[2]
				var sz: Vector2 = t.get_size()
				var rect := Rect2(p, sz)
				if op[3]:
					rect = Rect2(p + Vector2(sz.x, 0), Vector2(-sz.x, sz.y))
				painter.draw_texture_rect(t, rect, false, op[4])
			"crack":
				var p: Vector2 = op[1]
				var dir: Vector2 = op[2]
				var n := dir.orthogonal()
				var j := randf_range(-3, 3)
				painter.draw_line(p + n * j, p + dir * 6.0 + n * randf_range(-3, 3), Color(0.25, 0.24, 0.36, 0.7), 1.0)
				painter.draw_rect(Rect2(p + n * randf_range(-6, 6), Vector2(1, 1)), Color(0.95, 0.96, 1.0, 0.9))
			"rect":
				painter.draw_rect(op[1], op[2])
			"splat":
				var p: Vector2 = op[1]
				var dir: Vector2 = op[2]
				var rng := RandomNumberGenerator.new()
				rng.seed = int(p.x * 7.0 + p.y * 13.0)
				var cols := [Color(0.08, 0.05, 0.08, 0.85), Color(0.45, 0.03, 0.08, 0.85), Color(0.6, 0.06, 0.1, 0.8)]
				for k in 18:
					var along := rng.randf_range(-4.0, 34.0)
					var side := rng.randf_range(-8.0, 8.0) * (1.0 - along / 40.0)
					var q := p + dir * along + dir.orthogonal() * side
					var rr := rng.randf_range(0.8, 3.2) * (1.2 - along / 40.0)
					painter.draw_set_transform(q, 0.0, Vector2(1.0, 0.6))
					painter.draw_circle(Vector2.ZERO, maxf(0.6, rr), cols[k % 3])
				painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				for k in 4:
					var a := p + dir.orthogonal() * rng.randf_range(-3.0, 3.0)
					painter.draw_line(a, a + dir.rotated(rng.randf_range(-0.2, 0.2)) * rng.randf_range(20.0, 46.0), Color(0.08, 0.05, 0.08, 0.7), 1.0)
			"scorch":
				var p: Vector2 = op[1]
				var r: float = op[2]
				for k in 5:
					var rr := r * (1.0 - k * 0.16)
					painter.draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
					painter.draw_circle(Vector2(randf_range(-2, 2), randf_range(-2, 2)), rr, Color(0.16, 0.12, 0.16, 0.16 + k * 0.06))
				painter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ops.clear()

func footprint(p: Vector2) -> void:
	if ops.size() < 4000:
		ops.append(["fp", p.floor()])

func blood_pool(p: Vector2, r: float) -> void:
	ops.append(["blood", p, r])

func blood_drop(p: Vector2) -> void:
	ops.append(["drop", p.floor()])

func stamp(t: Texture2D, p: Vector2, flip: bool, mod: Color = Color(0.68, 0.66, 0.78, 1.0)) -> void:
	ops.append(["tex", t, p.floor(), flip, mod])

func stuck_arrow(p: Vector2) -> void:
	ops.append(["tex", Art.tex["arrow_stuck"], (p - Vector2(3, 9)).floor(), randf() < 0.5, Color.WHITE])

func crack(p: Vector2, dir: Vector2) -> void:
	ops.append(["crack", p, dir])

func splat(p: Vector2, dir: Vector2) -> void:
	ops.append(["splat", p, dir.normalized()])

func scorch(p: Vector2, r: float) -> void:
	ops.append(["scorch", p, r])

func patch(r: Rect2, c: Color) -> void:
	ops.append(["rect", r, c])
