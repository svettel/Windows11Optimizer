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
    echo Completed.
) else (
    echo Failed. Exit code: %__RC%
)
echo.
echo Press any key to close.
pause >nul
exit /b %__RC%


# POWERSHELL_START

trap {
    Write-Host ""
    Write-Host "[FATAL] PowerShell payload stopped." -ForegroundColor Red
    Write-Host ("[FATAL] " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Press any key to close."
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
    exit 1
}

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

function Get-ErrorText {
    param([Parameter(Mandatory)][object]$ErrorRecord)

    $message = ""

    if ($null -ne $ErrorRecord.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.Exception.Message)) {
        $message = [string]$ErrorRecord.Exception.Message
    }
    else {
        $message = [string]$ErrorRecord
    }

    # Native command stderr redirected through PowerShell can append this type name.
    # It is not useful to the user and can make an ordinary access-denied message look ambiguous.
    $message = $message -replace '\s*System\.Management\.Automation\.RemoteException\s*$', ''
    $message = $message.Trim()

    if ([string]::IsNullOrWhiteSpace($message)) {
        return "Unknown error"
    }

    return $message
}

function Join-NativeOutput {
    param([object[]]$Output)

    if ($null -eq $Output) {
        return ""
    }

    $text = ($Output | ForEach-Object { [string]$_ }) -join " "
    $text = $text -replace '\s*System\.Management\.Automation\.RemoteException\s*', ' '
    $text = $text -replace '\s+', ' '
    return $text.Trim()
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
        Write-Warning "Registry write failed: $Path\$Name = $Value :: $(Get-ErrorText $_)"
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
        Write-Warning "Registry write failed: $Path\$Name = $Value :: $(Get-ErrorText $_)"
    }
}

function Set-Binary {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][byte[]]$Value
    )

    try {
        Ensure-Key $Path

        if (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        }
    }
    catch {
        $hex = ($Value | ForEach-Object { $_.ToString("X2") }) -join " "
        Write-Warning "Registry write failed: $Path\$Name = $hex :: $(Get-ErrorText $_)"
    }
}

function Ensure-User32Interop {
    if ("Win32.NativeMethods" -as [type]) {
        return
    }

    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, System.IntPtr pvParam, uint fWinIni);
"@ -ErrorAction Stop
}

function Invoke-SystemParametersInfoBool {
    param(
        [Parameter(Mandatory)][uint32]$Action,
        [Parameter(Mandatory)][bool]$Value,
        [Parameter(Mandatory)][string]$Label
    )

    try {
        Ensure-User32Interop

        $SPIF_UPDATEINIFILE = 0x01
        $SPIF_SENDCHANGE    = 0x02
        $flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
        $uiParam = if ($Value) { [uint32]1 } else { [uint32]0 }

        $ok = [Win32.NativeMethods]::SystemParametersInfo($Action, $uiParam, [IntPtr]::Zero, [uint32]$flags)
        if (-not $ok) {
            $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Warning "SystemParametersInfo failed: $Label :: Win32Error=$err"
        }
    }
    catch {
        Write-Warning "SystemParametersInfo skipped: $Label :: $(Get-ErrorText $_)"
    }
}


function Invoke-SystemParametersInfoAnimationOff {
    param(
        [string]$Label = "Animation effects"
    )

    try {
        if (-not ("Win32.AnimationNativeMethods" -as [type])) {
            Add-Type -Namespace Win32 -Name AnimationNativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct ANIMATIONINFO {
    public uint cbSize;
    public int iMinAnimate;
}

[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, ref ANIMATIONINFO pvParam, uint fWinIni);
"@ -ErrorAction Stop
        }

        $SPI_SETANIMATION    = [uint32]0x0049
        $SPIF_UPDATEINIFILE = [uint32]0x01
        $SPIF_SENDCHANGE    = [uint32]0x02
        $flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE

        $animInfo = New-Object Win32.AnimationNativeMethods+ANIMATIONINFO
        $animInfo.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf([type][Win32.AnimationNativeMethods+ANIMATIONINFO])
        $animInfo.iMinAnimate = 0

        $ok = [Win32.AnimationNativeMethods]::SystemParametersInfo($SPI_SETANIMATION, $animInfo.cbSize, [ref]$animInfo, $flags)
        if (-not $ok) {
            $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            Write-Warning "SystemParametersInfo failed: $Label :: Win32Error=$err"
        }
    }
    catch {
        Write-Warning "SystemParametersInfo skipped: $Label :: $(Get-ErrorText $_)"
    }
}

