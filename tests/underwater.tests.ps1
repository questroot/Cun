# Godot 4.7 underwater and existing smoke checks; isolated project and user data only.
[CmdletBinding()]
param([string]$EnginePath = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher/Launcher.Core.ps1')
$paths = Get-CunPaths $root
if (-not $EnginePath) { $EnginePath = Find-CunEngine $paths }
if (-not $EnginePath) { $EnginePath = Initialize-CunBundledEngine $paths }
if (-not (Get-CunEngineInfo $EnginePath '4.7').Ready) { throw 'Godot 4.7 required' }
$console = $EnginePath -replace '(?<!_console)\.exe$', '_console.exe'
if (Test-Path -LiteralPath $console) { $EnginePath = $console }
$id = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $root ('.local/underwater-test-' + $id)
$source = Join-Path $root 'card-demo'
foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
    $relative = $file.FullName.Substring($source.Length + 1)
    if ($relative -match '(^|\\)\.godot(\\|$)') { continue }
    $target = Join-Path $testRoot $relative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [IO.File]::Copy($file.FullName, $target)
}
$configPath = Join-Path $testRoot 'project.godot'
$config = [IO.File]::ReadAllText($configPath).Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"Cun-Underwater-$id`"")
[IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding($false)))
foreach ($name in @('import', 'underwater', 'smoke')) {
    $arguments = @('--headless', '--path', $testRoot)
    if ($name -eq 'import') { $arguments += @('--editor', '--import', '--quit') }
    elseif ($name -eq 'underwater') { $arguments += @('--script', 'res://scripts/tests/underwater_smoke.gd') }
    else { $arguments += @('--script', 'res://scripts/tests/smoke_test.gd') }
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $EnginePath
    $process.StartInfo.Arguments = ($arguments | ForEach-Object { ConvertTo-CunArgument $_ }) -join ' '
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw 'Could not start Godot' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) { $process.Kill(); throw "$name timed out" }
        $output = $stdout.Result + "`n" + $stderr.Result
        $code = $process.ExitCode
    } finally { $process.Dispose() }
    $log = Join-Path $testRoot ($name + '.log')
    [IO.File]::WriteAllText($log, $output, [Text.Encoding]::UTF8)
    if ($code -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error|^FAIL:)') { throw "$name failed (exit $code). See $log" }
    $output -split '\r?\n' | Where-Object { $_ -match 'RESULT:' } | Write-Output
}
Write-Output "Evidence: $testRoot"
