extends Node
## Автозагрузка GameState: показатели выживания, время, тревога, настройки.

signal stats_changed
signal time_changed
signal alarm_changed
signal day_changed(day: int)
signal died
signal won
signal state_changed(new_state: int)
signal toast(text: String)
signal warn(text: String)

enum State { MENU, PLAYING, PAUSED, DEAD, WON }

const DAY_LENGTH_SEC: float = 720.0  # 12 минут реального времени = 1 сутки
const GOAL_DAYS: int = 10

# --- Выживание ---
var health: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var stamina: float = 100.0
var oxygen: float = 100.0
var warmth: float = 100.0

# --- Время ---
var day: int = 1
var time_of_day: float = 8.0  # часы 0..24

# --- Тревога аборигенов 0..100 ---
var alarm: float = 0.0

var unlocked_recipes: Dictionary = {}
var stats: Dictionary = {"kills": 0, "collected": 0, "built": 0}
# Доля снижения урона от брони (0..1).
var armor: float = 0.0
var world_seed: int = 0

# --- Настройки ---
var mouse_sensitivity: float = 0.003
var vol_master: float = 0.0
var vol_sfx: float = 0.0
var vol_ambient: float = 0.0
var vol_music: float = 0.0
var brightness: float = 1.0
var window_mode: int = 0   # 0 окно, 1 полный экран, 2 без рамки

var state: int = State.MENU
var simulate: bool = false
# Открыт ли интерфейс (крафт/пауза) — тогда игрок не реагирует на ввод.
var ui_open: bool = false

# Растёт только когда игрок под водой (ставит player.gd).
var submerged: bool = false
# Близость к лагерю аборигенов усиливает тревогу (ставит мир).
var camp_proximity: float = 0.0
# Размер плота и построек влияет на тревогу (ставит raft.gd).
var raft_footprint: int = 0

func _process(delta: float) -> void:
	if not simulate:
		return
	_tick_time(delta)
	_tick_survival(delta)

func _tick_time(delta: float) -> void:
	time_of_day += (24.0 / DAY_LENGTH_SEC) * delta
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day += 1
		day_changed.emit(day)
		if day > GOAL_DAYS:
			win()
	time_changed.emit()

func _tick_survival(delta: float) -> void:
	hunger = maxf(0.0, hunger - 0.11 * delta)
	thirst = maxf(0.0, thirst - 0.15 * delta)
	# Восстановление выносливости, когда игрок не бежит/плывёт.
	if stamina < 100.0:
		stamina = minf(100.0, stamina + 11.0 * delta)
	# Кислород под водой.
	if submerged:
		oxygen = maxf(0.0, oxygen - 9.0 * delta)
		if oxygen <= 0.0:
			damage(7.0 * delta, true)
	else:
		oxygen = minf(100.0, oxygen + 30.0 * delta)
	# Голод/жажда бьют по здоровью.
	if hunger <= 0.0:
		damage(1.6 * delta, true)
	if thirst <= 0.0:
		damage(2.4 * delta, true)
	# Ночью холодно; огонь рядом согревает (ставит мир).
	var night: bool = time_of_day < 6.0 or time_of_day > 21.0
	var target_warmth: float = 25.0 if night else 100.0
	warmth = move_toward(warmth, target_warmth, 4.0 * delta)
	if warmth < 15.0:
		damage(1.2 * delta, true)
	stats_changed.emit()

# --- Урон и лечение ---

func damage(amount: float, ignore_armor: bool = false) -> void:
	if state != State.PLAYING:
		return
	var applied: float = amount
	if not ignore_armor:
		applied *= (1.0 - armor)
	health -= applied
	stats_changed.emit()
	if health <= 0.0:
		die()

func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, 100.0)
	stats_changed.emit()

func feed(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, 100.0)
	stats_changed.emit()

func hydrate(amount: float) -> void:
	thirst = clampf(thirst + amount, 0.0, 100.0)
	stats_changed.emit()

func use_stamina(amount: float) -> bool:
	if stamina <= 0.0:
		return false
	stamina = maxf(0.0, stamina - amount)
	return true

func add_alarm(amount: float) -> void:
	set_alarm(alarm + amount)

func set_alarm(value: float) -> void:
	alarm = clampf(value, 0.0, 100.0)
	alarm_changed.emit()

# --- Состояние игры ---

func set_state(s: int) -> void:
	state = s
	simulate = (s == State.PLAYING)
	state_changed.emit(s)

func die() -> void:
	if state == State.DEAD:
		return
	set_state(State.DEAD)
	died.emit()

func win() -> void:
	if state == State.WON:
		return
	set_state(State.WON)
	won.emit()

func show_toast(text: String) -> void:
	toast.emit(text)

func show_warn(text: String) -> void:
	warn.emit(text)

## Фаза суток по игровому времени.
func day_phase() -> String:
	var t: float = time_of_day
	if t >= 5.0 and t < 7.0:
		return "dawn"
	if t >= 7.0 and t < 18.0:
		return "day"
	if t >= 18.0 and t < 20.0:
		return "dusk"
	return "night"

## Полный сброс для новой игры.
func new_game(seed_value: int = -1) -> void:
	health = 100.0
	hunger = 100.0
	thirst = 100.0
	stamina = 100.0
	oxygen = 100.0
	warmth = 100.0
	day = 1
	time_of_day = 8.0
	alarm = 0.0
	unlocked_recipes = {}
	stats = {"kills": 0, "collected": 0, "built": 0}
	world_seed = seed_value if seed_value >= 0 else randi()
	submerged = false
	camp_proximity = 0.0
	raft_footprint = 0

# --- Сохранение настроек и прогресса ---

func to_dict() -> Dictionary:
	return {
		"day": day, "time": time_of_day, "alarm": alarm,
		"health": health, "hunger": hunger, "thirst": thirst, "warmth": warmth,
		"unlocked": unlocked_recipes.keys(), "stats": stats, "seed": world_seed,
	}

func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	time_of_day = float(d.get("time", 8.0))
	alarm = float(d.get("alarm", 0.0))
	health = float(d.get("health", 100.0))
	hunger = float(d.get("hunger", 100.0))
	thirst = float(d.get("thirst", 100.0))
	warmth = float(d.get("warmth", 100.0))
	stats = d.get("stats", {"kills": 0, "collected": 0, "built": 0})
	world_seed = int(d.get("seed", 0))
	unlocked_recipes = {}
	for id in d.get("unlocked", []):
		unlocked_recipes[String(id)] = true