# Verification report — 2026-11-15

Patch: **0.1.1**. Host: Windows. Hub host/export templates: **4.7.1.stable.official.a13da4feb**. Child .NET engine: **4.6.3.stable.mono.official.7d41c59c4**. Installed SDK: **10.0.301**. VSCode: **1.146.0**.

## Backend spike

The viable backend is a normal editor plugin in a disposable bootstrap project, launched with private APPDATA/LOCALAPPDATA. It uses the editor's own EditorSettings/ResourceSaver APIs. Two concurrent fixture editors using the same engine read different `use_external_editor` values. The copied native baseline retained its shortcut subresource. An exported probe materialized and executed the helper successfully.

A `--editor --script` experiment was discarded: early exit leaked editor resources. The final backend does not use that approach. Standard exported templates also disable the standalone `--script` path override; final Hub export verification uses its actual UI.

The original .NET installation under `C:/Tools` reported missing assemblies in the sandbox despite its Api directory existing. A complete copy under ignored `build/editor-settings-spike/engine/` worked, without modifying the installation. Fixtures and engine copies remain in `build/` for inspection.

## Results

| Check | Result |
| --- | --- |
| Baseline and final import/main scene | Passed on 4.7.1; final normal runs have no parse/runtime warnings |
| Resolver false/zero/empty, equal-value pinning, remove override | Passed |
| Missing default initialized Built-in | Passed |
| Unchanged inherited Save / Cancel | No override file created; no persisted edits |
| Default/project form, source labels, reset | Passed through real form/controller tests |
| Open / double-click / context-menu launch | All emit the same project/engine selection into the launch service |
| Default change after a project override | Per-key inheritance and explicit pinning passed |
| Engine marked Default independent of code editor | Separate persisted state; default editor reads cfg only |
| Legacy JSON | IDs added once; language, close-on-launch, binding, tags, pinning and extra fields retained |
| Rename / engine change / round trip | Stable ID retained |
| Missing / empty / corrupt cfg, future cfg/JSON schema | Expected behavior; original data retained; corruption tests intentionally emit parse diagnostics |
| Failed final rename / locked original / unwritable temp target | Save rejected; original readable content retained |
| Real directory-junction escape | Read/save rejected before writing outside the repository root |
| `_sc_` marker | Explicit unsupported error; marker contents unchanged |
| Child environment | Received requested values; Hub values/absence restored on success and failed spawn |
| Version lookup | Actual `--version`, non-blocking pipes, bounded wait; tested real engines |
| Two simultaneous real editors | Passed on 4.6.3 .NET and 4.7.1 Standard |
| Spaces / Unicode | Fixture paths opened correctly |
| Managed value changed inside Godot | Reapplied from cfg on next launch |
| Unmanaged native value changed inside Godot | Whitespace display setting retained across helper application |
| Global native settings hashes | Unchanged during isolated checks/backend tests; global files are only initial-copy sources |
| C# build/run | Passed with installed SDK/packages; Godot `--build-solutions` also passed |
| NuGet source comparison | Both commands succeeded; sources unchanged under private APPDATA |
| NuGet local paths | Global packages/temp unchanged; HTTP/plugin caches moved under private local |
| VSCode profile | Native Code process created logs under the original fixture profile, with no Code profile under private APPDATA |
| UI visual check | Default/project forms fit the default 1152×648 Hub window; Save/Cancel visible |
| Error while form is modal | Shell error dialog works without a second-exclusive-window error |
| Windows release export | Metadata is 0.1.1.0; helper cfg/text are bundled; actual UI launch creates a child surviving Hub close |
| Linux/macOS | Not run; feature UI rejects overrides and legacy launch is retained without overrides |

Normal import/main logs: `build/final-import.log`, `build/final-main.log`. Assert-suite logs are generated under `build/checks/<run-id>/`. Launch observers/results are under `build/launch-tests/<run-id>/`. The release UI fixture is under `build/export-integration/`; native helper results are under its Hub `runtime/<project-id>/bootstrap/` directory.

## Reproduction

```powershell
tests/editor_settings/run_checks.ps1 -Engine "<Godot 4.7.1 executable>"

& "<Godot 4.7.1 executable>" --headless --path . --script tests/editor_settings/test_launch.gd -- "<child Godot executable>"

tests/editor_settings/run_spike.ps1 -MonoEngine "<Godot 4.6.3 .NET executable>" -HubEngine "<Godot 4.7.1 executable>"
```

For path guards, create a fresh root under `build/`, a `projects/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` directory junction pointing to another disposable directory outside that root, and `portable/engine.exe` plus `_sc_` containing `marker`. Run `test_guards.gd -- <root>`; no override may appear in the junction target. The sandbox denied junction creation, so this one fixture operation was repeated outside it.

For locked-file failure, create a file containing `original`, hold a .NET FileStream open with FileAccess.Read and FileShare.Read, then run `test_write_failure.gd -- <file>`. Release the stream afterwards. `test_repositories.gd` additionally exercises an actual failed final rename and recovery, without mocking rename success.

For release UI verification, prepare a separate APPDATA/LOCALAPPDATA with one disposable observer project in the library and `close_on_launch=true`. Launch the exported Hub, select it and click Open. Verify the Hub exits, wait for `observed.cfg`, check `editor.pid` still names a live process, then create the fixture's `stop` file. Never use a real project as the observer fixture.

## Limits of the evidence

- C# restoration used existing cached Godot packages. A vulnerability-metadata fetch produced NU1900 because nuget.org was unavailable in the sandbox. Online restore with uncached dependencies was not established.
- VSCode process/profile creation needed an outside-sandbox retry. Its profile selection was verified through real log placement and the adapter's observed child environment; a visible VSCode editing session and extension behavior were not inspected.
- Exhausted physical disks, power loss, PID reuse and concurrent Hub instances were not simulated. Real rename/lock failures and `.bak` recovery were tested.
- There is no assertion of support for other engines, other IDEs, self-contained engines or other operating-system backends. Their unsupported cases are explicit in the product/docs.
- Export templates and existing game saves are not copied into private runtimes. Their changed locations are intentional and shown in the form; they remain important rollout considerations for existing projects.
