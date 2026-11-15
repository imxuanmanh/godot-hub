class_name EditorItem
extends Button
## Card showing one catalog editor.

signal context_requested(index: int, screen_position: Vector2)
signal activated(index: int)

var index := -1

@onready var name_label: Label = $Content/Row/Info/NameRow/NameLabel
@onready var path_label: Label = $Content/Row/Info/PathLabel
@onready var mark: Label = $Content/Row/Mark


func _ready() -> void:
	toggled.connect(func(pressed_state: bool) -> void: mark.visible = pressed_state)


func _gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		context_requested.emit(index, mouse_event.global_position)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
		activated.emit(index)
		accept_event()


func setup(editor: Dictionary, item_index: int) -> void:
	index = item_index
	name_label.text = str(editor.name)
	path_label.text = str(editor.path)
	tooltip_text = "%s %s" % [editor.path, editor.flags]
