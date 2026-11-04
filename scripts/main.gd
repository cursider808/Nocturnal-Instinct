extends Node3D
## Главный мир: океан, острова, плот, враги, погода, день/ночь, менеджеры.

const PlayerScene := preload("res://scenes/player.tscn")
const JunkScript := preload("res://scripts/junk.gd")
const SharkScript := preload("res://scripts/shark.gd")
const NativeScript := preload("res://scripts/native.gd")
const CampScript := preload("res://scripts/camp.gd")
const HarvestableScript := preload("res://scripts/harvestable.gd")
const AnimalScript := preload("res://scripts/animal.gd")
const HudScript := preload("res://scripts/hud.gd")
const CraftScript := preload("res://scripts/crafting_menu.gd")
const OverlayScript := preload("res://scripts/overlay.gd")
const BuildLibScript := preload("res://scripts/build_lib.gd")
const InventoryUiScript := preload("res://scripts/inventory_ui.gd")
const Mdl := preload("res://scripts/models.gd")

var rng := RandomNumberGenerator.new()
var raft: Node3D            # плота в начале нет; появится позже как отдельная механика
var player: Node3D
var water_mat: ShaderMaterial
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var hud: Node
var overlay: Node
var camps: Array = []
var _warn_timer: float = 6.0

# Большой стартовый остров.
var island_radius: float = 55.0
const GROUND_CELL: float = 2.0
var ground_structures: Dictionary = {}   # "gx,gz,kind" -> Node3D

var _junk_timer: float = 0.0
var _junk_list: Array = []
var _sharks: Array = []
var _raiders: Array = []
var _raid_timer: float = 60.0
var _weather: String = "clear"
var _weather_timer: float = 45.0

func _ready() -> void:
	if GameState.world_seed == 0:
		GameState.world_seed = randi()
	rng.seed = GameState.world_seed
	_build_environment()
	_build_ocean()
	_build_islands()
	_spawn_player()
	_spawn_sharks()
	_build_ui()
	AudioManager.loop_play("waves", "Ambient", -20.0)
	AudioManager.loop_play("wind", "Ambient", -24.0)
	AudioManager.apply_volumes()
	GameState.set_state(GameState.State.PLAYING)
	_update_light()
	_apply_saved_world()
	_give_starting_kit()
	_start_tutorial()

## Стартовый набор новичка: крюк и немного материалов.
func _give_starting_kit() -> void:
	if Inventory.contents().size() > 0:
		return
	Inventory.add("hook", 1)
	Inventory.add("plank", 6)
	Inventory.add("fiber", 4)
	Inventory.add("wood_log", 4)
	Inventory.add("stone", 4)
	Inventory.select(0)
	GameState.show_toast("У вас есть крюк — ловите мусор (ПКМ)")

# ------------------------------------------------------------------
# Мир
# ------------------------------------------------------------------

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	var psm: ProceduralSkyMaterial = sky_mat
	psm.sky_top_color = Color(0.05, 0.07, 0.12)
	psm.sky_horizon_color = Color(0.1, 0.12, 0.16)
	psm.ground_bottom_color = Color(0.02, 0.03, 0.05)
	psm.ground_horizon_color = Color(0.08, 0.1, 0.13)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.2, 0.26)
	env.fog_density = 0.02
	env.fog_sky_affect = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = GameState.brightness
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
	add_child(sun)

func _build_ocean() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	mi.mesh = plane
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	mi.material_override = water_mat
	mi.position.y = 0.0
	add_child(mi)

func _build_islands() -> void:
	# Большой стартовый остров, игрок появляется прямо на нём.
	island_radius = 55.0
	_make_island(Vector3.ZERO, island_radius, Vector3(30, 0, -26))
	# Дальние острова для будущих путешествий.
	var spots := [Vector3(160, 0, 40), Vector3(-180, 0, 130), Vector3(90, 0, -200)]
	for s in spots:
		_make_island(s, rng.randf_range(16.0, 22.0), Vector3.ZERO)

