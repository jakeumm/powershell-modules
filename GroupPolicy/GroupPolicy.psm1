function Invoke-GroupPolicyReport {
    # Self-contained worker: the module is not required on the remote computer.
    param (
        [string]$Path,
        [string]$Name,
        [string]$Scope,
        [string]$DefaultFolder
    )

    $ErrorActionPreference = 'Stop'
    if (-not (Test-Path -LiteralPath $DefaultFolder -PathType Container)) {
        New-Item -Path $DefaultFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $folder = $DefaultFolder
    }
    elseif (Test-Path -LiteralPath $Path -PathType Container) {
        $folder = $Path
    }
    elseif ([IO.Path]::HasExtension($Path)) {
        $folder = Split-Path -Path $Path -Parent
        if ([string]::IsNullOrWhiteSpace($folder)) { $folder = '.' }
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            throw "Directory '$folder' does not exist."
        }
        if ([string]::IsNullOrWhiteSpace($Name)) { $Name = Split-Path -Path $Path -Leaf }
    }
    else {
        throw "Directory '$Path' does not exist."
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = '{0:yyyy-MM-dd-HHmmss}-GPResult.html' -f (Get-Date)
    }
    if ($Name -match '[\\/:*?"<>|]') { throw 'Name must be a filename without directory separators or wildcard characters.' }
    if (-not $Name.EndsWith('.html', [StringComparison]::OrdinalIgnoreCase)) { $Name += '.html' }
    $provider = $null
    $drive = $null
    $reportPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        (Join-Path $folder $Name), [ref]$provider, [ref]$drive
    )
    if ($provider.Name -ne 'FileSystem') { throw 'The report path must be a file system path.' }

    $updateArguments = @('/force')
    if ($Scope -ne 'Both') { $updateArguments += '/target:' + $Scope.ToLowerInvariant() }
    Write-Verbose 'Running gpupdate /force ...'
    $updateOutput = @(& gpupdate.exe @updateArguments 2>&1)
    $updateExitCode = $LASTEXITCODE
    if ($updateExitCode -ne 0) {
        throw ('gpupdate.exe failed with exit code {0}: {1}' -f $updateExitCode, ($updateOutput -join [Environment]::NewLine))
    }

    $resultArguments = @('/h', $reportPath)
    if ($Scope -ne 'Both') { $resultArguments += @('/scope', $Scope.ToLowerInvariant()) }
    Write-Verbose "Generating GPResult -> $reportPath"
    $resultOutput = @(& gpresult.exe @resultArguments 2>&1)
    $resultExitCode = $LASTEXITCODE
    if ($resultExitCode -ne 0) {
        throw ('gpresult.exe failed with exit code {0}: {1}' -f $resultExitCode, ($resultOutput -join [Environment]::NewLine))
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw "gpresult.exe did not create the report '$reportPath'."
    }
    $reportPath
}

