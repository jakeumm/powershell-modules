function grep {
    <#
    .SYNOPSIS
        Searches text or files using a small set of grep-style flags.
    .DESCRIPTION
        Usage: grep [-ivFnr] ['--'] PATTERN [PATH ...]

        Matching is case-sensitive by default. Flags can be combined, such as
        -in. Supports -i/--ignore-case, -v/--invert-match, -F/--fixed-strings,
        -n/--line-number, and -r/--recursive. Use the quoted string '--' before
        operands beginning with a dash. PowerShell consumes an unquoted --
        before passing arguments to a function. Options can appear anywhere
        before the quoted separator.

        Returns matching text lines. With -n, prefixes the original line number.
        Multiple-file and recursive searches also prefix the full filename.
        Directories require -r; with -r and no paths, searches the current folder.
        Explicit paths take precedence over pipeline input. Pipeline text is
        processed as it arrives. Paths support PowerShell wildcards.

        Uses Select-String and .NET regex syntax, not GNU basic regex syntax.
        Unsupported options raise PowerShell errors. GNU exit codes and other
        options are not implemented. No-path searches require pipeline input
        unless -r is supplied. Import LinuxAliases.psm1 to load the function.
    .EXAMPLE
        'ERROR: failed', 'ready' | grep -i error
    .EXAMPLE
        grep -in error .\application.log
    .EXAMPLE
        grep -rF 'TODO:' .\src
    .EXAMPLE
        Get-Content .\application.log | grep -v DEBUG
    .EXAMPLE
        '-i', 'other' | grep '--' '-i'
    #>
    # A plain function preserves short and combined flags in $args without
    # PowerShell interpreting them as abbreviated cmdlet parameter names.
    begin {
        $ignoreCase = $false
        $invert = $false
        $fixedStrings = $false
        $lineNumbers = $false
        $recursive = $false
        $optionsEnded = $false
        $operands = [System.Collections.Generic.List[string]]::new()

        foreach ($rawArgument in $args) {
            foreach ($value in $rawArgument) {
                $argument = [string]$value
                if (-not $optionsEnded -and $argument -eq '--') {
                    $optionsEnded = $true
                    continue
                }
                if (-not $optionsEnded -and $argument.StartsWith('-') -and $argument.Length -gt 1) {
                    switch -CaseSensitive ($argument) {
                        '--ignore-case'   { $argument = '-i' }
                        '--invert-match'  { $argument = '-v' }
                        '--fixed-strings' { $argument = '-F' }
                        '--line-number'   { $argument = '-n' }
                        '--recursive'     { $argument = '-r' }
                    }
                    if ($argument.StartsWith('--')) {
                        throw "grep: unsupported option '$argument'. Supported flags: -i, -v, -F, -n, -r."
                    }
                    foreach ($flag in $argument.Substring(1).ToCharArray()) {
                        switch -CaseSensitive ($flag) {
                            'i' { $ignoreCase = $true }
                            'v' { $invert = $true }
                            'F' { $fixedStrings = $true }
                            'n' { $lineNumbers = $true }
                            'r' { $recursive = $true }
                            default { throw "grep: unsupported option '-$flag'. Supported flags: -i, -v, -F, -n, -r." }
                        }
                    }
                }
                else {
                    $operands.Add($argument)
                }
            }
        }

        if ($operands.Count -eq 0) {
            throw "Usage: grep [-ivFnr] ['--'] PATTERN [PATH ...]"
        }
        $pattern = $operands[0]
        $searchPaths = @($operands | Select-Object -Skip 1)
        $useFiles = $searchPaths.Count -gt 0 -or $recursive
        if (-not $useFiles -and -not $MyInvocation.ExpectingInput) {
            throw 'grep: provide a file path or pipe text into the function; use -r to search the current directory.'
        }
        if ($recursive -and $searchPaths.Count -eq 0) { $searchPaths = @('.') }
        # Select-String rejects an empty Pattern. An empty regex matches every
        # line, including when the requested empty pattern was a literal string.
        $selectArguments = @{
            Pattern       = if ($pattern.Length -eq 0) { '(?:)' } else { $pattern }
            CaseSensitive = -not $ignoreCase
            SimpleMatch   = $fixedStrings -and $pattern.Length -gt 0
            NotMatch      = $invert
            ErrorAction   = 'Stop'
        }
        $pipelineLineNumber = 0L
    }

    process {
        if (-not $useFiles) {
            foreach ($inputValue in $input) {
                $text = [string]$inputValue
                $reader = [System.IO.StringReader]::new($text)
                try {
                    $line = if ($text.Length -eq 0) { '' } else { $reader.ReadLine() }
                    while ($null -ne $line) {
                        $pipelineLineNumber++
                        $match = Microsoft.PowerShell.Utility\Select-String -InputObject $line @selectArguments
                        if ($null -ne $match) {
                            if ($lineNumbers) { '{0}:{1}' -f $pipelineLineNumber, $match.Line }
                            else { $match.Line }
                        }
                        $line = $reader.ReadLine()
                    }
                }
                finally { $reader.Dispose() }
            }
        }
    }

    end {
        if ($useFiles) {
            $files = [System.Collections.Generic.List[string]]::new()
            foreach ($searchPath in $searchPaths) {
                if ($searchPath -eq '-') {
                    throw "grep: '-' as a stdin file operand is not supported. Pipe text with no file operands instead."
                }
                foreach ($item in Microsoft.PowerShell.Management\Get-Item -Path $searchPath -Force -ErrorAction Stop) {
                    if ($item -is [System.IO.DirectoryInfo]) {
                        if (-not $recursive) { throw "grep: '$searchPath' is a directory; use -r to search it." }
                        Microsoft.PowerShell.Management\Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force -ErrorAction Stop |
                            ForEach-Object { $files.Add($_.FullName) }
                    }
                    elseif ($item -is [System.IO.FileInfo]) {
                        $files.Add($item.FullName)
                    }
                    else { throw 'grep: only file system paths are supported.' }
                }
            }
            if ($files.Count -gt 0) {
                $includeFileName = $recursive -or $files.Count -gt 1
                Microsoft.PowerShell.Utility\Select-String -LiteralPath $files.ToArray() @selectArguments | ForEach-Object {
                    $result = if ($lineNumbers) { '{0}:{1}' -f $_.LineNumber, $_.Line } else { $_.Line }
                    if ($includeFileName) { '{0}:{1}' -f $_.Path, $result }
                    else { $result }
                }
            }
        }
    }
}

Set-Alias -Name touch -Value New-Item
Set-Alias -Name vi -Value vim

Export-ModuleMember -Function grep -Alias touch, vi