func _make_island(center: Vector3, radius: float, camp_offset: Vector3) -> void:
	var island := Node3D.new()
	island.position = center
	add_child(island)
	# Песчаная основа.
	var base: MeshInstance3D = Mdl.mesh_cyl(radius, 1.6, Color(0.72, 0.66, 0.48), 24)
	base.position.y = 0.2
	island.add_child(base)
	# Зелёная вершина.
	var top: MeshInstance3D = Mdl.mesh_cyl(radius * 0.82, 0.2, Color(0.22, 0.32, 0.16), 24)
	top.position.y = 1.0
	island.add_child(top)
	# Несколько холмов по площади острова (визуальные ориентиры).
	var hills: int = 1 + int(radius / 14.0)
	for i in hills:
		var a: float = TAU * i / float(maxi(hills, 1)) + rng.randf()
		var hr: float = rng.randf_range(radius * 0.25, radius * 0.55)
		var hh: float = rng.randf_range(2.5, 5.0)
		var hill: MeshInstance3D = Mdl.mesh_cone(rng.randf_range(radius * 0.12, radius * 0.22), hh, Color(0.18, 0.3, 0.14), 12)
		hill.position = Vector3(cos(a) * hr, 1.0 + hh * 0.5, sin(a) * hr)
		island.add_child(hill)
	# Коллизия — плоская цилиндрическая площадка (по ней можно строить).
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("ground")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.6
	cs.shape = cyl
	cs.position = Vector3(0, 0.2, 0)
	body.add_child(cs)
	island.add_child(body)
	_populate_island(island, radius)
	_make_nav_region(center, radius - 2.0, 1.1)
	# Лагерь аборигенов в стороне от места старта.
	var camp_pos: Vector3 = center + camp_offset + Vector3(0, 1.1, 0)
	var camp: Node3D = CampScript.new()
	camp.position = camp_pos
	add_child(camp)
	camps.append(camp)
	for i in 3:
		_spawn_native(camp_pos, camp)

func _populate_island(island: Node3D, radius: float) -> void:
	# Чем больше остров, тем больше ресурсов (числа масштабируются по радиусу).
	var count_scale: float = maxf(1.0, radius / 14.0)
	var counts := {"tree": 5, "palm": 4, "rock": 4, "bush": 5, "grass": 6, "ore": 2, "clay": 2}
	for kind in counts:
		var count: int = int(round(float(counts[kind]) * count_scale))
		for i in count:
			var a: float = rng.randf() * TAU
			var r: float = rng.randf_range(2.0, radius * 0.8)
			var pos := Vector3(cos(a) * r, 1.1, sin(a) * r)
			var h: Node3D = HarvestableScript.new()
			h.call("configure", kind, rng)
			h.position = pos
			island.add_child(h)
	# Прибрежный песок по кругу.
	var sand_n: int = int(round(6.0 * count_scale))
	for i in sand_n:
		var a2: float = TAU * i / float(sand_n) + rng.randf() * 0.3
		var s: Node3D = HarvestableScript.new()
		s.call("configure", "sand", rng)
		s.position = Vector3(cos(a2) * (radius * 0.95), 0.9, sin(a2) * (radius * 0.95))
		island.add_child(s)
	# Дикие животные (мясо и шкуры).
	var species_pool: Array[String] = ["Deer", "Stag", "Bull", "Cow", "Fox", "Wolf"]
	var animal_n: int = int(round(float(rng.randi_range(1, 3)) * count_scale))
	for i in animal_n:
		var a3: Node3D = AnimalScript.new()
		a3.call("configure", species_pool[rng.randi() % species_pool.size()], 1.1, radius * 0.7)
		a3.position = Vector3(rng.randf_range(-radius * 0.5, radius * 0.5), 1.1, rng.randf_range(-radius * 0.5, radius * 0.5))
		island.add_child(a3)

