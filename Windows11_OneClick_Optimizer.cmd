@echo off
setlocal EnableExtensions
chcp 65001 >nul

echo Windows One Click Optimizer
echo e-mail : s_vettel@naver.com
echo.
set "__SELF=%~f0"
set "__SELFDIR=%~dp0"
set "__TEMPPS=%TEMP%\Apply-Win11-Setting_%RANDOM%%RANDOM%.ps1"

fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator privileges...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $p = $env:__SELF; $d = $env:__SELFDIR; $q = [char]34; Start-Process -FilePath $env:ComSpec -ArgumentList '/c', ($q + $p + $q) -WorkingDirectory $d -Verb RunAs; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
    if errorlevel 1 (
        echo Failed to request administrator privileges or the request was cancelled.
        echo Press any key to close.
        pause >nul
    )
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
    echo Completed.
) else (
    echo Failed. Exit code: %__RC%
)
echo.
echo Press any key to close.
pause >nul
exit /b %__RC%


# POWERSHELL_START

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$BackupRoot = Join-Path $env:SystemDrive "Win11_Tweak_Backup"
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir  = Join-Path $BackupRoot $Timestamp
New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Ensure-Key {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
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
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Warning "Registry write failed: $Path\$Name = $Value"
        Write-Warning $_.Exception.Message
    }
}

function Set-String {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Value
    )

    try {
        Ensure-Key $Path

        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        Write-Warning "Registry write failed: $Path\$Name = $Value"
        Write-Warning $_.Exception.Message
    }
}

function Export-RegKey {
    param([Parameter(Mandatory)][string]$RegPath)

    $safeName = ($RegPath -replace '[\\/:*?"<>| ]', '_') + ".reg"
    $outFile = Join-Path $BackupDir $safeName
    & reg.exe export $RegPath $outFile /y *> $null
}

function Invoke-PowerCfg {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    $out = & powercfg.exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg $($Arguments -join ' ') :: $out"
    }
}

function Invoke-MMAgentEnable {
    Write-Step "Enabling Memory Compression and Page Combining"

    try {
        Import-Module MMAgent -ErrorAction Stop

        # Requested commands
        Enable-MMAgent -mc -ErrorAction Stop
        Enable-MMAgent -PageCombining -ErrorAction Stop

        $mma = Get-MMAgent -ErrorAction SilentlyContinue

        if ($null -ne $mma) {
            Write-Host "MemoryCompression : $($mma.MemoryCompression)"
            Write-Host "PageCombining     : $($mma.PageCombining)"
        }
    }
    catch {
        Write-Warning "MMAgent configuration failed."
        Write-Warning $_.Exception.Message
    }
}

function Disable-AndStopService {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$DisplayName = ""
    )

    $label = $Name
    if (-not [string]::IsNullOrWhiteSpace($DisplayName)) {
        $label = "$DisplayName ($Name)"
    }

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Warning "Service not found; skipped: $label"
        return
    }

    try {
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        Write-Host "StartupType Disabled: $label"
    }
    catch {
        Write-Warning "Set-Service failed: $label"
        Write-Warning $_.Exception.Message

        $out = & sc.exe config $Name start= disabled 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "sc.exe config failed: $label :: $($out -join ' ')"
        }
        else {
            Write-Host "StartupType Disabled via sc.exe: $label"
        }
    }

    try {
        $svc.Refresh()
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction Stop
            Write-Host "Stopped service: $label"
        }
        else {
            Write-Host "Already stopped: $label"
        }
    }
    catch {
        Write-Warning "Service stop failed: $label"
        Write-Warning $_.Exception.Message
    }
}

Write-Step "Creating registry backup"

$keysToBackup = @(
    "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo",
    "HKCU\Control Panel\International\User Profile",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Search",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings",
    "HKCU\Software\Microsoft\Siuf",
    "HKCU\Software\Microsoft\GameBar",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Lock Screen",
    "HKCU\Software\Policies\Microsoft\Windows\Explorer",
    "HKCU\Software\Policies\Microsoft\Windows\CloudContent",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization",
    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config",
    "HKLM\SOFTWARE\Policies\Microsoft\Dsh",
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync",
    "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
)

