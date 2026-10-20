extends Node
## Global state: the "legacy" (rank, XP and perks that carry over between bodies),
## the style meter, time effects (hit-stop / slow motion), input setup and the UI theme.

signal rank_changed(rank: int)
signal style_popup(text: String, color: Color)
signal banner(title: String, sub: String, color: Color)

const VIEW := Vector2(640, 360)

# Kingdom-style ranks. The Japanese reading (as used in the manga) is shown on promotion.
const RANKS := [
	{"name": "FIELD CAPTAIN", "jp": "LEADS 16", "xp": 0, "squad": 16},
	{"name": "BANNER CAPTAIN", "jp": "LEADS 20", "xp": 300, "squad": 20},
	{"name": "COMPANY COMMANDER", "jp": "LEADS 24", "xp": 1200, "squad": 24},
	{"name": "BATTALION COMMANDER", "jp": "LEADS 32", "xp": 3200, "squad": 32},
	{"name": "MARSHAL", "jp": "LEADS 40", "xp": 6500, "squad": 40},
	{"name": "GENERAL", "jp": "COMMANDER OF THE MARCH", "xp": 99999999, "squad": 48},
]

const STYLE_TIERS := [
	{"n": "D", "name": "DULL", "need": 0.0, "col": Color("#8a90a8")},
	{"n": "C", "name": "CLASHING", "need": 90.0, "col": Color("#6fb7ff")},
	{"n": "B", "name": "BRUTAL", "need": 220.0, "col": Color("#61e08a")},
	{"n": "A", "name": "ARDENT", "need": 400.0, "col": Color("#ffe066")},
	{"n": "S", "name": "SAVAGE", "need": 640.0, "col": Color("#ff9a3d")},
	{"n": "SS", "name": "SUPREME", "need": 920.0, "col": Color("#ff4d4d")},
	{"n": "SSS", "name": "SOVEREIGN", "need": 1250.0, "col": Color("#ff3df2")},
	{"n": "G", "name": "GREAT GENERAL", "need": 1650.0, "col": Color("#fff4c2")},
]
const STYLE_CAP := 2000.0

const PERKS := {
	"iron_lungs": {"name": "IRON LUNGS", "desc": "+30% MAX STAMINA\n+25% STAMINA REGEN"},
	"bloodthirst": {"name": "BLOODTHIRST", "desc": "HITTING BACK RECOVERS\nTWICE AS MUCH HP"},
	"keen_eye": {"name": "KEEN EYE", "desc": "PARRY WINDOW +60%"},
	"second_wind": {"name": "SECOND WIND", "desc": "NEW BODIES START AT\nFULL HP, 3S INVINCIBLE"},
	"war_drums": {"name": "WAR DRUMS", "desc": "YOUR SQUAD DEALS\n+35% DAMAGE"},
	"executioner": {"name": "EXECUTIONER", "desc": "CRITICALS +40% DMG\nAND HEAL 15% HP"},
	"ghost_step": {"name": "GHOST STEP", "desc": "LONGER DASH I-FRAMES\nDASH COSTS 30% LESS"},
	"hemorrhage": {"name": "HEMORRHAGE", "desc": "EVERY WEAPON CAUSES\nBLEED BUILDUP"},
	"unbroken": {"name": "UNBROKEN", "desc": "+50% POISE\nGUARD COSTS 30% LESS"},
	"spirit_well": {"name": "SPIRIT WELL", "desc": "+50% SPIRIT GAIN\nFOR WEAPON SKILLS"},
	"kings_umbrella": {"name": "THE KING'S UMBRELLA", "desc": "ARROWS CANNOT HURT\nYOU. STAY DRY."},
	"ruthless": {"name": "RUTHLESS STYLE", "desc": "STYLE DECAYS 40%\nSLOWER"},
	"heavy_hand": {"name": "HEAVY HAND", "desc": "HEAVY ATTACKS +35%\nDMG AND STANCE DMG"},
	"field_medic": {"name": "FIELD MEDIC", "desc": "+1 FLASK FOR\nEVERY BODY"},
	"veteran": {"name": "VETERAN'S EYE", "desc": "EVERY BODY YOU TAKE\nGETS +3 ALL STATS"},
}

