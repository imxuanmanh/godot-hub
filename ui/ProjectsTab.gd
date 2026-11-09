class_name ProjectsTab
extends VBoxContainer

signal add_requested
signal remove_requested(index: int)
signal launch_requested(project_index: int, engine_index: int)
signal engine_changed(project_index: int, engine_index: int)

const ITEM_SCENE := preload("res://ui/ProjectItem.tscn")

var _projects: Array = []
var _versions: Array = []
var _items: Array = []
var _selected_index := -1
var _button_group := ButtonGroup.new()
var _version_regex := RegEx.new()

@onready var items_container: VBoxContainer = $ListStack/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Stack/EmptyState
@onready var count_label: Label = $Toolbar/CountLabel
@onready var remove_button: Button = $Toolbar/RemoveButton
@onready var engine_selector: OptionButton = $LaunchPanel/Content/EngineSelector
@onready var launch_button: Button = $LaunchPanel/Content/LaunchButton


func _ready() -> void:
	_version_regex.compile("v?(\\d+\\.\\d+(?:\\.\\d+)?)")
	$Header/AddButton.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_emit_remove)
	launch_button.pressed.connect(_emit_launch)
	engine_selector.item_selected.connect(_on_engine_selected)
	_update_actions()


func set_versions(new_versions: Array) -> void:
	_versions = new_versions
	engine_selector.clear()
	for v in _versions:
		var tag := " [Mono]" if v.is_mono else " [Standard]"
		engine_selector.add_item(v.name + tag)
	engine_selector.disabled = _versions.is_empty()
	_refresh_engine_selection()
	_refresh_item_engine()
	_update_actions()


func set_projects(new_projects: Array) -> void:
	_projects = new_projects
	_rebuild_items()
	count_label.text = "%d project" % _projects.size()
	_update_actions()
	_update_empty_state()


func get_selected_index() -> int:
	return _selected_index


func _rebuild_items() -> void:
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()
	_items.clear()
	_selected_index = -1
	_button_group = ButtonGroup.new()
	_button_group.pressed.connect(_on_item_pressed)
	for i in _projects.size():
		var item: ProjectItem = ITEM_SCENE.instantiate()
		items_container.add_child(item)
		item.button_group = _button_group
		item.setup(_projects[i], i, _engine_display(int(_projects[i].engine_index)))
		_items.append(item)


func _on_item_pressed(button: BaseButton) -> void:
	var item := button as ProjectItem
	if item == null:
		return
	_selected_index = item.index
	_refresh_engine_selection()
	_update_actions()


func _on_add_pressed() -> void:
	add_requested.emit()


func _refresh_engine_selection() -> void:
	if _selected_index < 0 or _selected_index >= _projects.size():
		return
	var engine_index := int(_projects[_selected_index].engine_index)
	if engine_index >= 0 and engine_index < engine_selector.item_count:
		engine_selector.select(engine_index)


func _refresh_item_engine() -> void:
	if _selected_index < 0 or _selected_index >= _items.size():
		return
	_items[_selected_index].set_engine(
		_engine_display(int(_projects[_selected_index].engine_index))
	)


func _on_engine_selected(index: int) -> void:
	if _selected_index < 0 or _selected_index >= _projects.size():
		return
	_projects[_selected_index].engine_index = index
	_refresh_item_engine()
	engine_changed.emit(_selected_index, index)


func _emit_remove() -> void:
	if _selected_index >= 0:
		remove_requested.emit(_selected_index)


func _emit_launch() -> void:
	var engine_index := engine_selector.get_selected()
	if _selected_index >= 0 and engine_index >= 0:
		launch_requested.emit(_selected_index, engine_index)


func _engine_display(engine_index: int) -> String:
	if engine_index < 0 or engine_index >= _versions.size():
		return ""
	var version: Dictionary = _versions[engine_index]
	var version_name := str(version.name)
	var found := _version_regex.search(version_name)
	var base := found.get_string() if found != null else version_name
	if version.is_mono:
		base += " Mono"
	return base


func _update_actions() -> void:
	var has_project := _selected_index >= 0 and _selected_index < _projects.size()
	remove_button.disabled = not has_project
	launch_button.disabled = not has_project or _versions.is_empty()


func _update_empty_state() -> void:
	empty_state.visible = _projects.is_empty()
