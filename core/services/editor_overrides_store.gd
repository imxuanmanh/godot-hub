class_name EditorOverridesStore
extends RefCounted
## Reads and writes the external-editor keys in a project's [editor_overrides] section.
##
## Godot applies these keys on top of the global editor settings for that project only.
## Writes touch only the managed lines so comments and other sections stay untouched.

const PROJECT_FILE: String = "project.godot"
const SECTION: String = "editor_overrides"
const KEY_USE_EXTERNAL: String = "text_editor/external/use_external_editor"
const KEY_EXEC_PATH: String = "text_editor/external/exec_path"
const KEY_EXEC_FLAGS: String = "text_editor/external/exec_flags"
const MANAGED_KEYS: Array[String] = [KEY_USE_EXTERNAL, KEY_EXEC_PATH, KEY_EXEC_FLAGS]
const MODE_INHERIT: String = "inherit"
const MODE_BUILTIN: String = "builtin"
const MODE_EXTERNAL: String = "external"
const DEFAULT_FLAGS: String = "{project} --goto {file}:{line}:{col}"


## Returns {ok, mode, path, flags}; mode is inherit when no managed key is set.
static func load_overrides(project_dir: String) -> Dictionary:
	var file_path: String = project_dir.path_join(PROJECT_FILE)
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(file_path)
	if error != OK:
		return SafeFile.failure(file_path, error)
	var mode: String = MODE_INHERIT
	if config.has_section_key(SECTION, KEY_USE_EXTERNAL):
		mode = MODE_EXTERNAL if bool(config.get_value(SECTION, KEY_USE_EXTERNAL)) else MODE_BUILTIN
	return {
		"ok": true,
		"mode": mode,
		"path": str(config.get_value(SECTION, KEY_EXEC_PATH, "")),
		"flags": str(config.get_value(SECTION, KEY_EXEC_FLAGS, DEFAULT_FLAGS)),
	}


static func save_overrides(project_dir: String, mode: String, path: String, flags: String) -> Dictionary:
	var file_path: String = project_dir.path_join(PROJECT_FILE)
	if not FileAccess.file_exists(file_path):
		return SafeFile.failure(file_path, ERR_FILE_NOT_FOUND)
	var text: String = FileAccess.get_file_as_string(file_path)
	var updated: String = apply_overrides(text, build_values(mode, path, flags))
	if updated == text:
		return {"ok": true}
	var result: Dictionary = SafeFile.write_text(file_path, updated)
	if result.ok:
		# SafeFile keeps a .bak for Hub data; inside a user's repo it would only be noise.
		DirAccess.remove_absolute(file_path + SafeFile.BACKUP_SUFFIX)
	return result


## Maps a dialog mode to the key/value pairs that should exist after saving.
static func build_values(mode: String, path: String, flags: String) -> Dictionary:
	if mode == MODE_BUILTIN:
		return {KEY_USE_EXTERNAL: false}
	if mode == MODE_EXTERNAL:
		var clean_flags: String = flags.strip_edges()
		return {
			KEY_USE_EXTERNAL: true,
			KEY_EXEC_PATH: path.strip_edges(),
			KEY_EXEC_FLAGS: clean_flags if not clean_flags.is_empty() else DEFAULT_FLAGS,
		}
	return {}


## Pure text transform: rewrites the section with the managed keys, keeping every other line.
static func apply_overrides(text: String, values: Dictionary) -> String:
	var newline: String = "
" if text.contains("
") else "
"
	var lines: PackedStringArray = text.replace("
", "
").split("
")
	var bounds: Vector2i = _section_bounds(lines)
	var before: PackedStringArray = lines
	var after: PackedStringArray = PackedStringArray()
	var body: PackedStringArray = PackedStringArray()
	if bounds.x >= 0:
		before = lines.slice(0, bounds.x)
		after = lines.slice(bounds.y)
		for line: String in lines.slice(bounds.x + 1, bounds.y):
			if not line.strip_edges().is_empty() and not _is_managed(line):
				body.append(line)
	for key: String in MANAGED_KEYS:
		if values.has(key):
			body.append("%s=%s" % [key, var_to_str(values[key])])
	var result: PackedStringArray = before.duplicate()
	if not body.is_empty():
		if not result.is_empty() and not result[result.size() - 1].strip_edges().is_empty():
			result.append("")
		result.append("[%s]" % SECTION)
		result.append("")
		result.append_array(body)
		result.append("")
	result.append_array(after)
	return newline.join(result)


## x = header line index (-1 when missing), y = index of the next section header or EOF.
static func _section_bounds(lines: PackedStringArray) -> Vector2i:
	var header: String = "[%s]" % SECTION
	var start: int = -1
	for i: int in lines.size():
		var line: String = lines[i].strip_edges()
		if start < 0:
			if line == header:
				start = i
		elif line.begins_with("["):
			return Vector2i(start, i)
	return Vector2i(start, lines.size())


static func _is_managed(line: String) -> bool:
	return line.contains("=") and MANAGED_KEYS.has(line.get_slice("=", 0).strip_edges())
