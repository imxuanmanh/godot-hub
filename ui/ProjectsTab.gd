class_name ProjectsTab
extends VBoxContainer

signal add_requested
signal remove_requested(index: int)
signal launch_requested(project_index: int, engine_index: int)
signal engine_changed(project_index: int, engine_index: int)
signal pin_toggled(project_index: int)
signal tags_requested(project_index: int)
signal editor_config_requested(project_index: int)
signal open_folder_requested(project_index: int)

const ITEM_SCENE := preload("res://ui/ProjectItem.tscn")
const BUILD_STANDARD := "standard"
const BUILD_MONO := "mono"

var _projects: Array = []
var _versions: Array = []
var _items: Array[ProjectItem] = []
var _visible_indices: Array[int] = []
var _search_query := ""
var _tag_filter := ""
var _version_filter := -1
var _build_filter := ""
var _selected_index := -1
var _context_index := -1
var _button_group := ButtonGroup.new()
var _version_regex := RegEx.new()

@onready var items_container: VBoxContainer = $ListStack/Body/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Body/Stack/EmptyState
@onready var scroll: ScrollContainer = $ListStack/Body/Stack/Scroll
@onready var header_row: MarginContainer = $ListStack/Body/HeaderRow

var _header_margin_right := 0
@onready var filter_button: Button = $Header/FilterButton
@onready var filter_bar: HBoxContainer = $Header/FilterBar
@onready var header_spacer: Control = $Header/Spacer
@onready var search_edit: LineEdit = $Header/FilterBar/SearchEdit
@onready var tag_selector: OptionButton = $Header/FilterBar/TagSelector
@onready var version_selector: OptionButton = $Header/FilterBar/VersionSelector
@onready var type_selector: OptionButton = $Header/FilterBar/TypeSelector
@onready var clear_filter_button: Button = $Header/FilterBar/ClearButton
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
	filter_button.text = tr("PROJECTS_FILTER")
	search_edit.placeholder_text = tr("PROJECTS_SEARCH_PLACEHOLDER")
	clear_filter_button.tooltip_text = tr("PROJECTS_FILTER_CLEAR")
	$ListStack/Body/HeaderRow/Columns/NameHeader.text = tr("PROJECTS_COL_NAME")
	$ListStack/Body/HeaderRow/Columns/PathHeader.text = tr("PROJECTS_COL_PATH")
	$ListStack/Body/HeaderRow/Columns/VersionHeader.text = tr("PROJECTS_COL_VERSION")
	$ListStack/Body/HeaderRow/Columns/TagsHeader.text = tr("PROJECTS_COL_TAGS")
	_rebuild_filter_options()

	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_emit_remove)
	launch_button.pressed.connect(_emit_launch)
	engine_selector.item_selected.connect(_on_engine_selected)
	search_edit.text_changed.connect(_on_search_changed)
	filter_button.toggled.connect(_on_filter_toggled)
	tag_selector.item_selected.connect(_on_tag_selected)
	version_selector.item_selected.connect(_on_version_selected)
	type_selector.item_selected.connect(_on_type_selected)
	clear_filter_button.pressed.connect(_clear_filters)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	_header_margin_right = header_row.get_theme_constant("margin_right")
	scroll.get_v_scroll_bar().visibility_changed.connect(_sync_header_pad)
	scroll.resized.connect(_sync_header_pad)
	_sync_header_pad()
	_update_actions()
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
	_rebuild_filter_options()
	_update_actions()


func set_projects(new_projects: Array) -> void:
	_projects = new_projects
	_rebuild_filter_options()
	_rebuild_items()
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
	_visible_indices = ProjectFilter.visible_indices(
		_projects, _search_query, _versions, _tag_filter, _version_filter, _build_filter
	)
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
		item.open_folder_requested.connect(_on_item_open_folder_requested)
		_items.append(item)
	_selected_index = -1
	if keep >= 0 and _item_for(keep) != null:
		_select_item(keep)
	_sync_header_pad.call_deferred()


## Keeps the header columns aligned with rows, which lose the scrollbar width when it appears.
func _sync_header_pad() -> void:
	var scroll_bar := scroll.get_v_scroll_bar()
	var inset := scroll_bar.size.x if scroll_bar.visible else 0.0
	header_row.add_theme_constant_override("margin_right", _header_margin_right + int(inset))


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
	context_menu.add_item(tr("PROJECTS_OPEN_FOLDER"), 5)
	context_menu.add_item(tr("PROJECTS_UNPIN") if _is_pinned(index) else tr("PROJECTS_PIN"), 1)
	context_menu.add_item(tr("PROJECTS_EDIT_TAGS"), 2)
	context_menu.add_item(tr("PROJECTS_EDITOR_CONFIG"), 4)
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
	elif id == 4:
		editor_config_requested.emit(index)
	elif id == 5:
		_on_item_open_folder_requested(index)


