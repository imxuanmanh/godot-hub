extends Control

const SAVE_PATH := "user://godot_hub_data.json"

# versions: [{ name: String, path: String, is_mono: bool, is_default: bool }]
var versions: Array = []
# projects: [{ name: String, project_dir: String, engine_index: int }]
var projects: Array = []

@onready var versions_list: ItemList = $TabContainer/Versions/VersionsList
@onready var projects_list: ItemList = $TabContainer/Projects/ProjectsList
@onready var engine_selector: OptionButton = $TabContainer/Projects/LaunchBar/EngineSelector
@onready var add_version_dialog: FileDialog = $AddVersionDialog
@onready var add_project_dialog: FileDialog = $AddProjectDialog


func _ready() -> void:
	_load_data()
	_refresh_versions_list()
	_refresh_projects_list()
	_refresh_engine_selector()


# ---------------- VERSIONS TAB ----------------

func _on_add_version_pressed() -> void:
	add_version_dialog.popup_centered()


func _on_version_file_selected(path: String) -> void:
	var file_name := path.get_file().to_lower()
	var is_mono := file_name.find("mono") != -1
	versions.append({
		"name": path.get_file(),
		"path": path,
		"is_mono": is_mono,
		"is_default": versions.is_empty(),
	})
	_save_data()
	_refresh_versions_list()
	_refresh_engine_selector()


func _on_remove_version_pressed() -> void:
	var selected := versions_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	var removed_was_default: bool = versions[idx].is_default
	versions.remove_at(idx)
	if removed_was_default and not versions.is_empty():
		versions[0].is_default = true
	_save_data()
	_refresh_versions_list()
	_refresh_engine_selector()


func _on_set_default_pressed() -> void:
	var selected := versions_list.get_selected_items()
	if selected.is_empty():
		return
	for i in versions.size():
		versions[i].is_default = (i == selected[0])
	_save_data()
	_refresh_versions_list()


func _on_open_download_page_pressed() -> void:
	OS.shell_open("https://godotengine.org/download")


func _refresh_versions_list() -> void:
	versions_list.clear()
	for v in versions:
		var tag := " [Mono]" if v.is_mono else " [Standard]"
		var star := " ★" if v.is_default else ""
		versions_list.add_item(v.name + tag + star)


# ---------------- PROJECTS TAB ----------------

func _on_add_project_pressed() -> void:
	add_project_dialog.popup_centered()


func _on_project_file_selected(path: String) -> void:
	var project_dir := path.get_base_dir()
	var default_engine_index := 0
	for i in versions.size():
		if versions[i].is_default:
			default_engine_index = i
			break
	projects.append({
		"name": _read_project_name(path),
		"project_dir": project_dir,
		"engine_index": default_engine_index,
	})
	_save_data()
	_refresh_projects_list()


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


func _on_remove_project_pressed() -> void:
	var selected := projects_list.get_selected_items()
	if selected.is_empty():
		return
	projects.remove_at(selected[0])
	_save_data()
	_refresh_projects_list()


func _refresh_projects_list() -> void:
	projects_list.clear()
	for p in projects:
		projects_list.add_item(p.name)


func _on_project_selected(index: int) -> void:
	_refresh_engine_selector()
	if index >= 0 and index < projects.size():
		var idx: int = projects[index].engine_index
		if idx >= 0 and idx < engine_selector.item_count:
			engine_selector.select(idx)


func _refresh_engine_selector() -> void:
	engine_selector.clear()
	for v in versions:
		var tag := " [Mono]" if v.is_mono else " [Standard]"
		engine_selector.add_item(v.name + tag)


func _on_launch_pressed() -> void:
	var proj_selected := projects_list.get_selected_items()
	if proj_selected.is_empty():
		return
	var proj_index: int = proj_selected[0]
	var engine_index := engine_selector.get_selected()
	if engine_index < 0 or engine_index >= versions.size():
		return

	projects[proj_index].engine_index = engine_index
	_save_data()

	var engine_path: String = versions[engine_index].path
	var project_dir: String = projects[proj_index].project_dir
	OS.create_process(engine_path, ["--path", project_dir, "-e"])


# ---------------- PERSISTENCE ----------------

func _save_data() -> void:
	var data := {
		"versions": versions,
		"projects": projects,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


func _load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		versions = parsed.get("versions", [])
		projects = parsed.get("projects", [])
