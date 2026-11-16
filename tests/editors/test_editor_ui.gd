extends SceneTree
## Drives EditorsTab and ProjectEditorDialog headlessly against a scratch catalog.

var _saved: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root_dir: String = ProjectSettings.globalize_path("res://build/editor-ui-tests").path_join(ProjectIdentity.create())
	var catalog: EditorCatalog = EditorCatalog.new(root_dir.path_join("editors.json"))
	assert(catalog.load_catalog().ok)

	var tab: EditorsTab = load("res://ui/EditorsTab.tscn").instantiate()
	tab.setup(catalog)
	root.add_child(tab)
	await process_frame
	assert(tab.items_container.get_child_count() == 0 and tab.empty_state.visible)
	assert(tab.edit_button.disabled and tab.remove_button.disabled)

	tab.form_dialog.submitted.emit(-1, "VSCode", "C:/Code/Code.exe", EditorOverridesStore.DEFAULT_FLAGS)
	tab.form_dialog.submitted.emit(-1, "Rider", "C:/Rider/rider64.exe", "{file}")
	await process_frame
	assert(catalog.list().size() == 2 and tab.items_container.get_child_count() == 2)
	assert(not tab.empty_state.visible)

	var removed_paths: Array = []
	tab.editor_removed.connect(func(path: String) -> void: removed_paths.append(path))
	tab._select(0)
	tab._confirm_remove(0)
	tab.confirm_dialog.confirmed.emit()
	tab.confirm_dialog.hide()
	assert(catalog.list().size() == 1 and catalog.list()[0].name == "Rider", str(catalog.list()))
	assert(removed_paths == ["C:/Code/Code.exe"], str(removed_paths))

	var errors: Array = []
	tab.error_occurred.connect(func(result: Dictionary) -> void: errors.append(result))
	tab.form_dialog.submitted.emit(-1, "", "", "")
	assert(errors.size() == 1 and errors[0].error == "EDITOR_INVALID")

	var form: EditorFormDialog = tab.form_dialog
	form.open_form(-1, {})
	form._on_file_selected("C:/Rider/rider64.exe")
	assert(form.args_edit.text == "{solution} --line {line} {file}", form.args_edit.text)
	assert(form.name_edit.text == "JetBrains Rider", form.name_edit.text)
	form.args_edit.text = "{file}"
	form._reset_flags()
	assert(form.args_edit.text == "{solution} --line {line} {file}", form.args_edit.text)
	form.path_edit.text = "C:/Tools/notepad.exe"
	form._reset_flags()
	assert(form.args_edit.text == EditorOverridesStore.DEFAULT_FLAGS, form.args_edit.text)
	form.hide()

	var dialog: ProjectEditorDialog = load("res://ui/ProjectEditorDialog.tscn").instantiate()
	root.add_child(dialog)
	dialog.editor_saved.connect(func(_i: int, mode: String, path: String, flags: String) -> void: _saved.append([mode, path, flags]))
	var editors: Array[Dictionary] = catalog.list()

	dialog.open_dialog(0, "Demo", {"mode": "external", "path": "C:/Rider/rider64.exe", "flags": "{file}"}, editors)
	assert(dialog.mode_selector.item_count == 2 and dialog.mode_selector.selected == 1)
	dialog.save_button.pressed.emit()
	assert(_saved[-1] == ["external", "C:/Rider/rider64.exe", "{file}"], str(_saved))

	dialog.open_dialog(0, "Demo", {"mode": "external", "path": "C:/Old/Code.exe", "flags": "{project}"}, editors)
	assert(dialog.mode_selector.item_count == 3 and dialog.mode_selector.selected == 2)
	dialog.save_button.pressed.emit()
	assert(_saved[-1] == ["external", "C:/Old/Code.exe", "{project}"], str(_saved))

	dialog.open_dialog(0, "Demo", {"mode": "builtin", "path": "", "flags": ""}, editors)
	assert(dialog.mode_selector.selected == 0)
	dialog.save_button.pressed.emit()
	assert(_saved[-1][0] == "builtin", str(_saved))
	print("Editor UI checks passed.")
	quit()