func _on_item_open_folder_requested(project_index: int) -> void:
	_select_item(project_index)
	open_folder_requested.emit(project_index)


func _on_add_pressed() -> void:
	add_requested.emit()


func _on_search_changed(text: String) -> void:
	_search_query = text
	_apply_filters()


func _on_filter_toggled(pressed: bool) -> void:
	filter_bar.visible = pressed
	header_spacer.visible = not pressed
	if pressed:
		search_edit.grab_focus()


func _on_tag_selected(index: int) -> void:
	_tag_filter = "" if index <= 0 else tag_selector.get_item_text(index).trim_prefix("#")
	_apply_filters()


func _on_version_selected(index: int) -> void:
	_version_filter = index - 1
	_apply_filters()


func _on_type_selected(index: int) -> void:
	_build_filter = ""
	if index == 1:
		_build_filter = BUILD_STANDARD
	elif index == 2:
		_build_filter = BUILD_MONO
	_apply_filters()


func _clear_filters() -> void:
	_search_query = ""
	_tag_filter = ""
	_version_filter = -1
	_build_filter = ""
	search_edit.clear()
	tag_selector.select(0)
	version_selector.select(0)
	type_selector.select(0)
	_apply_filters()


func _apply_filters() -> void:
	filter_button.text = _filter_button_text()
	_rebuild_items()
	_update_empty_state()


func _filter_button_text() -> String:
	var count := _active_filter_count()
	return tr("PROJECTS_FILTER_ACTIVE") % count if count > 0 else tr("PROJECTS_FILTER")


func _active_filter_count() -> int:
	var count := 0
	if not _search_query.strip_edges().is_empty():
		count += 1
	if not _tag_filter.is_empty():
		count += 1
	if _version_filter >= 0:
		count += 1
	if not _build_filter.is_empty():
		count += 1
	return count


func _rebuild_filter_options() -> void:
	_rebuild_tag_options()
	_rebuild_version_options()
	_rebuild_type_options()


func _rebuild_tag_options() -> void:
	var keep := _tag_filter
	tag_selector.clear()
	tag_selector.add_item(tr("PROJECTS_FILTER_ALL_TAGS"))
	var tags: Array[String] = []
	var seen := {}
	for project in _projects:
		for value in project.get("tags", []):
			var tag := str(value).strip_edges()
			var key := tag.to_lower()
			if tag.is_empty() or seen.has(key):
				continue
			seen[key] = true
			tags.append(tag)
	tags.sort_custom(_tag_before)
	_tag_filter = ""
	for tag in tags:
		tag_selector.add_item("#" + tag)
		if tag.to_lower() == keep.to_lower():
			tag_selector.select(tag_selector.item_count - 1)
			_tag_filter = tag
	if _tag_filter.is_empty():
		tag_selector.select(0)


func _tag_before(a: String, b: String) -> bool:
	return a.to_lower() < b.to_lower()


func _rebuild_version_options() -> void:
	var keep := _version_filter
	version_selector.clear()
	version_selector.add_item(tr("PROJECTS_FILTER_ALL_VERSIONS"))
	_version_filter = -1
	for i in _versions.size():
		version_selector.add_item(_engine_display(i))
		if i == keep:
			version_selector.select(version_selector.item_count - 1)
			_version_filter = i
	if _version_filter < 0:
		version_selector.select(0)


func _rebuild_type_options() -> void:
	type_selector.clear()
	type_selector.add_item(tr("PROJECTS_FILTER_ALL_TYPES"))
	type_selector.add_item(tr("PROJECTS_FILTER_STANDARD"))
	type_selector.add_item(tr("PROJECTS_FILTER_MONO"))
	if _build_filter == BUILD_STANDARD:
		type_selector.select(1)
	elif _build_filter == BUILD_MONO:
		type_selector.select(2)
	else:
		type_selector.select(0)


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


func _update_empty_state() -> void:
	if _visible_indices.is_empty() and not _projects.is_empty():
		empty_state.text = tr("PROJECTS_NO_RESULTS")
	else:
		empty_state.text = tr("PROJECTS_EMPTY")
	empty_state.visible = _visible_indices.is_empty()
