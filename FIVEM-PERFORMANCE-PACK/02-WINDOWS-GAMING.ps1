$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Show-CurrentValue {
    param(
        [string]$Label,
        [object]$CurrentValue,
        [object]$NewValue,
        [string]$Reason
    )
    Write-Output "`n=== $Label ==="
    Write-Output "CURRENT VALUE"
    Write-Output $CurrentValue
    Write-Output "NEW VALUE"
    Write-Output $NewValue
    Write-Output "WHY"
    Write-Output $Reason
}

$gameMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction SilentlyContinue)
$gameDvr = if ($gameMode) { $gameMode.AppCaptureEnabled } else { 'Not set' }
$gamebar = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction SilentlyContinue
$hags = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue
$hagsMode = if ($hags) { $hags.HwSchMode } else { 'Not detected' }

$settings = @(
    @{ Label = 'Game Mode'; CurrentValue = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction SilentlyContinue).AppCaptureEnabled; NewValue = 'Enabled (recommended)'; Reason = 'Game Mode is safe and can improve scheduling on modern Windows 11 when used with a single full-screen game or when the system is gaming-focused.' },
    @{ Label = 'Xbox Game Bar / background capture'; CurrentValue = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' -ErrorAction SilentlyContinue).AppCaptureEnabled; NewValue = 'Disabled for gaming sessions'; Reason = 'Background capture can add frame overhead and I/O noise. Disable it during play and leave it enabled only when needed.' },
    @{ Label = 'Recorded gameplay / background recording'; CurrentValue = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled; NewValue = 'Off unless testing a recording scenario'; Reason = 'Background recording and capture add CPU/GPU overhead and can increase frame-time variance.' },
    @{ Label = 'Hardware Accelerated GPU Scheduling'; CurrentValue = $hagsMode; NewValue = 'Leave enabled if the system supports it and it remains stable'; Reason = 'HAGS can lower input latency or improve scheduling in some games, but it is not universally beneficial. It is not a magic FPS setting. It should be validated by test, not forced blindly.' },
    @{ Label = 'Fullscreen optimizations'; CurrentValue = 'Leave at OS default'; NewValue = 'Leave unchanged unless a specific app shows compatibility issues'; Reason = 'Modern Windows 11 generally handles fullscreen optimizations safely, and changing it globally is not a reliable performance improvement for all games.' },
    @{ Label = 'Windowed game optimizations'; CurrentValue = 'Leave at OS default'; NewValue = 'Leave unchanged'; Reason = 'For FiveM, the performance gain from forcing one window mode over another is small compared with frame-time stability and driver behavior.' }
)

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing Windows gaming settings.'

    foreach ($item in $settings) {
        Show-CurrentValue -Label $item.Label -CurrentValue $item.CurrentValue -NewValue $item.NewValue -Reason $item.Reason
    }

    Write-Output "`nA/B TEST ONLY: HAGS and Game Bar capture states should be validated on your exact setup before being considered permanent.`n"
    Write-Output 'Safe default recommendation: keep default Windows game settings unless a specific metric clearly improves in a repeatable test.'
    Write-Log 'Windows gaming review completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
