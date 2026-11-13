class_name ProjectsTab
extends VBoxContainer

signal add_requested
signal remove_requested(index: int)
signal launch_requested(project_index: int, engine_index: int)
signal engine_changed(project_index: int, engine_index: int)
signal pin_toggled(project_index: int)
signal tags_requested(project_index: int)

const ITEM_SCENE := preload("res://ui/ProjectItem.tscn")

var _projects: Array = []
var _versions: Array = []
var _items: Array[ProjectItem] = []
var _visible_indices: Array[int] = []
var _search_query := ""
var _selected_index := -1
var _context_index := -1
var _button_group := ButtonGroup.new()
var _version_regex := RegEx.new()

@onready var items_container: VBoxContainer = $ListStack/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Stack/EmptyState
@onready var count_label: Label = $Header/CountLabel
@onready var search_edit: LineEdit = $Header/SearchEdit
@onready var remove_button: Button = $Header/RemoveButton
@onready var engine_selector: OptionButton = $LaunchPanel/Content/EngineSelector
@onready var engine_label: Label = $LaunchPanel/Content/EngineLabel
@onready var launch_button: Button = $LaunchPanel/Content/LaunchButton
@onready var add_button: Button = $Header/AddButton
@onready var context_menu: PopupMenu = $ContextMenu


func _ready() -> void:
	_version_regex.compile("v?(\\d+\\.\\d+(?:\\.\\d+)?)")
	$Header/TitleBlock/Title.text = tr("PROJECTS_TITLE")
	$Header/TitleBlock/Subtitle.text = tr("PROJECTS_SUBTITLE")
	add_button.text = tr("PROJECTS_ADD")
	remove_button.text = tr("COMMON_REMOVE")
	engine_label.text = tr("PROJECTS_ENGINE_LABEL")
	launch_button.text = tr("PROJECTS_LAUNCH")
	search_edit.placeholder_text = tr("PROJECTS_SEARCH_PLACEHOLDER")

	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_emit_remove)
	launch_button.pressed.connect(_emit_launch)
	engine_selector.item_selected.connect(_on_engine_selected)
	search_edit.text_changed.connect(_on_search_changed)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	_update_actions()
	_update_count()
	_update_empty_state()


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
	_update_count()
	_update_actions()
	_update_empty_state()


func get_selected_index() -> int:
	return _selected_index


func _rebuild_items() -> void:
	var keep := _selected_index
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()
	_items.clear()
	_visible_indices = ProjectFilter.visible_indices(_projects, _search_query)
	_button_group = ButtonGroup.new()
	_button_group.pressed.connect(_on_item_pressed)
	for i in _visible_indices:
		var item: ProjectItem = ITEM_SCENE.instantiate()
		items_container.add_child(item)
		item.button_group = _button_group
		var engine_index := int(_projects[i].engine_index)
		item.setup(_projects[i], i, _engine_display(engine_index), _engine_is_mono(engine_index))
		item.double_clicked.connect(_on_item_double_clicked)
		item.context_requested.connect(_on_item_context_requested)
		_items.append(item)
	_selected_index = -1
	if keep >= 0 and _item_for(keep) != null:
		_select_item(keep)


func _item_for(project_index: int) -> ProjectItem:
	for item in _items:
		if item.index == project_index:
			return item
	return null


func _on_item_pressed(button: BaseButton) -> void:
	var item := button as ProjectItem
	if item == null:
		return
	_selected_index = item.index
	_refresh_engine_selection()
	_update_actions()


func _select_item(index: int) -> void:
	var item := _item_for(index)
	if item == null:
		return
	_selected_index = index
	item.button_pressed = true
	_refresh_engine_selection()
	_update_actions()


func _on_item_double_clicked(index: int) -> void:
	_select_item(index)
	_launch_project(index)


func _launch_project(index: int) -> void:
	if index < 0 or index >= _projects.size() or _versions.is_empty():
		return
	var engine_index := int(_projects[index].engine_index)
	if engine_index < 0 or engine_index >= _versions.size():
		return
	launch_requested.emit(index, engine_index)


func _on_item_context_requested(index: int, screen_position: Vector2) -> void:
	_select_item(index)
	_context_index = index
	context_menu.clear()
	context_menu.add_item(tr("PROJECTS_LAUNCH"), 0)
	context_menu.add_item(tr("PROJECTS_UNPIN") if _is_pinned(index) else tr("PROJECTS_PIN"), 1)
	context_menu.add_item(tr("PROJECTS_EDIT_TAGS"), 2)
	context_menu.add_separator()
	context_menu.add_item(tr("COMMON_REMOVE"), 3)
	context_menu.set_item_disabled(0, _versions.is_empty())
	context_menu.position = Vector2i(screen_position)
	context_menu.popup()


func _on_context_menu_pressed(id: int) -> void:
	var index := _context_index
	_context_index = -1
	if index < 0:
		return
	if id == 0:
		_launch_project(index)
	elif id == 1:
		pin_toggled.emit(index)
	elif id == 2:
		tags_requested.emit(index)
	elif id == 3:
		remove_requested.emit(index)


func _on_add_pressed() -> void:
	add_requested.emit()


func _on_search_changed(text: String) -> void:
	_search_query = text
	_rebuild_items()
	_update_count()
	_update_empty_state()


func _refresh_engine_selection() -> void:
	if _selected_index < 0 or _selected_index >= _projects.size():
		return
	var engine_index := int(_projects[_selected_index].engine_index)
	if engine_index >= 0 and engine_index < engine_selector.item_count:
		engine_selector.select(engine_index)


func _refresh_item_engine() -> void:
	var item := _item_for(_selected_index)
	if item == null:
		return
	var engine_index := int(_projects[_selected_index].engine_index)
	item.set_engine(_engine_display(engine_index), _engine_is_mono(engine_index))


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
	base += " Mono" if version.is_mono else " Standard"
	return base


func _engine_is_mono(engine_index: int) -> bool:
	if engine_index < 0 or engine_index >= _versions.size():
		return false
	return bool(_versions[engine_index].is_mono)


func _is_pinned(index: int) -> bool:
	if index < 0 or index >= _projects.size():
		return false
	return bool(_projects[index].get("pinned", false))


func _update_actions() -> void:
	var has_project := _selected_index >= 0 and _selected_index < _projects.size()
	remove_button.disabled = not has_project
	launch_button.disabled = not has_project or _versions.is_empty()


func _update_count() -> void:
	if _search_query.strip_edges().is_empty():
		count_label.text = tr("PROJECTS_COUNT") % _projects.size()
	else:
		count_label.text = tr("PROJECTS_COUNT_FILTERED") % [_visible_indices.size(), _projects.size()]


func _update_empty_state() -> void:
	if _visible_indices.is_empty() and not _projects.is_empty():
		empty_state.text = tr("PROJECTS_NO_RESULTS")
	else:
		empty_state.text = tr("PROJECTS_EMPTY")
	empty_state.visible = _visible_indices.is_empty()
