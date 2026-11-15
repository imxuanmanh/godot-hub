param([Parameter(Mandatory)][string]$Engine)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$checkRoot = Join-Path $repoRoot ('build\checks\' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path "$checkRoot\roaming", "$checkRoot\local" | Out-Null
$hashes = @{}
foreach ($path in @(Get-ChildItem (Join-Path $env:APPDATA 'Godot\editor_settings-*.tres') -ErrorAction SilentlyContinue)) {
    $hashes[$path.FullName] = (Get-FileHash -LiteralPath $path.FullName).Hash
}

foreach ($test in @('test_resolver', 'test_repositories', 'test_process', 'test_ui', 'test_error_ui')) {
    $info = [Diagnostics.ProcessStartInfo]::new($Engine)
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.WorkingDirectory = $repoRoot
    $info.Environment['APPDATA'] = "$checkRoot\roaming"
    $info.Environment['LOCALAPPDATA'] = "$checkRoot\local"
    foreach ($argument in @('--headless', '--path', $repoRoot, '--script', "tests/editor_settings/$test.gd")) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (!$process.WaitForExit(45000)) {
        $process.Kill($true)
        throw "$test timed out"
    }
    $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $checkRoot "$test.log"), $output)
    $unexpected = @($output -split "`n" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'ConfigFile parse error|Could not create child process' })
    if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:' -or $unexpected.Count -gt 0 -or $output -notmatch 'passed') {
        throw "$test failed; see $checkRoot\$test.log"
    }
    Write-Output "$test passed"
}
foreach ($path in $hashes.Keys) {
    if ((Get-FileHash -LiteralPath $path).Hash -ne $hashes[$path]) { throw "Global native settings changed: $path" }
}
Write-Output "Native settings hashes unchanged. Logs: $checkRoot"
