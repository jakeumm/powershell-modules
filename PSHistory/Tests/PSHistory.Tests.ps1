Import-Module (Join-Path $PSScriptRoot '..\PSHistory.psm1') -Force

function New-TestHistory {
    param (
        [string]$Name = 'history.txt',
        [string[]]$Commands = @(),
        [string]$NewLine = "`n",
        [switch]$Bom
    )
    $path = Join-Path $TestDrive $Name
    $lines = foreach ($command in $Commands) {
        $command.Replace("`n", ([string][char]96 + $NewLine))
    }
    $content = if ($Commands.Count) { ($lines -join $NewLine) + $NewLine } else { '' }
    [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new([bool]$Bom))
    $path
}

Describe 'PSHistory persistent history queries' {
    It 'exports only the two public commands' {
        ((Get-Command -Module PSHistory).Name -join ',') | Should Be 'Get-PSHistory,Search-PSHistory'
    }

    It 'returns newest entries first with source positions and type information' {
        $path = New-TestHistory -Commands 'first', "line one`nline two", 'last'
        $entries = @(Get-PSHistory -Path $path -All)
        ($entries.CommandLine -join '|') | Should Be "last|line one`nline two|first"
        $entries[1].PSTypeNames[0] | Should Be 'PSHistory.Entry'
        $entries[1].EntryNumber | Should Be 2
        $entries[1].StartLine | Should Be 2
        $entries[1].EndLine | Should Be 3
        $entries[1].SourcePath | Should Be $path
    }

    It 'defaults to the newest 50 entries' {
        $path = New-TestHistory -Commands (1..60 | ForEach-Object { "command $_" })
        $entries = @(Get-PSHistory -Path $path)
        $entries.Count | Should Be 50
        $entries[0].CommandLine | Should Be 'command 60'
        $entries[-1].CommandLine | Should Be 'command 11'
    }

    It 'displays only CommandLine by default and wraps multiline commands' {
        $path = New-TestHistory -Commands "git first line`nMULTILINE_END_MARKER"
        $searchOutput = Search-PSHistory 'git' -Path $path | Out-String -Width 80
        $getOutput = Get-PSHistory -Path $path | Out-String -Width 80
        foreach ($output in @($searchOutput, $getOutput)) {
            $output | Should Match '(?m)^\s*CommandLine\s*$'
            $output | Should Match 'git first line'
            $output | Should Match 'MULTILINE_END_MARKER'
            $output | Should Not Match 'SourcePath|EntryNumber|StartLine|EndLine'
        }
    }

    It 'preserves full search entry metadata for downstream selection and export' {
        $path = New-TestHistory -Commands 'git first', 'git second'
        $entry = Search-PSHistory 'git' -Path $path -Last 1
        $entry.PSTypeNames[0] | Should Be 'PSHistory.Entry'
        $entry.EntryNumber | Should Be 2
        $entry.SourcePath | Should Be $path
        $entry.StartLine | Should Be 2
        $entry.EndLine | Should Be 2
        $selected = Search-PSHistory 'git' -Path $path -Last 1 | Select-Object EntryNumber, SourcePath
        $selected.EntryNumber | Should Be 2
        $selected.SourcePath | Should Be $path
        $allProperties = $entry | Format-List * | Out-String -Width 4096
        $allProperties | Should Match 'SourcePath\s*:'
        $allProperties | Should Match 'EntryNumber\s*:'
        $csv = @($entry | ConvertTo-Csv -NoTypeInformation)
        $csv[0] | Should Match 'CommandLine'
        $csv[0] | Should Match 'SourcePath'
        $csv[0] | Should Match 'EntryNumber'
    }

    It 'keeps AsString output as plain command text with no display header' {
        $path = New-TestHistory -Commands 'git status'
        $command = Search-PSHistory 'git' -Path $path -AsString
        ($command -is [string]) | Should Be $true
        $command | Should Be 'git status'
        ($command | Out-String).Trim() | Should Be 'git status'
    }

    It 'limits matching commands rather than searching only the newest entries' {
        $path = New-TestHistory -Commands 'git old', 'git recent', 'unrelated'
        @(Search-PSHistory 'git' -Path $path -Last 1 -AsString)[0] | Should Be 'git recent'
    }

    It 'uses literal case-insensitive matching unless case sensitivity is requested' {
        $path = New-TestHistory -Commands 'Get-A [x]*', 'get-b', 'get-c xxxxx'
        @(Search-PSHistory '[x]*' -Path $path).Count | Should Be 1
        @(Search-PSHistory 'GET-' -Path $path).Count | Should Be 3
        @(Search-PSHistory 'Get-' -CaseSensitive -Path $path).Count | Should Be 1
        @(Search-PSHistory '' -Path $path).Count | Should Be 3
    }

    It 'supports regex and case-sensitive regex matching' {
        $path = New-TestHistory -Commands 'Get-A', 'get-b', 'Set-C'
        @(Search-PSHistory '^Get-\w+$' -Regex -Path $path).Count | Should Be 2
        @(Search-PSHistory '^Get-\w+$' -Regex -CaseSensitive -Path $path).Count | Should Be 1
        { Search-PSHistory '[' -Regex -Path $path } | Should Throw 'Invalid pattern'
    }

    It 'times out expensive regex matching' {
        $path = New-TestHistory -Commands (('a' * 10000) + '!')
        { Search-PSHistory '^(a+)+$' -Regex -Path $path } | Should Throw 'timed out'
    }

    It 'keeps newest exact duplicates before applying the limit' {
        $path = New-TestHistory -Commands 'A', 'B', 'A', 'a', 'B'
        $entries = @(Get-PSHistory -Path $path -Unique -Last 3)
        ($entries.CommandLine -join ',') | Should Be 'B,a,A'
        ($entries.EntryNumber -join ',') | Should Be '5,4,3'
        @(Get-PSHistory -Path $path -All -Unique).Count | Should Be 3
        @(Get-PSHistory -Path $path -All).Count | Should Be 5
    }

    It 'preserves whitespace when deduplicating and returning strings' {
        $path = New-TestHistory -Commands 'a', ' a', 'a ', 'a'
        $entries = @(Get-PSHistory -Path $path -Unique -AsString)
        ($entries -join '|') | Should Be 'a|a | a'
        ($entries[0] -is [string]) | Should Be $true
    }

    It 'handles UTF-8 BOM, CRLF, Unicode, and literal special characters in paths' {
        $path = New-TestHistory -Name 'history [test] file.txt' -Commands 'café 日本語 😀', "one`ntwo" -NewLine "`r`n" -Bom
        $entries = @(Get-PSHistory -Path $path -AsString)
        $entries[0] | Should Be "one`ntwo"
        $entries[1] | Should Be 'café 日本語 😀'
    }

    It 'decodes Unicode across byte buffer boundaries' {
        $command = ('x' * 8191) + '😀' + ('y' * 9000)
        $path = New-TestHistory -Commands $command
        @(Get-PSHistory -Path $path -AsString)[0] | Should Be $command
    }

    It 'reassembles pipelines, script blocks, here-strings and preceding backticks' {
        $commands = @(
            "Get-Item . |`n    Select-Object Name"
            "& {`n    'hello'`n}"
            "@'`ntext`n'@"
            ('one' + [char]96 + "`ntwo")
        )
        $path = New-TestHistory -Commands $commands
        $entries = @(Get-PSHistory -Path $path -All -AsString)
        for ($i = 0; $i -lt $commands.Count; $i++) {
            $entries[$commands.Count - 1 - $i] | Should Be $commands[$i]
        }
        @(Search-PSHistory "'hello'`n}" -Path $path).Count | Should Be 1
    }

    It 'returns no entries for an empty file' {
        $path = New-TestHistory
        @(Get-PSHistory -Path $path).Count | Should Be 0
    }

    It 'defers incomplete final lines and continuation records' {
        $path = New-TestHistory -Commands 'complete'
        [IO.File]::AppendAllText($path, 'unfinished')
        @(Get-PSHistory -Path $path -AsString)[0] | Should Be 'complete'
        @(Get-PSHistory -Path $path).Count | Should Be 1
        [IO.File]::AppendAllText($path, ([string][char]96 + "`n"))
        @(Get-PSHistory -Path $path).Count | Should Be 1
        [IO.File]::AppendAllText($path, "end`n")
        @(Get-PSHistory -Path $path -AsString)[0] | Should Be "unfinished`nend"
    }

    It 'rejects conflicting limits, nonpositive limits, and invalid paths' {
        $path = New-TestHistory
        { Get-PSHistory -Path $path -All -Last 1 } | Should Throw 'Parameter set'
        { Search-PSHistory 'x' -Path $path -All -Last 1 } | Should Throw 'Parameter set'
        { Get-PSHistory -Path $path -Last 0 } | Should Throw 'greater than or equal'
        { Get-PSHistory -Path (Join-Path $TestDrive 'missing.txt') } | Should Throw 'Cannot find path'
        { Get-PSHistory -Path $TestDrive } | Should Throw 'directory'
        { Get-PSHistory -Path 'Env:\PATH' } | Should Throw 'file system'
    }

    It 'reports a file that cannot be opened for reading' {
        $path = New-TestHistory -Commands 'hello'
        $lock = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try { { Get-PSHistory -Path $path } | Should Throw 'used by another process' }
        finally { $lock.Dispose() }
    }

    It 'reads a bounded snapshot while allowing a concurrent append' {
        $path = New-TestHistory -Commands 'original'
        $entries = @(& (Get-Module PSHistory) {
            param ($HistoryPath)
            Read-PSHistoryEntry -Path $HistoryPath | ForEach-Object {
                [IO.File]::AppendAllText($HistoryPath, "appended`n")
                $_
            }
        } $path)
        $entries.Count | Should Be 1
        $entries[0].CommandLine | Should Be 'original'
        @(Get-PSHistory -Path $path -AsString)[0] | Should Be 'appended'
    }

    It 'returns command text as data and leaves source bytes unchanged' {
        $marker = Join-Path $TestDrive 'must-not-exist.txt'
        $path = New-TestHistory -Commands "Set-Content -LiteralPath '$marker' -Value executed"
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        @(Search-PSHistory 'Set-Content' -Path $path).Count | Should Be 1
        (Test-Path -LiteralPath $marker) | Should Be $false
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) | Should Be $before
    }
}

