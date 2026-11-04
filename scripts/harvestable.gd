class_name Harvestable
extends StaticBody3D
## Добываемый ресурс (дерево, камень, куст...). Восстанавливается со временем.

const Mdl := preload("res://scripts/models.gd")

var resource_id: String = "wood_log"
var tool_required: String = "axe"
var amount: int = 1
var hp: int = 3
var max_hp: int = 3
var respawn_time: float = 45.0
var kind: String = "tree"
var _alive: bool = true
var _timer: float = 0.0
var _collision: CollisionShape3D
var _model: Node3D

func _ready() -> void:
	add_to_group("harvestable")
	collision_layer = 32   # слой harvestable
	collision_mask = 0

## Настраивает ресурс нужного типа: параметры + модель + коллизия.
func configure(kind_name: String, rng: RandomNumberGenerator) -> void:
	kind = kind_name
	_setup_params()
	_build_visual(rng)

func _setup_params() -> void:
	match kind:
		"tree":
			resource_id = "wood_log"; tool_required = "axe"; max_hp = 3; amount = 2; respawn_time = 60.0
		"palm":
			resource_id = "palm_leaf"; tool_required = "axe"; max_hp = 2; amount = 2; respawn_time = 55.0
		"rock":
			resource_id = "stone"; tool_required = "pickaxe"; max_hp = 3; amount = 2; respawn_time = 70.0
		"ore":
			resource_id = "ore"; tool_required = "pickaxe"; max_hp = 4; amount = 1; respawn_time = 120.0
		"bush":
			resource_id = "berry"; tool_required = ""; max_hp = 1; amount = 2; respawn_time = 40.0
		"grass":
			resource_id = "fiber"; tool_required = ""; max_hp = 1; amount = 3; respawn_time = 30.0
		"clay":
			resource_id = "clay"; tool_required = "shovel"; max_hp = 2; amount = 2; respawn_time = 60.0
		"sand":
			resource_id = "sand"; tool_required = "shovel"; max_hp = 2; amount = 2; respawn_time = 60.0
	hp = max_hp

func _build_visual(rng: RandomNumberGenerator) -> void:
	_model = Node3D.new()
	var col := CollisionShape3D.new()
	match kind:
		"tree":
			_model.add_child(Mdl.make_tree(rng))
			var c1 := CylinderShape3D.new(); c1.radius = 0.6; c1.height = 5.0
			col.shape = c1; col.position = Vector3(0, 2.5, 0)
		"palm":
			_model.add_child(Mdl.make_palm(rng))
			var c2 := CylinderShape3D.new(); c2.radius = 0.5; c2.height = 5.0
			col.shape = c2; col.position = Vector3(0, 2.5, 0)
		"rock":
			_model.add_child(Mdl.make_rock(rng))
			var c3 := SphereShape3D.new(); c3.radius = 1.1
			col.shape = c3; col.position = Vector3(0, 0.8, 0)
		"ore":
			_model.add_child(Mdl.make_ore(rng))
			var c4 := SphereShape3D.new(); c4.radius = 1.1
			col.shape = c4; col.position = Vector3(0, 0.8, 0)
		"bush":
			_model.add_child(Mdl.make_bush(rng))
			var c5 := SphereShape3D.new(); c5.radius = 0.9
			col.shape = c5; col.position = Vector3(0, 0.7, 0)
		"grass":
			_model.add_child(Mdl.make_grass(rng))
			var c6 := SphereShape3D.new(); c6.radius = 0.5
			col.shape = c6; col.position = Vector3(0, 0.3, 0)
		"clay", "sand":
			_model.add_child(Mdl.mesh_box(Vector3(1.2, 0.4, 1.2), Color(0.55, 0.35, 0.28) if kind == "clay" else Color(0.78, 0.72, 0.52)))
			var c7 := BoxShape3D.new(); c7.size = Vector3(1.2, 0.4, 1.2)
			col.shape = c7; col.position = Vector3(0, 0.2, 0)
	_collision = col
	add_child(_model)
	add_child(col)

## Удар инструментом: tool — тип инструмента, power — уровень.
func hit(tool: String, power: int, _pos: Vector3) -> void:
	if not _alive:
		return
	if tool_required != "" and tool != tool_required:
		AudioManager.play("hit_wood", global_position, -14.0)
		GameState.show_toast("Нужен инструмент получше")
		return
	hp -= 1 + power
	AudioManager.play("hit_stone" if tool_required == "pickaxe" else "hit_wood", global_position, -8.0)
	if hp <= 0:
		_gather()

## Собрать ресурс и спрятать до восстановления.
func _gather() -> void:
	_alive = false
	var leftover: int = Inventory.add(resource_id, amount)
	GameState.stats["collected"] = int(GameState.stats.get("collected", 0)) + amount
	GameState.show_toast("+%d %s" % [leftover if leftover == amount else amount, Recipes.item_name(resource_id)])
	if kind == "palm" and randf() < 0.5:
		Inventory.add("coconut", 1)
	if kind == "tree" and randf() < 0.3:
		Inventory.add("fiber", 1)
	_model.visible = false
	_collision.set_deferred("disabled", true)
	_timer = respawn_time
	set_process(true)

## Взаимодействие (E): мгновенный сбор кустов и травы.
func interact(_player: Node) -> void:
	if _alive and tool_required == "":
		_gather()

func _process(delta: float) -> void:
	if _alive:
		set_process(false)
		return
	_timer -= delta
	if _timer <= 0.0:
		_alive = true
		hp = max_hp
		_model.visible = true
		_collision.set_deferred("disabled", false)
		set_process(false)

func is_alive() -> bool:
	return _alive