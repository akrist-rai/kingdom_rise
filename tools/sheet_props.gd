extends SceneTree
## Contact sheet of chosen baked props on a ground colour: godot --script ... -- out.png name1 name2 ...
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var names := args.slice(1)
	var imgs: Array = []
	var w := 0
	var h := 0
	for n in names:
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://assets/props/%s.png" % n))
		im.convert(Image.FORMAT_RGBA8)
		imgs.append(im)
		w += im.get_width() + 10
		h = maxi(h, im.get_height())
	var out := Image.create(w + 10, h + 20, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.42, 0.52, 0.3))
	var x := 10
	for im in imgs:
		out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, 10 + h - im.get_height()))
		x += im.get_width() + 10
	out.save_png(args[0])
	quit()
