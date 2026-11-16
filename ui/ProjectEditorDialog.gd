class_name ProjectEditorDialog
extends Window
## Lets the user pick, from the editor catalog, the script editor Godot uses for one project.

signal editor_saved(project_index: int, mode: String, path: String, flags: String)

var _project_index := -1
## One entry per selector item: {mode, path, flags}.
var _choices: Array[Dictionary] = []

@onready var title_label: Label = $Content/Root/TitleLabel
@onready var project_label: Label = $Content/Root/ProjectLabel
@onready var mode_label: Label = $Content/Root/ModeRow/ModeLabel
@onready var mode_selector: OptionButton = $Content/Root/ModeRow/ModeSelector
@onready var hint_label: Label = $Content/Root/HintLabel
@onready var cancel_button: Button = $Content/Root/Footer/CancelButton
@onready var save_button: Button = $Content/Root/Footer/SaveButton


func _ready() -> void:
	title = tr("PROJECT_EDITOR_TITLE")
	title_label.text = tr("PROJECT_EDITOR_TITLE")
	mode_label.text = tr("PROJECT_EDITOR_MODE_LABEL")
	cancel_button.text = tr("COMMON_CANCEL")
	save_button.text = tr("COMMON_SAVE")
	close_requested.connect(_on_cancel)
	cancel_button.pressed.connect(_on_cancel)
	save_button.pressed.connect(_on_save)


## current = {mode, path, flags} from project.godot; no override (inherit) preselects built-in.
func open_dialog(project_index: int, project_name: String, current: Dictionary, editors: Array[Dictionary]) -> void:
	_project_index = project_index
	project_label.text = project_name
	_build_choices(current, editors)
	mode_selector.select(_find_current(current))
	hint_label.text = tr("PROJECT_EDITOR_HINT")
	if editors.is_empty():
		hint_label.text += "\n" + tr("PROJECT_EDITOR_NO_EDITORS")
	popup_centered()
	mode_selector.grab_focus()


func _build_choices(current: Dictionary, editors: Array[Dictionary]) -> void:
	_choices.clear()
	mode_selector.clear()
	_add_choice(tr("PROJECT_EDITOR_MODE_BUILTIN"), EditorOverridesStore.MODE_BUILTIN, "", "")
	for editor: Dictionary in editors:
		_add_choice(str(editor.name), EditorOverridesStore.MODE_EXTERNAL, str(editor.path), str(editor.flags))
	# Keep a value written outside the catalog selectable so saving does not silently drop it.
	if str(current.mode) == EditorOverridesStore.MODE_EXTERNAL and _find_current(current) < 0:
		var label: String = tr("PROJECT_EDITOR_OTHER") % str(current.path)
		_add_choice(label, EditorOverridesStore.MODE_EXTERNAL, str(current.path), str(current.flags))


func _add_choice(label: String, choice_mode: String, path: String, flags: String) -> void:
	mode_selector.add_item(label)
	_choices.append({"mode": choice_mode, "path": path, "flags": flags})


func _find_current(current: Dictionary) -> int:
	var current_mode: String = str(current.mode)
	for i: int in _choices.size():
		var choice: Dictionary = _choices[i]
		if choice.mode != current_mode:
			continue
		if current_mode != EditorOverridesStore.MODE_EXTERNAL:
			return i
		if str(choice.path).simplify_path() == str(current.path).strip_edges().simplify_path():
			return i
	return -1 if current_mode == EditorOverridesStore.MODE_EXTERNAL else 0


func _on_save() -> void:
	var index: int = mode_selector.get_selected()
	if _project_index < 0 or index < 0 or index >= _choices.size():
		return
	var choice: Dictionary = _choices[index]
	editor_saved.emit(_project_index, str(choice.mode), str(choice.path), str(choice.flags))
	_project_index = -1
	hide()


func _on_cancel() -> void:
	_project_index = -1
	hide()