function Test-ACPowerOnline {
    try {
        $batteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction Stop
        if ($null -ne $batteryStatus) {
            return [bool]($batteryStatus | Where-Object { $_.PowerOnline -eq $true } | Select-Object -First 1)
        }
    }
    catch {
        # Fall through to secondary checks.
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $lineStatus = [System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus
        if ($lineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online) {
            return $true
        }
        if ($lineStatus -eq [System.Windows.Forms.PowerLineStatus]::Offline) {
            return $false
        }
    }
    catch {
        # Fall through to WMI battery fallback.
    }

    try {
        $batteries = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($null -eq $batteries) {
            return $true
        }

        # Win32_Battery BatteryStatus values commonly treated as AC/charging states:
        # 2=AC/High, 6=Charging, 7=Charging and High, 8=Charging and Low,
        # 9=Charging and Critical, 11=Partially Charged.
        return [bool]($batteries | Where-Object { $_.BatteryStatus -in 2,6,7,8,9,11 } | Select-Object -First 1)
    }
    catch {
        Write-Warning "AC power detection failed; Ultimate Performance activation skipped: $(Get-ErrorText $_)"
        return $false
    }
}

function Get-PowerSchemeGuidByLabel {
    param([Parameter(Mandatory)][string[]]$Labels)

    $out = & powercfg.exe /list 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /list :: $(Join-NativeOutput $out)"
        return $null
    }

    foreach ($line in $out) {
        foreach ($label in $Labels) {
            if ([string]$line -match [regex]::Escape($label) -and [string]$line -match '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                return $matches[1]
            }
        }
    }

    return $null
}

function Enable-UltimatePerformanceOnAC {
    Write-Step "Applying Ultimate Performance power scheme on AC power only"

    if (-not (Test-ACPowerOnline)) {
        Write-Host "DC power detected. Ultimate Performance activation skipped; DC power policy was not changed."
        return
    }

    $ultimateBaseGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $targetGuid = Get-PowerSchemeGuidByLabel -Labels @("Ultimate Performance", "최고의 성능")

    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        $dupOut = & powercfg.exe /duplicatescheme $ultimateBaseGuid 2>&1
        if ($LASTEXITCODE -eq 0) {
            $dupText = Join-NativeOutput $dupOut
            if ($dupText -match '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
                $targetGuid = $matches[1]
            }
        }
        else {
            Write-Warning "powercfg failed: powercfg /duplicatescheme $ultimateBaseGuid :: $(Join-NativeOutput $dupOut)"
        }
    }

    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        $targetGuid = $ultimateBaseGuid
    }

    Invoke-PowerCfg "/setactive" $targetGuid
    Write-Host "Ultimate Performance active on AC power: $targetGuid"
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
        Write-Warning "powercfg failed: powercfg $($Arguments -join ' ') :: $(Join-NativeOutput $out)"
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
        Write-Warning "MMAgent configuration skipped: $(Get-ErrorText $_)"
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
        Write-Warning "Set-Service failed: $label :: $(Get-ErrorText $_)"

        $out = & sc.exe config $Name start= disabled 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "sc.exe config failed: $label :: $(Join-NativeOutput $out)"
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
        Write-Warning "Service stop failed: $label :: $(Get-ErrorText $_)"
    }
}

Write-Step "Creating registry backup"

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
    "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer",
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

# System > Notifications > Suggest ways I can finish setting up my device = Off
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0

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
Set-Dword $cloudHKLM "DisableConsumerFeatures" 1
Set-Dword $cloudHKLM "DisableSoftLanding" 1
Set-Dword $cloudHKLM "DisableThirdPartySuggestions" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightFeatures" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightOnSettings" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightOnActionCenter" 1
Set-Dword $cloudHKLM "DisableWindowsSpotlightWindowsWelcomeExperience" 1
Set-Dword $cloudHKLM "DisableTailoredExperiencesWithDiagnosticData" 1
Set-Dword $cloudHKCU "DisableTailoredExperiencesWithDiagnosticData" 1

# User-scope CloudContent complements for Windows tips / soft landing suppression.
Set-Dword $cloudHKCU "DisableSoftLanding" 1
Set-Dword $cloudHKCU "DisableConsumerFeatures" 1

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

Write-Step "Disabling Search, Store suggestions, Search permissions, Cloud content search, and Bing search"

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

# Windows key / Start search: disable web-backed suggestions, including Microsoft Store app suggestions.
Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1

