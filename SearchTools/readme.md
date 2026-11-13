**SearchTools** provides `Search-ChildItem`, a recursive file-system name search. It searches files by default; use `-Directory` to search directories instead.

Run [setup.ps1](setup.ps1) in PowerShell 7 or later from the repository root:

```powershell
.\SearchTools\setup.ps1
```

Setup creates the destination directories and installs [SearchTools.psm1](SearchTools.psm1) at:

```text
$HOME\Documents\WindowsPowerShell\Modules\SearchTools.psm1
```

The script prompts `Import SearchTools into this session now? [y/N]`. Answer `y` or `yes` to import the installed module into the current session. Press Enter to skip importing and display the command to use later. Repeating setup refreshes the installed module from the source beside the script.

The default destination uses the WindowsPowerShell directory even when running PowerShell 7. Override it with `-ModulePath`, which accepts the full destination file path:

```powershell
.\SearchTools\setup.ps1 -ModulePath 'D:\PowerShell\Modules\SearchTools.psm1'
```

Keep `setup.ps1` beside `SearchTools.psm1` when running it. The default installation is a single file directly in `Modules`; import it by full path in future sessions:

```powershell
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\SearchTools.psm1')
```

To load the module automatically in future sessions, add that import line to `$PROFILE`. If you chose a custom `-ModulePath`, use that path instead.

You can also import the source module directly from the repository root:

```powershell
Import-Module .\SearchTools\SearchTools.psm1
```

Common searches:

```powershell
# Find every file beneath the current directory.
Search-ChildItem

# Find PDF files recursively.
Search-ChildItem '*.pdf'

# Choose a starting directory; filter and path can both be positional.
Search-ChildItem '*.log' 'C:\Projects'

# Find directories with "cache" in their names.
Search-ChildItem '*cache*' -Directory

# Explicitly select files; this is also the default.
Search-ChildItem '*.ps1' -File

# Include hidden and system items where permitted.
Search-ChildItem '*cache*' -Directory -Force

# Search only immediate children of the starting directory.
Search-ChildItem '*.log' -Depth 0

# Also search the starting directory's immediate subdirectories.
Search-ChildItem '*.log' -Depth 1

# Treat brackets and other wildcard characters in a starting path literally.
Search-ChildItem '*.log' -LiteralPath 'C:\Builds\[latest]'

# Search several starting paths.
Search-ChildItem '*.ps1' -Path 'C:\Projects', 'D:\Scripts'

# Expand wildcard starting paths before searching beneath them.
Search-ChildItem '*.log' -Path 'C:\Projects\build-*'
```

The command accepts these parameters:

| Parameter | Behavior |
| --- | --- |
| `-Filter <string>` | File-system name filter, such as `*.pdf`. Defaults to `*`. First positional argument. |
| `-Path <string[]>` | Starting paths, with wildcard support. Defaults to `.`. Second positional argument. |
| `-LiteralPath <string[]>` | Exact starting paths, with no wildcard interpretation. Cannot be combined with `-Path`. |
| `-File` | Explicitly select files. File-only searching is also the default when neither type switch is supplied. |
| `-Directory` | Select directories instead of files. Cannot be combined with `-File`. |
| `-Force` | Include hidden and system items where permitted. Does not grant additional access permissions. |
| `-Depth <uint32>` | Maximum recursion depth. `0` searches immediate children only; `1` also searches immediate subdirectories. Omit to recurse without a depth limit. |

The filter matches item names, not file contents. Starting paths are resolved before the name filter is applied to the recursive search. Results follow the provider's enumeration order; use `Sort-Object` when you need a particular order.

Results are original `System.IO.FileInfo` objects for files and `System.IO.DirectoryInfo` objects for directories. Properties such as `Name`, `FullName`, `LastWriteTime`, `PSIsContainer`, and file `Length` remain available for pipeline processing:

```powershell
# Display the same two columns as the earlier version of the function.
Search-ChildItem '*.log' | Select-Object LastWriteTime, FullName

# Find the ten largest matching files.
Search-ChildItem '*.log' |
    Sort-Object Length -Descending |
    Select-Object -First 10 Name, Length, FullName
```

By default, access-denied errors are skipped so a recursive search can continue through accessible paths. `-Verbose` reports skipped access failures. Other errors, including nonexistent starting paths and non-file-system paths, are reported normally.

An explicit `-ErrorAction` controls all errors, including permission errors. A changed `$ErrorActionPreference` is also honored. Examples:

```powershell
# Report skipped access failures without interrupting the default search.
Search-ChildItem '*.log' -Verbose

# Stop on the first error, including access denied.
Search-ChildItem '*.log' -ErrorAction Stop

# Report access failures and continue.
Search-ChildItem '*.log' -ErrorAction Continue

# Suppress error display and collect errors for inspection.
Search-ChildItem '*.log' -ErrorAction SilentlyContinue -ErrorVariable searchErrors
```

Read the built-in help after importing the module:

```powershell
Get-Help Search-ChildItem -Full
Get-Help .\SearchTools\setup.ps1 -Full
```

The [test suite](Tests/SearchTools.Tests.ps1) uses temporary file-system fixtures and synthetic permission errors. It covers file-only defaults, directory selection, full output objects, filters, multiple roots, wildcard and literal paths, recursion depth, hidden items, conflicting parameters, and error handling. It has been run with Pester 3.4.0:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\SearchTools\Tests\SearchTools.Tests.ps1
```
