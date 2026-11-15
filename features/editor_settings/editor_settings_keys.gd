class_name EditorSettingsKeys
extends RefCounted
## Keys and paths owned by the editor settings feature.

const SCHEMA: int = 1
const SECTION: String = "editor"
const USE_EXTERNAL: String = "text_editor/external/use_external_editor"
const EXEC_PATH: String = "text_editor/external/exec_path"
const EXEC_FLAGS: String = "text_editor/external/exec_flags"
const TYPES: Dictionary = {USE_EXTERNAL: TYPE_BOOL, EXEC_PATH: TYPE_STRING, EXEC_FLAGS: TYPE_STRING}
const DEFAULT_FILE: String = "settings.cfg"
const PROJECTS_DIRECTORY: String = "projects"
const RUNTIME_DIRECTORY: String = "runtime"
const OVERRIDE_FILE: String = "settings.override.cfg"
const SEED_PATH: String = "res://config/editor_settings.cfg"
const HELPER_PATH: String = "res://features/editor_settings/native_bootstrap.gd.txt"
const POLL_SECONDS: float = 0.1
const TIMEOUT_SECONDS: float = 45.0
