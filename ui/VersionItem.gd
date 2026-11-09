class_name VersionItem
extends Button

signal context_requested(index: int, screen_position: Vector2)

var index := -1

@onready var name_label: Label = $Content/Row/Info/NameRow/NameLabel
@onready var type_label: Label = $Content/Row/Info/NameRow/TypeBadge/BadgeLabel
@onready var default_badge: PanelContainer = $Content/Row/Info/NameRow/DefaultBadge
@onready var default_label: Label = $Content/Row/Info/NameRow/DefaultBadge/DefaultLabel
@onready var path_label: Label = $Content/Row/Info/PathLabel
@onready var mark: Label = $Content/Row/Mark

const ACCENT := Color("478cbf")
const MUTED := Color("9ba3af")


func _ready() -> void:
	toggled.connect(_on_toggled)


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		context_requested.emit(index, mouse_event.global_position)
		accept_event()


func setup(version: Dictionary, item_index: int) -> void:
	index = item_index
	name_label.text = str(version.name)
	path_label.text = str(version.path)
	type_label.text = "Mono" if version.is_mono else "Standard"
	type_label.add_theme_color_override("font_color", ACCENT if version.is_mono else MUTED)
	default_label.text = tr("VERSION_DEFAULT_BADGE")
	default_badge.visible = bool(version.is_default)
	tooltip_text = str(version.path)


func _on_toggled(pressed_state: bool) -> void:
	mark.visible = pressed_state
