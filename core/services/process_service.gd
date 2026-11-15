class_name ProcessService
extends RefCounted
## Spawns detached child processes on the main thread.


## Returns success only for a valid PID; Hub never waits for the child.
static func spawn(executable: String, arguments: PackedStringArray) -> Dictionary:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		return {"ok": false, "error": "PROCESS_SPAWN_ERROR", "detail": executable}
	var pid: int = OS.create_process(executable, arguments)
	if pid <= 0:
		return {"ok": false, "error": "PROCESS_SPAWN_ERROR", "detail": executable}
	return {"ok": true, "pid": pid}
