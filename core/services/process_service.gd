class_name ProcessService
extends RefCounted
## Spawns with temporary child-only environment changes on the main thread.

const READ_BYTES: int = 4096
const POLL_SECONDS: float = 0.1
const CAPTURE_TIMEOUT_SECONDS: float = 45.0


## Restores both values and absence before returning a process result.
static func spawn(executable: String, arguments: PackedStringArray, environment: Dictionary = {}) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "error": "EDITOR_SETTINGS_SPAWN_ERROR", "detail": executable}
	var previous: Dictionary = {}
	for key: String in environment:
		previous[key] = {"exists": OS.has_environment(key), "value": OS.get_environment(key)}
	# No awaits, logging, callbacks or signals until the original environment is restored.
	for key: String in environment:
		OS.set_environment(key, str(environment[key]))
	var pid: int = OS.create_process(executable, arguments)
	for key: String in previous:
		if previous[key].exists:
			OS.set_environment(key, previous[key].value)
		else:
			OS.unset_environment(key)
	if pid <= 0:
		return {"ok": false, "error": "EDITOR_SETTINGS_SPAWN_ERROR", "detail": executable}
	return {"ok": true, "pid": pid}


## Polls non-blocking pipes so a bad executable cannot hang the Hub or a worker.
static func capture(executable: String, arguments: PackedStringArray, tree: SceneTree) -> Dictionary:
	var child: Dictionary = OS.execute_with_pipe(executable, arguments, false)
	if child.is_empty():
		return {"ok": false, "output": executable}
	var output: String = ""
	var started: int = Time.get_ticks_msec()
	while OS.is_process_running(child.pid):
		output = (output + child.stdio.get_buffer(READ_BYTES).get_string_from_utf8()).left(READ_BYTES)
		child.stderr.get_buffer(READ_BYTES)
		if Time.get_ticks_msec() - started > int(CAPTURE_TIMEOUT_SECONDS * 1000):
			OS.kill(child.pid)
			child.stdio.close()
			child.stderr.close()
			return {"ok": false, "output": executable}
		await tree.create_timer(POLL_SECONDS).timeout
	output += child.stdio.get_buffer(READ_BYTES).get_string_from_utf8()
	child.stdio.close()
	child.stderr.close()
	return {"ok": OS.get_process_exit_code(child.pid) == 0, "output": output.strip_edges()}
