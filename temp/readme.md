This README documents the helpers originally staged in **temp**. The CLI helpers are combined in the [CLIMacros module](../CLIMacros/readme.md), policy reporting lives in [GroupPolicy](../GroupPolicy), and `grep`, `touch`, and `vi` are combined in the [LinuxAliases module](../LinuxAliases/readme.md). The Notepad++ launcher remains in [notepad.ps1](notepad.ps1) here in `temp`.

Import the modules or dot-source the remaining standalone scripts to make their commands available in the current session. The examples below assume you are in the repository root. To load a helper in future sessions, add its dot-source or import command to `$PROFILE`, using the full path.

| Helper | Command defined | What it does |
| --- | --- | --- |
| [CLIMacros.psm1](../CLIMacros/CLIMacros.psm1) | `Copy-Path` | Copies a double-quoted path to the clipboard and returns the same string. |
| [Get-GroupPolicy.ps1](../GroupPolicy/Get-GroupPolicy.ps1) | `Get-GroupPolicy` | Refreshes Group Policy, generates an HTML report, and opens it. |
| [CLIMacros.psm1](../CLIMacros/CLIMacros.psm1) | `cd` function and argument completer | Changes directory through a Windows `.lnk` shortcut or a normal path. |
| [CLIMacros.psm1](../CLIMacros/CLIMacros.psm1) | `findstr` function | Sends pipeline input to `findstr.exe` with case-insensitive matching. |
| [LinuxAliases.psm1](../LinuxAliases/LinuxAliases.psm1) | `grep` function | Searches text and files with basic grep-style flags. |
| [notepad.ps1](notepad.ps1) | `notepad` alias | Opens Notepad++ through `notepad++.exe`. |
| [CLIMacros.psm1](../CLIMacros/CLIMacros.psm1) | `pwd` function | Copies the current provider path to the clipboard and returns it. |
| [LinuxAliases.psm1](../LinuxAliases/LinuxAliases.psm1) | `touch` alias | Calls `New-Item` to create files or other item types. |
| [LinuxAliases.psm1](../LinuxAliases/LinuxAliases.psm1) | `vi` alias | Opens Vim through `vim`. |

The [CLIMacros module](../CLIMacros/CLIMacros.psm1) exports `Copy-Path [-Path <string>]`. With no path, or a blank path, it uses the current location. With a supplied path, it checks that the item exists and retrieves its full path. Both forms copy and output the path surrounded by double quotes.

```powershell
Import-Module .\CLIMacros\CLIMacros.psm1

Copy-Path
Copy-Path '.\README.md'
Copy-Path '.\SearchTools'
```

An example result is `"C:\Projects\powershell-modules\README.md"`. A missing path prints a red host message and returns without copying it. Path lookup uses PowerShell wildcard syntax and is intended for a single file or directory. Clipboard access requires `Set-Clipboard` support in the current environment.

[Get-GroupPolicy.ps1](../GroupPolicy/Get-GroupPolicy.ps1) defines `Get-GroupPolicy [-Path <string>] [-Name <string>]`. Calling it performs these steps:

1. Ensures `$Env:LOCALAPPDATA\Custom-Functions\Get-GroupPolicy` exists. This default directory is created even when a custom report path is supplied.
2. Chooses the report destination and appends `.html` to the filename if needed.
3. Runs `gpupdate.exe /force` to refresh Group Policy, suppressing its normal output.
4. Runs `gpresult.exe /h <reportPath>` to generate the report.
5. Opens the report with `Start-Process` and outputs `GPResult saved to <reportPath>`.

```powershell
. .\GroupPolicy\Get-GroupPolicy.ps1

# Use the default directory and a timestamped report name.
Get-GroupPolicy

# Use an existing folder and a custom name.
Get-GroupPolicy -Path 'C:\Reports' -Name 'Workstation-policy.html'

# Supply a full report path whose parent directory already exists.
Get-GroupPolicy -Path 'C:\Reports\Workstation-policy.html' -Verbose
```

The default filename is `yyyy-MM-dd-HHmmss-GPResult.html`. Custom folders must already exist. A supplied `-Name` overrides the filename portion of a full `-Path`.

