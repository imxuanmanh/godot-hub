class_name VersionManager
extends RefCounted

const STORAGE_DIR := "user://versions"
const DOWNLOAD_DIR := "user://downloads"
const CACHE_PATH := "user://godot_manifest_cache.json"
const GITHUB_RELEASES_API := "https://api.github.com/repos/godotengine/godot/releases?per_page=30"

# Offline manifest: stable tags that are always available on GitHub Releases.
const KNOWN_STABLE := [
	"4.4-stable",
	"4.3-stable",
	"4.2.2-stable",
	"4.1.4-stable",
	"4.0.4-stable",
]


# ---------------- PLATFORM / URLS ----------------

static func platform_key() -> String:
	match OS.get_name():
		"Windows":
			return "win64"
		"Linux":
			return "linux.x86_64"
		"macOS":
			return "macos.universal"
	return ""


static func platform_label() -> String:
	match OS.get_name():
		"Windows":
			return "Windows x64"
		"Linux":
			return "Linux x86_64"
		"macOS":
			return "macOS Universal"
	return OS.get_name()


static func build_url(version_tag: String, mono: bool) -> String:
	var platform := platform_key()
	if platform.is_empty():
		return ""
	var asset := ""
	match platform:
		"win64":
			asset = "Godot_v%s%s_win64%s.zip" % [
				version_tag,
				"_mono" if mono else "",
				"" if mono else ".exe",
			]
		"linux.x86_64":
			asset = "Godot_v%s%s_linux.%s.zip" % [
				version_tag,
				"_mono" if mono else "",
				"x86_64",
			]
			if mono:
				asset = "Godot_v%s_mono_linux_x86_64.zip" % version_tag
		"macos.universal":
			asset = "Godot_v%s%s_macos.universal.zip" % [
				version_tag,
				"_mono" if mono else "",
			]
	return "https://github.com/godotengine/godot/releases/download/%s/%s" % [version_tag, asset]


# ---------------- MANIFEST ----------------

static func known_candidates() -> Array:
	var out: Array = []
	for tag in KNOWN_STABLE:
		for mono in [false, true]:
			var url := build_url(str(tag), bool(mono))
			if url.is_empty():
				continue
			out.append(_make_candidate(
				str(tag),
				url,
				bool(mono),
				"https://github.com/godotengine/godot/releases/tag/%s" % tag,
				"manifest"
			))
	return out


static func parse_github_releases(text: String) -> Array:
	var out: Array = []
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return out
	var platform := platform_key()
	if platform.is_empty():
		return out

	for release in parsed:
		if typeof(release) != TYPE_DICTIONARY:
			continue
		var tag := str(release.get("tag_name", ""))
		if tag.is_empty():
			continue
		var page := str(release.get("html_url", ""))
		var assets = release.get("assets", [])
		if typeof(assets) != TYPE_ARRAY:
			continue
		for asset in assets:
			if typeof(asset) != TYPE_DICTIONARY:
				continue
			var asset_name := str(asset.get("name", ""))
			if not asset_name.ends_with(".zip"):
				continue
			if asset_name.contains("export_templates") or asset_name.contains("headless"):
				continue
			if not _asset_matches(asset_name, platform):
				continue
			out.append(_make_candidate(
				tag,
				str(asset.get("browser_download_url", "")),
				asset_name.contains("mono"),
				page,
				"online"
			))
	return out


static func _make_candidate(version_tag: String, url: String, mono: bool, page: String, source: String) -> Dictionary:
	return {
		"label": "Godot %s · %s · %s" % [
			version_tag,
			"Mono" if mono else "Standard",
			platform_label(),
		],
		"version": version_tag,
		"url": url,
		"is_mono": mono,
		"platform": platform_label(),
		"page_url": page,
		"source": source,
	}


static func _asset_matches(asset_name: String, platform: String) -> bool:
	match platform:
		"win64":
			return asset_name.contains("_win64")
		"linux.x86_64":
			return asset_name.contains("linux.x86_64") or asset_name.contains("linux_x86_64")
		"macos.universal":
			return asset_name.contains("macos.universal")
	return false


