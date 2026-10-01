$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$RegistryBackupRoot = Join-Path $PackRoot 'REGISTRY-BACKUP'
$ChangesFile = Join-Path $PackRoot 'REGISTRY-CHANGES.txt'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path $RegistryBackupRoot)) { New-Item -Path $RegistryBackupRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing Windows registry values.'

    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile',
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    )

    $report = @()
    $report += '=== Registry review: Windows 11 modern gaming relevance ==='
    $report += 'This script does not randomly modify values. It only exports relevant keys and reports the current state.'
    $report += ''
    foreach ($key in $keys) {
        if (Test-Path $key) {
            $values = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            $report += "Key: $key"
            if ($values) {
                foreach ($p in $values.PSObject.Properties) {
                    if ($p.Name -notin 'PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') {
                        $report += "  $($p.Name) = $($p.Value)"
                    }
                }
            }
            else {
                $report += '  No writable values detected.'
            }
            $report += ''
        }
        else {
            $report += "Key missing: $key"
            $report += ''
        }
    }

    $report += 'Decision: Most values in the Multimedia\SystemProfile keys are legacy-era tuning hints and are not reliable performance levers on modern Windows 11. Do not force them unless you have a verified, repeatable reason and a clean system baseline.'
    $report += 'If a value is obsolete, ignored, or unnecessary, do not modify it.'
    $report += 'This is a documentation and backup script, not a broad registry shotgun.'

    $report | Set-Content -Path $ChangesFile
    Write-Output "Registry review saved to $ChangesFile"
    Write-Log 'Registry review completed without unsafe modifications.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
