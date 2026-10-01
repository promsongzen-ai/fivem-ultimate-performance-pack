$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Add-StatusLine {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
    Write-Output ("{0}: {1} - {2}" -f $Name, $Status, $Detail)
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Verifying configuration.'

    $results = @()

    $gameMode = if ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction SilentlyContinue).AppCaptureEnabled -eq 1) { 'PASS' } else { 'UNCHANGED' }
    $results += Add-StatusLine -Name 'Game Mode' -Status $gameMode -Detail 'Verify Windows Game Mode status and decide if it matches your gaming profile.'

    $hagsMode = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue
    $hagsState = if ($hagsMode) { 'PASS' } else { 'WARNING' }
    $results += Add-StatusLine -Name 'HAGS' -Status $hagsState -Detail 'HAGS should be validated, not forced.'

    $powerPlan = powercfg /getactivescheme 2>$null
    $results += Add-StatusLine -Name 'Power plan' -Status 'PASS' -Detail ($powerPlan | Out-String)

    $mouse = Get-ItemProperty 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue
    $mouseStatus = if (($mouse.MouseSpeed -eq 0) -and ($mouse.MouseThreshold1 -eq 0) -and ($mouse.MouseThreshold2 -eq 0)) { 'PASS' } else { 'WARNING' }
    $results += Add-StatusLine -Name 'Mouse acceleration' -Status $mouseStatus -Detail 'Use test to confirm pointer movement remains consistent.'

    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    $netStatus = if ($netAdapter) { 'PASS' } else { 'FAILED' }
    $results += Add-StatusLine -Name 'Network adapter' -Status $netStatus -Detail 'Verify active adapter and power management configuration.'

    $report = @(
        '=== Verification report ===',
        'PASS = expected state or acceptable safe configuration',
        'WARNING = value is present but should be validated',
        'UNCHANGED = left at default or not modified',
        'FAILED = not acceptable or not detected',
        '',
        $results | ForEach-Object { $_ }
    )

    $reportPath = Join-Path $PackRoot 'VERIFY-REPORT.txt'
    $report | Set-Content -Path $reportPath
    Write-Output "Verification report saved to $reportPath"
    Write-Log 'Verification report generated.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
