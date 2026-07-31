extends Node

const SAVE_PATH := "user://bonsai_save.json"
const SAVE_VERSION := 3

signal save_completed
signal load_completed


func save_game(state: Dictionary) -> void:
	state["version"] = SAVE_VERSION
	state["timestamp"] = int(Time.get_unix_time_from_system())
	var json := JSON.stringify(state, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	save_completed.emit()


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	load_completed.emit()
	return parsed


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
