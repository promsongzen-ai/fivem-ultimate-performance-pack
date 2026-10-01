$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogRoot = Join-Path $PackRoot 'LOGS'
$LogFile = Join-Path $LogRoot ("{0}.log" -f (Get-Date -Format 'yyyy-MM-dd-HHmmss'))

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

try {
    if (-not (Test-Path $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }
    Write-Log 'Reviewing network settings.'

    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if (-not $adapter) {
        throw 'No active network adapter found.'
    }

    $adapterName = $adapter.Name
    $powerMgmt = Get-NetAdapterPowerManagement -Name $adapterName -ErrorAction SilentlyContinue
    $adapterPower = if ($powerMgmt) { $powerMgmt.Enabled } else { 'Not supported' }
    $dns = (Get-DnsClientServerAddress -InterfaceAlias $adapterName -ErrorAction SilentlyContinue | Select-Object -First 1).ServerAddresses
    $ip = (Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress

    Write-Output '=== Network review ==='
    Write-Output "Active adapter: $($adapter.Name)"
    Write-Output "Interface type: $($adapter.InterfaceType)"
    Write-Output "Link speed: $($adapter.LinkSpeed)"
    Write-Output "IPv4: $ip"
    Write-Output "DNS: $($dns -join ', ')"
    Write-Output "Adapter power management: $adapterPower"
    Write-Output 'RSS: leave enabled; it is usually beneficial on modern multi-core systems.'
    Write-Output 'Receive/Transmit buffers: do not change by default. These values are driver and workload dependent.'
    Write-Output 'Interrupt moderation: leave at default unless a driver-specific issue is identified.'
    Write-Output 'Windows TCP tuning: avoid aggressive changes. They do not remove server latency or internet distance.'

    Write-Output "`nINPUT LATENCY = local device and OS responsiveness`"
    Write-Output "FRAME LATENCY = GPU/CPU frame-to-frame timing inside the game`"
    Write-Output "NETWORK LATENCY = transmission time to/from the server`"
    Write-Output "SERVER LATENCY = server-side simulation and processing`"
    Write-Output "PACKET LOSS = network reliability issue, not a local Windows registry magic fix`"
    Write-Output 'The physical distance to the server and server-side load remain the main determinants of network latency. Windows settings can reduce local overhead, but not the laws of physics.'

    Write-Log 'Network review completed.'
}
catch {
    Write-Error $_.Exception.Message
    Write-Log ("ERROR: {0}" -f $_.Exception.Message)
    exit 1
}
