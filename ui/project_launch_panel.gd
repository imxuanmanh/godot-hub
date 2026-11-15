class_name ProjectLaunchPanel
extends PanelContainer
## Displays launch controls; project selection and persistence belong to the parent.

signal launch_requested
signal engine_changed(index: int)
signal settings_requested

var busy: bool = false
var _has_project: bool = false

@onready var engine_selector: OptionButton = %EngineSelector
@onready var launch_button: Button = %LaunchButton
@onready var settings_button: Button = %SettingsButton


func _ready() -> void:
	%EngineLabel.text = tr("PROJECTS_ENGINE_LABEL")
	launch_button.text = tr("PROJECTS_LAUNCH")
	settings_button.text = tr("EDITOR_SETTINGS_PROJECT_BUTTON")
	launch_button.pressed.connect(func() -> void: launch_requested.emit())
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	engine_selector.item_selected.connect(func(index: int) -> void: engine_changed.emit(index))


func set_versions(versions: Array) -> void:
	engine_selector.clear()
	for version: Dictionary in versions:
		engine_selector.add_item(str(version.name) + (" [Mono]" if version.is_mono else " [Standard]"))
	_update_actions()


func set_selection(has_project: bool, engine_index: int) -> void:
	_has_project = has_project
	if engine_index >= 0 and engine_index < engine_selector.item_count:
		engine_selector.select(engine_index)
	_update_actions()


func set_busy(value: bool) -> void:
	busy = value
	_update_actions()


func _update_actions() -> void:
	engine_selector.disabled = busy or not _has_project or engine_selector.item_count == 0
	launch_button.disabled = engine_selector.disabled
	settings_button.disabled = busy or not _has_project
