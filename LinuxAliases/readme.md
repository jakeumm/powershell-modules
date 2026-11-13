**LinuxAliases** combines its helpers in a single [LinuxAliases.psm1](LinuxAliases.psm1) module. Import it from the repository root:

```powershell
Import-Module .\LinuxAliases\LinuxAliases.psm1
```

The module exports these commands:

| Command | Type | Purpose |
| --- | --- | --- |
| `grep` | Function | Search text and files with basic grep-style flags. |
| `touch` | Alias for `New-Item` | Create files or other item types using PowerShell parameters. |
| `vi` | Alias for `vim` | Open Vim, which must be available through command discovery. |

All three commands become available on import. To load them in future sessions, add an `Import-Module` line to `$PROFILE` using the full module path. Re-import with `-Force` after updating the module.

If you previously loaded the standalone scripts, replace their dot-source lines with the module import. Remove any old aliases in the current scope before importing, particularly the old `grep` alias to `Select-String`:

```powershell
Remove-Item -LiteralPath Alias:grep, Alias:touch, Alias:vi -Force -ErrorAction SilentlyContinue
Import-Module .\LinuxAliases\LinuxAliases.psm1 -Force
```

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

The [tests](Tests/grep.Tests.ps1) cover module exports, the `touch` alias, supported grep flags, pipeline and file searches, recursion, combined options, numbering, empty inputs, and error handling. They use Pester 3.4.0:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\LinuxAliases\Tests\grep.Tests.ps1
```
