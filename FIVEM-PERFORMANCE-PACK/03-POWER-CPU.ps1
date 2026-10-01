$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))
$PowerPlanName = 'FiveM Competitive Performance'

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function Get-CurrentPowerPlanGuid {
    $output = powercfg /getactivescheme 2>$null
    if ($output) {
        $guidLine = $output | Select-String 'Power Scheme GUID'
        if ($guidLine) {
            return ($guidLine.ToString() -split ':',2)[1].Trim()
        }
    }
    return $null
}

function Ensure-PowerPlan {
    $list = powercfg /list
    if ($list -match [regex]::Escape($PowerPlanName)) {
        $guid = ($list | Select-String $PowerPlanName | ForEach-Object { ($_ -split '\s{2,}')[1] })[0]
        powercfg /setactive $guid | Out-Null
        Write-Output "Power plan already exists: $PowerPlanName"
        return $guid
    }

    $balanced = powercfg /list | Select-String 'Balanced' | Select-Object -First 1
    if (-not $balanced) {
        throw 'Balanced power plan not found. Power plan creation cannot proceed safely.'
    }

    $baseGuid = ($balanced.ToString() -split '\s+', 4)[3].Trim()
    $newGuid = powercfg /duplicatescheme $baseGuid 2>$null
    if (-not $newGuid) {
        throw 'Unable to duplicate the Balanced power plan.'
    }

    $guidLine = $newGuid | Select-String 'GUID'
    if (-not $guidLine) { throw 'Power plan GUID could not be parsed.' }
    $guid = ($guidLine.ToString() -split ':',2)[1].Trim()

    powercfg /changename $guid $PowerPlanName 'High performance for stable gaming with CPU responsiveness and thermal safety' | Out-Null
    powercfg /setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMIN 5 | Out-Null
    powercfg /setacvalueindex $guid SUB_PROCESSOR PROCTHROTTLEMAX 100 | Out-Null
    powercfg /setacvalueindex $guid SUB_VIDEO VIDEOCONLOCK 100 | Out-Null
    powercfg /setacvalueindex $guid SUB_USB USBSELECTIVESUSPEND 0 | Out-Null
    powercfg /setacvalueindex $guid SUB_PCIEXPRESS PCIEXPRESSLINKSTATE 0 | Out-Null
    powercfg /setactive $guid | Out-Null
    Write-Output "Created and activated $PowerPlanName"
    return $guid
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Applying safe power and CPU configuration.'

    $oldPlan = Get-CurrentPowerPlanGuid
    $planGuid = Ensure-PowerPlan

    $planOutput = powercfg /getactivescheme
    Write-Output $planOutput
    Write-Output "`nCurrent power scheme: $planOutput"
    Write-Output "`nRationale: This plan avoids unsafe CPU forcing while allowing modern Intel boost behavior and reducing OS-driven power savings during gaming.`n"

    Write-Log ("Previous active power plan GUID: {0}" -f $oldPlan)
    Write-Log ("Current active power plan GUID: {0}" -f $planGuid)
    Write-Log 'Safe CPU power configuration applied.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
