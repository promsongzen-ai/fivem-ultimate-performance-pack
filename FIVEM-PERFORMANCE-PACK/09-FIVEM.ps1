$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Find-FiveMInstall {
    $candidates = @(
        "$env:LOCALAPPDATA\FiveM",
        "$env:LOCALAPPDATA\FiveM\FiveM.app",
        "$env:PROGRAMFILES\Rockstar Games\GTA V",
        "$env:PROGRAMFILES(X86)\Rockstar Games\GTA V",
        "$env:PROGRAMFILES\Steam\steamapps\common\Grand Theft Auto V",
        "$env:PROGRAMFILES(X86)\Steam\steamapps\common\Grand Theft Auto V"
    )
    $found = @()
    foreach ($item in $candidates) {
        if (Test-Path $item) { $found += $item }
    }
    return $found
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing FiveM installation and safe recommendations.'

    $installPaths = Find-FiveMInstall
    Write-Output '=== FiveM review ==='
    if ($installPaths.Count -gt 0) {
        foreach ($path in $installPaths) {
            Write-Output "Detected candidate path: $path"
        }
    }
    else {
        Write-Output 'FiveM installation not detected automatically. Check the launcher installation directory and the GTA V install path manually.'
    }

    Write-Output 'Safe recommendations:'
    Write-Output '- Verify GTA V and FiveM are installed on an SSD or a healthy storage device.'
    Write-Output '- Keep FiveM cache, but do not delete it automatically without warning. Cache clearing can force new downloads and temporary revalidation of game assets.'
    Write-Output '- Avoid modifying GTA V or FiveM files in ways that can trigger anti-cheat or launcher validation failures.'
    Write-Output '- Keep graphics settings consistent across tests. A stable configuration matters more than random preset switching.'
    Write-Output '- If the game launcher is causing stutter, close overlays and outside resource-heavy apps before testing.'

    Write-Log 'FiveM review completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
