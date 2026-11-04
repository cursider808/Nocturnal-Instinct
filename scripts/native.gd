class_name Native
extends CharacterBody3D
## Абориген: живёт лагерем (собирает ресурсы, строит), замечает игрока по дистанции,
## углу обзора и шуму, преследует и атакует. Рейдеры ночью атакуют плот.

const Mdl := preload("res://scripts/models.gd")

enum State { IDLE, GATHER, RETURN_TO_CAMP, PATROL, CHASE, ATTACK, FLEE }

const GRAVITY: float = 22.0

var state: int = State.IDLE
var hp: float = 50.0
var camp: Node3D = null          # лагерь (может быть null у рейдеров)
var camp_center: Vector3 = Vector3.ZERO
var is_raider: bool = false
var speed: float = 2.6
var attack_cooldown: float = 0.0
var _timer: float = 0.0
var _gather_target: Node3D = null
var _agent: NavigationAgent3D
var _player: Node3D

func configure(center: Vector3, camp_node: Node3D, raider: bool) -> void:
	camp_center = center
	camp = camp_node
	is_raider = raider
	if raider:
		state = State.CHASE
		camp_center = Vector3.ZERO

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("native")
	collision_layer = 8
	collision_mask = 1
	_speed_scale_from_alarm()
	var body: Node3D = Mdl.make_native()
	add_child(body)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.5
	_agent.target_desired_distance = 1.0
	_agent.radius = 0.4
	add_child(_agent)

func _speed_scale_from_alarm() -> void:
	speed = 2.6 + GameState.alarm / 100.0 * 1.8

func _physics_process(delta: float) -> void:
	if not GameState.simulate:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_player = get_tree().get_first_node_in_group("player")
	_think(delta)
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

# ------------------------------------------------------------------
# Мозг
# ------------------------------------------------------------------

func _think(delta: float) -> void:
	var sees: bool = _can_see_player()
	match state:
		State.IDLE:
			_halt()
			_timer -= delta
			if sees:
				_enter_chase()
			elif _timer <= 0.0:
				_set_state(State.PATROL if randf() < 0.6 else State.GATHER)
		State.PATROL:
			if sees:
				_enter_chase()
				return
			_timer -= delta
			if _timer <= 0.0 or not _step_to(camp_center + _rand_offset(9.0), delta, speed):
				_set_state(State.IDLE)
		State.GATHER:
			if sees:
				_enter_chase()
				return
			_gather_step(delta)
		State.RETURN_TO_CAMP:
			if sees:
				_enter_chase()
				return
			if not _step_to(camp_center, delta, speed):
				if camp != null:
					camp.call("deposit", 1)
				_set_state(State.IDLE)
		State.CHASE:
			if _player == null:
				_set_state(State.RETURN_TO_CAMP)
				return
			var d: float = global_position.distance_to(_player.global_position)
			if d < 2.0:
				_set_state(State.ATTACK)
			elif not sees and d > 26.0:
				_set_state(State.RETURN_TO_CAMP)
			else:
				_move_toward_direct(_player.global_position, delta, speed * 1.25)
		State.ATTACK:
			_halt()
			if _player == null:
				_set_state(State.IDLE)
				return
			var d2: float = global_position.distance_to(_player.global_position)
			if d2 > 2.5:
				_set_state(State.CHASE)
			elif attack_cooldown <= 0.0:
				attack_cooldown = maxf(0.6, 1.4 - GameState.alarm / 100.0 * 0.8)
				AudioManager.play("hit_flesh", global_position, -6.0)
				_player.call("take_damage", 12.0, self)
		State.FLEE:
			_timer -= delta
			if _player != null:
				_move_toward_direct(global_position + (global_position - _player.global_position).normalized() * 12.0, delta, speed * 1.3)
			if _timer <= 0.0:
				_set_state(State.IDLE)
	# Пассивный рост тревоги, когда абориген рядом с плотом игрока.
	if is_raider:
		GameState.add_alarm(0.4 * delta)

func _enter_chase() -> void:
	if state != State.CHASE:
		AudioManager.play("native_scream", global_position, -8.0)
		GameState.add_alarm(3.0)
	_set_state(State.CHASE)

func _gather_step(delta: float) -> void:
	if _gather_target == null or not is_instance_valid(_gather_target):
		_gather_target = _find_resource()
		if _gather_target == null:
			_set_state(State.PATROL)
			return
	if global_position.distance_to(_gather_target.global_position) < 1.6:
		_halt()
		_timer -= delta
		if _timer <= 0.0:
			_set_state(State.RETURN_TO_CAMP)
	else:
		_step_to(_gather_target.global_position, delta, speed)

func _find_resource() -> Node3D:
	var best: Node3D = null
	var best_d: float = 24.0
	for n in get_tree().get_nodes_in_group("harvestable"):
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d and n.call("is_alive"):
			best_d = d
			best = n
	return best

func _set_state(s: int) -> void:
	state = s
	match s:
		State.IDLE: _timer = randf_range(1.5, 3.5)
		State.PATROL: _timer = randf_range(4.0, 8.0)
		State.GATHER: _timer = randf_range(2.0, 4.0)
		State.FLEE: _timer = randf_range(3.0, 5.0)

# ------------------------------------------------------------------
# Обнаружение
# ------------------------------------------------------------------

func _can_see_player() -> bool:
	if _player == null:
		return false
	var detect: float = 12.0 + GameState.alarm * 0.22
	var to: Vector3 = _player.global_position - global_position
	var d: float = to.length()
	if d > detect:
		return false
	to.y = 0.0
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return true
	var angle: float = rad_to_deg(fwd.normalized().angle_to(to.normalized()))
	# Шум: бегущий игрок слышен и сзади.
	var vel: float = (_player.get("velocity") as Vector3).length() if _player.get("velocity") != null else 0.0
	if d < 9.0 and vel > 5.0:
		return true
	return angle < 60.0

# ------------------------------------------------------------------
# Движение
# ------------------------------------------------------------------

func _halt() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0)
	velocity.z = move_toward(velocity.z, 0.0, 20.0)

func _rand_offset(r: float) -> Vector3:
	var a: float = randf() * TAU
	return Vector3(cos(a) * r, 0, sin(a) * r)

func _move_toward_direct(target: Vector3, delta: float, spd: float) -> void:
	var dir: Vector3 = target - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_halt()
		return
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 6.0)

## Двигается по навигации к цели. Возвращает false, если путь пройден.
func _step_to(target: Vector3, delta: float, spd: float) -> bool:
	if _agent.get_navigation_map().is_valid():
		_agent.target_position = target
		if not _agent.is_navigation_finished():
			var next: Vector3 = _agent.get_next_path_position()
			_move_toward_direct(Vector3(next.x, global_position.y, next.z), delta, spd)
			return true
	# Без навигации — прямое движение.
	if global_position.distance_to(target) > 1.0:
		_move_toward_direct(target, delta, spd)
		return true
	return false

func take_damage(amount: float, _from: Node3D = null) -> void:
	hp -= amount
	AudioManager.play("hit_flesh", global_position, -6.0)
	if hp <= 0.0:
		GameState.stats["kills"] = int(GameState.stats.get("kills", 0)) + 1
		GameState.add_alarm(6.0)
		queue_free()
		return
	if hp < 25.0:
		_set_state(State.FLEE)