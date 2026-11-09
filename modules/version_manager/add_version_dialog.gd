class_name AddVersionDialog
extends Window

signal version_ready(version: Dictionary)

const ARCHIVE_URL := "https://godotengine.org/download/archive/"
const RELEASE_SCENE := preload("res://modules/version_manager/release_entry.tscn")

var _candidates: Array = []
var _pending: Dictionary = {}
var _downloading := false

@onready var tabs: TabContainer = $Content/Root/Tabs
@onready var status_label: Label = $Content/Root/StatusBox/StatusLabel
@onready var progress_bar: ProgressBar = $Content/Root/StatusBox/ProgressBar
@onready var close_button: Button = $Content/Root/Footer/CloseButton
@onready var choose_file_button: Button = $Content/Root/Tabs/File/FileBox/ChooseFileButton
@onready var file_title: Label = $Content/Root/Tabs/File/FileBox/FileTitle
@onready var file_hint: Label = $Content/Root/Tabs/File/FileBox/FileHint
@onready var file_dialog: FileDialog = $FileDialog
@onready var url_title: Label = $Content/Root/Tabs/Url/UrlBox/UrlTitle
@onready var url_hint: Label = $Content/Root/Tabs/Url/UrlBox/UrlHint
@onready var url_label: Label = $Content/Root/Tabs/Url/UrlBox/UrlForm/UrlLabel
@onready var name_label: Label = $Content/Root/Tabs/Url/UrlBox/UrlForm/NameLabel
@onready var url_edit: LineEdit = $Content/Root/Tabs/Url/UrlBox/UrlForm/UrlEdit
@onready var name_edit: LineEdit = $Content/Root/Tabs/Url/UrlBox/UrlForm/NameEdit
@onready var download_url_button: Button = $Content/Root/Tabs/Url/UrlBox/UrlForm/DownloadUrlButton
@onready var refresh_button: Button = $Content/Root/Tabs/Available/AvailableToolbar/RefreshButton
@onready var open_archive_button: Button = $Content/Root/Tabs/Available/AvailableToolbar/OpenArchiveButton
@onready var available_count: Label = $Content/Root/Tabs/Available/AvailableToolbar/AvailableCount
@onready var items_container: VBoxContainer = $Content/Root/Tabs/Available/AvailableList/Stack/Scroll/Items
@onready var empty_state: Label = $Content/Root/Tabs/Available/AvailableList/Stack/EmptyState
@onready var http: HTTPRequest = $Http
@onready var api_http: HTTPRequest = $ApiHttp


func _ready() -> void:
	title = tr("ADD_VERSION_TITLE")
	tabs.set_tab_title(0, tr("ADD_TAB_FILE"))
	tabs.set_tab_title(1, tr("ADD_TAB_URL"))
	tabs.set_tab_title(2, tr("ADD_TAB_AVAILABLE"))
	file_title.text = tr("ADD_FILE_TITLE")
	file_hint.text = tr("ADD_FILE_HINT")
	choose_file_button.text = tr("ADD_CHOOSE_FILE")
	url_title.text = tr("ADD_URL_TITLE")
	url_hint.text = tr("ADD_URL_HINT")
	url_label.text = tr("ADD_URL_LABEL")
	name_label.text = tr("ADD_NAME_LABEL")
	download_url_button.text = tr("ADD_DOWNLOAD_ADD")
	refresh_button.text = tr("ADD_REFRESH")
	open_archive_button.text = tr("ADD_OPEN_ARCHIVE")
	close_button.text = tr("COMMON_CLOSE")
	file_dialog.title = tr("ADD_FILE_DIALOG_TITLE")
	file_dialog.ok_button_text = tr("COMMON_CHOOSE")
	empty_state.text = tr("ADD_AVAILABLE_EMPTY")
	available_count.text = tr("ADD_AVAILABLE_COUNT") % 0

	close_requested.connect(_on_close)
	close_button.pressed.connect(_on_close)
	choose_file_button.pressed.connect(_on_choose_file)
	file_dialog.file_selected.connect(_on_file_selected)
	download_url_button.pressed.connect(_on_download_url)
	refresh_button.pressed.connect(_fetch_releases)
	open_archive_button.pressed.connect(_on_open_archive)
	http.request_completed.connect(_on_download_completed)
	api_http.request_completed.connect(_on_api_completed)
	progress_bar.visible = false


func _process(_delta: float) -> void:
	if not _downloading:
		return
	var megabytes := http.get_downloaded_bytes() / 1048576.0
	progress_bar.value = fmod(megabytes * 8.0, 100.0)
	status_label.text = tr("ADD_STATUS_DOWNLOADING") % megabytes


func open_dialog() -> void:
	_downloading = false
	_pending = {}
	progress_bar.visible = false
	download_url_button.disabled = false
	refresh_button.disabled = false
	_set_status(tr("ADD_STATUS_CHOOSE"), false)
	if _candidates.is_empty():
		var cached := VersionManager.load_cache()
		_candidates = cached if not cached.is_empty() else VersionManager.known_candidates()
	_rebuild_list()
	popup_centered(Vector2i(760, 640))


# ---------------- FROM FILE ----------------

func _on_choose_file() -> void:
	file_dialog.popup_centered(Vector2i(760, 480))


func _on_file_selected(path: String) -> void:
	var file_name := path.get_file()
	if file_name.is_empty():
		return
	version_ready.emit({
		"name": file_name,
		"path": path,
		"is_mono": file_name.to_lower().contains("mono"),
	})
	hide()


