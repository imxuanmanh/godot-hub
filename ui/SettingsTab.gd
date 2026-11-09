class_name SettingsTab
extends VBoxContainer

signal language_changed(code: String)

var _language := AppLanguages.DEFAULT
var _nav_buttons: Array[Button] = []
var _panels: Array[Control] = []

@onready var title_label: Label = $Header/TitleBlock/Title
@onready var subtitle_label: Label = $Header/TitleBlock/Subtitle
@onready var general_button: Button = $Body/Sidebar/SidebarMargin/Nav/GeneralButton
@onready var engines_button: Button = $Body/Sidebar/SidebarMargin/Nav/EnginesButton
@onready var projects_button: Button = $Body/Sidebar/SidebarMargin/Nav/ProjectsButton
@onready var general_panel: Control = $Body/Content/ContentMargin/Panels/General
@onready var engines_panel: Control = $Body/Content/ContentMargin/Panels/Engines
@onready var projects_panel: Control = $Body/Content/ContentMargin/Panels/Projects
@onready var language_label: Label = $Body/Content/ContentMargin/Panels/General/LanguageRow/LanguageLabel
@onready var language_selector: OptionButton = $Body/Content/ContentMargin/Panels/General/LanguageRow/LanguageSelector
@onready var language_hint: Label = $Body/Content/ContentMargin/Panels/General/LanguageHint
@onready var engines_placeholder: Label = $Body/Content/ContentMargin/Panels/Engines/Placeholder
@onready var projects_placeholder: Label = $Body/Content/ContentMargin/Panels/Projects/Placeholder


func _ready() -> void:
	title_label.text = tr("SETTINGS_TITLE")
	subtitle_label.text = tr("SETTINGS_SUBTITLE")
	general_button.text = tr("SETTINGS_NAV_GENERAL")
	engines_button.text = tr("SETTINGS_NAV_ENGINES")
	projects_button.text = tr("SETTINGS_NAV_PROJECTS")
	language_label.text = tr("SETTINGS_LANGUAGE_LABEL")
	language_hint.text = tr("SETTINGS_LANGUAGE_HINT")
	engines_placeholder.text = tr("SETTINGS_ENGINES_PLACEHOLDER")
	projects_placeholder.text = tr("SETTINGS_PROJECTS_PLACEHOLDER")

	_nav_buttons = [general_button, engines_button, projects_button]
	_panels = [general_panel, engines_panel, projects_panel]
	var group := ButtonGroup.new()
	for i in _nav_buttons.size():
		var button := _nav_buttons[i]
		button.button_group = group
		button.toggled.connect(_on_nav_toggled.bind(i))

	_setup_language_selector()
	general_button.button_pressed = true
	_show_panel(0)


func set_language(code: String) -> void:
	_language = code
	language_selector.select(maxi(AppLanguages.SUPPORTED.find(code), 0))


func _setup_language_selector() -> void:
	language_selector.clear()
	for code in AppLanguages.SUPPORTED:
		language_selector.add_item(str(AppLanguages.NAMES[code]))
		language_selector.set_item_metadata(language_selector.item_count - 1, code)
	language_selector.item_selected.connect(_on_language_selected)


func _on_language_selected(index: int) -> void:
	var code := str(language_selector.get_item_metadata(index))
	if code == _language:
		return
	_language = code
	language_changed.emit(code)


func _on_nav_toggled(pressed_state: bool, index: int) -> void:
	if pressed_state:
		_show_panel(index)


func _show_panel(index: int) -> void:
	for i in _panels.size():
		_panels[i].visible = (i == index)
