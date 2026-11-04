class_name Models
extends RefCounted
## Фабрика моделей: сначала пробует скачанные CC0-ассеты (AssetLibrary),
## иначе строит низкополигональную заготовку из примитивов.
## Все процедурные материалы кэшируются по цвету — единая мрачная палитра.

const Assets := preload("res://scripts/asset_library.gd")

static var _mats: Dictionary = {}

## Общий материал по цвету (кэш). emissive — для огня/ламп.
static func mat(color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	var key: String = str(color) + "_" + str(emissive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m

static func mesh_box(size: Vector3, color: Color, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, emissive)
	return mi

static func mesh_cyl(r: float, h: float, color: Color, seg: int = 6, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat(color, emissive)
	return mi

static func mesh_cone(r: float, h: float, color: Color, seg: int = 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 0
	mi.mesh = cm
	mi.material_override = mat(color)
	return mi

static func mesh_sphere(r: float, color: Color, seg: int = 6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = int(float(seg) / 2.0)
	mi.mesh = sm
	mi.material_override = mat(color)
	return mi

## Добавляет дочерний узел с локальной позицией.
static func at(node: Node3D, parent: Node3D, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> Node3D:
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node

# ------------------------------------------------------------------
# Готовые модели
# ------------------------------------------------------------------

static func make_tree(rng: RandomNumberGenerator) -> Node3D:
	var asset: Node3D = Assets.tree(rng)
	if asset != null:
		asset.name = "Tree"
		return asset
	var root := Node3D.new()
	root.name = "Tree"
	var h: float = rng.randf_range(3.5, 6.0)
	at(mesh_cyl(0.16, h, Color(0.24, 0.17, 0.1)), root, Vector3(0, h * 0.5, 0))
	var cols: Array[Color] = [Color(0.13, 0.24, 0.13), Color(0.16, 0.27, 0.15), Color(0.11, 0.2, 0.12)]
	for i in 3:
		var c := mesh_cone(rng.randf_range(1.3, 1.8), rng.randf_range(1.4, 2.0), cols[i % cols.size()])
		at(c, root, Vector3(0, h * 0.55 + i * 0.9, 0))
	return root

static func make_palm(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.name = "Palm"
	var h: float = rng.randf_range(4.0, 6.0)
	# Слегка изогнутый ствол из трёх сегментов.
	var x: float = 0.0
	for i in 3:
		var seg: MeshInstance3D = mesh_cyl(0.18 - i * 0.03, h / 3.0, Color(0.32, 0.26, 0.16), 5)
		at(seg, root, Vector3(x, h / 6.0 + i * h / 3.0, 0), Vector3(0, 0, deg_to_rad(-6.0 * (i + 1))))
		x += 0.22
	for i in 6:
		var frond := mesh_box(Vector3(0.18, 0.05, 1.8), Color(0.18, 0.34, 0.16))
		var a: float = TAU * i / 6.0
		at(frond, root, Vector3(x, h, 0) + Vector3(cos(a), 0.1, sin(a)) * 0.6, Vector3(deg_to_rad(20.0), -a, 0))
	# Кокосы.
	for i in 3:
		var a: float = TAU * i / 3.0
		at(mesh_sphere(0.16, Color(0.34, 0.24, 0.14), 5), root, Vector3(x + cos(a) * 0.25, h - 0.25, sin(a) * 0.25))
	return root

static func make_rock(rng: RandomNumberGenerator) -> Node3D:
	var asset: Node3D = Assets.rock(rng)
	if asset != null:
		asset.name = "Rock"
		asset.scale *= rng.randf_range(0.7, 1.1)
		return asset
	var root := Node3D.new()
	root.name = "Rock"
	var s: float = rng.randf_range(0.5, 1.2)
	var r := mesh_sphere(0.6, Color(0.36, 0.36, 0.38), 5)
	r.scale = Vector3(s, s * rng.randf_range(0.6, 0.9), s)
	at(r, root, Vector3(0, s * 0.3, 0), Vector3(rng.randf(), rng.randf(), rng.randf()))
	return root

static func make_ore(rng: RandomNumberGenerator) -> Node3D:
	var root: Node3D = make_rock(rng)
	var spec: MeshInstance3D = mesh_sphere(0.28, Color(0.5, 0.42, 0.28), 4)
	at(spec, root, Vector3(0.2, 0.5, 0.1))
	return root

static func make_bush(rng: RandomNumberGenerator) -> Node3D:
	var asset: Node3D = Assets.bush(rng)
	if asset != null:
		asset.name = "Bush"
		return asset
	var root := Node3D.new()
	root.name = "Bush"
	at(mesh_sphere(0.5, Color(0.16, 0.28, 0.14), 5), root, Vector3(0, 0.4, 0))
	for i in 3:
		var a: float = TAU * i / 3.0 + rng.randf()
		at(mesh_sphere(0.12, Color(0.5, 0.1, 0.16), 5), root, Vector3(cos(a) * 0.4, 0.55, sin(a) * 0.4))
	return root

static func make_grass(rng: RandomNumberGenerator) -> Node3D:
	var asset: Node3D = Assets.grass(rng)
	if asset != null:
		asset.name = "Grass"
		return asset
	var root := Node3D.new()
	root.name = "Grass"
	at(mesh_box(Vector3(0.5, 0.6, 0.5), Color(0.25, 0.4, 0.2)), root, Vector3(0, 0.3, 0))
	return root

## Животное из CC0-пака (с анимациями Idle/Walk/Gallop/Death).
static func make_animal(species: String, rng: RandomNumberGenerator) -> Node3D:
	var n: Node3D = Assets.animal(species, rng)
	if n != null:
		n.name = "Animal"
	return n

static func make_barrel() -> Node3D:
	var root := Node3D.new()
	root.name = "Barrel"
	at(mesh_cyl(0.32, 0.85, Color(0.35, 0.24, 0.13), 8), root, Vector3.ZERO)
	at(mesh_cyl(0.35, 0.08, Color(0.4, 0.4, 0.45), 8), root, Vector3(0, 0.3, 0))
	at(mesh_cyl(0.35, 0.08, Color(0.4, 0.4, 0.45), 8), root, Vector3(0, -0.3, 0))
	return root

static func make_crate() -> Node3D:
	var root := Node3D.new()
	root.name = "Crate"
	at(mesh_box(Vector3(0.75, 0.75, 0.75), Color(0.45, 0.32, 0.18)), root)
	for s in [-1.0, 1.0]:
		at(mesh_box(Vector3(0.8, 0.1, 0.8), Color(0.3, 0.2, 0.1)), root, Vector3(0, s * 0.34, 0))
	return root

static func make_plank_debris() -> Node3D:
	var root := Node3D.new()
	root.name = "PlankDebris"
	at(mesh_box(Vector3(1.6, 0.12, 0.4), Color(0.5, 0.38, 0.22)), root)
	return root

static func make_leaf() -> Node3D:
	var root := Node3D.new()
	root.name = "Leaf"
	at(mesh_box(Vector3(1.0, 0.06, 0.7), Color(0.2, 0.35, 0.16)), root)
	return root

static func make_plastic() -> Node3D:
	var root := Node3D.new()
	root.name = "Plastic"
	at(mesh_cyl(0.18, 0.5, Color(0.65, 0.72, 0.75), 6), root, Vector3(0, 0.2, 0))
	at(mesh_cyl(0.1, 0.15, Color(0.55, 0.62, 0.65), 6), root, Vector3(0, 0.52, 0))
	return root

static func make_fish(color: Color = Color(0.42, 0.5, 0.55)) -> Node3D:
	var root := Node3D.new()
	root.name = "Fish"
	var body := mesh_sphere(0.28, color, 5)
	body.scale = Vector3(1.8, 1.0, 0.7)
	at(body, root)
	at(mesh_cone(0.2, 0.35, color), root, Vector3(-0.55, 0, 0), Vector3(0, 0, deg_to_rad(90.0)))
	return root

static func make_shark() -> Node3D:
	var root := Node3D.new()
	root.name = "Shark"
	var body := mesh_sphere(0.6, Color(0.25, 0.28, 0.31), 6)
	body.scale = Vector3(3.2, 1.0, 0.9)
	at(body, root)
	at(mesh_cone(0.35, 0.9, Color(0.23, 0.26, 0.29)), root, Vector3(-1.9, 0, 0), Vector3(0, 0, deg_to_rad(90.0)))
	# Плавник.
	at(mesh_box(Vector3(0.5, 0.9, 0.1), Color(0.22, 0.25, 0.28)), root, Vector3(0, 0.6, 0), Vector3(deg_to_rad(-15.0), 0, 0))
	# Хвост.
	at(mesh_box(Vector3(0.9, 0.9, 0.1), Color(0.22, 0.25, 0.28)), root, Vector3(1.7, 0.3, 0), Vector3(0, 0, deg_to_rad(30.0)))
	return root

static func make_native() -> Node3D:
	var root := Node3D.new()
	root.name = "Native"
	var skin := Color(0.42, 0.3, 0.22)
	var cloth := Color(0.3, 0.24, 0.16)
	var torso := mesh_box(Vector3(0.5, 0.7, 0.3), skin)
	at(torso, root, Vector3(0, 1.05, 0))
	at(mesh_sphere(0.22, skin, 5), root, Vector3(0, 1.55, 0))
	# Руки и ноги.
	for sx in [-1.0, 1.0]:
		at(mesh_box(Vector3(0.16, 0.6, 0.16), skin), root, Vector3(sx * 0.36, 1.05, 0))
		at(mesh_box(Vector3(0.18, 0.7, 0.18), cloth), root, Vector3(sx * 0.16, 0.4, 0))
	# Маска/украшение.
	at(mesh_box(Vector3(0.3, 0.18, 0.05), Color(0.6, 0.5, 0.2)), root, Vector3(0, 1.6, 0.2))
	return root

static func make_boat() -> Node3D:
	var root := Node3D.new()
	root.name = "Boat"
	at(mesh_box(Vector3(1.2, 0.4, 3.0), Color(0.35, 0.25, 0.15)), root)
	at(mesh_box(Vector3(0.3, 0.6, 1.4), Color(0.7, 0.68, 0.6)), root, Vector3(0, 0.6, 0))
	return root

static func make_hut() -> Node3D:
	var root := Node3D.new()
	root.name = "Hut"
	at(mesh_cyl(1.6, 2.2, Color(0.4, 0.32, 0.2), 6), root, Vector3(0, 1.1, 0))
	at(mesh_cone(2.1, 1.6, Color(0.28, 0.34, 0.16), 6), root, Vector3(0, 2.9, 0))
	return root

static func make_campfire() -> Node3D:
	var root := Node3D.new()
	root.name = "Campfire"
	for i in 5:
		var a: float = TAU * i / 5.0
		at(mesh_box(Vector3(0.12, 0.5, 0.12), Color(0.3, 0.2, 0.12)), root, Vector3(cos(a) * 0.35, 0.25, sin(a) * 0.35), Vector3(deg_to_rad(12.0), -a, 0))
	at(mesh_cone(0.3, 0.7, Color(0.9, 0.45, 0.1)), root, Vector3(0, 0.6, 0))
	return root

static func make_torch_held() -> Node3D:
	var root := Node3D.new()
	at(mesh_cyl(0.03, 0.5, Color(0.3, 0.2, 0.12), 5), root)
	at(mesh_sphere(0.09, Color(0.95, 0.5, 0.12)), root, Vector3(0, 0.3, 0))
	return root

static func make_axe_held() -> Node3D:
	var root := Node3D.new()
	at(mesh_cyl(0.03, 0.7, Color(0.4, 0.28, 0.16), 5), root)
	at(mesh_box(Vector3(0.18, 0.22, 0.05), Color(0.5, 0.5, 0.55)), root, Vector3(0.08, 0.32, 0))
	return root