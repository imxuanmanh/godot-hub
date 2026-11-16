class_name EditorPresets
extends RefCounted
## Knows the external-editor flags Godot expects for common editors.
##
## Matching is by executable file name only; the flag strings mirror the presets
## from Godot's "Using an external text editor" documentation.

const PRESETS: Array[Dictionary] = [
	{
		"name": "JetBrains Rider",
		"executables": ["rider64", "rider"],
		# {solution} is resolved (and quoted) by the Hub to the project's .sln before saving.
		"flags": "{solution} --line {line} {file}",
	},
	{
		"name": "Visual Studio Code",
		"executables": ["code", "code-insiders", "codium"],
		"flags": "{project} --goto {file}:{line}:{col}",
	},
	{
		"name": "Sublime Text / Zed",
		"executables": ["sublime_text", "zed"],
		"flags": "{project} {file}:{line}:{col}",
	},
	{
		"name": "Kate / Geany",
		"executables": ["kate", "geany"],
		"flags": "{file} --line {line} --column {col}",
	},
	{
		"name": "Atom",
		"executables": ["atom"],
		"flags": "{file}:{line}",
	},
	{
		"name": "Visual Studio",
		"executables": ["devenv"],
		"flags": '/edit "{file}"',
	},
]


## Flags for the preset matching the executable's file name, or "" when unknown.
static func flags_for_executable(path: String) -> String:
	return str(_match(path).get("flags", ""))


## Human-readable preset name for the executable, or "" when unknown.
static func display_name(path: String) -> String:
	return str(_match(path).get("name", ""))


static func _match(path: String) -> Dictionary:
	var exe: String = path.strip_edges().replace("\\", "/").get_file().get_basename().to_lower()
	if exe.is_empty():
		return {}
	for preset: Dictionary in PRESETS:
		if preset.executables.has(exe):
			return preset
	return {}
