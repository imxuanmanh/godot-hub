extends Control

const SAVE_PATH := "user://godot_hub_data.json"

# versions: [{ name: String, path: String, is_mono: bool, is_default: bool }]
var versions: Array = []
# projects: [{ name: String, project_dir: String, engine_index: int }]
var projects: Array = []

@onready var tab_container: TabContainer = $Layout/Root/TabContainer
@onready var versions_tab: VersionsTab = $Layout/Root/TabContainer/Versions
@onready var projects_tab: ProjectsTab = $Layout/Root/TabContainer/Projects
@onready var add_version_dialog: AddVersionDialog = $AddVersionDialog
@onready var add_project_dialog: FileDialog = $AddProjectDialog


func _ready() -> void:
	tab_container.set_tab_title(0, "Phiên bản")
	tab_container.set_tab_title(1, "Project")

	versions_tab.add_requested.connect(_on_add_version_pressed)
	versions_tab.remove_requested.connect(_on_remove_version_requested)
	versions_tab.set_default_requested.connect(_on_set_default_requested)
	versions_tab.download_requested.connect(_on_open_download_page_pressed)
	add_version_dialog.version_ready.connect(_on_version_ready)

	projects_tab.add_requested.connect(_on_add_project_pressed)
	projects_tab.remove_requested.connect(_on_remove_project_requested)
	projects_tab.launch_requested.connect(_on_launch_requested)
	projects_tab.engine_changed.connect(_on_engine_changed)

	_load_data()
	_refresh_versions()
	_refresh_projects()


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
		f.store_string(JSON.stringify({"versions": versions, "projects": projects}, "\t"))
		f.close()


func _load_data() -> void:
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
