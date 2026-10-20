extends Node
## Switches between the title screen and the battle. Also handles fullscreen (F11)
## and the --autotest mode used to smoke-test the game without a player.

var current: Node = null
var test_t := 0.0
var test_len := 60.0
var shot_every := 0.0
var shot_t := 0.0
var shot_i := 0
var out_dir := ""
var title_only := false
var wipe: Control
var wipe_tex: Array = []
var wipe_k := 0.0
var wipe_dir := 0
var wipe_cb: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--len="):
			test_len = float(a.substr(6))
		elif a.begins_with("--shots="):
			shot_every = float(a.substr(8))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a == "--level=commander_city":
			next_level = "commander_city"
		elif a == "--title":
			title_only = true

	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	wipe = Control.new()
	wipe.size = Game.VIEW
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.draw.connect(_draw_wipe)
	cl.add_child(wipe)
	for i in 4:
		wipe_tex.append(ImageTexture.create_from_image(Hud._brush_image(760, 130, 20 + i)))
	# All sprites are rendered on the GPU during the first frames; wait for them.
	if not Art.ready_done:
		await Art.built
	if OS.get_cmdline_user_args().has("--gallery"):
		_gallery()
	elif OS.get_cmdline_user_args().has("--map"):
		title_only = true
		show_map()
	elif Game.autotest and not title_only:
		start_battle()
	else:
		show_title()

## Ink-brush wipe: strokes sweep across to cover the screen, the scene swaps, they sweep away.
func transition(cb: Callable) -> void:
	if wipe_dir != 0:
		return
	wipe_cb = cb
	wipe_dir = 1
	wipe_k = 0.0
	Sfx.play("swing_heavy", -4.0, 0.6)

func _draw_wipe() -> void:
	if wipe_dir == 0 and wipe_k <= 0.0:
		return
	for i in 4:
		var k := clampf(wipe_k * 1.5 - i * 0.12, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var y := -30.0 + i * 100.0
		var x := 0.0
		if wipe_dir >= 0:
			x = lerpf(-800.0, -60.0, k)
		else:
			x = lerpf(740.0, -60.0, k)
		wipe.draw_texture_rect(wipe_tex[i], Rect2(Vector2(x, y), Vector2(760, 130)), false, Color(0.05, 0.035, 0.06))
		if k > 0.0:
			wipe.draw_rect(Rect2(Vector2(x + 40.0, y + 64.0), Vector2(680, 1)), Color(0.75, 0.12, 0.12, 0.6))

func _swap(n: Node) -> void:
	if current != null:
		current.queue_free()
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.possess_slow = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current = n
	add_child(n)

func show_title() -> void:
	Sfx.boss_mode = false
	var t := TitleScreen.new()
	t.start_game.connect(func(): transition(start_battle))
	t.open_map.connect(func(): transition(show_map))
	t.start_commander.connect(func():
		next_level = "commander_city"
		transition(start_battle))
	_swap(t)

func show_map() -> void:
	var m := CampaignMap.new()
	m.march.connect(func(id: String):
		next_level = "commander_city" if id == "bellacourt" else "siege" if id == "handan" else "snow_plains"
		transition(start_battle))
	m.back.connect(func(): transition(show_title))
	_swap(m)

var next_level := "siege"

func start_battle() -> void:
	Game.reset_legacy()
	var b: Battle = CommanderBattle.new() if next_level == "commander_city" else Battle.new()
	b.level = next_level
	b.leave_battle.connect(_on_leave)
	_swap(b)

func _on_leave(restart: bool) -> void:
	transition(start_battle if restart else show_map)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		Game.low_gfx = not Game.low_gfx
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _process(delta: float) -> void:
	if wipe_dir != 0:
		var wr := minf(delta / maxf(Engine.time_scale, 0.0001), 0.05)
		if get_tree().paused:
			wr = minf(delta, 0.05)
		if wipe_dir == 1:
			wipe_k += wr * 2.2
			if wipe_k >= 1.0:
				wipe_k = 1.0
				wipe_dir = -1
				if wipe_cb.is_valid():
					wipe_cb.call()
		else:
			wipe_k -= wr * 2.0
			if wipe_k <= 0.0:
				wipe_k = 0.0
				wipe_dir = 0
		wipe.queue_redraw()
	if not Game.autotest and not title_only:
		return
	var rdt := delta / maxf(Engine.time_scale, 0.0001)
	if get_tree().paused:
		rdt = delta
	test_t += rdt
	shot_t += rdt
	if shot_every > 0.0 and shot_t >= shot_every and out_dir != "":
		shot_t = 0.0
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [out_dir, shot_i])
		shot_i += 1
		_report()
	if test_t >= test_len:
		_report()
		print("[autotest] done")
		get_tree().quit()

