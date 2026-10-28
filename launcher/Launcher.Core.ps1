# Windows PowerShell 5.1 compatible launcher helpers. No dependency installation.
$script:CunDefaultRoot = Split-Path -Parent $PSScriptRoot

function Get-CunPaths {
    param([string]$Root = $script:CunDefaultRoot)
    $rootPath = [IO.Path]::GetFullPath($Root)
    $local = Join-Path $rootPath '.local'
    return @{
        Root = $rootPath
        Project = Join-Path $rootPath 'card-demo'
        ProjectFile = Join-Path $rootPath 'card-demo\project.godot'
        Local = $local
        Settings = Join-Path $local 'launcher.settings.json'
        Log = Join-Path $local 'launcher.log'
        Snapshot = Join-Path $local 'project-snapshot.md'
        Status = Join-Path $rootPath 'PROJECT_STATUS.md'
    }
}

function Write-CunLog {
    param([hashtable]$Paths, [string]$Message)
    [IO.Directory]::CreateDirectory($Paths.Local) | Out-Null
    $line = '{0} {1}{2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message, [Environment]::NewLine
    [IO.File]::AppendAllText($Paths.Log, $line, (New-Object Text.UTF8Encoding($true)))
}

function Read-CunSettings {
    param([hashtable]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.Settings -PathType Leaf)) { return @{ EnginePath = '' } }
    try {
        $data = Get-Content -LiteralPath $Paths.Settings -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($data.version -ne 1 -or $data.engine_path -isnot [string]) { throw 'Invalid settings format' }
        return @{ EnginePath = $data.engine_path }
    } catch {
        Write-CunLog $Paths ('Settings ignored: ' + $_.Exception.Message)
        return @{ EnginePath = ''; Warning = '本机设置无法读取，请重新选择引擎。' }
    }
}

function Save-CunSettings {
    param([hashtable]$Paths, [string]$EnginePath)
    [IO.Directory]::CreateDirectory($Paths.Local) | Out-Null
    $temp = $Paths.Settings + '.tmp'
    $json = @{ version = 1; engine_path = $EnginePath } | ConvertTo-Json
    [IO.File]::WriteAllText($temp, $json, (New-Object Text.UTF8Encoding($true)))
    if (Test-Path -LiteralPath $Paths.Settings) {
        [IO.File]::Replace($temp, $Paths.Settings, ($Paths.Settings + '.bak'))
    } else { [IO.File]::Move($temp, $Paths.Settings) }
}

function Get-CunProjectInfo {
    param([hashtable]$Paths)
    if (-not (Test-Path -LiteralPath $Paths.ProjectFile -PathType Leaf)) { throw '缺少 card-demo/project.godot，请下载完整仓库，不要只复制启动器。' }
    $text = [IO.File]::ReadAllText($Paths.ProjectFile, [Text.Encoding]::UTF8)
    $name = 'Cun 原型'
    $scene = ''
    $required = '4.7'
    if ($text -match '(?m)^config/name="([^"]+)"') { $name = $Matches[1] }
    if ($text -match '(?m)^run/main_scene="([^"]+)"') { $scene = $Matches[1] }
    if ($text -match '(?m)^config/features=.*?"(\d+\.\d+)"') { $required = $Matches[1] }
    if (-not $scene.StartsWith('res://') -or $scene.Contains('..')) { throw '项目入口路径不合法。' }
    $scenePath = Join-Path $Paths.Project $scene.Substring(6).Replace('/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $scenePath -PathType Leaf)) { throw ('启动场景不存在：' + $scene) }
    return @{ Name = $name; MainScene = $scene; RequiredVersion = $required; ScenePath = $scenePath }
}

function Initialize-CunBundledEngine {
    param([hashtable]$Paths)
    $bundle = Join-Path $Paths.Root '.setup\Godot'
    $archive = Join-Path $bundle 'gui.zip'
    $manifestPath = Join-Path $bundle 'manifest.json'
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) { return '' }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw '内置引擎缺少校验清单，请重新获取完整仓库或手动选择可信Godot。' }
    $manifest = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($manifest.version -ne 1 -or $manifest.archive -ne 'gui.zip' -or $manifest.archive_sha256 -notmatch '^[a-f0-9]{64}$' -or @($manifest.files).Count -ne 2) { throw '内置引擎校验清单格式错误。' }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $manifest.archive_sha256 -or (Get-Item -LiteralPath $archive).Length -ne $manifest.archive_bytes) { throw '内置Godot压缩包校验失败，已阻止解压/运行。请重新下载完整仓库。' }
    $destination = Join-Path $Paths.Local 'godot'
    [IO.Directory]::CreateDirectory($destination) | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $expectedNames = @($manifest.files | ForEach-Object { $_.name })
        if (@($zip.Entries).Count -ne 2) { throw '内置引擎归档包含非预期条目。' }
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -notmatch '^Godot_v\d+\.\d+\.\d+-stable_win64(?:_console)?\.exe$' -or $expectedNames -notcontains $entry.FullName) { throw '内置引擎归档路径/名称不合法，已阻止越界解压。' }
        }
        foreach ($file in $manifest.files) {
            if ($file.name -notmatch '^Godot_v\d+\.\d+\.\d+-stable_win64(?:_console)?\.exe$' -or $file.sha256 -notmatch '^[a-f0-9]{64}$') { throw '内置引擎文件描述不合法。' }
            $entry = $zip.GetEntry($file.name)
            if (-not $entry -or $entry.Length -ne $file.bytes) { throw '内置引擎条目大小不匹配。' }
            $target = Join-Path $destination $file.name
            if (Test-Path -LiteralPath $target) {
                if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) { throw '已有本机缓存引擎与清单不符，不会自动覆盖，请手动选择可信引擎。' }
            } else {
                $temp = $target + '.extracting'
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $temp, $true)
                if ((Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) { throw '解压后的引擎指纹错误，已阻止运行。' }
                [IO.File]::Move($temp, $target)
            }
        }
    } finally { $zip.Dispose() }
    Write-CunLog $Paths 'Bundled Godot archive verified and extracted to local cache; no download.'
    return $destination
}

