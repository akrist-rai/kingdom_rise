class_name ArtProps
extends RefCounted
## Vector drawings for weapons, environment props, flags, fires and projectiles in the
## "painted poster" style. Sizes and weapon pivots match the original sprites so the
## gameplay code that positions them is unchanged.

const W := {
	"jian": {"size": Vector2(22, 7), "pivot": Vector2(3, 3)},
	"glaive": {"size": Vector2(40, 11), "pivot": Vector2(9, 5)},
	"spear": {"size": Vector2(38, 9), "pivot": Vector2(11, 4)},
	"daggers": {"size": Vector2(13, 6), "pivot": Vector2(2, 3)},
	"axe": {"size": Vector2(26, 13), "pivot": Vector2(7, 6)},
	"zhanmadao": {"size": Vector2(31, 7), "pivot": Vector2(5, 3)},
	"shortsword": {"size": Vector2(16, 7), "pivot": Vector2(2, 3)},
	"bow": {"size": Vector2(10, 21), "pivot": Vector2(6, 10)},
	"crossbow": {"size": Vector2(18, 11), "pivot": Vector2(4, 6)},
	"hammer": {"size": Vector2(25, 11), "pivot": Vector2(7, 5)},
	"black_glaive": {"size": Vector2(48, 13), "pivot": Vector2(12, 6)},
}

static var A = null

static func _c(r: float, g: float, b: float) -> Color:
	return Color(r, g, b)

# ------------------------------------------------------------------ weapons
static func queue_weapons(art) -> void:
	A = art
	for k in W.keys():
		art.job("wpn/" + k, W[k]["size"], Callable(ArtProps, "_wpn_" + k))
	art.job("shield_qin", Vector2(10, 13), _shield.bind("qin"))
	art.job("shield_zhao", Vector2(10, 13), _shield.bind("zhao"))

static func assemble_weapons(art) -> void:
	for k in W.keys():
		var t: Texture2D = art.result("wpn/" + k)
		var pv: Vector2 = W[k]["pivot"]
		art.weapons[k] = {"tex": t, "pivot": pv, "len": W[k]["size"].x - pv.x}

static func _blade(p: Painter, pts: PackedVector2Array) -> void:
	p.shape(pts, A.STEEL[1], A.STEEL[2], A.STEEL[0], true, 0.6)

static func _grip(p: Painter, a: Vector2, b: Vector2, r: float, c: Color) -> void:
	p.shape(Painter.limb(a, b, r, r), c, c.darkened(0.35), Color(0, 0, 0, 0), true, 0.5)

static func _wpn_jian(p: Painter) -> void:
	p.ink_w = 0.35
	p.shape(Painter.circle(Vector2(1.3,3.5),1.0,8), A.GOLD[1], A.GOLD[2])
	_grip(p, Vector2(2.0,3.5), Vector2(6.0,3.5),0.65,A.LEATHER[1])
	p.shape(PackedVector2Array([Vector2(5.8,0.7),Vector2(6.9,0.5),Vector2(7.2,3.5),Vector2(6.9,6.5),Vector2(5.8,6.3),Vector2(6.2,3.5)]),A.GOLD[1],A.GOLD[2])
	_blade(p,PackedVector2Array([Vector2(7.0,2.5),Vector2(17.5,2.7),Vector2(21.6,3.5),Vector2(17.5,4.3),Vector2(7.0,4.5)]))
	p.line(Vector2(8.0,3.5),Vector2(18.7,3.5),A.STEEL[0],0.38)

static func _wpn_glaive(p: Painter) -> void:
	p.ink_w=0.35
	_grip(p,Vector2(0.8,5.5),Vector2(32.3,5.5),0.70,A.WOOD[1])
	_blade(p,PackedVector2Array([Vector2(30.5,4.5),Vector2(34,3.5),Vector2(39.7,5.5),Vector2(34,6.6),Vector2(30.5,6.5)]))
	_blade(p,PackedVector2Array([Vector2(28,4.8),Vector2(29,1.8),Vector2(34,0.5),Vector2(33.2,4.8)]))
	_blade(p,PackedVector2Array([Vector2(28,6.1),Vector2(33,6.1),Vector2(30,9.7),Vector2(26,10.2)]))
	p.shape(Painter.rect(25.2,4.1,2.0,2.8),A.GOLD[1],A.GOLD[2])

static func _wpn_spear(p: Painter) -> void:
	p.ink_w = 0.35
	_grip(p,Vector2(0.8,4.5),Vector2(29.5,4.5),0.64,A.WOOD[1])
	p.shape(Painter.rect(27.5,3.4,2.8,2.2),A.STEEL[2],A.STEEL[1])
	_blade(p,PackedVector2Array([Vector2(29.8,4.5),Vector2(32.5,2.6),Vector2(37.7,4.5),Vector2(32.5,6.4)]))
	p.line(Vector2(31,4.5),Vector2(36.4,4.5),A.STEEL[0],0.4)
	p.shape(PackedVector2Array([Vector2(26.5,5.2),Vector2(23,8.3),Vector2(27,7.4),Vector2(29,5.2)]),A.PAL["qin"]["cloth"][0],A.PAL["qin"]["cloth"][2])

