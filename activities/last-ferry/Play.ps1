param([string]$EnginePath = '', [switch]$Editor)
$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'game'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $EnginePath) {
    $EnginePath = Join-Path $workspace '.local\godot\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
    throw 'Godot not found. Prepare the bundled engine with the root launcher, or pass -EnginePath. This script does not download files.'
}
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) {
    throw 'Activity project is not ready: game/project.godot is missing.'
}
# Capture and inspect import diagnostics: Godot can exit 0 even after script errors.
$importLog = @(& $EnginePath --headless --path $project --editor --import 2>&1)
$importExit = $LASTEXITCODE
$importLog | ForEach-Object { Write-Host $_ }
if ($importExit -ne 0 -or ($importLog -match 'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:').Count -gt 0) {
    throw 'Import or script validation failed. Launch stopped; see diagnostics above.'
}
if ($Editor) {
    & $EnginePath --path $project --editor
} else {
    & $EnginePath --path $project
}
exit $LASTEXITCODE
