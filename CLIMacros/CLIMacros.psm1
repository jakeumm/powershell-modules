function Copy-Path {
    <#
    .SYNOPSIS
        Copies a double-quoted file or directory path to the clipboard.
    .DESCRIPTION
        Copies and returns the full path of a specified existing item, surrounded
        by double quotes. With no path or a blank path, uses the current location.
    .PARAMETER Path
        File or directory path. Supports PowerShell wildcard syntax.
    .EXAMPLE
        Copy-Path
    .EXAMPLE
        Copy-Path '.\file.txt'
    #>
    param (
        [Parameter(Position = 0)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $currentPath = Get-Location
        $quotedPath = '"' + $currentPath.Path + '"'
    }
    else {
        if (-not (Test-Path $Path)) {
            Write-Host 'No Directory or File can be found with that path' -ForegroundColor Red
            return
        }
        $item = Get-Item -Path $Path
        $quotedPath = '"' + $item.FullName + '"'
    }

    $quotedPath | Set-Clipboard
    Write-Output $quotedPath
}

function pwd {
    <#
    .SYNOPSIS
        Copies the current provider path to the clipboard and returns it.
    .DESCRIPTION
        Returns the current location's ProviderPath as an unquoted string and
        copies the same value to the clipboard on every call. Use CLIMacros\pwd
        or remove the built-in pwd alias to invoke this function.
    .EXAMPLE
        CLIMacros\pwd
    #>
    $currentDir = Get-Location
    $presentDir = $currentDir.ProviderPath
    $presentDir | Set-Clipboard
    Write-Output $presentDir
}

function findstr {
    <#
    .SYNOPSIS
        Filters pipeline text with case-insensitive Windows findstr matching.
    .DESCRIPTION
        Pipes input to findstr.exe with /i and forwards all supplied arguments.
        Requires Windows findstr.exe. Arguments follow native findstr syntax.
    .EXAMPLE
        'ERROR: failed', 'ready' | findstr error
    .EXAMPLE
        Get-Content .\application.log | findstr /n error
    #>
    $input | & findstr.exe /i @args
}

function cd {
    <#
    .SYNOPSIS
        Changes directory using a path or a Windows .lnk shortcut.
    .DESCRIPTION
        For a target ending in lowercase .lnk, resolves its TargetPath through
        WScript.Shell and changes to that directory. Other targets are passed
        to Set-Location. Expects a target argument. Use CLIMacros\cd or remove
        the built-in cd alias to invoke this function.
    .PARAMETER Target
        Directory path or a .lnk shortcut whose target is a directory.
    .EXAMPLE
        CLIMacros\cd '.\Project.lnk'
    .EXAMPLE
        CLIMacros\cd 'C:\Projects'
    #>
    param ($Target)

    if ($Target.EndsWith('.lnk')) {
        $shell = New-Object -ComObject WScript.Shell
        $fullPath = Resolve-Path $Target
        $targetPath = $shell.CreateShortcut($fullPath).TargetPath
        Set-Location $targetPath
    }
    else {
        Set-Location $Target
    }
}

Register-ArgumentCompleter -CommandName cd, 'CLIMacros\cd' -ParameterName Target -ScriptBlock {
    param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)

    $word = if ($wordToComplete) { $wordToComplete } else { '*' }
    $items = Get-ChildItem -Path . -Filter "$word*.lnk" -File
    foreach ($item in $items) {
        [System.Management.Automation.CompletionResult]::new(
            $item.Name,
            $item.Name,
            'ParameterValue',
            $item.FullName
        )
    }
}

Export-ModuleMember -Function Copy-Path, pwd, cd, findstr
