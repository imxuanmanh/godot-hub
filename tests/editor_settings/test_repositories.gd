extends SceneTree
## Uses a new scratch directory on every run, never the real Hub user data.

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")


func _initialize() -> void:
	var root: String = "res://build/repository-tests/" + ProjectIdentity.create()
	assert(DirAccess.make_dir_recursive_absolute(root) == OK)
	_test_cfg(root)
	_test_json(root)
	_test_failed_replace(root)
	print("Repository checks passed.")
	quit()


func _test_cfg(root: String) -> void:
	var repo: EditorSettingsRepository = EditorSettingsRepository.new(root)
	var id: String = ProjectIdentity.create()
	var defaults: Dictionary = repo.load_default()
	assert(defaults.ok and defaults.values[Keys.USE_EXTERNAL] == false)
	assert(repo.load_project(id).values.is_empty())
	assert(repo.save_project(id, {}).ok and not repo.load_project(id).exists)
	assert(repo.save_project(id, {Keys.USE_EXTERNAL: false, Keys.EXEC_PATH: ""}).ok)
	assert(repo.save_default({Keys.USE_EXTERNAL: true}).ok)
	assert(repo.load_project(id).values[Keys.USE_EXTERNAL] == false)
	assert(repo.save_project(id, {}).ok)
	assert(not repo.load_project(id).values.has(Keys.USE_EXTERNAL))
	assert(repo.load_default().values[Keys.USE_EXTERNAL])
	assert(not repo.load_project("../escape").ok)
	assert(not repo.load_project("a/".repeat(16)).ok)
	var path: String = repo.load_project(id).path
	assert(SafeFile.write_text(path, '[meta]\nschema_version=2\n[editor]\ncustom="keep"\n').ok)
	var previous: String = FileAccess.get_file_as_string(path)
	assert(not repo.save_project(id, {}).ok)
	assert(FileAccess.get_file_as_string(path) == previous)
	assert(SafeFile.write_text(path, '[meta]\nschema_version=1\n[other]\ncustom="keep"\n[editor]\nunknown=42\n').ok)
	assert(repo.save_project(id, {Keys.USE_EXTERNAL: false}).ok)
	var saved: ConfigFile = repo.load_project(id).cfg
	assert(saved.get_value("other", "custom") == "keep")
	assert(saved.get_value("editor", "unknown") == 42)
	assert(SafeFile.write_text(path, "[").ok)
	assert(not repo.save_project(id, {}).ok and FileAccess.get_file_as_string(path) == "[")
	assert(SafeFile.write_text(path, "").ok and repo.load_project(id).ok)


func _test_json(root: String) -> void:
	var path: String = root.path_join("hub.json")
	var old: Dictionary = {"versions": [], "projects": [{"name": "Game", "project_dir": "space / Unicode đ", "engine_index": 3, "pinned": true, "tags": ["a"], "custom": 42}], "language": "vi", "close_on_launch": true, "future": "preserved"}
	assert(SafeFile.write_text(path, JSON.stringify(old)).ok)
	var repo: HubDataRepository = HubDataRepository.new(path)
	var result: Dictionary = repo.load_data()
	assert(result.ok and result.value.schema_version == 1)
	var id: String = result.value.projects[0].id
	assert(ProjectIdentity.is_valid(id))
	assert(result.value.projects[0].engine_index == 3 and result.value.projects[0].pinned)
	assert(result.value.language == "vi" and result.value.close_on_launch)
	assert(result.value.projects[0].custom == 42 and result.value.future == "preserved")
	assert(repo.save_data({"language": "en"}).ok)
	result = repo.load_data()
	assert(result.ok, str(result))
	assert(result.value.projects[0].id == id)
	assert(repo.snapshot().future == "preserved")
	var changed: Dictionary = repo.snapshot()
	changed.projects[0].name = "Renamed"
	changed.projects[0].engine_index = 0
	changed.projects.reverse()
	assert(repo.save_data(changed).ok)
	assert(repo.load_data().value.projects[0].id == id)
	assert(SafeFile.write_text(path, '{"schema_version":2}').ok)
	assert(not repo.load_data().ok and repo.read_only)
	assert(not repo.save_data({}).ok)
	assert(FileAccess.get_file_as_string(path) == '{"schema_version":2}')
	assert(SafeFile.write_text(path, "broken").ok)
	assert(not repo.load_data().ok and FileAccess.get_file_as_string(path) == "broken")


func _test_failed_replace(root: String) -> void:
	var path: String = root.path_join("atomic.txt")
	assert(SafeFile.write_text(path, "original").ok)
	assert(not SafeFile._replace(root.path_join("missing.tmp"), path).ok)
	assert(FileAccess.get_file_as_string(path) == "original")
	assert(DirAccess.make_dir_absolute(path + SafeFile.TEMP_SUFFIX) == OK)
	assert(not SafeFile.write_text(path, "replacement").ok)
	assert(FileAccess.get_file_as_string(path) == "original")
	assert(DirAccess.rename_absolute(path, path + SafeFile.BACKUP_SUFFIX) == OK)
	assert(SafeFile.recover(path).ok and FileAccess.get_file_as_string(path) == "original")
