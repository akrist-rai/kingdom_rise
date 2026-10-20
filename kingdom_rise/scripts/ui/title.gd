class_name TitleScreen
extends Node2D
## Title scene: a lone soldier with a red cape in the snow at sunset, ringed by two armies
## and their torches (after the first reference image), then a briefing on an ink scroll.

signal start_game

var cam: Camera2D
var sky: ColorRect
var atmos: Atmos
var lp: LightPainter
var shadows: ShadowLayer
var world: Node2D
var glowfx: Node2D
var high: Node2D
var flames: Array = []
var ui: Control
var t := 0.0
var stage := 0      # 0 = title, 1 = briefing
var stage_t := 0.0
var help := false
var knight: Sprite2D
var sword: Sprite2D
var cape: Cape
var band: Texture2D
var seal_qin: Texture2D
var anim_f := -1

const C_INK := Color(0.05, 0.035, 0.06)
const C_GOLD := Color("#ffd166")
const CENTER := Vector2(320, 236)

const BRIEF := [
	"WINTER. THE SEVEN STATES ARE AT WAR.",
	"QIN MARCHES ON THE SNOW PLAINS OF ZHAO.",
	"",
	"YOU ARE A NAMELESS FOOT SOLDIER IN THE FIRST LINE.",
	"KILL, SURVIVE AND RISE:  SQUAD LEADER, 100-MAN,",
	"1000-MAN, 5000-MAN COMMANDER... GENERAL.",
	"",
	"WHEN YOU FALL, YOUR WILL PASSES TO ANOTHER SOLDIER",
	"ON THE FIELD. YOUR RANK AND LEGACY GO WITH YOU.",
	"",
	"TAKE THE ENEMY GENERAL'S HEAD.",
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.time_scale = 1.0
	visibility_layer = 3
	var c := CENTER
	var ground := WorldBuilder.ground(Rect2(-500, -60, 1700, 900), 70.0, 900.0)
	add_child(ground)
	sky = WorldBuilder.sky(Rect2(-500, -560, 1700, 600), 40.0)
	add_child(sky)
	# trampled snow and blood around the soldier
	var marks := Node2D.new()
	add_child(marks)
	marks.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 1100:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 130.0
			marks.draw_rect(Rect2((c + Vector2(cos(a) * d, sin(a) * d * 0.45)).floor(), Vector2(2, 1)), Color(0.33, 0.37, 0.58, 0.28))
		for i in 7:
			var p := c + Vector2(rng.randf_range(-100, 100), rng.randf_range(-34, 34))
			marks.draw_set_transform(p, 0.0, Vector2(1, 0.5))
			marks.draw_circle(Vector2.ZERO, rng.randf_range(3, 7), Color(0.45, 0.05, 0.1, 0.6))
			marks.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	)
	shadows = ShadowLayer.new()
	add_child(shadows)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var crowd := WorldBuilder.Crowd.new()
	add_child(crowd)
	for row in 3:
		crowd.add_row("qin" if row % 2 == 0 else "zhao", -300.0, 940.0, 96.0 + row * 10.0, 8.0, 1.2, rng, 7 if row == 2 else 0)
	crowd.add_ring("qin", "zhao", c, 190.0, 74.0, 5, rng, 0, 6)
	crowd.finish()
	shadows.add_crowd(crowd)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	glowfx = Node2D.new()
	glowfx.visibility_layer = 3
	add_child(glowfx)
	high = Node2D.new()
	add_child(high)
	var crows := Crows.new()
	add_child(crows)
	crows.setup(Rect2(0, 60, 640, 300), 9)
	cam = Camera2D.new()
	cam.position = Vector2(320, 128)
	add_child(cam)
	cam.make_current()
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self, cam)
	atmos.sky_mat = sky.material
	atmos.ground_mat = ground.material
	atmos.snow_nodes = WorldBuilder.snow_layers(cam)
	atmos.day = 0.66
	atmos.day_target = 0.66
	lp = LightPainter.new()
	lp.atmos = atmos
	add_child(lp)
	lp.sources.append(_draw_lights)
	WorldBuilder.light_torches(self, crowd)
	for i in 16:
		var a := rng.randf() * TAU
		var d := rng.randf_range(34, 150)
		var key: String = ["sword_stuck", "sword_tilt", "spear_stuck", "rock0", "sword_stuck", "shield_drop"][i % 6]
		if key == "shield_drop":
			continue
		WorldBuilder.prop(world, key, c + Vector2(cos(a) * d, sin(a) * d * 0.4), rng.randf() < 0.5, shadows, 0.8)
	WorldBuilder.prop(world, "wreck_tower", c + Vector2(-128, -18), false, shadows)
	WorldBuilder.fire(self, c + Vector2(-124, -20), 2)
	WorldBuilder.prop(world, "wreck_chariot", c + Vector2(136, 14), true, shadows)
	WorldBuilder.fire(self, c + Vector2(132, 12), 1)
	knight = Sprite2D.new()
	knight.texture = Art.units["qin_officer"]["idle"][0]
	knight.centered = false
	knight.offset = Vector2(-10, -22)
	knight.position = c
	world.add_child(knight)
	cape = Cape.new()
	cape.setup(Unit.CAPE_PLAYER, 3.4, 1.15)
	knight.add_child(cape)
	knight.move_child(cape, 0)
	cape.show_behind_parent = true
	sword = Sprite2D.new()
	sword.texture = Art.weapons["jian"]["tex"]
	sword.centered = false
	sword.offset = -Art.weapons["jian"]["pivot"]
	sword.position = Vector2(3, -12)
	sword.rotation = deg_to_rad(70)
	knight.add_child(sword)
	var ks := shadows.add_sprite(knight.texture, knight.offset)
	ks.transform = ShadowLayer.proj(atmos.sun_shadow(), c)
	knight.set_meta("shadow", ks)
	var sh := Sprite2D.new()
	sh.texture = Art.tex["shadow"]
	sh.position = c + Vector2(0, -1)
	add_child(sh)
	move_child(sh, world.get_index())
	var cl := CanvasLayer.new()
	cl.layer = 10
	add_child(cl)
	ui = Control.new()
	ui.size = Game.VIEW
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	cl.add_child(ui)
	band = ImageTexture.create_from_image(Hud._brush_image(640, 46, 9))
	if OS.get_cmdline_user_args().has("--brief"):
		stage = 1
	seal_qin = Hud.seal_tex(["qin"], Color("#b3202a"), Color("#ffe6b0"), 11)

