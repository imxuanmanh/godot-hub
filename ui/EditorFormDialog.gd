class_name EditorFormDialog
extends Window
## Add/edit form for one catalog editor; validation of the data lives in EditorCatalog.

signal submitted(index: int, editor_name: String, path: String, flags: String)

var _index := -1

@onready var title_label: Label = $Content/Root/TitleLabel
@onready var name_label: Label = $Content/Root/NameRow/NameLabel
@onready var name_edit: LineEdit = $Content/Root/NameRow/NameEdit
@onready var path_label: Label = $Content/Root/PathRow/PathLabel
@onready var path_edit: LineEdit = $Content/Root/PathRow/PathEdit
@onready var browse_button: Button = $Content/Root/PathRow/BrowseButton
@onready var args_label: Label = $Content/Root/ArgsRow/ArgsLabel
@onready var args_edit: LineEdit = $Content/Root/ArgsRow/ArgsEdit
@onready var reset_button: Button = $Content/Root/ArgsRow/ResetButton
@onready var hint_label: Label = $Content/Root/HintLabel
@onready var cancel_button: Button = $Content/Root/Footer/CancelButton
@onready var save_button: Button = $Content/Root/Footer/SaveButton
@onready var file_dialog: FileDialog = $EditorFileDialog


func _ready() -> void:
	name_label.text = tr("EDITOR_FORM_NAME_LABEL")
	path_label.text = tr("PROJECT_EDITOR_PATH_LABEL")
	args_label.text = tr("PROJECT_EDITOR_ARGS_LABEL")
	reset_button.text = tr("EDITOR_FORM_RESET")
	hint_label.text = tr("EDITOR_FORM_HINT")
	browse_button.text = tr("COMMON_CHOOSE")
	cancel_button.text = tr("COMMON_CANCEL")
	save_button.text = tr("COMMON_SAVE")
	file_dialog.title = tr("PROJECT_EDITOR_PATH_LABEL")
	close_requested.connect(hide)
	cancel_button.pressed.connect(hide)
	save_button.pressed.connect(_on_save)
	browse_button.pressed.connect(func() -> void: file_dialog.popup_centered())
	reset_button.pressed.connect(_reset_flags)
	file_dialog.file_selected.connect(_on_file_selected)
	name_edit.text_changed.connect(func(_text: String) -> void: _update_save())
	path_edit.text_changed.connect(func(_text: String) -> void: _update_save())
	args_edit.text_submitted.connect(func(_text: String) -> void: _on_save())


## index < 0 opens an empty "add" form; otherwise edits that entry.
func open_form(index: int, editor: Dictionary) -> void:
	_index = index
	var heading: String = tr("EDITOR_FORM_ADD_TITLE") if index < 0 else tr("EDITOR_FORM_EDIT_TITLE")
	title = heading
	title_label.text = heading
	name_edit.text = str(editor.get("name", ""))
	path_edit.text = str(editor.get("path", ""))
	args_edit.text = str(editor.get("flags", EditorOverridesStore.DEFAULT_FLAGS))
	_update_save()
	popup_centered()
	name_edit.grab_focus()


func _on_file_selected(path: String) -> void:
	path_edit.text = path
	if name_edit.text.strip_edges().is_empty():
		var preset_name: String = EditorPresets.display_name(path)
		name_edit.text = preset_name if not preset_name.is_empty() else path.get_file().get_basename()
	var detected: String = EditorPresets.flags_for_executable(path)
	if not detected.is_empty():
		args_edit.text = detected
	_update_save()


func _reset_flags() -> void:
	var detected: String = EditorPresets.flags_for_executable(path_edit.text)
	args_edit.text = detected if not detected.is_empty() else EditorOverridesStore.DEFAULT_FLAGS


func _update_save() -> void:
	reset_button.disabled = path_edit.text.strip_edges().is_empty()
	save_button.disabled = name_edit.text.strip_edges().is_empty() or path_edit.text.strip_edges().is_empty()


func _on_save() -> void:
	if save_button.disabled:
		return
	submitted.emit(_index, name_edit.text, path_edit.text, args_edit.text)
	hide()
