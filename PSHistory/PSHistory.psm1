#Requires -Version 7.0

function Resolve-PSHistoryPath {
    [CmdletBinding()]
    param ([string]$Path)

    $explicitPath = $PSBoundParameters.ContainsKey('Path')
    if (-not $explicitPath) {
        try {
            $Path = (PSReadLine\Get-PSReadLineOption -ErrorAction Stop).HistorySavePath
        }
        catch {
            throw 'Cannot discover the PSReadLine history file. Supply -Path with a history file path.'
        }
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw 'PSReadLine has no history file path configured. Supply -Path with a history file path.'
        }
    }

    $provider = $null
    $drive = $null
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
        $Path, [ref]$provider, [ref]$drive
    )
    if ($provider.Name -ne 'FileSystem') {
        throw 'PSHistory requires a file system path.'
    }

    try {
        $item = Get-Item -LiteralPath $resolvedPath -Force -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        if ($explicitPath) { throw }
        Write-Verbose "No persisted history file exists yet at '$resolvedPath'."
        return
    }
    if ($item.PSIsContainer) {
        throw "The history path '$resolvedPath' is a directory. Supply a file path."
    }
    $item.FullName
}

function Read-PSHistoryEntry {
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$Path)

    $stream = $null
    try {
        $sharing = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        $stream = [System.IO.FileStream]::new(
            $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $sharing
        )
        $remaining = $stream.Length
        # Decode bounded chunks instead of StreamReader.ReadLine(), which can read
        # past the original length while another shell is appending.
        $decoder = [System.Text.UTF8Encoding]::new($false, $true).GetDecoder()
        $bytes = [byte[]]::new(8192)
        $chars = [char[]]::new(8193)
        $physicalLine = [System.Text.StringBuilder]::new()
        $command = [System.Text.StringBuilder]::new()
        $firstChunk = $true
        $endsWithNewline = $true
        $lineNumber = 0L
        $entryNumber = 0L
        $startLine = 1L

        while ($remaining -gt 0) {
            $read = $stream.Read($bytes, 0, [int][Math]::Min($bytes.Length, $remaining))
            if ($read -eq 0) { throw "History file '$Path' was truncated during the read. Retry the query." }
            $remaining -= $read
            $endsWithNewline = $bytes[$read - 1] -eq 10
            $count = $decoder.GetChars($bytes, 0, $read, $chars, 0, $false)
            $text = [string]::new($chars, 0, $count)
            if ($firstChunk -and $text.Length -gt 0) {
                $firstChunk = $false
                if ($text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
            }

            $offset = 0
            while (($newline = $text.IndexOf([char]10, $offset)) -ge 0) {
                [void]$physicalLine.Append($text, $offset, $newline - $offset)
                $line = $physicalLine.ToString()
                [void]$physicalLine.Clear()
                $lineNumber++
                if ($line.EndsWith("`r", [StringComparison]::Ordinal)) {
                    $line = $line.Substring(0, $line.Length - 1)
                }

                # PSReadLine stores embedded newlines as a backtick plus newline.
                # Remove just the final marker, preserving any preceding backticks.
                if ($line.EndsWith('`', [StringComparison]::Ordinal)) {
                    [void]$command.Append($line, 0, $line.Length - 1)
                    [void]$command.Append([char]10)
                }
                else {
                    [void]$command.Append($line)
                    $entryNumber++
                    [pscustomobject]@{
                        PSTypeName  = 'PSHistory.Entry'
                        CommandLine = $command.ToString()
                        SourcePath  = $Path
                        EntryNumber = $entryNumber
                        StartLine   = $startLine
                        EndLine     = $lineNumber
                    }
                    [void]$command.Clear()
                    $startLine = $lineNumber + 1
                }
                $offset = $newline + 1
            }
            [void]$physicalLine.Append($text, $offset, $text.Length - $offset)
        }

        if ($stream.Length -lt $stream.Position) {
            throw "History file '$Path' was truncated during the read. Retry the query."
        }
        if (-not $endsWithNewline -or $command.Length -gt 0) {
            Write-Verbose 'Deferred an incomplete trailing history record until a subsequent query.'
        }
    }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Select-PSHistoryEntry {
    [CmdletBinding()]
    param (
        [string]$Path,
        [int]$Last = 50,
        [switch]$All,
        [switch]$Unique,
        [switch]$AsString,
        [string]$Pattern,
        [switch]$Regex,
        [switch]$CaseSensitive
    )

    $hasPattern = $PSBoundParameters.ContainsKey('Pattern')
    $matcher = $null
    if ($Regex) {
        $options = [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        if (-not $CaseSensitive) {
            $options = $options -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        }
        try {
            $matcher = [regex]::new($Pattern, $options, [TimeSpan]::FromSeconds(1))
        }
        catch {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                $_.Exception, 'InvalidPSHistoryPattern',
                [System.Management.Automation.ErrorCategory]::InvalidArgument, $Pattern
            ))
        }
    }
    $comparison = if ($CaseSensitive) { [StringComparison]::Ordinal } else { [StringComparison]::OrdinalIgnoreCase }
    $pathArguments = @{}
    if ($PSBoundParameters.ContainsKey('Path')) { $pathArguments.Path = $Path }
    $sourcePath = Resolve-PSHistoryPath @pathArguments
    if ($null -eq $sourcePath) { return }

    $entries = [System.Collections.Generic.LinkedList[object]]::new()
    $seen = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    try {
        Read-PSHistoryEntry -Path $sourcePath | ForEach-Object {
            $entry = $_
            $matchesPattern = $true
            if ($hasPattern) {
                $matchesPattern = if ($Regex) {
                    $matcher.IsMatch($entry.CommandLine)
                }
                else {
                    $entry.CommandLine.IndexOf($Pattern, $comparison) -ge 0
                }
            }
            if ($matchesPattern) {
                if ($Unique -and $seen.ContainsKey($entry.CommandLine)) {
                    $entries.Remove([System.Collections.Generic.LinkedListNode[object]]$seen[$entry.CommandLine])
                }
                $node = $entries.AddLast([object]$entry)
                if ($Unique) { $seen[$entry.CommandLine] = $node }
                if (-not $All -and $entries.Count -gt $Last) {
                    if ($Unique) { [void]$seen.Remove($entries.First.Value.CommandLine) }
                    $entries.RemoveFirst()
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            $_.Exception, 'PSHistoryReadFailed',
            [System.Management.Automation.ErrorCategory]::ReadError, $sourcePath
        ))
    }

    for ($node = $entries.Last; $null -ne $node; $node = $node.Previous) {
        if ($AsString) { $PSCmdlet.WriteObject($node.Value.CommandLine) }
        else { $PSCmdlet.WriteObject($node.Value) }
    }
}

function Get-PSHistory {
    <#
    .SYNOPSIS
        Gets commands from persistent PSReadLine history, newest first.
    .DESCRIPTION
        Reads the configured PSReadLine history file or an explicit UTF-8 file.
        Multiline commands are returned as single PSHistory.Entry objects. Only
        complete, newline-terminated records present when the file is opened are
        included. The source file and PSReadLine settings are left unchanged.

        Results reflect file order. EntryNumber is a file position, not a session
        history ID. Persisted history has no per-command timestamps or exit status.
        SaveAtExit delays persistence; SaveNothing does not save new commands.
    .PARAMETER Last
        Returns the newest N entries. Defaults to 50. Cannot be combined with All.
    .PARAMETER All
        Returns all persisted entries.
    .PARAMETER Path
        A literal history file path. Defaults to the current PSReadLine HistorySavePath.
        Explicit paths work without PSReadLine. A missing default file returns no entries.
    .PARAMETER Unique
        Keeps the newest occurrence of each exact, case-sensitive command text.
    .PARAMETER AsString
        Returns complete command strings instead of history entry objects.
    .EXAMPLE
        Get-PSHistory -Last 100 -Unique
    .EXAMPLE
        Get-PSHistory -Path 'C:\Backups\ConsoleHost_history.txt' -All
    .EXAMPLE
        Get-PSHistory -Last 1 -AsString | Set-Clipboard
    #>
    [CmdletBinding(DefaultParameterSetName = 'Last')]
    param (
        [Parameter(ParameterSetName = 'Last')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Last = 50,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [switch]$Unique,
        [switch]$AsString
    )

    Select-PSHistoryEntry @PSBoundParameters
}

function Search-PSHistory {
    <#
    .SYNOPSIS
        Searches persistent PSReadLine history, returning newest matches first.
    .DESCRIPTION
        Matches a literal, case-insensitive substring by default. Regex enables
        regular expressions with a one-second timeout per command. Matching uses
        complete decoded commands, including embedded newlines. Filtering and
        optional deduplication happen before the result limit.
    .PARAMETER Pattern
        Text to find. An empty string matches every command. Wildcards are literal.
    .PARAMETER Regex
        Treats Pattern as a .NET regular expression. Use (?s) to let dot match newlines.
    .PARAMETER CaseSensitive
        Enables case-sensitive matching.
    .PARAMETER Last
        Returns the newest N matches. Defaults to 50. Cannot be combined with All.
    .PARAMETER All
        Returns all matching entries.
    .PARAMETER Path
        A literal UTF-8 history file path. Defaults to PSReadLine HistorySavePath.
    .PARAMETER Unique
        Keeps the newest occurrence of each exact, case-sensitive command text.
    .PARAMETER AsString
        Returns complete command strings instead of history entry objects.
    .EXAMPLE
        Search-PSHistory 'git commit' -Unique
    .EXAMPLE
        Search-PSHistory '^Get-\w+' -Regex -Last 20
    .EXAMPLE
        Search-PSHistory 'docker' -Last 1 -AsString | Set-Clipboard
    #>
    [CmdletBinding(DefaultParameterSetName = 'Last')]
    param (
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Pattern,

        [switch]$Regex,
        [switch]$CaseSensitive,

        [Parameter(ParameterSetName = 'Last')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Last = 50,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [switch]$Unique,
        [switch]$AsString
    )

    Select-PSHistoryEntry @PSBoundParameters
}

Export-ModuleMember -Function Get-PSHistory, Search-PSHistory
