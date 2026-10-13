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
Remove-Item Env:CUN_FIXTURE_ARGS,Env:CUN_FIXTURE_VERSION -ErrorAction SilentlyContinue
Write-Output ('LAUNCHER TESTS PASS: ' + $script:checks + ' checks. Fixture results are not Godot/gameplay verification.')
