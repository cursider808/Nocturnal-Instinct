class_name Raft
extends Node3D
## Плот: сетка плит 2x2 м, качка, дрейф, стройка, станции.

const Mdl := preload("res://scripts/models.gd")
const StationScript := preload("res://scripts/station.gd")
const Build := preload("res://scripts/build_lib.gd")

signal tiles_changed

const CELL: float = 2.0
const TILE_TOP: float = 0.25
const MAX_TILES: int = 80

var tiles: Dictionary = {}       # Vector2i -> StaticBody3D
var structures: Dictionary = {}  # ключ -> Node3D
var drift_velocity: Vector3 = Vector3.ZERO
var anchored: bool = false
var has_sail: bool = false
var has_rudder: bool = false
var has_oar: bool = false
var has_anchor: bool = false
var current: Vector3 = Vector3(0.35, 0, 0.18)

var _bob: float = 0.0

func _ready() -> void:
	add_to_group("raft")

## Стартовый плот 3x3.
func build_starting() -> void:
	for x in range(-1, 2):
		for y in range(-1, 2):
			_add_tile(Vector2i(x, y))

func _add_tile(cell: Vector2i) -> bool:
	if tiles.has(cell) or tiles.size() >= MAX_TILES:
		return false
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.add_to_group("raft")
	body.set_meta("cell", cell)
	body.set_meta("hp", 100.0)
	var mi: MeshInstance3D = Mdl.mesh_box(Vector3(CELL, 0.3, CELL), Color(0.42, 0.30, 0.18))
	mi.position.y = 0.1
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(CELL, 0.3, CELL)
	cs.shape = box
	cs.position = Vector3(0, 0.1, 0)
	body.add_child(cs)
	body.position = Vector3(cell.x * CELL, 0.0, cell.y * CELL)
	add_child(body)
	tiles[cell] = body
	GameState.raft_footprint = tiles.size()
	tiles_changed.emit()
	return true

## Повреждение плиты (акула грызёт). При нуле плита разрушается.
func damage_tile(cell: Vector2i, amount: float) -> void:
	if not tiles.has(cell):
		return
	var body: StaticBody3D = tiles[cell]
	var hp: float = float(body.get_meta("hp", 100.0)) - amount
	if hp > 0.0:
		body.set_meta("hp", hp)
		return
	body.queue_free()
	tiles.erase(cell)
	GameState.raft_footprint = tiles.size()
	tiles_changed.emit()
	GameState.show_toast("Акула разрушила плиту плота!")

func cell_of_body(body: Object) -> Vector2i:
	if body != null and body.has_meta("cell"):
		return body.get_meta("cell")
	return Vector2i(99999, 99999)

