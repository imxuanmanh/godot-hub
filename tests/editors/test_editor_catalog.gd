extends SceneTree
## Verifies catalog persistence, validation and corrupt-file handling.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: String = ProjectSettings.globalize_path("res://build/editor-catalog-tests").path_join(ProjectIdentity.create())
	var path: String = root.path_join("editors.json")
	var catalog: EditorCatalog = EditorCatalog.new(path)
	assert(catalog.load_catalog().ok and catalog.list().is_empty())

	assert(catalog.upsert(-1, " VSCode ", "C:/Ứng dụng/Code.exe", "{project} --goto {file}:{line}:{col}").ok)
	assert(catalog.upsert(-1, "Rider", "C:/Rider/rider64.exe", "").ok)
	assert(not catalog.upsert(-1, "", "C:/x.exe", "").ok)
	assert(not catalog.upsert(-1, "No path", " ", "").ok)
	assert(not catalog.upsert(9, "Out", "C:/x.exe", "").ok)
	assert(catalog.list().size() == 2 and catalog.list()[0].name == "VSCode")

	var reloaded: EditorCatalog = EditorCatalog.new(path)
	assert(reloaded.load_catalog().ok and reloaded.list().size() == 2)
	assert(reloaded.upsert(1, "Rider 2026", "C:/Rider/rider64.exe", "{file}").ok)
	assert(reloaded.list()[1].name == "Rider 2026" and reloaded.list()[1].flags == "{file}")
	assert(reloaded.remove(0).ok and reloaded.list().size() == 1)
	assert(not reloaded.remove(5).ok)

	assert(SafeFile.write_text(path, "{broken").ok)
	var corrupt: EditorCatalog = EditorCatalog.new(path)
	assert(not corrupt.load_catalog().ok and corrupt.read_only)
	assert(not corrupt.upsert(-1, "X", "C:/x.exe", "").ok)
	assert(FileAccess.get_file_as_string(path) == "{broken")
	print("Editor catalog checks passed.")
	quit()