func _make_nav_region(center: Vector3, radius: float, y: float) -> void:
	var region := NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.agent_radius = 0.5
	var verts := PackedVector3Array()
	verts.append(Vector3(center.x, y, center.z))
	var n: int = 12
	for i in n:
		var a: float = TAU * i / n
		verts.append(Vector3(center.x + cos(a) * radius, y, center.z + sin(a) * radius))
	nav.vertices = verts
	var poly := PackedInt32Array()
	for i in n:
		poly.append(0)
		poly.append(i + 1)
		poly.append((i + 1) % n + 1)
	nav.add_polygon(poly)
	region.navigation_mesh = nav
	add_child(region)

## Игрок стартует прямо на большом острове (стартового плота больше нет).
func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.position = Vector3(-18, 2.6, 24)
	add_child(player)

func _spawn_sharks() -> void:
	for i in 3:
		var s: Node3D = SharkScript.new()
		var a: float = rng.randf() * TAU
		var r: float = island_radius + 8.0
		s.position = Vector3(cos(a) * r, -0.35, sin(a) * r)
		add_child(s)
		_sharks.append(s)

func _spawn_native(center: Vector3, camp: Node3D, raider: bool = false) -> void:
	var n: Node3D = NativeScript.new()
	n.call("configure", center, camp, raider)
	n.position = center + Vector3(rng.randf_range(-4, 4), 0.1, rng.randf_range(-4, 4))
	add_child(n)
	if raider:
		_raiders.append(n)

func _build_ui() -> void:
	hud = HudScript.new()
	add_child(hud)
	var craft: Node = CraftScript.new()
	add_child(craft)
	var inv_ui: Node = InventoryUiScript.new()
	add_child(inv_ui)
	overlay = OverlayScript.new()
	add_child(overlay)

# ------------------------------------------------------------------
# Кадровые обновления мира
# ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not GameState.simulate:
		return
	_update_light()
	_update_alarm(delta)
	_update_junk(delta)
	_update_weather(delta)
	_update_raids(delta)
	_update_equipment()
	_update_warnings(delta)

func _update_light() -> void:
	var t: float = GameState.time_of_day
	# Положение солнца/луны по времени суток (рассвет 5-7, день 7-18, закат 18-20, ночь 20-5).
	var angle: float = deg_to_rad((t / 24.0) * 360.0 - 90.0)
	sun.rotation_degrees = Vector3(-rad_to_deg(angle), 40.0, 0)
	var day_f: float = clampf(sin((t - 6.0) / 12.0 * PI), 0.0, 1.0)
	var twilight: float = clampf(1.0 - absf(t - 6.5) / 2.0, 0.0, 1.0) + clampf(1.0 - absf(t - 18.5) / 2.0, 0.0, 1.0)
	twilight = clampf(twilight, 0.0, 1.0)
	sun.light_energy = 0.05 + day_f * 1.35
	var night_col := Color(0.45, 0.55, 0.85)
	var day_col := Color(1.0, 0.94, 0.82)
	var tw_col := Color(1.0, 0.55, 0.3)
	sun.light_color = night_col.lerp(day_col, day_f).lerp(tw_col, twilight * 0.7)
	if env != null:
		env.ambient_light_energy = 0.12 + day_f * 0.6
		var rain_f: float = 0.03 if _weather == "storm" else (0.015 if _weather == "rain" else 0.0)
		env.fog_density = 0.012 + (1.0 - day_f) * 0.022 + rain_f
		env.fog_light_color = Color(0.16, 0.2, 0.26).lerp(Color(0.55, 0.62, 0.7), day_f)
		env.adjustment_brightness = GameState.brightness
	if sky_mat != null:
		var n_top := Color(0.015, 0.02, 0.05)
		var n_hor := Color(0.05, 0.06, 0.10)
		var d_top := Color(0.30, 0.48, 0.72)
		var d_hor := Color(0.62, 0.72, 0.82)
		var tw_hor := Color(0.9, 0.45, 0.25)
		sky_mat.sky_top_color = n_top.lerp(d_top, day_f)
		var hor: Color = n_hor.lerp(d_hor, day_f)
		sky_mat.sky_horizon_color = hor.lerp(tw_hor, twilight * 0.8)
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color * 0.45
		sky_mat.ground_bottom_color = Color(0.02, 0.03, 0.05)
	if water_mat != null:
		water_mat.set_shader_parameter("storm", 1.0 if _weather == "storm" else 0.0)

