extends SceneTree
## Verifies executable-name detection of the built-in editor flag presets.

const RIDER_FLAGS: String = "{solution} --line {line} {file}"
const VSCODE_FLAGS: String = "{project} --goto {file}:{line}:{col}"
const SUBLIME_FLAGS: String = "{project} {file}:{line}:{col}"
const KATE_FLAGS: String = "{file} --line {line} --column {col}"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(EditorPresets.flags_for_executable("C:/Rider/rider64.exe") == RIDER_FLAGS)
	assert(EditorPresets.display_name("C:/Rider/rider64.exe") == "JetBrains Rider")
	assert(EditorPresets.flags_for_executable("C:\\Program Files\\Rider\\rider64.exe") == RIDER_FLAGS)

	assert(EditorPresets.flags_for_executable("C:/Code/Code.exe") == VSCODE_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/code.cmd") == VSCODE_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/code-insiders.exe") == VSCODE_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/Codium.exe") == VSCODE_FLAGS)

	assert(EditorPresets.flags_for_executable("C:/Tools/sublime_text.exe") == SUBLIME_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/zed.exe") == SUBLIME_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/kate") == KATE_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/geany.exe") == KATE_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/atom.exe") == "{file}:{line}")
	assert(EditorPresets.flags_for_executable("C:/VS/devenv.exe") == '/edit "{file}"')

	assert(EditorPresets.flags_for_executable("C:/Ứng dụng/Rider/rider64.exe") == RIDER_FLAGS)
	assert(EditorPresets.flags_for_executable("C:/Tools/notepad.exe") == "")
	assert(EditorPresets.display_name("C:/Tools/notepad.exe") == "")
	assert(EditorPresets.flags_for_executable("  ") == "")
	print("Editor presets checks passed.")
	quit()
