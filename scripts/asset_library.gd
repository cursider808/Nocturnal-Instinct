class_name AssetLibrary
extends RefCounted
## Загрузка скачанных CC0-моделей (Quaternius) с кэшем.
## Все методы возвращают Node3D или null, если файла нет — тогда вызывающий
## код использует процедурную заглушку.

const NATURE := "res://assets/models/nature/"
const ANIMALS := "res://assets/models/animals/"
const CHARS := "res://assets/models/characters/"

const TREES: Array[String] = ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"]
const PINES: Array[String] = ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"]
const DEAD_TREES: Array[String] = ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"]
const BUSHES: Array[String] = ["Bush_Common", "Bush_Common_Flowers"]
const ROCKS: Array[String] = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_1", "Pebble_Square_1"]
const GRASSES: Array[String] = ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Short", "Grass_Wispy_Tall"]
const PLANTS: Array[String] = ["Plant_1", "Plant_1_Big", "Plant_7", "Plant_7_Big", "Fern_1", "Clover_1", "Clover_2"]
const MUSHROOMS: Array[String] = ["Mushroom_Common", "Mushroom_Laetiporus"]
const ANIMAL_LIST: Array[String] = ["Wolf", "Fox", "Deer", "Stag", "Bull", "Cow", "Donkey", "Horse", "Husky", "ShibaInu", "Alpaca"]

static var _scenes: Dictionary = {}

## Возвращает PackedScene по пути (с кэшем) или null.
static func get_scene(path: String) -> PackedScene:
	if _scenes.has(path):
		return _scenes[path]
	var s: PackedScene = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is PackedScene:
			s = res
	_scenes[path] = s
	return s

## Инстанцирует сцену модели.
static func spawn(path: String) -> Node3D:
	var s: PackedScene = get_scene(path)
	if s == null:
		return null
	var n: Node = s.instantiate()
	return n as Node3D

static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return String(list[rng.randi() % list.size()])

## Дерево (обычное/сосна/сухое/кривое) с лёгким случайным масштабом.
static func tree(rng: RandomNumberGenerator) -> Node3D:
	var pool: Array = TREES + PINES
	if rng.randf() < 0.2:
		pool = DEAD_TREES
	var n: Node3D = spawn(NATURE + _pick(pool, rng) + ".gltf")
	if n != null:
		n.scale *= rng.randf_range(0.9, 1.25)
	return n

static func bush(rng: RandomNumberGenerator) -> Node3D:
	var n: Node3D = spawn(NATURE + _pick(BUSHES, rng) + ".gltf")
	if n != null:
		n.scale *= rng.randf_range(0.9, 1.3)
	return n

static func rock(rng: RandomNumberGenerator) -> Node3D:
	return spawn(NATURE + _pick(ROCKS, rng) + ".gltf")

static func grass(rng: RandomNumberGenerator) -> Node3D:
	var pool: Array = GRASSES + PLANTS
	return spawn(NATURE + _pick(pool, rng) + ".gltf")

static func plant(rng: RandomNumberGenerator) -> Node3D:
	var pool: Array = PLANTS + MUSHROOMS
	return spawn(NATURE + _pick(pool, rng) + ".gltf")

## Животное (можно выбрать конкретное имя или случайное).
static func animal(name: String, rng: RandomNumberGenerator) -> Node3D:
	var file: String = name if name != "" else _pick(ANIMAL_LIST, rng)
	return spawn(ANIMALS + file + ".gltf")

## Базовый персонаж-гуманоид.
static func character(male: bool = true) -> Node3D:
	var file: String = "Superhero_Male_FullBody" if male else "Superhero_Female_FullBody"
	return spawn(CHARS + file + ".gltf")