static func _wpn_daggers(p: Painter) -> void:
	p.ink_w = 0.35
	_grip(p, Vector2(0.6, 3.2), Vector2(4.0, 3.2), 0.6, A.LEATHER[1])
	p.shape(Painter.rect(3.8, 1.8, 0.9, 2.8), A.GOLD[1], A.GOLD[2])
	_blade(p, PackedVector2Array([Vector2(4.7, 2.4), Vector2(10.5, 2.5), Vector2(12.6, 3.2), Vector2(10.5, 3.9), Vector2(4.7, 4.0)]))

static func _wpn_axe(p: Painter) -> void:
	p.ink_w = 0.4
	_grip(p, Vector2(0.8, 6.5), Vector2(19.0, 6.5), 0.75, A.WOOD[1])
	p.shape(Painter.rect(14.8, 5.2, 1.6, 2.6), A.GOLD[1], A.GOLD[2])
	_blade(p, Painter.blob(PackedVector2Array([Vector2(16.6, 4.6), Vector2(20.6, 2.2), Vector2(25.4, 0.6), Vector2(24.6, 6.5),
		Vector2(25.4, 12.4), Vector2(20.6, 10.8), Vector2(16.6, 8.4)]), 2))

static func _wpn_zhanmadao(p: Painter) -> void:
	p.ink_w=0.35
	p.shape(Painter.circle(Vector2(1.5,3.5),1.0,8),A.GOLD[1],A.GOLD[2])
	_grip(p,Vector2(2.1,3.5),Vector2(9.1,3.5),0.7,A.LEATHER[1])
	p.line(Vector2(8.9,0.6),Vector2(8.9,6.4),A.GOLD[0],1.0)
	_blade(p,PackedVector2Array([Vector2(9.6,2.2),Vector2(25.6,2.4),Vector2(30.5,3.5),Vector2(25.6,4.6),Vector2(9.6,4.8)]))
	p.line(Vector2(11,3.5),Vector2(27,3.5),A.STEEL[0],0.4)

static func _wpn_shortsword(p: Painter) -> void:
	p.ink_w = 0.4
	_grip(p, Vector2(0.6, 3.5), Vector2(4.0, 3.5), 0.7, A.WOOD[2])
	p.shape(Painter.rect(3.8, 1.8, 1.1, 3.4), A.GOLD[1], A.GOLD[2])
	_blade(p, PackedVector2Array([Vector2(4.9, 2.6), Vector2(13.2, 2.7), Vector2(15.4, 3.5), Vector2(13.2, 4.3), Vector2(4.9, 4.4)]))

static func _wpn_bow(p: Painter) -> void:
	p.ink_w = 0.4
	var arc := Painter.curve(PackedVector2Array([Vector2(3.4, 0.8), Vector2(6.6, 4.0), Vector2(7.4, 10.5), Vector2(6.6, 17.0), Vector2(3.4, 20.2)]))
	p.line(Vector2(3.4, 0.8), Vector2(3.4, 20.2), Color("#f3ead8"), 0.4)
	p.shape(Painter.stroke(arc, 0.65, 0.65), A.WOOD[0], A.WOOD[2])
	p.shape(Painter.rect(6.4, 8.8, 1.8, 3.4), A.LEATHER[0], A.LEATHER[1])

static func _wpn_crossbow(p: Painter) -> void:
	p.ink_w = 0.4
	p.shape(PackedVector2Array([Vector2(0.8, 5.2), Vector2(13.6, 5.2), Vector2(13.6, 7.2), Vector2(4.0, 7.2), Vector2(1.6, 8.6), Vector2(0.8, 7.6)]), A.WOOD[1], A.WOOD[2])
	p.shape(Painter.rect(5.0, 3.0, 6.0, 2.4), A.WOOD[2], Color(0, 0, 0, 0))
	var arc := Painter.curve(PackedVector2Array([Vector2(11.4, 0.6), Vector2(13.6, 5.5), Vector2(11.4, 10.4)]))
	p.shape(Painter.stroke(arc, 0.6, 0.6), A.WOOD[0], A.WOOD[2])
	p.line(Vector2(6.0, 4.2), Vector2(16.6, 4.2), A.STEEL[1], 0.6)
	p.shape(PackedVector2Array([Vector2(16.2, 3.4), Vector2(17.6, 4.2), Vector2(16.2, 5.0)]), A.STEEL[0], A.STEEL[2])

static func _wpn_hammer(p: Painter) -> void:
	p.ink_w = 0.4
	_grip(p, Vector2(0.8, 5.5), Vector2(18.0, 5.5), 0.75, A.WOOD[1])
	p.shape(Painter.rect(15.0, 3.6, 2.0, 3.8), A.GOLD[1], A.GOLD[2])
	p.shape(Painter.blob(PackedVector2Array([Vector2(17.0, 1.2), Vector2(23.4, 1.0), Vector2(24.0, 5.5), Vector2(23.4, 10.0), Vector2(17.0, 9.8)]), 2), A.STEEL[1], A.STEEL[2], A.STEEL[0])