var font: Font          # body text (drawn in caps with an ink outline)
var font_title: Font    # display headings (heavier, wider spacing)
var font_plain: Font
var font_italic: Font   # map labels
var campaign := {}      # battle id -> true once won (this session)
var theme: Theme
var rng := RandomNumberGenerator.new()

# Legacy (shared across bodies)
var xp := 0.0
var rank := 0
var perks := {}
# Battle stats
var stats := {}
# Style meter
var style := 0.0
var style_hold := 0.0
# General's Aura (the "great general" presence from Kingdom): filled by fighting with style,
# released with X for a short, overwhelming surge.
var aura := 0.0
var aura_t := 0.0
const AURA_DUR := 12.0
var fresh := {}
var kill_times: Array[float] = []
var chain_hits := 0
var chain_t := 0.0

# Time effects (real-time based)
var _hitstop_until := 0.0
var _slow_until := 0.0
var _slow_scale := 1.0
var possess_slow := false
var paused_by_menu := false

var autotest := false
var low_gfx := false
var command_view := false
var noauto := false
var god := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	autotest = OS.get_cmdline_user_args().has("--autotest")
	noauto = OS.get_cmdline_user_args().has("--noauto")
	god = OS.get_cmdline_user_args().has("--god")
	_setup_input()
	_make_fonts()
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 10
	get_tree().root.theme = theme
	# Canvas items on visibility layer 2 are lights: only the light buffer may see them.
	get_tree().root.set_canvas_cull_mask_bit(1, false)
	reset_legacy()

# ------------------------------------------------------------------ typography
## UI code passes the sizes it used with the old pixel fonts (8 = body, 9 x scale = display);
## these factors map them to the smooth font so the layout keeps its proportions.
const BODY_K := 1.3
const TITLE_K := 1.4
const TEXT_INK := Color(0.02, 0.05, 0.07, 0.92)

func _make_fonts() -> void:
	var base: Font = ThemeDB.fallback_font
	var body := FontVariation.new()
	body.base_font = base
	body.variation_embolden = 0.45
	body.set_spacing(TextServer.SPACING_GLYPH, 0)
	font = body
	var title := FontVariation.new()
	title.base_font = base
	title.variation_embolden = 1.2
	title.set_spacing(TextServer.SPACING_GLYPH, 2)
	font_title = title
	var plain := FontVariation.new()
	plain.base_font = base
	plain.variation_embolden = 0.2
	font_plain = plain
	var it := FontVariation.new()
	it.base_font = base
	it.variation_embolden = 0.1
	it.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	font_italic = it

func text_size(sz: int, kind: int = 0) -> int:
	return int(round(sz * (TITLE_K if kind == 1 else BODY_K)))

## kind: 0 body (caps), 1 display (caps), 2 plain, 3 italic (both keep their case).
func text_font(kind: int) -> Font:
	match kind:
		1: return font_title
		2: return font_plain
		3: return font_italic
	return font

## Width of a string as `text()` would draw it. kind: 0 body, 1 display, 2 plain.
func text_w(s: String, sz: int = 8, kind: int = 0) -> float:
	var t := s if kind >= 2 else s.to_upper()
	return text_font(kind).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size(sz, kind)).x

## Draws UI text: caps, an ink outline, and (for display text) a drop shadow.
## align: 0 left, 1 centre, 2 right. `pos.y` is the baseline.
func text(ci: CanvasItem, pos: Vector2, s: String, sz: int = 8, col: Color = Color.WHITE, align: int = 0, kind: int = 0, outline: bool = true, oc: Color = TEXT_INK) -> void:
	var f := text_font(kind)
	var t := s if kind >= 2 else s.to_upper()
	var fs := text_size(sz, kind)
	var x := pos.x
	if align != 0:
		x -= f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * (0.5 if align == 1 else 1.0)
	var p := Vector2(x, pos.y)
	var ink := Color(oc.r, oc.g, oc.b, oc.a * col.a)
	if kind == 1 and outline:
		ci.draw_string_outline(f, p + Vector2(0, fs * 0.12), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, fs / 4), Color(ink.r, ink.g, ink.b, ink.a * 0.7))
	if outline:
		ci.draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 4) if kind == 1 else 1, ink)
	ci.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func reset_legacy() -> void:
	xp = 0.0
	rank = 0
	perks = {}
	style = 0.0
	fresh = {}
	kill_times.clear()
	chain_hits = 0
	aura = 0.0
	aura_t = 0.0
	stats = {"kills": 0, "deaths": 0, "crits": 0, "parries": 0, "bodies": 1,
		"officers": 0, "best_style": 0, "time": 0.0, "dmg": 0.0, "dodges": 0}

