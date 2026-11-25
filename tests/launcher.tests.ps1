# Native Windows tests. The compiled fixture is NOT Godot or a gameplay test.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'launcher\Launcher.Core.ps1')
$script:checks = 0
function Assert-Cun {
    param([bool]$Condition, [string]$Label)
    if (-not $Condition) { throw ('FAIL: ' + $Label) }
    $script:checks += 1
    Write-Output ('PASS: ' + $Label)
}

foreach ($file in @('launcher\Launcher.Core.ps1','launcher\Launcher.ps1','tests\launcher.tests.ps1')) {
    $tokens = $null; $errors = $null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$errors) | Out-Null
    Assert-Cun (@($errors).Count -eq 0) ('PowerShell parses: ' + $file)
}
$tempRoot = Join-Path $root ('.local\launcher-test-' + [guid]::NewGuid().ToString('N') + '\project with spaces 中文')
[IO.Directory]::CreateDirectory((Join-Path $tempRoot 'card-demo\scenes')) | Out-Null
[IO.Directory]::CreateDirectory((Join-Path $tempRoot 'card-demo\data')) | Out-Null
$paths = Get-CunPaths $tempRoot
[IO.File]::WriteAllText($paths.ProjectFile, "config/name=`"Fixture only`"`nrun/main_scene=`"res://scenes/MainCity.tscn`"`nconfig/features=PackedStringArray(`"4.7`", `"GL Compatibility`")", [Text.Encoding]::UTF8)
[IO.File]::WriteAllText((Join-Path $paths.Project 'scenes\MainCity.tscn'), '[gd_scene format=3]', [Text.Encoding]::UTF8)
foreach ($table in @('units','skills','stages')) { [IO.File]::WriteAllText((Join-Path $paths.Project ('data\' + $table + '.json')), '{"one":{}}', [Text.Encoding]::UTF8) }
$info = Get-CunProjectInfo $paths
Assert-Cun ($info.Name -eq 'Fixture only' -and $info.RequiredVersion -eq '4.7') 'Project metadata is read, not hardcoded'
$missing = Get-CunEngineInfo ''
Assert-Cun (-not $missing.Ready) 'Missing engine is explicitly not ready'
$badProject = Get-CunPaths (Join-Path $tempRoot 'missing')
$thrown = $false
try { Get-CunProjectInfo $badProject | Out-Null } catch { $thrown = $true }
Assert-Cun $thrown 'Missing project does not launch'
$fixture = Join-Path $tempRoot 'FakeGodot.exe'
$source = @'
using System;
using System.IO;
public class CunLauncherFixture {
  public static int Main(string[] args) {
    if (args.Length == 1 && args[0] == "--version") {
      Console.WriteLine(Environment.GetEnvironmentVariable("CUN_FIXTURE_VERSION") ?? "4.7.2.stable.fixture");
      return 0;
    }
    if (Array.IndexOf(args, "--import") >= 0) {
      if (Environment.GetEnvironmentVariable("CUN_FIXTURE_IMPORT_ERROR") == "1") {
        Console.Error.WriteLine("SCRIPT ERROR: fixture import error, exit still zero");
        return 0;
      }
      if (Environment.GetEnvironmentVariable("CUN_FIXTURE_IMPORT_SKIP_CACHE") != "1") {
        string project = args[Array.IndexOf(args, "--path") + 1];
        string cache = Path.Combine(project, ".godot");
        string artifacts = Path.Combine(cache, "imported");
        Directory.CreateDirectory(artifacts);
        File.WriteAllText(Path.Combine(artifacts, "fixture.ctex"), "fixture artifact");
        File.WriteAllText(Path.Combine(cache, "global_script_class_cache.cfg"), "fixture only, not real Godot import");
      }
      return 0;
    }
    File.WriteAllLines(Environment.GetEnvironmentVariable("CUN_FIXTURE_ARGS"), args);
    return 0;
  }
}
'@
Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $fixture -OutputType ConsoleApplication
$env:CUN_FIXTURE_VERSION = '4.7.2.stable.fixture'
$engine = Get-CunEngineInfo $fixture '4.7'
Assert-Cun $engine.Ready 'Compatible version output accepted (fixture only)'
$env:CUN_FIXTURE_VERSION = '4.6.0.stable.fixture'
Assert-Cun (-not (Get-CunEngineInfo $fixture '4.7').Ready) 'Older declared minor is blocked'
$env:CUN_FIXTURE_VERSION = '5.0.0.stable.fixture'
Assert-Cun (-not (Get-CunEngineInfo $fixture '4.7').Ready) 'Different major is blocked'
$env:CUN_FIXTURE_VERSION = 'not an engine'
Assert-Cun (-not (Get-CunEngineInfo $fixture '4.7').Ready) 'Non-version output is blocked'
$env:CUN_FIXTURE_VERSION = '4.7.2.stable.fixture'
Save-CunSettings $paths $fixture
Assert-Cun ((Read-CunSettings $paths).EnginePath -eq $fixture) 'Local settings roundtrip'
Save-CunSettings $paths $fixture
Assert-Cun ((Read-CunSettings $paths).EnginePath -eq $fixture) 'Atomic settings replacement'
[IO.File]::WriteAllText($paths.Settings, '{broken', [Text.Encoding]::UTF8)
Assert-Cun ((Read-CunSettings $paths).EnginePath -eq '') 'Malformed settings are ignored with warning'
Assert-Cun ((Find-CunEngine $paths $fixture) -eq $fixture) 'Saved path discovery'
$env:CUN_FIXTURE_ARGS = Join-Path $tempRoot 'argv.txt'
foreach ($mode in @('Game', 'Editor')) {
    $run = Start-CunProject $paths $fixture $mode
    Assert-Cun ($run.Process.WaitForExit(5000)) ('Fixture process ends: ' + $mode)
    Assert-Cun ($run.Process.ExitCode -eq 0) ('Fixture process exits zero: ' + $mode)
    $argv = [IO.File]::ReadAllLines($env:CUN_FIXTURE_ARGS)
    Assert-Cun ($argv[0] -eq '--path' -and $argv[1] -eq $paths.Project) ('Spaces and Unicode survive process arguments: ' + $mode)
    Assert-Cun (($argv -contains '--editor') -eq ($mode -eq 'Editor')) ('Correct game/editor flags: ' + $mode)
    $run.Process.Dispose()
}
Assert-Cun (Test-Path -LiteralPath (Join-Path $paths.Project '.godot\global_script_class_cache.cfg')) 'Game start prepared script cache before creating game process'
[IO.File]::WriteAllText((Join-Path $paths.Project 'scenes\Fudi.tscn'), '[gd_scene format=3]', [Text.Encoding]::UTF8)
[IO.File]::WriteAllText((Join-Path $paths.Project 'scenes\WaterActivity.tscn'), '[gd_scene format=3]', [Text.Encoding]::UTF8)
foreach ($selection in @('Spirit', 'Fudi', 'Water')) {
    $run = Start-CunProject $paths $fixture 'Game' -Game $selection
    Assert-Cun ($run.Process.WaitForExit(5000)) ('Selected game starts: ' + $selection)
    $argv = [IO.File]::ReadAllLines($env:CUN_FIXTURE_ARGS)
    $expected = @{ Spirit = 'res://scenes/MainCity.tscn'; Fudi = 'res://scenes/Fudi.tscn'; Water = 'res://scenes/WaterActivity.tscn' }[$selection]
    Assert-Cun ($argv -contains $expected) ('Selected scene survives process arguments: ' + $selection)
    $run.Process.Dispose()
}
$run = Start-CunProject $paths $fixture 'Game' -Game 'Water' -ParentWindow 123456
Assert-Cun ($run.Process.WaitForExit(5000)) 'Embedded launch passes through the engine fixture'
$argv = [IO.File]::ReadAllLines($env:CUN_FIXTURE_ARGS)
Assert-Cun (($argv -join '|') -ceq "--wid|123456|--single-window|--position|-30000,-30000|--path|$($paths.Project)|res://scenes/WaterActivity.tscn|--|--cun-scroll") 'Embedded route passes exact HWND, scene and handoff flag'
$run.Process.Dispose()
$receiptPath = Join-Path $paths.Project '.godot\.cun-import-v1'
Assert-Cun ([IO.File]::Exists($receiptPath)) 'Successful embedded import writes a local reuse receipt'
# Failing the import sentinel proves the next call never invokes it on a hit.
$env:CUN_FIXTURE_IMPORT_ERROR = '1'
$run = Start-CunProject $paths $fixture 'Game' -Game 'Water' -ParentWindow 123456
Assert-Cun ($run.Process.WaitForExit(5000)) 'Unchanged cached resources bypass the importer'
$run.Process.Dispose()
[IO.File]::Delete((Join-Path $paths.Project '.godot\imported\fixture.ctex'))
$blocked = $false
try { Start-CunProject $paths $fixture 'Game' -Game 'Water' -ParentWindow 123456 | Out-Null } catch { $blocked = $true }
Assert-Cun ($blocked -and -not [IO.File]::Exists($receiptPath)) 'Deleted import artifact forces validation; failed import leaves no receipt'
Remove-Item Env:CUN_FIXTURE_IMPORT_ERROR
$run = Start-CunProject $paths $fixture 'Game' -Game 'Water' -ParentWindow 123456
Assert-Cun ($run.Process.WaitForExit(5000)) 'Clean import recovers after artifact loss'
$run.Process.Dispose()
[IO.File]::AppendAllText((Join-Path $paths.Project 'scenes\WaterActivity.tscn'), "`n; resource edit")
$env:CUN_FIXTURE_IMPORT_ERROR = '1'
$blocked = $false
try { Start-CunProject $paths $fixture 'Game' -Game 'Water' -ParentWindow 123456 | Out-Null } catch { $blocked = $true }
Assert-Cun ($blocked -and -not [IO.File]::Exists($receiptPath)) 'Source changes invalidate the import receipt'
Remove-Item Env:CUN_FIXTURE_IMPORT_ERROR
$shell = [PowerShell]::Create()
$task = { param($CoreFile, $Paths, $Engine) $ErrorActionPreference='Stop'; . $CoreFile; Start-CunProject $Paths $Engine 'Game' }
$shell.AddScript($task.ToString()).AddArgument((Join-Path $root 'launcher\Launcher.Core.ps1')).AddArgument($paths).AddArgument($fixture) | Out-Null
$async = $shell.BeginInvoke()
Assert-Cun ($async.AsyncWaitHandle.WaitOne(10000)) 'Background startup prepares without blocking the UI thread'
$result = $shell.EndInvoke($async)
$workerRun = $result[0].PSObject.BaseObject
Assert-Cun (-not $shell.HadErrors -and $result.Count -eq 1 -and $workerRun.Mode -eq 'Game') 'Background worker returns the real process record to UI timer'
$workerRun.Process.WaitForExit(5000) | Out-Null
$workerRun.Process.Dispose(); $shell.Dispose()
$prefs = ([Environment]::GetFolderPath('ApplicationData') + '/Godot/editor_settings-4.7.tres').Replace('\','/')
$noise = "ERROR: Failed to read the root certificate store.`nERROR: Cannot save file '$prefs'.`nERROR: Error saving editor settings to $prefs"
Assert-Cun (-not (Get-CunBlockingImportError $noise)) 'Offline import ignores only the reported editor-profile diagnostics'
foreach ($real in @('ERROR: Cannot save file ''res://editor_settings-4.7.tres''.', 'SCRIPT ERROR: invalid preload', 'Parse Error: unexpected token', 'ERROR: Failed to import res://art.png')) {
    Assert-Cun ((Get-CunBlockingImportError ($noise + "`n" + $real)) -ceq $real) ('Real failure survives editor noise: ' + $real)
}
$env:CUN_FIXTURE_IMPORT_ERROR = '1'
$blocked = $false
try { Start-CunProject $paths $fixture 'Game' | Out-Null } catch { $blocked = $true }
Assert-Cun $blocked 'Zero-exit import script errors still block game startup'
Remove-Item Env:CUN_FIXTURE_IMPORT_ERROR -ErrorAction SilentlyContinue
$coldRoot = Join-Path $tempRoot 'cold-fixture'
[IO.Directory]::CreateDirectory((Join-Path $coldRoot 'card-demo\scenes')) | Out-Null
$coldPaths = Get-CunPaths $coldRoot
[IO.File]::Copy($paths.ProjectFile, $coldPaths.ProjectFile)
[IO.File]::Copy((Join-Path $paths.Project 'scenes\MainCity.tscn'), (Join-Path $coldPaths.Project 'scenes\MainCity.tscn'))
$env:CUN_FIXTURE_IMPORT_SKIP_CACHE = '1'
$blocked = $false
try { Start-CunProject $coldPaths $fixture 'Game' | Out-Null } catch { $blocked = $true }
Assert-Cun $blocked 'Successful exit without a script cache still blocks startup'
Remove-Item Env:CUN_FIXTURE_IMPORT_SKIP_CACHE -ErrorAction SilentlyContinue
$quoted = ConvertTo-CunArgument 'a"b\'
Assert-Cun ($quoted -eq '"a\"b\\"') 'Embedded quote and trailing slash quoting'
$snapshot = Write-CunSnapshot $paths $engine $fixture
$content = [IO.File]::ReadAllText($snapshot, [Text.Encoding]::UTF8)
Assert-Cun ($content.Contains('关卡数：1') -and $content.Contains('没有持续后台监听')) 'Snapshot has measured data and explicit scope'
Assert-Cun ((Test-Path -LiteralPath $paths.Log) -and -not (Test-Path -LiteralPath (Join-Path $tempRoot 'card-demo\spirit_save.json'))) 'Launcher log exists; game save is not changed'
# A tiny fixture archive validates the bundled-engine path without redistributing fake engines.
$bundle = Join-Path $tempRoot '.setup\Godot'
$sourceDir = Join-Path $tempRoot 'package-files'
[IO.Directory]::CreateDirectory($bundle) | Out-Null
[IO.Directory]::CreateDirectory($sourceDir) | Out-Null
$names = @('Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe')
$descriptions = @()
foreach ($name in $names) {
    $file = Join-Path $sourceDir $name
    [IO.File]::Copy($fixture, $file)
    $descriptions += @{ name = $name; bytes = (Get-Item -LiteralPath $file).Length; sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $bundle 'gui.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($sourceDir, $zipPath)
$manifest = @{ version = 1; engine_version = '4.7.2.fixture'; archive = 'gui.zip'; archive_bytes = (Get-Item -LiteralPath $zipPath).Length; archive_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant(); files = $descriptions }
$manifestPath = Join-Path $bundle 'manifest.json'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
$extracted = Initialize-CunBundledEngine $paths
Assert-Cun (Test-Path -LiteralPath (Join-Path $extracted $names[0])) 'Verified bundled fixture archive extracts locally'
Assert-Cun ((Initialize-CunBundledEngine $paths) -eq $extracted) 'Cached bundled files are idempotent'
$originalGodotOverride = $env:GODOT_EXE
try {
    $env:GODOT_EXE = ''
    Assert-Cun ((Find-CunDesktopEngine $paths) -eq (Join-Path $extracted $names[0])) 'Desktop discovers the cached GUI engine without global search'
    $env:GODOT_EXE = $fixture
    Assert-Cun ((Find-CunDesktopEngine $paths) -eq $fixture) 'Desktop honors the explicit environment engine override'
    Assert-Cun ((Find-CunDesktopEngine $paths (Join-Path $extracted $names[0])) -eq (Join-Path $extracted $names[0])) 'Desktop saved engine retains highest precedence'
} finally { $env:GODOT_EXE = $originalGodotOverride }
$manifest.archive_sha256 = '0' * 64
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
$blocked = $false
try { Initialize-CunBundledEngine $paths | Out-Null } catch { $blocked = $true }
Assert-Cun $blocked 'Wrong archive SHA256 blocks extraction'
$manifest.archive_sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest.files[0].name = '../escape.exe'
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
$blocked = $false
try { Initialize-CunBundledEngine $paths | Out-Null } catch { $blocked = $true }
Assert-Cun $blocked 'Unsafe entry descriptors cannot escape the local cache'
$channel = Join-Path $tempRoot 'fake session'
$entryScene = 'scenes/AddedGame.tscn'
[IO.File]::WriteAllText((Join-Path $paths.Project $entryScene),'[gd_scene format=3]')
$run = Start-CunProject $paths $fixture 'Game' -ParentWindow 123456 -EntryScene $entryScene -WarmChannel $channel
Assert-Cun ($run.Process.WaitForExit(5000)) 'Registered scene can launch without a hardcoded route'
$argv = [IO.File]::ReadAllLines($env:CUN_FIXTURE_ARGS)
Assert-Cun (($argv -join '|') -ceq "--wid|123456|--single-window|--position|-30000,-30000|--path|$($paths.Project)|res://$entryScene|--|--cun-scroll|--cun-warm|$channel") 'Resident launch preserves exact scene and opaque local channel arguments'
$run.Process.Dispose()
[IO.File]::WriteAllText($channel + '.stop','')
$run = Start-CunProject $paths $fixture 'Game' -ParentWindow 123456 -EntryScene $entryScene -WarmChannel $channel
Assert-Cun ($null -eq $run) 'A retired prewarm never launches another GUI process'
Remove-Item Env:CUN_FIXTURE_ARGS,Env:CUN_FIXTURE_VERSION -ErrorAction SilentlyContinue
Write-Output ('LAUNCHER TESTS PASS: ' + $script:checks + ' checks. Fixture results are not Godot/gameplay verification.')
