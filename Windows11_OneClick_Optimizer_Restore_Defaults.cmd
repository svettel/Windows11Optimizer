@echo off
setlocal EnableExtensions
chcp 65001 >nul

echo Windows One Click Optimizer - Restore
echo e-mail : s_vettel@naver.com
echo.
set "__SELF=%~f0"
set "__SELFDIR=%~dp0"
set "__TEMPPS=%TEMP%\Restore-Win11-Setting_%RANDOM%%RANDOM%.ps1"

fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $p = $env:__SELF; $d = $env:__SELFDIR; $q = [char]34; $args = @('/k','call',($q + $p + $q)); Start-Process -FilePath $env:ComSpec -ArgumentList $args -WorkingDirectory $d -Verb RunAs; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
    if errorlevel 1 (
        echo Failed to request administrator privileges or the request was cancelled.
        echo Press any key to close.
        pause >nul
        exit /b 1
    )
    echo Elevated administrator window was requested.
    echo If a new administrator window did not open, run this file from an elevated Command Prompt.
    echo Press any key to close this non-administrator window.
    pause >nul
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$content = Get-Content -LiteralPath $env:__SELF -Raw; $marker = '# POWER' + 'SHELL_START'; $idx = $content.LastIndexOf($marker); if ($idx -lt 0) { throw 'POWERSHELL_START marker not found.' }; $ps = $content.Substring($idx + $marker.Length).TrimStart([char]13,[char]10); Set-Content -LiteralPath $env:__TEMPPS -Value $ps -Encoding UTF8"
if errorlevel 1 (
    echo Failed to extract PowerShell payload.
    echo Press any key to close.
    pause >nul
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%__TEMPPS%"
set "__RC=%ERRORLEVEL%"

del "%__TEMPPS%" >nul 2>&1

echo.
if "%__RC%"=="0" (
    echo Restore completed.
) else (
    echo Restore failed or completed with warnings. Exit code: %__RC%
)
echo.
echo Press any key to close.
pause >nul
exit /b %__RC%

# POWERSHELL_START

trap {
    Write-Host ""
    Write-Host "[FATAL] PowerShell restore payload stopped." -ForegroundColor Red
    Write-Host ("[FATAL] " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Press any key to close."
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
    exit 1
}

$ErrorActionPreference = "Continue"

$RestoreBackupRoot = Join-Path $env:SystemDrive "Win11_Tweak_Restore_Backup"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$RestoreBackupDir = Join-Path $RestoreBackupRoot $Timestamp
New-Item -Path $RestoreBackupDir -ItemType Directory -Force | Out-Null

# Optional safety switches.
# Importing historical registry backups is not enabled by default because multiple optimizer runs can make "latest" ambiguous.
$ImportLatestRegistryBackup = $false
$InstallMissingAppsWithWinget = $true
$OpenStoreSearchForMissingApps = $false
$RemoveUltimatePerformanceSchemes = $false

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Get-ErrorText {
    param([Parameter(Mandatory)][object]$ErrorRecord)
    $message = ""
    if ($null -ne $ErrorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.Message)) {
        $message = [string]$ErrorRecord.Exception.Message
    } else {
        $message = [string]$ErrorRecord
    }
    $message = $message -replace '\s*System\.Management\.Automation\.RemoteException\s*$', ''
    $message = $message.Trim()
    if ([string]::IsNullOrWhiteSpace($message)) { return "Unknown error" }
    return $message
}

function Join-NativeOutput {
    param([object[]]$Output)
    if ($null -eq $Output) { return "" }
    $text = ($Output | ForEach-Object { [string]$_ }) -join " "
    $text = $text -replace '\s*System\.Management\.Automation\.RemoteException\s*', ' '
    $text = $text -replace '\s+', ' '
    return $text.Trim()
}

function Ensure-Key {
    param([Parameter(Mandatory)][string]$Path)
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
    } catch {
        Write-Warning "Ensure-Key failed: $Path :: $(Get-ErrorText $_)"
    }
}

function Set-Dword {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )
    try {
        Ensure-Key $Path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        } else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "DWORD restored: $Path\$Name = $Value"
    } catch {
        Write-Warning "Set-Dword failed: $Path\$Name :: $(Get-ErrorText $_)"
    }
}

function Set-StringValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][string]$Value
    )
    try {
        Ensure-Key $Path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        } else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "String restored: $Path\$Name = $Value"
    } catch {
        Write-Warning "Set-String failed: $Path\$Name :: $(Get-ErrorText $_)"
    }
}

