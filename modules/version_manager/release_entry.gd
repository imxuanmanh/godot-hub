class_name ReleaseEntry
extends PanelContainer

signal download_requested(candidate: Dictionary)

var _standard: Dictionary = {}
var _mono: Dictionary = {}
var _page_url := ""

@onready var title_label: Label = $Row/Info/TitleLabel
@onready var state_label: Label = $Row/Info/StateLabel
@onready var standard_button: Button = $Row/Buttons/StandardButton
@onready var mono_button: Button = $Row/Buttons/MonoButton
@onready var page_button: Button = $Row/Buttons/PageButton


func _ready() -> void:
	page_button.text = tr("COMMON_OPEN_PAGE")
	standard_button.pressed.connect(_on_standard_pressed)
	mono_button.pressed.connect(_on_mono_pressed)
	page_button.pressed.connect(_on_page_pressed)


func setup(group: Dictionary) -> void:
	_standard = group.get("standard", {})
	_mono = group.get("mono", {})
	_page_url = str(group.get("page_url", ""))
	title_label.text = "Godot %s" % str(group.get("version", ""))
	state_label.text = _describe()
	standard_button.tooltip_text = str(_standard.get("url", ""))
	mono_button.tooltip_text = str(_mono.get("url", ""))
	page_button.tooltip_text = _page_url
	set_buttons_enabled(true)


func set_buttons_enabled(enabled: bool) -> void:
	standard_button.disabled = not enabled or _standard.is_empty()
	mono_button.disabled = not enabled or _mono.is_empty()
	page_button.disabled = not enabled or _page_url.is_empty()


func _describe() -> String:
	var platform := str(_standard.get("platform", _mono.get("platform", "")))
	var availability := tr("AVAIL_BOTH")
	if _standard.is_empty() and _mono.is_empty():
		availability = tr("AVAIL_NONE")
	elif _standard.is_empty():
		availability = tr("AVAIL_MONO_ONLY")
	elif _mono.is_empty():
		availability = tr("AVAIL_STANDARD_ONLY")
	if platform.is_empty():
		return availability
	return "%s · %s" % [platform, availability]


func _on_standard_pressed() -> void:
	if not _standard.is_empty():
		download_requested.emit(_standard)


func _on_mono_pressed() -> void:
	if not _mono.is_empty():
		download_requested.emit(_mono)


func _on_page_pressed() -> void:
	if not _page_url.is_empty():
		OS.shell_open(_page_url)
