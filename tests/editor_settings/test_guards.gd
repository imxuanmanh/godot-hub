extends SceneTree
## Rejects portable engines and a real directory-junction escape before writing.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var root: String = args[0]
	var repo: EditorSettingsRepository = EditorSettingsRepository.new(root)
	assert(not repo.load_project("a".repeat(32)).ok)
	assert(not repo.save_project("a".repeat(32), {EditorSettingsKeys.USE_EXTERNAL: false}).ok)
	var adapter: NativeSettingsAdapter = NativeSettingsAdapter.new()
	adapter.repository = repo
	get_root().add_child(adapter)
	var result: Dictionary = await adapter.prepare(root.path_join("portable/engine.exe"), ProjectIdentity.create(), {EditorSettingsKeys.USE_EXTERNAL: false})
	assert(not result.ok and result.error == "EDITOR_SETTINGS_PORTABLE_ERROR", str(result))
	assert(FileAccess.get_file_as_string(root.path_join("portable/_sc_")) == "marker")
	adapter.queue_free()
	await process_frame
	print("Path containment and portable-engine checks passed.")
	quit()
