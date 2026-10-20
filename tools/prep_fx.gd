extends SceneTree
## Copies the effect textures the game uses from the Kenney Particle Pack and Smoke Particles
## (CC0, art_src/kenney) into assets/fx, downscaled. White-on-transparent; tinted in game.
## godot --path . --script res://tools/prep_fx.gd

const P := "res://art_src/kenney/particle-pack/PNG (Transparent)/"
const S := "res://art_src/kenney/smoke-particles/PNG/"
const OUT := "res://assets/fx/"

## [source, out name, size]
const LIST := [
	[P + "spark_01.png", "spark_1", 96], [P + "spark_02.png", "spark_2", 96], [P + "spark_04.png", "spark_3", 96],
	[P + "spark_05.png", "spark_4", 96], [P + "spark_06.png", "spark_5", 96],
	[P + "star_04.png", "star_1", 128], [P + "star_06.png", "star_2", 128], [P + "star_08.png", "star_3", 128],
	[P + "flare_01.png", "flare", 128], [P + "light_01.png", "light_1", 128], [P + "light_03.png", "light_2", 128],
	[P + "circle_01.png", "circle_1", 128], [P + "circle_03.png", "ring_1", 256], [P + "circle_05.png", "ring_2", 256],
	[P + "slash_01.png", "slash_1", 256], [P + "slash_02.png", "slash_2", 256], [P + "slash_03.png", "slash_3", 256], [P + "slash_04.png", "slash_4", 256],
	[P + "trace_01.png", "trace_1", 128], [P + "trace_04.png", "trace_2", 128],
	[P + "smoke_01.png", "smoke_1", 128], [P + "smoke_04.png", "smoke_2", 128], [P + "smoke_07.png", "smoke_3", 128],
	[P + "dirt_01.png", "dirt_1", 128], [P + "dirt_02.png", "dirt_2", 128], [P + "dirt_03.png", "dirt_3", 128],
	[P + "scorch_01.png", "scorch_1", 128], [P + "scorch_03.png", "scorch_2", 128],
	[P + "twirl_01.png", "twirl_1", 128], [P + "magic_02.png", "magic_1", 128], [P + "magic_04.png", "magic_2", 128],
	[P + "flame_02.png", "flame_1", 128], [P + "flame_05.png", "flame_2", 128], [P + "fire_01.png", "fire_1", 128],
	[P + "muzzle_02.png", "muzzle_1", 128], [P + "scratch_01.png", "scratch_1", 128],
	[S + "White puff/whitePuff02.png", "puff_1", 96], [S + "White puff/whitePuff06.png", "puff_2", 96],
	[S + "White puff/whitePuff10.png", "puff_3", 96], [S + "White puff/whitePuff14.png", "puff_4", 96],
	[S + "White puff/whitePuff18.png", "puff_5", 96], [S + "White puff/whitePuff22.png", "puff_6", 96],
	[S + "Black smoke/blackSmoke04.png", "smoke_dark_1", 96], [S + "Black smoke/blackSmoke12.png", "smoke_dark_2", 96],
	[S + "Explosion/explosion02.png", "boom_1", 128], [S + "Explosion/explosion05.png", "boom_2", 128],
	[S + "Flash/flash02.png", "flash_1", 128], [S + "Flash/flash05.png", "flash_2", 128],
]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for e in LIST:
		var img := Image.load_from_file(ProjectSettings.globalize_path(e[0]))
		if img == null or img.is_empty():
			push_error("missing " + e[0])
			continue
		img.convert(Image.FORMAT_RGBA8)
		var s: int = e[2]
		var k := float(s) / maxf(img.get_width(), img.get_height())
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(OUT + e[1] + ".png"))
	print("[fx] prepared %d textures" % LIST.size())
	quit()
