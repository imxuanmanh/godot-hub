class_name AppLanguages
extends RefCounted

const DEFAULT := "vi"
const SUPPORTED := ["vi", "en"]
const NAMES := {"vi": "Tiếng Việt", "en": "English"}


static func is_supported(code: String) -> bool:
	return SUPPORTED.has(code)