static func group_by_version(candidates: Array) -> Array:
	var order: Array = []
	var groups: Dictionary = {}
	for candidate in candidates:
		if typeof(candidate) != TYPE_DICTIONARY:
			continue
		var tag := str(candidate.get("version", ""))
		if tag.is_empty():
			continue
		if not groups.has(tag):
			groups[tag] = {"version": tag, "page_url": "", "standard": {}, "mono": {}}
			order.append(tag)
		var group: Dictionary = groups[tag]
		if str(group.get("page_url", "")).is_empty():
			group["page_url"] = str(candidate.get("page_url", ""))
		if bool(candidate.get("is_mono", false)):
			if group.mono.is_empty():
				group["mono"] = candidate
		elif group.standard.is_empty():
			group["standard"] = candidate

	var out: Array = []
	for tag in order:
		out.append(groups[tag])
	return out


static func save_cache(candidates: Array) -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(candidates, "\t"))
	f.close()


static func load_cache() -> Array:
	if not FileAccess.file_exists(CACHE_PATH):
		return []
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_ARRAY else []


# ---------------- INSTALL ----------------

static func ensure_dir(path: String) -> bool:
	if path.is_empty():
		return false
	var global := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global):
		return true
	return DirAccess.make_dir_recursive_absolute(global) == OK


static func install_zip(zip_path: String, preferred_name: String) -> Dictionary:
	var folder := preferred_name
	if folder.to_lower().ends_with(".zip"):
		folder = folder.get_basename()
	folder = sanitize(folder)
	if folder.is_empty():
		folder = "godot_version"

	ensure_dir(STORAGE_DIR)
	var dest := _unique_dir(folder)
	if not extract_zip(zip_path, dest):
		return {"ok": false, "error": "Giải nén thất bại."}

	var executable := find_executable(dest)
	if executable.is_empty():
		return {
			"ok": false,
			"error": "Không tìm thấy file thực thi Godot trong gói.",
			"dir": dest,
		}

	_make_executable(executable)
	return {"ok": true, "dir": dest, "executable": executable}


static func extract_zip(zip_path: String, dest_dir: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return false
	ensure_dir(dest_dir)
	var entries := reader.get_files()
	for entry in entries:
		var relative := str(entry)
		if relative.contains(".."):
			continue
		var target := dest_dir.path_join(relative)
		if relative.ends_with("/"):
			ensure_dir(target)
			continue
		ensure_dir(target.get_base_dir())
		var data := reader.read_file(relative)
		var f := FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			reader.close()
			return false
		f.store_buffer(data)
		f.close()
	reader.close()
	return true


static func find_executable(dir: String) -> String:
	var files: Array = []
	_collect_files(dir, files, 0)

	if OS.get_name() == "macOS":
		for file in files:
			var path := str(file)
			if path.contains(".app/Contents/MacOS/"):
				return path

	var best := ""
	for file in files:
		var path := str(file)
		var base := path.get_file()
		if not base.contains("Godot_v"):
			continue
		var lower := base.to_lower()
		if lower.contains("console"):
			continue
		if lower.ends_with(".dll") or lower.ends_with(".so") or lower.ends_with(".dylib"):
			continue
		if lower.ends_with(".json") or lower.ends_with(".txt"):
			continue
		if OS.get_name() == "Windows" and not lower.ends_with(".exe"):
			continue
		best = path
	return best


static func _collect_files(dir: String, out: Array, depth: int) -> void:
	if depth > 8:
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var name := da.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var path := dir.path_join(name)
			if da.current_is_dir():
				_collect_files(path, out, depth + 1)
			else:
				out.append(path)
		name = da.get_next()
	da.list_dir_end()


static func sanitize(value: String) -> String:
	var result := value.strip_edges()
	for ch in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*", " "]:
		result = result.replace(ch, "_")
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")


static func _unique_dir(base: String) -> String:
	var candidate := STORAGE_DIR.path_join(base)
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
		return candidate
	var index := 2
	while true:
		candidate = STORAGE_DIR.path_join("%s_%d" % [base, index])
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):
			return candidate
		index += 1
	return candidate


static func _make_executable(path: String) -> void:
	if OS.get_name() == "Windows":
		return
	OS.execute("chmod", PackedStringArray(["+x", ProjectSettings.globalize_path(path)]))


static func remove_path(path: String) -> void:
	if path.is_empty():
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
