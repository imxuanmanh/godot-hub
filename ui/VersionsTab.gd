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
var _button_group := ButtonGroup.new()

@onready var items_container: VBoxContainer = $ListStack/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Stack/EmptyState
@onready var count_label: Label = $Toolbar/CountLabel
@onready var remove_button: Button = $Toolbar/RemoveButton
@onready var set_default_button: Button = $Toolbar/SetDefaultButton


func _ready() -> void:
	$Header/AddButton.pressed.connect(_on_add_pressed)
	$Toolbar/DownloadButton.pressed.connect(_on_download_pressed)
	remove_button.pressed.connect(_emit_remove)
	set_default_button.pressed.connect(_emit_set_default)
	_update_actions()


func set_versions(new_versions: Array) -> void:
	_versions = new_versions
	_rebuild_items()
	count_label.text = "%d phiên bản" % _versions.size()
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
		_items.append(item)


func _on_item_pressed(button: BaseButton) -> void:
	var item := button as VersionItem
	if item == null:
		return
	_selected_index = item.index
	_update_actions()


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
