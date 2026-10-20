extends Node
## Baked soldier sprites (tools/bake_units.gd renders the CC0 KayKit characters into atlases).
## Every frame is {tex, rect, ax, ay, w}: the atlas page, the region, and the foot anchor
## inside the region. Directions: 8 on screen, 5 baked (e, se, s, ne, n); the west-facing three
## are mirrored. Faction colours come from shaders/unit.gdshader (team cloth is a green key).

const DIR := "res://assets/units/"
## screen direction index (0 = east, clockwise, y down) -> [baked key, mirrored]
const DIR8 := [["e", false], ["se", false], ["s", false], ["se", true], ["e", true], ["ne", true], ["n", false], ["ne", false]]

## weapon id -> [animation set, weapon layer]
const LOADOUT := {
	"jian": ["1h", "sword"], "sword_shield": ["1h", "sword_shield"], "sidearm": ["1h", "knife"],
	"daggers": ["dual", "daggers"], "glaive": ["2h", "glaive"], "spear": ["2h", "spear"], "axe": ["2h", "axe"],
	"hammer": ["2h", "hammer"], "zhanmadao": ["2h", "greatsword"], "black_glaive": ["2h", "black_glaive"],
	"bow": ["ranged", "bow"], "crossbow": ["ranged", "crossbow"],
}

## faction palettes: [team_hi, team_mid, team_lo, steel tint]
const PALETTES := {
	"march": [Color("#e8664a"), Color("#c02c26"), Color("#3d0a12"), Vector3(1.12, 1.0, 0.84)],
	"crown": [Color("#86c6e8"), Color("#2f6f9e"), Color("#0b1d33"), Vector3(0.8, 0.92, 1.14)],
	"hero": [Color("#ffb070"), Color("#e0402c"), Color("#4a0c10"), Vector3(1.28, 1.06, 0.6)],
	"crown_elite": [Color("#7fa6ff"), Color("#24387a"), Color("#080c22"), Vector3(0.78, 0.82, 0.96)],
	"general": [Color("#d6a8ff"), Color("#6b2fb0"), Color("#1a0830"), Vector3(0.62, 0.58, 0.74)],
	"march_elite": [Color("#ffc46b"), Color("#b5532a"), Color("#3a120a"), Vector3(1.12, 1.0, 0.8)],
}

var meta := {}
var sheets := {}           # sheet name -> {anim key: Array[frame dict]}
var trails := {}           # "set/anim/dir" -> PackedVector2Array (pixels from the foot)
var anim_info := {}        # "set/anim" -> {len, windup, active, swing}
var saddle := {}           # "horse anim/dir" -> PackedVector2Array: where the rider sits (world units)
var materials := {}        # palette -> ShaderMaterial
var R := 3.0
var ready_ok := false

func _ready() -> void:
	var path := DIR + "units.json"
	if not FileAccess.file_exists(path):
		push_warning("UnitArt: no baked units (run tools/bake_units.gd)")
		return
	meta = JSON.parse_string(FileAccess.get_file_as_string(path))
	R = float(meta["r"])
	for group in ["bodies", "weapons"]:
		for name in meta[group].keys():
			_load_sheet(name, meta[group][name])
	for k in meta["trails"].keys():
		var pts := PackedVector2Array()
		for p in meta["trails"][k]:
			pts.append(Vector2(p[0], p[1]) / R)
		trails[k] = pts
	anim_info = meta["anims"]
	for k in meta.get("saddle", {}).keys():
		var sp := PackedVector2Array()
		for p in meta["saddle"][k]:
			sp.append(Vector2(p[0], p[1]) / R)
		saddle[k] = sp
	var sh: Shader = load("res://shaders/unit.gdshader")
	for k in PALETTES.keys():
		var p: Array = PALETTES[k]
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("team_hi", p[0])
		m.set_shader_parameter("team_mid", p[1])
		m.set_shader_parameter("team_lo", p[2])
		m.set_shader_parameter("steel_tint", p[3])
		materials[k] = m
	ready_ok = true

