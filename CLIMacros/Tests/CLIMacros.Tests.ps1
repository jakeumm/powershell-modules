Import-Module (Join-Path $PSScriptRoot '..\CLIMacros.psm1') -Force

Describe 'CLIMacros module exports' {
    It 'exports the four existing macros' {
        (((Get-Module CLIMacros).ExportedFunctions.Keys | Sort-Object) -join ',') | Should Be 'cd,Copy-Path,findstr,pwd'
    }
}

Describe 'CLIMacros clipboard paths' {
    InModuleScope CLIMacros {
        It 'copies and returns the current location with double quotes' {
            Mock Set-Clipboard { } -ModuleName CLIMacros
            $expected = '"' + (Get-Location).Path + '"'
            Copy-Path | Should Be $expected
            Assert-MockCalled Set-Clipboard -ModuleName CLIMacros -Times 1 -Scope It -ParameterFilter { $Value -eq $expected }
        }

        It 'resolves file and directory paths and copies the quoted full path' {
            Mock Set-Clipboard { } -ModuleName CLIMacros
            $path = Join-Path $TestDrive 'file with spaces.txt'
            [IO.File]::WriteAllText($path, 'test')
            $expected = '"' + $path + '"'
            Copy-Path $path | Should Be $expected
            Assert-MockCalled Set-Clipboard -ModuleName CLIMacros -Times 1 -Scope It -ParameterFilter { $Value -eq $expected }
            Copy-Path $TestDrive | Should Be ('"' + (Get-Item -LiteralPath $TestDrive).FullName + '"')
        }

        It 'leaves the clipboard alone for a missing path' {
            Mock Set-Clipboard { } -ModuleName CLIMacros
            Mock Write-Host { } -ModuleName CLIMacros
            @(Copy-Path (Join-Path $TestDrive 'missing.txt')).Count | Should Be 0
            Assert-MockCalled Set-Clipboard -ModuleName CLIMacros -Times 0 -Scope It
        }

        It 'copies and returns the unquoted current provider path through pwd' {
            Mock Set-Clipboard { } -ModuleName CLIMacros
            $expected = (Get-Location).ProviderPath
            CLIMacros\pwd | Should Be $expected
            Assert-MockCalled Set-Clipboard -ModuleName CLIMacros -Times 1 -Scope It -ParameterFilter { $Value -eq $expected }
        }
    }
}

Describe 'CLIMacros navigation' {
    It 'changes the caller location using an ordinary directory path' {
        $target = Join-Path $TestDrive 'normal'
        [void][IO.Directory]::CreateDirectory($target)
        Push-Location
        try {
            CLIMacros\cd $target
            (Get-Location).Path | Should Be $target
        }
        finally { Pop-Location }
    }

    It 'completes shortcuts in the current directory' {
        [IO.File]::WriteAllText((Join-Path $TestDrive 'Project.lnk'), '')
        Push-Location -LiteralPath $TestDrive
        try {
            foreach ($command in @('CLIMacros\cd Pro')) {
                $completions = TabExpansion2 $command $command.Length
                (@($completions.CompletionMatches.CompletionText) -contains 'Project.lnk') | Should Be $true
            }
        }
        finally { Pop-Location }
    }

    InModuleScope CLIMacros {
        It 'resolves a shortcut target before changing directory' {
            $target = Join-Path $TestDrive 'shortcut-target'
            [void][IO.Directory]::CreateDirectory($target)
            $shortcutPath = Join-Path $TestDrive 'Project.lnk'
            [IO.File]::WriteAllText($shortcutPath, '')
            $script:fakeShell = [pscustomobject]@{ Target = $target }
            $script:fakeShell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value {
                param ($Path)
                [pscustomobject]@{ TargetPath = $this.Target }
            }
            Mock New-Object { $script:fakeShell } -ModuleName CLIMacros -ParameterFilter { $ComObject -eq 'WScript.Shell' }
            Push-Location
            try {
                CLIMacros\cd $shortcutPath
                (Get-Location).Path | Should Be $target
                Assert-MockCalled New-Object -ModuleName CLIMacros -Times 1 -ParameterFilter { $ComObject -eq 'WScript.Shell' }
            }
            finally { Pop-Location }
        }
    }
}

Describe 'CLIMacros findstr wrapper' {
    It 'filters pipeline input without case sensitivity' {
        $lines = @('ERROR: failed', 'error: retry', 'ready' | CLIMacros\findstr error)
        ($lines -join ',') | Should Be 'ERROR: failed,error: retry'
    }

    It 'forwards additional native arguments such as line numbering' {
        @('ready', 'ERROR: failed' | CLIMacros\findstr /n error)[0] | Should Be '2:ERROR: failed'
    }
}
