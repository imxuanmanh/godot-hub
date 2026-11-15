param([Parameter(Mandatory)][string]$Engine)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
foreach ($test in @('test_repositories', 'test_process')) {
    $output = & $Engine --headless --path $repoRoot --script "tests/persistence/$test.gd" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $output -match 'SCRIPT ERROR:' -or $output -notmatch 'passed') {
        Write-Output $output
        throw "$test failed"
    }
    Write-Output "$test passed"
}
