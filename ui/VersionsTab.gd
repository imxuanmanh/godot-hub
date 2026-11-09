class_name VersionsTab
extends VBoxContainer

signal add_requested
signal remove_requested(index: int)
signal set_default_requested(index: int)
signal download_requested

const ITEM_SCENE := preload("res://ui/VersionItem.tscn")

var _versions: Array = []
var _items: Array = []
var _selected_index := -1
var _context_index := -1
var _button_group := ButtonGroup.new()

@onready var items_container: VBoxContainer = $ListStack/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Stack/EmptyState
@onready var count_label: Label = $Header/CountLabel
@onready var remove_button: Button = $Header/RemoveButton
@onready var set_default_button: Button = $Header/SetDefaultButton
@onready var add_button: Button = $Header/AddButton
@onready var download_button: Button = $Header/DownloadButton
@onready var context_menu: PopupMenu = $ContextMenu


func _ready() -> void:
	$Header/TitleBlock/Title.text = tr("VERSIONS_TITLE")
	$Header/TitleBlock/Subtitle.text = tr("VERSIONS_SUBTITLE")
	add_button.text = tr("VERSIONS_ADD")
	remove_button.text = tr("COMMON_REMOVE")
	set_default_button.text = tr("VERSIONS_SET_DEFAULT")
	download_button.text = tr("VERSIONS_DOWNLOAD")
	empty_state.text = tr("VERSIONS_EMPTY")
	count_label.text = tr("VERSIONS_COUNT") % _versions.size()

	add_button.pressed.connect(_on_add_pressed)
	download_button.pressed.connect(_on_download_pressed)
	remove_button.pressed.connect(_emit_remove)
	set_default_button.pressed.connect(_emit_set_default)
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	_update_actions()


func set_versions(new_versions: Array) -> void:
	_versions = new_versions
	_rebuild_items()
	count_label.text = tr("VERSIONS_COUNT") % _versions.size()
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
	for i in _versions.size():
		var item: VersionItem = ITEM_SCENE.instantiate()
		items_container.add_child(item)
		item.button_group = _button_group
		item.setup(_versions[i], i)
		item.context_requested.connect(_on_item_context_requested)
		_items.append(item)


func _on_item_pressed(button: BaseButton) -> void:
	var item := button as VersionItem
	if item == null:
		return
	_selected_index = item.index
	_update_actions()


func _select_item(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_selected_index = index
	_items[index].button_pressed = true
	_update_actions()


func _on_item_context_requested(index: int, screen_position: Vector2) -> void:
	_select_item(index)
	_context_index = index
	var is_default := index < _versions.size() and bool(_versions[index].is_default)
	context_menu.clear()
	context_menu.add_item(tr("VERSIONS_SET_DEFAULT"), 0)
	context_menu.set_item_disabled(0, is_default)
	context_menu.add_separator()
	context_menu.add_item(tr("COMMON_REMOVE"), 1)
	context_menu.position = Vector2i(screen_position)
	context_menu.popup()


func _on_context_menu_pressed(id: int) -> void:
	var index := _context_index
	_context_index = -1
	if index < 0:
		return
	if id == 0:
		set_default_requested.emit(index)
	elif id == 1:
		remove_requested.emit(index)


func _on_add_pressed() -> void:
	add_requested.emit()


func _on_download_pressed() -> void:
	download_requested.emit()


func _emit_remove() -> void:
	if _selected_index >= 0:
		remove_requested.emit(_selected_index)


func _emit_set_default() -> void:
	if _selected_index >= 0:
		set_default_requested.emit(_selected_index)


func _update_actions() -> void:
	var has_selection := _selected_index >= 0 and _selected_index < _versions.size()
	remove_button.disabled = not has_selection
	set_default_button.disabled = not has_selection


func _update_empty_state() -> void:
	empty_state.visible = _versions.is_empty()