func _has_neighbor(cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tiles.has(cell + d):
			return true
	return false

## Строит по выбранному предмету игрока. Вызывается из main.
func try_place_build(player: Node3D) -> void:
	var id: String = Inventory.selected_id()
	var item: Dictionary = Recipes.get_item(id)
	var build: String = String(item.get("build", ""))
	if build == "":
		GameState.show_toast("Возьмите в руку то, что строите")
		return
	if not Inventory.has(id, 1):
		return
	var cam: Camera3D = player.get("camera")
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = cam.global_position
	var to: Vector3 = from - cam.global_transform.basis.z * 8.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(q)
	if build == "foundation":
		_place_foundation(hit, id)
	else:
		_place_structure(hit, build, id)

func _place_foundation(hit: Dictionary, id: String) -> void:
	var cell: Vector2i
	if hit.has("collider") and (hit["collider"] as Object).is_in_group("raft"):
		cell = cell_of_body(hit["collider"])
		var n: Vector3 = hit.get("normal", Vector3.UP)
		if absf(n.x) > absf(n.z):
			cell += Vector2i(signi(int(signf(n.x))), 0)
		else:
			cell += Vector2i(0, signi(int(signf(n.z))))
	elif hit.has("position"):
		cell = Vector2i(roundi(hit["position"].x / CELL), roundi(hit["position"].z / CELL))
	else:
		GameState.show_toast("Слишком далеко — встаньте у края")
		return
	if tiles.has(cell):
		return
	if not _has_neighbor(cell):
		GameState.show_toast("Фундамент должен примыкать к плоту")
		return
	if not Inventory.remove(id, 1):
		return
	_add_tile(cell)
	GameState.stats["built"] = int(GameState.stats.get("built", 0)) + 1
	AudioManager.play("hit_wood", global_position, -10.0)
	GameState.show_toast("Фундамент поставлен (%d плит)" % tiles.size())

func _place_structure(hit: Dictionary, build: String, id: String) -> void:
	if not (hit.has("collider") and (hit["collider"] as Object).is_in_group("raft")):
		GameState.show_toast("Ставьте на плиту плота")
		return
	var cell: Vector2i = cell_of_body(hit["collider"])
	var key: String = "%d,%d,%s" % [cell.x, cell.y, build]
	if structures.has(key):
		return
	if not Inventory.remove(id, 1):
		return
	_spawn_structure(cell, build)
	GameState.stats["built"] = int(GameState.stats.get("built", 0)) + 1
	AudioManager.play("craft", global_position, -8.0)
	GameState.show_toast("Построено: " + Recipes.item_name(id))

func _spawn_structure(cell: Vector2i, build: String) -> void:
	var key: String = "%d,%d,%s" % [cell.x, cell.y, build]
	var base: Vector3 = Vector3(cell.x * CELL, TILE_TOP, cell.y * CELL)
	var node: Node3D = Build.spawn_structure(self, base, build)
	_apply_raft_part(build)
	structures[key] = node

## Ставит флаг, если это часть плота (парус/руль/весло/якорь).
func _apply_raft_part(build: String) -> void:
	match build:
		"sail": has_sail = true
		"rudder": has_rudder = true
		"oar": has_oar = true
		"anchor": has_anchor = true

## Есть ли на плоту нужная станция.
func has_station(station_id: String) -> bool:
	for key in structures:
		var n: Node = structures[key]
		if n is Node and String(n.name) != "" and n.get_script() == StationScript:
			if String(n.get("station_id")) == station_id:
				return true
	return false

func toggle_anchor() -> void:
	if not has_anchor:
		GameState.show_toast("Сначала постройте якорь")
		return
	anchored = not anchored
	AudioManager.play("hit_stone", global_position, -10.0)
	GameState.show_toast("Якорь: " + ("опущен" if anchored else "поднят"))

func _process(delta: float) -> void:
	if not GameState.simulate:
		return
	var speed: Vector3 = Vector3.ZERO if anchored else current
	if has_sail and not anchored:
		speed += -transform.basis.z * 1.4
	if has_oar and not anchored:
		speed += transform.basis.z * 0.4
	drift_velocity = speed
	global_position += drift_velocity * delta
	_bob += delta
	rotation.z = sin(_bob * 0.7) * 0.02
	rotation.x = cos(_bob * 0.9) * 0.02
	global_position.y = sin(_bob * 1.1) * 0.04

# --- Сохранение ---

func get_save_data() -> Dictionary:
	var tile_list: Array = []
	for cell in tiles:
		tile_list.append([cell.x, cell.y])
	var struct_list: Array = []
	for key in structures:
		var n: Node = structures[key]
		if n.get_script() == StationScript:
			struct_list.append({"cell": key.split(",").slice(0, 2), "kind": String(n.get("station_id"))})
		else:
			struct_list.append({"cell": key.split(",").slice(0, 2), "kind": key.split(",")[2]})
	return {
		"tiles": tile_list, "structures": struct_list, "anchored": anchored,
		"pos": [global_position.x, global_position.y, global_position.z],
	}

func load_save_data(data: Dictionary) -> void:
	_clear()
	for t in data.get("tiles", []):
		_add_tile(Vector2i(int(t[0]), int(t[1])))
	for s in data.get("structures", []):
		var c: Array = s.get("cell", [0, 0])
		_spawn_structure(Vector2i(int(c[0]), int(c[1])), String(s.get("kind")))
	anchored = bool(data.get("anchored", false))
	var p: Array = data.get("pos", [0, 0, 0])
	global_position = Vector3(p[0], p[1], p[2])

func _clear() -> void:
	for key in structures:
		structures[key].queue_free()
	structures.clear()
	for cell in tiles:
		tiles[cell].queue_free()
	tiles.clear()
	has_sail = false
	has_rudder = false
	has_oar = false
	has_anchor = false