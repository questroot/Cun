# Real Godot checks in a fresh copy, with unique test save directories.
[CmdletBinding()]
param([string]$EnginePath = '', [switch]$Render)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher/Launcher.Core.ps1')
$paths = Get-CunPaths $root
if (-not $EnginePath) { $EnginePath = Find-CunEngine $paths }
if (-not $EnginePath) { Initialize-CunBundledEngine $paths | Out-Null; $EnginePath = Find-CunEngine $paths }
$engine = Get-CunEngineInfo $EnginePath '4.7'
if (-not $engine.Ready) { throw $engine.Message }
$testId = [guid]::NewGuid().ToString('N')
$testRoot = Join-Path $root ('.local/fudi-gm-test-' + $testId)
$source = Join-Path $root 'card-demo'
foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
    $relative = $file.FullName.Substring($source.Length + 1)
    if ($relative -match '(^|\\)\.godot(\\|$)') { continue }
    $target = Join-Path $testRoot $relative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [IO.File]::Copy($file.FullName, $target)
}
$configPath = Join-Path $testRoot 'project.godot'
$originalConfig = [IO.File]::ReadAllText($configPath)
function Set-TestSave([string]$Name) {
    $config = $originalConfig.Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$Name-$testId`"")
    [IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding($false)))
}
function Invoke-ExplorationCheck([string]$Name, [string[]]$EngineArgs) {
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $EnginePath
    $process.StartInfo.Arguments = ($EngineArgs | ForEach-Object { ConvertTo-CunArgument $_ }) -join ' '
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    try {
        if (-not $process.Start()) { throw "$Name could not start Godot." }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "$Name timed out after 60 seconds." }
        $output = $stdout.Result + "`n" + $stderr.Result
        $code = $process.ExitCode
    } finally { $process.Dispose() }
    $log = Join-Path $testRoot ($Name + '.log')
    [IO.File]::WriteAllText($log, $output, [Text.Encoding]::UTF8)
    if ($code -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error|^FAIL:)') { throw "$Name failed (exit $code). See $log" }
    $output -split '\r?\n' | Where-Object { $_ -match '_RESULT:|_CAPTURE:|SMOKE RESULT:' } | Write-Output
}
Set-TestSave 'Cun-Fudi-GM'
Invoke-ExplorationCheck 'import' @('--headless', '--path', $testRoot, '--editor', '--import', '--quit')
$explorationArgs = @('--path', $testRoot, '--script', 'res://scripts/tests/fudi_gm_smoke.gd')
if (-not $Render) { $explorationArgs = @('--headless') + $explorationArgs }
Invoke-ExplorationCheck 'fudi-gm' $explorationArgs
Set-TestSave 'Cun-Exploration'
Invoke-ExplorationCheck 'exploration' @('--headless', '--path', $testRoot, '--script', 'res://scripts/tests/exploration_smoke.gd')
Write-Output "Evidence: $testRoot"