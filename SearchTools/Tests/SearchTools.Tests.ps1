Import-Module (Join-Path $PSScriptRoot '..\SearchTools.psm1') -Force

Describe 'Search-ChildItem file system searches' {
    BeforeEach {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory((Join-Path $root 'nested\deeper'))
        [IO.File]::WriteAllText((Join-Path $root 'root.log'), 'root')
        [IO.File]::WriteAllText((Join-Path $root 'root.txt'), 'text')
        [IO.File]::WriteAllText((Join-Path $root 'nested\child.log'), 'child')
        [IO.File]::WriteAllText((Join-Path $root 'nested\deeper\deep.log'), 'deep')
    }

    It 'exports only Search-ChildItem' {
        @(Get-Command -Module SearchTools).Count | Should Be 1
        (Get-Command -Module SearchTools).Name | Should Be 'Search-ChildItem'
    }

    It 'defaults to recursive file-only results' {
        $items = @(Search-ChildItem -Path $root)
        $items.Count | Should Be 4
        @($items | Where-Object { $_ -isnot [IO.FileInfo] }).Count | Should Be 0
    }

    It 'uses the current directory when no path is supplied' {
        Push-Location -LiteralPath $root
        try { @(Search-ChildItem).Count | Should Be 4 }
        finally { Pop-Location }
    }

    It 'accepts the filter and path positionally' {
        @(Search-ChildItem '*.log' $root).Count | Should Be 3
    }

    It 'supports explicit File and still defaults to files when File is false' {
        @(Search-ChildItem -Path $root -File).Count | Should Be 4
        @(Search-ChildItem -Path $root -File:$false).Count | Should Be 4
    }

    It 'returns original file objects with size and extension properties' {
        $item = Search-ChildItem 'root.log' -Path $root
        ($item -is [IO.FileInfo]) | Should Be $true
        $item.Length | Should Be 4
        $item.Extension | Should Be '.log'
        $item.PSIsContainer | Should Be $false
    }

    It 'selects directories only and applies the name filter' {
        $items = @(Search-ChildItem -Path $root -Directory)
        $items.Count | Should Be 2
        @($items | Where-Object { $_ -isnot [IO.DirectoryInfo] }).Count | Should Be 0
        @(Search-ChildItem '*deep*' -Path $root -Directory)[0].Name | Should Be 'deeper'
    }

    It 'supports Depth zero and one for files and directories' {
        @(Search-ChildItem '*.log' -Path $root -Depth 0).Count | Should Be 1
        @(Search-ChildItem '*.log' -Path $root -Depth 1).Count | Should Be 2
        @(Search-ChildItem -Path $root -Directory -Depth 0).Count | Should Be 1
        @(Search-ChildItem -Path $root -Directory -Depth 1).Count | Should Be 2
    }

    It 'supports multiple starting paths' {
        $other = Join-Path $TestDrive 'other'
        [void][IO.Directory]::CreateDirectory($other)
        [IO.File]::WriteAllText((Join-Path $other 'other.log'), 'other')
        @(Search-ChildItem '*.log' -Path $root, $other).Count | Should Be 4
        @(Search-ChildItem '*.log' -LiteralPath $root, $other).Count | Should Be 4
    }

    It 'supports wildcard Path and literal paths containing brackets' {
        $literal = Join-Path $root '[build]'
        [void][IO.Directory]::CreateDirectory((Join-Path $literal 'output'))
        [IO.File]::WriteAllText((Join-Path $literal 'build.log'), 'build')
        @(Search-ChildItem '*.log' -LiteralPath $literal).Count | Should Be 1
        @(Search-ChildItem -LiteralPath $literal -File).Count | Should Be 1
        @(Search-ChildItem -LiteralPath $literal -Directory)[0].Name | Should Be 'output'
        @(Search-ChildItem '*.log' -Path (Join-Path $root 'nest*')).Count | Should Be 2
    }

    It 'includes hidden files and directories only with Force' {
        $hiddenFile = Join-Path $root '.hidden.log'
        $hiddenDirectory = Join-Path $root '.hidden-directory'
        [IO.File]::WriteAllText($hiddenFile, 'hidden')
        [void][IO.Directory]::CreateDirectory($hiddenDirectory)
        if ($env:OS -eq 'Windows_NT') {
            [IO.File]::SetAttributes($hiddenFile, [IO.FileAttributes]::Hidden)
            [IO.File]::SetAttributes($hiddenDirectory, [IO.FileAttributes]::Hidden)
        }
        @(Search-ChildItem '*.log' -Path $root).Count | Should Be 3
        @(Search-ChildItem '*.log' -Path $root -Force).Count | Should Be 4
        @(Search-ChildItem -Path $root -Directory).Count | Should Be 2
        @(Search-ChildItem -Path $root -Directory -Force).Count | Should Be 3
    }

    It 'rejects conflicting selection switches and paths' {
        { Search-ChildItem -Path $root -File -Directory } | Should Throw 'Parameter set'
        { Search-ChildItem -LiteralPath $root -File -Directory } | Should Throw 'Parameter set'
        { Search-ChildItem -Path $root -LiteralPath $root } | Should Throw 'Parameter set'
        { Search-ChildItem -Path $root -Depth -1 } | Should Throw 'Depth'
    }

    It 'reports missing starting paths by default' {
        $missing = Join-Path $root 'missing'
        $items = @(Search-ChildItem -Path $missing 2>&1)
        $items.Count | Should Be 1
        ($items[0] -is [System.Management.Automation.ErrorRecord]) | Should Be $true
    }

    It 'honors ErrorAction Stop, SilentlyContinue, and ErrorVariable' {
        $missing = Join-Path $root 'missing'
        { Search-ChildItem -Path $missing -ErrorAction Stop } | Should Throw 'Cannot find path'
        $searchErrors = @()
        @(Search-ChildItem -Path $missing -ErrorAction SilentlyContinue -ErrorVariable searchErrors).Count | Should Be 0
        ($searchErrors.Count -gt 0) | Should Be $true
    }
}

Describe 'Search-ChildItem access-denied handling' {
    InModuleScope SearchTools {
        function Set-SearchAccessDeniedMock {
            Mock Get-ChildItem {
                Write-Error 'Synthetic access denied' -Category PermissionDenied -ErrorAction Continue
                [pscustomobject]@{ Name = 'allowed.txt' }
            } -ModuleName SearchTools
        }

        It 'skips access denied by default and still returns accessible items' {
            Set-SearchAccessDeniedMock
            $items = @(Search-ChildItem 2>&1)
            $items.Count | Should Be 1
            $items[0].Name | Should Be 'allowed.txt'
        }

        It 'reports skipped access-denied paths with Verbose' {
            Set-SearchAccessDeniedMock
            $records = @(Search-ChildItem -Verbose 4>&1)
            @($records | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Count | Should Be 1
        }

        It 'surfaces access denied when ErrorAction Continue is explicit' {
            Set-SearchAccessDeniedMock
            $records = @(Search-ChildItem -ErrorAction Continue 2>&1)
            @($records | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
        }

        It 'stops on access denied when ErrorAction Stop is explicit' {
            Set-SearchAccessDeniedMock
            { Search-ChildItem -ErrorAction Stop } | Should Throw 'Synthetic access denied'
        }

        It 'honors a changed ErrorActionPreference' {
            Set-SearchAccessDeniedMock
            $ErrorActionPreference = 'Stop'
            { Search-ChildItem } | Should Throw 'Synthetic access denied'
        }
    }
}
