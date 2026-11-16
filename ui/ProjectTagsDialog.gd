class_name ProjectTagsDialog
extends Window

signal tags_submitted(project_index: int, tags: Array[String])

const ROW_SEPARATION := 6
const REMOVE_BUTTON_WIDTH := 28.0
const REMOVE_GLYPH := "×"

var _project_index := -1
var _tags: Array[String] = []

@onready var title_label: Label = $Content/Root/TitleLabel
@onready var project_label: Label = $Content/Root/ProjectLabel
@onready var hint_label: Label = $Content/Root/HintLabel
@onready var tag_list: VBoxContainer = $Content/Root/TagsScroll/TagList
@onready var empty_label: Label = $Content/Root/TagsScroll/TagList/EmptyLabel
@onready var tag_input: LineEdit = $Content/Root/AddRow/TagInput
@onready var add_button: Button = $Content/Root/AddRow/AddButton
@onready var cancel_button: Button = $Content/Root/Footer/CancelButton
@onready var save_button: Button = $Content/Root/Footer/SaveButton


func _ready() -> void:
	title_label.text = tr("PROJECT_TAGS_TITLE")
	hint_label.text = tr("PROJECT_TAGS_HINT")
	empty_label.text = tr("PROJECT_TAGS_EMPTY")
	tag_input.placeholder_text = tr("PROJECT_TAGS_PLACEHOLDER")
	add_button.text = tr("PROJECT_TAGS_ADD")
	cancel_button.text = tr("COMMON_CANCEL")
	save_button.text = tr("COMMON_SAVE")

	close_requested.connect(_on_cancel)
	cancel_button.pressed.connect(_on_cancel)
	save_button.pressed.connect(_on_save)
	add_button.pressed.connect(_on_add_tag)
	tag_input.text_submitted.connect(_on_tag_submitted)


func open_dialog(project_index: int, project_name: String, tags: Array) -> void:
	_project_index = project_index
	project_label.text = project_name
	_tags.clear()
	for tag in tags:
		var text := _normalize(str(tag))
		if not text.is_empty() and _tag_position(text) < 0:
			_tags.append(text)
	tag_input.clear()
	_rebuild_rows()
	popup_centered()
	tag_input.grab_focus()


func _on_tag_submitted(_text: String) -> void:
	_on_add_tag()


func _on_add_tag() -> void:
	for part in tag_input.text.split(",", false):
		var text := _normalize(part)
		if not text.is_empty() and _tag_position(text) < 0:
			_tags.append(text)
	tag_input.clear()
	_rebuild_rows()
	tag_input.grab_focus()


func _on_save() -> void:
	if _project_index < 0:
		return
	var result: Array[String] = _tags.duplicate()
	tags_submitted.emit(_project_index, result)
	_project_index = -1
	hide()


func _on_cancel() -> void:
	_project_index = -1
	hide()


func _rebuild_rows() -> void:
	for child in tag_list.get_children():
		if child == empty_label:
			continue
		tag_list.remove_child(child)
		child.queue_free()
	empty_label.visible = _tags.is_empty()
	for tag in _tags:
		tag_list.add_child(_create_row(tag))


func _create_row(tag: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	var label := Label.new()
	label.text = "#" + tag
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)
	var remove_button := Button.new()
	remove_button.text = REMOVE_GLYPH
	remove_button.flat = true
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	remove_button.custom_minimum_size = Vector2(REMOVE_BUTTON_WIDTH, 0)
	remove_button.tooltip_text = tr("PROJECT_TAGS_REMOVE")
	remove_button.pressed.connect(_on_remove_tag.bind(tag))
	row.add_child(remove_button)
	return row


func _on_remove_tag(tag: String) -> void:
	var index := _tag_position(tag)
	if index >= 0:
		_tags.remove_at(index)
	_rebuild_rows()


func _normalize(value: String) -> String:
	return value.strip_edges().trim_prefix("#").strip_edges()


func _tag_position(tag: String) -> int:
	var needle := tag.to_lower()
	for i in _tags.size():
		if _tags[i].to_lower() == needle:
			return i
	return -1