function Get-GroupPolicy {
    <#
    .SYNOPSIS
        Refreshes Group Policy, generates an HTML report, and opens it locally.
    .DESCRIPTION
        Without ComputerName, runs locally and saves the report below
        $Env:LOCALAPPDATA\Custom-Functions\Get-GroupPolicy by default.

        With ComputerName, uses Invoke-Command to run gpupdate.exe and gpresult.exe
        on that computer. The default remote folder is
        C:\ProgramData\Custom-Functions\Get-GroupPolicy. Opens the report from
        the calling computer through its administrative share, such as
        \\PC01\c$\ProgramData\Custom-Functions\Get-GroupPolicy\report.html.

        Remote calls require PowerShell remoting and access to the target's
        administrative share using the current account. Local calls default to
        both scopes; remote calls default to Computer. User scope refers to the
        account running the command, not automatically the console user.
    .PARAMETER Path
        Existing folder or full HTML filename. For remote calls, interpreted on
        the target computer: supply an absolute drive path or an administrative
        share path for the same ComputerName. Custom folders must already exist.
    .PARAMETER Name
        Optional report filename, overriding the filename in Path. Appends .html
        if needed. Defaults to a timestamped name.
    .PARAMETER ComputerName
        One remote computer name or IPv4 address. Omit to run locally.
    .PARAMETER Scope
        Both, User, or Computer. Applies to both refresh and report generation.
        Defaults to Both locally and Computer remotely.
    .EXAMPLE
        Get-GroupPolicy
    .EXAMPLE
        Get-GroupPolicy -Path 'C:\Reports' -Name 'My-GP.html'
    .EXAMPLE
        Get-GroupPolicy -ComputerName PC01
    .EXAMPLE
        Get-GroupPolicy -ComputerName PC01 -Path '\\PC01\c$\Reports' -Name 'Policy.html'
    .EXAMPLE
        Get-GroupPolicy -ComputerName PC01 -Path 'C:\Reports\Policy.html' -Scope Computer
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter(Position = 1)]
        [string]$Name,

        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
        [string]$ComputerName,

        [ValidateSet('Both', 'User', 'Computer')]
        [string]$Scope
    )

    $remote = $PSBoundParameters.ContainsKey('ComputerName')
    if (-not $PSBoundParameters.ContainsKey('Scope')) {
        $Scope = if ($remote) { 'Computer' } else { 'Both' }
    }

    if ($remote) {
        $defaultFolder = 'C:\ProgramData\Custom-Functions\Get-GroupPolicy'
        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            $shareMatch = [regex]::Match($Path, '^\\\\(?<host>[^\\]+)\\(?<drive>[A-Za-z])\$(?:\\(?<rest>.*))?$')
            if ($shareMatch.Success) {
                if ($shareMatch.Groups['host'].Value -ine $ComputerName) {
                    throw 'The administrative share hostname must match ComputerName.'
                }
                $Path = '{0}:\{1}' -f $shareMatch.Groups['drive'].Value.ToUpperInvariant(), $shareMatch.Groups['rest'].Value
            }
            elseif ($Path -notmatch '^[A-Za-z]:\\') {
                throw 'Remote Path must be an absolute drive path or a drive administrative share on ComputerName, such as \\PC01\c$\Reports.'
            }
        }

        $worker = (Get-Command Invoke-GroupPolicyReport -CommandType Function).ScriptBlock
        $reportPath = Invoke-Command -ComputerName $ComputerName -ScriptBlock $worker -ArgumentList $Path, $Name, $Scope, $defaultFolder -ErrorAction Stop
        $reportMatch = [regex]::Match([string]$reportPath, '^(?<drive>[A-Za-z]):\\(?<rest>.*)$')
        if (-not $reportMatch.Success) { throw 'The remote command did not return an absolute report path.' }
        $accessiblePath = '\\{0}\{1}$\{2}' -f $ComputerName, $reportMatch.Groups['drive'].Value.ToLowerInvariant(), $reportMatch.Groups['rest'].Value
        try {
            if (-not (Test-Path -LiteralPath $accessiblePath -PathType Leaf -ErrorAction Stop)) {
                throw 'The report is not accessible through the administrative share.'
            }
        }
        catch {
            throw "Report created on '$ComputerName' at '$reportPath', but it could not be accessed at '$accessiblePath'. Check SMB connectivity and administrative share permissions. $($_.Exception.Message)"
        }
    }
    else {
        $defaultFolder = Join-Path $Env:LOCALAPPDATA 'Custom-Functions\Get-GroupPolicy'
        $accessiblePath = Invoke-GroupPolicyReport -Path $Path -Name $Name -Scope $Scope -DefaultFolder $defaultFolder
    }

    Start-Process -FilePath $accessiblePath -ErrorAction Stop
    Write-Output "GPResult saved to $accessiblePath"
}

Export-ModuleMember -Function Get-GroupPolicy
