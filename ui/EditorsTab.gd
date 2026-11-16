class_name EditorsTab
extends VBoxContainer
## Lists catalog editors and lets the user add, edit or remove them.

signal error_occurred(result: Dictionary)
## Emitted after an editor is removed from the catalog, with its executable path.
signal editor_removed(editor_path: String)

const ITEM_SCENE := preload("res://ui/EditorItem.tscn")
const MENU_EDIT: int = 0
const MENU_REMOVE: int = 1

var _catalog: EditorCatalog
var _editors: Array[Dictionary] = []
var _selected_index := -1
var _context_index := -1

@onready var items_container: VBoxContainer = $ListStack/Stack/Scroll/Items
@onready var empty_state: Label = $ListStack/Stack/EmptyState
@onready var count_label: Label = $Header/CountLabel
@onready var add_button: Button = $Header/AddButton
@onready var edit_button: Button = $Header/EditButton
@onready var remove_button: Button = $Header/RemoveButton
@onready var context_menu: PopupMenu = $ContextMenu
@onready var form_dialog: EditorFormDialog = $EditorFormDialog
@onready var confirm_dialog: ConfirmationDialog = $RemoveConfirmDialog


func _ready() -> void:
	$Header/TitleBlock/Title.text = tr("EDITORS_TITLE")
	$Header/TitleBlock/Subtitle.text = tr("EDITORS_SUBTITLE")
	add_button.text = tr("EDITORS_ADD")
	edit_button.text = tr("COMMON_EDIT")
	remove_button.text = tr("COMMON_REMOVE")
	empty_state.text = tr("EDITORS_EMPTY")
	confirm_dialog.title = tr("EDITORS_REMOVE_TITLE")
	confirm_dialog.ok_button_text = tr("COMMON_REMOVE")
	confirm_dialog.cancel_button_text = tr("COMMON_CANCEL")
	add_button.pressed.connect(func() -> void: form_dialog.open_form(-1, {}))
	edit_button.pressed.connect(func() -> void: _edit(_selected_index))
	remove_button.pressed.connect(func() -> void: _confirm_remove(_selected_index))
	context_menu.id_pressed.connect(_on_context_menu_pressed)
	form_dialog.submitted.connect(_on_form_submitted)
	confirm_dialog.confirmed.connect(_on_remove_confirmed)
	_rebuild()


func setup(catalog: EditorCatalog) -> void:
	_catalog = catalog
	if is_node_ready():
		_rebuild()


func _rebuild() -> void:
	_editors.clear()
	if _catalog != null:
		_editors = _catalog.list()
	_selected_index = -1
	for child: Node in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	for i: int in _editors.size():
		var item: EditorItem = ITEM_SCENE.instantiate()
		items_container.add_child(item)
		item.button_group = group
		item.setup(_editors[i], i)
		item.pressed.connect(_select.bind(i))
		item.activated.connect(_edit)
		item.context_requested.connect(_on_item_context_requested)
	count_label.text = tr("EDITORS_COUNT") % _editors.size()
	empty_state.visible = _editors.is_empty()
	_update_actions()


func _select(index: int) -> void:
	_selected_index = index
	_update_actions()


func _edit(index: int) -> void:
	if index >= 0 and index < _editors.size():
		form_dialog.open_form(index, _editors[index])


func _confirm_remove(index: int) -> void:
	if index < 0 or index >= _editors.size():
		return
	_context_index = index
	confirm_dialog.dialog_text = tr("EDITORS_REMOVE_CONFIRM") % str(_editors[index].name)
	confirm_dialog.popup_centered()


func _on_remove_confirmed() -> void:
	var index := _context_index
	_context_index = -1
	if index < 0 or index >= _editors.size():
		return
	var removed_path: String = str(_editors[index].path)
	var result: Dictionary = _catalog.remove(index)
	_apply(result)
	if result.ok:
		editor_removed.emit(removed_path)


func _on_form_submitted(index: int, editor_name: String, path: String, flags: String) -> void:
	_apply(_catalog.upsert(index, editor_name, path, flags))


func _apply(result: Dictionary) -> void:
	if not result.ok:
		error_occurred.emit(result)
	_rebuild()


func _on_item_context_requested(index: int, screen_position: Vector2) -> void:
	var item: EditorItem = items_container.get_child(index)
	item.button_pressed = true
	_select(index)
	_context_index = index
	context_menu.clear()
	context_menu.add_item(tr("COMMON_EDIT"), MENU_EDIT)
	context_menu.add_separator()
	context_menu.add_item(tr("COMMON_REMOVE"), MENU_REMOVE)
	context_menu.position = Vector2i(screen_position)
	context_menu.popup()


func _on_context_menu_pressed(id: int) -> void:
	if id == MENU_EDIT:
		_edit(_context_index)
	elif id == MENU_REMOVE:
		_confirm_remove(_context_index)


func _update_actions() -> void:
	var has_selection := _selected_index >= 0 and _selected_index < _editors.size()
	edit_button.disabled = not has_selection
	remove_button.disabled = not has_selection
