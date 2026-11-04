class_name Station
extends StaticBody3D
## Интерактивная станция или предмет мебели на плоту.
## Верстак/плита/очиститель/стол исследователя, сундук, кровать, лампа, грядка.

const Mdl := preload("res://scripts/models.gd")
const ItemContainerScript := preload("res://scripts/item_container.gd")

var station_id: String = "workbench"
var chest: ItemContainerScript
var light: OmniLight3D
var lit: bool = true
var garden_timer: float = 20.0

func configure(id: String) -> void:
	station_id = id
	collision_layer = 1     # world — игрок и враги упираются
	collision_mask = 0
	add_to_group("station")
	_build_mesh()
	_build_collision()
	if station_id == "chest":
		chest = ItemContainerScript.new(12)

func _build_mesh() -> void:
	match station_id:
		"workbench":
			_add(Mdl.mesh_box(Vector3(1.8, 0.2, 0.9), Color(0.5, 0.38, 0.22)), Vector3(0, 0.9, 0))
			_add(Mdl.mesh_box(Vector3(1.7, 0.8, 0.8), Color(0.4, 0.3, 0.18)), Vector3(0, 0.4, 0))
		"cooker":
			_add(Mdl.mesh_box(Vector3(1.1, 0.7, 1.1), Color(0.32, 0.3, 0.28)), Vector3(0, 0.35, 0))
			_add(Mdl.mesh_box(Vector3(1.0, 0.06, 1.0), Color(0.9, 0.4, 0.1), 2.0), Vector3(0, 0.72, 0))
		"purifier":
			_add(Mdl.mesh_box(Vector3(0.9, 1.1, 0.9), Color(0.4, 0.5, 0.55)), Vector3(0, 0.55, 0))
			_add(Mdl.mesh_cyl(0.12, 0.7, Color(0.5, 0.55, 0.6), 6), Vector3(0.3, 1.3, 0))
		"research_table":
			_add(Mdl.mesh_box(Vector3(1.6, 0.2, 0.9), Color(0.45, 0.42, 0.3)), Vector3(0, 0.9, 0))
			_add(Mdl.mesh_box(Vector3(1.5, 0.8, 0.8), Color(0.35, 0.32, 0.22)), Vector3(0, 0.4, 0))
			_add(Mdl.mesh_box(Vector3(0.4, 0.3, 0.1), Color(0.6, 0.7, 0.75), 0.5), Vector3(0.3, 1.15, 0))
		"chest":
			_add(Mdl.mesh_box(Vector3(1.0, 0.55, 0.7), Color(0.45, 0.32, 0.18)), Vector3(0, 0.28, 0))
			_add(Mdl.mesh_box(Vector3(1.02, 0.12, 0.72), Color(0.3, 0.2, 0.1)), Vector3(0, 0.58, 0))
		"bed":
			_add(Mdl.mesh_box(Vector3(0.9, 0.35, 2.0), Color(0.5, 0.4, 0.35)), Vector3(0, 0.25, 0))
			_add(Mdl.mesh_box(Vector3(0.7, 0.15, 0.5), Color(0.8, 0.78, 0.7)), Vector3(0, 0.5, -0.7))
		"lamp":
			_add(Mdl.mesh_cyl(0.08, 1.6, Color(0.35, 0.3, 0.2), 6), Vector3(0, 0.8, 0))
			_add(Mdl.mesh_sphere(0.22, Color(0.95, 0.85, 0.5), 6), Vector3(0, 1.7, 0), 0.0, true)
		"water_barrel":
			_add(Mdl.mesh_cyl(0.45, 1.0, Color(0.34, 0.28, 0.2), 8), Vector3(0, 0.5, 0))
		"garden_plot":
			_add(Mdl.mesh_box(Vector3(1.8, 0.3, 1.8), Color(0.3, 0.22, 0.14)), Vector3(0, 0.15, 0))
			for i in 4:
				_add(Mdl.mesh_sphere(0.15, Color(0.2, 0.4, 0.16), 5), Vector3(-0.5 + (i % 2), 0.35, -0.5 + int(float(i) / 2.0)), 0.0, false)
		"table":
			_add(Mdl.mesh_box(Vector3(1.4, 0.15, 1.4), Color(0.45, 0.35, 0.22)), Vector3(0, 0.8, 0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					_add(Mdl.mesh_box(Vector3(0.12, 0.75, 0.12), Color(0.35, 0.26, 0.16)), Vector3(sx * 0.6, 0.38, sz * 0.6))
		"shelf":
			_add(Mdl.mesh_box(Vector3(1.4, 1.4, 0.3), Color(0.45, 0.35, 0.22)), Vector3(0, 0.7, 0))
		_:
			_add(Mdl.mesh_box(Vector3(1.0, 1.0, 1.0), Color(0.4, 0.32, 0.2)), Vector3(0, 0.5, 0))

func _add(mesh: MeshInstance3D, pos: Vector3, _spin: float = 0.0, add_light: bool = false) -> void:
	mesh.position = pos
	add_child(mesh)
	if add_light:
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.6)
		light.light_energy = 1.4
		light.omni_range = 8.0
		light.shadow_enabled = false
		light.position = pos
		add_child(light)

func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = box
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)

func interact(_player: Node) -> void:
	match station_id:
		"workbench", "cooker", "purifier":
			GameState.show_toast("Откройте крафт — клавиша Tab")
		"research_table":
			_research()
		"chest":
			var ui: Node = get_tree().get_first_node_in_group("inventory_ui")
			if ui != null:
				ui.call("open_container", chest)
		"bed":
			_sleep()
		"lamp":
			lit = not lit
			if light != null:
				light.visible = lit
			AudioManager.play("craft", global_position, -12.0)
		"garden_plot":
			if garden_timer <= 0.0:
				Inventory.add("berry", 2)
				garden_timer = 25.0
				GameState.show_toast("Собрано с грядки")
			else:
				GameState.show_toast("Грядка ещё растёт")
		_:
			pass

## Открывает один закрытый рецепт.
func _research() -> void:
	var locked: Array = []
	for r in Recipes.recipes:
		if bool(r.get("research", false)) and not Recipes.is_unlocked(r):
			locked.append(r)
	if locked.is_empty():
		GameState.show_toast("Все рецепты открыты")
		return
	var pick: Dictionary = locked[randi() % locked.size()]
	GameState.unlocked_recipes[String(pick.get("id"))] = true
	Recipes.recipes_changed.emit()
	AudioManager.play("craft", global_position, -8.0)
	GameState.show_toast("Открыт рецепт: " + Recipes.item_name(String(pick.get("out"))))

## Сон до утра следующего дня.
func _sleep() -> void:
	if GameState.time_of_day > 6.0 and GameState.time_of_day < 20.0:
		GameState.show_toast("Спать можно только ночью")
		return
	GameState.time_of_day = 7.0
	GameState.day += 1
	GameState.heal(25.0)
	GameState.show_toast("Вы выспались. День %d" % GameState.day)
	AudioManager.play("craft", global_position, -10.0)

func _process(delta: float) -> void:
	if station_id == "garden_plot" and garden_timer > 0.0:
		garden_timer -= delta