func _update_alarm(delta: float) -> void:
	# Близость к лагерям.
	var prox: float = 0.0
	for c in camps:
		var d: float = player.global_position.distance_to(c.global_position)
		if d < 30.0:
			prox = maxf(prox, 1.0 - d / 30.0)
	GameState.camp_proximity = prox
	var baseline: float = clampf(GameState.raft_footprint * 0.5 + prox * 45.0, 0.0, 100.0)
	if GameState.alarm > baseline:
		GameState.set_alarm(maxf(baseline, GameState.alarm - 0.8 * delta))
	else:
		GameState.set_alarm(minf(baseline, GameState.alarm + 1.5 * delta))

func _update_junk(delta: float) -> void:
	_junk_timer -= delta
	if _junk_timer <= 0.0 and _junk_list.size() < 28:
		_junk_timer = rng.randf_range(1.5, 3.0)
		_spawn_junk()
	# Переработка мусора: ушёл к центру острова или далеко в океан — вернуть в пул.
	for j in _junk_list.duplicate():
		if not is_instance_valid(j):
			_junk_list.erase(j)
			continue
		var d: float = Vector2(j.global_position.x, j.global_position.z).length()
		if d < island_radius - 1.0 or d > island_radius + 55.0:
			j.queue_free()
			_junk_list.erase(j)

## Мусор появляется в океане вокруг острова и дрейфует к берегу.
func _spawn_junk() -> void:
	var kinds := ["plank", "plank", "leaf", "plastic", "plastic", "fish", "barrel", "crate"]
	var kind: String = kinds[rng.randi() % kinds.size()]
	var j: Node3D = JunkScript.new()
	j.call("configure", kind, rng)
	add_child(j)
	var a: float = rng.randf() * TAU
	var r: float = island_radius + rng.randf_range(6.0, 24.0)
	j.global_position = Vector3(cos(a) * r, 0, sin(a) * r)
	var to_shore: Vector3 = -j.global_position
	to_shore.y = 0.0
	j.set("drift", to_shore.normalized() * rng.randf_range(0.4, 0.9) + Vector3(0.1, 0, 0.05))
	_junk_list.append(j)

func _update_weather(delta: float) -> void:
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_weather_timer = rng.randf_range(50.0, 110.0)
		var roll: float = rng.randf()
		var new_weather: String = "clear" if roll < 0.6 else ("rain" if roll < 0.9 else "storm")
		if new_weather != _weather:
			_set_weather(new_weather)

func _set_weather(w: String) -> void:
	_weather = w
	AudioManager.loop_stop("rain")
	if w == "rain":
		AudioManager.loop_play("rain", "Ambient", -18.0)
		GameState.show_toast("Начался дождь")
	elif w == "storm":
		AudioManager.loop_play("rain", "Ambient", -10.0)
		AudioManager.play("thunder", player.global_position, -4.0)
		GameState.show_toast("Шторм! Волны выше")
	else:
		GameState.show_toast("Небо прояснилось")

func _update_raids(delta: float) -> void:
	# Считаем живых рейдеров.
	_raiders = _raiders.filter(func(n): return is_instance_valid(n))
	var night: bool = GameState.time_of_day > 20.0 or GameState.time_of_day < 5.0
	if not night or GameState.alarm < 45.0:
		return
	_raid_timer -= delta
	if _raid_timer <= 0.0 and _raiders.size() < 3:
		_raid_timer = maxf(25.0, 70.0 - GameState.alarm * 0.3)
		var a: float = rng.randf() * TAU
		var spawn: Vector3 = player.global_position + Vector3(cos(a) * 10.0, 0.0, sin(a) * 10.0)
		var boat: Node3D = Mdl.make_boat()
		boat.position = spawn
		add_child(boat)
		_spawn_native(player.global_position, null, true)
		GameState.show_toast("Рейд аборигенов! Обороняйте лагерь")

