extends Control

const TAB_VERSIONS: int = 0
const TAB_PROJECTS: int = 1
const TAB_EDITORS: int = 2
const TAB_SETTINGS: int = 3
const REPOSITORY_SETTING := "godot_hub/links/repository"

# Keeps the active tab when the scene reloads after a language change.
static var _restore_tab: int = -1

# versions: [{ name: String, path: String, is_mono: bool, is_default: bool }]
var versions: Array = []
# projects: [{ name: String, project_dir: String, engine_index: int, pinned: bool, tags: Array[String] }]
var projects: Array = []
var language: String = ""
var close_on_launch: bool = false
var _repository_url := ""
var _data_repository: HubDataRepository = HubDataRepository.new()
var _load_result: Dictionary = {}
var _editor_catalog: EditorCatalog = EditorCatalog.new()

@onready var tab_container: TabContainer = $Layout/Root/TabContainer
@onready var versions_tab: VersionsTab = $Layout/Root/TabContainer/Versions
@onready var projects_tab: ProjectsTab = $Layout/Root/TabContainer/Projects
@onready var editors_tab: EditorsTab = $Layout/Root/TabContainer/Editors
@onready var settings_tab: SettingsTab = $Layout/Root/TabContainer/Settings
@onready var add_version_dialog: AddVersionDialog = $AddVersionDialog
@onready var project_tags_dialog: ProjectTagsDialog = $ProjectTagsDialog
@onready var project_editor_dialog: ProjectEditorDialog = $ProjectEditorDialog
@onready var add_project_dialog: FileDialog = $AddProjectDialog
@onready var github_button: Button = $Layout/Root/Header/GithubButton
@onready var error_dialog: AcceptDialog = $ErrorDialog


func _enter_tree() -> void:
	# Locale must be ready before child nodes build their UI in _ready().
	_load_data()
	TranslationServer.set_locale(language)


func _ready() -> void:
	tab_container.set_tab_title(TAB_VERSIONS, tr("TAB_VERSIONS"))
	tab_container.set_tab_title(TAB_PROJECTS, tr("TAB_PROJECTS"))
	tab_container.set_tab_title(TAB_EDITORS, tr("TAB_EDITORS"))
	tab_container.set_tab_title(TAB_SETTINGS, tr("TAB_SETTINGS"))
	tab_container.current_tab = _restore_tab if _restore_tab >= 0 else TAB_PROJECTS
	_restore_tab = -1
	settings_tab.set_language(language)
	settings_tab.set_close_on_launch(close_on_launch)
	_setup_github_button()

	add_project_dialog.title = tr("PROJECT_DIALOG_TITLE")
	add_project_dialog.ok_button_text = tr("COMMON_CHOOSE")
	add_project_dialog.filters = PackedStringArray(["*.godot ; %s" % tr("PROJECT_FILTER")])

	versions_tab.add_requested.connect(_on_add_version_pressed)
	versions_tab.remove_requested.connect(_on_remove_version_requested)
	versions_tab.set_default_requested.connect(_on_set_default_requested)
	versions_tab.download_requested.connect(_on_open_download_page_pressed)
	add_version_dialog.version_ready.connect(_on_version_ready)

	projects_tab.add_requested.connect(_on_add_project_pressed)
	projects_tab.remove_requested.connect(_on_remove_project_requested)
	projects_tab.launch_requested.connect(_on_launch_requested)
	projects_tab.engine_changed.connect(_on_engine_changed)
	projects_tab.pin_toggled.connect(_on_pin_toggled)
	projects_tab.tags_requested.connect(_on_project_tags_requested)
	projects_tab.editor_config_requested.connect(_on_editor_config_requested)
	projects_tab.open_folder_requested.connect(_on_open_folder_requested)
	project_tags_dialog.tags_submitted.connect(_on_project_tags_submitted)
	project_editor_dialog.editor_saved.connect(_on_project_editor_saved)

	var catalog_result: Dictionary = _editor_catalog.load_catalog()
	editors_tab.setup(_editor_catalog)
	editors_tab.error_occurred.connect(_show_error)
	editors_tab.editor_removed.connect(_on_editor_removed)
	if not catalog_result.ok:
		_show_error.call_deferred(catalog_result)

	settings_tab.language_changed.connect(_on_language_changed)
	settings_tab.close_on_launch_changed.connect(_on_close_on_launch_changed)

	_refresh_versions()
	_refresh_projects()
	if not _load_result.ok:
		_show_error.call_deferred(_load_result)