func _draw_lights(l: LightPainter) -> void:
	l.glow(CENTER + Vector2(0, -6), 40.0, Color(1.0, 0.78, 0.45) * 0.3)

func _process(delta: float) -> void:
	t += delta
	stage_t += delta
	var push := clampf(t / 12.0, 0.0, 1.0)
	cam.position = Vector2(320 + sin(t * 0.15) * 12.0, lerpf(128.0, 146.0, push * push * (3.0 - 2.0 * push)) + sin(t * 0.11) * 3.0)
	knight.texture = Art.units["qin_officer"]["idle"][int(t * 1.6) % 2]
	var ks: Sprite2D = knight.get_meta("shadow")
	ks.texture = knight.texture
	shadows.set_sun(atmos.sun_shadow(), atmos.cur["shadow_col"], atmos.cur["shadow_alpha"])
	ks.transform = ShadowLayer.proj(atmos.sun_shadow(), CENTER)
	cape.step(delta, knight.global_position + Vector2(-1.5, -13), 1)
	var f := int(t * 10.0)
	if f != anim_f:
		anim_f = f
		for fl in flames:
			fl[0].texture = Art.tex[fl[1] + str((f + int(fl[2])) % 4)]
	ui.queue_redraw()
	if OS.get_cmdline_user_args().has("--autostart") and t > 1.0 and not has_meta("started"):
		set_meta("started", true)
		start_game.emit()
	if Input.is_action_just_pressed("help") and stage == 0:
		help = not help
	var go := Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack")
	if go and t > 0.4:
		if help:
			help = false
		elif stage == 0:
			stage = 1
			stage_t = 0.0
			Sfx.play("drum", -2.0)
		elif stage == 1 and stage_t > 0.6:
			Sfx.play("horn_short", -2.0)
			start_game.emit()

