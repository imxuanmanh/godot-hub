class_name EditorSettingsResolver
extends RefCounted
## Resolves each key independently; explicit false/zero/empty values stay pinned.


static func resolve(defaults: Dictionary, overrides: Dictionary, native: Dictionary = {}) -> Dictionary:
	var values: Dictionary = native.duplicate(true)
	var sources: Dictionary = {}
	for key: Variant in native:
		sources[key] = "Native"
	for key: Variant in defaults:
		values[key] = defaults[key]
		sources[key] = "Default"
	for key: Variant in overrides:
		values[key] = overrides[key]
		sources[key] = "Project"
	return {"values": values, "sources": sources}


## Validation is separate so merging remains independent of the supported UI keys.
static func validate(values: Dictionary) -> Dictionary:
	for key: Variant in values:
		if not EditorSettingsKeys.TYPES.has(key):
			return {"ok": false, "error": "EDITOR_SETTINGS_UNSUPPORTED_KEY", "detail": str(key)}
		if typeof(values[key]) != EditorSettingsKeys.TYPES[key]:
			return {"ok": false, "error": "EDITOR_SETTINGS_INVALID_TYPE", "detail": str(key)}
	return {"ok": true}
