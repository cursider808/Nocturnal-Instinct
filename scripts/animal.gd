class_name Animal
extends CharacterBody3D
## Дикое животное на острове (олень, бык, волк...). Бродит, убегает от игрока,
## при добыче даёт мясо и шкуру. Анимации берутся из модели.

const Mdl := preload("res://scripts/models.gd")

enum State { IDLE, WANDER, FLEE }

var species: String = "Deer"
var hp: float = 25.0
var speed: float = 2.2
var ground_y: float = 1.1
var wander_radius: float = 12.0
var _state: int = State.IDLE
var _timer: float = 1.0
var _target: Vector3 = Vector3.ZERO
var _ap: AnimationPlayer
var _current_anim: String = ""
var _player: Node3D

func configure(species_name: String, gy: float, radius: float) -> void:
	species = species_name
	ground_y = gy
	wander_radius = radius

func _ready() -> void:
	add_to_group("animal")
	add_to_group("enemy")
	collision_layer = 8
	collision_mask = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(species) + get_instance_id()
	var model: Node3D = Mdl.make_animal(species, rng)
	if model != null:
		model.scale *= 0.8
		add_child(model)
		for ap in model.find_children("*", "AnimationPlayer", true, false):
			_ap = ap
			break
	_play("Idle")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	_target = global_position

func _physics_process(delta: float) -> void:
	if not GameState.simulate:
		return
	_think(delta)
	_move(delta)
	# Держим животное на плоскости острова.
	global_position.y = ground_y

func _think(delta: float) -> void:
	_player = get_tree().get_first_node_in_group("player")
	var seeing: bool = _player != null and global_position.distance_to(_player.global_position) < 11.0
	match _state:
		State.IDLE:
			_halt()
			if seeing:
				_state = State.FLEE
				_timer = 3.5
			else:
				_timer -= delta
				if _timer <= 0.0:
					_state = State.WANDER
					_timer = randf_range(3.0, 6.0)
					_target = global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.0, wander_radius)
		State.WANDER:
			if seeing:
				_state = State.FLEE
				_timer = 3.5
			else:
				_timer -= delta
				if _timer <= 0.0 or global_position.distance_to(_target) < 1.0:
					_state = State.IDLE
					_timer = randf_range(1.0, 3.0)
		State.FLEE:
			_timer -= delta
			if _player != null:
				_target = global_position + (global_position - _player.global_position).normalized() * 14.0
			if _timer <= 0.0:
				_state = State.IDLE
				_timer = 1.5

func _move(delta: float) -> void:
	var spd: float = speed * (2.2 if _state == State.FLEE else 1.0)
	var to: Vector3 = _target - global_position
	to.y = 0.0
	if to.length() < 0.4 or _state == State.IDLE:
		_halt()
		_play("Idle")
		return
	var dir: Vector3 = to.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	velocity.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), delta * 5.0)
	move_and_slide()
	_play("Gallop" if _state == State.FLEE else "Walk")

func _halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func _play(anim: String) -> void:
	if _ap == null or _current_anim == anim:
		return
	if _ap.has_animation(anim):
		_ap.play(anim)
		_current_anim = anim

func take_damage(amount: float, _from: Node3D = null) -> void:
	hp -= amount
	AudioManager.play("hit_flesh", global_position, -6.0)
	if hp <= 0.0:
		_die()

func _die() -> void:
	Inventory.add("raw_meat", 2)
	if randf() < 0.7:
		Inventory.add("hide", 1)
	GameState.stats["kills"] = int(GameState.stats.get("kills", 0)) + 1
	GameState.show_toast("Добыто мясо")
	_play("Death")
	# Отключаем логику и убираем через пару секунд.
	set_physics_process(false)
	collision_layer = 0
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(queue_free)