This helper requires Windows, `gpupdate.exe`, `gpresult.exe`, and an application associated with HTML files. It refreshes policy as part of generating the report. Its path classification uses `[IO.Path]::HasExtension()`, so a folder name containing a dot can be interpreted as a filename; use a full report filename under such a folder. The function does not check native command exit codes before attempting to open the report.

The [CLIMacros module](../CLIMacros/CLIMacros.psm1) exports a `cd` function. For a target ending in lowercase `.lnk`, it resolves the shortcut with the Windows `WScript.Shell` COM object and passes its `TargetPath` to `Set-Location`. Other targets go directly to `Set-Location`.

PowerShell's built-in `cd` alias takes precedence over a function with the same name. To use this function as `cd`, load it and remove that alias in the current scope:

```powershell
Remove-Item Alias:cd -Force
Import-Module .\CLIMacros\CLIMacros.psm1

cd '.\Project.lnk'
cd 'C:\Projects'
```

Importing the module also registers argument completion for `cd` and `CLIMacros\cd`. It suggests `.lnk` files from the current directory using the typed prefix. Shortcut targets must be directories. The function expects a target argument, and its `.lnk` suffix check is case-sensitive. The completer inserts bare filenames, so quote names containing spaces when invoking the command. Shortcut resolution requires Windows COM support.

The [CLIMacros module](../CLIMacros/CLIMacros.psm1) exports a `findstr` wrapper that pipes `$input` to `findstr.exe /i` and forwards all supplied arguments. Matching is case-insensitive because `/i` is always supplied. Additional patterns and flags follow the native `findstr.exe` syntax; results are matching text lines.

```powershell
Import-Module .\CLIMacros\CLIMacros.psm1

'ERROR: failed', 'INFO: ready' | findstr 'error'
Get-Content '.\application.log' | findstr /n 'error'
```

This helper requires Windows `findstr.exe` to be available.

The [LinuxAliases module](../LinuxAliases/readme.md) exports a `grep` function supporting `-i`, `-v`, `-F`, `-n`, and `-r`, including combined flags. It returns text lines and matches case-sensitively by default. Patterns use .NET regular expressions; use `-F` for literal matching.

```powershell
Import-Module .\LinuxAliases\LinuxAliases.psm1

grep -i error '.\application.log'
'alpha', 'beta' | grep -F alpha
```

[notepad.ps1](notepad.ps1) aliases `notepad` to `notepad++.exe`. Notepad++ must be installed and its executable available through command discovery, such as on `PATH`.

```powershell
. .\temp\notepad.ps1

notepad '.\notes.txt'
```

The [CLIMacros module](../CLIMacros/CLIMacros.psm1) exports a `pwd` function. Each call obtains `Get-Location`, copies its `ProviderPath` to the clipboard, and returns that path as an unquoted string. Use the module-qualified name or remove the built-in `pwd` alias to activate the short name.

```powershell
Import-Module .\CLIMacros\CLIMacros.psm1

CLIMacros\pwd
```

This changes the clipboard on each call and requires `Set-Clipboard` support. The returned value is the current provider path rather than a `PathInfo` object.

The [LinuxAliases module](../LinuxAliases/LinuxAliases.psm1) exports `touch` as an alias for `New-Item`. It uses PowerShell's item-creation parameters. For example, explicitly select `File` to create an empty file:

```powershell
Import-Module .\LinuxAliases\LinuxAliases.psm1

touch '.\new-file.txt' -ItemType File
touch '.\new-folder' -ItemType Directory
```

Existing-item behavior follows `New-Item`; this alias does not implement Unix `touch` timestamp updates.

The [LinuxAliases module](../LinuxAliases/LinuxAliases.psm1) exports `vi` as an alias for `vim`. Vim must be installed and available through command discovery, such as on `PATH`.

```powershell
Import-Module .\LinuxAliases\LinuxAliases.psm1

vi '.\notes.txt'
```

Loading the scripts or importing the module configures the current PowerShell session; use profile entries to load them again in later sessions.
