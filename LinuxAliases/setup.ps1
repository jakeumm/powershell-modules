#Requires -Version 7.0

<#
.SYNOPSIS
    Installs LinuxAliases and prompts to import it into the current session.
.DESCRIPTION
    Copies LinuxAliases.psm1 to
    $HOME\Documents\WindowsPowerShell\Modules\LinuxAliases.psm1, creating the
    destination directories as needed. Repeating setup refreshes the installed
    module. Prompts to import grep, touch, and vi into the current session.
.PARAMETER ModulePath
    Destination module file. Defaults to
    $HOME\Documents\WindowsPowerShell\Modules\LinuxAliases.psm1.
.EXAMPLE
    .\LinuxAliases\setup.ps1
.EXAMPLE
    .\LinuxAliases\setup.ps1 -ModulePath 'D:\PowerShell\Modules\LinuxAliases.psm1'
#>
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$ModulePath = (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\LinuxAliases.psm1')
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'LinuxAliases.psm1'
if (-not [IO.File]::Exists($sourcePath)) {
    throw "Cannot find '$sourcePath'. Keep setup.ps1 beside LinuxAliases.psm1."
}

$moduleFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModulePath)
$pathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($moduleFullPath))
if (-not [string]::Equals($sourcePath, $moduleFullPath, $pathComparison)) {
    [IO.File]::Copy($sourcePath, $moduleFullPath, $true)
}
Write-Host "Installed LinuxAliases: $moduleFullPath"

$answer = Read-Host 'Import LinuxAliases into this session now? [y/N]'
if ($answer -match '^\s*(?i:y|yes)\s*$') {
    Import-Module -Name $moduleFullPath -Force -Global -ErrorAction Stop
    Write-Host 'Imported LinuxAliases. Try grep, touch, or vi.'
}
else {
    $quotedModulePath = $moduleFullPath.Replace("'", "''")
    Write-Host "To import later: Import-Module '$quotedModulePath'"
}