func event_log(msg: String) -> void:
	if autotest:
		print("[event] " + msg)

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	var t := now()
	var ts := 1.0
	if t < _slow_until:
		ts = _slow_scale
	if possess_slow:
		ts = min(ts, 0.1)
	if t < _hitstop_until:
		ts = min(ts, 0.04)
	if command_view:
		ts = minf(ts, 0.16)
	Engine.time_scale = ts
	if get_tree().paused:
		return
	# Style decay and freshness recovery (in game time).
	var gd := delta * Engine.time_scale
	style_hold -= gd
	if style_hold <= 0.0 and style > 0.0:
		var tier := style_tier()
		var decay := 22.0 + tier * 12.0
		if has_perk("ruthless"):
			decay *= 0.6
		style = max(0.0, style - decay * gd)
	for k in fresh.keys():
		fresh[k] = min(1.0, fresh[k] + 0.07 * gd)
	if chain_hits > 0 and t - chain_t > 3.0:
		chain_hits = 0

# ---------------------------------------------------------------- time effects
func hitstop(dur: float) -> void:
	_hitstop_until = max(_hitstop_until, now() + dur)

func slowmo(scale: float, dur: float) -> void:
	_slow_scale = scale
	_slow_until = now() + dur

# ---------------------------------------------------------------- legacy
func has_perk(id: String) -> bool:
	return perks.has(id)

func rank_name(r: int = -1) -> String:
	if r < 0:
		r = rank
	return RANKS[r]["name"]

func squad_size() -> int:
	return RANKS[rank]["squad"]

func next_rank_xp() -> float:
	if rank >= RANKS.size() - 2:
		return -1.0
	return float(RANKS[rank + 1]["xp"])

func rank_progress() -> float:
	var nx := next_rank_xp()
	if nx < 0:
		return 1.0
	var cur := float(RANKS[rank]["xp"])
	return clamp((xp - cur) / (nx - cur), 0.0, 1.0)

func add_xp(amount: float) -> void:
	xp += amount
	# General (the last rank) is only granted by taking the enemy general's head.
	while rank < RANKS.size() - 2 and xp >= RANKS[rank + 1]["xp"]:
		rank += 1
		rank_changed.emit(rank)

func promote_to_general() -> void:
	if rank < RANKS.size() - 1:
		rank = RANKS.size() - 1
		rank_changed.emit(rank)

func player_damage_mult() -> float:
	# The "spirit" of a rising hero: grows with rank (and surges under the General's Aura).
	return (1.45 + rank * 0.1) * (1.5 if aura_t > 0.0 else 1.0)

func aura_active() -> bool:
	return aura_t > 0.0

func aura_ready() -> bool:
	return aura >= 100.0 and aura_t <= 0.0

func random_perks(n: int) -> Array:
	var pool: Array = []
	for k in PERKS.keys():
		if not perks.has(k):
			pool.append(k)
	pool.shuffle()
	return pool.slice(0, min(n, pool.size()))

# ---------------------------------------------------------------- style
func style_tier() -> int:
	var t := 0
	for i in STYLE_TIERS.size():
		if style >= STYLE_TIERS[i]["need"]:
			t = i
	return t

func style_mult() -> float:
	return 1.0 + style_tier() * 0.2

func style_frac() -> float:
	var t := style_tier()
	var lo: float = STYLE_TIERS[t]["need"]
	var hi: float = STYLE_CAP if t == STYLE_TIERS.size() - 1 else STYLE_TIERS[t + 1]["need"]
	return clamp((style - lo) / max(1.0, hi - lo), 0.0, 1.0)

## Adds style points for an action. Repeating the same action gives less ("freshness").
func add_style(tag: String, pts: float, label: String = "", col: Color = Color.WHITE) -> void:
	var f: float = fresh.get(tag, 1.0)
	var gained := pts * f
	fresh[tag] = max(0.25, f - 0.18)
	if aura_t <= 0.0:
		aura = minf(100.0, aura + gained * 0.04)
	style = min(STYLE_CAP, style + gained)
	style_hold = 1.4
	var tier := style_tier()
	if tier > stats["best_style"]:
		stats["best_style"] = tier
	if label != "":
		style_popup.emit("+" + label, col)

