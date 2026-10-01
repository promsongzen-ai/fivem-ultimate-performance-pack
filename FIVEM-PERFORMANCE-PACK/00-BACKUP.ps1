param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$PackRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupRoot = Join-Path $PackRoot 'BACKUP'
$RegistryBackupRoot = Join-Path $PackRoot 'REGISTRY-BACKUP'
$LogsRoot = Join-Path $PackRoot 'LOGS'
$Timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'

function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile
    )
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
}

function New-RequiredDirectory {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Get-ComputerSummary {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
    $ram = Get-CimInstance Win32_ComputerSystem
    $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    $storage = Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 3" | Select-Object -First 1
    $pwr = powercfg /getactivescheme 2>$null | Select-String 'Power Scheme GUID'
    $data = [ordered]@{
        Timestamp = $Timestamp
        WindowsVersion = $os.Version
        WindowsBuild = $os.BuildNumber
        OSName = $os.Caption
        CPU = $cpu.Name
        Cores = $cpu.NumberOfCores
        Threads = $cpu.ThreadCount
        GPU = $gpu.Name
        RAMGB = [math]::Round(($ram.TotalPhysicalMemory / 1GB), 2)
        Storage = $storage.DeviceID
        StorageModel = $storage.VolumeName
        PowerPlan = if ($pwr) { ($pwr.ToString() -split ':',2)[1].Trim() } else { 'Unknown' }
    }
    return $data
}

function Export-RegistryKey {
    param(
        [string]$RegistryPath,
        [string]$ExportPath
    )
    if (Test-Path $RegistryPath) {
        reg export $RegistryPath $ExportPath /y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to export $RegistryPath"
        }
    }
}

try {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This script must be run as Administrator.'
    }

    New-RequiredDirectory -Path $BackupRoot
    New-RequiredDirectory -Path $RegistryBackupRoot
    New-RequiredDirectory -Path $LogsRoot

    $BackupDir = Join-Path $BackupRoot $Timestamp
    New-RequiredDirectory -Path $BackupDir

    $LogFile = Join-Path $LogsRoot ("{0}.log" -f $Timestamp)
    $Summary = Get-ComputerSummary

    Write-Output "Creating backup in $BackupDir"
    Write-Log -Message "Starting FiveM Performance Pack backup." -LogFile $LogFile
    Write-Log -Message ("Windows: {0} Build {1}" -f $Summary.WindowsVersion, $Summary.WindowsBuild) -LogFile $LogFile
    Write-Log -Message ("CPU: {0} ({1} cores / {2} threads)" -f $Summary.CPU, $Summary.Cores, $Summary.Threads) -LogFile $LogFile
    Write-Log -Message ("GPU: {0}" -f $Summary.GPU) -LogFile $LogFile
    Write-Log -Message ("RAM: {0} GB" -f $Summary.RAMGB) -LogFile $LogFile
    Write-Log -Message ("Current power plan: {0}" -f $Summary.PowerPlan) -LogFile $LogFile

    $Summary | ConvertTo-Json | Set-Content -Path (Join-Path $BackupDir 'SYSTEM-SUMMARY.json')
    $output = & powercfg /list
    $output | Set-Content -Path (Join-Path $BackupDir 'POWER-SCHEMES.txt')
    $output = & systeminfo
    $output | Set-Content -Path (Join-Path $BackupDir 'SYSTEMINFO.txt')

    Export-RegistryKey -RegistryPath 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -ExportPath (Join-Path $RegistryBackupRoot 'SystemProfile.reg')
    Export-RegistryKey -RegistryPath 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' -ExportPath (Join-Path $RegistryBackupRoot 'Games.reg')
    Export-RegistryKey -RegistryPath 'HKCU\Software\Microsoft\GameBar' -ExportPath (Join-Path $RegistryBackupRoot 'GameBar.reg')
    Export-RegistryKey -RegistryPath 'HKCU\Control Panel\Mouse' -ExportPath (Join-Path $RegistryBackupRoot 'Mouse.reg')
    Export-RegistryKey -RegistryPath 'HKCU\Control Panel\Desktop' -ExportPath (Join-Path $RegistryBackupRoot 'Desktop.reg')
    Export-RegistryKey -RegistryPath 'HKLM\SYSTEM\CurrentControlSet\Control\Power' -ExportPath (Join-Path $RegistryBackupRoot 'Power.reg')
    Export-RegistryKey -RegistryPath 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -ExportPath (Join-Path $RegistryBackupRoot 'GraphicsDrivers.reg')

    $netAdapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed, DriverVersion, InterfaceType
    $netAdapters | Format-List | Out-File -FilePath (Join-Path $BackupDir 'NETWORK-ADAPTERS.txt')

    $serviceStates = Get-Service | Select-Object Name, Status, StartType | Sort-Object Name
    $serviceStates | Out-File -FilePath (Join-Path $BackupDir 'SERVICE-STATE.txt')

    $backupManifest = @{
        Timestamp = $Timestamp
        BackupDirectory = $BackupDir
        RegistryBackupDirectory = $RegistryBackupRoot
        PowerPlan = $Summary.PowerPlan
        WindowsVersion = $Summary.WindowsVersion
        CPU = $Summary.CPU
        GPU = $Summary.GPU
        RAMGB = $Summary.RAMGB
    }
    $backupManifest | ConvertTo-Json | Set-Content -Path (Join-Path $BackupDir 'BACKUP-MANIFEST.json')

    Write-Log -Message 'Backup completed successfully.' -LogFile $LogFile
    Write-Output "Backup created: $BackupDir"
    if (-not $Quiet) {
        Write-Output "Registry backups stored in: $RegistryBackupRoot"
        Write-Output "Log file: $LogFile"
    }
}
catch {
    $msg = $_.Exception.Message
    Write-Error $msg
    if (Test-Path $LogsRoot) {
        $log = Join-Path $LogsRoot ("{0}.log" -f $Timestamp)
        Write-Log -Message ("ERROR: {0}" -f $msg) -LogFile $log
    }
    exit 1
}
