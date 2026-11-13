**CLIMacros** combines clipboard paths, shortcut navigation, and case-insensitive text filtering in [CLIMacros.psm1](CLIMacros.psm1). Import it from the repository root:

```powershell
Import-Module .\CLIMacros\CLIMacros.psm1
```

The module exports four functions:

| Command | Behavior |
| --- | --- |
| `Copy-Path` | Copy and return a double-quoted full path. Defaults to the current location. |
| `pwd` | Copy and return the current provider path as an unquoted string. |
| `cd` | Change directory through a directory path or a Windows `.lnk` shortcut. |
| `findstr` | Filter text through `findstr.exe`, always supplying `/i` for case-insensitive matching. |

PowerShell's built-in `cd` and `pwd` aliases take precedence over functions with the same names. To activate the macros under those short names, remove the aliases in your current scope before importing:

```powershell
Remove-Item -LiteralPath Alias:cd, Alias:pwd -Force -ErrorAction SilentlyContinue
Import-Module .\CLIMacros\CLIMacros.psm1 -Force
```

You can also call `CLIMacros\cd` or `CLIMacros\pwd` directly after import. To load the macros in future sessions, put the alias-removal and import commands in `$PROFILE`, using the full path to the module. Replace any old dot-source lines for the four standalone scripts with that module import.

`Copy-Path [-Path <string>]` copies and outputs a path surrounded by double quotes. No argument, an empty string, or whitespace selects the current location. A supplied path must exist; a missing path prints a red host message and returns without updating the clipboard.

```powershell
Copy-Path
Copy-Path '.\README.md'
Copy-Path '.\SearchTools'
```

Path lookup uses PowerShell wildcard syntax and is intended for one file or directory. A typical result is `"C:\Projects\powershell-modules\README.md"`.

`pwd` copies the current location's `ProviderPath` to the clipboard and returns the same unquoted string on every call:

```powershell
CLIMacros\pwd
```

Both path commands require `Set-Clipboard` support in the current environment.

`cd <target>` passes ordinary paths to `Set-Location`. For a target ending in lowercase `.lnk`, it resolves the shortcut through the Windows `WScript.Shell` COM object and changes to the shortcut's target directory:

```powershell
CLIMacros\cd 'C:\Projects'
CLIMacros\cd '.\Project.lnk'
```

Importing registers shortcut completion for both `cd` and `CLIMacros\cd`. Completion suggests `.lnk` files in the current directory using the typed prefix. The function requires a target argument, and its `.lnk` suffix check is case-sensitive. Shortcut targets must be directories. The completer inserts bare filenames; quote paths containing spaces when invoking the command. Shortcut resolution requires Windows COM support.

`findstr` pipes input to Windows `findstr.exe /i` and forwards all additional arguments. Matching is always case-insensitive, and output consists of matching text lines. Patterns and switches use native `findstr.exe` syntax:

```powershell
'ERROR: failed', 'INFO: ready' | findstr error
Get-Content .\application.log | findstr /n error
```

`findstr.exe` must be available through command discovery. The Notepad++ launcher remains a separate [temp/notepad.ps1](../temp/notepad.ps1) script.

Built-in help is available after importing:

```powershell
Get-Help Copy-Path -Full
Get-Help CLIMacros\pwd -Full
Get-Help CLIMacros\cd -Full
Get-Help CLIMacros\findstr -Full
```

The [tests](Tests/CLIMacros.Tests.ps1) verify exports, clipboard values, navigation, shortcut resolution and completion, and case-insensitive text filtering. Clipboard writes and COM shortcut resolution are mocked. The suite uses Pester 3.4.0:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\CLIMacros\Tests\CLIMacros.Tests.ps1
```
