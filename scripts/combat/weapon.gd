class_name Weapon
extends RefCounted
## Weapon definition. Moves are Dictionaries (see Weapon.mv) describing timing,
## hit shape and damage. Scaling letters follow Elden Ring's convention:
## a weapon gains more damage from STR (strength) or DEX (dexterity) the higher the letter.

const SCALE := {"S": 1.25, "A": 1.0, "B": 0.8, "C": 0.6, "D": 0.4, "E": 0.2, "-": 0.0}
const LEVEL_NAMES := ["", " +1", " +2", " +3"]

var id := ""
var name := ""
var desc := ""
var tex_key := ""
var base := 10.0
var str_s := "C"
var dex_s := "C"
var level := 0
var reach := 30.0
var weight := 1.0
var stance_pow := 1.0
var guard_absorb := 0.6
var guard_stab := 1.0
var guard_break := 1.0
var parry_bonus := 0.0
var bleed := 0.0
var crit_mult := 3.0
var anti_cav := false
var ranged := false
var rest := 40.0          # resting angle (deg) relative to aim
var combo: Array = []
var heavy: Dictionary = {}
var dash_atk: Dictionary = {}
var skill := ""
var skill_name := ""
var skill_cost := 30.0
var shield := false
var proj_speed := 420.0
var clip := 0
var reload := 1.0

static func mv(w: float, a: float, r: float, dmg: float, a0: float, a1: float, extra: Dictionary = {}) -> Dictionary:
	var d := {"w": w, "a": a, "r": r, "dmg": dmg, "a0": a0, "a1": a1, "shape": "arc", "arc": 140.0,
		"rng": 1.0, "lunge": 80.0, "kb": 50.0, "pz": 12.0, "st": 10.0, "cost": 8.0, "ticks": 1,
		"width": 8.0, "ext": 0.0, "sfx": "swing", "hyper": false, "perilous": false, "trail": 1.0}
	d.merge(extra, true)
	return d

func display_name() -> String:
	return name + LEVEL_NAMES[clampi(level, 0, 3)]

func scaling_text() -> String:
	return "STR %s  DEX %s" % [str_s, dex_s]

func str_k() -> float:
	return SCALE[str_s]

func dex_k() -> float:
	return SCALE[dex_s]