foreach ($k in $keysToBackup) {
    Export-RegKey $k
}

Write-Step "Disabling Privacy > General / Recommendations / Suggestions"

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1

Set-Dword "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

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

foreach ($name in $cdmDwords) {
    Set-Dword $cdmPath $name 0
}

$cloudHKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
$cloudHKCU = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"

Set-Dword $cloudHKLM "DisableWindowsConsumerFeatures" 1
Set-Dword $cloudHKLM "DisableSoftLanding" 1
Set-Dword $cloudHKLM "DisableThirdPartySuggestions" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightFeatures" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightOnSettings" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightOnActionCenter" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightWindowsWelcomeExperience" 1
Set-Dword $cloudHKLM "DisableTailoredExperiencesWithDiagnosticData" 1
Set-Dword $cloudHKCU "DisableTailoredExperiencesWithDiagnosticData" 1

Write-Step "Disabling Accounts > Windows Backup > Remember my apps"

# Accounts > Windows backup > Remember my apps = Off
# DisableAppSyncSettingSync 2 = enabled policy "Do not sync Apps".
# UserOverride 1 = users cannot turn app syncing back on through Settings.
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableAppSyncSettingSync" 2
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableAppSyncSettingSyncUserOverride" 1

# Compatibility with Windows builds / ADMX mappings that expose app-settings sync separately.
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableApplicationSettingSync" 2
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableApplicationSettingSyncUserOverride" 1

Write-Step "Disabling Feedback and Diagnostics options"

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1
Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 1

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDiagnosticLogCollection" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "LimitDumpCollection" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DoNotShowFeedbackNotifications" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "DisableTelemetryOptInSettingsUx" 1

Set-Dword "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
Set-Dword "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" 0

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" 0

Set-Dword "HKCU:\Software\Microsoft\Input\TIPC" "Enabled" 0
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
Set-Dword "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" "HarvestContacts" 0
Set-Dword "HKCU:\Software\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0

Write-Step "Disabling Search, Search permissions, Cloud content search, and Bing search"

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "AllowSearchToUseLocation" 0

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsMSACloudSearchEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsAADCloudSearchEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDeviceSearchHistoryEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "SafeSearchMode" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "IsDynamicSearchBoxEnabled" 0

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCloudSearch" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowSearchToUseLocation" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWebOverMeteredConnections" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "EnableDynamicContentInWSB" 0

Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

Write-Step "Disabling File Explorer sync provider notifications"

# Folder Options > View > Advanced settings > Show sync provider notifications = Off
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

Write-Step "Disabling and stopping selected Windows services"

$servicesToDisableAndStop = @(
    [pscustomobject]@{ Name = "DiagTrack"; DisplayName = "Connected User Experiences and Telemetry" },
    [pscustomobject]@{ Name = "SCardSvr"; DisplayName = "Smart Card" },
    [pscustomobject]@{ Name = "ScDeviceEnum"; DisplayName = "Smart Card Device Enumeration Service" },
    [pscustomobject]@{ Name = "SCPolicySvc"; DisplayName = "Smart Card Removal Policy" },
    [pscustomobject]@{ Name = "WSearch"; DisplayName = "Windows Search" },
    [pscustomobject]@{ Name = "SEMgrSvc"; DisplayName = "Payments and NFC/SE Manager" }
)

foreach ($service in $servicesToDisableAndStop) {
    Disable-AndStopService -Name $service.Name -DisplayName $service.DisplayName
}

Write-Step "Disabling Windows Update Delivery Optimization peer downloads"

# Windows Update > Delivery Optimization > Allow downloads from other devices = Off
# DODownloadMode 0 = HTTP only, no peering.
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0

# Mirror local Settings UI storage used on unmanaged devices. Policy above remains authoritative.
Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DownloadMode" 0
Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0

Write-Step "Applying power mode fallback settings"

Invoke-PowerCfg "/setactive" "SCHEME_BALANCED"

Invoke-PowerCfg "/setacvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PROCTHROTTLEMIN" "5"
Invoke-PowerCfg "/setacvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PROCTHROTTLEMAX" "100"
Invoke-PowerCfg "/setacvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PERFEPP" "0"