static func _wpn_black_glaive(p: Painter) -> void:
	p.ink_w = 0.45
	var g: Dictionary = A.PAL["general"]
	_grip(p, Vector2(0.8, 6.5), Vector2(33.0, 6.5), 0.8, Color("#3a3448"))
	p.shape(Painter.rect(29.0, 7.2, 3.0, 4.6), g["cloth"][1], g["cloth"][2])
	p.shape(Painter.rect(32.2, 4.4, 2.2, 4.4), g["trim"], Color("#9a7a3a"))
	var bl := PackedVector2Array([Vector2(34.4, 5.2), Vector2(37.0, 3.4), Vector2(42.0, 1.6), Vector2(47.4, 0.6), Vector2(45.6, 4.6),
		Vector2(41.0, 8.4), Vector2(36.6, 9.4), Vector2(34.4, 8.6)])
	p.shape(bl, Color("#6f6a92"), Color("#36334c"), Color("#d8d2ff"), true, 0.6)
	p.line(Vector2(36.0, 4.6), Vector2(45.6, 1.8), Color("#ffffff"), 0.4)

static func _shield(p: Painter, fac: String) -> void:
	var pal: Dictionary = A.PAL[fac]
	var shape := PackedVector2Array([Vector2(1,1),Vector2(9,1),Vector2(8.6,7),Vector2(5,12.2),Vector2(1.4,7)])
	p.shape(shape,pal["cloth"][1],pal["cloth"][2])
	p.line(Vector2(5,1.7),Vector2(5,10.8),pal["trim"],0.8)
	p.line(Vector2(1.8,4.5),Vector2(8.2,4.5),pal["trim"],0.8)
	p.ink(shape,true,0.65)

# ------------------------------------------------------------------ props
static func queue_props(art) -> void:
	A = art
	for v in 3:
		art.job("rock%d" % v, Vector2(16 + v * 4, 11 + v * 2), _rock.bind(v))
	art.job("sword_stuck", Vector2(7, 15), _sword_stuck)
	art.job("sword_tilt", Vector2(10, 15), _sword_tilt)
	art.job("arrow_stuck", Vector2(6, 10), _arrow_stuck, 0.35)
	art.job("spear_stuck", Vector2(16, 24), _spear_stuck)
	art.job("shield_drop", Vector2(9, 6), _shield_drop)
	art.job("dead_tree", Vector2(26, 34), _dead_tree)
	art.job("pine", Vector2(26, 42), _pine)
	for fac in ["qin", "zhao"]:
		for f in 3:
			art.job("banner_%s_%d" % [fac, f], Vector2(23, 54), _flag.bind(fac, f, 18, 20, 50))
			art.job("gbanner_%s_%d" % [fac, f], Vector2(31, 82), _flag.bind(fac, f, 26, 28, 78))
		art.job("tent_" + fac, Vector2(44, 32), _tent.bind(fac))
	art.job("brazier", Vector2(10, 10), _brazier)
	art.job("lantern", Vector2(5, 8), _lantern)
	art.job("stakes", Vector2(16, 12), _stakes)
	art.job("barrel", Vector2(9, 10), _barrel)
	art.job("stall", Vector2(48, 36), _stall)
	art.job("drum", Vector2(14, 14), _drum)
	art.job("wreck_tower", Vector2(56, 44), _wreck_tower)
	art.job("wreck_cart", Vector2(36, 24), _wreck_cart)
	art.job("wreck_chariot", Vector2(34, 28), _wreck_chariot)
	art.job("stele", Vector2(14, 30), _stele)
	for v in 4:
		art.job("grass%d" % v, Vector2(7, 6), _grass.bind(v), 0.0)
	for f in 4:
		art.job("flame_big%d" % f, Vector2(14, 24), _flame.bind(f, 1), 0.0)
		art.job("flame_med%d" % f, Vector2(10, 16), _flame.bind(f, 2), 0.0)
		art.job("flame_sm%d" % f, Vector2(6, 10), _flame.bind(f, 3), 0.0)
	for v in 3:
		art.job("tallgrass%d" % v, Vector2(14, 18), _tallgrass.bind(v), 0.3)
	art.job("gold_sword", Vector2(7, 20), _gold_sword)
	art.job("gold_sword_stuck", Vector2(9, 16), _gold_sword_stuck)
	art.job("arrow", Vector2(11, 3), _arrow, 0.35)
	art.job("bolt", Vector2(8, 3), _bolt, 0.35)

static func _snowcap(p: Painter, pts: PackedVector2Array) -> void:
	p.shape(pts, A.SNOW[0], A.SNOW[1], Color(0, 0, 0, 0), false)

static func _rock(p: Painter, v: int) -> void:
	var w := 14.0 + v * 4.0
	var h := 9.0 + v * 2.0
	var c := Vector2((w + 2.0) * 0.5, h * 0.5 + 2.0)
	var rk := Painter.blob(PackedVector2Array([c + Vector2(-w * 0.5, h * 0.25), c + Vector2(-w * 0.35, -h * 0.3), c + Vector2(0, -h * 0.48),
		c + Vector2(w * 0.4, -h * 0.25), c + Vector2(w * 0.5, h * 0.3), c + Vector2(0, h * 0.48)]), 3)
	p.shape(rk, Color("#7a7fa6"), Color("#474b72"), Color(0, 0, 0, 0), true, 1.4)
	var cap := Painter.blob(PackedVector2Array([c + Vector2(-w * 0.42, -h * 0.05), c + Vector2(-w * 0.3, -h * 0.36), c + Vector2(0, -h * 0.5),
		c + Vector2(w * 0.38, -h * 0.28), c + Vector2(w * 0.3, -h * 0.02), c + Vector2(0, h * 0.06)]), 3)
	_snowcap(p, cap)
	p.ink(rk)