func _load_sheet(name: String, d: Dictionary) -> void:
	var pages: Array = []
	for f in d["pages"]:
		pages.append(load(DIR + f))
	var anims := {}
	for key in d["anims"].keys():
		var arr: Array = []
		for fr in d["anims"][key]:
			if fr == null:
				arr.append(null)
			else:
				arr.append({"tex": pages[int(fr[0])], "rect": Rect2(fr[1], fr[2], fr[3], fr[4]),
					"ax": float(fr[5]), "ay": float(fr[6]), "w": float(fr[3])})
		anims[key] = arr
	sheets[name] = anims

func has_sheet(name: String) -> bool:
	return sheets.has(name)

## The body sheet a soldier wears: knights by default, barbarians for heavy infantry and
## hooded rogues for archers when their weapon fits that body's baked animation set.
func body_sheet(kind: String, weapon_id: String) -> String:
	var aset: String = LOADOUT.get(weapon_id, ["1h", "sword"])[0]
	var want := "knight"
	match kind:
		"heavy":
			want = "barbarian"
		"archer":
			want = "rogue"
	var n := "%s_%s" % [want, aset]
	if sheets.has(n):
		return n
	return "knight_%s" % aset

func weapon_sheet(weapon_id: String) -> String:
	var l: Array = LOADOUT.get(weapon_id, ["1h", "sword"])
	return "wpn_%s_%s" % [l[0], l[1]]

func anim_set(weapon_id: String) -> String:
	return LOADOUT.get(weapon_id, ["1h", "sword"])[0]

func frames(sheet: String, anim: String, dir_key: String) -> Array:
	var s: Dictionary = sheets.get(sheet, {})
	return s.get(anim + "/" + dir_key, [])

func has_anim(sheet: String, anim: String) -> bool:
	return sheets.get(sheet, {}).has(anim + "/e")

static func dir_index(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (PI * 0.25))), 8)

## The weapon-tip path of an attack (world units from the foot), mirrored for west-facing.
func trail(aset: String, anim: String, dir8: int) -> PackedVector2Array:
	var d: Array = DIR8[dir8]
	var pts: PackedVector2Array = trails.get("%s/%s/%s" % [aset, anim, d[0]], PackedVector2Array())
	if not d[1] or pts.is_empty():
		return pts
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(-p.x, p.y))
	return out

## Mounted soldiers: the rider sheet and weapon layer for a weapon (riders bake 1h, 2h and ranged).
func rider_set(weapon_id: String) -> String:
	var s := anim_set(weapon_id)
	if s == "dual":
		return "1h"
	return s

func rider_sheet(weapon_id: String) -> String:
	return "rider_" + rider_set(weapon_id)

func rider_weapon_sheet(weapon_id: String) -> String:
	var l: Array = LOADOUT.get(weapon_id, ["1h", "sword"])
	var w: String = l[1]
	if l[0] == "dual":
		w = "knife"
	return "wpn_rider_%s_%s" % [rider_set(weapon_id), w]

## The saddle point of a horse frame (world units from the hooves), mirrored for west-facing.
func saddle_at(anim: String, dir8: int, fi: int) -> Vector2:
	var d: Array = DIR8[dir8]
	var pts: PackedVector2Array = saddle.get(anim + "/" + d[0], PackedVector2Array())
	if pts.is_empty():
		return Vector2(0, -21)
	var p := pts[clampi(fi, 0, pts.size() - 1)]
	return Vector2(-p.x, p.y) if d[1] else p

# ------------------------------------------------------------------ crowds
## Small static figures for background armies and the duel ring: baked body + weapon frames,
## composited and team-coloured on the CPU (same maths as the unit shader), shrunk to crowd size.
## Each entry: {tex (size = world units), ax, ay}.
const CROWD_SCALE := 0.62
const CROWD_SPECS := [["knight_1h", "wpn_1h_sword_shield", "idle", "s", 0], ["knight_2h", "wpn_2h_spear", "idle", "s", 1],
	["knight_1h", "wpn_1h_sword", "cheer", "s", 1], ["knight_2h", "wpn_2h_spear", "idle", "se", 2],
	["knight_2h", "wpn_2h_glaive", "idle", "s", 3], ["knight_1h", "wpn_1h_sword_shield", "idle", "se", 1],
	["knight_2h", "wpn_2h_spear", "cheer", "s", 2], ["knight_1h", "wpn_1h_sword", "idle", "n", 0]]
