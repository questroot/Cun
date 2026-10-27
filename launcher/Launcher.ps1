[CmdletBinding()]
param([switch]$Diagnose, [switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
$script:CoreFile = Join-Path $PSScriptRoot 'Launcher.Core.ps1'
. $script:CoreFile
$script:Paths = Get-CunPaths
$script:EnginePath = ''
$script:EngineInfo = @{ Ready = $false; Version = ''; Message = '尚未检测。' }
$script:Running = $null
$script:Worker = $null

function Update-CunEnvironment {
    $settings = Read-CunSettings $script:Paths
    $project = Get-CunProjectInfo $script:Paths
    $script:EnginePath = Find-CunEngine $script:Paths $settings.EnginePath
    $bundleError = ''
    if (-not $script:EnginePath) {
        try { Initialize-CunBundledEngine $script:Paths | Out-Null; $script:EnginePath = Find-CunEngine $script:Paths }
        catch { $bundleError = $_.Exception.Message; Write-CunLog $script:Paths $bundleError }
    }
    $script:EngineInfo = Get-CunEngineInfo $script:EnginePath $project.RequiredVersion
    if ($bundleError) { $script:EngineInfo.Message = $bundleError + ' 可点击“选择Godot”手动指定可信引擎。' }
    Write-CunSnapshot $script:Paths $script:EngineInfo $script:EnginePath | Out-Null
    return $project
}

try {
    $project = Update-CunEnvironment
    if ($Diagnose) {
        @{ project = $project.Name; scene = $project.MainScene; required = $project.RequiredVersion; engine = $script:EnginePath; ready = $script:EngineInfo.Ready; version = $script:EngineInfo.Version; message = $script:EngineInfo.Message; snapshot = $script:Paths.Snapshot } | ConvertTo-Json
        if ($script:EngineInfo.Ready) { exit 0 } else { exit 2 }
    }
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    [xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Cun · 游戏启动器" Width="1040" Height="760" MinWidth="900" MinHeight="720" WindowStartupLocation="CenterScreen" Background="#101B2B" Foreground="#E8F0F8" FontFamily="Microsoft YaHei" FontSize="14">
<Window.Resources>
<Style TargetType="Button"><Setter Property="Foreground" Value="#E8F0F8"/><Setter Property="Background" Value="#25394F"/><Setter Property="BorderBrush" Value="#42627A"/><Setter Property="Padding" Value="18,11"/><Setter Property="Margin" Value="0,0,10,10"/><Setter Property="Cursor" Value="Hand"/><Style.Triggers><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger></Style.Triggers></Style>
<Style TargetType="TextBox"><Setter Property="Background" Value="#142537"/><Setter Property="Foreground" Value="#E8F0F8"/><Setter Property="BorderBrush" Value="#42627A"/><Setter Property="Padding" Value="10"/></Style>
</Window.Resources>
<Grid Margin="26"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<StackPanel Margin="0,0,0,18"><TextBlock Text="CUN / PLAYTEST HUB" FontSize="13" Foreground="#8CD8C8"/><TextBlock Text="游戏启动器" FontSize="30" Margin="0,6,0,4"/><TextBlock Text="选择灵伴回合冒险、福地或海底水世界；各项目独立进入。" Foreground="#B0C4D5"/></StackPanel>
<Grid Grid.Row="1"><Grid.ColumnDefinitions><ColumnDefinition Width="1.05*"/><ColumnDefinition Width="1*"/></Grid.ColumnDefinitions>
<Border CornerRadius="12" Background="#1C3043" Margin="0,0,20,0" Padding="18"><Grid><Grid.RowDefinitions><RowDefinition Height="190"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
<Border CornerRadius="8" Background="#102231" ClipToBounds="True"><Image x:Name="Preview" Stretch="UniformToFill"/></Border>
<StackPanel Grid.Row="1" Margin="0,16,0,0"><ComboBox x:Name="GameChoice" SelectedIndex="0" Foreground="#102231" FontSize="17" Padding="10,6" Margin="0,0,0,10"><ComboBoxItem Content="游戏选择大厅"/><ComboBoxItem Content="灵伴回合冒险"/><ComboBoxItem Content="福地"/><ComboBoxItem Content="海底水世界"/></ComboBox><TextBlock x:Name="ProjectTitle" FontSize="22" TextWrapping="Wrap"/><TextBlock x:Name="GameDescription" Text="选择游戏，或进入大厅查看地图" Foreground="#8CD8C8" Margin="0,7,0,0"/><TextBlock Text="上方为仓库素材预览，不是本次实机截图。" Foreground="#A7BBCC" FontSize="12" Margin="0,5,0,0"/></StackPanel>
<StackPanel Grid.Row="2" Margin="0,20,0,0"><Button x:Name="Play" Content="▶  启动游戏" FontSize="19" Background="#176A5B" BorderBrush="#4EB39C" HorizontalContentAlignment="Center"/><WrapPanel><Button x:Name="Editor" Content="在 Godot 编辑器打开"/><Button x:Name="Folder" Content="项目文件夹"/></WrapPanel></StackPanel>
<TextBlock Grid.Row="3" Text="内置引擎在需要时校验解压。不联网下载，不改玩法或删除存档。" TextWrapping="Wrap" Foreground="#B0C4D5" FontSize="13" Margin="0,12,0,0"/>
</Grid></Border>
<ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto"><StackPanel>
<TextBlock Text="运行环境" FontSize="20"/><TextBlock x:Name="Requirement" Foreground="#B0C4D5" Margin="0,8,0,8"/>
<TextBox x:Name="EngineText" IsReadOnly="True" TextWrapping="Wrap" MinHeight="54"/>
<WrapPanel Margin="0,12,0,0"><Button x:Name="Browse" Content="选择 Godot"/><Button x:Name="Refresh" Content="刷新检测"/></WrapPanel>
<Border Background="#203449" Padding="12" CornerRadius="8"><TextBlock x:Name="EnvironmentStatus" TextWrapping="Wrap"/></Border>
<TextBlock Text="项目与协作入口" FontSize="20" Margin="0,22,0,12"/>
<WrapPanel><Button x:Name="StatusDoc" Content="共享项目状态"/><Button x:Name="Snapshot" Content="本机状态快照"/><Button x:Name="AgentKit" Content="个人 Agent 讨论材料"/><Button x:Name="Architecture" Content="架构规划"/><Button x:Name="Discussion" Content="讨论与选择页"/><Button x:Name="Log" Content="查看启动日志"/></WrapPanel>
<TextBlock Text="共享状态由每次工作核对维护；本机快照在打开/刷新时生成，没有后台持续监控。" Foreground="#B0C4D5" TextWrapping="Wrap" FontSize="12"/>
</StackPanel></ScrollViewer>
</Grid>
<Border Grid.Row="2" Background="#142537" Padding="12" CornerRadius="8" Margin="0,18,0,0"><TextBlock x:Name="Feedback" Text="就绪。请检查运行环境，或先查看共享项目状态。" TextWrapping="Wrap" Foreground="#C6DBE9"/></Border>
</Grid></Window>
'@
    $reader = New-Object Xml.XmlNodeReader $xaml
    $script:Window = [Windows.Markup.XamlReader]::Load($reader)
    $script:Controls = @{}
    foreach ($name in @('Preview','ProjectTitle','GameChoice','GameDescription','Play','Editor','Folder','Requirement','EngineText','Browse','Refresh','EnvironmentStatus','StatusDoc','Snapshot','AgentKit','Architecture','Discussion','Log','Feedback')) { $script:Controls[$name] = $script:Window.FindName($name) }
    $script:Controls.ProjectTitle.Text = '灵伴 / 福地 / 海底水世界'
    $script:Controls.GameChoice.Add_SelectionChanged({
        $index = $script:Controls.GameChoice.SelectedIndex
        $script:Controls.ProjectTitle.Text = @('灵伴 / 福地 / 海底水世界', '灵伴回合冒险', '福地', '海底水世界')[$index]
        $script:Controls.GameDescription.Text = @('选择游戏，或进入大厅查看地图', '主城探索 · 九宫格编队 · 回合战斗', 'WASD 移动 · J / K / L 攻击 · M 地图', '海面浮台出发下潜 · 海上进度独立保存')[$index]
    })
    $script:Controls.Requirement.Text = '项目声明 Godot ' + $project.RequiredVersion + ' / GL Compatibility'
    $previewPath = Join-Path $script:Paths.Root 'card-demo\assets\backgrounds\battle_courtyard_universal.png'
    if (Test-Path -LiteralPath $previewPath) {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad; $bitmap.UriSource = New-Object Uri $previewPath; $bitmap.EndInit(); $bitmap.Freeze()
        $script:Controls.Preview.Source = $bitmap
    }

    function Show-CunEnvironment {
        $script:Controls.EngineText.Text = $(if ($script:EnginePath) { $script:EnginePath } else { '尚未选择 Godot 引擎' })
        $script:Controls.EnvironmentStatus.Text = $script:EngineInfo.Message + $(if ($script:EngineInfo.Version) { "`n版本：" + $script:EngineInfo.Version } else { '' })
        $busy = ($null -ne $script:Running) -or ($null -ne $script:Worker)
        $script:Controls.Play.IsEnabled = $script:EngineInfo.Ready -and -not $busy
        $script:Controls.Editor.IsEnabled = $script:EngineInfo.Ready -and -not $busy
        $script:Controls.Browse.IsEnabled = -not $busy
        $script:Controls.Refresh.IsEnabled = -not $busy
        $script:Controls.GameChoice.IsEnabled = -not $busy
    }
    function Open-CunFile {
        param([string]$Relative)
        try {
            $file = Join-Path $script:Paths.Root $Relative
            if (-not (Test-Path -LiteralPath $file)) { throw ('文件还不存在：' + $Relative) }
            if ([IO.Path]::GetExtension($file) -in @('.md','.log','.json')) { Start-Process -FilePath 'notepad.exe' -ArgumentList (ConvertTo-CunArgument $file) | Out-Null }
            else { Start-Process -FilePath $file | Out-Null }
            $script:Controls.Feedback.Text = '已打开：' + $Relative
        } catch { $script:Controls.Feedback.Text = $_.Exception.Message }
    }
    function Invoke-CunLaunch {
        param([string]$Mode)
        try {
            if ($script:Running -or $script:Worker) { return }
            $shell = [PowerShell]::Create()
            $task = {
                param($CoreFile, $Paths, $Engine, $Mode, $Game)
                $ErrorActionPreference = 'Stop'
                . $CoreFile
                Start-CunProject $Paths $Engine $Mode -Game $Game
            }
            $game = @('Menu', 'Spirit', 'Fudi', 'Water')[$script:Controls.GameChoice.SelectedIndex]
            $shell.AddScript($task.ToString()).AddArgument($script:CoreFile).AddArgument($script:Paths).AddArgument($script:EnginePath).AddArgument($Mode).AddArgument($game) | Out-Null
            $script:Worker = @{ Shell = $shell; Async = $shell.BeginInvoke(); Mode = $Mode }
            $script:Controls.Feedback.Text = $(if ($Mode -eq 'Game') { '正在后台校验并导入资源/脚本，完成后才打开游戏；首次需等待，可查看日志。' } else { '正在准备编辑器，请稍候。' })
            Show-CunEnvironment
            $script:Timer.Start()
        } catch { Write-CunLog $script:Paths $_.Exception.Message; $script:Controls.Feedback.Text = $_.Exception.Message }
    }
    $script:Timer = New-Object Windows.Threading.DispatcherTimer
    $script:Timer.Interval = [TimeSpan]::FromMilliseconds(400)
    $script:Timer.Add_Tick({
        if ($script:Worker -and $script:Worker.Async.IsCompleted) {
            $worker = $script:Worker
            try {
                $result = $worker.Shell.EndInvoke($worker.Async)
                if ($worker.Shell.HadErrors -or $result.Count -ne 1) { throw ($worker.Shell.Streams.Error | Out-String) }
                $script:Running = $result[0].PSObject.BaseObject
                $script:Controls.Feedback.Text = '资源准备完成，已创建' + $(if ($worker.Mode -eq 'Game') { '游戏' } else { '编辑器' }) + '进程；启动结果记录到日志。'
            } catch {
                $script:Controls.Feedback.Text = '启动准备失败：' + $_.Exception.Message
                Write-CunLog $script:Paths $_.Exception.Message
                $script:Timer.Stop()
            } finally { $worker.Shell.Dispose(); $script:Worker = $null; Show-CunEnvironment }
        }
        if ($script:Running -and $script:Running.Process.HasExited) {
            $run = $script:Running
            Write-CunLog $script:Paths ('Exited ' + $run.Mode + ' code=' + $run.Process.ExitCode)
            $outText = $run.Stdout.Result; $errText = $run.Stderr.Result
            if ($outText) { Write-CunLog $script:Paths $outText }
            if ($errText) { Write-CunLog $script:Paths $errText }
            $errorDetected = $run.Process.ExitCode -ne 0 -or ($outText + "`n" + $errText) -match '(?m)(SCRIPT ERROR:|ERROR:|Parse Error)'
            $script:Controls.Feedback.Text = $(if ($errorDetected) { '运行报告错误，请查看启动日志；不要将此结果视为试玩通过。' } else { '进程已退出。是否完整可玩仍需实际试玩确认。' })
            $run.Process.Dispose(); $script:Running = $null; $script:Timer.Stop(); Show-CunEnvironment
        }
    })
    $script:Controls.Play.Add_Click({ Invoke-CunLaunch 'Game' })
    $script:Controls.Editor.Add_Click({ Invoke-CunLaunch 'Editor' })
    $script:Controls.Folder.Add_Click({ Start-Process -FilePath 'explorer.exe' -ArgumentList (ConvertTo-CunArgument $script:Paths.Project) | Out-Null })
    $script:Controls.Refresh.Add_Click({ try { Update-CunEnvironment | Out-Null; Show-CunEnvironment; $script:Controls.Feedback.Text = '已重新检测并更新本机快照。' } catch { $script:Controls.Feedback.Text = $_.Exception.Message } })
    $script:Controls.Browse.Add_Click({
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = '选择可信的 Godot Windows 编辑器 exe'
        $dialog.Filter = 'Godot / Windows executable (*.exe)|*.exe'
        if ($dialog.ShowDialog($script:Window)) {
            $candidate = $dialog.FileName
            $currentProject = Get-CunProjectInfo $script:Paths
            $result = Get-CunEngineInfo $candidate $currentProject.RequiredVersion
            if ($result.Ready) { Save-CunSettings $script:Paths $candidate; $script:EnginePath = $candidate; $script:EngineInfo = $result; Write-CunSnapshot $script:Paths $result $candidate | Out-Null; Show-CunEnvironment; $script:Controls.Feedback.Text = '已记住本机引擎路径，不会提交到 Git。' }
            else { $script:Controls.Feedback.Text = $result.Message }
        }
    })
    $script:Controls.StatusDoc.Add_Click({ Open-CunFile 'PROJECT_STATUS.md' })
    $script:Controls.Snapshot.Add_Click({ Open-CunFile '.local\project-snapshot.md' })
    $script:Controls.AgentKit.Add_Click({ Open-CunFile 'docs\design\agent-discussion-kit.md' })
    $script:Controls.Architecture.Add_Click({ Open-CunFile 'docs\architecture.md' })
    $script:Controls.Discussion.Add_Click({ Open-CunFile 'share\team-discussion.html' })
    $script:Controls.Log.Add_Click({ Open-CunFile '.local\launcher.log' })
    $script:Window.Add_Closing({
        param($sender, $eventArgs)
        if ($script:Worker) {
            $eventArgs.Cancel = $true
            $script:Controls.Feedback.Text = '正在准备资源，请等待完成或错误提示后再关闭；不会遗留导入进程。'
        } elseif ($script:Running) {
            # Keep the supervising launcher/log reader alive; never silently kill a running game/editor.
            $eventArgs.Cancel = $true
            $script:Controls.Feedback.Text = '请先从游戏/编辑器正常退出，再关闭启动器；不会强制结束你的进程。'
        } else { $script:Timer.Stop() }
    })
    Show-CunEnvironment
    Write-CunLog $script:Paths 'Launcher opened; no gameplay changes.'
    if ($SmokeTest) {
        $script:Window.Show()
        if ($script:Controls.GameChoice.Items.Count -ne 4 -or $script:Controls.GameChoice.Items[3].Content -ne '海底水世界') { throw 'Water project missing from launcher' }
        $script:Controls.GameChoice.SelectedIndex = 3
        $script:Window.UpdateLayout()
        if ($script:Controls.ProjectTitle.Text -ne '海底水世界' -or $script:Controls.GameDescription.Text -notlike '*海面浮台*') { throw 'Water project card mismatch' }
        $cardBounds = $script:Controls.GameDescription.TransformToAncestor($script:Window).TransformBounds((New-Object Windows.Rect 0, 0, $script:Controls.GameDescription.ActualWidth, $script:Controls.GameDescription.ActualHeight))
        if ($cardBounds.Bottom -gt $script:Controls.Play.TranslatePoint((New-Object Windows.Point 0, 0), $script:Window).Y) { throw 'Water description overlaps launch button' }
        $width = [int]$script:Window.ActualWidth; $height = [int]$script:Window.ActualHeight
        $target = New-Object Windows.Media.Imaging.RenderTargetBitmap $width, $height, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
        $target.Render($script:Window)
        $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($target))
        $preview = Join-Path $script:Paths.Local 'launcher-preview.png'
        $stream = [IO.File]::Create($preview)
        try { $encoder.Save($stream) } finally { $stream.Dispose() }
        if ($script:Controls.Play.IsEnabled -ne $script:EngineInfo.Ready) { throw 'Launch button state mismatch' }
        if (-not (Test-Path -LiteralPath $script:Paths.Snapshot)) { throw 'Snapshot not generated' }
        $script:Window.Close()
        Write-Output ('WPF UI SMOKE PASS; preview=' + $preview + '; engine_ready=' + $script:EngineInfo.Ready)
    } else { $script:Window.ShowDialog() | Out-Null }
} catch {
    try { Write-CunLog $script:Paths ('Launcher failed: ' + $_.Exception.Message) } catch {}
    if ($Diagnose -or $SmokeTest) { Write-Error $_.Exception.Message }
    else { Add-Type -AssemblyName PresentationFramework; [Windows.MessageBox]::Show($_.Exception.Message, 'Cun 启动器错误') | Out-Null }
    exit 1
}
