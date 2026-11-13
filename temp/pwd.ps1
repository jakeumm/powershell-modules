if (Test-Path alias:pwd) { Remove-Item alias:pwd -Force }

function pwd {
    $currentDir = Get-Location
    $PresentDir = $currentDir.ProviderPath
    # Copy the quoted directory to the clipboard
    $PresentDir | Set-Clipboard
    # Output the quoted directory to the console
    Write-Output $PresentDir
}