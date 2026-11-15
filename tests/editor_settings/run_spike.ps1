param(
    [Parameter(Mandatory)][string]$MonoEngine,
    [Parameter(Mandatory)][string]$HubEngine
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$spikeRoot = Join-Path $repoRoot 'build\editor-settings-spike'
$originalRoaming = $env:APPDATA
$originalLocal = $env:LOCALAPPDATA
$nativePath = Join-Path $originalRoaming 'Godot\editor_settings-4.6.tres'
$nativeHash = (Get-FileHash -LiteralPath $nativePath).Hash

function Start-FixtureProcess([string]$Executable, [string[]]$Arguments, [string]$Runtime, [string]$External = '') {
    $info = [System.Diagnostics.ProcessStartInfo]::new($Executable)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $info.Environment['APPDATA'] = Join-Path $Runtime 'roaming'
    $info.Environment['LOCALAPPDATA'] = Join-Path $Runtime 'local'
    $info.Environment['HUB_SPIKE_EXTERNAL'] = $External
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (!$process.Start()) { throw 'Spawn failed' }
    return @{
        Process = $process
        Output = $process.StandardOutput.ReadToEndAsync()
        Errors = $process.StandardError.ReadToEndAsync()
    }
}

function Wait-FixtureProcess($Job, [string]$Log) {
    if (!$Job.Process.WaitForExit(60000)) {
        $Job.Process.Kill($true)
        throw "Fixture timed out: $Log"
    }
    $output = $Job.Output.GetAwaiter().GetResult() + $Job.Errors.GetAwaiter().GetResult()
    [IO.File]::WriteAllText($Log, $output)
    if ($Job.Process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "Fixture failed: $Log`n$output"
    }
}

foreach ($id in @('A', 'B', 'export')) {
    $runtime = Join-Path $spikeRoot $id
    New-Item -ItemType Directory -Force -Path "$runtime\roaming\Godot", "$runtime\local", "$runtime\bootstrap\addons\probe" | Out-Null
    Copy-Item -LiteralPath $nativePath -Destination "$runtime\roaming\Godot\editor_settings-4.6.tres"
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bootstrap_probe.gd') -Destination "$runtime\bootstrap\addons\probe\probe.gd"
    [IO.File]::WriteAllText("$runtime\bootstrap\addons\probe\plugin.cfg", "[plugin]`nname=`"Probe`"`nscript=`"probe.gd`"`n")
    [IO.File]::WriteAllText("$runtime\bootstrap\project.godot", "config_version=5`n[application]`nconfig/name=`"Fixture $id`"`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/probe/plugin.cfg`")`n")
}

$a = Start-FixtureProcess $MonoEngine @('--headless', '--editor', '--path', "$spikeRoot\A\bootstrap") "$spikeRoot\A" 'false'
$b = Start-FixtureProcess $MonoEngine @('--headless', '--editor', '--path', "$spikeRoot\B\bootstrap") "$spikeRoot\B" 'true'
Wait-FixtureProcess $a "$spikeRoot\A\apply.log"
Wait-FixtureProcess $b "$spikeRoot\B\apply.log"
$aReport = Get-Content "$spikeRoot\A\bootstrap\report.json" -Raw | ConvertFrom-Json
$bReport = Get-Content "$spikeRoot\B\bootstrap\report.json" -Raw | ConvertFrom-Json
if ($aReport.external -or !$bReport.external -or $aReport.shortcut_count -ne $bReport.shortcut_count) { throw 'Isolation failed' }

# Open two real editor instances with their already prepared native settings.
foreach ($id in @('A', 'B')) {
    [IO.File]::WriteAllText("$spikeRoot\$id\project.godot", "config_version=5`n[application]`nconfig/name=`"Game $id`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n")
}
$a = Start-FixtureProcess $MonoEngine @('--headless', '--editor', '--path', "$spikeRoot\A", '--quit-after', '120', '--max-fps', '30') "$spikeRoot\A"
$b = Start-FixtureProcess $MonoEngine @('--headless', '--editor', '--path', "$spikeRoot\B", '--quit-after', '120', '--max-fps', '30') "$spikeRoot\B"
if ($a.Process.HasExited -or $b.Process.HasExited) { throw 'Editors did not overlap' }
Wait-FixtureProcess $a "$spikeRoot\A\editor.log"
Wait-FixtureProcess $b "$spikeRoot\B\editor.log"

# The .NET fixture uses the installed SDK/packages and writes only under build/.
$csRoot = Join-Path $spikeRoot 'CSharp fixture'
New-Item -ItemType Directory -Force -Path $csRoot | Out-Null
[IO.File]::WriteAllText("$csRoot\project.godot", "config_version=5`n[application]`nconfig/name=`"CSharp fixture`"`nrun/main_scene=`"res://Main.tscn`"`n[dotnet]`nproject/assembly_name=`"Fixture`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n")
[IO.File]::WriteAllText("$csRoot\Fixture.csproj", '<Project Sdk="Godot.NET.Sdk/4.6.3"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>')
[IO.File]::WriteAllText("$csRoot\Main.cs", 'using Godot; public partial class Main : Node { public override void _Ready() { using var f = FileAccess.Open("res://ran.txt", FileAccess.ModeFlags.Write); f.StoreString(OS.GetUserDataDir()); GetTree().Quit(); } }')
[IO.File]::WriteAllText("$csRoot\Main.tscn", "[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://Main.cs`" id=`"1`"]`n[node name=`"Main`" type=`"Node`"]`nscript=ExtResource(`"1`")`n")
$dotnetPath = (Get-Command dotnet).Source
$build = Start-FixtureProcess $dotnetPath @('build', "$csRoot\Fixture.csproj", '--nologo') "$spikeRoot\A"
Wait-FixtureProcess $build "$spikeRoot\dotnet-build.log"
$run = Start-FixtureProcess $MonoEngine @('--headless', '--path', $csRoot) "$spikeRoot\A"
Wait-FixtureProcess $run "$spikeRoot\dotnet-run.log"
if (!(Test-Path "$csRoot\ran.txt")) { throw '.NET fixture did not run' }

$exportRoot = Join-Path $spikeRoot 'export-source'
New-Item -ItemType Directory -Force -Path $exportRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bootstrap_probe.gd') -Destination "$exportRoot\probe.gd.txt"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_probe.gd') -Destination "$exportRoot\main.gd"
[IO.File]::WriteAllText("$exportRoot\project.godot", "config_version=5`n[application]`nconfig/name=`"Export probe`"`nrun/main_scene=`"res://main.tscn`"`n")
[IO.File]::WriteAllText("$exportRoot\main.tscn", "[gd_scene load_steps=2 format=3]`n[ext_resource type=`"Script`" path=`"res://main.gd`" id=`"1`"]`n[node name=`"Probe`" type=`"Node`"]`nscript=ExtResource(`"1`")`n")
[IO.File]::WriteAllText("$exportRoot\export_presets.cfg", "[preset.0]`nname=`"Windows`"`nplatform=`"Windows Desktop`"`nexport_filter=`"all_resources`"`ninclude_filter=`"*.txt`"`n[preset.0.options]`nbinary_format/embed_pck=true`napplication/modify_resources=false`n")
# Keep the actual installed templates visible only for this export invocation.
$exportInfo = [System.Diagnostics.ProcessStartInfo]::new($HubEngine)
$exportInfo.UseShellExecute = $false
$exportInfo.CreateNoWindow = $true
$exportInfo.Environment['APPDATA'] = "$spikeRoot\baseline\roaming"
$exportInfo.Environment['LOCALAPPDATA'] = "$spikeRoot\baseline\local"
$templateSource = Join-Path $originalRoaming 'Godot\export_templates\4.7.1.stable'
$templateTarget = "$spikeRoot\baseline\roaming\Godot\export_templates\4.7.1.stable"
New-Item -ItemType Directory -Force -Path $templateTarget | Out-Null
Copy-Item -Path "$templateSource\*.exe" -Destination $templateTarget
foreach ($argument in @('--headless', '--path', $exportRoot, '--export-debug', 'Windows', "$spikeRoot\export-probe.exe")) { $exportInfo.ArgumentList.Add($argument) }
$exportProcess = [System.Diagnostics.Process]::Start($exportInfo)
if (!$exportProcess.WaitForExit(60000) -or $exportProcess.ExitCode -ne 0) { throw 'Export failed' }
$run = Start-FixtureProcess "$spikeRoot\export-probe.exe" @('--headless', '--', $MonoEngine, "$spikeRoot\export") "$spikeRoot\baseline"
Wait-FixtureProcess $run "$spikeRoot\export-run.log"
$report = Get-Content "$spikeRoot\export\bootstrap\report.json" -Raw | ConvertFrom-Json
if (!$report.external) { throw 'Export helper did not apply settings' }
if ((Get-FileHash -LiteralPath $nativePath).Hash -ne $nativeHash) { throw 'Global native settings changed' }
Write-Output "Spike passed: $($report.version); A/B isolation, shortcut preservation, .NET build/run, exported helper, unchanged global native hash."
