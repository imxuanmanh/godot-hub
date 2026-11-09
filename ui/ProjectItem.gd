class_name ProjectItem
extends Button

var index := -1

@onready var name_label: Label = $Content/Row/Info/NameRow/NameLabel
@onready var engine_badge: PanelContainer = $Content/Row/Info/NameRow/EngineBadge
@onready var engine_label: Label = $Content/Row/Info/NameRow/EngineBadge/EngineLabel
@onready var path_label: Label = $Content/Row/Info/PathLabel
@onready var mark: Label = $Content/Row/Mark


func _ready() -> void:
	toggled.connect(_on_toggled)


func setup(project: Dictionary, item_index: int, engine_text: String) -> void:
	index = item_index
	name_label.text = str(project.name)
	path_label.text = str(project.project_dir)
	set_engine(engine_text)
	tooltip_text = str(project.project_dir)


func set_engine(engine_text: String) -> void:
	engine_label.text = engine_text
	engine_badge.visible = not engine_text.is_empty()


func _on_toggled(pressed_state: bool) -> void:
	mark.visible = pressed_state
