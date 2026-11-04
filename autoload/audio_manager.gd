extends Node
## Автозагрузка AudioManager: процедурный синтез всех звуков и их воспроизведение.
## Звуки генерируются как AudioStreamWAV прямо в памяти — внешние файлы не нужны.

const RATE: int = 22050

var lib: Dictionary = {}              # имя -> AudioStreamWAV
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _loops: Dictionary = {}           # имя -> AudioStreamPlayer (зациклено)
var _alarm_player: AudioStreamPlayer

func _ready() -> void:
	_build_library()
	_alarm_player = _make_loop("alarm_ambient", "Ambient", -80.0)
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# Громкость тревожного эмбиента растёт вместе с уровнем тревоги.
	if is_instance_valid(_alarm_player):
		var v: float = lerpf(-34.0, -8.0, clampf(GameState.alarm / 100.0, 0.0, 1.0))
		_alarm_player.volume_db = -80.0 if GameState.alarm < 5.0 else v

# ------------------------------------------------------------------
# Синтез
# ------------------------------------------------------------------

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	stream.data = data
	return stream

## Тон с качанием частоты f0->f1 и простой огибающей.
func _tone(dur: float, f0: float, f1: float, amp: float, kind: String = "sine") -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var f: float = lerpf(f0, f1, t / maxf(dur, 0.0001))
		phase += f / RATE
		var s: float = 0.0
		match kind:
			"sine": s = sin(TAU * phase)
			"square": s = 1.0 if sin(TAU * phase) >= 0.0 else -1.0
			"saw": s = 2.0 * (phase - floor(phase + 0.5))
			"tri": s = 2.0 * abs(2.0 * (phase - floor(phase + 0.5))) - 1.0
		out[i] = s * amp * _env(t, dur)
	return out

## Шум (опционально сглаженный lowpass).
func _noise(dur: float, amp: float, smooth: float = 0.0) -> PackedFloat32Array:
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var raw: float = randf() * 2.0 - 1.0
		prev = lerpf(raw, prev, smooth)
		out[i] = prev * amp * _env(t, dur)
	return out

## Огибающая: быстрая атака, плавный спад.
func _env(t: float, dur: float) -> float:
	var attack: float = minf(0.005, dur * 0.2)
	if t < attack:
		return t / attack
	return pow(1.0 - (t - attack) / maxf(dur - attack, 0.0001), 1.6)

## Складывает два буфера с заданным сдвигом (если b длиннее — расширяет a).
func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: int = 0, b_amp: float = 1.0) -> PackedFloat32Array:
	var need: int = offset + b.size()
	if a.size() < need:
		a.resize(need)
	for i in b.size():
		a[offset + i] += b[i] * b_amp
	return a

## Зацикливаемый буфер с кроссфейдом концов, чтобы не было щелчка.
func _loop_noise(dur: float, amp: float, smooth: float) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _noise(dur, amp, smooth)
	# Убираем огибающую спада на конце для ровного цикла.
	var n: int = buf.size()
	var fade: int = mini(int(0.05 * RATE), int(float(n) / 4.0))
	for i in fade:
		var g: float = float(i) / fade
		buf[i] = lerpf(buf[n - fade + i] * 0.5, buf[i], g)
	return buf

