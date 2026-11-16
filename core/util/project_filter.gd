class_name ProjectFilter
extends RefCounted

## Pure helpers for filtering and ordering projects for display.


## True when the project name or any tag contains the query (case-insensitive).
static func matches(project: Dictionary, query: String) -> bool:
	var needle := query.strip_edges().to_lower()
	if needle.is_empty():
		return true
	if str(project.get("name", "")).to_lower().contains(needle):
		return true
	for tag in project.get("tags", []):
		if str(tag).to_lower().contains(needle):
			return true
	return false


## Project indices matching every active filter, pinned projects first (stable order).
## `build` is empty, "standard" or "mono"; `engine_index` -1 means any version.
static func visible_indices(
	projects: Array,
	query: String,
	versions: Array = [],
	tag: String = "",
	engine_index: int = -1,
	build: String = ""
) -> Array[int]:
	var pinned: Array[int] = []
	var others: Array[int] = []
	for i in projects.size():
		if not _passes(projects[i], query, versions, tag, engine_index, build):
			continue
		if bool(projects[i].get("pinned", false)):
			pinned.append(i)
		else:
			others.append(i)
	pinned.append_array(others)
	return pinned


static func _passes(
	project: Dictionary,
	query: String,
	versions: Array,
	tag: String,
	engine_index: int,
	build: String
) -> bool:
	if not matches(project, query):
		return false
	if not tag.is_empty() and not _has_tag(project, tag):
		return false
	var project_engine := int(project.get("engine_index", -1))
	if engine_index >= 0 and project_engine != engine_index:
		return false
	if build.is_empty():
		return true
	if project_engine < 0 or project_engine >= versions.size():
		return false
	var is_mono := bool(versions[project_engine].get("is_mono", false))
	return is_mono if build == "mono" else not is_mono


static func _has_tag(project: Dictionary, tag: String) -> bool:
	var needle := tag.to_lower()
	for item in project.get("tags", []):
		if str(item).to_lower() == needle:
			return true
	return false