var _crowd := {}

func crowd_figures(palette: String) -> Array:
	if _crowd.has(palette):
		return _crowd[palette]
	var out: Array = []
	var p: Array = PALETTES.get(palette, PALETTES["march"])
	for spec in CROWD_SPECS:
		var bf: Array = frames(spec[0], spec[2], spec[3])
		if bf.is_empty():
			continue
		var fi: int = mini(spec[4], bf.size() - 1)
		var b = bf[fi]
		var wl: Array = frames(spec[1], spec[2], spec[3])
		var w = wl[fi] if fi < wl.size() else null
		# canvas around the foot anchor
		var x0 := -float(b["ax"])
		var y0 := -float(b["ay"])
		var x1: float = x0 + b["rect"].size.x
		var y1: float = y0 + b["rect"].size.y
		if w != null:
			x0 = minf(x0, -float(w["ax"]))
			y0 = minf(y0, -float(w["ay"]))
			x1 = maxf(x1, -float(w["ax"]) + w["rect"].size.x)
			y1 = maxf(y1, -float(w["ay"]) + w["rect"].size.y)
		var img := Image.create(int(ceil(x1 - x0)), int(ceil(y1 - y0)), false, Image.FORMAT_RGBA8)
		for layer in [b, w]:
			if layer == null:
				continue
			var src: Image = _atlas_image(layer["tex"])
			var reg := Rect2i(layer["rect"])
			img.blend_rect(src, reg, Vector2i(int(-float(layer["ax"]) - x0), int(-float(layer["ay"]) - y0)))
		_recolor(img, p)
		var nw := maxi(4, int(img.get_width() * CROWD_SCALE))
		var nh := maxi(4, int(img.get_height() * CROWD_SCALE))
		img.resize(nw, nh, Image.INTERPOLATE_CUBIC)
		var tex := ImageTexture.create_from_image(img)
		var k := CROWD_SCALE / R
		tex.set_size_override(Vector2i(maxi(1, int(round(img.get_width() / CROWD_SCALE * k))), maxi(1, int(round(img.get_height() / CROWD_SCALE * k)))))
		out.append({"tex": tex, "ax": -x0 / R * CROWD_SCALE, "ay": -y0 / R * CROWD_SCALE})
	_imgs.clear()
	_crowd[palette] = out
	return out

var _imgs := {}

func _atlas_image(t: Texture2D) -> Image:
	if not _imgs.has(t):
		var im := t.get_image()
		if im.is_compressed():
			im.decompress()
		if im.has_mipmaps():
			im.clear_mipmaps()
		im.convert(Image.FORMAT_RGBA8)
		_imgs[t] = im
	return _imgs[t]

func _recolor(img: Image, p: Array) -> void:
	var hi: Color = p[0]
	var mid: Color = p[1]
	var lo: Color = p[2]
	var steel: Vector3 = p[3]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var key := smoothstep(0.04, 0.14, c.g - maxf(c.r, c.b))
			if key > 0.0:
				var s := pow(clampf(c.g * 1.08, 0.0, 1.0), 1.3)
				var tc := lo.lerp(mid, s * 2.0) if s < 0.5 else mid.lerp(hi, (s - 0.5) * 2.0)
				c = Color(lerpf(c.r, tc.r, key), lerpf(c.g, tc.g, key), lerpf(c.b, tc.b, key), c.a)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var grey := (1.0 - smoothstep(0.04, 0.16, mx - mn)) * (1.0 - key)
			c.r *= lerpf(1.0, steel.x, grey)
			c.g *= lerpf(1.0, steel.y, grey)
			c.b *= lerpf(1.0, steel.z, grey)
			img.set_pixel(x, y, c)
