class_name Shark
extends Node3D
## Акула: кружит у плота, атакует игрока в воде, грызёт плиты плота.

const Mdl := preload("res://scripts/models.gd")

enum Mode { ORBIT, CHASE, BITE, FLEE }

var hp: float = 60.0
var speed: float = 3.2
var mode: int = Mode.ORBIT
var bite_cooldown: float = 0.0
var _orbit_angle: float = 0.0
var _orbit_radius: float = 9.0
var _flee_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("shark")
	_orbit_angle = randf() * TAU
	_orbit_radius = randf_range(7.0, 12.0)
	var body := Mdl.make_shark()
	add_child(body)
	var sb := StaticBody3D.new()
	sb.collision_layer = 8
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.2, 1.0)
	cs.shape = box
	sb.add_child(cs)
	add_child(sb)
	rotation.x = 0.0

func _physics_process(delta: float) -> void:
	if not GameState.simulate:
		return
	bite_cooldown = maxf(0.0, bite_cooldown - delta)
	var raft: Node3D = get_tree().get_first_node_in_group("raft")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var center: Vector3 = raft.global_position if raft != null else (player.global_position if player != null else Vector3.ZERO)

	# Решение о режиме.
	if _flee_timer > 0.0:
		_flee_timer -= delta
		mode = Mode.FLEE
	elif player != null and player.get("in_water") == true and global_position.distance_to(player.global_position) < 22.0:
		mode = Mode.CHASE
	else:
		mode = Mode.ORBIT

	match mode:
		Mode.ORBIT:
			_orbit_angle += (speed / _orbit_radius) * delta
			var target: Vector3 = center + Vector3(cos(_orbit_angle), 0, sin(_orbit_angle)) * _orbit_radius
			_move_toward(target, delta)
			_bite_raft_if_near(raft)
		Mode.CHASE:
			if player != null:
				_move_toward(player.global_position, delta)
				if global_position.distance_to(player.global_position) < 2.0 and bite_cooldown <= 0.0:
					bite_cooldown = 1.6
					AudioManager.play("shark_hit", global_position, -4.0)
					player.call("take_damage", 22.0, self)
		Mode.FLEE:
			_move_toward(global_position + (global_position - center).normalized() * 20.0, delta * 1.6)
	global_position.y = -0.35 + sin(Time.get_ticks_msec() * 0.002) * 0.1

func _move_toward(target: Vector3, delta: float) -> void:
	target.y = global_position.y
	var dir: Vector3 = (target - global_position)
	if dir.length() < 0.1:
		return
	dir = dir.normalized()
	global_position += dir * speed * delta
	# Плавный поворот к цели.
	var desired_yaw: float = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, delta * 2.0)

## Акула грызёт плиту плота, если подплыла к ней.
func _bite_raft_if_near(raft: Node3D) -> void:
	if raft == null or bite_cooldown > 0.0:
		return
	if randf() > 0.004:
		return
	var tiles: Dictionary = raft.get("tiles")
	if tiles.is_empty():
		return
	var keys: Array = tiles.keys()
	var cell: Vector2i = keys[randi() % keys.size()]
	var body: Node3D = tiles[cell]
	if global_position.distance_to(body.global_position) < 3.0:
		bite_cooldown = 2.5
		AudioManager.play("hit_wood", global_position, -6.0)
		raft.call("damage_tile", cell, 20.0)

func take_damage(amount: float, _from: Node3D = null) -> void:
	hp -= amount
	AudioManager.play("hit_flesh", global_position, -4.0)
	_flee_timer = 3.0
	if hp <= 0.0:
		GameState.stats["kills"] = int(GameState.stats.get("kills", 0)) + 1
		GameState.add_alarm(2.0)
		queue_free()