func style_hit_taken(dmg: float) -> void:
	style = max(0.0, style - 40.0 - dmg * 2.0)
	chain_hits = 0

func style_reset() -> void:
	style = 0.0
	chain_hits = 0

func register_hit() -> void:
	chain_hits += 1
	chain_t = now()
	if chain_hits % 12 == 0:
		add_style("chain", 80.0, "%d HIT CHAIN" % chain_hits, Color("#9fe8ff"))

func register_kill(victim_xp: float, crit: bool, by_skill: bool) -> void:
	stats["kills"] += 1
	var t := now()
	kill_times.append(t)
	while kill_times.size() > 0 and t - kill_times[0] > 1.4:
		kill_times.remove_at(0)
	var n := kill_times.size()
	var mult := style_mult()
	var gain := victim_xp * mult * (1.5 if crit else 1.0)
	add_style("kill", 38.0, "KILL" if not crit else "", Color("#ffffff"))
	if by_skill:
		add_style("skillkill", 50.0, "ARTFUL", Color("#c9a6ff"))
	if n == 2:
		add_style("multi", 60.0, "DOUBLE KILL", Color("#ffd166"))
	elif n == 3:
		add_style("multi3", 100.0, "TRIPLE KILL", Color("#ff9f43"))
	elif n >= 4:
		add_style("multi4", 150.0, "MASSACRE", Color("#ff4d4d"))
	add_xp(gain)

# ---------------------------------------------------------------- input
func _key(action: String, keys: Array) -> void:
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

func _mouse(action: String, button: int) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

func _joy(action: String, button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

func _axis(action: String, axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)

func _setup_input() -> void:
	var actions := ["move_left", "move_right", "move_up", "move_down", "attack", "heavy", "dash",
		"guard", "skill", "flask", "interact", "order_follow", "order_charge", "order_hold",
		"war_cry", "volley", "pause", "cycle", "confirm", "help", "aura", "kick", "throw"]
	for a in actions:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a, 0.25)
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_key("attack", [KEY_J])
	_joy("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_mouse("heavy", MOUSE_BUTTON_RIGHT)
	_key("heavy", [KEY_K])
	_axis("heavy", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key("dash", [KEY_SPACE])
	_joy("dash", JOY_BUTTON_B)
	_key("guard", [KEY_SHIFT, KEY_L])
	_joy("guard", JOY_BUTTON_LEFT_SHOULDER)
	_key("skill", [KEY_E])
	_axis("skill", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key("flask", [KEY_R])
	_joy("flask", JOY_BUTTON_X)
	_key("interact", [KEY_F])
	_joy("interact", JOY_BUTTON_Y)
	_key("order_follow", [KEY_1])
	_joy("order_follow", JOY_BUTTON_DPAD_UP)
	_key("order_charge", [KEY_2])
	_joy("order_charge", JOY_BUTTON_DPAD_RIGHT)
	_key("order_hold", [KEY_3])
	_joy("order_hold", JOY_BUTTON_DPAD_DOWN)
	_key("war_cry", [KEY_G])
	_joy("war_cry", JOY_BUTTON_LEFT_STICK)
	_key("volley", [KEY_V])
	_joy("volley", JOY_BUTTON_RIGHT_STICK)
	_key("pause", [KEY_ESCAPE, KEY_P])
	_joy("pause", JOY_BUTTON_START)
	_key("cycle", [KEY_BACKSPACE])
	_joy("cycle", JOY_BUTTON_DPAD_LEFT)
	_key("confirm", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])
	_joy("confirm", JOY_BUTTON_A)
	_key("help", [KEY_F1, KEY_H])
	_key("aura", [KEY_X])
	_joy("aura", JOY_BUTTON_BACK)
	_key("kick", [KEY_C])
	_mouse("kick", MOUSE_BUTTON_XBUTTON1)
	_key("throw", [KEY_T])
	_mouse("throw", MOUSE_BUTTON_MIDDLE)
	_joy("throw", JOY_BUTTON_DPAD_LEFT)
