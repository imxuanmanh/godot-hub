extends Control

const SAVE_PATH := "user://godot_hub_data.json"
const TAB_VERSIONS: int = 0
const TAB_PROJECTS: int = 1
const TAB_SETTINGS: int = 2
const REPOSITORY_SETTING := "godot_hub/links/repository"

# Keeps the active tab when the scene reloads after a language change.
static var _restore_tab: int = -1

# versions: [{ name: String, path: String, is_mono: bool, is_default: bool }]
var versions: Array = []
# projects: [{ name: String, project_dir: String, engine_index: int }]
var projects: Array = []
var language: String = ""
var _repository_url := ""

@onready var tab_container: TabContainer = $Layout/Root/TabContainer
@onready var versions_tab: VersionsTab = $Layout/Root/TabContainer/Versions
@onready var projects_tab: ProjectsTab = $Layout/Root/TabContainer/Projects
@onready var settings_tab: SettingsTab = $Layout/Root/TabContainer/Settings
@onready var add_version_dialog: AddVersionDialog = $AddVersionDialog
@onready var add_project_dialog: FileDialog = $AddProjectDialog
@onready var github_button: Button = $Layout/Root/Header/GithubButton


func _enter_tree() -> void:
	# Locale must be ready before child nodes build their UI in _ready().
	_load_data()
	TranslationServer.set_locale(language)


func _ready() -> void:
	tab_container.set_tab_title(TAB_VERSIONS, tr("TAB_VERSIONS"))
	tab_container.set_tab_title(TAB_PROJECTS, tr("TAB_PROJECTS"))
	tab_container.set_tab_title(TAB_SETTINGS, tr("TAB_SETTINGS"))
	tab_container.current_tab = _restore_tab if _restore_tab >= 0 else TAB_PROJECTS
	_restore_tab = -1
	settings_tab.set_language(language)
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

	settings_tab.language_changed.connect(_on_language_changed)

	_refresh_versions()
	_refresh_projects()


# ---------------- LANGUAGE ----------------

func _on_language_changed(code: String) -> void:
	if code == language:
		return
	language = code
	_restore_tab = tab_container.current_tab
	_save_data()
	TranslationServer.set_locale(language)
	get_tree().reload_current_scene()


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
	})
	_save_data()
	_refresh_projects()


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
	_save_data()
	OS.create_process(
		versions[engine_index].path,
		["--path", projects[project_index].project_dir, "-e"]
	)


func _on_engine_changed(project_index: int, engine_index: int) -> void:
	if project_index < 0 or project_index >= projects.size():
		return
	projects[project_index].engine_index = engine_index
	_save_data()


# ---------------- PERSISTENCE ----------------

func _save_data() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"versions": versions,
			"projects": projects,
			"language": language,
		}, "\t"))
		f.close()


func _load_data() -> void:
	language = AppLanguages.DEFAULT
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		versions = parsed.get("versions", [])
		projects = parsed.get("projects", [])
		var saved_language := str(parsed.get("language", ""))
		if AppLanguages.is_supported(saved_language):
			language = saved_language
