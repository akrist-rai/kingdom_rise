extends Node
## Procedural audio: every sound effect and the war-drum music loops are synthesised
## at startup into AudioStreamWAV buffers (no audio files needed).

const RATE := 22050
const VOICES := 28

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var listener := Vector2.ZERO
var music := {}          # name -> AudioStreamPlayer
var loops_ready := false
var intensity := 0.0     # 0..1, drives the intense drum layer
var boss_mode := false
var music_on := true
var want_music := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players.append(pl)
	var t0 := Time.get_ticks_msec()
	_gen_sfx()
	print("[Sfx] sfx built in %d ms" % (Time.get_ticks_msec() - t0))
	WorkerThreadPool.add_task(_gen_loops_thread)

func play(name: String, vol_db: float = 0.0, pitch: float = 1.0, min_gap: float = 0.03) -> void:
	if not streams.has(name):
		return
	var t := Time.get_ticks_msec() / 1000.0
	if t - float(_last.get(name, -10.0)) < min_gap:
		return
	_last[name] = t
	var pl := players[_next]
	_next = (_next + 1) % VOICES
	pl.stream = streams[name]
	pl.volume_db = vol_db
	pl.pitch_scale = pitch * randf_range(0.94, 1.06)
	pl.play()

## Plays a sound with simple distance attenuation from the camera.
func play_at(name: String, pos: Vector2, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var d := pos.distance_to(listener)
	if d > 560.0:
		return
	play(name, vol_db - d / 560.0 * 16.0, pitch, 0.045)

func _process(delta: float) -> void:
	if not loops_ready:
		return
	var target_int := 0.0 if not music_on else intensity
	var mi: AudioStreamPlayer = music["drums_hi"]
	var want := linear_to_db(clamp(target_int, 0.0001, 1.0)) - 4.0
	mi.volume_db = lerp(mi.volume_db, want, clamp(delta * 2.0, 0.0, 1.0))
	var mb: AudioStreamPlayer = music["boss"]
	var mbase: AudioStreamPlayer = music["drums"]
	var bwant := -3.0 if (boss_mode and music_on) else -60.0
	mb.volume_db = lerp(mb.volume_db, bwant, clamp(delta * 1.5, 0.0, 1.0))
	var dwant := -7.0 if (music_on and not boss_mode) else -60.0
	mbase.volume_db = lerp(mbase.volume_db, dwant, clamp(delta * 1.5, 0.0, 1.0))

func start_music() -> void:
	want_music = true
	if not loops_ready:
		return
	for k in music.keys():
		var pl: AudioStreamPlayer = music[k]
		if not pl.playing:
			pl.play()

func stop_music() -> void:
	for k in music.keys():
		music[k].stop()

# ------------------------------------------------------------------ building blocks
func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

func _stream(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s

func _whoosh(dur: float, f_lo: float, f_hi: float, amp: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var n := b.size()
	var l1 := 0.0
	var l2 := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := f_lo + (f_hi - f_lo) * sin(t * PI)
		var a := clampf(TAU * cutoff / RATE, 0.0, 1.0)
		l1 += a * (randf() * 2.0 - 1.0 - l1)
		l2 += a * (l1 - l2)
		var env := pow(sin(t * PI), 1.6)
		b[i] = (l1 - l2 * 0.7) * env * amp
	return b

func _partials(dur: float, freqs: Array, amps: Array, decays: Array, noise_amt: float, noise_decay: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * freqs[k] * t) * amps[k] * exp(-t * decays[k])
		lp += 0.5 * (randf() * 2.0 - 1.0 - lp)
		v += lp * noise_amt * exp(-t * noise_decay)
		b[i] = v * 0.5
	return b

func _thump(dur: float, f0: float, f1: float, fdecay: float, adecay: float, noise_amt: float, noise_decay: float, lp_a: float = 0.2) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t * fdecay)
		ph += TAU * f / RATE
		lp += lp_a * (randf() * 2.0 - 1.0 - lp)
		b[i] = sin(ph) * exp(-t * adecay) + lp * noise_amt * exp(-t * noise_decay)
	return b

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, gb: float = 1.0, offset: int = 0) -> PackedFloat32Array:
	var n: int = max(a.size(), b.size() + offset)
	var o := PackedFloat32Array()
	o.resize(n)
	for i in a.size():
		o[i] = a[i]
	for i in b.size():
		o[i + offset] += b[i] * gb
	return o

func _gain(a: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in a.size():
		a[i] *= g
	return a

# ------------------------------------------------------------------ sound effects
func _gen_sfx() -> void:
	streams["swing"] = _stream(_whoosh(0.15, 700.0, 2600.0, 1.3))
	streams["swing_fast"] = _stream(_whoosh(0.09, 1400.0, 3600.0, 1.0))
	streams["swing_heavy"] = _stream(_whoosh(0.32, 250.0, 1300.0, 1.8))
	streams["dash"] = _stream(_whoosh(0.2, 1800.0, 4200.0, 0.9))
	streams["hit"] = _stream(_thump(0.22, 170.0, 55.0, 30.0, 16.0, 0.9, 45.0, 0.35))
	streams["hit_heavy"] = _stream(_mix(_thump(0.35, 120.0, 40.0, 18.0, 9.0, 1.1, 25.0, 0.3),
		_partials(0.2, [700.0, 1130.0], [0.4, 0.3], [30.0, 40.0], 0.0, 1.0), 0.6))
	streams["clank"] = _stream(_partials(0.3, [830.0, 1247.0, 1979.0, 2671.0, 3433.0], [1.0, 0.7, 0.5, 0.35, 0.2], [14.0, 18.0, 22.0, 26.0, 30.0], 0.8, 80.0))
	streams["block"] = _stream(_mix(_partials(0.25, [520.0, 790.0, 1240.0], [1.0, 0.6, 0.4], [22.0, 26.0, 30.0], 0.6, 60.0),
		_thump(0.15, 140.0, 60.0, 30.0, 25.0, 0.3, 40.0), 0.6))
	streams["parry"] = _stream(_partials(0.8, [1520.0, 2290.0, 3410.0, 4570.0, 5980.0, 1532.0], [1.0, 0.7, 0.5, 0.35, 0.2, 0.6], [5.0, 6.0, 7.0, 9.0, 12.0, 5.5], 1.2, 120.0))
	streams["crit"] = _stream(_mix(_thump(0.6, 110.0, 38.0, 9.0, 6.0, 1.0, 11.0, 0.25),
		_partials(0.4, [640.0, 1020.0, 1610.0], [0.5, 0.4, 0.3], [10.0, 14.0, 18.0], 0.4, 40.0), 0.7))
	streams["break"] = _stream(_mix(_partials(0.5, [2100.0, 1650.0, 1240.0, 930.0], [0.6, 0.5, 0.5, 0.4], [9.0, 8.0, 7.0, 6.0], 1.4, 18.0),
		_thump(0.3, 90.0, 40.0, 15.0, 10.0, 0.3, 20.0), 0.7))
	streams["boom"] = _stream(_thump(0.9, 75.0, 26.0, 4.0, 3.5, 1.0, 5.5, 0.12))
	streams["arrow_hit"] = _stream(_thump(0.1, 420.0, 120.0, 40.0, 40.0, 0.4, 200.0, 0.6))
	streams["ui"] = _stream(_gain(_partials(0.06, [660.0, 1320.0], [1.0, 0.3], [60.0, 80.0], 0.0, 1.0), 0.6))
	streams["pickup"] = _stream(_mix(_partials(0.08, [880.0], [1.0], [30.0], 0.0, 1.0), _partials(0.12, [1320.0, 1760.0], [1.0, 0.4], [20.0, 25.0], 0.0, 1.0), 1.0, int(0.06 * RATE)))
	streams["step"] = _stream(_gain(_thump(0.06, 200.0, 90.0, 60.0, 60.0, 1.0, 70.0, 0.5), 0.25))
	streams["death"] = _stream(_death())
	streams["bow"] = _stream(_bow())
	streams["horn"] = _stream(_horn(2.4, 98.0))
	streams["horn_short"] = _stream(_horn(1.1, 131.0))
	streams["drum"] = _stream(_thump(0.8, 140.0, 50.0, 25.0, 4.5, 0.5, 35.0, 0.25))
	streams["gong"] = _stream(_partials(2.8, [140.0, 141.6, 197.0, 311.0, 421.0, 589.0, 733.0], [1.0, 0.8, 0.7, 0.55, 0.4, 0.3, 0.2], [1.2, 1.25, 1.6, 2.0, 2.6, 3.2, 4.0], 0.5, 30.0))
	streams["possess"] = _stream(_possess())
	streams["skill"] = _stream(_mix(_whoosh(0.4, 400.0, 3000.0, 1.4), _rise(0.4, 500.0, 1900.0, 0.35), 1.0))
	streams["volley"] = _stream(_volley())
	streams["heal"] = _stream(_rise(0.45, 400.0, 900.0, 0.5))

func _death() -> PackedFloat32Array:
	var b := _buf(0.42)
	var ph := 0.0
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 230.0 - 130.0 * (t / 0.42)
		ph += f / RATE
		var tri := 1.0 - 4.0 * absf(fmod(ph, 1.0) - 0.5)
		lp += 0.15 * (randf() * 2.0 - 1.0 - lp)
		var env := minf(1.0, t * 30.0) * exp(-t * 6.0)
		b[i] = (tri * 0.35 + lp * 0.9) * env
	return b

func _bow() -> PackedFloat32Array:
	var b := _buf(0.32)
	var period := int(RATE / 196.0)
	var ring := PackedFloat32Array()
	ring.resize(period)
	for i in period:
		ring[i] = randf() * 2.0 - 1.0
	for i in b.size():
		var j := i % period
		var nx := (j + 1) % period
		var v := (ring[j] + ring[nx]) * 0.5 * 0.985
		ring[j] = v
		b[i] = v * 0.6
	return _mix(b, _thump(0.1, 220.0, 90.0, 40.0, 40.0, 0.2, 80.0), 0.5)

func _horn(dur: float, f0: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph1 := 0.0
	var ph2 := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var vib := 1.0 + 0.012 * sin(TAU * 5.0 * t) * minf(1.0, t * 2.0)
		ph1 += f0 * vib / RATE
		ph2 += f0 * 1.5 * vib / RATE
		var saw := (fmod(ph1, 1.0) * 2.0 - 1.0) + 0.45 * (fmod(ph2, 1.0) * 2.0 - 1.0)
		lp += 0.09 * (saw - lp)
		lp2 += 0.09 * (lp - lp2)
		var env := minf(1.0, t / 0.35) * minf(1.0, (dur - t) / 0.5)
		b[i] = lp2 * env * 1.4
	return b

func _rise(dur: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var f := f0 + (f1 - f0) * t
		ph += TAU * f / RATE
		b[i] = (sin(ph) + 0.3 * sin(ph * 2.01)) * sin(t * PI) * amp
	return b

func _possess() -> PackedFloat32Array:
	var b := _buf(1.0)
	var ph := [0.0, 0.0, 0.0, 0.0]
	var det := [1.0, 1.007, 0.994, 2.0]
	var amp := [0.4, 0.4, 0.4, 0.15]
	for i in b.size():
		var t := float(i) / b.size()
		var f := 330.0 * (1.0 + t * 1.2)
		var v := 0.0
		for k in 4:
			ph[k] += TAU * f * det[k] / RATE
			v += sin(ph[k]) * amp[k]
		b[i] = v * sin(t * PI)
	return b

func _volley() -> PackedFloat32Array:
	var b := _buf(1.2)
	var l1 := 0.0
	var l2 := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var a := 0.35
		l1 += a * (randf() * 2.0 - 1.0 - l1)
		l2 += a * (l1 - l2)
		var trem := 0.6 + 0.4 * sin(TAU * 23.0 * t + sin(TAU * 7.0 * t) * 3.0)
		b[i] = (l1 - l2) * trem * sin(t * PI) * 1.4
	return b

# ------------------------------------------------------------------ music & ambience
func _add_event(b: PackedFloat32Array, ev: PackedFloat32Array, at: int, g: float) -> void:
	var n := b.size()
	for i in ev.size():
		var j := (at + i) % n   # wrap around so the loop is seamless
		b[j] += ev[i] * g

func _gen_loops_thread() -> void:
	var out := {}
	# --- war drums, base layer (100 bpm, 2 bars of 4/4)
	var beat := 0.6
	var drums := _buf(beat * 8.0)
	var don := _thump(0.9, 130.0, 46.0, 22.0, 4.0, 0.45, 30.0, 0.22)
	var don_soft := _gain(_thump(0.6, 160.0, 60.0, 25.0, 6.0, 0.3, 40.0, 0.22), 0.55)
	var ka := _gain(_partials(0.06, [1800.0, 2700.0], [0.5, 0.3], [60.0, 70.0], 1.0, 90.0), 0.5)
	for s in [0.0, 1.5, 2.0, 4.0, 5.5, 6.0, 7.0]:
		_add_event(drums, don, int(s * beat * RATE), 0.9)
	for s in [1.0, 3.0, 3.5, 5.0, 6.5, 7.5]:
		_add_event(drums, don_soft, int(s * beat * RATE), 0.9)
	for s in [0.5, 2.5, 4.5, 6.75]:
		_add_event(drums, ka, int(s * beat * RATE), 0.8)
	out["drums"] = _stream(_gain(drums, 0.55), true)
	# --- intense layer: driving eighths, rim clicks and a low drone
	var hi := _buf(beat * 8.0)
	for k in 16:
		var g := 0.7 if k % 2 == 0 else 0.45
		_add_event(hi, don_soft, int(k * 0.5 * beat * RATE), g)
	for k in 32:
		if k % 4 != 0:
			_add_event(hi, ka, int(k * 0.25 * beat * RATE), 0.35)
	var lp := 0.0
	var ph := 0.0
	for i in hi.size():
		ph += 55.0 / RATE
		lp += 0.03 * ((fmod(ph, 1.0) * 2.0 - 1.0) - lp)
		hi[i] += lp * 0.25
	out["drums_hi"] = _stream(_gain(hi, 0.5), true)
	# --- boss theme: faster, heavier, with horn stabs
	var bbeat := 0.46
	var boss := _buf(bbeat * 8.0)
	for k in 8:
		_add_event(boss, don, int(k * bbeat * RATE), 0.9 if k % 2 == 0 else 0.6)
		_add_event(boss, don_soft, int((k + 0.5) * bbeat * RATE), 0.6)
	for k in 32:
		if k % 3 == 0:
			_add_event(boss, ka, int(k * 0.25 * bbeat * RATE), 0.4)
	_add_event(boss, _gain(_horn(1.4, 73.4), 0.6), 0, 1.0)
	_add_event(boss, _gain(_horn(1.2, 82.4), 0.5), int(4 * bbeat * RATE), 1.0)
	out["boss"] = _stream(_gain(boss, 0.5), true)
	# --- wind ambience (seamless via wrapped noise and periodic modulation)
	var wind := _buf(6.0)
	var w1 := 0.0
	var w2 := 0.0
	for pass_i in 2:
		for i in wind.size():
			var t := float(i) / wind.size()
			var cut := 0.02 + 0.03 * (0.5 + 0.5 * sin(TAU * t * 2.0)) + 0.015 * sin(TAU * t * 5.0)
			w1 += cut * (randf() * 2.0 - 1.0 - w1)
			w2 += cut * (w1 - w2)
			if pass_i == 1:
				var amp := 0.6 + 0.4 * sin(TAU * t * 3.0 + 1.0)
				wind[i] = w2 * 5.0 * amp
	out["wind"] = _stream(wind, true)
	# --- distant battle ambience: murmur and far-away clashes
	var amb := _buf(8.0)
	var br := 0.0
	for i in amb.size():
		br += 0.02 * (randf() * 2.0 - 1.0 - br)
		amb[i] = br * 1.6
	var clash := _gain(_partials(0.25, [830.0, 1247.0, 1979.0], [1.0, 0.7, 0.5], [16.0, 20.0, 24.0], 0.4, 60.0), 0.12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 26:
		_add_event(amb, clash, rng.randi_range(0, amb.size() - 1), rng.randf_range(0.4, 1.0))
	out["ambience"] = _stream(amb, true)
	call_deferred("_loops_done", out)

func _loops_done(out: Dictionary) -> void:
	for k in out.keys():
		var pl := AudioStreamPlayer.new()
		pl.stream = out[k]
		pl.volume_db = -60.0
		add_child(pl)
		music[k] = pl
	music["wind"].volume_db = -14.0
	music["ambience"].volume_db = -12.0
	loops_ready = true
	music["wind"].play()
	music["ambience"].play()
	if want_music:
		start_music()
	print("[Sfx] music loops ready")
