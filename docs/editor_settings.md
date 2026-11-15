# Editor defaults and project overrides — 0.1.1

Settings → General controls the default **GDScript code editor**, independently of the engine marked Default. A missing `settings.cfg` is initialized to Built-in. Subsequent launches always read the saved choice.

Projects → Editor settings… opens the project form. Each Override checkbox pins only that field. Unchecking it removes the key, so the next launch inherits the latest default. Saving an unchanged inherited form creates no override file. Cancel writes nothing. Built-in needs no external executable or arguments; existing unused values can remain stored.

## Resolution

For each key: project override → Hub default → native engine baseline. Key existence matters: `false`, zero and an empty string are values. An override equal to the current default remains pinned when the default changes. Zero is covered by the general resolver tests; none of the three supported editor fields is numeric.

Supported `[editor]` keys:

| Key | Type |
| --- | --- |
| `text_editor/external/use_external_editor` | Boolean |
| `text_editor/external/exec_path` | String |
| `text_editor/external/exec_flags` | String |

Unknown editor keys and wrong types produce diagnostics. Other sections and unknown keys survive repository round trips. The form cannot edit unsupported keys; correct those manually before opening it or launching. A Native field without a Hub value is engine-specific and is resolved/validated by the helper at launch, so its exact native path/arguments are not previewed in the form.

Initial default:

```ini
[meta]
schema_version=1

[editor]
text_editor/external/use_external_editor=false
```

A project can pin only Built-in using the same editor key with `false`, or pin External with an executable and arguments. VSCode arguments commonly use `{project} --goto {file}:{line}:{col}`. Executables must be existing absolute paths when External is active. No shell command is assembled by Hub.

## Storage and recovery

All paths below are under Hub's `user://` directory:

```text
godot_hub_data.json                         # schema 1; stable project IDs
settings.cfg                               # schema 1
projects/<id>/settings.override.cfg         # schema 1; sparse
runtime/<id>/bootstrap/                     # disposable editor-only helper project
runtime/<id>/roaming/Godot/                 # private native settings and editor data
runtime/<id>/local/                         # private Godot cache
runtime/<id>/editor.pid                     # prevents applying settings to a running editor
```

IDs survive search, pinning, renaming, reordering and engine changes. They are opaque random IDs, never project names or list indices. Paths are derived from trusted roots; traversal, existing symbolic links and directory junctions are rejected. Runtime paths cannot be supplied by cfg.

The JSON migration retains versions, bindings, language, close-on-launch, tags, pinning and additional fields. Migration does not create project overrides. Corrupt files or unknown schema versions are preserved and reported. The Hub library becomes read-only after a failed load.

Saves write/flush a `.tmp`, move the previous file to `.bak`, then rename the temporary file. This avoids relying on Godot's Windows rename to preserve an existing target. Failed replacement attempts restore the old file; if restoration is also blocked, the backup remains available. A missing main file is recovered from `.bak` before defaults are initialized. UI state commits only after saving succeeds. Do not run multiple Hub instances against the same data directory while editing or launching.

Removing a library entry leaves overrides and runtime data intact. No cleanup runs automatically. A stale `editor.pid` containing `pending` after a crash requires checking that the editor is closed before manually removing the marker. PID reuse may conservatively block a launch; the error includes its marker path.

## Native application and isolation

These cfg files belong to Hub; they are not Godot's ProjectSettings `override.cfg` and are not read automatically by Godot.

On Windows the adapter verifies the executable's real `--version`, rejects self-contained markers, then prepares a private APPDATA/LOCALAPPDATA for that project. On first use of each native settings filename, it copies the matching global `.tres` baseline. Later launches retain that project's native settings, including unrelated theme/shortcut changes.

A small editor-only plugin runs in Hub's own bootstrap project. It uses `EditorInterface.get_editor_settings()` and `ResourceSaver` to apply supported keys, validates the native external executable and writes a result. Hub never parses `.tres` with regex or installs an addon in a user project. The bootstrap source is bundled as `.gd.txt` so exported Hub runtimes can materialize it without loading editor-only APIs themselves. Native resources have a recovery backup around helper application.

The final editor starts only after a successful helper result. Hub restores both environment values and previously absent variables immediately after each spawn, before awaiting or logging. `close_on_launch` runs only after a positive editor PID; that PID alone does not prove editor initialization has finished. Editors remain independent of Hub's lifetime.

Inside Godot, changes to the three managed fields do not create Hub overrides. The next launch reapplies cfg values. Other native settings persist in the private baseline. Later changes to global native settings are not automatically recopied into existing runtimes.

## Platform scope and side effects

| Area | Policy / verified behavior |
| --- | --- |
| Windows builds | Godot `4.6.3.stable.mono.official.7d41c59c4` and `4.7.1.stable.official.a13da4feb` |
| Other engine versions | Rejected with their actual version; no silent native fallback |
| Self-contained engines | `_sc_` / `._sc_` rejected; installations and markers are unchanged |
| Linux/macOS | Legacy native launch without project overrides; editor settings UI reports unsupported |
| Native settings | Global files are read as initial baselines, never modified by applying Hub settings |
| Godot `user://` | Editor-launched games use the project's private roaming directory, including custom user directories; existing global saves are untouched and are not copied |
| Cache / editor data | Godot cache is private under local; editor data/Mono build logs are private under roaming |
| Export templates | Private per runtime; install templates there when required. Existing global templates are not copied for user projects |
| VSCode | Original `VSCODE_APPDATA` is preserved. Otherwise Hub supplies the original APPDATA as `VSCODE_APPDATA`, except when arguments explicitly contain `--user-data-dir`. Portable VSCode retains its own native precedence |
| SDK / NuGet | USERPROFILE, SDK installation, NuGet sources and global packages are retained. HTTP and plugin caches follow private LOCALAPPDATA; temporary files retain the normal temp path. C# build/run and Godot `--build-solutions` passed |
| Other external IDEs | Their own APPDATA behavior has not been verified; this release's external-editor proof is scoped to VSCode |
| C# code editor | Separate from GDScript editor selection; no .NET editor enum/UI is added |

No profiles, hot sync, arbitrary Resource/shortcut editor, imports/exports, cloud sync or automatic native-to-cfg synchronization are included.

## Verification

Run `tests/editor_settings/run_checks.ps1 -Engine <Godot-4.7.1-executable>` after importing the project. It runs assert-based GDScript tests in disposable data roots and checks global native hashes. Deliberate corrupt-file/spawn-failure tests produce expected diagnostics, which the runner distinguishes from script failures.

`test_launch.gd` accepts the engine executable after `--` and creates disposable projects. `run_spike.ps1` accepts `-MonoEngine` and `-HubEngine`, requires installed 4.7.1 Windows export templates and builds a C# fixture using the existing SDK/packages. Junction and locked-file guards use the two small guard scripts described in the verification report. Test fixtures remain under ignored `build/`; none is installed into real projects.

Official references: [EditorSettings](https://docs.godotengine.org/en/4.6/classes/class_editorsettings.html), [process/environment APIs](https://docs.godotengine.org/en/4.6/classes/class_os.html), [data paths](https://docs.godotengine.org/en/4.6/tutorials/io/data_paths.html), [Windows paths implementation](https://github.com/godotengine/godot/blob/4.6-stable/platform/windows/os_windows.cpp), [VSCode user-data resolution](https://github.com/microsoft/vscode/blob/main/src/vs/platform/environment/node/userDataPath.ts).
