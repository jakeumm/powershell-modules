**PSHistory** retrieves and searches commands saved by PSReadLine across PowerShell sessions. It reads the existing history file and returns complete commands, including multiline input, newest first. The module exports `Get-PSHistory` and `Search-PSHistory`.

PowerShell 7 or later is required. PSReadLine is needed for automatic history-path discovery; an explicit `-Path` works without PSReadLine. The module has no other runtime dependencies. The setup script defaults to Windows installation paths.

Run setup from the repository root:

```powershell
.\PSHistory\setup.ps1
```

The script copies [PSHistory.psm1](PSHistory.psm1) to:

```text
$HOME\Documents\WindowsPowerShell\Modules\PSHistory.psm1
```

It also installs [PSHistory.format.ps1xml](PSHistory.format.ps1xml) beside the module. This file supplies the default `CommandLine`-only display and must stay with the installed module, including when using a custom `-ModulePath`.

It creates the destination directories and the current host's `$PROFILE` if needed, then appends any missing settings:

```powershell
$MaximumHistoryCount = 10000
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
```

Existing profile content is retained, and BOM-marked encodings are detected and preserved. A new profile uses UTF-8 without a BOM. Repeating setup refreshes the module and format file and skips settings already present in the recognized form.

Setup prompts `Import PSHistory into this session now? [y/N]`. Answer `y` or `yes` to import it into the current session; Enter skips the import. The profile settings take effect when the profile next loads, such as when you open a new shell. Importing the module alone does not apply those settings.

Setup updates the profile for the PowerShell host running it. The default module destination remains the WindowsPowerShell path shown above even when setup runs in PowerShell 7. You can override either destination:

| Setup parameter | Default | Purpose |
| --- | --- | --- |
| `-ProfilePath` | `$PROFILE` | Select a different profile file. |
| `-ModulePath` | `$HOME\Documents\WindowsPowerShell\Modules\PSHistory.psm1` | Select a different destination module file. |

Keep [setup.ps1](setup.ps1), `PSHistory.psm1`, and `PSHistory.format.ps1xml` together when running setup.

To import the default installation later, use its full path:

```powershell
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\PSHistory.psm1')
```

Setup installs the module and format file directly in `Modules`, so the full-path import is the documented way to load it. Setup adds only the history settings to the profile. To load PSHistory automatically in future sessions, also add the import line above to your profile. If you supplied `-ModulePath`, use that path instead.

You can also use the module directly from the repository without running setup:

```powershell
Import-Module .\PSHistory\PSHistory.psm1
```

Start with these retrieval and search examples:

```powershell
# Retrieve the newest 50 persisted commands.
Get-PSHistory

# Retrieve the newest 100 distinct commands.
Get-PSHistory -Last 100 -Unique

# Retrieve every persisted command.
Get-PSHistory -All

# Find a literal substring, ignoring case.
Search-PSHistory 'git commit'

# Return the newest 20 matching commands, with duplicates removed.
Search-PSHistory 'docker' -Last 20 -Unique

# Match a regular expression.
Search-PSHistory '^Get-\w+' -Regex

# Match case exactly.
Search-PSHistory 'Get-Item' -CaseSensitive

# Copy the newest matching command to the clipboard.
Search-PSHistory 'ssh' -Last 1 -AsString | Set-Clipboard

# Read a specific history file; spaces and wildcard characters in the path are literal.
Get-PSHistory -Path 'C:\Backups\ConsoleHost_history.txt' -Last 10

# Export matching records using the normal PowerShell pipeline.
Search-PSHistory 'git' -All | Export-Csv .\git-history.csv -NoTypeInformation
```

Both commands share these parameters:

| Parameter | Behavior |
| --- | --- |
| `-Last <int>` | Return the newest N results. Defaults to `50`; must be positive. |
| `-All` | Return every result. Cannot be combined with `-Last`. |
| `-Path <string>` | Read one literal file path instead of discovering the current PSReadLine path. |
| `-Unique` | Keep only the latest occurrence of each exact command text. Comparison is case-sensitive and preserves whitespace. |
| `-AsString` | Return full command strings instead of entry objects. |

`Search-PSHistory` adds these parameters:

| Parameter | Behavior |
| --- | --- |
| `-Pattern <string>` | Required search text, also accepted as the first positional argument. An empty string matches every command. |
| `-Regex` | Interpret the pattern as a .NET regular expression. Invalid patterns and match timeouts raise errors. |
| `-CaseSensitive` | Enable case-sensitive matching in either literal or regex mode. |

