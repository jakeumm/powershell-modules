#Requires -Version 7.0

<#
.SYNOPSIS
    Installs PSHistory and configures persistent PowerShell history.
.DESCRIPTION
    Copies PSHistory.psm1 to $HOME\Documents\WindowsPowerShell\Modules\PSHistory.psm1
    and PSHistory.format.ps1xml beside the installed module. Adds missing history
    settings to the current user's $PROFILE. Existing
    profile content and encoding are preserved. Prompts to import the installed
    module into the current session. Profile settings apply the next time that
    profile is loaded.
.PARAMETER ProfilePath
    Profile to update. Defaults to $PROFILE for the PowerShell host running setup.
.PARAMETER ModulePath
    Destination file. Defaults to the module path described above.
.EXAMPLE
    .\PSHistory\setup.ps1
#>
[CmdletBinding()]
param (
    [ValidateNotNullOrEmpty()]
    [string]$ProfilePath = $PROFILE,

    [ValidateNotNullOrEmpty()]
    [string]$ModulePath = (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\PSHistory.psm1')
)

$ErrorActionPreference = 'Stop'
$sourcePath = Join-Path $PSScriptRoot 'PSHistory.psm1'
$sourceFormatPath = Join-Path $PSScriptRoot 'PSHistory.format.ps1xml'
if (-not [IO.File]::Exists($sourcePath)) {
    throw "Cannot find '$sourcePath'. Keep setup.ps1 beside PSHistory.psm1."
}
if (-not [IO.File]::Exists($sourceFormatPath)) {
    throw "Cannot find '$sourceFormatPath'. Keep PSHistory.format.ps1xml beside setup.ps1."
}

$profileFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProfilePath)
$moduleFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModulePath)
$installedFormatPath = Join-Path ([IO.Path]::GetDirectoryName($moduleFullPath)) 'PSHistory.format.ps1xml'
$pathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if ([string]::Equals($profileFullPath, $moduleFullPath, $pathComparison) -or
    [string]::Equals($profileFullPath, $sourcePath, $pathComparison) -or
    [string]::Equals($profileFullPath, $installedFormatPath, $pathComparison) -or
    [string]::Equals($profileFullPath, $sourceFormatPath, $pathComparison)) {
    throw 'The profile path must be different from the module and format file paths.'
}

# StreamReader detects an existing BOM so appending also works for UTF-16/32
# profiles. A new profile uses UTF-8 without a BOM.
$encoding = [Text.UTF8Encoding]::new($false)
$profileContent = ''
if ([IO.File]::Exists($profileFullPath)) {
    $reader = [IO.StreamReader]::new($profileFullPath, $encoding, $true)
    try {
        $profileContent = $reader.ReadToEnd()
        $encoding = $reader.CurrentEncoding
    }
    finally { $reader.Dispose() }
}
elseif ([IO.Directory]::Exists($profileFullPath)) {
    throw "The profile path '$profileFullPath' is a directory. Supply a file path."
}

$settings = [ordered]@{
    '$MaximumHistoryCount = 10000' = '(?im)^[\t ]*\$MaximumHistoryCount[\t ]*=[\t ]*10000[\t ]*(?:#.*)?\r?$'
    'Set-PSReadLineOption -MaximumHistoryCount 10000' = '(?im)^[\t ]*Set-PSReadLineOption[\t ]+-MaximumHistoryCount[\t ]+10000[\t ]*(?:#.*)?\r?$'
    'Set-PSReadLineOption -HistorySaveStyle SaveIncrementally' = '(?im)^[\t ]*Set-PSReadLineOption[\t ]+-HistorySaveStyle[\t ]+SaveIncrementally[\t ]*(?:#.*)?\r?$'
}
$missingSettings = @(
    foreach ($setting in $settings.GetEnumerator()) {
        if ($profileContent -notmatch $setting.Value) { $setting.Key }
    }
)

[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($moduleFullPath))
if (-not [string]::Equals($sourceFormatPath, $installedFormatPath, $pathComparison)) {
    [IO.File]::Copy($sourceFormatPath, $installedFormatPath, $true)
}
if (-not [string]::Equals($sourcePath, $moduleFullPath, $pathComparison)) {
    [IO.File]::Copy($sourcePath, $moduleFullPath, $true)
}
Write-Host "Installed PSHistory: $moduleFullPath"

if ($missingSettings.Count -gt 0) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($profileFullPath))
    $newLine = if ($profileContent.Contains("`r`n")) { "`r`n" } elseif ($profileContent.Contains("`n")) { "`n" } else { [Environment]::NewLine }
    $addition = if ($profileContent.Length -gt 0 -and -not $profileContent.EndsWith("`n")) { $newLine } else { '' }
    $addition += '# PSHistory history settings' + $newLine
    $addition += ($missingSettings -join $newLine) + $newLine
    [IO.File]::AppendAllText($profileFullPath, $addition, $encoding)
    Write-Host "Added history settings to: $profileFullPath"
}
else {
    Write-Host "History settings are already present in: $profileFullPath"
}
Write-Host 'History settings apply when this profile next loads.'

$answer = Read-Host 'Import PSHistory into this session now? [y/N]'
if ($answer -match '^\s*(?i:y|yes)\s*$') {
    Import-Module -Name $moduleFullPath -Force -Global -ErrorAction Stop
    Write-Host 'Imported PSHistory. Try Get-PSHistory or Search-PSHistory.'
}
else {
    $quotedModulePath = $moduleFullPath.Replace("'", "''")
    Write-Host "To import later: Import-Module '$quotedModulePath'"
}
