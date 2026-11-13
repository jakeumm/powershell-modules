**LinuxAliases** combines its helpers in a single [LinuxAliases.psm1](LinuxAliases.psm1) module, exporting `grep`, `touch`, and `vi`.

If you previously loaded the standalone scripts, replace their dot-source lines in `$PROFILE` with the module import. Before running setup or importing in an existing session, remove the old aliases in your current scope, particularly the old `grep` alias to `Select-String`:

```powershell
Remove-Item -LiteralPath Alias:grep, Alias:touch, Alias:vi -Force -ErrorAction SilentlyContinue
```

Run [setup.ps1](setup.ps1) in PowerShell 7 or later from the repository root:

```powershell
.\LinuxAliases\setup.ps1
```

Setup creates the destination directories and installs the module at:

```text
$HOME\Documents\WindowsPowerShell\Modules\LinuxAliases.psm1
```

The script prompts `Import LinuxAliases into this session now? [y/N]`. Answer `y` or `yes` to import `grep`, `touch`, and `vi` into the current session. Press Enter to skip importing and display the command to use later. Repeating setup refreshes the installed module from the source beside the script.

The default destination uses `WindowsPowerShell` even when running PowerShell 7. Override it with `-ModulePath`, which accepts the full destination module filename:

```powershell
.\LinuxAliases\setup.ps1 -ModulePath 'D:\PowerShell\Modules\LinuxAliases.psm1'
```

Keep `setup.ps1` beside `LinuxAliases.psm1` when running it. Import the default installation by full path in later sessions:

```powershell
Import-Module (Join-Path $HOME 'Documents\WindowsPowerShell\Modules\LinuxAliases.psm1')
```

To load the module automatically in future sessions, add that import line to `$PROFILE`. If you chose a custom `-ModulePath`, use that path instead. Setup imports into the current session when requested; future imports are configured through the profile. Vim must be installed separately to use `vi`.

You can also import the source module directly from the repository root:

```powershell
Import-Module .\LinuxAliases\LinuxAliases.psm1
```

The module exports these commands:

| Command | Type | Purpose |
| --- | --- | --- |
| `grep` | Function | Search text and files with basic grep-style flags. |
| `touch` | Alias for `New-Item` | Create files or other item types using PowerShell parameters. |
| `vi` | Alias for `vim` | Open Vim, which must be available through command discovery. |

All three commands become available on import. After updating the checkout, re-run setup to refresh an installed copy, then import that installed copy with `-Force`. For direct checkout use, re-import the source module with `-Force`.

`grep` supports a basic set of grep-style flags. Searches are case-sensitive by default, and results are text strings.

```powershell
# Search pipeline text, ignoring case.
'ERROR: failed', 'ready' | grep -i error

# Search a file, ignoring case and including original line numbers.
grep -in error .\application.log

# Return lines that do not contain DEBUG.
Get-Content .\application.log | grep -v DEBUG

# Search a directory recursively for literal text.
grep -rF 'TODO:' .\src

# With -r and no paths, search the current directory recursively.
grep -ri error
```

| Flag | Long form | Behavior |
| --- | --- | --- |
| `-i` | `--ignore-case` | Ignore case when matching. |
| `-v` | `--invert-match` | Return lines that do not match. |
| `-F` | `--fixed-strings` | Treat the pattern as literal text instead of a regular expression. |
| `-n` | `--line-number` | Prefix matches with their original one-based line number. |
| `-r` | `--recursive` | Search directories recursively, including hidden files. Defaults to the current directory when no paths are given. |

Flags are case-sensitive and can be combined, for example `-in` or `-riv`. The first non-option operand is the pattern; later operands are file or directory paths. Options can appear before or after operands. Directories require `-r`.

Use the quoted string `'--'` to stop option parsing when a pattern or path starts with a dash. The quotes are required here because PowerShell consumes an unquoted `--` before passing arguments to a function:

```powershell
'-i', 'other' | grep '--' '-i'
```

File operands support PowerShell wildcard expansion and arrays. A single-file search returns matching lines, optionally prefixed as `lineNumber:text`. Multiple-file and recursive searches prefix full filenames as `file:text` or `file:lineNumber:text`. Pipeline searches count original input lines, including nonmatching lines; multiline strings are split into individual lines.

Explicit file operands take precedence over pipeline input. With no paths, pipe text into the function or use `-r`. Empty patterns match every line. No matches produce no output. Unsupported flags, missing files, unreadable files, and invalid regular expressions raise PowerShell errors.

This wrapper uses `Select-String` and .NET regular expressions. It implements the listed flags rather than full GNU grep compatibility: GNU basic-regex syntax, binary-file handling, GNU exit codes, and `-` as a stdin file operand are outside its scope. `Get-Help grep -Full` shows built-in help.

`touch` aliases `New-Item`. Specify the item type when creating a file or directory. Existing-item behavior follows `New-Item`; this alias does not implement Unix timestamp updates.

```powershell
touch .\new-file.txt -ItemType File
touch .\new-folder -ItemType Directory
```

`vi` aliases `vim`, which must be installed and available through command discovery, such as on `PATH`.

```powershell
vi .\notes.txt
```

Read the built-in help after importing the module:

```powershell
Get-Help grep -Full
Get-Help .\LinuxAliases\setup.ps1 -Full
```

Local tests in `Tests/grep.Tests.ps1` cover module exports, the `touch` alias, supported grep flags, pipeline and file searches, recursion, combined options, numbering, empty inputs, and error handling. Test folders are ignored by Git and are not included in a fresh checkout. With the local tests present, run them using Pester 3.4.0:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\LinuxAliases\Tests\grep.Tests.ps1
```
