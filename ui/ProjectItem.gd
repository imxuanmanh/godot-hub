class_name ProjectItem
extends Button

signal double_clicked(index: int)
signal context_requested(index: int, screen_position: Vector2)
signal open_folder_requested(index: int)

const BADGE_MIN_WIDTH := 100.0
const STANDARD_COLOR := Color("4ea86b")
const MONO_COLOR := Color("7fb4db")
const PIN_GLYPH := "★"
const NO_ENGINE_ALPHA := 0.0

var index := -1
var _suppress_release := false

@onready var pin_label: Label = $Content/Row/PinLabel
@onready var name_label: Label = $Content/Row/NameLabel
@onready var path_label: Label = $Content/Row/PathCell/PathLabel
@onready var open_folder_button: Button = $Content/Row/PathCell/OpenFolderButton
@onready var engine_badge: PanelContainer = $Content/Row/EngineBadge
@onready var engine_label: Label = $Content/Row/EngineBadge/EngineLabel
@onready var tags_label: Label = $Content/Row/TagsLabel


func _ready() -> void:
	engine_badge.custom_minimum_size = Vector2(BADGE_MIN_WIDTH, 0)
	engine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	engine_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	open_folder_button.tooltip_text = tr("PROJECTS_OPEN_FOLDER")
	open_folder_button.pressed.connect(_on_open_folder_pressed)


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
	pin_label.text = PIN_GLYPH if bool(project.get("pinned", false)) else ""
	_set_tags(project.get("tags", []))
	set_engine(engine_text, is_mono)
	tooltip_text = str(project.project_dir)


func _set_tags(tags: Array) -> void:
	var parts: Array[String] = []
	for tag in tags:
		var tag_text := str(tag).strip_edges()
		if not tag_text.is_empty():
			parts.append("#" + tag_text)
	tags_label.text = "  ".join(parts)


func set_engine(engine_text: String, is_mono: bool) -> void:
	engine_label.text = engine_text
	engine_badge.modulate.a = NO_ENGINE_ALPHA if engine_text.is_empty() else 1.0
	engine_label.add_theme_color_override("font_color", MONO_COLOR if is_mono else STANDARD_COLOR)


func _on_open_folder_pressed() -> void:
	open_folder_requested.emit(index)
