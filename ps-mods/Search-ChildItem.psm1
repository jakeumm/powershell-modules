function Search-ChildItem {
    <#
    .SYNOPSIS
        Lists matching files recursively, skipping inaccessible directories.
    .EXAMPLE
        Search-ChildItem *pdf
    .EXAMPLE
        Search-ChildItem -Filter *.pdf -Path C:\Documents
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$Filter = '*',

        [Parameter(Position = 1)]
        [string[]]$Path = '.'
    )

    Microsoft.PowerShell.Management\Get-ChildItem -Path $Path -Filter $Filter -Recurse -File -ErrorAction Ignore |
        Select-Object LastWriteTime, FullName
}

Export-ModuleMember -Function Search-ChildItem