Describe 'PSHistory path discovery' {
    InModuleScope PSHistory {
        It 'resolves the configured path anew on each call' {
            $first = Join-Path $TestDrive 'first.txt'
            $second = Join-Path $TestDrive 'second.txt'
            [IO.File]::WriteAllText($first, "first`n")
            [IO.File]::WriteAllText($second, "second`n")
            Mock 'PSReadLine\Get-PSReadLineOption' { [pscustomobject]@{ HistorySavePath = $first } }
            @(Get-PSHistory -AsString)[0] | Should Be 'first'
            Mock 'PSReadLine\Get-PSReadLineOption' { [pscustomobject]@{ HistorySavePath = $second } }
            @(Get-PSHistory -AsString)[0] | Should Be 'second'
        }

        It 'returns no entries for a missing discovered file' {
            Mock 'PSReadLine\Get-PSReadLineOption' {
                [pscustomobject]@{ HistorySavePath = (Join-Path $TestDrive 'not-created.txt') }
            }
            @(Get-PSHistory).Count | Should Be 0
        }

        It 'allows explicit files when PSReadLine discovery is unavailable' {
            Mock 'PSReadLine\Get-PSReadLineOption' { throw 'Unavailable' }
            $path = Join-Path $TestDrive 'explicit.txt'
            [IO.File]::WriteAllText($path, "explicit`n")
            @(Get-PSHistory -Path $path -AsString)[0] | Should Be 'explicit'
            { Get-PSHistory } | Should Throw 'Supply -Path'
        }
    }
}
