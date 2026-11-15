class_name ProjectIdentity
extends RefCounted
## Stable opaque IDs shared by persistence and per-project storage.


static func create() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func is_valid(project_id: String) -> bool:
	return project_id.length() == 32 and project_id.is_valid_hex_number(false) and project_id == project_id.to_lower()