static func _sword_stuck(p: Painter) -> void:
	p.ink_w = 0.35
	p.shape(Painter.rect(3.0, 0.0, 1.0, 3.2), A.WOOD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(1.0, 3.0, 5.0, 1.0), A.GOLD[1], A.GOLD[2])
	_blade(p, PackedVector2Array([Vector2(2.9, 4.0), Vector2(4.1, 4.0), Vector2(4.0, 13.4), Vector2(3.0, 13.4)]))
	p.shape(Painter.ellipse(Vector2(3.5, 13.6), 3.0, 0.9, 10), A.SNOW[1], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _sword_tilt(p: Painter) -> void:
	p.ink_w = 0.35
	p.shape(Painter.limb(Vector2(2, 0.5), Vector2(3.2, 2.6), 0.5, 0.5), A.WOOD[2], Color(0, 0, 0, 0))
	p.shape(Painter.limb(Vector2(1.0, 3.2), Vector2(5.4, 2.2), 0.5, 0.5), A.GOLD[1], A.GOLD[2])
	_blade(p, Painter.limb(Vector2(3.6, 3.4), Vector2(7.4, 12.6), 0.6, 0.35))
	p.shape(Painter.ellipse(Vector2(7.0, 13.4), 3.0, 0.9, 10), A.SNOW[1], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _arrow_stuck(p: Painter) -> void:
	p.ink_w = 0.3
	p.line(Vector2(1.2, 1.2), Vector2(4.4, 8.6), A.WOOD[1], 0.55)
	p.shape(PackedVector2Array([Vector2(0.2, 0.2), Vector2(2.4, 0.6), Vector2(1.6, 2.4)]), Color("#f4ece0"), Color("#c2b8a8"))
	p.line(Vector2(2.0, 1.4), Vector2(2.6, 2.6), Color("#d8323a"), 0.5)

static func _spear_stuck(p: Painter) -> void:
	p.ink_w = 0.35
	p.line(Vector2(2.0, 22.4), Vector2(13.0, 3.4), A.WOOD[1], 0.8)
	p.shape(PackedVector2Array([Vector2(12.4, 3.4), Vector2(15.2, 0.0), Vector2(13.8, 4.4)]), A.STEEL[1], A.STEEL[2])
	p.shape(PackedVector2Array([Vector2(11.0, 5.0), Vector2(12.4, 4.4), Vector2(11.6, 7.6), Vector2(10.2, 6.8)]), A.PAL["zhao"]["cloth"][1], A.PAL["zhao"]["cloth"][2])
	p.shape(Painter.ellipse(Vector2(2.6, 22.6), 2.6, 0.8, 10), A.SNOW[1], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _shield_drop(p: Painter) -> void:
	p.shape(Painter.ellipse(Vector2(4.5, 3.0), 4.0, 2.5, 14), A.PAL["zhao"]["armor"][1], A.PAL["zhao"]["armor"][2])
	p.shape(Painter.ellipse(Vector2(4.5, 2.7), 2.4, 1.4, 12), A.PAL["zhao"]["cloth"][1], Color(0, 0, 0, 0))

static func _dead_tree(p: Painter) -> void:
	var bark := Color("#3b2a30")
	var trunk := Painter.stroke(Painter.curve(PackedVector2Array([Vector2(13, 33.6), Vector2(13.4, 24.0), Vector2(12.6, 16.0), Vector2(13.2, 7.0)])), 1.6, 0.6)
	p.shape(trunk, Color("#5a4048"), bark)
	for br in [[Vector2(13, 19), Vector2(8, 13), Vector2(3.6, 9.6)], [Vector2(13.2, 15), Vector2(18, 9), Vector2(22.4, 5.0)],
			[Vector2(13, 11), Vector2(10.6, 5), Vector2(9.2, 1.6)], [Vector2(8.6, 14.6), Vector2(5.0, 14.4), Vector2(2.6, 13.2)],
			[Vector2(18.4, 9.4), Vector2(21.4, 10.6), Vector2(23.6, 11.4)]]:
		p.shape(Painter.stroke(Painter.curve(PackedVector2Array(br)), 0.7, 0.2), Color("#5a4048"), bark)
	for q in [Vector2(4.2, 9.0), Vector2(21.6, 4.6), Vector2(9.2, 1.4), Vector2(12.6, 6.8)]:
		p.shape(Painter.ellipse(q, 1.2, 0.5, 8), A.SNOW[0], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _pine(p: Painter) -> void:
	p.shape(Painter.rect(11.8, 33.0, 2.4, 8.0), Color("#5a4048"), Color("#3b2a30"))
	for layer in 4:
		var top := 2.0 + layer * 8.0
		var half := 4.6 + layer * 2.4
		var tri := PackedVector2Array([Vector2(13, top), Vector2(13 + half, top + 11.0), Vector2(13 - half, top + 11.0)])
		p.shape(tri, Color("#3f6a5e"), Color("#24443f"), Color(0, 0, 0, 0), true, 1.5)
		var cap := PackedVector2Array([Vector2(13, top), Vector2(13 + half * 0.55, top + 5.6), Vector2(13 + half * 0.2, top + 4.6),
			Vector2(13 - half * 0.1, top + 6.0), Vector2(13 - half * 0.5, top + 5.4)])
		_snowcap(p, cap)

## A swallow-tailed war banner: the fly end splits into three streaming tails that ripple
## with the animation frame. Qin flies red with a dark character, Zhao blue with a pale one.
static func _flag(p: Painter, fac: String, f: int, cw: int, ch: int, pole: int) -> void:
	var pal: Dictionary = A.PAL[fac]
	var cl: Array = pal["cloth"]
	var trim: Color = pal["trim"]
	var em: Color = Color("#1a0d12") if fac == "qin" else Color("#eef1ff")
	p.shape(Painter.rect(1.0, 2.0, 1.6, pole), A.WOOD[2], Color("#1d140f"))
	p.shape(Painter.rect(0.2, 0.2, 3.2, 2.2), A.GOLD[1], A.GOLD[2])
	var x0 := 2.6
	var y0 := 3.0
	var body_w := cw * 0.62
	var ph := f * 2.09
	var wave := func(x: float) -> float:
		var k := (x - x0) / cw
		return sin(k * 3.6 + ph) * 1.5 * k
	var top := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var x := x0 + body_w * i / steps
		top.append(Vector2(x, y0 + wave.call(x)))
	# three tails, each a tapered ribbon flowing out from the body
	var tails := PackedVector2Array()
	var tips := [0.12, 0.5, 0.88]
	var roots := [[0.0, 0.3], [0.36, 0.64], [0.7, 1.0]]
	for t in 3:
		var tl: float = [1.0, 0.86, 1.0][t] * cw
		var ty: float = y0 + ch * tips[t]
		var r0: float = y0 + ch * roots[t][0]
		var r1: float = y0 + ch * roots[t][1]
		var sway := sin(ph + t * 1.3) * 2.2
		var tip := Vector2(x0 + tl, ty + sway + wave.call(x0 + tl))
		var mid := Vector2(x0 + (body_w + tl) * 0.5, lerpf((r0 + r1) * 0.5, ty, 0.5) + sway * 0.5 + wave.call(x0 + (body_w + tl) * 0.5))
		tails.append(Vector2(x0 + body_w, r0 + wave.call(x0 + body_w)))
		tails.append(mid + Vector2(0, -(r1 - r0) * 0.22))
		tails.append(tip)
		tails.append(mid + Vector2(0, (r1 - r0) * 0.22))
		tails.append(Vector2(x0 + body_w, r1 + wave.call(x0 + body_w)))
	var cloth := PackedVector2Array(top)
	cloth.append_array(tails)
	var bot := PackedVector2Array()
	for i in steps + 1:
		var x := x0 + body_w * (steps - i) / steps
		bot.append(Vector2(x, y0 + ch + wave.call(x) * 1.1))
	cloth.append_array(bot)
	p.shape(cloth, cl[1], cl[2], cl[0], true, 1.2)
	# fold shading bands
	for i in steps:
		var k := float(i) / steps
		if cos(k * 2.2 + ph) * k < -0.25:
			p.fill(PackedVector2Array([top[i], top[i + 1], bot[steps - i - 1], bot[steps - i]]), Color(cl[2].r, cl[2].g, cl[2].b, 0.5))
	# the state's character
	# Heraldic sun / cross device, drawn into the cloth rather than a raster label.
	var center := Vector2(x0+body_w*0.5,y0+ch*0.45)
	center.y += wave.call(center.x)
	var radius := minf(body_w,ch)*0.23
	if fac == "qin":
		p.fill(Painter.circle(center,radius,8),em)
		p.fill(Painter.circle(center,radius*0.5,8),pal["cloth"][1])
	else:
		p.line(center-Vector2(radius,0),center+Vector2(radius,0),em,1.4)
		p.line(center-Vector2(0,radius),center+Vector2(0,radius),em,1.4)
	p.line(top[0], top[steps], trim, 0.5)
	p.ink(cloth)

static func _tent(p: Painter, fac: String) -> void:
	var pal: Dictionary = A.PAL[fac]
	var canvas := Color("#efe2c4") if fac == "qin" else Color("#b2acd4")
	var shade := Color("#bfa983") if fac == "qin" else Color("#76709c")
	var body := PackedVector2Array([Vector2(22, 4.0), Vector2(41.0, 29.6), Vector2(3.0, 29.6)])
	p.shape(body, canvas, shade, Color(0, 0, 0, 0), true, 2.4)
	for i in 4:
		var x := 9.0 + i * 9.0
		p.line(Vector2(22, 4.6), Vector2(x, 29.4), pal["cloth"][1], 0.5)
	p.shape(PackedVector2Array([Vector2(22, 17.0), Vector2(26.4, 29.6), Vector2(17.6, 29.6)]), Color("#2b2230"), Color(0, 0, 0, 0))
	_snowcap(p, PackedVector2Array([Vector2(22, 4.0), Vector2(30.0, 14.0), Vector2(26.0, 13.0), Vector2(22, 15.0), Vector2(17.0, 12.6), Vector2(14.0, 14.0)]))
	p.ink(body)
	p.line(Vector2(22, 4.2), Vector2(22, 0.2), A.WOOD[2], 0.6)
	p.shape(PackedVector2Array([Vector2(22.3, 0.2), Vector2(27.0, 1.2), Vector2(22.3, 2.8)]), pal["cloth"][0], pal["cloth"][2])

static func _brazier(p: Painter) -> void:
	p.line(Vector2(2.6, 6.0), Vector2(1.4, 9.6), Color("#2a252e"), 0.7)
	p.line(Vector2(7.4, 6.0), Vector2(8.6, 9.6), Color("#2a252e"), 0.7)
	p.shape(PackedVector2Array([Vector2(1.0, 2.2), Vector2(9.0, 2.2), Vector2(7.6, 6.2), Vector2(2.4, 6.2)]), Color("#4a4250"), Color("#26212c"))
	p.shape(Painter.ellipse(Vector2(5, 2.2), 4.0, 1.0, 10), Color("#ff9a3c"), Color("#c24a20"))

static func _lantern(p: Painter) -> void:
	p.ink_w = 0.3
	p.line(Vector2(2.5, 0.0), Vector2(2.5, 1.8), Color("#2a252e"), 0.5)
	p.shape(Painter.blob(PackedVector2Array([Vector2(2.5, 1.6), Vector2(4.2, 3.0), Vector2(4.0, 5.8), Vector2(2.5, 6.6), Vector2(1.0, 5.8), Vector2(0.8, 3.0)]), 2), Color("#ffd27a"), Color("#e2752c"))
	p.shape(Painter.rect(1.2, 6.4, 2.6, 1.0), Color("#3b2b26"), Color(0, 0, 0, 0))

static func _stakes(p: Painter) -> void:
	p.shape(Painter.limb(Vector2(1.0, 11.4), Vector2(12.6, 0.6), 0.8, 0.5), A.WOOD[1], A.WOOD[2])
	p.shape(Painter.limb(Vector2(3.0, 0.6), Vector2(14.8, 11.4), 0.8, 0.5), A.WOOD[0], A.WOOD[2])
	p.shape(Painter.ellipse(Vector2(8, 5.6), 2.0, 0.8, 8), A.SNOW[0], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _barrel(p: Painter) -> void:
	p.shape(Painter.blob(PackedVector2Array([Vector2(1.2, 1.4), Vector2(7.8, 1.4), Vector2(8.4, 5.0), Vector2(7.8, 9.0), Vector2(1.2, 9.0), Vector2(0.6, 5.0)]), 2), A.WOOD[1], A.WOOD[2])
	p.line(Vector2(0.8, 3.6), Vector2(8.2, 3.6), Color("#3b3540"), 0.6)
	p.line(Vector2(0.8, 6.8), Vector2(8.2, 6.8), Color("#3b3540"), 0.6)
	p.shape(Painter.ellipse(Vector2(4.5, 1.6), 3.4, 0.9, 10), A.SNOW[0], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _stall(p: Painter) -> void:
	p.shape(Painter.rect(4, 12, 2, 22), A.WOOD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(42, 12, 2, 22), A.WOOD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(6, 15, 36, 10), Color("#ffb85c"), Color("#e2852e"))
	p.shape(Painter.ellipse(Vector2(22, 19.5), 4.0, 2.0, 12), Color("#5b5560"), Color("#3a3540"))
	p.shape(PackedVector2Array([Vector2(1.0, 15.2), Vector2(4.0, 7.6), Vector2(44.0, 7.6), Vector2(47.0, 15.2)]), Color("#f2e6c8"), Color("#c6b48e"), Color(0, 0, 0, 0), true, 1.4)
	for x in range(4, 46, 7):
		p.fill(PackedVector2Array([Vector2(x, 15.0), Vector2(x + 3.5, 15.0), Vector2(x + 1.75, 17.2)]), Color("#c6b48e"))
	_snowcap(p, PackedVector2Array([Vector2(4.2, 7.4), Vector2(44.0, 7.4), Vector2(42.0, 9.4), Vector2(30, 8.6), Vector2(18, 9.6), Vector2(6, 8.8)]))
	p.shape(Painter.rect(3, 25, 42, 4), A.WOOD[0], A.WOOD[1])
	p.shape(Painter.rect(5, 29, 2, 6), A.WOOD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(41, 29, 2, 6), A.WOOD[2], Color(0, 0, 0, 0))
	for x in [12.0, 32.0]:
		p.shape(Painter.ellipse(Vector2(x, 24.4), 1.8, 0.8, 8), Color("#f6ecdc"), Color(0, 0, 0, 0))

static func _drum(p: Painter) -> void:
	p.line(Vector2(2.4, 8.6), Vector2(1.0, 13.6), A.WOOD[2], 0.8)
	p.line(Vector2(11.6, 8.6), Vector2(13.0, 13.6), A.WOOD[2], 0.8)
	p.shape(Painter.ellipse(Vector2(7, 6.4), 6.0, 4.4, 16), Color("#b8323a"), Color("#6e1a22"))
	p.shape(Painter.ellipse(Vector2(7, 4.6), 5.6, 2.4, 16), Color("#f2e6c8"), Color("#c6b48e"))
	p.line(Vector2(4.2, 9.0), Vector2(9.8, 9.0), A.GOLD[1], 0.7)

static func _wreck_tower(p: Painter) -> void:
	p.shape(Painter.ellipse(Vector2(28, 40), 26, 3.6, 20), Color("#3a3038"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)
	for k in 7:
		p.shape(Painter.limb(Vector2(5 + k * 7, 41), Vector2(11 + k * 7, 37), 0.9, 0.9), A.WOOD[1 + k % 2], A.WOOD[2])
	var char := Color("#2e2224")
	p.shape(Painter.limb(Vector2(9, 40), Vector2(31, 7), 1.2, 1.0), A.WOOD[1], char)
	p.shape(Painter.limb(Vector2(24, 41), Vector2(46, 10), 1.2, 1.0), A.WOOD[2], char)
	for k in 5:
		var t := 0.12 + k * 0.19
		var a := Vector2(9, 40).lerp(Vector2(31, 7), t)
		var b := Vector2(24, 41).lerp(Vector2(46, 10), t)
		p.shape(Painter.limb(a, b, 0.6, 0.6), A.WOOD[k % 2], char)
	p.shape(Painter.limb(Vector2(29, 6), Vector2(50, 9), 1.0, 0.9), A.WOOD[0], char)
	p.shape(Painter.rect(33, 3.6, 10, 2.4), Color("#6b4a36"), char)
	p.shape(PackedVector2Array([Vector2(36, 10), Vector2(40, 10), Vector2(38.6, 16), Vector2(36.6, 15)]), Color("#8a6a50"), Color("#5a4030"))
	var wh := Painter.circle(Vector2(47, 37), 5.0, 16)
	p.shape(wh, A.WOOD[2], char)
	p.line(Vector2(42.2, 37), Vector2(51.8, 37), A.WOOD[1], 0.8)
	p.line(Vector2(47, 32.2), Vector2(47, 41.8), A.WOOD[1], 0.8)
	for q in [Vector2(30, 6), Vector2(41, 7), Vector2(10, 39)]:
		p.shape(Painter.ellipse(q, 2.0, 0.6, 8), A.SNOW[0], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _wreck_cart(p: Painter) -> void:
	p.shape(Painter.ellipse(Vector2(18, 21), 16, 2.6, 18), Color("#3a3038"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)
	p.shape(PackedVector2Array([Vector2(4, 8), Vector2(24, 4), Vector2(28.6, 13.4), Vector2(8.6, 17.4)]), A.WOOD[1], A.WOOD[2], A.WOOD[0])
	for k in 3:
		p.line(Vector2(5.4 + k * 1.2, 11 + k * 2), Vector2(25.4 + k * 1.2, 7 + k * 2), A.WOOD[2], 0.4)
	p.shape(Painter.limb(Vector2(26, 14), Vector2(35, 20), 0.6, 0.5), A.WOOD[1], A.WOOD[2])
	var wh := Painter.ellipse(Vector2(12, 18), 6, 4, 16)
	p.shape(wh, A.WOOD[2], Color("#2e2224"))
	p.line(Vector2(7, 18), Vector2(17, 18), A.WOOD[1], 0.7)
	p.line(Vector2(12, 14.2), Vector2(12, 21.8), A.WOOD[1], 0.7)
	p.shape(Painter.ellipse(Vector2(30, 18), 3, 2, 10), Color("#d8c49a"), Color("#a8946a"))
	p.shape(Painter.ellipse(Vector2(26, 20), 3, 2, 10), Color("#c8b48a"), Color("#98845a"))

static func _wreck_chariot(p: Painter) -> void:
	p.shape(Painter.ellipse(Vector2(17, 25), 15, 2.4, 18), Color("#3a3038"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)
	p.shape(Painter.rect(16, 13, 12, 8), A.WOOD[1], A.WOOD[2], A.WOOD[0])
	p.shape(Painter.rect(17, 15, 10, 1.2), A.PAL["zhao"]["cloth"][1], Color(0, 0, 0, 0))
	p.shape(Painter.limb(Vector2(27, 19), Vector2(33, 24), 0.9, 0.7), A.WOOD[2], Color(0, 0, 0, 0))
	var wh := Painter.circle(Vector2(11, 15), 9.0, 20)
	p.shape(wh, A.WOOD[2], Color("#2e2224"))
	p.fill(Painter.circle(Vector2(11, 15), 7.0, 18), Color(0.0, 0.0, 0.0, 0.0))
	for k in 8:
		var a := k * TAU / 8.0
		p.line(Vector2(11, 15), Vector2(11, 15) + Vector2.from_angle(a) * 7.2, A.WOOD[1], 0.6)
	p.shape(Painter.circle(Vector2(11, 15), 1.6, 10), A.GOLD[1], A.GOLD[2])

static func _stele(p: Painter) -> void:
	p.shape(Painter.rect(1, 24, 12, 5), Color("#5d5a74"), Color("#3e3c52"))
	p.shape(PackedVector2Array([Vector2(3, 4), Vector2(5, 2), Vector2(9, 2), Vector2(11, 4), Vector2(11, 24), Vector2(3, 24)]), Color("#827ea0"), Color("#55526e"), Color(0, 0, 0, 0), true, 1.2)
	for yy in range(7, 22, 3):
		p.line(Vector2(5.4, yy), Vector2(8.4, yy), Color("#45425a"), 0.6)
	_snowcap(p, PackedVector2Array([Vector2(3, 4), Vector2(5, 1.8), Vector2(9, 1.8), Vector2(11, 4), Vector2(8, 4.8), Vector2(6, 4.2)]))

static func _grass(p: Painter, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + v
	for k in 3 + v % 2:
		var x := rng.randf_range(1.0, 6.0)
		var hgt := rng.randf_range(2.5, 5.5)
		var lean := rng.randf_range(-1.4, 1.4)
		var path := Painter.curve(PackedVector2Array([Vector2(x, 6.0), Vector2(x + lean * 0.3, 6.0 - hgt * 0.5), Vector2(x + lean, 6.0 - hgt)]), 3)
		p.fill(Painter.stroke(path, 0.45, 0.1), Color("#6a6440") if k % 2 == 0 else Color("#8c8256"))

static func _flame(p: Painter, f: int, size: int) -> void:
	var w: float = [0.0, 14.0, 10.0, 6.0][size]
	var h: float = [0.0, 24.0, 16.0, 10.0][size]
	var cx := w * 0.5
	var sway: float = [0.0, 0.8, -0.3, -0.9][f] * w * 0.08
	var tip: float = [0.0, -0.06, 0.04, -0.02][f] * h
	var layers := [[1.0, Color("#d8322a")], [0.72, Color("#ff7a2a")], [0.48, Color("#ffcf4a")], [0.24, Color("#fff4cf")]]
	for L in layers:
		var k: float = L[0]
		var hh := h * k
		var ww := w * 0.5 * k
		var base_y := h - 0.4
		var pts := Painter.blob(PackedVector2Array([Vector2(cx - ww, base_y - hh * 0.25), Vector2(cx - ww * 0.55 + sway * 0.5, base_y - hh * 0.62),
			Vector2(cx + sway, base_y - hh + tip * k), Vector2(cx + ww * 0.6 + sway * 0.4, base_y - hh * 0.55), Vector2(cx + ww, base_y - hh * 0.2),
			Vector2(cx, base_y)]), 3)
		p.fill(pts, L[1])

## A clump of tall dry winter grass, dark slate blades with frost-pale tips.
static func _tallgrass(p: Painter, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91 + v * 17
	var n := 7 + v * 2
	var blades: Array = []
	for i in n:
		var bx := 7.0 + rng.randf_range(-4.5, 4.5)
		var h := rng.randf_range(9.0, 17.0)
		var lean := rng.randf_range(-3.5, 3.5) + (bx - 7.0) * 0.4
		blades.append([bx, h, lean, rng.randf()])
	blades.sort_custom(func(a, b): return a[1] > b[1])
	for b in blades:
		var bx: float = b[0]
		var h: float = b[1]
		var lean: float = b[2]
		var path := Painter.curve(PackedVector2Array([Vector2(bx, 17.6), Vector2(bx + lean * 0.3, 17.6 - h * 0.55), Vector2(bx + lean, 17.6 - h)]), 4)
		var dark := Color("#1d2c36") if b[3] < 0.5 else Color("#2b3b45")
		p.fill(Painter.stroke(path, 0.55, 0.08), dark)
		var tip := Painter.curve(PackedVector2Array([path[path.size() - 4], path[path.size() - 1]]), 2)
		p.polyline(tip, Color("#c9d3d8"), 0.3)

static func _gold_sword(p: Painter) -> void:
	p.ink_col = Color("#5a3510")
	p.ink_w = 0.4
	p.shape(Painter.rect(3.0, 0.0, 1.0, 3.0), A.GOLD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(0.4, 2.8, 6.2, 1.1), A.GOLD[0], A.GOLD[1])
	p.shape(PackedVector2Array([Vector2(2.2, 3.9), Vector2(4.8, 3.9), Vector2(4.6, 17.0), Vector2(3.5, 19.6), Vector2(2.4, 17.0)]), Color("#fff2b8"), Color("#e8b84a"), Color("#ffffff"))

static func _gold_sword_stuck(p: Painter) -> void:
	p.ink_col = Color("#5a3510")
	p.ink_w = 0.4
	p.shape(Painter.rect(4.0, 0.0, 1.0, 3.0), A.GOLD[2], Color(0, 0, 0, 0))
	p.shape(Painter.rect(1.4, 2.8, 6.2, 1.1), A.GOLD[0], A.GOLD[1])
	p.shape(PackedVector2Array([Vector2(3.2, 3.9), Vector2(5.8, 3.9), Vector2(5.6, 13.4), Vector2(3.4, 13.4)]), Color("#fff2b8"), Color("#e8b84a"), Color("#ffffff"))
	p.shape(Painter.ellipse(Vector2(4.5, 13.6), 3.6, 1.0, 10), A.SNOW[1], Color(0, 0, 0, 0), Color(0, 0, 0, 0), false)

static func _arrow(p: Painter) -> void:
	p.ink_w = 0.25
	p.line(Vector2(2.0, 1.5), Vector2(9.0, 1.5), A.WOOD[0], 0.55)
	p.shape(PackedVector2Array([Vector2(8.6, 0.4), Vector2(10.8, 1.5), Vector2(8.6, 2.6)]), A.STEEL[0], A.STEEL[2])
	p.shape(PackedVector2Array([Vector2(0.2, 0.3), Vector2(2.6, 1.2), Vector2(2.6, 1.8), Vector2(0.2, 2.7), Vector2(1.0, 1.5)]), Color("#f4ece0"), Color("#c2b8a8"))

static func _bolt(p: Painter) -> void:
	p.ink_w = 0.25
	p.line(Vector2(0.4, 1.5), Vector2(6.2, 1.5), A.WOOD[1], 0.6)
	p.shape(PackedVector2Array([Vector2(5.8, 0.5), Vector2(7.8, 1.5), Vector2(5.8, 2.5)]), A.STEEL[0], A.STEEL[2])
