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

function Find-MostRecentBackup {
    $items = Get-ChildItem -Path $BackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    return $items | Select-Object -First 1
}

try {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required. Run PowerShell as Administrator.'
    }

    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $BackupRoot)) { New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null }

    Write-Output '=== Restore script ==='
    $backup = Find-MostRecentBackup
    if (-not $backup) {
        throw 'No backup found. Run 00-BACKUP.ps1 before using restore.'
    }

    Write-Output "Restoring from: $($backup.FullName)"
    $regFiles = Get-ChildItem -Path $backup.FullName -Filter *.reg -ErrorAction SilentlyContinue
    foreach ($regFile in $regFiles) {
        Write-Output "Importing $($regFile.FullName)"
        reg import $regFile.FullName | Out-Null
    }

    $powerPlanFile = Join-Path $backup.FullName 'POWER-SCHEMES.txt'
    if (Test-Path $powerPlanFile) {
        Write-Output 'Power scheme file detected; review this file and restore the original scheme if needed.'
    }

    Write-Output 'Restore completed using the most recent backup.'
    Write-Log ('Restore completed from {0}' -f $backup.FullName)
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