# ---------------- FROM URL ----------------

func _on_download_url() -> void:
	var url := url_edit.text.strip_edges()
	if url.is_empty():
		_set_status(tr("ERR_URL_EMPTY"), true)
		return
	if not url.begins_with("http://") and not url.begins_with("https://"):
		_set_status(tr("ERR_URL_SCHEME"), true)
		return
	var display := name_edit.text.strip_edges()
	if display.is_empty():
		display = url.get_file().get_basename()
	_start_download(url, display, {})


# ---------------- FROM MANIFEST ----------------

func _fetch_releases() -> void:
	refresh_button.disabled = true
	_set_status(tr("ADD_STATUS_FETCHING"), false)
	var err := api_http.request(
		VersionManager.GITHUB_RELEASES_API,
		PackedStringArray(["User-Agent: GodotHub/1.0", "Accept: application/vnd.github+json"])
	)
	if err != OK:
		refresh_button.disabled = false
		_set_status(tr("ERR_REQUEST_SEND") % err, true)


func _on_api_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	refresh_button.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status(tr("ERR_MANIFEST_HTTP") % code, true)
		return
	var list := VersionManager.parse_github_releases(body.get_string_from_utf8())
	if list.is_empty():
		_set_status(tr("ERR_MANIFEST_EMPTY"), true)
		return
	_candidates = list
	VersionManager.save_cache(list)
	_rebuild_list()
	_set_status(tr("ADD_STATUS_UPDATED") % VersionManager.group_by_version(list).size(), false)


func _rebuild_list() -> void:
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()
	var groups := VersionManager.group_by_version(_candidates)
	for group in groups:
		var entry: ReleaseEntry = RELEASE_SCENE.instantiate()
		items_container.add_child(entry)
		entry.setup(group)
		entry.download_requested.connect(_on_entry_download)
	available_count.text = tr("ADD_AVAILABLE_COUNT") % groups.size()
	empty_state.visible = groups.is_empty()


func _on_entry_download(candidate: Dictionary) -> void:
	var display := "Godot %s" % str(candidate.get("version", ""))
	if bool(candidate.get("is_mono", false)):
		display += " Mono"
	_start_download(str(candidate.get("url", "")), display, candidate)


func _on_open_archive() -> void:
	OS.shell_open(ARCHIVE_URL)


# ---------------- DOWNLOAD ----------------

func _start_download(url: String, display_name: String, meta: Dictionary) -> void:
	if _downloading:
		return
	if url.is_empty():
		_set_status(tr("ERR_DOWNLOAD_URL_INVALID"), true)
		return
	VersionManager.ensure_dir(VersionManager.DOWNLOAD_DIR)
	var temp_path := VersionManager.DOWNLOAD_DIR.path_join("dl_%d.zip" % Time.get_ticks_usec())
	http.cancel_request()
	http.download_file = temp_path
	var err := http.request(url)
	if err != OK:
		http.download_file = ""
		_set_status(tr("ERR_DOWNLOAD_START") % err, true)
		return
	_pending = {"url": url, "name": display_name, "temp": temp_path}
	_pending.merge(meta)
	_downloading = true
	progress_bar.value = 0
	progress_bar.visible = true
	download_url_button.disabled = true
	refresh_button.disabled = true
	_set_list_enabled(false)
	_set_status(tr("ADD_STATUS_DOWNLOADING_FILE") % url.get_file(), false)


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	http.download_file = ""
	progress_bar.visible = false
	download_url_button.disabled = false
	refresh_button.disabled = false
	_set_list_enabled(true)

	if _pending.is_empty():
		return
	var pending := _pending
	_pending = {}

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status(tr("ERR_DOWNLOAD_FAILED") % code, true)
		VersionManager.remove_path(str(pending.get("temp", "")))
		return

	var temp_path := str(pending.get("temp", ""))
	if not FileAccess.file_exists(temp_path):
		_set_status(tr("ERR_DOWNLOAD_MISSING"), true)
		return

	_set_status(tr("ADD_STATUS_EXTRACTING"), false)
	var installed := VersionManager.install_zip(temp_path, str(pending.get("name", "")))
	VersionManager.remove_path(temp_path)
	if not bool(installed.get("ok", false)):
		_set_status(str(installed.get("error", tr("ERR_INSTALL_FAILED"))), true)
		return

	var display := str(pending.get("name", ""))
	if display.is_empty():
		display = str(installed.get("dir", "")).get_file()
	var is_mono := bool(pending.get("is_mono", display.to_lower().contains("mono")))
	version_ready.emit({
		"name": display,
		"path": str(installed.get("executable", "")),
		"is_mono": is_mono,
	})
	_set_status(tr("ADD_STATUS_ADDED") % display, false)
	hide()


# ---------------- HELPERS ----------------

func _set_list_enabled(enabled: bool) -> void:
	for child in items_container.get_children():
		var entry := child as ReleaseEntry
		if entry != null:
			entry.set_buttons_enabled(enabled)


func _set_status(text: String, is_error: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color("d98a8a") if is_error else Color("9ba3af"))


func _on_close() -> void:
	if _downloading:
		var temp_path := str(_pending.get("temp", ""))
		_pending = {}
		_downloading = false
		http.cancel_request()
		progress_bar.visible = false
		VersionManager.remove_path(temp_path)
		_set_list_enabled(true)
	hide()
