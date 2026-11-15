param([Parameter(Mandatory)][string]$Engine)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($test in @('persistence/test_repositories', 'persistence/test_process', 'editors/test_editor_overrides', 'editors/test_editor_catalog', 'editors/test_editor_ui')) {
    $output = & $Engine --headless --path $repoRoot --script "tests/$test.gd" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $output -match 'SCRIPT ERROR:' -or $output -notmatch 'passed') {
        Write-Output $output
        throw "$test failed"
    }
    Write-Output "$test passed"
}
