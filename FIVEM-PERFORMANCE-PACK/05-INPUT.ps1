$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Set-SafeMouseSettings {
    $mouse = 'HKCU:\Control Panel\Mouse'
    $desktop = 'HKCU:\Control Panel\Desktop'
    $current = Get-ItemProperty -Path $mouse -ErrorAction SilentlyContinue
    $currentDesktop = Get-ItemProperty -Path $desktop -ErrorAction SilentlyContinue

    if ($current) {
        Set-ItemProperty -Path $mouse -Name MouseSpeed -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mouse -Name MouseThreshold1 -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $mouse -Name MouseThreshold2 -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }

    if ($currentDesktop) {
        Set-ItemProperty -Path $desktop -Name UserPreferencesMask -Value 0x00000000 -Type Binary -ErrorAction SilentlyContinue
    }

    Write-Output 'Mouse acceleration: disabled for consistent pointer movement.'
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing input settings.'

    Write-Output '=== Input pipeline ==='
    Write-Output 'Mouse -> USB -> HID -> Windows -> FiveM -> CPU -> GPU -> Display'
    Write-Output 'PowerShell can affect OS-level settings such as acceleration and keyboard repeat behavior, but it cannot overcome a poor USB polling rate, a weak wireless adapter, or a high-latency display path.'
    Write-Output 'On modern Windows 11, the biggest practical gains usually come from a clean system, stable GPU driver, good power plan, and stable frame timing.'

    $mouse = Get-ItemProperty 'HKCU:\Control Panel\Mouse' -ErrorAction SilentlyContinue
    if ($mouse) {
        Write-Output "MouseSpeed: $($mouse.MouseSpeed)"
        Write-Output "MouseThreshold1: $($mouse.MouseThreshold1)"
        Write-Output "MouseThreshold2: $($mouse.MouseThreshold2)"
        Set-SafeMouseSettings
    }

    $keyboard = Get-ItemProperty 'HKCU:\Control Panel\Keyboard' -ErrorAction SilentlyContinue
    if ($keyboard) {
        Write-Output "KeyboardDelay: $($keyboard.KeyboardDelay)"
        Write-Output "KeyboardSpeed: $($keyboard.KeyboardSpeed)"
    }

    Write-Output 'A/B TEST ONLY: Keyboard repeat delay and output rate can produce a small feel improvement, but the benefit is not universal. Validate with a real gameplay scenario.'
    Write-Log 'Input review completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