# ------------------------------------------------------------------ ui
func _txt(pos: Vector2, s: String, sz: int, col: Color, align: int = 1, plain: bool = false) -> void:
	Game.text(ui, pos, s, sz, col, align, 2 if plain else 0)

func _tt(pos: Vector2, s: String, col: Color, scale: int = 1, align: int = 1) -> void:
	Game.text(ui, pos, s, 9 * scale, col, align, 1)

func _band(r: Rect2, a: float) -> void:
	ui.draw_texture_rect(band, r, false, Color(C_INK.r, C_INK.g, C_INK.b, a))

func _draw_ui() -> void:
	if stage == 1:
		_draw_brief()
		return
	var a1 := clampf(t * 0.7, 0.0, 1.0)
	var grow := clampf(t / 0.9, 0.0, 1.0)
	var bw := 560.0 * (1.0 - (1.0 - grow) * (1.0 - grow))
	_band(Rect2(320.0 - bw * 0.5, 22, bw, 60), 0.85 * a1)
	_tt(Vector2(320, 68), "SEVEN STATES", Color(1.0, 0.85, 0.5, a1), 4)
	_txt(Vector2(320, 80), "RISE THROUGH THE RANKS", 8, Color(0.95, 0.88, 0.8, a1))
	var sk := clampf((t - 0.9) / 0.14, 0.0, 1.0)
	if sk > 0.0:
		var sz := seal_qin.get_size() * lerpf(4.0, 2.0, sk * sk)
		var sp := Vector2(560, 50)
		ui.draw_texture_rect(seal_qin, Rect2(sp - sz * 0.5, sz), false, Color(1, 1, 1, sk))
	var lines := ["THIS IS IT.", "YOU'RE SURROUNDED.", "THERE'S NO WAY OUT."]
	for i in 3:
		var a := clampf((t - 1.4 - i * 0.8) * 1.2, 0.0, 1.0)
		if a <= 0.0:
			continue
		var y := 146.0 + i * 28.0
		var w := Game.text_w(lines[i], 18, 1)
		_band(Rect2(320.0 - w * 0.5 - 26.0, y - 20.0, w + 52.0, 27.0), 0.55 * a)
		var slide := (1.0 - a) * 14.0
		_tt(Vector2(320 + slide, y + 2), lines[i], Color(1, 0.98, 0.94, a), 2)
	if t > 4.2:
		var b := 0.55 + 0.45 * sin(t * 4.0)
		_band(Rect2(170, 312, 300, 30), 0.6)
		_txt(Vector2(320, 324), "PRESS ENTER OR CLICK TO BEGIN", 8, Color(1, 0.9, 0.6, b))
		_txt(Vector2(320, 336), "H: HOW TO PLAY      F11: FULLSCREEN      F2: LOW GRAPHICS", 8, Color(0.8, 0.76, 0.84, 0.9))
	if help:
		_draw_help()