function Set-BinaryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][byte[]]$Value
    )
    try {
        Ensure-Key $Path
        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        } else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "Binary restored: $Path\$Name"
    } catch {
        Write-Warning "Set-Binary failed: $Path\$Name :: $(Get-ErrorText $_)"
    }
}

function Remove-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    try {
        if (Test-Path $Path) {
            $prop = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $prop) {
                Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
                Write-Host "Policy/value removed: $Path\$Name"
            }
        }
    } catch {
        Write-Warning "Remove-RegValue failed: $Path\$Name :: $(Get-ErrorText $_)"
    }
}

function Export-RegKey {
    param([Parameter(Mandatory)][string]$RegPath)
    try {
        $safeName = ($RegPath -replace '[\\/:*?"<>| ]', '_') + ".reg"
        $outFile = Join-Path $RestoreBackupDir $safeName
        & reg.exe export $RegPath $outFile /y *> $null
    } catch { }
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    $out = & $FilePath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$FilePath failed: $($Arguments -join ' ') :: $(Join-NativeOutput $out)"
    }
    return $LASTEXITCODE
}

function Set-ServiceRestoreState {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][ValidateSet('Automatic','Manual','Disabled')][string]$StartupType,
        [bool]$DelayedAuto = $false,
        [bool]$StartService = $false
    )

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Warning "Service not found, skipped: $DisplayName ($Name)"
        return
    }

    try {
        if ($DelayedAuto) {
            $out = & sc.exe config $Name start= delayed-auto 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "sc.exe delayed-auto failed: $DisplayName :: $(Join-NativeOutput $out)"
            } else {
                Write-Host "StartupType restored: $DisplayName = Automatic (Delayed Start)"
            }
        } else {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Host "StartupType restored: $DisplayName = $StartupType"
        }
    } catch {
        Write-Warning "Set-Service failed: $DisplayName :: $(Get-ErrorText $_)"
        $scStart = switch ($StartupType) {
            'Automatic' { 'auto' }
            'Manual' { 'demand' }
            'Disabled' { 'disabled' }
        }
        $out = & sc.exe config $Name start= $scStart 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "sc.exe config failed: $DisplayName :: $(Join-NativeOutput $out)"
        }
    }

    if ($StartService) {
        try {
            Start-Service -Name $Name -ErrorAction Stop
            Write-Host "Service started: $DisplayName"
        } catch {
            Write-Warning "Start-Service failed: $DisplayName :: $(Get-ErrorText $_)"
        }
    }
}

function Invoke-SystemParametersInfoBool {
    param(
        [Parameter(Mandatory)][int]$Action,
        [Parameter(Mandatory)][bool]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    try {
        if (-not ("Win32.NativeMethods" -as [type])) {
            Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace Win32 {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError=true)]
        public static extern bool SystemParametersInfo(int uiAction, int uiParam, bool pvParam, int fWinIni);
    }
}
"@ -ErrorAction Stop
        }
        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDCHANGE = 0x02
        $ok = [Win32.NativeMethods]::SystemParametersInfo($Action, 0, $Value, ($SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE))
        if (-not $ok) {
            Write-Warning "SystemParametersInfo returned false: $Label"
        }
    } catch {
        Write-Warning "SystemParametersInfo failed: $Label :: $(Get-ErrorText $_)"
    }
}

function Restore-AppxFromExistingPackage {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    $registered = $false

    foreach ($pattern in $Patterns) {
        $pkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like $pattern -or $_.PackageFullName -like $pattern
        }

        foreach ($pkg in $pkgs) {
            $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
            if (Test-Path $manifest) {
                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                    Write-Host "Appx re-registered [$Description]: $($pkg.Name)"
                    $registered = $true
                } catch {
                    Write-Warning "Appx re-register failed [$Description]: $($pkg.Name) :: $(Get-ErrorText $_)"
                }
            }
        }
    }

    # Best-effort fallback for staged folders that remain under WindowsApps.
    $windowsApps = Join-Path $env:ProgramFiles "WindowsApps"
    if (Test-Path $windowsApps) {
        foreach ($pattern in $Patterns) {
            try {
                Get-ChildItem -LiteralPath $windowsApps -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern } | ForEach-Object {
                    $manifest = Join-Path $_.FullName "AppxManifest.xml"
                    if (Test-Path $manifest) {
                        try {
                            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                            Write-Host "Appx re-registered from WindowsApps [$Description]: $($_.Name)"
                            $script:__AppxRegisteredFromFolder = $true
                            $registered = $true
                        } catch {
                            Write-Warning "WindowsApps re-register failed [$Description]: $($_.Name) :: $(Get-ErrorText $_)"
                        }
                    }
                }
            } catch {
                Write-Warning "WindowsApps enumeration failed [$Description] :: $(Get-ErrorText $_)"
            }
        }
    }

    return $registered
}

