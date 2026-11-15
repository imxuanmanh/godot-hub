extends SceneTree
## No framework: run with godot --headless --path . --script this_file.

const Resolver = preload("res://features/editor_settings/editor_settings_resolver.gd")
const Keys = preload("res://features/editor_settings/editor_settings_keys.gd")


func _initialize() -> void:
	var defaults: Dictionary = {"boolean": true, "number": 1, "text": "default"}
	var overrides: Dictionary = {"boolean": false, "number": 0, "text": ""}
	var merged: Dictionary = Resolver.resolve(defaults, overrides)
	assert(merged.values == overrides)
	assert(merged.sources.boolean == "Project")
	assert(defaults.boolean and defaults.number == 1)
	assert(Resolver.resolve({"number": 0}, {"number": 0}).values.number == 0)
	assert(Resolver.resolve({"number": 2}, {"number": 0}).values.number == 0)
	overrides.erase("number")
	merged = Resolver.resolve(defaults, overrides, {"native": "kept"})
	assert(merged.values.number == 1 and merged.sources.number == "Default")
	assert(merged.values.native == "kept" and merged.sources.native == "Native")
	assert(Resolver.validate({Keys.USE_EXTERNAL: false, Keys.EXEC_PATH: ""}).ok)
	assert(not Resolver.validate({Keys.USE_EXTERNAL: 0}).ok)
	assert(not Resolver.validate({"unknown": true}).ok)
	print("Resolver checks passed.")
	quit()
