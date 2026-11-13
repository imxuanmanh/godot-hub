class_name ProjectTagsDialog
extends Window

signal tags_submitted(project_index: int, tags: Array[String])

var _project_index := -1

@onready var title_label: Label = $Content/Root/TitleLabel
@onready var project_label: Label = $Content/Root/ProjectLabel
@onready var hint_label: Label = $Content/Root/HintLabel
@onready var tags_edit: LineEdit = $Content/Root/TagsEdit
@onready var cancel_button: Button = $Content/Root/Footer/CancelButton
@onready var save_button: Button = $Content/Root/Footer/SaveButton


func _ready() -> void:
	title_label.text = tr("PROJECT_TAGS_TITLE")
	hint_label.text = tr("PROJECT_TAGS_HINT")
	tags_edit.placeholder_text = tr("PROJECT_TAGS_PLACEHOLDER")
	cancel_button.text = tr("COMMON_CANCEL")
	save_button.text = tr("COMMON_SAVE")

	close_requested.connect(_on_cancel)
	cancel_button.pressed.connect(_on_cancel)
	save_button.pressed.connect(_on_save)
	tags_edit.text_submitted.connect(_on_text_submitted)


func open_dialog(project_index: int, project_name: String, tags: Array) -> void:
	_project_index = project_index
	project_label.text = project_name
	var parts := PackedStringArray()
	for tag in tags:
		parts.append(str(tag))
	tags_edit.text = ", ".join(parts)
	popup_centered()
	tags_edit.grab_focus()
	tags_edit.caret_column = tags_edit.text.length()


func _on_text_submitted(_text: String) -> void:
	_on_save()


func _on_save() -> void:
	if _project_index < 0:
		return
	tags_submitted.emit(_project_index, ProjectFilter.parse_tags(tags_edit.text))
	_project_index = -1
	hide()


func _on_cancel() -> void:
	_project_index = -1
	hide()