function Install-AppFromStoreWithWinget {
    param(
        [Parameter(Mandatory)][string]$Description,
        [string]$StoreId,
        [string]$StoreQuery
    )

    if (-not $InstallMissingAppsWithWinget) { return $false }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        Write-Warning "winget.exe not found. Store install skipped: $Description"
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($StoreId)) {
        Write-Host "winget install from Microsoft Store [$Description]: $StoreId"
        $out = & winget.exe install --source msstore --id $StoreId --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Warning "winget install failed [$Description/$StoreId]: $(Join-NativeOutput $out)"
    }

    if (-not [string]::IsNullOrWhiteSpace($StoreQuery)) {
        Write-Host "winget install by name from Microsoft Store [$Description]: $StoreQuery"
        $out = & winget.exe install --source msstore --name $StoreQuery --accept-source-agreements --accept-package-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }
        Write-Warning "winget name install failed [$Description/$StoreQuery]: $(Join-NativeOutput $out)"
    }

    return $false
}

function Open-StoreSearch {
    param([Parameter(Mandatory)][string]$Query)
    if (-not $OpenStoreSearchForMissingApps) { return }
    try {
        $encoded = [System.Uri]::EscapeDataString($Query)
        Start-Process "ms-windows-store://search/?query=$encoded" -ErrorAction SilentlyContinue
    } catch { }
}

function Import-LatestRegistryBackupIfRequested {
    if (-not $ImportLatestRegistryBackup) { return }
    $backupRoot = Join-Path $env:SystemDrive "Win11_Tweak_Backup"
    if (-not (Test-Path $backupRoot)) {
        Write-Warning "Registry backup root not found: $backupRoot"
        return
    }

    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        Write-Warning "No registry backup directory found under $backupRoot"
        return
    }

    Write-Step "Importing latest optimizer registry backup: $($latest.FullName)"
    Get-ChildItem -LiteralPath $latest.FullName -Filter "*.reg" -File -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "reg import: $($_.Name)"
        & reg.exe import $_.FullName *> $null
    }
}

Write-Step "Creating pre-restore registry backup"
$keysToBackup = @(
    "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
    "HKCU\Control Panel\International\User Profile",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects",
    "HKCU\Software\Microsoft\Windows\DWM",
    "HKCU\Control Panel\Desktop",
    "HKCU\Control Panel\Desktop\WindowMetrics",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Search",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings",
    "HKCU\Software\Microsoft\Siuf",
    "HKCU\Software\Microsoft\GameBar",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Lock Screen",
    "HKCU\Software\Policies\Microsoft\Windows\Explorer",
    "HKCU\Software\Policies\Microsoft\Windows\CloudContent",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config",
    "HKLM\SOFTWARE\Policies\Microsoft\Dsh",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
)
foreach ($k in $keysToBackup) { Export-RegKey $k }

Import-LatestRegistryBackupIfRequested

Write-Step "Restoring privacy, suggestions, advertising, and SCOOBE settings"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 1
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy"
Set-Dword "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 1

$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$cdmDwords = @(
    "ContentDeliveryAllowed",
    "FeatureManagementEnabled",
    "OemPreInstalledAppsEnabled",
    "PreInstalledAppsEnabled",
    "PreInstalledAppsEverEnabled",
    "SilentInstalledAppsEnabled",
    "SoftLandingEnabled",
    "SubscribedContentEnabled",
    "SystemPaneSuggestionsEnabled",
    "RotatingLockScreenEnabled",
    "RotatingLockScreenOverlayEnabled",
    "SlideshowEnabled",
    "SubscribedContent-310093Enabled",
    "SubscribedContent-314559Enabled",
    "SubscribedContent-338380Enabled",
    "SubscribedContent-338387Enabled",
    "SubscribedContent-338388Enabled",
    "SubscribedContent-338389Enabled",
    "SubscribedContent-338393Enabled",
    "SubscribedContent-353694Enabled",
    "SubscribedContent-353696Enabled",
    "SubscribedContent-353698Enabled",
    "SubscribedContent-88000326Enabled"
)
foreach ($name in $cdmDwords) { Set-Dword $cdmPath $name 1 }

$cloudHKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
$cloudHKCU = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
$cloudDisableValues = @(
    "DisableWindowsConsumerFeatures",
    "DisableConsumerFeatures",
    "DisableSoftLanding",
    "DisableThirdPartySuggestions",
    "DisableWindowsSpotlightFeatures",
    "DisableWindowsSpotlightOnSettings",
    "DisableWindowsSpotlightOnActionCenter",
    "DisableWindowsSpotlightWindowsWelcomeExperience",
    "DisableTailoredExperiencesWithDiagnosticData"
)
foreach ($name in $cloudDisableValues) { Remove-RegValue $cloudHKLM $name }
Remove-RegValue $cloudHKCU "DisableTailoredExperiencesWithDiagnosticData"
Remove-RegValue $cloudHKCU "DisableSoftLanding"
Remove-RegValue $cloudHKCU "DisableConsumerFeatures"

Write-Step "Restoring Windows Backup app-sync policy"
$settingSyncPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
$settingSyncValues = @(
    "DisableAppSyncSettingSync",
    "DisableAppSyncSettingSyncUserOverride",
    "DisableApplicationSettingSync",
    "DisableApplicationSettingSyncUserOverride"
)
foreach ($name in $settingSyncValues) { Remove-RegValue $settingSyncPath $name }

Write-Step "Restoring Feedback and Diagnostics options"
$dataPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
foreach ($name in @("AllowTelemetry", "LimitDiagnosticLogCollection", "LimitDumpCollection", "DoNotShowFeedbackNotifications", "DisableTelemetryOptInSettingsUx")) {
    Remove-RegValue $dataPolicyPath $name
}
Remove-RegValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry"
Remove-RegValue "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod"
Remove-RegValue "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 1
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 0
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 0
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 1
Set-Dword "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 1

Write-Step "Restoring Search, Store search suggestions, Bing search, Cortana, and cloud search settings"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "AllowSearchToUseLocation" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsMSACloudSearchEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsAADCloudSearchEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 1
Remove-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "SafeSearchMode"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 1
$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
foreach ($name in @("AllowCortana", "AllowCloudSearch", "AllowSearchToUseLocation", "ConnectedSearchUseWeb", "ConnectedSearchUseWebOverMeteredConnections", "DisableWebSearch", "EnableDynamicContentInWSB")) {
    Remove-RegValue $searchPolicyPath $name
}
# Restore Windows key / Start search Store-related policy blocks.
Remove-RegValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
Remove-RegValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith"

Write-Step "Restoring File Explorer options"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 1
# Windows 11 default is Home/Quick Access. If This PC is desired, change LaunchTo back to 1 manually.
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 2
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowRecent" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowFrequent" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudFilesInQuickAccess" 1

