class_name CampaignSave
extends RefCounted

const VERSION := 4
const SLOT_COUNT := 3


static func read(directory: String, slot: int) -> Dictionary:
	var file := FileAccess.open(_path(directory, slot), FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var(false)
	if payload is Dictionary and payload.get("version") == VERSION and payload.get("run") is Dictionary:
		return payload.run
	return {}


static func write(directory: String, slot: int, snapshot: Dictionary) -> Error:
	var path: String = _path(directory, slot)
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({"version": VERSION, "run": snapshot}, false)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, path)


static func exists(directory: String, slot: int) -> bool:
	return FileAccess.file_exists(_path(directory, slot))


static func _path(directory: String, slot: int) -> String:
	return directory.path_join("floor-one-%d.save" % slot)
