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
$testRoot = Join-Path $root ('.local/fudi-refinements-test-' + $testId)
$source = Join-Path $root 'card-demo'
foreach ($file in (Get-ChildItem -LiteralPath $source -Recurse -File)) {
    $relative = $file.FullName.Substring($source.Length + 1)
    if ($relative -match '(^|\\)\.godot(\\|$)') { continue }
    $target = Join-Path $testRoot $relative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [IO.File]::Copy($file.FullName, $target)
}
$configPath = Join-Path $testRoot 'project.godot'
$config = [IO.File]::ReadAllText($configPath).Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"Cun-Fudi-Refinements-$testId`"")
$config += "`n[threading]`nworker_pool/max_threads=1`n"
[IO.File]::WriteAllText($configPath, $config, (New-Object Text.UTF8Encoding($false)))
Write-Output "Evidence: $testRoot"
function Invoke-ProgressCheck([string]$Name, [string[]]$EngineArgs) {
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
        if (-not $process.WaitForExit(120000)) {
            $process.Kill()
            $process.WaitForExit()
            [IO.File]::WriteAllText((Join-Path $testRoot ($Name + '.log')), $stdout.Result + "`n" + $stderr.Result, [Text.Encoding]::UTF8)
            throw "$Name timed out; see $testRoot"
        }
        $output = $stdout.Result + "`n" + $stderr.Result
        $code = $process.ExitCode
    } finally { $process.Dispose() }
    $log = Join-Path $testRoot ($Name + '.log')
    [IO.File]::WriteAllText($log, $output, [Text.Encoding]::UTF8)
    if ($code -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error|^FAIL:)') { throw "$Name failed (exit $code). See $log" }
    if ($Name -ne 'import' -and $output -notmatch 'FUDI_REFINEMENTS_RESULT: \d+ checks, 0 failures') { throw "$Name exited without a complete successful report. See $log" }
    $output -split '\r?\n' | Where-Object { $_ -match 'FUDI_REFINEMENTS_(RESULT:|CAPTURE:|ENCOUNTER_REGION:)' } | Write-Output
}
Invoke-ProgressCheck 'import' @('--headless', '--path', $testRoot, '--editor', '--import', '--quit')
$checkArgs = @('--path', $testRoot, '--script', 'res://scripts/tests/fudi_refinements_smoke.gd')
if (-not $Render) { $checkArgs = @('--headless') + $checkArgs }
Invoke-ProgressCheck 'progress' $checkArgs
Invoke-ProgressCheck 'relaunch' ($checkArgs + @('--', '--verify-relaunch'))
