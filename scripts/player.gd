class_name Player
extends CharacterBody3D
## FPS-контроллер: ходьба, бег, плавание, ныряние, кислород, крюк, добыча, стройка.

const Mdl := preload("res://scripts/models.gd")

const WATER_LEVEL: float = 0.0
const WALK_SPEED: float = 4.2
const SPRINT_SPEED: float = 7.0
const SWIM_SPEED: float = 3.2
const JUMP_VELOCITY: float = 5.2
const SWIM_FLOAT_Y: float = -0.5      # центр тела при всплытии
const MOUSE_CLAMP: float = deg_to_rad(88.0)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var ground_ray: RayCast3D = $GroundRay
@onready var view_model: Node3D = $Head/Camera3D/ViewModel

var gravity: float = 22.0
var look_speed: float = 1.0
var in_water: bool = false
var is_diving: bool = false
var _hook_charging: bool = false
var _charge: float = 0.0
var _bob_time: float = 0.0
var _foot_timer: float = 0.0
var _build_mode: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.mouse_mode
	GameState.state_changed.connect(_on_state_changed)
	Inventory.selection_changed.connect(func(_i: int): _refresh_view_model())
	Inventory.inventory_changed.connect(_refresh_view_model)
	refresh_tool_range()
	_refresh_view_model()
	flashlight.visible = false

func _on_state_changed(s: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if s == GameState.State.PLAYING else Input.MOUSE_MODE_VISIBLE
	if s == GameState.State.PLAYING:
		look_speed = GameState.mouse_sensitivity / 0.003

func _unhandled_input(event: InputEvent) -> void:
	if GameState.state != GameState.State.PLAYING or GameState.ui_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * GameState.mouse_sensitivity * look_speed)
		head.rotate_x(-event.relative.y * GameState.mouse_sensitivity * look_speed)
		head.rotation.x = clampf(head.rotation.x, -MOUSE_CLAMP, MOUSE_CLAMP)
	elif event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	elif event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("build_mode"):
		_build_mode = not _build_mode
		GameState.show_toast("Режим стройки: " + ("ВКЛ" if _build_mode else "ВЫКЛ"))
	elif event.is_action_pressed("toggle_craft"):
		_toggle_craft()
	elif event.is_action_pressed("use_primary"):
		_primary()
	elif event.is_action_pressed("use_secondary"):
		_start_hook_charge()
	elif event.is_action_released("use_secondary"):
		_release_hook()

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING or GameState.ui_open:
		return
	_update_water()
	_handle_movement(delta)
	_handle_look_input(delta)
	_handle_footsteps(delta)

func _normalized_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return v

func _update_water() -> void:
	in_water = global_position.y < WATER_LEVEL + 0.15
	var head_y: float = global_position.y + head.position.y
	GameState.submerged = head_y < WATER_LEVEL
	is_diving = in_water and Input.is_action_pressed("sprint")

func _handle_movement(delta: float) -> void:
	var input := _normalized_input()
	var dir := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if in_water:
		_move_swim(delta, dir)
	else:
		_move_walk(delta, dir)

func _move_walk(delta: float, dir: Vector3) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		AudioManager.play("footstep_sand", null, -12.0)
	var sprinting: bool = Input.is_action_pressed("sprint") and GameState.stamina > 1.0
	var speed: float = SPRINT_SPEED if sprinting else WALK_SPEED
	if sprinting:
		GameState.use_stamina(14.0 * delta)
	velocity.x = move_toward(velocity.x, dir.x * speed, 40.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 40.0 * delta)
	# Увлекаем игрока дрейфом плота, если он стоит на нём (полное совпадение скоростей).
	if is_on_floor():
		var floor_body: Object = _floor_body()
		if floor_body != null:
			var dv = floor_body.get("drift_velocity")
			if dv != null and dv is Vector3:
				velocity += dv
	move_and_slide()

func _move_swim(delta: float, dir: Vector3) -> void:
	# Всплытие к поверхности + ныряние.
	var target: float = SWIM_FLOAT_Y
	if is_diving:
		target = -2.2
	var vy_target: float = (target - global_position.y) * 3.0
	velocity.y = lerpf(velocity.y, vy_target, 6.0 * delta)
	if Input.is_action_just_pressed("jump"):
		velocity.y = 6.0
	GameState.use_stamina(9.0 * delta)
	velocity.x = move_toward(velocity.x, dir.x * SWIM_SPEED, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * SWIM_SPEED, 20.0 * delta)
	move_and_slide()
	if global_position.y > WATER_LEVEL + 1.0:
		velocity.y = 0.0