# ---------------- LANGUAGE ----------------

func _on_language_changed(code: String) -> void:
	if code == language:
		return
	language = code
	_restore_tab = tab_container.current_tab
	if not _save_data():
		_restore_tab = -1
		return
	TranslationServer.set_locale(language)
	get_tree().reload_current_scene()


func _on_close_on_launch_changed(enabled: bool) -> void:
	close_on_launch = enabled
	_save_data()


func _setup_github_button() -> void:
	_repository_url = str(ProjectSettings.get_setting(REPOSITORY_SETTING, ""))
	github_button.visible = not _repository_url.is_empty()
	github_button.tooltip_text = _repository_url
	github_button.pressed.connect(_on_github_pressed)


func _on_github_pressed() -> void:
	OS.shell_open(_repository_url)


func _refresh_versions() -> void:
	versions_tab.set_versions(versions)
	projects_tab.set_versions(versions)


func _refresh_projects() -> void:
	projects_tab.set_projects(projects)


# ---------------- VERSIONS TAB ----------------

func _on_add_version_pressed() -> void:
	add_version_dialog.open_dialog()


func _on_version_ready(version: Dictionary) -> void:
	version["is_default"] = versions.is_empty()
	versions.append(version)
	_save_data()
	_refresh_versions()


func _on_remove_version_requested(index: int) -> void:
	if index < 0 or index >= versions.size():
		return
	var removed_was_default: bool = versions[index].is_default
	versions.remove_at(index)
	for p in projects:
		if p.engine_index == index:
			p.engine_index = clampi(index, 0, maxi(versions.size() - 1, 0))
		elif p.engine_index > index:
			p.engine_index -= 1
	if removed_was_default and not versions.is_empty():
		versions[0].is_default = true
	_save_data()
	_refresh_versions()
	_refresh_projects()


func _on_set_default_requested(index: int) -> void:
	if index < 0 or index >= versions.size():
		return
	for i in versions.size():
		versions[i].is_default = (i == index)
	_save_data()
	_refresh_versions()


func _on_open_download_page_pressed() -> void:
	OS.shell_open("https://godotengine.org/download")


# ---------------- PROJECTS TAB ----------------

func _on_add_project_pressed() -> void:
	add_project_dialog.popup_centered()


func _on_project_file_selected(path: String) -> void:
	var default_engine_index := 0
	for i in versions.size():
		if versions[i].is_default:
			default_engine_index = i
			break
	projects.append({
		"name": _read_project_name(path),
		"project_dir": path.get_base_dir(),
		"engine_index": default_engine_index,
		"pinned": false,
		"tags": [],
	})
	_save_data()
	_refresh_projects()
	_init_project_editor(path.get_base_dir())


# An override already in project.godot is kept; otherwise built-in is pinned so Godot's global setting cannot leak in.
func _init_project_editor(project_dir: String) -> void:
	var config: Dictionary = EditorOverridesStore.load_overrides(project_dir)
	if not config.ok or str(config.mode) != EditorOverridesStore.MODE_INHERIT:
		return
	var result: Dictionary = EditorOverridesStore.save_overrides(project_dir, EditorOverridesStore.MODE_BUILTIN, "", "")
	if not result.ok:
		_show_error(result)


func _read_project_name(path: String) -> String:
	var fallback := path.get_base_dir().get_file()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return fallback
	var result := fallback
	while not f.eof_reached():
		var line := f.get_line()
		if line.begins_with("config/name="):
			result = line.substr("config/name=".length()).strip_edges()
			result = result.lstrip("\"").rstrip("\"")
			break
	f.close()
	return result


