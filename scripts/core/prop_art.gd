extends Node
## Baked environment sprites (tools/bake_props.gd: Quaternius Stylized Nature MegaKit and KayKit
## Medieval Hexagon, both CC0). Large props are separate textures (trees, buildings, tents);
## small ground clutter (grass, flowers, pebbles, path stones) is packed at startup into one
## atlas so thousands of pieces draw in a handful of batches.

const DIR := "res://assets/props/"
const R := 3.0   # baked pixels per world unit
const CLUTTER := ["grass_1", "grass_2", "grass_3", "grass_4", "flowers_1", "flowers_2", "flower_1", "flower_2",
	"clover_1", "clover_2", "mushroom_1", "mushroom_2", "pebble_1", "pebble_2", "pebble_3", "pebble_4",
	"path_1", "path_2", "path_3", "path_4", "petals_1", "plant_1", "plant_7"]

var info := {}
var _tex := {}
var _sh := {}
var atlas: ImageTexture
var regions := {}         # clutter name -> Rect2 in the atlas

func _ready() -> void:
	var p := DIR + "props.json"
	if not FileAccess.file_exists(p):
		push_warning("PropArt: no baked props (run tools/bake_props.gd)")
		return
	info = JSON.parse_string(FileAccess.get_file_as_string(p))
	_build_atlas()

func has(name: String) -> bool:
	return info.has(name)

func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + name + ".png") if info.has(name) else null
	return _tex[name]

func shadow_tex(name: String) -> Texture2D:
	if not _sh.has(name):
		_sh[name] = load(DIR + name + "_sh.png") if (info.has(name) and info[name]["sh"] != null) else null
	return _sh[name]

## Foot anchor inside the sprite, in baked pixels.
func anchor(name: String) -> Vector2:
	var d: Dictionary = info[name]
	return Vector2(float(d["ax"]), float(d["ay"]))

func shadow_anchor(name: String) -> Vector2:
	var s: Array = info[name]["sh"]
	return Vector2(float(s[2]), float(s[3]))

## Footprint on the ground in world units: [width, depth on screen].
func foot(name: String) -> Vector2:
	var f: Array = info[name]["foot"]
	return Vector2(float(f[0]), float(f[1]))

func _build_atlas() -> void:
	var imgs := {}
	for n in CLUTTER:
		if info.has(n):
			var t: Texture2D = tex(n)
			if t:
				var im := t.get_image()
				if im.is_compressed():
					im.decompress()
				im.convert(Image.FORMAT_RGBA8)
				imgs[n] = im
	var order := imgs.keys()
	order.sort_custom(func(a, b): return imgs[a].get_height() > imgs[b].get_height())
	var w := 1024
	var page := Image.create(w, 1024, false, Image.FORMAT_RGBA8)
	var x := 0
	var y := 0
	var row := 0
	for n in order:
		var im: Image = imgs[n]
		if x + im.get_width() + 2 > w:
			x = 0
			y += row
			row = 0
		page.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x + 1, y + 1))
		regions[n] = Rect2(x + 1, y + 1, im.get_width(), im.get_height())
		x += im.get_width() + 2
		row = maxi(row, im.get_height() + 2)
	page = page.get_region(Rect2i(0, 0, w, maxi(16, y + row)))
	page.generate_mipmaps()
	atlas = ImageTexture.create_from_image(page)
