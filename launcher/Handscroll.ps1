# Windows PowerShell 5.1; compile a native desktop WinExe into this checkout's ignored cache.
[CmdletBinding()] param([switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
try {
    $root = Split-Path -Parent $PSScriptRoot
    $framework = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $csc = Join-Path $framework 'csc.exe'
    $wpf = Join-Path $framework 'WPF'
    $sources = @('ScrollArtwork.cs','ScrollWindow.cs','ScrollCatalog.cs') | ForEach-Object { Join-Path $PSScriptRoot $_ }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $inputs = @($PSCommandPath) + $sources
        $stamps = foreach ($f in $inputs) { [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($f))) }
        $key = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes(($stamps -join '|')))).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
    $cache = Join-Path $root ('.local\native-launcher\' + $key)
    $exe = Join-Path $cache 'Cun.Handscroll.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        [void][IO.Directory]::CreateDirectory($cache)
        $temp = Join-Path $cache (([Guid]::NewGuid()).ToString('N') + '.exe')
        $refs = @('WindowsBase','PresentationCore','PresentationFramework') | ForEach-Object { '/r:' + (Join-Path $wpf ($_ + '.dll')) }
        & $csc /nologo /target:winexe /optimize+ /codepage:65001 /r:System.Xaml.dll @refs ('/out:' + $temp) @sources
        if ($LASTEXITCODE -ne 0) { throw 'Could not build the native desktop launcher.' }
        try { [IO.File]::Move($temp,$exe) } catch [IO.IOException] { if (-not [IO.File]::Exists($exe)) { throw }; [IO.File]::Delete($temp) }
    }
    if ($BuildOnly) { Write-Output $exe; exit 0 }
    $si = New-Object Diagnostics.ProcessStartInfo
    $si.FileName = $exe; $si.WorkingDirectory = $root; $si.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($si); $p.Dispose()
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.GetBaseException().Message)
    exit 1
}
