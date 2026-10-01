$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReportPath = Join-Path $PackRoot 'DIAGNOSTIC-REPORT.txt'
$LogDir = Join-Path $PackRoot 'LOGS'
$TimeStamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$LogPath = Join-Path $LogDir ("{0}.log" -f $TimeStamp)

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogPath -Value $line
}

function Get-CurrentPowerPlan {
    $plan = powercfg /getactivescheme 2>$null
    if ($plan) {
        return ($plan | Select-String 'Power Scheme GUID:').ToString() -replace '.*:\s*',''
    }
    return 'Unknown'
}

function Get-GpuStatus {
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    if (-not $gpu) { return 'Unknown' }
    $gpuName = $gpu.Name
    $vram = if ($gpu.AdapterRAM) { [math]::Round(($gpu.AdapterRAM / 1GB), 2) } else { 'Unknown' }
    $driver = if ($gpu.DriverVersion) { $gpu.DriverVersion } else { 'Unknown' }
    return "Name: $gpuName; VRAM: $vram GB; Driver: $driver"
}

try {
    if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
    Write-Log 'Starting diagnostic collection.'

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $ram = Get-CimInstance Win32_ComputerSystem
    $memory = Get-CimInstance Win32_PhysicalMemory
    $storage = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" | Select-Object -First 1
    $net = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    $powerScheme = Get-CurrentPowerPlan
    $gameMode = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar' -ErrorAction SilentlyContinue).AutoGameModeEnabled
    $gpus = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ErrorAction SilentlyContinue
    $hagsState = if ($gpus) { $gpus.HwSchMode } else { 'Not detected' }

    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
    $gpuUsage = if ($gpu) { (Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue) } else { $null }
    $gpuCoreLoad = if ($gpuUsage) { (($gpuUsage.CounterSamples | Measure-Object -Property CookedValue -Average).Average) } else { 'N/A' }

    $memTotalGB = [math]::Round(($ram.TotalPhysicalMemory / 1GB), 2)
    $memFreeGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    $memUsedGB = [math]::Round($memTotalGB - $memFreeGB, 2)

    $storageInfo = @()
    foreach ($d in Get-WmiObject Win32_LogicalDisk -Filter "DriveType = 3") {
        $storageInfo += "Drive: $($d.DeviceID); Free: $([math]::Round(($d.FreeSpace / 1GB), 2)) GB; Total: $([math]::Round(($d.Size / 1GB), 2)) GB"
    }

    $netInfo = ''
    if ($net) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $net.Name | Select-Object -First 1).IPAddress
        $dns = (Get-DnsClientServerAddress -InterfaceAlias $net.Name -ErrorAction SilentlyContinue | Select-Object -First 1).ServerAddresses
        $link = $net.LinkSpeed
        $netInfo = "Adapter: $($net.Name); Type: $($net.InterfaceType); Link: $link; IPv4: $ip; DNS: $($dns -join ', ')"
    }

    $report = @()
    $report += '=== GPU/CPU Diagnostic Report ==='
    $report += ''
    $report += 'CPU:'
    $report += "Model: $($cpu.Name)"
    $report += "Cores: $($cpu.NumberOfCores)"
    $report += "Threads: $($cpu.ThreadCount)"
    $report += "Current clock: $($cpu.CurrentClockSpeed) MHz"
    $report += "Max clock: $($cpu.MaxClockSpeed) MHz"
    $report += "Utilization: $([math]::Round($cpuUsage, 2)) %"
    $report += "Per-core workload: not exposed via standard API; use Task Manager for per-core view"

    $report += ''
    $report += 'GPU:'
    $report += "Model: $($gpu.Name)"
    $report += "VRAM: $([math]::Round(($gpu.AdapterRAM / 1GB), 2)) GB"
    $report += "GPU utilization: $([math]::Round($gpuCoreLoad, 2)) %"
    $report += "GPU clock: $($gpu.CurrentRefreshRate) Hz (refresh rate not actual GPU clock)"
    $report += "Driver version: $($gpu.DriverVersion)"

    $report += ''
    $report += 'RAM:'
    $report += "Total RAM: $memTotalGB GB"
    $report += "Available RAM: $memFreeGB GB"
    $report += "Used RAM: $memUsedGB GB"
    $report += "Modules: $($memory.Count)"

    $report += ''
    $report += 'Storage:'
    foreach ($line in $storageInfo) { $report += $line }

    $report += ''
    $report += 'Windows:'
    $report += "Edition: $($os.Caption)"
    $report += "Version: $($os.Version)"
    $report += "Build: $($os.BuildNumber)"
    $report += "Game Mode status: $($gameMode)"
    $report += "HAGS status if detectable: $hagsState"

    $report += ''
    $report += 'Power:'
    $report += "Active power plan: $powerScheme"
    $report += "AC/DC state: $(if ((Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)) { 'On battery' } else { 'AC power' })"

    $report += ''
    $report += 'Network:'
    if ($netInfo) { $report += $netInfo } else { $report += 'No active adapter detected.' }
    $report += "Adapter power management: $(if ((Get-NetAdapterPowerManagement -Name $net.Name -ErrorAction SilentlyContinue).Enabled) { 'Enabled' } else { 'Disabled or not supported' })"

    $report += ''
    $report += 'Notes:'
    $report += 'CPU usage alone is not a direct bottleneck indicator. For FiveM, per-core and frame-time behavior are more important.'
    $report += 'Reduce background activity and avoid unsafe priority changes to improve consistency.'

    $report | Set-Content -Path $ReportPath
    Write-Log 'Diagnostic report created.'
    Write-Output "Diagnostic report saved to $ReportPath"
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
