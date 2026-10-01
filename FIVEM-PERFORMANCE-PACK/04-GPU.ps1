$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Get-GpuIdentity {
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    if ($gpu) { return $gpu.Name }
    return 'Unknown GPU'
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing GPU-side settings.'

    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $gpuName = if ($gpu) { $gpu.Name } else { 'Unknown' }
    $hwSch = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue
    $hwschMode = if ($hwSch) { $hwSch.HwSchMode } else { 'Not detected' }

    Write-Output '=== GPU settings review ==='
    Write-Output "GPU detected: $gpuName"
    Write-Output "Hardware Accelerated GPU Scheduling (HwSchMode): $hwschMode"
    Write-Output 'Graphics preference: leave to Windows application defaults unless a game-specific requirement exists.'
    Write-Output 'NVIDIA GPU selection: prefer the NVIDIA GPU through Windows Settings > System > Display > Graphics for FiveM and GTA V.'
    Write-Output 'Power management: do not disable GPU power management or force a permanent low-power state; that often increases stability issues, not lowers stutter.'
    Write-Output 'NVIDIA Control Panel settings: Some options cannot be changed safely through PowerShell. Use NVIDIA Control Panel manually for any final tuning.'
    Write-Output "`nWHY: Windows-side GPU tuning is primarily about not starving the GPU or forcing a bad scheduling mode. The RTX 3050 Laptop GPU is efficient when not sabotaged by poor power settings or driver-level over-tuning.`n"

    Write-Log 'GPU settings review completed.'
    Write-Output 'No unsafe GPU voltage or overclocking changes were made.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
