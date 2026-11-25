# Standalone on Windows PowerShell 5.1. No installation, URL ACL or admin required.
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
try {
    $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Handscroll.Host.cs'))
    Add-Type -TypeDefinition $source -ReferencedAssemblies System.dll,System.Core.dll,System.Web.Extensions.dll -Language CSharp
    (New-Object Cun.ScrollHost((Split-Path -Parent $PSScriptRoot))).Run()
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.GetBaseException().Message)
    exit 1
}
