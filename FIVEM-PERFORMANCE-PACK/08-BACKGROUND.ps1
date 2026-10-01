$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Get-StartupData {
    $items = @()
    $items += Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue
    $items += Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    $items += Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue
    return $items
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing background activity.'

    Write-Output '=== Background process review ==='
    Write-Output 'Purpose: identify unnecessary background activity without disabling critical Windows services.'
    Write-Output 'Recommended review list: OneDrive, Teams, browsers, game launchers, RGB software, updaters, cloud sync, overlays, recording software.'
    Write-Output 'Do not automatically terminate services required for Windows security, networking, or storage health.'
    Write-Output 'Prefer temporary, user-controlled actions over permanent service disabling.'

    $startup = Get-StartupData
    if ($startup) {
        $startup | Format-Table -AutoSize | Out-String | Write-Output
    }
    else {
        Write-Output 'No additional startup entries detected.'
    }

    Write-Log 'Background review completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