func _build_library() -> void:
	lib["footstep_grass"] = _wav(_noise(0.12, 0.5, 0.6))
	lib["footstep_sand"] = _wav(_noise(0.14, 0.35, 0.85))
	var wood: PackedFloat32Array = _noise(0.10, 0.4, 0.6)
	wood = _mix(wood, _tone(0.10, 180.0, 120.0, 0.3, "sine"))
	lib["footstep_wood"] = _wav(wood)
	lib["footstep_stone"] = _wav(_mix(_noise(0.10, 0.3, 0.4), _tone(0.09, 420.0, 300.0, 0.25)))

	lib["splash"] = _wav(_mix(_noise(0.35, 0.7, 0.3), _tone(0.3, 900.0, 200.0, 0.25, "sine")))
	lib["swim"] = _wav(_noise(0.4, 0.45, 0.2))
	lib["waves"] = _wav(_loop_noise(4.0, 0.5, 0.9), true)
	lib["wind"] = _wav(_loop_noise(4.0, 0.32, 0.95), true)

	var gull: PackedFloat32Array = _tone(0.16, 1400.0, 900.0, 0.4, "saw")
	gull = _mix(gull, _tone(0.16, 1200.0, 700.0, 0.35, "saw"), int(0.22 * RATE))
	lib["seagull"] = _wav(gull)

	lib["rain"] = _wav(_loop_noise(3.0, 0.35, 0.35), true)
	var thunder: PackedFloat32Array = _noise(1.5, 0.7, 0.85)
	thunder = _mix(thunder, _tone(1.4, 60.0, 30.0, 0.5, "sine"))
	lib["thunder"] = _wav(thunder)

	lib["hit_wood"] = _wav(_mix(_tone(0.9, 200.0, 90.0, 0.4), _noise(0.9, 0.35, 0.5)))
	lib["hit_stone"] = _wav(_mix(_tone(0.9, 500.0, 260.0, 0.35), _noise(0.9, 0.4, 0.2)))
	lib["hit_flesh"] = _wav(_mix(_tone(0.9, 160.0, 70.0, 0.5), _noise(0.9, 0.3, 0.7)))

	lib["craft"] = _wav(_mix(_tone(0.14, 600.0, 900.0, 0.35, "tri"), _tone(0.2, 900.0, 1200.0, 0.3, "tri"), int(0.12 * RATE)))
	lib["chest_open"] = _wav(_mix(_noise(0.5, 0.4, 0.8), _tone(0.5, 300.0, 500.0, 0.2, "saw")))
	lib["eat"] = _wav(_noise(0.18, 0.5, 0.4))
	lib["drink"] = _wav(_mix(_tone(0.25, 250.0, 400.0, 0.35, "sine"), _noise(0.25, 0.25, 0.6)))
	lib["fire"] = _wav(_loop_noise(2.5, 0.3, 0.5), true)
	lib["floor_creak"] = _wav(_mix(_tone(0.5, 220.0, 160.0, 0.25, "saw"), _noise(0.5, 0.15, 0.9)))
	lib["door"] = _wav(_mix(_tone(0.7, 180.0, 120.0, 0.3, "saw"), _noise(0.7, 0.2, 0.9)))

	lib["hook_throw"] = _wav(_mix(_tone(0.3, 300.0, 900.0, 0.3, "sine"), _noise(0.3, 0.3, 0.3)))
	lib["sail"] = _wav(_noise(0.5, 0.4, 0.5))
	lib["shark_hit"] = _wav(_mix(_noise(0.4, 0.7, 0.2), _tone(0.35, 120.0, 60.0, 0.4)))
	lib["native_step"] = _wav(_noise(0.12, 0.35, 0.7))
	lib["native_scream"] = _wav(_mix(_tone(0.6, 900.0, 300.0, 0.5, "saw"), _noise(0.6, 0.25, 0.4)))
	lib["player_hurt"] = _wav(_tone(0.25, 400.0, 120.0, 0.5, "sine"))

	var drums: PackedFloat32Array = _tone(0.6, 90.0, 60.0, 0.7, "sine")
	drums = _mix(drums, _tone(0.6, 90.0, 60.0, 0.7, "sine"), int(0.8 * RATE))
	drums = _mix(drums, _tone(0.6, 110.0, 70.0, 0.6, "sine"), int(1.6 * RATE))
	lib["drums"] = _wav(drums, true)

	# Тревожный эмбиент: низкий гудящий дрон с пульсацией.
	var alarm: PackedFloat32Array = _tone(4.0, 55.0, 58.0, 0.5, "sine")
	alarm = _mix(alarm, _tone(4.0, 82.0, 80.0, 0.28, "sine"))
	lib["alarm_ambient"] = _wav(alarm, true)

	# Простая музыка меню: медленное арпеджио в миноре.
	var music := PackedFloat32Array()
	var notes: Array[float] = [220.0, 261.63, 329.63, 261.63, 196.0, 246.94, 293.66, 246.94]
	for k in notes.size():
		music = _mix(music, _tone(1.0, notes[k], notes[k], 0.22, "tri"), int(k * 1.0 * RATE))
	lib["menu_music"] = _wav(music, true)

# ------------------------------------------------------------------
# Воспроизведение
# ------------------------------------------------------------------

func _get_3d() -> AudioStreamPlayer3D:
	for p in _pool3d:
		if not p.playing:
			return p
	var p := AudioStreamPlayer3D.new()
	p.max_distance = 40.0
	add_child(p)
	_pool3d.append(p)
	return p

func _get_2d() -> AudioStreamPlayer:
	for p in _pool2d:
		if not p.playing:
			return p
	var p := AudioStreamPlayer.new()
	add_child(p)
	_pool2d.append(p)
	return p

## Одноразовый звук. position != null -> позиционный (AudioStreamPlayer3D).
func play(sound: String, position: Variant = null, db: float = 0.0, pitch: float = 1.0) -> void:
	if not lib.has(sound):
		return
	if position != null:
		var p: AudioStreamPlayer3D = _get_3d()
		p.stream = lib[sound]
		p.bus = "SFX"
		p.volume_db = db
		p.pitch_scale = pitch
		p.global_position = position
		p.play()
	else:
		var p: AudioStreamPlayer = _get_2d()
		p.stream = lib[sound]
		p.bus = "SFX"
		p.volume_db = db
		p.pitch_scale = pitch
		p.play()

func _make_loop(sound: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = lib.get(sound)
	p.bus = bus
	p.volume_db = db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p

## Постоянный зацикленный звук (ветер, волны, музыка, огонь...).
func loop_play(sound: String, bus: String = "Ambient", db: float = -12.0) -> void:
	if _loops.has(sound):
		return
	var p: AudioStreamPlayer = _make_loop(sound, bus, db)
	p.play()
	_loops[sound] = p

func loop_stop(sound: String) -> void:
	if _loops.has(sound):
		_loops[sound].queue_free()
		_loops.erase(sound)

func loop_set_volume(sound: String, db: float) -> void:
	if _loops.has(sound):
		_loops[sound].volume_db = db

## Применяет настройки громкости к шинам.
func apply_volumes() -> void:
	_set_bus("Master", GameState.vol_master)
	_set_bus("SFX", GameState.vol_sfx)
	_set_bus("Ambient", GameState.vol_ambient)
	_set_bus("Music", GameState.vol_music)

func _set_bus(bus: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))