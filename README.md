**PowerShell Modules** is a collection of utilities for finding files and directories, reusing persistent command history, and working with Linux-style command helpers. Use PowerShell 7 or later; the setup scripts use Windows installation paths by default.

| Module | Commands | Purpose |
| --- | --- | --- |
| [PSHistory](PSHistory/readme.md) | `Get-PSHistory`, `Search-PSHistory` | Retrieve and search existing PSReadLine history across sessions, with multiline support, regex matching, and deduplication. |
| [SearchTools](SearchTools/readme.md) | `Search-ChildItem` | Search recursively by name, returning files by default or directories with `-Directory`. Supports depth limits, hidden items, and literal paths. |
| [LinuxAliases](LinuxAliases/readme.md) | `grep`, `touch`, `vi` | Search text with basic grep-style flags, create items with `New-Item`, and launch Vim. |
| [CLIMacros](CLIMacros/readme.md) | `Copy-Path`, `pwd`, `cd`, `findstr` | Copy paths to the clipboard, navigate through Windows shortcuts, and filter text case-insensitively. |
| [GroupPolicy](GroupPolicy/readme.md) | `Get-GroupPolicy` | Refresh policy and open an HTML report locally or from a remote computer using PowerShell remoting and administrative shares. |

Setup scripts are available for PSHistory, SearchTools, and LinuxAliases. Run the ones you want from the repository root:

```powershell
.\PSHistory\setup.ps1
.\SearchTools\setup.ps1
.\LinuxAliases\setup.ps1
```

Each script creates the destination directories, installs its module, and prompts to import it into the current session. Answer `y` or `yes` to import; press Enter to skip. Running setup again refreshes the installed module.

The default installation places the files directly in:

```text
$HOME\Documents\WindowsPowerShell\Modules\PSHistory.psm1
$HOME\Documents\WindowsPowerShell\Modules\PSHistory.format.ps1xml
$HOME\Documents\WindowsPowerShell\Modules\SearchTools.psm1
$HOME\Documents\WindowsPowerShell\Modules\SearchTools.format.ps1xml
$HOME\Documents\WindowsPowerShell\Modules\LinuxAliases.psm1
```

These destinations use `WindowsPowerShell` even when setup runs in PowerShell 7. All installers accept `-ModulePath` to select a different destination file. PSHistory and SearchTools also install their format definitions beside the module; keep each of those modules and its format file together. PSHistory setup also accepts `-ProfilePath` to select a different profile. LinuxAliases installs a single module file; `vi` requires Vim to be installed separately.

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
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\LinuxAliases.psm1')
```

To load the modules automatically in future sessions, add the desired import lines above to `$PROFILE`. If you selected custom installation paths, use those paths instead. Setup's import prompts apply to the current session; automatic imports are configured separately in the profile.

For use directly from a checkout, import the source files:

```powershell
Import-Module .\PSHistory\PSHistory.psm1
Import-Module .\SearchTools\SearchTools.psm1
Import-Module .\LinuxAliases\LinuxAliases.psm1
Import-Module .\CLIMacros\CLIMacros.psm1
Import-Module .\GroupPolicy\GroupPolicy.psm1
```

CLIMacros and GroupPolicy use these direct imports. To load either in future sessions, add its import to `$PROFILE` with an absolute path to your checkout. The module READMEs include alias activation and migration instructions for existing CLIMacros and LinuxAliases users.

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

# Search pipeline text using grep-style ignore-case and line-number flags.
'INFO: ready', 'ERROR: failed' | grep -in error

# Copy a quoted full path to the clipboard.
Copy-Path .\README.md

# Use a macro even while PowerShell's built-in pwd alias is present.
CLIMacros\pwd

# Refresh remote computer policy and open its HTML report through C$.
Get-GroupPolicy -ComputerName PC01

# Save the remote report in an existing folder on that computer.
$computerName = 'PC01'
Get-GroupPolicy -ComputerName $computerName -Path "\\$computerName\c$\Reports" -Name 'Policy.html'
```

PSHistory returns full `PSHistory.Entry` objects, newest first, with a default display showing only `CommandLine`. Metadata such as `EntryNumber` and `SourcePath` remains available downstream. Use `-AsString` for complete command strings. It reads saved history; timestamps and other execution metadata are not available from that file.

SearchTools returns full `FileInfo` or `DirectoryInfo` objects with a default two-column display showing `LastWriteTime` and `FullName`. All properties remain available for downstream selection, filtering, and export. It skips access-denied errors by default, reports skipped paths with `-Verbose`, and honors an explicit `-ErrorAction`. `-File` and `-Directory` are mutually exclusive.

CLIMacros is imported directly from its `.psm1` file. `Copy-Path` and the `pwd` macro update the clipboard. Use `CLIMacros\cd` and `CLIMacros\pwd`, or remove the built-in `cd` and `pwd` aliases in the current scope to activate those short names; the [CLIMacros README](CLIMacros/readme.md) shows the import commands. Shortcut resolution and `findstr.exe` require Windows.

GroupPolicy runs `gpupdate.exe` and `gpresult.exe` locally or through `Invoke-Command -ComputerName`. Remote calls use the current account and require PowerShell remoting plus SMB administrative-share access. Reports default to both user and computer policy locally and computer policy remotely; select `-Scope Both`, `User`, or `Computer` explicitly when needed. Custom report folders must already exist on the computer processing the request.

See each module's readme for all parameters, setup options, behavior, and troubleshooting:

- [PSHistory documentation](PSHistory/readme.md)
- [SearchTools documentation](SearchTools/readme.md)
- [LinuxAliases documentation](LinuxAliases/readme.md)
- [CLIMacros documentation](CLIMacros/readme.md)
- [GroupPolicy documentation](GroupPolicy/readme.md)

Built-in help is also available after import:

```powershell
Get-Help Get-PSHistory -Full
Get-Help Search-PSHistory -Examples
Get-Help Search-ChildItem -Full
Get-Help grep -Full
Get-Help .\LinuxAliases\setup.ps1 -Full
Get-Help Copy-Path -Full
Get-Help Get-GroupPolicy -Full
```

Planning documents, `Test`/`Tests` folders, and the root `temp` folder are ignored by Git. Test suites and temporary files are kept locally and are not included in a fresh checkout.

The local test suites have been run with Pester 3.4.0. If you have those local test files and that Pester version installed, run them from the repository root:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\PSHistory\Tests\PSHistory.Tests.ps1
Invoke-Pester -Script .\SearchTools\Tests\SearchTools.Tests.ps1
Invoke-Pester -Script .\LinuxAliases\Tests\grep.Tests.ps1
Invoke-Pester -Script .\CLIMacros\Tests\CLIMacros.Tests.ps1
Invoke-Pester -Script .\GroupPolicy\Tests\GroupPolicy.Tests.ps1
```
