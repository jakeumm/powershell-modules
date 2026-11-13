**GroupPolicy** exports one command, `Get-GroupPolicy`, from [GroupPolicy.psm1](GroupPolicy.psm1). It refreshes policy, generates an HTML GPResult report, opens that report on the calling computer, and returns a message containing the report path.

Import this repository's module by its file path:

```powershell
Import-Module .\GroupPolicy\GroupPolicy.psm1 -Force
```

Run locally using the existing workflow:

```powershell
Get-GroupPolicy
Get-GroupPolicy -Path 'C:\Reports' -Name 'My-GP.html'
```

For a remote computer, supply `-ComputerName`. The command uses `Invoke-Command` to run both `gpupdate.exe` and `gpresult.exe` on that computer. The module itself does not have to be installed on the target.

```powershell
Get-GroupPolicy -ComputerName PC01

# An existing folder reached through the target's C$ administrative share.
Get-GroupPolicy -ComputerName PC01 -Path '\\PC01\c$\Reports' -Name 'Policy.html'

# The equivalent target-local filename.
Get-GroupPolicy -ComputerName PC01 -Path 'C:\Reports\Policy.html'
```

Remote `-Path` is interpreted on the target computer. A UNC administrative share such as `\\PC01\c$\Reports` is converted to `C:\Reports` before the command is sent. The share hostname must match `-ComputerName`. Absolute paths on other drives work as well, with the report opened through the corresponding drive share, such as `D:\Reports` becoming `\\PC01\d$\Reports`.

After the remote report is generated, its path is converted back to an administrative-share path. The caller checks that the file is accessible and opens it locally, for example:

```text
\\PC01\c$\ProgramData\Custom-Functions\Get-GroupPolicy\2026-11-13-120000-GPResult.html
```

| Parameter | Behavior |
| --- | --- |
| `-Path <string>` | Existing folder or full report filename. Omit for the default folder. Remote calls accept absolute drive paths or matching drive-administrative-share paths. |
| `-Name <string>` | Report filename. Overrides the filename in `-Path` and appends `.html` if needed. Defaults to `yyyy-MM-dd-HHmmss-GPResult.html`. |
| `-ComputerName <string>` | One remote computer name, FQDN, or IPv4 address. Omit to run locally. |
| `-Scope Both/User/Computer` | Controls both refresh and report generation. Defaults to `Both` locally and `Computer` remotely. |

The local default folder is `$Env:LOCALAPPDATA\Custom-Functions\Get-GroupPolicy`. The remote default is `C:\ProgramData\Custom-Functions\Get-GroupPolicy` on the target. The command ensures the applicable default folder exists. Custom folders must already exist. Filenames can contain spaces; supply them as quoted strings.

Scope behavior is explicit:

```powershell
# Refresh and report computer policy on the target.
Get-GroupPolicy -ComputerName PC01 -Scope Computer

# Request both scopes on the target.
Get-GroupPolicy -ComputerName PC01 -Scope Both

# Refresh and report the local caller's user policy.
Get-GroupPolicy -Scope User
```

Remote calls default to computer policy because the remoting account may have no user RSoP data on the target. User scope refers to the account executing the command; it does not automatically select the interactive console user.

Windows `gpupdate.exe` and `gpresult.exe` are required on the computer processing the request. Remote execution requires configured PowerShell remoting and sufficient permissions for policy processing. Opening the resulting UNC path requires SMB connectivity and administrative-share access from the caller using the current account. The command uses the current account for remoting and share access.

The refresh uses `/force`, with `/target:user` or `/target:computer` for a single scope. The report uses `/h` and the matching `/scope` when selected. A nonzero native exit code stops processing. A missing report is an error; if the report exists remotely but cannot be reached through its share, the error includes both its target-local path and UNC path. Existing reports are not forcibly overwritten.

Microsoft documents the underlying behavior in [gpupdate](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/gpupdate), [gpresult](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/gpresult), and [Invoke-Command](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/invoke-command).

Built-in help is available after import:

```powershell
Get-Help Get-GroupPolicy -Full
```

Local tests in `Tests/GroupPolicy.Tests.ps1` mock remoting, native policy commands, and report opening. They cover scope selection, target-local and UNC paths, native failures, inaccessible shares, filenames, and local behavior. Test folders are ignored by Git and are not included in a fresh checkout. With the local tests present, run them using Pester 3.4.0; no live remote computer is required.

```powershell
Import-Module Pester -RequiredVersion 3.4.0
Invoke-Pester -Script .\GroupPolicy\Tests\GroupPolicy.Tests.ps1
```
