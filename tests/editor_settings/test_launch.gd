extends SceneTree
## Exercises the real launch service with disposable projects and native settings.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")
const OBSERVER: String = "res://tests/editor_settings/observe_editor.gd.txt"
const NATIVE_KEY: String = "text_editor/appearance/whitespace/draw_tabs"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	assert(args.size() in [1, 2])
	var engine: Dictionary = {"path": args[0]}
	var root: String = ProjectSettings.globalize_path("res://build/launch-tests").path_join(ProjectIdentity.create())
	var repo: EditorSettingsRepository = EditorSettingsRepository.new(root.path_join("data"))
	var service: EditorLaunchService = EditorLaunchService.new()
	service.repository = repo
	get_root().add_child(service)
	var a: Dictionary = _fixture(root, "Project A Unicode đ")
	var b: Dictionary = _fixture(root, "Project B")
	assert(repo.load_default().ok)
	var external_path: String = args[1] if args.size() == 2 else OS.get_executable_path()
	var flags: String = "--disable-extensions --new-window --goto {file}:{line}:{col}" if args.size() == 2 else "{project}"
	assert(repo.save_project(b.id, {Keys.USE_EXTERNAL: true, Keys.EXEC_PATH: external_path, Keys.EXEC_FLAGS: flags}).ok)
	var launched_a: Dictionary = await service.launch(a, engine)
	assert(launched_a.ok, str(launched_a))
	var launched_b: Dictionary = await service.launch(b, engine)
	assert(launched_b.ok, str(launched_b))
	await _wait_for_file(a.project_dir.path_join("observed.cfg"))
	await _wait_for_file(b.project_dir.path_join("observed.cfg"))
	var observed: ConfigFile = ConfigFile.new()
	assert(observed.load(a.project_dir.path_join("observed.cfg")) == OK)
	assert(not observed.get_value("editor", Keys.USE_EXTERNAL))
	var native_original: bool = observed.get_value("editor", NATIVE_KEY)
	assert(observed.load(b.project_dir.path_join("observed.cfg")) == OK)
	assert(observed.get_value("editor", Keys.USE_EXTERNAL))
	var vscode_root: String = OS.get_environment("VSCODE_APPDATA")
	assert(observed.get_value("paths", "vscode_appdata") == (OS.get_environment("APPDATA") if vscode_root.is_empty() else vscode_root))
	assert(OS.is_process_running(launched_a.pid) and OS.is_process_running(launched_b.pid))
	if args.size() == 2:
		_write(a.project_dir.path_join("open_script"), "open")
		_write(b.project_dir.path_join("open_script"), "open")
		await _wait_for_file(a.project_dir.path_join("script_opened.txt"))
		await _wait_for_file(b.project_dir.path_join("script_opened.txt"))
		assert(FileAccess.get_file_as_string(a.project_dir.path_join("script_opened.txt")) == "res://fixture.gd")
		assert(FileAccess.get_file_as_string(b.project_dir.path_join("script_opened.txt")) == "external")
	var duplicate: Dictionary = await service.launch(a, engine)
	assert(not duplicate.ok and duplicate.error == "EDITOR_SETTINGS_ALREADY_RUNNING")
	await _stop(a, launched_a.pid, {Keys.USE_EXTERNAL: true, NATIVE_KEY: not native_original})
	await _stop(b, launched_b.pid)
	_clear_observation(a)
	launched_a = await service.launch(a, engine)
	assert(launched_a.ok, str(launched_a))
	await _wait_for_file(a.project_dir.path_join("observed.cfg"))
	assert(observed.load(a.project_dir.path_join("observed.cfg")) == OK)
	assert(not observed.get_value("editor", Keys.USE_EXTERNAL))
	assert(observed.get_value("editor", NATIVE_KEY) == not native_original)
	await _stop(a, launched_a.pid)
	assert(repo.save_default({Keys.USE_EXTERNAL: true, Keys.EXEC_PATH: OS.get_executable_path()}).ok)
	_clear_observation(a)
	launched_a = await service.launch(a, engine)
	assert(launched_a.ok, str(launched_a))
	await _wait_for_file(a.project_dir.path_join("observed.cfg"))
	assert(observed.load(a.project_dir.path_join("observed.cfg")) == OK)
	assert(observed.get_value("editor", Keys.USE_EXTERNAL))
	await _stop(a, launched_a.pid)
	service.queue_free()
	await process_frame
	print("Launch integration checks passed: " + root)
	quit()


func _fixture(root: String, name: String) -> Dictionary:
	var path: String = root.path_join(name)
	assert(DirAccess.make_dir_recursive_absolute(path.path_join("addons/observer")) == OK)
	_write(path.path_join("addons/observer/observer.gd"), FileAccess.get_file_as_string(OBSERVER))
	_write(path.path_join("addons/observer/plugin.cfg"), '[plugin]\nname="Observer"\nscript="observer.gd"\n')
	_write(path.path_join("fixture.gd"), "extends Node\n")
	_write(path.path_join("project.godot"), 'config_version=5\n[application]\nconfig/name="Fixture"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/observer/plugin.cfg")\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
	return {"id": ProjectIdentity.create(), "project_dir": path}


func _wait_for_file(path: String) -> void:
	var started: int = Time.get_ticks_msec()
	while not FileAccess.file_exists(path):
		assert(Time.get_ticks_msec() - started < 45000, path)
		await create_timer(0.1).timeout


func _stop(project: Dictionary, pid: int, changes: Dictionary = {}) -> void:
	if not changes.is_empty():
		var cfg: ConfigFile = ConfigFile.new()
		for key: String in changes:
			cfg.set_value("editor", key, changes[key])
		assert(cfg.save(project.project_dir.path_join("change.cfg")) == OK)
	_write(project.project_dir.path_join("stop"), "stop")
	while OS.is_process_running(pid):
		await create_timer(0.1).timeout


func _clear_observation(project: Dictionary) -> void:
	assert(DirAccess.remove_absolute(project.project_dir.path_join("stop")) == OK)
	assert(DirAccess.remove_absolute(project.project_dir.path_join("observed.cfg")) == OK)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()