Write-Step "Restoring selected Windows services"
$serviceDefaults = @(
    [pscustomobject]@{ Name = "DiagTrack";   DisplayName = "Connected User Experiences and Telemetry"; StartupType = "Automatic"; DelayedAuto = $false; StartService = $true },
    [pscustomobject]@{ Name = "SCardSvr";    DisplayName = "Smart Card"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
    [pscustomobject]@{ Name = "ScDeviceEnum"; DisplayName = "Smart Card Device Enumeration Service"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
    [pscustomobject]@{ Name = "SCPolicySvc"; DisplayName = "Smart Card Removal Policy"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
    [pscustomobject]@{ Name = "CertPropSvc"; DisplayName = "Certificate Propagation"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
    [pscustomobject]@{ Name = "WSearch";     DisplayName = "Windows Search"; StartupType = "Automatic"; DelayedAuto = $true; StartService = $true },
    [pscustomobject]@{ Name = "SEMgrSvc";    DisplayName = "Payments and NFC/SE Manager"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false }
)
foreach ($svc in $serviceDefaults) {
    Set-ServiceRestoreState -Name $svc.Name -DisplayName $svc.DisplayName -StartupType $svc.StartupType -DelayedAuto $svc.DelayedAuto -StartService $svc.StartService
}

Write-Step "Restoring Windows Update Delivery Optimization settings"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode"
# Default unmanaged Windows behavior is not forced by policy; set local UI storage to LAN peering.
Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DownloadMode" 1
Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 1

Write-Step "Restoring Balanced power scheme"
$balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
Invoke-Native powercfg.exe "/setactive" $balancedGuid | Out-Null
if ($RemoveUltimatePerformanceSchemes) {
    $out = & powercfg.exe /list 2>&1
    foreach ($line in $out) {
        if ([string]$line -match '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})' -and [string]$line -match 'Ultimate Performance|최고의 성능') {
            $guid = $matches[1]
            if ($guid -ne $balancedGuid) {
                Invoke-Native powercfg.exe "/delete" $guid | Out-Null
            }
        }
    }
}

Write-Step "Restoring Game Bar user settings"
Set-Dword "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 1
Set-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1

Write-Step "Restoring common visual effects and transparency defaults"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0
# Common Windows 11-friendly defaults. Exact OEM/user prior state can only be restored from a pre-run registry backup.
Set-BinaryValue "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x9E,0x3E,0x07,0x80,0x12,0x00,0x00,0x00))
Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 0
Set-StringValue "HKCU:\Control Panel\Desktop" "DragFullWindows" "1"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 1
Set-StringValue "HKCU:\Control Panel\Desktop" "FontSmoothing" "2"
Set-Dword "HKCU:\Control Panel\Desktop" "FontSmoothingType" 2
Set-StringValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "1"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1
Invoke-SystemParametersInfoBool -Action 0x0025 -Value $true -Label "Show window contents while dragging"
Invoke-SystemParametersInfoBool -Action 0x004B -Value $true -Label "Smooth edges of screen fonts"

Write-Step "Restoring Lock Screen tips, Spotlight, and Widgets policies"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 1
Remove-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "DetailedStatusApp"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsOnLockScreen"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsBoard"
Write-Host "TaskbarDa direct write is intentionally not used; Widgets are restored by removing HKLM policies."

Write-Step "Restoring removed Microsoft Store apps where possible"
$appRestoreItems = @(
    [pscustomobject]@{ Description = "MSN Weather"; Patterns = @("*Microsoft.BingWeather*"); StoreId = "9WZDNCRFJ3Q2"; StoreQuery = "MSN Weather" },
    [pscustomobject]@{ Description = "Microsoft News"; Patterns = @("*Microsoft.BingNews*", "*Microsoft.News*", "*Microsoft.MicrosoftNews*"); StoreId = "9WZDNCRFHVFW"; StoreQuery = "Microsoft News" },
    [pscustomobject]@{ Description = "Xbox"; Patterns = @("*Microsoft.GamingApp*", "*Microsoft.XboxApp*"); StoreId = "9MV0B5HZVK9Z"; StoreQuery = "Xbox" },
    [pscustomobject]@{ Description = "Xbox Identity Provider"; Patterns = @("*Microsoft.XboxIdentityProvider*"); StoreId = "9WZDNCRD1HKW"; StoreQuery = "Xbox Identity Provider" },
    [pscustomobject]@{ Description = "Xbox Game Bar / Game Speech Window"; Patterns = @("*Microsoft.XboxGamingOverlay*", "*Microsoft.XboxGameOverlay*", "*Microsoft.XboxSpeechToTextOverlay*", "*Microsoft.Xbox.TCUI*"); StoreId = "9NZKPSTSNW4P"; StoreQuery = "Xbox Game Bar" },
    [pscustomobject]@{ Description = "Microsoft Family"; Patterns = @("*MicrosoftCorporationII.MicrosoftFamily*", "*MicrosoftFamily*"); StoreId = ""; StoreQuery = "Microsoft Family Safety" },
    [pscustomobject]@{ Description = "Solitaire & Casual Games"; Patterns = @("*Microsoft.MicrosoftSolitaireCollection*"); StoreId = "9WZDNCRFHWD2"; StoreQuery = "Microsoft Solitaire Collection" },
    [pscustomobject]@{ Description = "Feedback Hub"; Patterns = @("*Microsoft.WindowsFeedbackHub*"); StoreId = "9NBLGGH4R32N"; StoreQuery = "Feedback Hub" }
)

$manualStoreItems = New-Object System.Collections.Generic.List[string]
foreach ($item in $appRestoreItems) {
    $registered = Restore-AppxFromExistingPackage -Description $item.Description -Patterns $item.Patterns
    if (-not $registered) {
        $installed = Install-AppFromStoreWithWinget -Description $item.Description -StoreId $item.StoreId -StoreQuery $item.StoreQuery
        if (-not $installed) {
            $manualStoreItems.Add($item.StoreQuery) | Out-Null
            Open-StoreSearch -Query $item.StoreQuery
        }
    }
}

Write-Step "Refreshing policies and restarting shell components"
& gpupdate.exe /target:computer /force | Out-Null
& gpupdate.exe /target:user /force | Out-Null

$procNames = @("explorer", "SearchHost", "StartMenuExperienceHost", "Widgets", "WidgetService")
foreach ($p in $procNames) {
    Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
Start-Process explorer.exe

Write-Host ""
Write-Host "Restore pre-change backup path: $RestoreBackupDir"
if ($manualStoreItems.Count -gt 0) {
    Write-Host ""
    Write-Warning "Some removed Store apps could not be restored automatically. Open Microsoft Store and install/search these items manually:"
    $manualStoreItems | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
}
Write-Host ""
Write-Host "Restore completed. Reboot is recommended."
