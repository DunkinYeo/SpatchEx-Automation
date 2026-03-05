# SpatchEx — Windows Unblock + Run
# Right-click this file -> "Run with PowerShell"

Set-Location $PSScriptRoot

Write-Host ""
Write-Host "  Unblocking all files (Windows security)..."
Get-ChildItem -Recurse | Unblock-File
Write-Host "  OK  All files unblocked."
Write-Host ""
Write-Host "  Starting setup..."
Write-Host ""

Start-Process "cmd.exe" -ArgumentList "/k install\install.bat" -WorkingDirectory $PSScriptRoot
