class_name HubDataRepository
extends RefCounted
## Owns the legacy JSON format, migration and recoverable writes.

const PATH: String = "user://godot_hub_data.json"
const SCHEMA: int = 1

var read_only: bool = false
var _path: String
var _data: Dictionary = {"schema_version": SCHEMA, "versions": [], "projects": [], "language": AppLanguages.DEFAULT, "close_on_launch": false}


func _init(path: String = PATH) -> void:
	_path = path


## Corrupt or future data remains read-only and is never replaced with defaults.
func load_data() -> Dictionary:
	read_only = true
	var recovery: Dictionary = SafeFile.recover(_path)
	if not recovery.ok:
		return recovery
	if not FileAccess.file_exists(_path):
		read_only = false
		return {"ok": true, "value": snapshot()}
	var file: FileAccess = FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return SafeFile.failure(_path, FileAccess.get_open_error())
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or not json.data is Dictionary:
		return SafeFile.failure(_path, ERR_PARSE_ERROR)
	var result: Dictionary = migrate(json.data)
	if not result.ok:
		result.detail = _path
		return result
	_data = result.value
	if json.data != _data:
		result = SafeFile.write_text(_path, JSON.stringify(_data, "\t"))
		if not result.ok:
			return result
	read_only = false
	return {"ok": true, "value": snapshot()}


## Commits the in-memory snapshot only after the durable replacement succeeds.
func save_data(changes: Dictionary) -> Dictionary:
	if read_only:
		return SafeFile.failure(_path, ERR_FILE_CANT_WRITE)
	var candidate: Dictionary = _data.duplicate(true)
	candidate.merge(changes, true)
	var result: Dictionary = migrate(candidate)
	if not result.ok:
		return result
	var next: Dictionary = result.value
	result = SafeFile.write_text(_path, JSON.stringify(next, "\t"))
	if result.ok:
		_data = next
		result.value = snapshot()
	return result


## Callers can edit their copy without changing the committed state.
func snapshot() -> Dictionary:
	return _data.duplicate(true)


## Assigns IDs only when absent, without changing existing engine bindings or extra fields.
static func migrate(data: Dictionary) -> Dictionary:
	var schema: Variant = data.get("schema_version", 0)
	if not (schema is int or schema is float) or (schema != 0 and schema != SCHEMA):
		return {"ok": false, "error": "EDITOR_SETTINGS_SCHEMA_ERROR", "detail": ""}
	var value: Dictionary = data.duplicate(true)
	if not value.get("projects", []) is Array or not value.get("versions", []) is Array:
		return SafeFile.failure(PATH, ERR_INVALID_DATA)
	value["projects"] = value.get("projects", [])
	value["versions"] = value.get("versions", [])
	for engine: Variant in value.versions:
		if not engine is Dictionary or not engine.get("path") is String or not engine.get("name") is String:
			return SafeFile.failure(PATH, ERR_INVALID_DATA)
		engine["is_mono"] = bool(engine.get("is_mono", false))
		engine["is_default"] = bool(engine.get("is_default", false))
	var ids: Dictionary = {}
	for project: Variant in value.projects:
		if not project is Dictionary or not project.get("name") is String or not project.get("project_dir") is String:
			return SafeFile.failure(PATH, ERR_INVALID_DATA)
		if not project.get("engine_index", 0) is int and not project.get("engine_index", 0) is float:
			return SafeFile.failure(PATH, ERR_INVALID_DATA)
		if not project.has("id"):
			project["id"] = ProjectIdentity.create()
		if not project.id is String or not ProjectIdentity.is_valid(project.id) or ids.has(project.id):
			return {"ok": false, "error": "EDITOR_SETTINGS_INVALID_ID", "detail": str(project.id)}
		ids[project.id] = true
		project["engine_index"] = int(project.get("engine_index", 0))
		project["pinned"] = bool(project.get("pinned", false))
		project["tags"] = _tags(project.get("tags", []))
	value["schema_version"] = SCHEMA
	return {"ok": true, "value": value}


static func _tags(raw: Variant) -> Array[String]:
	var tags: Array[String] = []
	if raw is Array:
		for tag: Variant in raw:
			var text: String = str(tag).strip_edges()
			if not text.is_empty() and not tags.has(text):
				tags.append(text)
	return tags
