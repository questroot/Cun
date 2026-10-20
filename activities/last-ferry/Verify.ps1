param([string]$EnginePath = '', [switch]$Window)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$project = Join-Path $PSScriptRoot 'game'
if (-not $EnginePath) { $EnginePath = Join-Path $workspace '.local\godot\Godot_v4.7.2-stable_win64_console.exe' }
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) { throw 'Godot not found. Pass -EnginePath.' }
$artifacts = Join-Path $workspace '.local\last-ferry-tests'
New-Item -ItemType Directory -Force -Path $artifacts | Out-Null
function Invoke-Checked([string]$Name, [string[]]$Arguments) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $lines = @(& $EnginePath @Arguments 2>&1)
    $code = $LASTEXITCODE
    $timer.Stop()
    $lines | Set-Content -LiteralPath (Join-Path $artifacts ($Name + '.log')) -Encoding UTF8
    $lines | ForEach-Object { Write-Host $_ }
    if ($code -ne 0 -or ($lines -match 'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:').Count -gt 0) { throw "$Name failed (exit $code). Inspect local validation log." }
    Write-Host ($Name + ' PASS; elapsed ' + $timer.Elapsed.TotalSeconds + 's')
}
Invoke-Checked 'import' @('--headless','--path',$project,'--editor','--import')
# Test scripts are maintained alongside the actual activity, not a mock model.
$test = Join-Path $project 'smoke_test.gd'
if (-not (Test-Path -LiteralPath $test)) { throw 'The actual rule test script is not ready: game/smoke_test.gd.' }
Invoke-Checked 'rules' @('--headless','--path',$project,'--script','res://smoke_test.gd')
if ($Window) {
    Invoke-Checked 'window' @('--path',$project,'--script','res://smoke_test.gd')
}
Write-Host 'These results do not constitute human playtest acceptance.'
