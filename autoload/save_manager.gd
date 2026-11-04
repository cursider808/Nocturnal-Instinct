extends Node
## Автозагрузка SaveManager: сохранение и загрузка прогресса в JSON (user://).

const SAVE_PATH: String = "user://savegame.json"

signal saved
signal loaded

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

## Собирает данные из GameState, Inventory и активного мира (если он есть).
func save_game() -> void:
	var world: Node = get_tree().current_scene
	var data: Dictionary = {
		"version": 1,
		"game": GameState.to_dict(),
		"inventory": Inventory.to_dict(),
		"world": {},
	}
	if world != null and world.has_method("get_save_data"):
		data["world"] = world.call("get_save_data")
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		saved.emit()
		GameState.show_toast("Игра сохранена")

## Загружает данные и передаёт их в мир.
func load_game() -> bool:
	if not has_save():
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed
	GameState.from_dict(data.get("game", {}))
	Inventory.from_dict(data.get("inventory", {}))
	_pending_world_data = data.get("world", {})
	loaded.emit()
	return true

var _pending_world_data: Dictionary = {}

## Мир вызывает это после генерации, чтобы применить сохранённое состояние.
func take_world_data() -> Dictionary:
	var d: Dictionary = _pending_world_data
	_pending_world_data = {}
	return d