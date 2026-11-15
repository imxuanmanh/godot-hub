class_name EditorCatalog
extends RefCounted
## Stores the external script editors installed on this machine (name, executable, flags).

const PATH: String = "user://editors.json"
const SCHEMA: int = 1

var read_only: bool = false
var _path: String
var _editors: Array[Dictionary] = []


func _init(path: String = PATH) -> void:
	_path = path


## Missing file means an empty catalog; a corrupt one stays untouched and read-only.
func load_catalog() -> Dictionary:
	read_only = true
	_editors.clear()
	var recovery: Dictionary = SafeFile.recover(_path)
	if not recovery.ok:
		return recovery
	if not FileAccess.file_exists(_path):
		read_only = false
		return {"ok": true}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(_path)) != OK or not json.data is Dictionary:
		return SafeFile.failure(_path, ERR_PARSE_ERROR)
	var data: Dictionary = json.data
	if data.get("schema_version", 0) != SCHEMA or not data.get("editors") is Array:
		return {"ok": false, "error": "DATA_SCHEMA_ERROR", "detail": _path}
	for raw: Variant in data.editors:
		var entry: Dictionary = _normalize(raw)
		if entry.is_empty():
			return SafeFile.failure(_path, ERR_INVALID_DATA)
		_editors.append(entry)
	read_only = false
	return {"ok": true}


func list() -> Array[Dictionary]:
	return _editors.duplicate(true)


## index < 0 appends; otherwise replaces that entry.
func upsert(index: int, editor_name: String, path: String, flags: String) -> Dictionary:
	var entry: Dictionary = {"name": editor_name.strip_edges(), "path": path.strip_edges(), "flags": flags.strip_edges()}
	if entry.name.is_empty() or entry.path.is_empty():
		return {"ok": false, "error": "EDITOR_INVALID", "detail": str(entry.name)}
	var next: Array[Dictionary] = list()
	if index < 0:
		next.append(entry)
	elif index < next.size():
		next[index] = entry
	else:
		return {"ok": false, "error": "EDITOR_INVALID", "detail": str(index)}
	return _commit(next)


func remove(index: int) -> Dictionary:
	if index < 0 or index >= _editors.size():
		return {"ok": false, "error": "EDITOR_INVALID", "detail": str(index)}
	var next: Array[Dictionary] = list()
	next.remove_at(index)
	return _commit(next)


func _commit(next: Array[Dictionary]) -> Dictionary:
	if read_only:
		return SafeFile.failure(_path, ERR_FILE_CANT_WRITE)
	var result: Dictionary = SafeFile.write_text(_path, JSON.stringify({"schema_version": SCHEMA, "editors": next}, "\t"))
	if result.ok:
		_editors = next
	return result


static func _normalize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("name") is String or not raw.get("path") is String:
		return {}
	return {"name": raw.name, "path": raw.path, "flags": str(raw.get("flags", ""))}
