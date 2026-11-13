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


## Project indices matching the query, pinned projects first (stable order).
static func visible_indices(projects: Array, query: String) -> Array[int]:
	var pinned: Array[int] = []
	var others: Array[int] = []
	for i in projects.size():
		if not matches(projects[i], query):
			continue
		if bool(projects[i].get("pinned", false)):
			pinned.append(i)
		else:
			others.append(i)
	pinned.append_array(others)
	return pinned


## Splits a comma-separated tag string, trimming and removing duplicates.
static func parse_tags(text: String) -> Array[String]:
	var tags: Array[String] = []
	for part in text.split(",", false):
		var tag := part.strip_edges()
		if not tag.is_empty() and not tags.has(tag):
			tags.append(tag)
	return tags
