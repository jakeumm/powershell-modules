**PowerShell Modules** is a collection of utilities for finding files and directories and reusing persistent command history. Use PowerShell 7 or later; the setup scripts use Windows installation paths by default.

| Module | Commands | Purpose |
| --- | --- | --- |
| [PSHistory](PSHistory/readme.md) | `Get-PSHistory`, `Search-PSHistory` | Retrieve and search existing PSReadLine history across sessions, with multiline support, regex matching, and deduplication. |
| [SearchTools](SearchTools/readme.md) | `Search-ChildItem` | Search recursively by name, returning files by default or directories with `-Directory`. Supports depth limits, hidden items, and literal paths. |
| [LinuxAliases](LinuxAliases/readme.md) | `grep`, `touch`, `vi` | Search text with basic grep-style flags, create items with `New-Item`, and launch Vim. Import `LinuxAliases.psm1` directly. |

Run either or both setup scripts from the repository root:

```powershell
.\PSHistory\setup.ps1
.\SearchTools\setup.ps1
```

Each script creates the destination directories, installs its module, and prompts to import it into the current session. Answer `y` or `yes` to import; press Enter to skip. Running setup again refreshes the installed module.

The default installation places the files directly in:

```text
$HOME\Documents\WindowsPowerShell\Modules\PSHistory.psm1
$HOME\Documents\WindowsPowerShell\Modules\PSHistory.format.ps1xml
$HOME\Documents\WindowsPowerShell\Modules\SearchTools.psm1
$HOME\Documents\WindowsPowerShell\Modules\SearchTools.format.ps1xml
```

These destinations use `WindowsPowerShell` even when setup runs in PowerShell 7. Both installers accept `-ModulePath` to select a different destination file and install their format definition beside the module; keep each module and its format file together. PSHistory setup also accepts `-ProfilePath` to select a different profile.

PSHistory setup adds these settings to the current host's `$PROFILE` when they are missing:

```powershell
$MaximumHistoryCount = 10000
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
```

The settings take effect when that profile next loads, such as in a new shell. PSReadLine is required for automatic history-path discovery; PSHistory can also read an explicit UTF-8 history file with `-Path`.

Import the default installations by full path in later sessions:

```powershell
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\PSHistory.psm1')
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\SearchTools.psm1')
```

To load the modules automatically in future sessions, add the desired import lines above to `$PROFILE`. If you selected custom installation paths, use those paths instead. Setup's import prompts apply to the current session; automatic imports are configured separately in the profile.

For use directly from a checkout, import the source files:

```powershell
Import-Module .\PSHistory\PSHistory.psm1
Import-Module .\SearchTools\SearchTools.psm1
Import-Module .\LinuxAliases\LinuxAliases.psm1
```

Try these examples after importing:

```powershell
# Retrieve the newest 50 persisted commands.
Get-PSHistory

# Find the newest 20 distinct commands containing a literal substring.
Search-PSHistory 'git commit' -Last 20 -Unique

# Search history with a regular expression.
Search-PSHistory '^Get-\w+' -Regex

# Select history metadata beyond the default CommandLine display.
Search-PSHistory 'git' | Select-Object EntryNumber, SourcePath, CommandLine

# Copy the newest matching command to the clipboard.
Search-PSHistory 'docker' -Last 1 -AsString | Set-Clipboard

# Find files recursively; file-only searching is the default.
Search-ChildItem '*.log' -Path 'C:\Projects'

# Find directories instead of files.
Search-ChildItem '*cache*' -Directory

# Select file properties beyond the default display columns.
Search-ChildItem '*.log' | Select-Object Extension, Length, FullName

# Include hidden files and limit recursion.
Search-ChildItem '*.ps1' -Force -Depth 1

# Treat wildcard characters in a starting path literally.
Search-ChildItem '*.log' -LiteralPath 'C:\Builds\[latest]'
```

PSHistory returns full `PSHistory.Entry` objects, newest first, with a default display showing only `CommandLine`. Metadata such as `EntryNumber` and `SourcePath` remains available downstream. Use `-AsString` for complete command strings. It reads saved history; timestamps and other execution metadata are not available from that file.

SearchTools returns full `FileInfo` or `DirectoryInfo` objects with a default two-column display showing `LastWriteTime` and `FullName`. All properties remain available for downstream selection, filtering, and export. It skips access-denied errors by default, reports skipped paths with `-Verbose`, and honors an explicit `-ErrorAction`. `-File` and `-Directory` are mutually exclusive.

See each module's readme for all parameters, setup options, behavior, and troubleshooting:

- [PSHistory documentation](PSHistory/readme.md)
- [SearchTools documentation](SearchTools/readme.md)
- [LinuxAliases documentation](LinuxAliases/readme.md)

Built-in help is also available after import:

```powershell
Get-Help Get-PSHistory -Full
Get-Help Search-PSHistory -Examples
Get-Help Search-ChildItem -Full
```

The test suites have been run with Pester 3.4.0. With that version installed, run them from the repository root:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\PSHistory\Tests\PSHistory.Tests.ps1
Invoke-Pester -Script .\SearchTools\Tests\SearchTools.Tests.ps1
Invoke-Pester -Script .\LinuxAliases\Tests\grep.Tests.ps1
```