func _update_equipment() -> void:
	GameState.armor = 0.25 if Inventory.has("wood_armor") else (0.1 if Inventory.has("shield") else 0.0)

## Предупреждения состояния (жажда/голод/акула рядом).
func _update_warnings(delta: float) -> void:
	_warn_timer -= delta
	if _warn_timer > 0.0:
		return
	_warn_timer = 14.0
	if GameState.thirst < 20.0:
		GameState.show_warn("Вы хотите пить")
	elif GameState.hunger < 20.0:
		GameState.show_warn("Вы голодны")
	else:
		for s in _sharks:
			if is_instance_valid(s) and s.global_position.distance_to(player.global_position) < 9.0:
				GameState.show_warn("Приближается акула")
				break

# ------------------------------------------------------------------
# Стройка / якорь
# ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if GameState.state != GameState.State.PLAYING or GameState.ui_open:
		return
	if event.is_action_pressed("anchor"):
		if raft != null:
			raft.call("toggle_anchor")
		else:
			GameState.show_toast("Якорь нужен только на плоту")
	elif event.is_action_pressed("pause"):
		overlay.call("toggle_pause")

## Ставит постройку на землю острова или на плот (если он есть).
func try_place_build(p: Node3D) -> void:
	var id: String = Inventory.selected_id()
	var item: Dictionary = Recipes.get_item(id)
	var build: String = String(item.get("build", ""))
	if build == "":
		GameState.show_toast("Возьмите в руку то, что строите")
		return
	if not Inventory.has(id, 1):
		return
	var cam: Camera3D = p.get("camera")
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	var from: Vector3 = cam.global_position
	var to: Vector3 = from - cam.global_transform.basis.z * 8.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.has("collider"):
		GameState.show_toast("Слишком далеко — подойдите ближе")
		return
	var col: Object = hit["collider"]
	if col.is_in_group("raft") and raft != null:
		raft.call("try_place_build", p)
		return
	if col.is_in_group("ground"):
		if build == "foundation":
			GameState.show_toast("На земле фундамент не нужен")
			return
		var pt: Vector3 = hit["position"]
		var cell := Vector2i(roundi(pt.x / GROUND_CELL), roundi(pt.z / GROUND_CELL))
		var key: String = "%d,%d,%s" % [cell.x, cell.y, build]
		if ground_structures.has(key):
			return
		if not Inventory.remove(id, 1):
			return
		var pos := Vector3(cell.x * GROUND_CELL, pt.y, cell.y * GROUND_CELL)
		ground_structures[key] = BuildLibScript.spawn_structure(self, pos, build)
		GameState.stats["built"] = int(GameState.stats.get("built", 0)) + 1
		AudioManager.play("craft", pos, -8.0)
		GameState.show_toast("Построено: " + Recipes.item_name(id))
		return
	GameState.show_toast("Ставьте на землю или плот")

# ------------------------------------------------------------------
# Туториал
# ------------------------------------------------------------------

func _start_tutorial() -> void:
	GameState.show_toast("Вы на острове. Разбейте дерево и камень (ЛКМ)")
	await get_tree().create_timer(6.0).timeout
	GameState.show_toast("Tab — крафт. Возьмите постройку в руку и поставьте: B, затем ЛКМ")
	await get_tree().create_timer(7.0).timeout
	GameState.show_toast("Соберите мусор у берега крюком (ПКМ). Осторожно: акулы и аборигены")

# ------------------------------------------------------------------
# Сохранение мира
# ------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var d: Dictionary = {
		"player": [player.global_position.x, player.global_position.y, player.global_position.z],
		"weather": _weather,
	}
	if raft != null:
		d["raft"] = raft.call("get_save_data")
	return d

func _apply_saved_world() -> void:
	var data: Dictionary = SaveManager.take_world_data()
	if data.is_empty():
		return
	if data.has("raft") and raft != null:
		raft.call("load_save_data", data["raft"])
	if data.has("player"):
		var p: Array = data["player"]
		player.global_position = Vector3(p[0], p[1], p[2])
	if data.has("weather"):
		_set_weather(String(data["weather"]))