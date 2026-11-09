class_name ProjectItem
extends Button

signal double_clicked(index: int)
signal context_requested(index: int, screen_position: Vector2)

const BADGE_MIN_WIDTH := 100.0
const STANDARD_COLOR := Color("4ea86b")
const MONO_COLOR := Color("7fb4db")

var index := -1
var _suppress_release := false

@onready var name_label: Label = $Content/Row/Info/NameRow/NameLabel
@onready var engine_badge: PanelContainer = $Content/Row/Info/NameRow/EngineBadge
@onready var engine_label: Label = $Content/Row/Info/NameRow/EngineBadge/EngineLabel
@onready var path_label: Label = $Content/Row/Info/PathLabel
@onready var mark: Label = $Content/Row/Mark


func _ready() -> void:
	toggled.connect(_on_toggled)
	engine_badge.custom_minimum_size = Vector2(BADGE_MIN_WIDTH, 0)
	engine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		context_requested.emit(index, mouse_event.global_position)
		accept_event()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.double_click and mouse_event.pressed:
		_suppress_release = true
		double_clicked.emit(index)
		accept_event()
	elif _suppress_release and not mouse_event.pressed:
		_suppress_release = false
		accept_event()


func setup(project: Dictionary, item_index: int, engine_text: String, is_mono: bool) -> void:
	index = item_index
	name_label.text = str(project.name)
	path_label.text = str(project.project_dir)
	set_engine(engine_text, is_mono)
	tooltip_text = str(project.project_dir)


func set_engine(engine_text: String, is_mono: bool) -> void:
	engine_label.text = engine_text
	engine_badge.visible = not engine_text.is_empty()
	engine_label.add_theme_color_override("font_color", MONO_COLOR if is_mono else STANDARD_COLOR)


func _on_toggled(pressed_state: bool) -> void:
	mark.visible = pressed_state
