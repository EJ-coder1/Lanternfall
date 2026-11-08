extends Node
## JSON save/load with atomic writes. Autoload: SaveSystem.

const DEFAULT_PATH := "user://lanternfall_save.json"

var path: String = DEFAULT_PATH


func has_save() -> bool:
	return FileAccess.file_exists(path)


func save_game() -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	f.close()
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Save rename failed: %s" % error_string(err))
		return false
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt; ignoring it.")
		return false
	return GameState.from_dict(json.data)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
