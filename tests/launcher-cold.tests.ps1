# Real Godot cold-start regression. Uses an isolated project and unique test save directory.
[CmdletBinding()]
param([string]$EnginePath = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher\Launcher.Core.ps1')
$rootPaths = Get-CunPaths $root
if (-not $EnginePath) { $EnginePath = Find-CunEngine $rootPaths }
if (-not $EnginePath) { Initialize-CunBundledEngine $rootPaths | Out-Null; $EnginePath = Find-CunEngine $rootPaths }
$engine = Get-CunEngineInfo $EnginePath '4.7'
if (-not $engine.Ready) { throw $engine.Message }
$base = Join-Path $root ('.local\cold-launch-' + [guid]::NewGuid().ToString('N'))
$paths = Get-CunPaths $base
[IO.Directory]::CreateDirectory($paths.Project) | Out-Null
$source = Join-Path $root 'card-demo'
foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
    $relative = $file.FullName.Substring($source.Length + 1)
    if ($relative -match '(^|\\)\.godot(\\|$)') { continue }
    $target = Join-Path $paths.Project $relative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [IO.File]::Copy($file.FullName, $target)
}
$config = [IO.File]::ReadAllText($paths.ProjectFile, [Text.Encoding]::UTF8)
$saveName = 'Cun-Cold-Launch-' + (Split-Path -Leaf $base)
$config = $config.Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$saveName`"")
[IO.File]::WriteAllText($paths.ProjectFile, $config, (New-Object Text.UTF8Encoding($false)))
$city = Join-Path $paths.Project 'scripts\scenes\main_menu.gd'
$text = [IO.File]::ReadAllText($city, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
if (-not $text.Contains("func _ready() -> void:`n")) { throw 'Cannot attach isolated capture to actual main-scene startup.' }
$text = $text.Replace("func _ready() -> void:`n", "func _ready() -> void:`n`tcall_deferred(`"_launcher_cold_capture`")`n")
$text += @'

func _launcher_cold_capture() -> void:
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: int = image.save_png("user://launcher_cold_preview.png")
	print("LAUNCHER_COLD_CAPTURE: %s %s" % ["PASS" if result == OK else "FAIL", ProjectSettings.globalize_path("user://launcher_cold_preview.png")])
	get_tree().quit(0 if result == OK else 1)
'@
[IO.File]::WriteAllText($city, $text, (New-Object Text.UTF8Encoding($false)))
if (Test-Path -LiteralPath (Join-Path $paths.Project '.godot')) { throw 'Cold project unexpectedly contains a cache.' }
$run = Start-CunProject $paths $EnginePath 'Game'
try {
    if (-not $run.Process.WaitForExit(45000)) { throw 'Cold game did not reach capture checkpoint within 45 seconds.' }
    $output = $run.Stdout.Result + "`n" + $run.Stderr.Result
    Write-CunLog $paths $output
    if ($run.Process.ExitCode -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error|LAUNCHER_COLD_CAPTURE: FAIL)') { throw ('Cold game reported errors. ' + $output) }
    if ($output -notmatch '(?m)^LAUNCHER_COLD_CAPTURE: PASS (.+\.png)') { throw 'Actual main scene did not render a screenshot.' }
    $image = $Matches[1].Trim()
    $destination = Join-Path $root '.local\launcher-cold-preview.png'
    [IO.File]::Copy($image, $destination, $true)
    Write-Output 'REAL COLD START PASS: no initial cache -> launcher import -> actual main scene -> rendered screenshot -> normal exit.'
    Write-Output ('Evidence: ' + $destination)
} finally {
    if (-not $run.Process.HasExited) { $run.Process.Kill() }
    $run.Process.Dispose()
}
