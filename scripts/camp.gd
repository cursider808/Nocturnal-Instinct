class_name Camp
extends Node3D
## Лагерь аборигенов: копит ресурсы и достраивает хижины, костёр, частокол, склад.

const Mdl := preload("res://scripts/models.gd")

var stock: int = 0
var structures: Array[Node3D] = []
var _next_threshold: int = 4

func _ready() -> void:
	add_to_group("camp")
	# Базовый костёр всегда есть.
	_add(Mdl.make_campfire(), Vector3.ZERO, "fire")
	_add(Mdl.make_hut(), Vector3(4, 0, 0), "hut")

## Аборигены приносят ресурсы.
func deposit(amount: int) -> void:
	stock += amount
	if stock >= _next_threshold:
		stock = 0
		_next_threshold += 3
		_build_next()

func _build_next() -> void:
	var rng := RandomNumberGenerator.new()
	var a: float = randf() * TAU
	var r: float = rng.randf_range(3.0, 8.0)
	var pos := Vector3(cos(a) * r, 0, sin(a) * r)
	if structures.size() % 2 == 0:
		_add(Mdl.make_hut(), pos, "hut")
	else:
		_add(Mdl.make_barrel(), pos, "store")
	# Сообщаем миру, что лагерь растёт — тревога выше.
	GameState.add_alarm(1.5)

func _add(model: Node3D, pos: Vector3, _kind: String) -> void:
	model.position = pos
	add_child(model)
	structures.append(model)