function Find-CunEngine {
    param([hashtable]$Paths, [string]$SavedPath = '')
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if ($SavedPath) { $candidates.Add($SavedPath) }
    if ($env:GODOT_EXE) { $candidates.Add($env:GODOT_EXE) }
    foreach ($name in @('godot', 'godot4', 'godot.exe', 'godot4.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $candidates.Add($command.Source) }
    }
    $folders = @('.setup\Godot', 'Godot_v4.7.2', 'Godot', 'vendor\godot', 'tools\godot', '.local\godot')
    foreach ($folder in $folders) {
        $path = Join-Path $Paths.Root $folder
        if (Test-Path -LiteralPath $path -PathType Container) {
            $files = Get-ChildItem -LiteralPath $path -Filter '*godot*.exe' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object @{Expression={ $_.Name -like '*console*' }}, FullName
            foreach ($file in $files) { $candidates.Add($file.FullName) }
        }
    }
    foreach ($candidate in $candidates) {
        if ([IO.Path]::GetExtension($candidate) -ieq '.exe' -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return [IO.Path]::GetFullPath($candidate) }
    }
    return ''
}

function ConvertTo-CunArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW quoting, including embedded quotes/trailing backslashes.
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Get-CunEngineInfo {
    param([string]$EnginePath, [string]$RequiredVersion = '4.7')
    if (-not $EnginePath -or -not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) { return @{ Ready = $false; Version = ''; Message = '未找到 Godot。请点击“选择 Godot”指定已有编辑器 exe。' } }
    if ([IO.Path]::GetExtension($EnginePath) -ine '.exe') { return @{ Ready = $false; Version = ''; Message = '请选择 Godot 的 Windows exe，不是项目文件或压缩包。' } }
    $p = New-Object Diagnostics.Process
    $p.StartInfo.FileName = $EnginePath
    $p.StartInfo.Arguments = '--version'
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.CreateNoWindow = $true
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    try {
        if (-not $p.Start()) { throw '无法启动版本检测。' }
        $stdoutTask = $p.StandardOutput.ReadToEndAsync()
        $stderrTask = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(5000)) { $p.Kill(); throw '版本检测超过5秒，已结束本次检测进程。' }
        $stdout = $stdoutTask.Result.Trim()
        $stderr = $stderrTask.Result.Trim()
        if ($p.ExitCode -ne 0 -or $stdout -notmatch '^(\d+)\.(\d+)(?:\.(\d+))?') { throw ('不是可识别的 Godot 引擎：' + $stdout + ' ' + $stderr) }
        $actual = New-Object Version ([int]$Matches[1]), ([int]$Matches[2])
        $required = New-Object Version $RequiredVersion
        $compatible = $actual.Major -eq $required.Major -and $actual.Minor -ge $required.Minor
        if (-not $compatible) { return @{ Ready = $false; Version = $stdout; Message = ('项目声明 Godot ' + $RequiredVersion + '，所选版本为 ' + $stdout + '。请选择同主版本且不低于声明版本的引擎；不会自动升级或改项目。') } }
        return @{ Ready = $true; Version = $stdout; Message = '引擎版本检查通过；项目导入与游戏运行仍以实际结果为准。' }
    } catch { return @{ Ready = $false; Version = ''; Message = $_.Exception.Message } }
    finally { $p.Dispose() }
}

function Get-CunLaunchArguments {
    param([hashtable]$Paths, [ValidateSet('Game', 'Editor')][string]$Mode = 'Game', [ValidateSet('Menu', 'Spirit', 'Fudi', 'Water')][string]$Game = 'Menu')
    $arguments = @('--path', $Paths.Project)
    if ($Mode -eq 'Editor') { $arguments += '--editor' }
    elseif ($Game -ne 'Menu') {
        $scene = @{ Spirit = 'res://scenes/MainCity.tscn'; Fudi = 'res://scenes/Fudi.tscn'; Water = 'res://scenes/WaterActivity.tscn' }[$Game]
        if (-not (Test-Path -LiteralPath (Join-Path $Paths.Project $scene.Substring(6)) -PathType Leaf)) { throw ('缺少游戏入口：' + $scene) }
        $arguments += $scene
    }
    return $arguments
}