# Also disable Store-based app lookup surfaces used by Windows shell.
Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1

Write-Step "Disabling File Explorer sync provider notifications"

# Folder Options > View > Advanced settings > Show sync provider notifications = Off
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0

Write-Step "Configuring File Explorer startup and privacy options"

# Folder Options > General > Open File Explorer to: This PC
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1

# Folder Options > General > Privacy
# Show recently used files, frequently used folders, and Office.com files = Off
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowRecent" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowFrequent" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudFilesInQuickAccess" 0

Write-Step "Disabling and stopping selected Windows services"

$servicesToDisableAndStop = @(
    [pscustomobject]@{ Name = "DiagTrack"; DisplayName = "Connected User Experiences and Telemetry" },
    [pscustomobject]@{ Name = "SCardSvr"; DisplayName = "Smart Card" },
    [pscustomobject]@{ Name = "ScDeviceEnum"; DisplayName = "Smart Card Device Enumeration Service" },
    [pscustomobject]@{ Name = "SCPolicySvc"; DisplayName = "Smart Card Removal Policy" },
    [pscustomobject]@{ Name = "CertPropSvc"; DisplayName = "Certificate Propagation" },
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

Enable-UltimatePerformanceOnAC

Invoke-MMAgentEnable

Write-Step "Disabling Game Bar controller launch"

Set-Dword "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
Set-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 0

Write-Step "Applying custom visual effects"

# System Properties > Advanced > Performance > Visual Effects = Custom.
# Use a custom UserPreferencesMask that keeps requested non-animation visual effects enabled
# while keeping the Accessibility > Visual effects > Animation effects group off.
# - Enable Peek
# - Show window contents while dragging
# - Show thumbnails instead of icons
# - Show translucent selection rectangle
# - Smooth edges of screen fonts
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
Set-Binary "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x07,0x80,0x10,0x00,0x00,0x00))

Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 1
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 0

Set-String "HKCU:\Control Panel\Desktop" "DragFullWindows" "1"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 1
Set-String "HKCU:\Control Panel\Desktop" "FontSmoothing" "2"
Set-Dword "HKCU:\Control Panel\Desktop" "FontSmoothingType" 2

# Explicitly keep non-requested common visual-effect items disabled.
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0

Write-Step "Disabling Accessibility animation effects"

# Settings > Accessibility > Visual effects > Animation effects = Off.
# The Settings toggle is not controlled by MinAnimate alone. It also depends on UserPreferencesMask.
# Keep VisualFXSetting at Custom so the requested visual-effect checkboxes above remain enabled.
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
Set-Binary "HKCU:\Control Panel\Desktop" "UserPreferencesMask" ([byte[]](0x90,0x12,0x07,0x80,0x10,0x00,0x00,0x00))
Set-String "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
Invoke-SystemParametersInfoAnimationOff -Label "Animation effects"

# Accessibility > Visual effects > Transparency effects = Off.
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

# Apply the two UI parameters that Windows exposes through SystemParametersInfo.
Invoke-SystemParametersInfoBool -Action 0x0025 -Value $true -Label "Show window contents while dragging"
Invoke-SystemParametersInfoBool -Action 0x004B -Value $true -Label "Smooth edges of screen fonts"

Write-Step "Disabling Lock Screen tips and setting status to None"

Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0
Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0

Set-String "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "DetailedStatusApp" ""

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsOnLockScreen" 1

Write-Step "Disabling taskbar Widgets"

Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsBoard" 1
# Do not write HKCU/HKEY_USERS TaskbarDa directly. Current Windows 11 builds may protect this user toggle;
# the HKLM Widgets policy above is the supported control path.
Write-Warning "TaskbarDa user toggle was skipped. Widgets policy is already applied."

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


Write-Step "Removing Family, Solitaire and Casual Games, and Feedback Hub apps"

$additionalConsumerAppPatterns = @(
    [pscustomobject]@{ Pattern = "*MicrosoftCorporationII.MicrosoftFamily*"; Description = "Family" },
    [pscustomobject]@{ Pattern = "*MicrosoftFamily*"; Description = "Family" },
    [pscustomobject]@{ Pattern = "*Microsoft.MicrosoftSolitaireCollection*"; Description = "Solitaire and Casual Games" },
    [pscustomobject]@{ Pattern = "*Microsoft.WindowsFeedbackHub*"; Description = "Feedback Hub" }
)

foreach ($item in $additionalConsumerAppPatterns) {
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