static func make(wid: String, lvl: int = 0) -> Weapon:
	var w := Weapon.new()
	w.id = wid
	w.level = lvl
	match wid:
		"jian":
			w.name = "ARMING SWORD"
			w.desc = "STRAIGHT SWORD. FAST 4-HIT COMBO."
			w.tex_key = "jian"
			w.base = 14.0
			w.str_s = "D"
			w.dex_s = "B"
			w.reach = 30.0
			w.combo = [
				mv(0.10, 0.08, 0.20, 1.0, -75, 70, {"lunge": 90.0, "cost": 7.0}),
				mv(0.09, 0.08, 0.20, 1.0, 70, -75, {"lunge": 90.0, "cost": 7.0}),
				mv(0.10, 0.08, 0.22, 1.15, 0, 0, {"shape": "thrust", "rng": 1.2, "lunge": 170.0, "ext": 8.0, "cost": 7.0}),
				mv(0.16, 0.10, 0.30, 1.6, -115, 85, {"arc": 165.0, "lunge": 130.0, "kb": 90.0, "pz": 25.0, "st": 18.0, "sfx": "swing_heavy", "cost": 10.0}),
			]
			w.heavy = mv(0.30, 0.10, 0.34, 2.0, 105, -95, {"arc": 175.0, "lunge": 150.0, "kb": 140.0, "pz": 40.0, "st": 30.0, "hyper": true, "cost": 18.0, "sfx": "swing_heavy"})
			w.dash_atk = mv(0.05, 0.10, 0.24, 1.35, 0, 0, {"shape": "thrust", "rng": 1.25, "lunge": 280.0, "ext": 10.0, "pz": 22.0})
			w.skill = "gale_slash"
			w.skill_name = "GALE SLASH"
			w.skill_cost = 30.0
		"glaive":
			w.name = "WAR GLAIVE"
			w.desc = "GREAT GLAIVE. HUGE SWEEPS, LONG REACH."
			w.tex_key = "glaive"
			w.base = 22.0
			w.str_s = "B"
			w.dex_s = "D"
			w.reach = 44.0
			w.weight = 1.6
			w.stance_pow = 1.3
			w.guard_absorb = 0.55
			w.rest = 30.0
			w.combo = [
				mv(0.18, 0.12, 0.28, 1.0, -95, 95, {"arc": 200.0, "lunge": 70.0, "kb": 80.0, "pz": 25.0, "st": 15.0, "cost": 13.0, "sfx": "swing_heavy"}),
				mv(0.14, 0.12, 0.30, 1.0, 95, -105, {"arc": 200.0, "lunge": 70.0, "kb": 80.0, "pz": 25.0, "st": 15.0, "cost": 13.0, "sfx": "swing_heavy"}),
				mv(0.24, 0.10, 0.40, 1.55, -130, 10, {"arc": 70.0, "rng": 1.15, "lunge": 120.0, "kb": 130.0, "pz": 45.0, "st": 32.0, "cost": 15.0, "sfx": "swing_heavy"}),
			]
			w.heavy = mv(0.32, 0.32, 0.36, 1.7, 0, 360, {"shape": "circle", "kb": 150.0, "pz": 50.0, "st": 34.0, "hyper": true, "cost": 22.0, "sfx": "swing_heavy", "lunge": 40.0})
			w.dash_atk = mv(0.06, 0.12, 0.30, 1.25, -80, 80, {"arc": 160.0, "lunge": 230.0, "kb": 90.0, "pz": 30.0})
			w.skill = "tempest"
			w.skill_name = "TEMPEST SPIN"
			w.skill_cost = 45.0
		"spear":
			w.name = "WAR PIKE"
			w.desc = "LONG THRUSTS. DOUBLE DAMAGE TO CAVALRY."
			w.tex_key = "spear"
			w.base = 15.0
			w.str_s = "C"
			w.dex_s = "C"
			w.reach = 48.0
			w.weight = 1.2
			w.anti_cav = true
			w.rest = 15.0
			w.combo = [
				mv(0.10, 0.07, 0.18, 1.0, 0, 0, {"shape": "thrust", "lunge": 80.0, "ext": 10.0, "width": 7.0, "cost": 7.0, "sfx": "swing_fast"}),
				mv(0.09, 0.07, 0.18, 1.0, 0, 0, {"shape": "thrust", "lunge": 80.0, "ext": 10.0, "width": 7.0, "cost": 7.0, "sfx": "swing_fast"}),
				mv(0.16, 0.10, 0.30, 1.45, 0, 0, {"shape": "thrust", "lunge": 230.0, "ext": 14.0, "width": 8.0, "pz": 30.0, "st": 20.0, "kb": 100.0, "cost": 10.0}),
			]
			w.heavy = mv(0.30, 0.10, 0.34, 2.0, 0, 0, {"shape": "thrust", "rng": 1.3, "lunge": 270.0, "ext": 16.0, "width": 9.0, "pz": 45.0, "st": 30.0, "kb": 150.0, "hyper": true, "cost": 18.0})
			w.dash_atk = mv(0.05, 0.10, 0.26, 1.45, 0, 0, {"shape": "thrust", "rng": 1.2, "lunge": 330.0, "ext": 14.0, "pz": 30.0, "kb": 120.0})
			w.skill = "piercing_charge"
			w.skill_name = "PIERCING CHARGE"
			w.skill_cost = 35.0
		"sidearm":
			# drawn after you throw your weapon: quick but weak, so go and pick something up
			w.name = "SIDE KNIFE"
			w.desc = "YOUR LAST BLADE. QUICK BUT WEAK."
			w.tex_key = "daggers"
			w.base = 6.5
			w.str_s = "D"
			w.dex_s = "B"
			w.reach = 21.0
			w.weight = 0.4
			w.crit_mult = 3.2
			w.guard_absorb = 0.35
			for k in 3:
				var s := -1.0 if k % 2 == 0 else 1.0
				w.combo.append(mv(0.05, 0.05, 0.12, 1.0, 60 * s, -60 * s, {"arc": 120.0, "lunge": 80.0, "cost": 4.0, "pz": 7.0, "st": 6.0, "kb": 25.0, "sfx": "swing_fast", "trail": 0.7}))
			w.heavy = mv(0.16, 0.08, 0.24, 1.9, 0, 0, {"shape": "thrust", "lunge": 160.0, "ext": 6.0, "pz": 18.0, "st": 14.0, "cost": 10.0})
			w.dash_atk = mv(0.04, 0.10, 0.20, 1.2, 0, 0, {"shape": "thrust", "lunge": 240.0, "ext": 6.0, "pz": 12.0})
			w.skill = "blade_dance"
			w.skill_name = "BLADE DANCE"
			w.skill_cost = 50.0
		"daggers":
			w.name = "TWIN DAGGERS"
			w.desc = "BLINDING SPEED. BUILDS BLEED."
			w.tex_key = "daggers"
			w.base = 7.5
			w.str_s = "E"
			w.dex_s = "A"
			w.reach = 22.0
			w.weight = 0.5
			w.bleed = 16.0
			w.crit_mult = 3.6
			w.guard_absorb = 0.4
			for k in 6:
				var s := -1.0 if k % 2 == 0 else 1.0
				w.combo.append(mv(0.05, 0.05, 0.10, 1.0, 60 * s, -60 * s, {"arc": 130.0, "lunge": 75.0, "cost": 4.0, "pz": 6.0, "st": 5.0, "kb": 20.0, "sfx": "swing_fast", "trail": 0.7}))
			w.heavy = mv(0.18, 0.10, 0.24, 2.2, -95, 95, {"arc": 150.0, "lunge": 130.0, "pz": 20.0, "st": 15.0, "cost": 12.0})
			w.dash_atk = mv(0.04, 0.16, 0.20, 1.2, 0, 360, {"shape": "circle", "rng": 1.3, "lunge": 250.0, "ticks": 2, "pz": 10.0})
			w.skill = "blade_dance"
			w.skill_name = "BLADE DANCE"
			w.skill_cost = 40.0
		"axe":
			w.name = "WAR AXE"
			w.desc = "CRUSHING CHOPS. MASSIVE STANCE DAMAGE."
			w.tex_key = "axe"
			w.base = 26.0
			w.str_s = "A"
			w.dex_s = "-"
			w.reach = 33.0
			w.weight = 1.8
			w.stance_pow = 1.6
			w.guard_absorb = 0.5
			w.guard_break = 1.6
			w.combo = [
				mv(0.22, 0.10, 0.36, 1.0, -125, 40, {"arc": 145.0, "lunge": 90.0, "kb": 110.0, "pz": 40.0, "st": 28.0, "cost": 15.0, "sfx": "swing_heavy"}),
				mv(0.20, 0.10, 0.40, 1.1, 125, -40, {"arc": 145.0, "lunge": 90.0, "kb": 110.0, "pz": 40.0, "st": 28.0, "cost": 15.0, "sfx": "swing_heavy", "hyper": true}),
			]
			w.heavy = mv(0.38, 0.10, 0.45, 2.2, -150, 10, {"arc": 90.0, "rng": 1.15, "lunge": 110.0, "kb": 170.0, "pz": 70.0, "st": 45.0, "hyper": true, "cost": 22.0, "sfx": "swing_heavy", "quake": 46.0})
			w.dash_atk = mv(0.08, 0.10, 0.34, 1.4, -100, 40, {"arc": 140.0, "lunge": 220.0, "kb": 120.0, "pz": 40.0})
			w.skill = "earthsplitter"
			w.skill_name = "EARTHSPLITTER"
			w.skill_cost = 45.0
		"zhanmadao":
			w.name = "GREATSWORD"
			w.desc = "HORSE-CUTTING SABER. WIDE CLEAVES."
			w.tex_key = "zhanmadao"
			w.base = 20.0
			w.str_s = "B"
			w.dex_s = "C"
			w.reach = 38.0
			w.weight = 1.5
			w.anti_cav = true
			w.stance_pow = 1.2
			w.combo = [
				mv(0.16, 0.10, 0.26, 1.0, -105, 80, {"arc": 175.0, "lunge": 110.0, "kb": 70.0, "pz": 28.0, "st": 18.0, "cost": 11.0, "sfx": "swing_heavy"}),
				mv(0.14, 0.10, 0.28, 1.0, 80, -105, {"arc": 175.0, "lunge": 110.0, "kb": 70.0, "pz": 28.0, "st": 18.0, "cost": 11.0, "sfx": "swing_heavy"}),
				mv(0.18, 0.10, 0.34, 1.3, 125, -65, {"arc": 170.0, "lunge": 140.0, "kb": 110.0, "pz": 35.0, "st": 24.0, "cost": 13.0, "sfx": "swing_heavy"}),
			]
			w.heavy = mv(0.30, 0.12, 0.40, 2.1, -110, 95, {"arc": 180.0, "lunge": 260.0, "kb": 150.0, "pz": 50.0, "st": 35.0, "hyper": true, "cost": 20.0, "sfx": "swing_heavy"})
			w.dash_atk = mv(0.06, 0.10, 0.30, 1.3, -90, 80, {"arc": 160.0, "lunge": 270.0, "kb": 100.0, "pz": 30.0})
			w.skill = "horse_cleaver"
			w.skill_name = "HORSE CLEAVER"
			w.skill_cost = 40.0
		"sword_shield":
			w.name = "SWORD + SHIELD"
			w.desc = "SUPERB GUARD AND PARRY. SHIELD BASH."
			w.tex_key = "shortsword"
			w.base = 11.0
			w.str_s = "C"
			w.dex_s = "C"
			w.reach = 26.0
			w.weight = 0.9
			w.guard_absorb = 0.95
			w.guard_stab = 0.55
			w.parry_bonus = 0.08
			w.shield = true
			w.combo = [
				mv(0.08, 0.07, 0.18, 1.0, 0, 0, {"shape": "thrust", "lunge": 110.0, "ext": 7.0, "cost": 6.0, "sfx": "swing_fast"}),
				mv(0.09, 0.08, 0.20, 1.0, -65, 65, {"arc": 130.0, "lunge": 90.0, "cost": 6.0}),
				mv(0.12, 0.08, 0.26, 0.7, -20, 20, {"arc": 110.0, "rng": 0.85, "lunge": 160.0, "kb": 140.0, "pz": 35.0, "st": 35.0, "cost": 9.0, "sfx": "swing_heavy", "bash": true}),
			]
			w.heavy = mv(0.24, 0.12, 0.32, 1.2, -20, 20, {"arc": 120.0, "rng": 0.9, "lunge": 300.0, "kb": 190.0, "pz": 45.0, "st": 42.0, "hyper": true, "cost": 16.0, "bash": true})
			w.dash_atk = mv(0.05, 0.10, 0.24, 1.3, 0, 0, {"shape": "thrust", "lunge": 290.0, "ext": 8.0, "pz": 20.0})
			w.skill = "bulwark_rush"
			w.skill_name = "BULWARK RUSH"
			w.skill_cost = 30.0
		"bow":
			w.name = "COMPOSITE BOW"
			w.desc = "RANGED. HOLD ATTACK TO DRAW A PIERCING SHOT."
			w.tex_key = "bow"
			w.base = 13.0
			w.str_s = "D"
			w.dex_s = "B"
			w.reach = 22.0
			w.weight = 0.7
			w.ranged = true
			w.rest = 0.0
			w.guard_absorb = 0.35
			w.proj_speed = 470.0
			w.combo = [mv(0.12, 0.04, 0.24, 0.8, 0, 0, {"shot": "arrow", "cost": 5.0, "sfx": "bow"})]
			w.heavy = mv(0.20, 0.04, 0.30, 0.8, 0, 0, {"shot": "triple", "cost": 14.0, "sfx": "bow"})
			w.dash_atk = mv(0.04, 0.04, 0.16, 0.9, 0, 0, {"shot": "arrow", "cost": 4.0, "sfx": "bow"})
			w.skill = "arrow_rain"
			w.skill_name = "ARROW RAIN"
			w.skill_cost = 40.0
		"crossbow":
			w.name = "REPEATING CROSSBOW"
			w.desc = "RAPID BOLTS. HOLD ATTACK TO FIRE."
			w.tex_key = "crossbow"
			w.base = 6.0
			w.str_s = "D"
			w.dex_s = "C"
			w.reach = 22.0
			w.weight = 0.8
			w.ranged = true
			w.rest = 0.0
			w.guard_absorb = 0.35
			w.proj_speed = 560.0
			w.clip = 10
			w.reload = 1.4
			w.combo = [mv(0.02, 0.02, 0.14, 1.0, 0, 0, {"shot": "bolt", "cost": 3.0, "sfx": "bow"})]
			w.heavy = mv(0.12, 0.08, 0.26, 0.8, -40, 40, {"arc": 110.0, "rng": 1.0, "lunge": 120.0, "kb": 180.0, "pz": 35.0, "st": 25.0, "cost": 10.0, "bash": true})
			w.dash_atk = w.combo[0]
			w.skill = "bolt_storm"
			w.skill_name = "BOLT STORM"
			w.skill_cost = 35.0
		"hammer":
			w.name = "WAR HAMMER"
			w.desc = "BREAKS GUARDS AND STANCE."
			w.tex_key = "hammer"
			w.base = 18.0
			w.str_s = "A"
			w.dex_s = "E"
			w.reach = 31.0
			w.weight = 1.6
			w.stance_pow = 1.7
			w.guard_break = 2.0
			w.combo = [
				mv(0.18, 0.10, 0.32, 1.0, -105, 60, {"arc": 150.0, "lunge": 90.0, "kb": 90.0, "pz": 35.0, "st": 30.0, "cost": 12.0, "sfx": "swing_heavy"}),
				mv(0.17, 0.10, 0.34, 1.0, 105, -60, {"arc": 150.0, "lunge": 90.0, "kb": 90.0, "pz": 35.0, "st": 30.0, "cost": 12.0, "sfx": "swing_heavy"}),
				mv(0.20, 0.10, 0.38, 1.4, 120, -20, {"arc": 90.0, "lunge": 120.0, "kb": 140.0, "pz": 50.0, "st": 45.0, "cost": 14.0, "sfx": "swing_heavy"}),
			]
			w.heavy = mv(0.34, 0.10, 0.45, 1.8, -160, 0, {"shape": "circle", "rng": 1.5, "kb": 160.0, "pz": 60.0, "st": 55.0, "hyper": true, "cost": 22.0, "sfx": "swing_heavy", "quake": 50.0})
			w.dash_atk = mv(0.08, 0.10, 0.32, 1.3, -100, 50, {"arc": 140.0, "lunge": 220.0, "kb": 120.0, "pz": 40.0, "st": 30.0})
			w.skill = "quake"
			w.skill_name = "QUAKE"
			w.skill_cost = 45.0
		"black_glaive":
			w.name = "HENG YAO'S BLACK GLAIVE"
			w.desc = "THE TYRANT'S GLAIVE."
			w.tex_key = "black_glaive"
			w.base = 20.0
			w.str_s = "A"
			w.dex_s = "C"
			w.reach = 54.0
			w.weight = 1.4
			w.stance_pow = 1.5
			w.guard_absorb = 0.7
			w.rest = 30.0
			w.combo = [
				mv(0.30, 0.13, 0.30, 0.85, -100, 100, {"arc": 210.0, "lunge": 120.0, "kb": 140.0, "pz": 40.0, "st": 25.0, "sfx": "swing_heavy"}),
				mv(0.18, 0.13, 0.32, 0.85, 100, -110, {"arc": 210.0, "lunge": 120.0, "kb": 140.0, "pz": 40.0, "st": 25.0, "sfx": "swing_heavy"}),
				mv(0.32, 0.12, 0.45, 1.3, -150, 10, {"arc": 80.0, "rng": 1.2, "lunge": 200.0, "kb": 200.0, "pz": 70.0, "st": 40.0, "sfx": "swing_heavy", "quake": 60.0}),
			]
			w.heavy = mv(0.55, 0.40, 0.40, 0.8, 0, 720, {"shape": "circle", "rng": 1.1, "ticks": 3, "kb": 160.0, "pz": 60.0, "st": 30.0, "hyper": true, "perilous": true, "sfx": "swing_heavy", "lunge": 60.0})
			w.dash_atk = mv(0.45, 0.14, 0.40, 1.4, 0, 0, {"shape": "thrust", "rng": 1.4, "width": 12.0, "lunge": 520.0, "ext": 18.0, "kb": 220.0, "pz": 80.0, "perilous": true, "hyper": true})
			w.skill = "tempest"
			w.skill_name = "BLACK TEMPEST"
			w.skill_cost = 45.0
		_:
			return make("jian", lvl)
	return w

const PLAYER_POOL := ["jian", "glaive", "spear", "daggers", "axe", "zhanmadao", "sword_shield", "bow", "crossbow", "hammer"]