function Invoke-CunProjectImport {
    param([hashtable]$Paths, [string]$EnginePath)
    Get-CunProjectInfo $Paths | Out-Null
    $process = New-Object Diagnostics.Process
    $process.StartInfo.FileName = $EnginePath
    $process.StartInfo.Arguments = (@('--headless','--path',$Paths.Project,'--editor','--import') | ForEach-Object { ConvertTo-CunArgument $_ }) -join ' '
    $process.StartInfo.WorkingDirectory = $Paths.Project
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    Write-CunLog $Paths 'Preparing Godot resources and global script classes before game launch.'
    try {
        if (-not $process.Start()) { throw '无法启动资源导入。' }
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(180000)) { $process.Kill(); throw '资源导入超过3分钟，已停止本次导入，未启动游戏。' }
        $output = $stdout.Result + "`n" + $stderr.Result
        if ($output) { Write-CunLog $Paths $output }
        if ($process.ExitCode -ne 0 -or $output -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error)') { throw '资源/脚本导入报告错误，游戏未启动。请查看启动日志中的具体文件与错误。' }
        $cache = Join-Path $Paths.Project '.godot\global_script_class_cache.cfg'
        if (-not (Test-Path -LiteralPath $cache -PathType Leaf)) { throw '导入后仍缺少脚本类型缓存，已阻止空白游戏窗口。请查看启动日志。' }
        Write-CunLog $Paths 'Godot import completed with no reported errors; launching game.'
    } finally { $process.Dispose() }
}

function Start-CunProject {
    param([hashtable]$Paths, [string]$EnginePath, [ValidateSet('Game', 'Editor')][string]$Mode = 'Game', [switch]$SkipVersionCheck, [ValidateSet('Menu', 'Spirit', 'Fudi', 'Water')][string]$Game = 'Menu')
    $project = Get-CunProjectInfo $Paths
    $launchArguments = Get-CunLaunchArguments $Paths $Mode $Game
    if (-not $SkipVersionCheck) {
        $engine = Get-CunEngineInfo $EnginePath $project.RequiredVersion
        if (-not $engine.Ready) { throw $engine.Message }
    }
    if ($Mode -eq 'Game') { Invoke-CunProjectImport $Paths $EnginePath }
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $EnginePath
    $info.Arguments = (($launchArguments | ForEach-Object { ConvertTo-CunArgument $_ }) -join ' ')
    $info.WorkingDirectory = $Paths.Project
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    # Local logs allow parse/import failures to be diagnosed; wait/read them in the UI without blocking it.
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw '进程未能启动。' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Write-CunLog $Paths ('Started ' + $Mode + ' PID=' + $process.Id)
    return @{ Process = $process; Stdout = $stdoutTask; Stderr = $stderrTask; Mode = $Mode }
}

function Write-CunSnapshot {
    param([hashtable]$Paths, [hashtable]$EngineInfo, [string]$EnginePath = '')
    [IO.Directory]::CreateDirectory($Paths.Local) | Out-Null
    $name = '读取失败'
    $scene = '未知'
    $required = '未知'
    $projectError = ''
    try {
        $project = Get-CunProjectInfo $Paths
        $name = $project.Name; $scene = $project.MainScene; $required = $project.RequiredVersion
    } catch { $projectError = $_.Exception.Message }
    $counts = @{}
    foreach ($table in @('units', 'skills', 'stages')) {
        try {
            $data = [IO.File]::ReadAllText((Join-Path $Paths.Project ('data\' + $table + '.json')), [Text.Encoding]::UTF8) | ConvertFrom-Json
            $counts[$table] = @($data.PSObject.Properties).Count
        } catch { $counts[$table] = '读取失败' }
    }
    $ready = '未就绪'
    if ($EngineInfo.Ready) { $ready = '仅版本检查通过，未证明游戏可玩' }
    $text = @"
# 本机项目状态快照

生成时间：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
触发：启动器打开/刷新/选择引擎；没有持续后台监听。

- 项目：$name
- 入口：$scene
- 项目声明版本：$required
- 所选引擎：$EnginePath
- 检测输出：$($EngineInfo.Version)
- 引擎状态：$ready
- 检测说明：$($EngineInfo.Message)
- 项目读取问题：$projectError
- 单位模板数：$($counts.units)
- 技能模板数：$($counts.skills)
- 关卡数：$($counts.stages)

此文件是本机派生快照，包含本机路径，不提交Git。
共享现状请读仓库根 PROJECT_STATUS.md；候选规划不等于已实现。
游戏启动后的具体失败请查看同目录 launcher.log，不自动认定测试通过。
"@
    [IO.File]::WriteAllText($Paths.Snapshot, $text, (New-Object Text.UTF8Encoding($true)))
    return $Paths.Snapshot
}
