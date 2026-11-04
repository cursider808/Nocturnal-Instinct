class_name Junk
extends StaticBody3D
## Плавающий мусор в океане: качается на волнах, дрейфует по течению,
## ловится крюком и содержит предметы.

const Mdl := preload("res://scripts/models.gd")

const CONTAINER_LOOT: Array[String] = ["plank", "plastic", "scrap", "stone", "fiber", "rope", "berry", "sand", "clay"]
const SURFACE_Y: float = 0.0

var junk_kind: String = "plank"
var reward: String = "plank"
var reward_count: int = 1
var is_container: bool = false
var drift: Vector3 = Vector3.ZERO
var bob_phase: float = 0.0
var pull_target: Node3D = null

func configure(kind_name: String, rng: RandomNumberGenerator) -> void:
	junk_kind = kind_name
	bob_phase = rng.randf() * TAU
	add_to_group("junk")
	collision_layer = 16    # слой junk
	collision_mask = 0
	match junk_kind:
		"plank":
			add_child(Mdl.make_plank_debris()); reward = "plank"; is_container = false
		"leaf":
			add_child(Mdl.make_leaf()); reward = "palm_leaf"; is_container = false
		"plastic":
			add_child(Mdl.make_plastic()); reward = "plastic"; is_container = false
		"fish":
			add_child(Mdl.make_fish()); reward = "raw_fish"; is_container = false
		"barrel":
			add_child(Mdl.make_barrel()); reward = "scrap"; is_container = true
		"crate":
			add_child(Mdl.make_crate()); reward = "plank"; is_container = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.7, 1.0)
	cs.shape = box
	cs.position = Vector3(0, 0.2, 0)
	add_child(cs)
	rotation.y = rng.randf() * TAU

## Ловит игрок: выдаёт предметы (или лут из контейнера).
func collect(player: Node) -> void:
	if is_container:
		_give_container_loot()
		AudioManager.play("chest_open", global_position, -6.0)
	else:
		Inventory.add(reward, reward_count)
		AudioManager.play("splash", global_position, -10.0)
	GameState.stats["collected"] = int(GameState.stats.get("collected", 0)) + 1
	if player != null:
		GameState.show_toast("Добыто с мусора")
	queue_free()

func _give_container_loot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count: int = rng.randi_range(2, 4)
	for i in count:
		var id: String = CONTAINER_LOOT[rng.randi() % CONTAINER_LOOT.size()]
		Inventory.add(id, rng.randi_range(1, 3))

func _process(delta: float) -> void:
	# Качание на волнах и дрейф по течению.
	var t: float = Time.get_ticks_msec() * 0.001
	global_position.y = SURFACE_Y + sin(t * 1.6 + bob_phase) * 0.08
	global_position += drift * delta
	rotation.z = sin(t * 1.2 + bob_phase) * 0.08
	rotation.x = cos(t * 1.4 + bob_phase) * 0.08