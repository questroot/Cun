# Windows PowerShell 5.1. Keep this file UTF-8 with BOM for Chinese diagnostics.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('city', 'fudi', 'water', 'ferry')][string]$Game,
    [string]$EnginePath = '',
    [long]$ParentWindow = 0,
    [switch]$IsolatedFerry
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Launcher.Core.ps1')
$paths = Get-CunPaths
$run = $null
try {
    # The desktop launcher does not attach to an inherited play bridge.
    Remove-Item Env:CUN_PLAY_PORT,Env:CUN_PLAY_TOKEN -ErrorAction SilentlyContinue
    if ($IsolatedFerry -and $Game -ne 'ferry') { throw '隔离试玩仅支持末班渡船。' }
    # This distinction is specific to the new lobby; leave the classic entry's behavior intact.
    if ($Game -eq 'water') {
        $scripts = Join-Path $paths.Project 'scripts\scenes'
        $surface = Join-Path $scripts 'water_activity.gd'
        if (-not (Test-Path -LiteralPath $surface -PathType Leaf) -or
            -not (Test-Path -LiteralPath (Join-Path $scripts 'underwater_catalog.gd') -PathType Leaf) -or
            -not (Test-Path -LiteralPath (Join-Path $scripts 'underwater_exploration.gd') -PathType Leaf) -or
            -not ([IO.File]::ReadAllText($surface).Contains('preload("res://scripts/scenes/underwater_catalog.gd")'))) {
            throw '当前分支没有完整的海底水世界入口，旧浮台不作为替代。'
        }
    }
    if (-not $EnginePath) {
        $settings = Read-CunSettings $paths
        $EnginePath = Find-CunEngine $paths $settings.EnginePath
        if (-not $EnginePath) {
            Initialize-CunBundledEngine $paths | Out-Null
            $EnginePath = Find-CunEngine $paths
        }
    }
    if ($Game -eq 'ferry') {
        $play = Join-Path $paths.Root 'activities\last-ferry\Play.ps1'
        $activity = Join-Path $paths.Root 'activities\last-ferry\game'
        $activityPaths = $paths.Clone()
        $activityPaths.Project = $activity
        $activityPaths.ProjectFile = Join-Path $activity 'project.godot'
        $project = Get-CunProjectInfo $activityPaths
        $engine = Get-CunEngineInfo $EnginePath $project.RequiredVersion
        if (-not $engine.Ready) { throw $engine.Message }
        if (-not (Test-Path -LiteralPath $play -PathType Leaf)) { throw '找不到末班渡船的独立启动脚本。' }
        if ($IsolatedFerry) {
            $id = [guid]::NewGuid().ToString('N')
            $test = Join-Path $paths.Local ('mirror-ferry-' + $id)
            $copy = Join-Path $test 'game'
            $robocopy = Join-Path $env:SystemRoot 'System32\robocopy.exe'
            & $robocopy $activity $copy /E /XJ /SL /R:0 /W:0 /XD .godot .git .test-output /XF override.cfg /NFL /NDL /NJH /NJS /NP
            if ($LASTEXITCODE -ge 8) { throw '末班渡船工程副本创建失败。' }
            # Reject any copied links before opening or writing files in the copy.
            if (Get-ChildItem -LiteralPath $copy -Recurse -Force -ErrorAction Stop | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Select-Object -First 1) {
                throw '测试工程副本含链接，未运行。'
            }
            $config = Join-Path $copy 'project.godot'
            $text = [IO.File]::ReadAllText($config)
            $saveId = 'Cun-Mirror-Ferry-Test-' + $id
            $pattern = '(?m)^config/custom_user_dir_name="Cun-LastFerry-v1"\r?$'
            if (-not ($text -match $pattern) -or $text -notmatch '(?m)^config/use_custom_user_dir=true\r?$') { throw '未确认原存档配置，未运行测试。' }
            $text = $text -replace $pattern, ('config/custom_user_dir_name="' + $saveId + '"')
            [IO.File]::WriteAllText($config, $text, (New-Object Text.UTF8Encoding($false)))
            $activityPaths.Project = $copy
            $activityPaths.ProjectFile = $config
            $activityPaths.Log = Join-Path $test 'launcher.log'
            # Validate the exact Windows Roaming AppData target; never read production saves.
            $appData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
            if (-not $appData) { throw '无法确定 Windows 用户数据目录，未运行试玩。' }
            $expectedSave = [IO.Path]::GetFullPath((Join-Path $appData $saveId))
            if (Test-Path -LiteralPath $expectedSave) { throw '测试存档目录已存在，未运行试玩。' }
            # Probe a minimal configuration without running any game autoloads.
            $probeProject = Join-Path $test 'probe'
            [IO.Directory]::CreateDirectory($probeProject) | Out-Null
            $settings = "config_version=5`n[application]`nconfig/name=`"Cun Mirror Save Probe`"`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$saveId`"`n"
            [IO.File]::WriteAllText((Join-Path $probeProject 'project.godot'), $settings, (New-Object Text.UTF8Encoding($false)))
            $probe = Join-Path $paths.Root 'tools\play_mcp\probe_userdir.gd'
            if (-not (Test-Path -LiteralPath $probe -PathType Leaf)) { throw '缺少 Godot 存档路径校验脚本，未运行试玩。' }
            $check = New-Object Diagnostics.Process
            $check.StartInfo.FileName = $EnginePath
            $check.StartInfo.Arguments = (@('--headless','--path',$probeProject,'--script',$probe) | ForEach-Object { ConvertTo-CunArgument $_ }) -join ' '
            $check.StartInfo.WorkingDirectory = $probeProject
            $check.StartInfo.UseShellExecute = $false
            $check.StartInfo.CreateNoWindow = $true
            $check.StartInfo.RedirectStandardOutput = $true
            $check.StartInfo.RedirectStandardError = $true
            # Godot writes UTF-8 to redirected output, including Windows user paths.
            $check.StartInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
            $check.StartInfo.StandardErrorEncoding = [Text.Encoding]::UTF8
            try {
                if (-not $check.Start()) { throw '无法启动 Godot 存档路径校验。' }
                $checkOut = $check.StandardOutput.ReadToEndAsync()
                $checkErr = $check.StandardError.ReadToEndAsync()
                if (-not $check.WaitForExit(15000)) { $check.Kill(); throw 'Godot 存档路径校验超时，未运行试玩。' }
                $checkText = $checkOut.Result + "`n" + $checkErr.Result
                $reported = @($checkOut.Result -split '\r?\n' | Where-Object { $_.StartsWith('USER_DIR=') })
                if ($check.ExitCode -ne 0 -or $checkText -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error)' -or $reported.Count -ne 1) {
                    [Console]::Error.WriteLine($checkText)
                    throw '无法取得 Godot 实际存档路径，未运行试玩。'
                }
                $reportedPath = $reported[0].Substring(9).TrimEnd([char[]]@('/', '\'))
                if (-not [IO.Path]::IsPathRooted($reportedPath) -or [IO.Path]::GetFullPath($reportedPath) -ne $expectedSave -or (Test-Path -LiteralPath (Join-Path $expectedSave 'journey.json'))) {
                    throw 'Godot 未解析到预期的新存档目录，未运行试玩。'
                }
                Write-Output ('Mirror isolated ferry: ' + $test + '; save directory verified: ' + $reportedPath)
            } finally { $check.Dispose() }
        }
        # Use the project's own run/main_scene. The shared runner bounds import
        # time and returns the engine process (or its wait-and-exit-code wrapper).
        $run = Start-CunProject $activityPaths $EnginePath 'Game' -SkipVersionCheck -NoGlobalClasses -ParentWindow $ParentWindow
    } else {
        $target = @{ city = 'Spirit'; fudi = 'Fudi'; water = 'Water' }[$Game]
        # The shared runner validates exact scene availability before import.
        $run = Start-CunProject $paths $EnginePath 'Game' -Game $target -ParentWindow $ParentWindow
    }
    [Console]::Out.WriteLine(('Mirror engine launcher started: game={0}; launch_pid={1}' -f $Game, $run.Process.Id))
    $run.Process.WaitForExit()
    $exitCode = $run.Process.ExitCode
    [Console]::Out.WriteLine(('Mirror engine launcher exited: game={0}; launch_pid={1}; code={2}' -f $Game, $run.Process.Id, $exitCode))
    $outText = $run.Stdout.Result
    $errText = $run.Stderr.Result
    if ($outText) { [Console]::Out.WriteLine($outText) }
    if ($errText) { [Console]::Error.WriteLine($errText) }
    if ($ParentWindow -gt 0 -and $Game -ne 'ferry' -and $exitCode -eq 42) { exit 42 }
    if ($exitCode -ne 0 -or ($outText + "`n" + $errText) -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error)') {
        throw '游戏报告运行错误，请查看启动日志。'
    }
    exit 0
} catch {
    try { Write-CunLog $paths ('Mirror / ' + $Game + ': ' + $_.Exception.Message) } catch {}
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
} finally {
    if ($run) { $run.Process.Dispose() }
}
