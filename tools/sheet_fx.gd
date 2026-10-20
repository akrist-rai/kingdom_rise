extends SceneTree
## Contact sheet of assets/fx on a dark background.
func _init() -> void:
	var files := DirAccess.get_files_at("res://assets/fx")
	var list: Array = []
	for f in files:
		if f.ends_with(".png"):
			list.append(f)
	list.sort()
	var cell := 136
	var cols := 8
	var rows := int(ceil(list.size() / float(cols)))
	var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.14, 0.18))
	for i in list.size():
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://assets/fx/" + list[i]))
		im.convert(Image.FORMAT_RGBA8)
		img.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * cell + 4, (i / cols) * cell + 4))
		print(i, " ", list[i])
	img.save_png(OS.get_cmdline_user_args()[0])
	quit()
