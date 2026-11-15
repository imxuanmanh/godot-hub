extends SceneTree
## Verifies the [editor_overrides] text transform and a real project.godot round-trip.

const BASE: String = "; header comment\nconfig_version=5\n\n[application]\n\nconfig/name=\"Demo\"\n\n[rendering]\n\nfoo=1\n"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var external: Dictionary = EditorOverridesStore.build_values("external", " C:/My Tools/Code.exe ", "")
	var text: String = EditorOverridesStore.apply_overrides(BASE, external)
	assert(text.begins_with("; header comment\nconfig_version=5\n"), text)
	assert(text.contains("[rendering]\n\nfoo=1\n"), text)
	assert(text.contains("text_editor/external/exec_path=\"C:/My Tools/Code.exe\""), text)
	assert(text.contains("text_editor/external/exec_flags=\"%s\"" % EditorOverridesStore.DEFAULT_FLAGS), text)

	var builtin: String = EditorOverridesStore.apply_overrides(text, EditorOverridesStore.build_values("builtin", "", ""))
	assert(builtin.contains("text_editor/external/use_external_editor=false"), builtin)
	assert(not builtin.contains("exec_path"), builtin)
	assert(EditorOverridesStore.apply_overrides(builtin, {}) .strip_edges() == BASE.strip_edges())

	var foreign: String = BASE + "\n[editor_overrides]\n\ninterface/theme/preset=\"Light\"\n"
	var mixed: String = EditorOverridesStore.apply_overrides(foreign, external)
	assert(mixed.contains("interface/theme/preset=\"Light\""), mixed)
	assert(mixed.count("[editor_overrides]") == 1, mixed)
	var cleared: String = EditorOverridesStore.apply_overrides(mixed, {})
	assert(cleared.contains("[editor_overrides]") and cleared.contains("preset"), cleared)
	assert(not cleared.contains("use_external_editor"), cleared)

	var crlf: String = BASE.replace("\n", "\r\n")
	assert(EditorOverridesStore.apply_overrides(crlf, {}) == crlf)
	assert(EditorOverridesStore.apply_overrides(crlf, external).count("\r\n") == EditorOverridesStore.apply_overrides(crlf, external).count("\n"))

	var dir: String = ProjectSettings.globalize_path("res://build/editor-overrides-tests").path_join(ProjectIdentity.create())
	assert(DirAccess.make_dir_recursive_absolute(dir) == OK)
	assert(SafeFile.write_text(dir.path_join("project.godot"), BASE).ok)
	var loaded: Dictionary = EditorOverridesStore.load_overrides(dir)
	assert(loaded.ok and loaded.mode == "inherit", str(loaded))
	assert(EditorOverridesStore.save_overrides(dir, "external", "C:/Ứng dụng/Code.exe", "{project}").ok)
	loaded = EditorOverridesStore.load_overrides(dir)
	assert(loaded.mode == "external" and loaded.path == "C:/Ứng dụng/Code.exe" and loaded.flags == "{project}", str(loaded))
	assert(not FileAccess.file_exists(dir.path_join("project.godot.bak")))
	assert(EditorOverridesStore.save_overrides(dir, "builtin", "", "").ok)
	assert(EditorOverridesStore.load_overrides(dir).mode == "builtin")
	assert(EditorOverridesStore.save_overrides(dir, "inherit", "", "").ok)
	assert(FileAccess.get_file_as_string(dir.path_join("project.godot")).strip_edges() == BASE.strip_edges())
	assert(not EditorOverridesStore.load_overrides(dir.path_join("missing")).ok)
	print("Editor overrides checks passed.")
	quit()
