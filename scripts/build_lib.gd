class_name BuildLib
extends RefCounted
## Общая фабрика построек: используется и плотом, и землёй острова.
## Возвращает готовые узлы (станции или простые постройки) с коллизией.

const Mdl := preload("res://scripts/models.gd")
const StationScript := preload("res://scripts/station.gd")

const STATIONS: Array[String] = ["workbench", "cooker", "purifier", "research_table", "chest", "bed", "lamp", "water_barrel", "garden_plot", "table", "shelf"]

## Создаёт узел постройки и ставит его в parent на заданную локальную позицию.
static func spawn_structure(parent: Node3D, local_pos: Vector3, kind: String) -> Node3D:
	var node: Node3D
	if kind in STATIONS:
		var st: Node = StationScript.new()
		st.call("configure", kind)
		node = st
	else:
		node = make_plain(kind)
	node.position = local_pos
	parent.add_child(node)
	return node

## Простые постройки без логики (стены, крыша, парус, ловушки...).
static func make_plain(kind: String) -> Node3D:
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		"wall":
			box.size = Vector3(2.0, 2.2, 0.2)
			root.add_child(_mi(Vector3(2.0, 2.2, 0.2), Color(0.4, 0.3, 0.18), Vector3(0, 1.1, 0)))
			col.position = Vector3(0, 1.1, 0)
		"fence":
			box.size = Vector3(2.0, 1.0, 0.15)
			root.add_child(_mi(Vector3(2.0, 1.0, 0.15), Color(0.42, 0.32, 0.2), Vector3(0, 0.5, 0)))
			col.position = Vector3(0, 0.5, 0)
		"door":
			box.size = Vector3(1.9, 2.1, 0.12)
			root.add_child(_mi(Vector3(1.9, 2.1, 0.12), Color(0.4, 0.28, 0.16), Vector3(0, 1.05, 0)))
			col.position = Vector3(0, 1.05, 0)
		"window":
			box.size = Vector3(2.0, 2.0, 0.12)
			root.add_child(_mi(Vector3(2.0, 0.5, 0.12), Color(0.4, 0.3, 0.18), Vector3(0, 0.25, 0)))
			root.add_child(_mi(Vector3(2.0, 0.5, 0.12), Color(0.4, 0.3, 0.18), Vector3(0, 1.75, 0)))
			root.add_child(_mi(Vector3(0.4, 1.0, 0.12), Color(0.6, 0.7, 0.75), Vector3(0, 1.0, 0)))
			col.position = Vector3(0, 1.1, 0)
		"floor2":
			box.size = Vector3(2.0, 0.2, 2.0)
			root.add_child(_mi(Vector3(2.0, 0.2, 2.0), Color(0.42, 0.32, 0.2), Vector3(0, 2.4, 0)))
			col.position = Vector3(0, 2.4, 0)
		"roof":
			box.size = Vector3(2.0, 0.2, 2.0)
			root.add_child(_mi(Vector3(2.0, 0.2, 2.0), Color(0.3, 0.28, 0.18), Vector3(0, 4.9, 0)))
			col.position = Vector3(0, 4.9, 0)
		"ladder":
			box.size = Vector3(0.7, 2.5, 0.2)
			root.add_child(_mi(Vector3(0.6, 2.5, 0.15), Color(0.45, 0.35, 0.22), Vector3(0, 1.25, 0)))
			col.position = Vector3(0, 1.25, 0)
		"sail":
			box.size = Vector3(0.2, 3.0, 0.2)
			root.add_child(_mi(Vector3(0.2, 3.0, 0.2), Color(0.4, 0.3, 0.2), Vector3(0, 1.5, 0)))
			root.add_child(_mi(Vector3(0.1, 2.0, 1.6), Color(0.72, 0.7, 0.62), Vector3(0, 1.8, 0)))
			col.position = Vector3(0, 1.5, 0)
		"rudder":
			box.size = Vector3(1.0, 0.3, 0.3)
			root.add_child(_mi(Vector3(0.3, 1.2, 0.3), Color(0.4, 0.3, 0.2), Vector3(0, 0.6, 0)))
			col.position = Vector3(0, 0.6, 0)
		"oar":
			box.size = Vector3(0.2, 0.2, 2.4)
			root.add_child(_mi(Vector3(0.15, 0.15, 2.4), Color(0.5, 0.4, 0.25), Vector3(0, 0.4, 0)))
			col.position = Vector3(0, 0.4, 0)
		"anchor":
			box.size = Vector3(0.4, 0.6, 0.4)
			root.add_child(_mi(Vector3(0.4, 0.6, 0.4), Color(0.4, 0.4, 0.45), Vector3(0, 0.3, 0)))
			col.position = Vector3(0, 0.3, 0)
		"trap":
			box.size = Vector3(1.8, 0.2, 1.8)
			root.add_child(_mi(Vector3(1.8, 0.15, 1.8), Color(0.35, 0.28, 0.18), Vector3(0, 0.08, 0)))
			col.position = Vector3(0, 0.08, 0)
		"spike_wall":
			box.size = Vector3(2.0, 1.2, 0.4)
			root.add_child(_mi(Vector3(2.0, 0.6, 0.4), Color(0.38, 0.3, 0.2), Vector3(0, 0.3, 0)))
			for i in 5:
				root.add_child(_mi(Vector3(0.1, 0.6, 0.1), Color(0.5, 0.5, 0.52), Vector3(-0.8 + i * 0.4, 0.9, 0)))
			col.position = Vector3(0, 0.3, 0)
		"watchtower":
			box.size = Vector3(1.4, 3.0, 1.4)
			root.add_child(_mi(Vector3(1.2, 3.0, 1.2), Color(0.4, 0.32, 0.2), Vector3(0, 1.5, 0)))
			root.add_child(_mi(Vector3(1.8, 0.2, 1.8), Color(0.35, 0.28, 0.18), Vector3(0, 3.05, 0)))
			col.position = Vector3(0, 1.5, 0)
		_:
			box.size = Vector3(1.0, 1.0, 1.0)
			root.add_child(_mi(Vector3(1.0, 1.0, 1.0), Color(0.4, 0.32, 0.2), Vector3(0, 0.5, 0)))
			col.position = Vector3(0, 0.5, 0)
	col.shape = box
	root.add_child(col)
	return root

static func _mi(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var m: MeshInstance3D = Mdl.mesh_box(size, color)
	m.position = pos
	return m

## Части плота, влияющие на его поведение (парус/руль/весло/якорь).
static func is_raft_part(kind: String) -> bool:
	return kind in ["sail", "rudder", "oar", "anchor"]