func _on_remove_project_requested(index: int) -> void:
	if index < 0 or index >= projects.size():
		return
	projects.remove_at(index)
	_save_data()
	_refresh_projects()


func _on_launch_requested(project_index: int, engine_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	if engine_index < 0 or engine_index >= versions.size():
		return
	projects[project_index].engine_index = engine_index
	if not _save_data():
		return
	var result: Dictionary = ProcessService.spawn(
		str(versions[engine_index].path),
		PackedStringArray(["--path", str(projects[project_index].project_dir), "-e"])
	)
	if not result.ok:
		_show_error(result)
	elif close_on_launch and result.pid > 0:
		get_tree().quit()


func _on_editor_config_requested(project_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	var project: Dictionary = projects[project_index]
	var config: Dictionary = EditorOverridesStore.load_overrides(str(project.project_dir))
	if not config.ok:
		_show_error(config)
		return
	project_editor_dialog.open_dialog(project_index, str(project.name), config, _editor_catalog.list())


func _on_project_editor_saved(project_index: int, mode: String, path: String, flags: String) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	var result: Dictionary = EditorOverridesStore.save_overrides(
		str(projects[project_index].project_dir), mode, path, flags
	)
	if not result.ok:
		_show_error(result)


# Projects still pointing at the removed editor fall back to Godot built-in.
func _on_editor_removed(editor_path: String) -> void:
	var project_dirs: Array[String] = []
	for project in projects:
		project_dirs.append(str(project.project_dir))
	var result: Dictionary = EditorOverridesStore.reset_projects_to_builtin(project_dirs, editor_path)
	if not result.ok:
		_show_error(result)


func _on_open_folder_requested(project_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	var project_dir := str(projects[project_index].project_dir)
	var error := OS.shell_open(project_dir) if DirAccess.dir_exists_absolute(project_dir) else ERR_FILE_NOT_FOUND
	if error != OK:
		_show_error({"error": "ERR_OPEN_FOLDER", "detail": project_dir})
		return


func _on_engine_changed(project_index: int, engine_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	projects[project_index].engine_index = engine_index
	_save_data()


func _on_pin_toggled(project_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	projects[project_index].pinned = not bool(projects[project_index].get("pinned", false))
	_save_data()
	_refresh_projects()


func _on_project_tags_requested(project_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	project_tags_dialog.open_dialog(
		project_index,
		str(projects[project_index].name),
		projects[project_index].get("tags", [])
	)


func _on_project_tags_submitted(project_index: int, tags: Array[String]) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	projects[project_index].tags = tags
	_save_data()
	_refresh_projects()


# ---------------- PERSISTENCE ----------------

func _save_data() -> bool:
	var result: Dictionary = _data_repository.save_data({
		"versions": versions, "projects": projects,
		"language": language, "close_on_launch": close_on_launch,
	})
	_apply_data(_data_repository.snapshot())
	if not result.ok:
		_refresh_versions()
		_refresh_projects()
		settings_tab.set_language(language)
		settings_tab.set_close_on_launch(close_on_launch)
		_show_error(result)
	return result.ok


func _load_data() -> void:
	_load_result = _data_repository.load_data()
	_apply_data(_data_repository.snapshot())


func _apply_data(data: Dictionary) -> void:
	versions.assign(data.get("versions", []))
	projects.assign(data.get("projects", []))
	close_on_launch = bool(data.get("close_on_launch", false))
	var saved_language: String = str(data.get("language", AppLanguages.DEFAULT))
	language = saved_language if AppLanguages.is_supported(saved_language) else AppLanguages.DEFAULT


func _show_error(result: Dictionary) -> void:
	error_dialog.title = tr("COMMON_ERROR")
	error_dialog.dialog_text = tr(str(result.error)) + "\n" + str(result.get("detail", ""))
	push_warning(error_dialog.dialog_text)
	error_dialog.popup_centered()
