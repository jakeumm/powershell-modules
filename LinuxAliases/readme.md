**LinuxAliases** contains PowerShell helpers with familiar Linux command names. Load the scripts you want by dot-sourcing them from the repository root:

```powershell
. .\LinuxAliases\grep.ps1
. .\LinuxAliases\touch.ps1
. .\LinuxAliases\vi.ps1
```

[grep.ps1](grep.ps1) defines a function supporting a basic set of grep-style flags. Loading it removes the earlier `grep` alias so the function takes precedence. Searches are case-sensitive by default, and results are text strings.

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

[touch.ps1](touch.ps1) aliases `touch` to `New-Item`. Specify the item type when creating a file or directory. Existing-item behavior follows `New-Item`; this alias does not implement Unix timestamp updates.

```powershell
touch .\new-file.txt -ItemType File
touch .\new-folder -ItemType Directory
```

[vi.ps1](vi.ps1) aliases `vi` to `vim`, which must be installed and available through command discovery, such as on `PATH`.

```powershell
vi .\notes.txt
```

The [grep tests](Tests/grep.Tests.ps1) cover the supported flags, pipeline and file searches, recursion, combined options, numbering, empty inputs, and error handling. They use Pester 3.4.0:

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\LinuxAliases\Tests\grep.Tests.ps1
```
