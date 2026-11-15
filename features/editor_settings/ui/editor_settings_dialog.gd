class_name EditorSettingsDialog
extends Window
## A sparse three-field form; repository writes happen only after submission.

signal submitted(values: Dictionary)

const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")

var _defaults: Dictionary = {}
var _draft: Dictionary = {}
var _project_mode: bool = false
var _updating: bool = false
var _toggles: Dictionary
var _sources: Dictionary
var _arguments_hint: String = ""

@onready var editor_choice: OptionButton = %EditorChoice
@onready var executable: LineEdit = %Executable
@onready var arguments: LineEdit = %Arguments
@onready var picker: FileDialog = $ExecutablePicker


func _ready() -> void:
	_toggles = {Keys.USE_EXTERNAL: %EditorOverride, Keys.EXEC_PATH: %PathOverride, Keys.EXEC_FLAGS: %FlagsOverride}
	_sources = {Keys.USE_EXTERNAL: %EditorSource, Keys.EXEC_PATH: %PathSource, Keys.EXEC_FLAGS: %FlagsSource}
	editor_choice.add_item(tr("EDITOR_SETTINGS_BUILTIN"))
	editor_choice.add_item(tr("EDITOR_SETTINGS_EXTERNAL"))
	editor_choice.add_item(tr("EDITOR_SETTINGS_SOURCE_NATIVE"))
	%EditorLabel.text = tr("EDITOR_SETTINGS_EDITOR_LABEL")
	%PathLabel.text = tr("EDITOR_SETTINGS_EXECUTABLE_LABEL")
	%FlagsLabel.text = tr("EDITOR_SETTINGS_ARGUMENTS_LABEL")
	%Hint.text = tr("EDITOR_SETTINGS_HINT")
	%ResetButton.text = tr("EDITOR_SETTINGS_RESET_ALL")
	%BrowseButton.text = tr("COMMON_CHOOSE")
	%SaveButton.text = tr("EDITOR_SETTINGS_SAVE")
	%CancelButton.text = tr("COMMON_CANCEL")
	for key: String in _toggles:
		_toggles[key].text = tr("EDITOR_SETTINGS_OVERRIDE")
		_toggles[key].tooltip_text = tr("EDITOR_SETTINGS_USE_DEFAULT_HINT")
		_toggles[key].toggled.connect(_on_override_toggled.bind(key))
	editor_choice.item_selected.connect(_on_editor_selected)
	executable.text_changed.connect(_on_text_changed.bind(Keys.EXEC_PATH))
	arguments.text_changed.connect(_on_text_changed.bind(Keys.EXEC_FLAGS))
	%BrowseButton.pressed.connect(func() -> void: picker.popup_centered())
	picker.file_selected.connect(_on_executable_selected)
	%ResetButton.pressed.connect(func() -> void: _draft.clear(); _refresh())
	%SaveButton.pressed.connect(func() -> void: submitted.emit(_draft.duplicate(true)))
	%CancelButton.pressed.connect(hide)
	close_requested.connect(hide)


func present(defaults: Dictionary, overrides: Dictionary, project_mode: bool, project_name: String = "", arguments_hint: String = "") -> void:
	_defaults = defaults.duplicate(true) if project_mode else {}
	_draft = overrides.duplicate(true) if project_mode else defaults.duplicate(true)
	_project_mode = project_mode
	_arguments_hint = arguments_hint
	editor_choice.set_item_disabled(2, true)
	title = tr("EDITOR_SETTINGS_PROJECT_TITLE") % project_name if project_mode else tr("EDITOR_SETTINGS_DEFAULT_TITLE")
	_refresh()
	popup_centered()


func _refresh() -> void:
	_updating = true
	var effective: Dictionary = EditorSettingsResolver.resolve(_defaults, _draft)
	var values: Dictionary = effective.values
	var external: bool = values.get(Keys.USE_EXTERNAL, false)
	editor_choice.select(int(external) if values.has(Keys.USE_EXTERNAL) else 2)
	executable.text = values.get(Keys.EXEC_PATH, "")
	arguments.text = values.get(Keys.EXEC_FLAGS, "")
	executable.placeholder_text = tr("EDITOR_SETTINGS_NATIVE_VALUE")
	arguments.placeholder_text = tr("EDITOR_SETTINGS_NATIVE_VALUE")
	for key: String in _toggles:
		_toggles[key].visible = _project_mode
		_toggles[key].set_pressed_no_signal(_draft.has(key))
		var source: String = effective.sources.get(key, "Native")
		if not _project_mode and _draft.has(key):
			source = "Default"
		_sources[key].text = tr("EDITOR_SETTINGS_SOURCE_" + source.to_upper())
	editor_choice.disabled = _project_mode and not _draft.has(Keys.USE_EXTERNAL)
	executable.editable = external and (not _project_mode or _draft.has(Keys.EXEC_PATH))
	arguments.editable = external and (not _project_mode or _draft.has(Keys.EXEC_FLAGS))
	%BrowseButton.disabled = not executable.editable
	%ResetButton.visible = _project_mode
	%Status.text = tr("EDITOR_SETTINGS_USING_DEFAULT") if _project_mode and _draft.is_empty() else ""
	_updating = false


func _on_override_toggled(enabled: bool, key: String) -> void:
	if _updating:
		return
	if enabled:
		var fallback: Variant = false if key == Keys.USE_EXTERNAL else (_arguments_hint if key == Keys.EXEC_FLAGS else "")
		_draft[key] = EditorSettingsResolver.resolve(_defaults, _draft).values.get(key, fallback)
	else:
		_draft.erase(key)
	_refresh()


func _on_editor_selected(index: int) -> void:
	if _updating:
		return
	if index == 2:
		_draft.erase(Keys.USE_EXTERNAL)
	else:
		_draft[Keys.USE_EXTERNAL] = index == 1
	_refresh()


func _on_text_changed(value: String, key: String) -> void:
	if not _updating:
		_draft[key] = value
		_sources[key].text = tr("EDITOR_SETTINGS_SOURCE_PROJECT" if _project_mode else "EDITOR_SETTINGS_SOURCE_DEFAULT")


func _on_executable_selected(path: String) -> void:
	_draft[Keys.EXEC_PATH] = path
	_refresh()
