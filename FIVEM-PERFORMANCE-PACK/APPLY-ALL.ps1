$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupRoot = Join-Path $PackRoot 'BACKUP'
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Show-WhatWillChange {
    Write-Output 'WHAT WILL CHANGE'
    Write-Output '- Safe Windows gaming configuration'
    Write-Output '- Safe power plan creation and activation'
    Write-Output '- Safe input adjustments for pointer consistency'
    Write-Output '- Safe reporting only for registry values'
    Write-Output '- Safe network review and adapter power check'
    Write-Output '- Log generation and verification'
}

try {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required. Run PowerShell as Administrator.'
    }

    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $BackupRoot)) { New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null }

    Write-Output '=== FiveM Performance Pack summary ==='
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    Write-Output "OS: $($os.Caption) $($os.Version)"
    Write-Output "CPU: $($cpu.Name)"
    Write-Output "GPU: $($gpu.Name)"
    Write-Output "Objective: stable FPS, low frame-time variance, reduced input delay, system stability."
    Show-WhatWillChange

    $answer = Read-Host 'Do you want to continue? (Y/N)'
    if ($answer -notmatch '^(Y|y)$') {
        Write-Output 'Aborted by user.'
        exit 0
    }

    Write-Log 'User confirmed application.'
    Write-Output 'Executing backup and safe configuration steps...'

    & (Join-Path $PackRoot '00-BACKUP.ps1')
    & (Join-Path $PackRoot '02-WINDOWS-GAMING.ps1')
    & (Join-Path $PackRoot '03-POWER-CPU.ps1')
    & (Join-Path $PackRoot '04-GPU.ps1')
    & (Join-Path $PackRoot '05-INPUT.ps1')
    & (Join-Path $PackRoot '06-NETWORK.ps1')
    & (Join-Path $PackRoot '07-REGISTRY.ps1')
    & (Join-Path $PackRoot '08-BACKGROUND.ps1')
    & (Join-Path $PackRoot '09-FIVEM.ps1')
    & (Join-Path $PackRoot '10-VERIFY.ps1')

    Write-Output 'All safe checks completed.'
    Write-Log 'APPLY-ALL completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
