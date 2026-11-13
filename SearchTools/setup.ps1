#Requires -Version 7.0

<#
.SYNOPSIS
    Installs SearchTools and prompts to import it into the current session.
.DESCRIPTION
    Copies SearchTools.psm1 to
    $HOME\Documents\WindowsPowerShell\Modules\SearchTools.psm1, creating the
    destination directories as needed. Repeating setup refreshes the installed
    module. Prompts to import the installed module into the current session.
.PARAMETER ModulePath
    Destination module file. Defaults to
    $HOME\Documents\WindowsPowerShell\Modules\SearchTools.psm1.
.EXAMPLE
    .\SearchTools\setup.ps1
.EXAMPLE
    .\SearchTools\setup.ps1 -ModulePath 'D:\PowerShell\Modules\SearchTools.psm1'
#>
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$ModulePath = (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\SearchTools.psm1')
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'SearchTools.psm1'
if (-not [IO.File]::Exists($sourcePath)) {
    throw "Cannot find '$sourcePath'. Keep setup.ps1 beside SearchTools.psm1."
}

$moduleFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModulePath)
$pathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($moduleFullPath))
if (-not [string]::Equals($sourcePath, $moduleFullPath, $pathComparison)) {
    [IO.File]::Copy($sourcePath, $moduleFullPath, $true)
}
Write-Host "Installed SearchTools: $moduleFullPath"

$answer = Read-Host 'Import SearchTools into this session now? [y/N]'
if ($answer -match '^\s*(?i:y|yes)\s*$') {
    Import-Module -Name $moduleFullPath -Force -Global -ErrorAction Stop
    Write-Host 'Imported SearchTools. Try Search-ChildItem or Search-ChildItem -Directory.'
}
else {
    $quotedModulePath = $moduleFullPath.Replace("'", "''")
    Write-Host "To import later: Import-Module '$quotedModulePath'"
}
