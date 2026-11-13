function Search-ChildItem {
    <#
    .SYNOPSIS
        Searches recursively for files or directories by name.
    .DESCRIPTION
        Returns original FileInfo objects by default, or DirectoryInfo objects
        with Directory. Searches all subdirectories unless Depth limits recursion.
        Access-denied errors are skipped by default and reported with Verbose.
        Other errors are reported normally. An explicit ErrorAction or a changed
        ErrorActionPreference controls all errors, including access denied.
    .PARAMETER Filter
        File-system name filter. Defaults to *. Use '*.pdf' to find PDF files.
        The filter matches names, not file contents.
    .PARAMETER Path
        One or more starting paths. Supports wildcards. Defaults to the current directory.
    .PARAMETER LiteralPath
        One or more exact starting paths. Wildcard characters are treated literally.
        Cannot be combined with Path.
    .PARAMETER File
        Explicitly selects files, which is also the default. Cannot be combined with Directory.
    .PARAMETER Directory
        Selects directories instead of files. Cannot be combined with File.
    .PARAMETER Force
        Includes hidden and system items where permitted. Does not bypass access permissions.
    .PARAMETER Depth
        Limits recursion. Zero searches only the starting directories' immediate children.
        One also searches their immediate subdirectories. Omit for unlimited recursion.
    .EXAMPLE
        Search-ChildItem '*.pdf'
    .EXAMPLE
        Search-ChildItem -Filter *.pdf -Path C:\Documents
    .EXAMPLE
        Search-ChildItem '*cache*' -Directory -Force
    .EXAMPLE
        Search-ChildItem '*.log' -LiteralPath 'C:\Builds\[latest]' -Depth 1
    .EXAMPLE
        Search-ChildItem '*.log' -ErrorAction Stop
    .EXAMPLE
        Search-ChildItem '*.log' | Select-Object LastWriteTime, FullName
    #>
    [CmdletBinding(DefaultParameterSetName = 'PathFile')]
    param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter = '*',

        [Parameter(Position = 1, ParameterSetName = 'PathFile')]
        [Parameter(Position = 1, ParameterSetName = 'PathDirectory')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path = '.',

        [Parameter(Mandatory, ParameterSetName = 'LiteralFile')]
        [Parameter(Mandatory, ParameterSetName = 'LiteralDirectory')]
        [ValidateNotNullOrEmpty()]
        [string[]]$LiteralPath,

        [Parameter(ParameterSetName = 'PathFile')]
        [Parameter(ParameterSetName = 'LiteralFile')]
        [switch]$File,

        [Parameter(Mandatory, ParameterSetName = 'PathDirectory')]
        [Parameter(Mandatory, ParameterSetName = 'LiteralDirectory')]
        [switch]$Directory,

        [switch]$Force,

        [uint32]$Depth
    )

    $childArguments = @{
        Filter      = $Filter
        Recurse     = $true
        Force       = $Force
        ErrorAction = 'Continue'
    }
    if ($Directory) { $childArguments.Directory = $true }
    else { $childArguments.File = $true }

    $rootArguments = @{ Force = $Force; ErrorAction = 'Continue' }
    if ($PSBoundParameters.ContainsKey('LiteralPath')) { $rootArguments.LiteralPath = $LiteralPath }
    else { $rootArguments.Path = $Path }
    if ($PSBoundParameters.ContainsKey('Depth')) { $childArguments.Depth = $Depth }

    $skipAccessDenied = -not $PSBoundParameters.ContainsKey('ErrorAction') -and
        $ErrorActionPreference -eq [System.Management.Automation.ActionPreference]::Continue

    # Capture provider errors so expected access failures can be skipped without
    # hiding invalid roots. WriteError honors this function's common parameters.
    # Resolve roots without Filter: recursive Get-ChildItem can otherwise treat a
    # nonexistent root as a search pattern, or match Filter against a wildcard root.
    Microsoft.PowerShell.Management\Get-Item @rootArguments 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $_
        }
        elseif ($_.PSProvider.Name -ne 'FileSystem') {
            [System.Management.Automation.ErrorRecord]::new(
                [System.ArgumentException]::new('Search-ChildItem requires file system paths.'),
                'SearchChildItemRequiresFileSystem',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $_.PSPath
            )
        }
        else {
            $childArguments.LiteralPath = $_.PSPath
            Microsoft.PowerShell.Management\Get-ChildItem @childArguments 2>&1
        }
    } | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            $accessDenied = $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::PermissionDenied -or
                $_.Exception -is [System.UnauthorizedAccessException]
            if ($skipAccessDenied -and $accessDenied) {
                Write-Verbose "Skipped inaccessible path: $($_.Exception.Message)"
            }
            else {
                $PSCmdlet.WriteError($_)
            }
        }
        else {
            $PSCmdlet.WriteObject($_)
        }
    }
}

Export-ModuleMember -Function Search-ChildItem