func _floor_body() -> Object:
	ground_ray.force_raycast_update()
	return ground_ray.get_collider() if ground_ray.is_colliding() else null

func _handle_look_input(delta: float) -> void:
	# Небольшое покачивание камеры при ходьбе.
	if is_on_floor() and velocity.length() > 1.0 and not in_water:
		_bob_time += delta * velocity.length()
		camera.position.y = sin(_bob_time * 2.0) * 0.03
	else:
		camera.position.y = move_toward(camera.position.y, 0.0, delta * 0.2)

func _handle_footsteps(delta: float) -> void:
	if in_water or not is_on_floor() or velocity.length() < 1.0:
		return
	_foot_timer -= delta
	if _foot_timer <= 0.0:
		_foot_timer = 0.42 if velocity.length() < 5.0 else 0.3
		AudioManager.play("footstep_wood" if _on_raft() else "footstep_grass", null, -16.0)

func _on_raft() -> bool:
	var b: Object = _floor_body()
	return b != null and b.is_in_group("raft")

# ------------------------------------------------------------------
# Действия
# ------------------------------------------------------------------

func _toggle_flashlight() -> void:
	flashlight.visible = not flashlight.visible
	AudioManager.play("craft", null, -18.0)

func _try_interact() -> void:
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var c: Object = interact_ray.get_collider()
	if c != null and c.has_method("interact"):
		c.call("interact", self)

## Информация для прицела HUD: что под курсором и какое действие подсказать.
func get_hover_info() -> Dictionary:
	if GameState.state != GameState.State.PLAYING or GameState.ui_open:
		return {}
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return {}
	return _hover_for(interact_ray.get_collider())

func _hover_for(c: Object) -> Dictionary:
	if c == null:
		return {}
	if c.is_in_group("harvestable") and c.has_method("is_alive") and bool(c.call("is_alive")):
		var tool: String = String(Recipes.get_item(Inventory.selected_id()).get("tool", ""))
		var need: String = String(c.get("tool_required"))
		var rname: String = Recipes.item_name(String(c.get("resource_id")))
		var icon: String = "hand"
		var verb: String = "Собрать"
		match need:
			"axe": icon = "axe"; verb = "Рубить"
			"pickaxe": icon = "pickaxe"; verb = "Копать"
			"shovel": icon = "shovel"; verb = "Копать"
		if need != "" and tool != need:
			verb = "Нужен инструмент"
		return {"key": "ЛКМ", "text": "%s %s (%d/%d)" % [verb, rname, int(c.get("hp")), int(c.get("max_hp"))], "icon": icon}
	if c.has_method("interact"):
		return {"key": "E", "text": _station_verb(String(c.get("station_id"))), "icon": ""}
	if c.is_in_group("junk"):
		return {"key": "ПКМ", "text": "Зацепить крюком", "icon": "hook"}
	return {}

func _station_verb(sid: String) -> String:
	match sid:
		"chest": return "Открыть сундук"
		"bed": return "Спать"
		"lamp": return "Переключить лампу"
		"research_table": return "Исследовать"
		"workbench": return "Верстак"
		"cooker": return "Плита"
		"purifier": return "Очиститель"
		"garden_plot": return "Собрать грядку"
		_: return "Использовать" if sid != "" else "Взаимодействие"

func _primary() -> void:
	if _build_mode:
		_place_build()
		return
	var id: String = Inventory.selected_id()
	var item: Dictionary = Recipes.get_item(id)
	var tool: String = String(item.get("tool", ""))
	if tool == "fishing_rod":
		_fish()
		return
	if tool in ["axe", "pickaxe", "hammer", "shovel", "spear", "bow"]:
		_swing(item)
		return
	# Пустая рука — просто ткнуть.
	_swing({"tool": "hand", "power": 0})

func _swing(item: Dictionary) -> void:
	AudioManager.play("hit_wood", null, -12.0, randf_range(0.9, 1.1))
	_animate_swing()
	interact_ray.force_raycast_update()
	if not interact_ray.is_colliding():
		return
	var c: Object = interact_ray.get_collider()
	var hit_pos: Vector3 = interact_ray.get_collision_point()
	# Удар по врагу.
	if c != null and c.has_method("take_damage") and c.is_in_group("enemy"):
		c.call("take_damage", float(item.get("damage", 10)), self)
		AudioManager.play("hit_flesh", hit_pos, -6.0)
		return
	# Добыча ресурса.
	if c != null and c.is_in_group("harvestable") and c.has_method("hit"):
		c.call("hit", String(item.get("tool", "hand")), int(item.get("power", 0)), hit_pos)

