class_name SafeFile
extends RefCounted
## Replaces files with a recoverable backup; Godot's Windows rename removes its target first.

const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"


## Recovers a crash between backup and final rename before creating defaults.
static func recover(path: String) -> Dictionary:
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory != null and directory.is_link(path.get_file() + BACKUP_SUFFIX):
		return failure(path, ERR_INVALID_PARAMETER)
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + BACKUP_SUFFIX):
		var error: Error = DirAccess.rename_absolute(path + BACKUP_SUFFIX, path)
		if error != OK:
			return failure(path, error)
	return {"ok": true}


## Keeps the previous data available if writing or either rename fails.
static func write_text(path: String, content: String) -> Dictionary:
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return failure(path, error)
	var recovery: Dictionary = recover(path)
	if not recovery.ok:
		return recovery
	var directory: DirAccess = DirAccess.open(path.get_base_dir())
	if directory.is_link(path.get_file() + TEMP_SUFFIX) or directory.is_link(path.get_file() + BACKUP_SUFFIX):
		return failure(path, ERR_INVALID_PARAMETER)
	var temporary: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failure(path, FileAccess.get_open_error())
	file.store_string(content)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return failure(path, error)
	return _replace(temporary, path)


## Returns a translated-error key with native filesystem diagnostics.
static func failure(path: String, error: Error) -> Dictionary:
	return {"ok": false, "error": "DATA_FILE_ERROR", "detail": "%s (%s)" % [path, error_string(error)]}


static func _replace(temporary: String, path: String) -> Dictionary:
	var had_original: bool = FileAccess.file_exists(path)
	var error: Error = OK
	if had_original:
		error = DirAccess.rename_absolute(path, path + BACKUP_SUFFIX)
		if error != OK:
			return failure(path, error)
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		if had_original:
			DirAccess.rename_absolute(path + BACKUP_SUFFIX, path)
		return failure(path, error)
	return {"ok": true}