func _draw_brief() -> void:
	var a := clampf(stage_t / 0.4, 0.0, 1.0)
	ui.draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.02, 0.01, 0.03, 0.6 * a))
	# an unrolling paper scroll with wooden rods
	var open := clampf(stage_t / 0.5, 0.0, 1.0)
	open = 1.0 - (1.0 - open) * (1.0 - open)
	var w := 470.0 * open
	var r := Rect2(320.0 - w * 0.5, 54, w, 254)
	ui.draw_rect(r, Color(0.92, 0.87, 0.76))
	ui.draw_rect(Rect2(r.position + Vector2(0, 4), Vector2(r.size.x, 1)), Color(0.7, 0.62, 0.5))
	ui.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 5), Vector2(r.size.x, 1)), Color(0.7, 0.62, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 260:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		ui.draw_rect(Rect2(p.floor(), Vector2(1, 1)), Color(0.78, 0.7, 0.58, 0.5))
	for x in [r.position.x - 6, r.end.x]:
		ui.draw_rect(Rect2(x, 48, 6, 266), Color("#5a3a26"))
		ui.draw_rect(Rect2(x + 1, 48, 1, 266), Color("#8a5c3c"))
		ui.draw_rect(Rect2(x - 1, 44, 8, 5), Color("#c99a3a"))
		ui.draw_rect(Rect2(x - 1, 312, 8, 5), Color("#c99a3a"))
	if open < 0.98:
		return
	var y := 88.0
	for i in BRIEF.size():
		var la := clampf((stage_t - 0.5 - i * 0.14) * 3.0, 0.0, 1.0)
		var col := Color(0.7, 0.1, 0.1, la) if i == BRIEF.size() - 1 else Color(0.12, 0.08, 0.1, la)
		_txt(Vector2(320, y), BRIEF[i], 8, col, 1, true)
		y += 17.0
	var sk := clampf((stage_t - 2.1) / 0.14, 0.0, 1.0)
	if sk > 0.0:
		var sz := seal_qin.get_size() * lerpf(3.5, 1.5, sk * sk)
		ui.draw_texture_rect(seal_qin, Rect2(Vector2(512, 270) - sz * 0.5, sz), false, Color(1, 1, 1, sk))
	if stage_t > 2.0:
		var b := 0.55 + 0.45 * sin(t * 5.0)
		_band(Rect2(190, 318, 260, 22), 0.75)
		_txt(Vector2(320, 333), "PRESS ENTER OR CLICK TO MARCH", 8, Color(1, 0.92, 0.7, b))

func _draw_help() -> void:
	ui.draw_rect(Rect2(Vector2.ZERO, Game.VIEW), Color(0.03, 0.015, 0.04, 0.85))
	var r := Rect2(40, 40, 560, 290)
	ui.draw_rect(r, Color(0.07, 0.045, 0.06, 0.95))
	ui.draw_rect(r, Color(0.55, 0.38, 0.2), false, 1.0)
	ui.draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, 1)), Color(0.7, 0.14, 0.16))
	_tt(Vector2(320, 66), "HOW TO PLAY", C_GOLD, 2)
	var lines := [
		"WASD MOVE    MOUSE AIM    LMB LIGHT ATTACK (COMBO)    RMB HEAVY (HOLD TO CHARGE)",
		"SPACE DASH (INVINCIBLE)    SHIFT GUARD - TAP RIGHT BEFORE A HIT TO PARRY",
		"E WEAPON SKILL (SPIRIT)    R FLASK    F PICK UP WEAPON    ESC PAUSE",
		"",
		"HEAVY HITS AND PARRIES FILL AN ENEMY'S STANCE. WHEN IT BREAKS THEY KNEEL:",
		"ATTACK THEM FOR A CRITICAL HIT.",
		"WHITE GLINT = YOU CAN PARRY OR BLOCK.  RED GLINT = YOU MUST DODGE.",
		"ORANGE HP (RALLY) COMES BACK IF YOU HIT ENEMIES QUICKLY.",
		"FIGHT WITH STYLE: VARIED MOVES RAISE YOUR STYLE RANK, WHICH MULTIPLIES XP.",
		"",
		"RANKS UNLOCK A SQUAD, ORDERS (1/2/3), WAR CRY (G) AND ARROW VOLLEYS (V).",
		"WHEN YOU DIE, PICK ANOTHER SOLDIER TO CONTINUE. LOW MORALE = DEFEAT.",
		"GAMEPAD SUPPORTED.",
	]
	var y := 94.0
	for l in lines:
		_txt(Vector2(320, y), l, 8, Color(0.93, 0.9, 0.86))
		y += 15.0
	_txt(Vector2(320, 316), "ENTER: BACK", 8, Color(1, 0.9, 0.6))
