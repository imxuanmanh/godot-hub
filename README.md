<p align="center">
  <img src="assets/godot-hub-logo.svg" alt="Godot Hub logo" width="120">
</p>

<h1 align="center">Godot Hub</h1>

<p align="center">
  A lightweight desktop companion for managing multiple Godot engine builds and your Godot projects — built entirely with Godot.
</p>

<p align="center">
  <img alt="Godot 4.7" src="https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white">
  <img alt="GDScript" src="https://img.shields.io/badge/Language-GDScript-3776ab">
  <img alt="Platforms" src="https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey">
  <img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-green">
</p>

---

## Overview

**Godot Hub** is a small, self-hosted alternative to Unity Hub for the Godot ecosystem. It keeps multiple Godot versions side by side, remembers which engine each project uses, and launches projects with the right executable — no more juggling folders or renaming binaries.

The app is written in **GDScript** with **static typing**, follows a feature-oriented structure, and ships with a dark theme and Vietnamese/English localization.

Current patch: **0.1.2**.

## Features

- **Multiple engine versions** — keep Standard and Mono builds side by side.
- **Flexible installation** — add an existing executable, download a `.zip` from a URL, or browse official GitHub releases.
- **Automatic extraction** — downloaded archives are extracted into the app's data directory and registered automatically.
- **Project library** — import projects from `project.godot`, rename, open, and remove them from a single list.
- **Per-project engine binding** — each project remembers its assigned engine across restarts.
- **Fast launch** — select a project and press **Open project**, or simply **double-click** it.
- **Editor catalog** — register the script editors installed on your machine (VSCode, Rider, …) once in the **Editors** tab.
- **Per-project script editor** — pick Godot built-in or a catalog editor per project via Godot's own `[editor_overrides]`.
- **Context menus** — right-click a project or version card for quick actions.
- **Themed UI** — a consistent dark theme powered by a single `Theme` resource.
- **Localization** — Vietnamese and English out of the box, switchable at runtime.

## Requirements

- **Godot Engine 4.7** or newer (stable).
- Windows, Linux, or macOS.
- An internet connection for downloading engine builds from GitHub (optional).

## Getting started

### Run from source

```bash
git clone https://github.com/imxuanmanh/godot-hub.git
```

1. Open Godot 4.7+.
2. Choose **Import** and select the `project.godot` file in the cloned folder.
3. Press **F5** (or click **Run**) to start the app.

### Build a release

1. Install the export templates for your Godot version.
2. Open **Project → Export**.
3. Select the **Windows Desktop** preset (or add a preset for your platform).
4. Export to `Godot Hub.exe` in the project root.

The current preset embeds the PCK in the executable.

## Usage

### Versions tab

- **+ Add version** opens a dialog with three sources:
  - **From file** — pick an existing Godot executable.
  - **From URL** — paste a direct link to a Godot `.zip` package.
  - **Available** — fetch the latest releases from GitHub, then download in one click.
- **Set as default** — the default engine is preselected when adding new projects.
- **Remove** — removes the version from the list (the executable on disk is left untouched).

### Projects tab

- **+ Add project** — select a project's `project.godot` file.
- Select a project, choose an engine from the **Godot version** dropdown, then click **Open project**.
- **Double-click** a project to open it with its assigned engine.
- **Right-click** a card to open, configure the script editor, or remove the project.
- **Editors tab** — add, edit (double-click) or remove script editors: a name, the executable and flags (`{project} {file} {line} {col}`). Removing an editor asks for confirmation and switches the Hub projects that used it back to **Godot built-in**. Picking the executable auto-fills the flags for known editors (e.g. Rider `{solution} --line {line} {file}`, VS Code `{project} --goto {file}:{line}:{col}`); the field stays editable and **Reset** restores the detected preset (or the default flags when unknown). `{solution}` is a Hub-only placeholder: when saving, it is replaced (quoted) by the project's `.sln` if one exists, so Rider opens the solution directly instead of asking; otherwise it falls back to `"{project}"`.
- When a project is added, an editor override already in its `project.godot` is kept; otherwise the Hub sets it to **Godot built-in**.
- **Configure editor…** picks the script editor Godot uses for that project: **Godot built-in** or one of the catalog editors. A path not in the catalog is shown as **Other** and kept. Editing a catalog entry does not rewrite projects that already use it; pick it again to update them.
- The choice is written to the `[editor_overrides]` section of the project's `project.godot` (only the `text_editor/external/*` keys; other lines are kept). Godot applies it to that project only, without touching the global editor settings. Close the project in Godot before saving, and reopen it to apply.

## Data and storage

All app data is stored under the Godot `user://` directory:

| Platform | Location |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\Godot Hub\` |
| Linux | `~/.local/share/godot/app_userdata/Godot Hub/` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Godot Hub/` |

Key files:

- `godot_hub_data.json` — versions, projects, and preferences.
- `editors.json` — the editor catalog (name, path, flags).
- `versions/` — extracted engine builds.
- `downloads/` — temporary download files.
- `godot_manifest_cache.json` — cached GitHub release manifest.

The library JSON has schema 1 and stable project IDs; migration preserves existing fields. Writes retain a `.bak` recovery copy.

Deleting this folder resets the app to a clean state. Your actual Godot projects are never modified, except the `[editor_overrides]` keys you save from **Configure editor…**.

## Project structure

```
godot-hub/
├─ core/                     # Shared infrastructure and utilities
├─ locales/                  # Vietnamese and English translations
├─ modules/
│  └─ version_manager/       # Engine discovery, download, and install logic
├─ ui/                       # Tabs, list cards, dialogs
│  └─ theme/                 # Application theme
├─ assets/                   # Logos and icons
├─ Main.gd / Main.tscn       # Application shell
├─ export_presets.cfg        # Export configuration
└─ project.godot             # Godot project file
```

## Roadmap

- [ ] Automatic update checks for installed engines.
- [ ] Project templates.
- [ ] Persistent options for engine and project settings.
- [ ] Automated tests for pure logic (version parsing, project metadata).
- [ ] Additional export targets and installers.

## Contributing

Issues and pull requests are welcome. Please keep changes focused, follow the existing GDScript style, and make sure the project opens in Godot without parse errors.

## License

Released under the [MIT License](LICENSE).