Invoke-PowerCfg "/setdcvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PROCTHROTTLEMIN" "5"
Invoke-PowerCfg "/setdcvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PROCTHROTTLEMAX" "100"
Invoke-PowerCfg "/setdcvalueindex" "SCHEME_CURRENT" "SUB_PROCESSOR" "PERFEPP" "50"

Invoke-PowerCfg "/setactive" "SCHEME_CURRENT"

Invoke-MMAgentEnable

Write-Step "Disabling Game Bar controller launch"

Set-Dword "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
Set-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 0

Write-Step "Disabling visual transparency effects"

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

Write-Step "Disabling Lock Screen tips and setting status to None"

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0

Set-String "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "DetailedStatusApp" ""

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsOnLockScreen" 1

Write-Step "Disabling taskbar Widgets"

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsBoard" 1

$taskbarDaOutput = & reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "TaskbarDa user toggle was skipped. Widgets policy is already applied."
    Write-Warning ($taskbarDaOutput -join " ")
}


Write-Step "Removing Weather and News apps"

$appPatterns = @(
    "*Microsoft.BingWeather*",
    "*Microsoft.BingNews*",
    "*Microsoft.News*",
    "*Microsoft.MicrosoftNews*"
)

foreach ($pattern in $appPatterns) {
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $pattern } | ForEach-Object {
        Write-Host "Remove-AppxPackage: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }

    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pattern } | ForEach-Object {
        Write-Host "Remove-AppxProvisionedPackage: $($_.DisplayName)"
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Step "Removing Xbox, Xbox Identity Provider, Xbox Live, Game Bar, and Game Speech Window apps"

# Stop related foreground/background processes before Appx removal.
# This prevents removal failures when Xbox Game Bar or its helper processes are already running.
$xboxGameProcessNames = @(
    "GameBar",
    "GameBarFTServer",
    "GameBarPresenceWriter",
    "XboxAppServices",
    "XboxPcApp"
)

foreach ($processName in $xboxGameProcessNames) {
    Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

$xboxGameAppPatterns = @(
    [pscustomobject]@{ Pattern = "*Microsoft.GamingApp*"; Description = "Xbox" },
    [pscustomobject]@{ Pattern = "*Microsoft.XboxApp*"; Description = "Xbox legacy app" },
    [pscustomobject]@{ Pattern = "*Microsoft.XboxIdentityProvider*"; Description = "Xbox Identity Provider" },
    [pscustomobject]@{ Pattern = "*Microsoft.Xbox.TCUI*"; Description = "Xbox Live" },
    [pscustomobject]@{ Pattern = "*Microsoft.XboxGamingOverlay*"; Description = "Game Bar" },
    [pscustomobject]@{ Pattern = "*Microsoft.XboxGameOverlay*"; Description = "Game Bar overlay component" },
    [pscustomobject]@{ Pattern = "*Microsoft.XboxSpeechToTextOverlay*"; Description = "Game Speech Window" }
)

foreach ($item in $xboxGameAppPatterns) {
    $pattern = $item.Pattern
    $description = $item.Description

    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } | ForEach-Object {
        Write-Host "Remove-AppxPackage [$description]: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }

    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern } | ForEach-Object {
        Write-Host "Remove-AppxProvisionedPackage [$description]: $($_.DisplayName)"
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
    }
}

$RemoveWebExperiencePack = $false

if ($RemoveWebExperiencePack) {
    Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "*MicrosoftWindows.Client.WebExperience*" } | ForEach-Object {
        Write-Host "Remove WebExperiencePack: $($_.Name)"
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
}

Write-Step "Refreshing policies and restarting shell components"

& gpupdate.exe /target:computer /force | Out-Null
& gpupdate.exe /target:user /force | Out-Null

$procNames = @(
    "explorer",
    "SearchHost",
    "StartMenuExperienceHost",
    "Widgets",
    "WidgetService"
)

foreach ($p in $procNames) {
    Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Process explorer.exe

Write-Host ""
Write-Host "Registry backup path: $BackupDir"
Write-Host "Reboot is recommended."