func _animate_swing() -> void:
	var t := create_tween()
	t.tween_property(view_model, "rotation:z", deg_to_rad(-60.0), 0.08)
	t.tween_property(view_model, "rotation:z", 0.0, 0.16)

func _fish() -> void:
	if Inventory.count("fishing_rod") <= 0:
		return
	AudioManager.play("splash", null, -10.0)
	GameState.show_toast("Ловим рыбу...")
	await get_tree().create_timer(1.4).timeout
	if randf() < 0.7:
		var loot: String = ["raw_fish", "raw_fish", "seaweed"][randi() % 3]
		Inventory.add(loot, 1)
		GameState.stats["collected"] = int(GameState.stats.get("collected", 0)) + 1
		GameState.show_toast("Поймано: " + Recipes.item_name(loot))
	else:
		GameState.show_toast("Сорвалось!")

# ------------------------------------------------------------------
# Крюк-бросалка
# ------------------------------------------------------------------

func _start_hook_charge() -> void:
	var item: Dictionary = Recipes.get_item(Inventory.selected_id())
	if String(item.get("tool", "")) != "hook":
		GameState.show_toast("Возьмите крюк в руку")
		return
	_hook_charging = true
	_charge = 0.0
	AudioManager.play("hook_throw", null, -20.0)

func _release_hook() -> void:
	if not _hook_charging:
		return
	_hook_charging = false
	AudioManager.play("hook_throw", null, -8.0)
	var item: Dictionary = Recipes.get_item(Inventory.selected_id())
	var range_m: float = float(item.get("range", 30)) * (0.5 + 0.5 * _charge)
	_throw_hook(range_m)
	_charge = 0.0

func _throw_hook(range_m: float) -> void:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_transform.basis.z * range_m
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	var target: Node3D = null
	if hit.has("collider"):
		var c: Object = hit["collider"]
		if c is Node3D and c.is_in_group("junk"):
			target = c
	_launch_hook_visual(hit.get("position", to), target)

func _launch_hook_visual(point: Vector3, target: Node3D) -> void:
	var ball: MeshInstance3D = Mdl.mesh_sphere(0.12, Color(0.5, 0.45, 0.4), 6)
	get_tree().current_scene.add_child(ball)
	ball.global_position = camera.global_position
	var t := create_tween()
	t.tween_property(ball, "global_position", point, 0.25)
	if target != null:
		t.tween_callback(func(): _pull_junk(target))
		t.tween_property(ball, "global_position", camera.global_position, 0.5)
	t.tween_callback(ball.queue_free)

func _pull_junk(junk: Node3D) -> void:
	if not is_instance_valid(junk):
		return
	var t := create_tween()
	t.tween_property(junk, "global_position", global_position + Vector3(0, 0.5, 0), 0.6)
	t.tween_callback(func():
		if is_instance_valid(junk) and junk.has_method("collect"):
			junk.call("collect", self))

# ------------------------------------------------------------------
# Стройка
# ------------------------------------------------------------------

func _place_build() -> void:
	var world: Node = get_tree().current_scene
	if world != null and world.has_method("try_place_build"):
		world.call("try_place_build", self)

## Открывает/закрывает меню крафта (узел в группе crafting_menu).
func _toggle_craft() -> void:
	var menus: Array = get_tree().get_nodes_in_group("crafting_menu")
	if menus.is_empty():
		return
	menus[0].call("toggle")

# ------------------------------------------------------------------
# Витрина инструмента
# ------------------------------------------------------------------

func refresh_tool_range() -> void:
	for c in view_model.get_children():
		c.queue_free()
	var id: String = Inventory.selected_id()
	var item: Dictionary = Recipes.get_item(id)
	var tool: String = String(item.get("tool", ""))
	var model: Node3D = null
	match tool:
		"axe", "pickaxe", "hammer", "shovel":
			model = Mdl.make_axe_held()
		"torch", "lantern":
			model = Mdl.make_torch_held()
		"hook":
			model = Mdl.mesh_sphere(0.1, Color(0.5, 0.45, 0.4), 6)
	if model != null:
		view_model.add_child(model)

func _refresh_view_model() -> void:
	refresh_tool_range()

# ------------------------------------------------------------------
# Урон
# ------------------------------------------------------------------

func take_damage(amount: float, _from: Node3D = null) -> void:
	GameState.damage(amount)
	AudioManager.play("player_hurt", global_position, -6.0)

func _process(delta: float) -> void:
	if _hook_charging:
		_charge = minf(1.0, _charge + delta)