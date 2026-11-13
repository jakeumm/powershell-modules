Import-Module (Join-Path $PSScriptRoot '..\LinuxAliases.psm1') -Force

Describe 'grep basic Linux-style flags' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory((Join-Path $root 'nested'))
        $file = Join-Path $root 'application.log'
        $nestedFile = Join-Path $root 'nested\child.log'
        [IO.File]::WriteAllText($file, "ERROR first`nkeep`nerror third`n")
        [IO.File]::WriteAllText($nestedFile, "error nested`n")
    }

    It 'exports grep as a function' {
        (Get-Command grep).CommandType | Should Be 'Function'
        (Get-Command grep).ModuleName | Should Be 'LinuxAliases'
    }

    It 'exports only grep and the touch and vi aliases' {
        (((Get-Module LinuxAliases).ExportedCommands.Keys | Sort-Object) -join ',') | Should Be 'grep,touch,vi'
        (Get-Alias touch).Definition | Should Be 'New-Item'
        (Get-Alias vi).Definition | Should Be 'vim'
    }

    It 'creates a file through the exported touch alias' {
        $path = Join-Path $root 'created.txt'
        $created = touch $path -ItemType File
        ($created -is [IO.FileInfo]) | Should Be $true
        (Test-Path -LiteralPath $path -PathType Leaf) | Should Be $true
    }

    It 'matches case-sensitively by default and returns strings' {
        $results = @('ERROR', 'error', 'ready' | grep error)
        $results.Count | Should Be 1
        $results[0] | Should Be 'error'
        ($results[0] -is [string]) | Should Be $true
    }

    It 'supports ignore-case matching' {
        $results = @('ERROR', 'error', 'ready' | grep -i error)
        ($results -join ',') | Should Be 'ERROR,error'
    }

    It 'supports inverse matching' {
        $results = @('ERROR', 'keep', 'error' | grep -v error)
        ($results -join ',') | Should Be 'ERROR,keep'
        @('ERROR', 'error', 'keep' | grep -iv error)[0] | Should Be 'keep'
    }

    It 'supports fixed-string matching and regex matching' {
        @('a.b', 'axb' | grep -F 'a.b').Count | Should Be 1
        @('a.b', 'axb' | grep 'a.b').Count | Should Be 2
    }

    It 'numbers original pipeline lines and supports combined flags' {
        $results = @('skip', 'ERROR', 'skip', 'error' | grep -in error)
        ($results -join ',') | Should Be '2:ERROR,4:error'
    }

    It 'searches one file and numbers its original lines' {
        @(grep error $file)[0] | Should Be 'error third'
        $results = @(grep -in error $file)
        ($results -join ',') | Should Be '1:ERROR first,3:error third'
    }

    It 'allows flags after the pattern and file operands' {
        @(grep error $file -in).Count | Should Be 2
    }

    It 'prefixes filenames when searching multiple file operands' {
        $results = @(grep error $file $nestedFile)
        $results.Count | Should Be 2
        ($results -contains ($file + ':error third')) | Should Be $true
        ($results -contains ($nestedFile + ':error nested')) | Should Be $true
    }

    It 'accepts a PowerShell array of file operands and wildcard paths' {
        @(grep error @($file, $nestedFile)).Count | Should Be 2
        @(grep error (Join-Path $root '*.log')).Count | Should Be 1
    }

    It 'searches recursively and includes filenames and line numbers' {
        $results = @(grep -rin error $root)
        $results.Count | Should Be 3
        ($results -contains ($file + ':1:ERROR first')) | Should Be $true
        ($results -contains ($file + ':3:error third')) | Should Be $true
        ($results -contains ($nestedFile + ':1:error nested')) | Should Be $true
    }

    It 'defaults recursive searches to the current directory' {
        Push-Location -LiteralPath $root
        try { @(grep -r error).Count | Should Be 2 }
        finally { Pop-Location }
    }

    It 'includes hidden files when searching recursively' {
        $hidden = Join-Path $root '.hidden.log'
        [IO.File]::WriteAllText($hidden, "error hidden`n")
        if ($env:OS -eq 'Windows_NT') { [IO.File]::SetAttributes($hidden, [IO.FileAttributes]::Hidden) }
        @(grep -r error $root).Count | Should Be 3
    }

    It 'supports the long forms of the basic flags' {
        @('ERROR', 'skip' | grep --ignore-case --line-number error)[0] | Should Be '1:ERROR'
        @('a.b', 'axb' | grep --fixed-strings --invert-match 'a.b')[0] | Should Be 'axb'
        @(grep --recursive error $root).Count | Should Be 2
    }

    It 'supports a quoted -- before a pattern starting with a dash' {
        @('-i', 'other' | grep '--' '-i')[0] | Should Be '-i'
    }

    It 'handles multiline pipeline strings and blank lines' {
        @("skip`nERROR match`nend`n" | grep -in error)[0] | Should Be '2:ERROR match'
        @('' | grep -n '^$')[0] | Should Be '1:'
    }

    It 'supports empty patterns in fixed-string and regex modes' {
        @('a', '', 'b' | grep '').Count | Should Be 3
        @('a', '', 'b' | grep -F '').Count | Should Be 3
        @('a', '', 'b' | grep -v '').Count | Should Be 0
    }

    It 'returns no records when nothing matches or an input pipeline is empty' {
        @('ready' | grep error).Count | Should Be 0
        @(@() | grep error).Count | Should Be 0
    }

    It 'searches explicit files when pipeline input is also supplied' {
        @('error piped' | grep error $file)[0] | Should Be 'error third'
    }

    It 'rejects unsupported options and flag casing' {
        { 'error' | grep -q error } | Should Throw 'unsupported option'
        { 'error' | grep --unknown error } | Should Throw 'unsupported option'
        { 'error' | grep -f error } | Should Throw 'unsupported option'
        { 'error' | grep -I error } | Should Throw 'unsupported option'
    }

    It 'reports missing patterns, missing input, files, and invalid regexes' {
        { grep } | Should Throw 'Usage:'
        { grep error } | Should Throw 'provide a file path'
        { grep error (Join-Path $root 'missing.log') } | Should Throw 'Cannot find path'
        { grep error $root } | Should Throw 'use -r'
        { 'error' | grep '[' } | Should Throw '['
    }
}