Search defaults to a literal, case-insensitive substring match. Characters such as `*`, `[` and `]` have no special meaning unless `-Regex` is used. Matching covers the entire decoded command, including embedded newlines. With regex, use `(?s)` when `.` should match newlines. Regex matching has a one-second timeout per command, rather than a timeout for the entire query.

Filtering and optional deduplication happen before the result limit. For example, `Search-PSHistory 'git' -Last 10` searches the file for the newest ten matches, even if the ten newest entries contain no Git commands. Case-sensitive deduplication is independent of the search's case setting.

Both `Search-PSHistory` and `Get-PSHistory` display only `CommandLine` by default, with multiline commands wrapped for readability. Each result remains a full `PSHistory.Entry` object with these properties:

| Property | Meaning |
| --- | --- |
| `CommandLine` | Complete command text, including embedded newlines. Decoded multiline separators use LF. |
| `SourcePath` | Absolute path to the history file. |
| `EntryNumber` | One-based logical record position in that file before filtering. |
| `StartLine` | One-based first physical file line for the record. |
| `EndLine` | One-based last physical file line for the record. |

Use normal PowerShell formatting to inspect or select properties beyond the default display:

```powershell
Get-PSHistory -Last 1 | Format-List *
Search-PSHistory 'git' | Select-Object EntryNumber, CommandLine
Search-PSHistory 'git' | Select-Object SourcePath, StartLine, EndLine
```

The display does not restrict pipeline data or exported columns. `Export-Csv` receives all entry properties unless you select a subset first. `-AsString` returns plain command strings without a table header. Re-run setup and import the refreshed module to update an existing installation.

`EntryNumber` is a position in the source file and can change if the file is rewritten. It is separate from the session IDs used by `Get-History` and `Invoke-History`. Results are ordered by file position; they do not establish execution order across concurrent shells. PSHistory does not provide timestamps, duration, exit status, working directory, or originating session because that metadata is absent from the persisted command text.

Without `-Path`, each query resolves `(Get-PSReadLineOption).HistorySavePath`. This honors custom paths and selects the current host's history file. A query reads one file; it does not combine history from other hosts or include unsaved in-memory entries. Built-in `Get-History` works with separate session history.

History freshness depends on PSReadLine's save style:

| Save style | Effect on PSHistory results |
| --- | --- |
| `SaveIncrementally` | New commands become available as PSReadLine saves them during the session. |
| `SaveAtExit` | Commands from an active session may be unavailable until that session exits. |
| `SaveNothing` | New commands are not persisted. An existing file can still be queried. |

History files must be UTF-8, with or without a BOM. Both LF and CRLF line endings are supported. Multiline decoding follows PSReadLine's trailing-backtick convention and its format limitations. A query permits other processes to append but reads only up to the file length observed when opened. Incomplete final lines or continuation records are deferred until a later query; `-Verbose` reports this. Truncation detected during a read raises an error so you can retry.

Queries leave the source file and PSReadLine settings unchanged and return command text as data. They do not execute, delete, or add history entries. Every query scans the selected file, including queries with `-Last`. Limited queries retain only the newest requested results; `-All` uses more memory to return results in reverse file order.

If you receive no results or an error, check the selected source and persistence settings:

```powershell
Get-PSReadLineOption | Select-Object HistorySavePath, HistorySaveStyle, MaximumHistoryCount
Get-PSHistory -Verbose
```

- A missing automatically discovered file returns no entries. An explicitly supplied missing file raises an error.
- If automatic path discovery is unavailable, supply `-Path` with an existing UTF-8 history file.
- If a command is missing, check the host's history path and save style, whether the record has finished writing, and whether PSReadLine saved that command.
- A directory, non-file-system path, unreadable file, or invalid UTF-8 content raises an error.

Built-in help is available after import:

```powershell
Get-Help Get-PSHistory -Full
Get-Help Search-PSHistory -Examples
Get-Help .\PSHistory\setup.ps1 -Full
```

The [test suite](Tests/PSHistory.Tests.ps1) uses synthetic history files and covers retrieval, search, limits, deduplication, multiline input, Unicode, the command-line-only default display, downstream metadata selection, path discovery, concurrent appends, and error handling. It has been run with Pester 3.4.0. To run it from the repository root with that version installed:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\PSHistory\Tests\PSHistory.Tests.ps1
```