## Debug view (--gallery): every generated sprite on a paper background, magnified.
func _gallery() -> void:
	title_only = true
	var page := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--page="):
			page = int(a.substr(7))
	var root := Node2D.new()
	var bg := ColorRect.new()
	bg.color = Color("#e9dcc0")
	bg.size = Game.VIEW
	root.add_child(bg)
	var items: Array = []
	if page == 0:
		for k in ["qin_infantry", "qin_spear", "qin_archer", "qin_heavy", "qin_officer", "zhao_infantry", "zhao_heavy", "zhao_general"]:
			var d: Dictionary = Art.units[k]
			items.append_array([d["walk"][0], d["walk"][1], d["idle"][0], d["hurt"], d["broken"], d["dead"]])
	elif page == 1:
		for k in ["qin_cavalry", "zhao_cavalry"]:
			var d: Dictionary = Art.units[k]
			items.append_array([d["walk"][0], d["walk"][1], d["walk"][2], d["walk"][3], d["idle"][0], d["dead"]])
		for k in Art.weapons.keys():
			items.append(Art.weapons[k]["tex"])
		for f in ["qin", "zhao"]:
			items.append_array(Art.crowd[f])
			items.append(Art.crowd_torch[f])
	else:
		var keys := Art.tex.keys()
		keys.sort()
		for k in keys:
			if not str(k).begins_with("flame_") or str(k).ends_with("0"):
				items.append(Art.tex[k])
	var zoom := 3.0 if page == 0 else 2.0
	var x := 6.0
	var y := 6.0
	var row := 0.0
	for t in items:
		var sz: Vector2 = t.get_size() * zoom
		if x + sz.x > Game.VIEW.x - 4.0:
			x = 6.0
			y += row + 4.0
			row = 0.0
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.scale = Vector2(zoom, zoom)
		s.position = Vector2(x, y)
		root.add_child(s)
		x += sz.x + 4.0
		row = maxf(row, sz.y)
	_swap(root)

func _report() -> void:
	print("[perf] fps=%d process_ms=%.1f draw_calls=%d objects=%d nodes=%d" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("[prof] " + Prof.report())
	var vr := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vr, true)
	print("[render] cpu=%.1fms gpu=%.1fms setup=%.1fms" % [RenderingServer.viewport_get_measured_render_time_cpu(vr), RenderingServer.viewport_get_measured_render_time_gpu(vr), RenderingServer.get_frame_setup_time_cpu()])
	if current is CommanderBattle:
		var city = current as CommanderBattle
		var director = city.tactics as CommanderDirector
		print("[commander] time=%.1f fps=%d soldiers=%d alive=%s companies=%d selected=%s orders=%d reforms=%d routes=%d mounted=%s wards=%d ended=%s" % [city.time, Engine.get_frames_per_second(), city.units.size(), str(city.alive), director.regiments.size(), str(director.selected), director.order_count, director.reform_count, director.routes_completed, str(city.player != null and city.player.mounted), city.level_ctl.captured_total, str(city.ended)])
		return
	if current is Battle:
		var b := current as Battle
		var p := b.player
		if b.tactics != null:
			print("[formations] groups=%d squad=%d form=%s orders=%s caps=%s" % [b.tactics.regiments.size(), b.squad.size(), b.tactics.FORMS[b.tactics.formation], b.squad_order, str(b.caps)])
		print("[autotest] falls=%d exec=%d auras=%d kicks=%d crits=%d aura=%.0f duel=%s clash=%s officers=%d horses=%d mounted=%s fin=%d zoom=%.2f" % [int(Game.stats.get("falls", 0)), int(Game.stats.get("executions", 0)), int(Game.stats.get("auras", 0)),
			int(Game.stats.get("kicks", 0)), int(Game.stats["crits"]), Game.aura, b.duel_kind, str(not b.clash.is_empty()), Game.stats["officers"], b.horses.size(), str(b.player != null and is_instance_valid(b.player) and b.player.mounted), int(Game.stats.get("finishers", 0)), b.cam.cur_zoom])
		print("[autotest] t=%.1f fps=%d units=%d alive=%s reserves=%s morale=[%.1f, %.1f] rank=%d xp=%.0f kills=%d deaths=%d style=%d boss=%s duel=%s ended=%s player=%s" % [
			b.time, Engine.get_frames_per_second(), b.units.size(), str(b.alive), str(b.reserves), b.morale[0], b.morale[1],
			Game.rank, Game.xp, Game.stats["kills"], Game.stats["deaths"], Game.style_tier(),
			str(b.boss != null and is_instance_valid(b.boss) and not b.boss.dead), str(b.duel), str(b.ended),
			("%s hp=%.0f/%.0f %s @%d,%d" % [p.kind, p.hp, p.max_hp, p.weapon.id, int(p.global_position.x), int(p.global_position.y)]) if p != null and is_instance_valid(p) else "none"])
