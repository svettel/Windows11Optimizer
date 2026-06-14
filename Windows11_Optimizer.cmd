@echo off
setlocal EnableExtensions
chcp 65001 >nul

echo Windows One Click Optimizer - Group Toggle
echo e-mail : s_vettel@naver.com
echo.
set "__SELF=%~f0"
set "__SELFDIR=%~dp0"
set "__TEMPPS=%TEMP%\Win11_GroupToggle_%RANDOM%%RANDOM%.ps1"

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

rem Read this UTF-8 batch file explicitly; Windows PowerShell 5.1 Get-Content defaults to ANSI without BOM.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$utf8In = New-Object System.Text.UTF8Encoding($false, $true); $utf8Out = New-Object System.Text.UTF8Encoding($true); $content = [System.IO.File]::ReadAllText($env:__SELF, $utf8In); $marker = '# POWER' + 'SHELL_START'; $idx = $content.LastIndexOf($marker); if ($idx -lt 0) { throw 'POWERSHELL_START marker not found.' }; $ps = $content.Substring($idx + $marker.Length).TrimStart([char]13,[char]10); [System.IO.File]::WriteAllText($env:__TEMPPS, $ps, $utf8Out)"
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
    echo Failed or completed with warnings. Exit code: %__RC%
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

$InstallMissingAppsWithWinget = $true
$OpenStoreSearchForMissingApps = $false
$RemoveUltimatePerformanceSchemes = $false
$BackupRoot = Join-Path $env:SystemDrive "Win11_Tweak_GroupToggle_Backup"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$BackupDir = Join-Path $BackupRoot $Timestamp
New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-ActionHeader {
    param(
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Title
    )
    Write-Host ""
    Write-Host ("==== {0}: {1} ====" -f $Mode, $Title) -ForegroundColor Yellow
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
    }
    catch {
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
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "DWORD: $Path\$Name = $Value"
    }
    catch {
        Write-Warning "Registry write failed: $Path\$Name = $Value :: $(Get-ErrorText $_)"
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
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force -ErrorAction Stop | Out-Null
        }
        Write-Host "String: $Path\$Name = $Value"
    }
    catch {
        Write-Warning "Registry write failed: $Path\$Name = $Value :: $(Get-ErrorText $_)"
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
        }
        else {
            New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        }
        $hex = ($Value | ForEach-Object { $_.ToString("X2") }) -join " "
        Write-Host "Binary: $Path\$Name = $hex"
    }
    catch {
        $hex = ($Value | ForEach-Object { $_.ToString("X2") }) -join " "
        Write-Warning "Registry write failed: $Path\$Name = $hex :: $(Get-ErrorText $_)"
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
                Write-Host "Removed: $Path\$Name"
            }
            else {
                Write-Host "Already absent: $Path\$Name"
            }
        }
        else {
            Write-Host "Key not found: $Path"
        }
    }
    catch {
        Write-Warning "Remove-RegValue failed: $Path\$Name :: $(Get-ErrorText $_)"
    }
}

function Export-RegKey {
    param([Parameter(Mandatory)][string]$RegPath)
    try {
        $safeName = ($RegPath -replace '[\\/:*?"<>| ]', '_') + ".reg"
        $outFile = Join-Path $BackupDir $safeName
        & reg.exe export $RegPath $outFile /y *> $null
    }
    catch { }
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

function Invoke-PowerCfg {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $out = & powercfg.exe @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg $($Arguments -join ' ') :: $(Join-NativeOutput $out)"
    }
}

function Ensure-User32Interop {
    if ("Win32.NativeMethods" -as [type]) { return }
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
        $SPIF_SENDCHANGE = 0x02
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


function Invoke-SystemParametersInfoAnimation {
    param(
        [Parameter(Mandatory)][bool]$Enabled,
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
        $SPI_SETANIMATION = [uint32]0x0049
        $SPIF_UPDATEINIFILE = [uint32]0x01
        $SPIF_SENDCHANGE = [uint32]0x02
        $flags = $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
        $animInfo = New-Object Win32.AnimationNativeMethods+ANIMATIONINFO
        $animInfo.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf([type][Win32.AnimationNativeMethods+ANIMATIONINFO])
        $animInfo.iMinAnimate = if ($Enabled) { 1 } else { 0 }
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
    <#
        AC 전원 연결 여부를 여러 소스에서 교차 확인한다.
        하나의 WMI 값만으로 판단하면 일부 Modern Standby/가상화/데스크톱 환경에서
        실제 AC 연결 상태를 잘못 판단할 수 있으므로 여러 소스를 사용한다.
    #>
    $observations = New-Object System.Collections.Generic.List[object]

    try {
        $batteryStatus = Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction Stop
        foreach ($item in @($batteryStatus)) {
            if ($null -ne $item -and $null -ne $item.PowerOnline) {
                $observations.Add([pscustomobject]@{ Source = "root\wmi:BatteryStatus.PowerOnline"; IsAC = [bool]$item.PowerOnline })
            }
        }
    }
    catch { }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $lineStatus = [System.Windows.Forms.SystemInformation]::PowerStatus.PowerLineStatus
        if ($lineStatus -eq [System.Windows.Forms.PowerLineStatus]::Online) {
            $observations.Add([pscustomobject]@{ Source = "System.Windows.Forms.PowerLineStatus"; IsAC = $true })
        }
        elseif ($lineStatus -eq [System.Windows.Forms.PowerLineStatus]::Offline) {
            $observations.Add([pscustomobject]@{ Source = "System.Windows.Forms.PowerLineStatus"; IsAC = $false })
        }
    }
    catch { }

    try {
        $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
        if ($batteries.Count -eq 0) {
            Write-Host "AC power assumed: no battery device was detected."
            return $true
        }

        foreach ($battery in $batteries) {
            if ($battery.BatteryStatus -in 6,7,8,9) {
                $observations.Add([pscustomobject]@{ Source = "Win32_Battery.BatteryStatus"; IsAC = $true })
            }
            elseif ($battery.BatteryStatus -eq 1) {
                $observations.Add([pscustomobject]@{ Source = "Win32_Battery.BatteryStatus"; IsAC = $false })
            }
        }
    }
    catch { }

    if ($observations | Where-Object { $_.IsAC -eq $true } | Select-Object -First 1) {
        Write-Host "AC power detected."
        return $true
    }

    if ($observations.Count -gt 0) {
        $details = ($observations | ForEach-Object { "$($_.Source)=$($_.IsAC)" }) -join "; "
        Write-Host "DC power detected or AC not confirmed: $details"
        return $false
    }

    Write-Warning "AC power state could not be determined. Power scheme activation skipped to avoid changing DC policy."
    return $false
}

function Get-PowerSchemes {
    $out = & powercfg.exe /list 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /list :: $(Join-NativeOutput $out)"
        return @()
    }

    $schemes = @()
    foreach ($line in $out) {
        $s = [string]$line
        if ($s -match '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
            $guid = $matches[1].ToLowerInvariant()
            $name = ""
            if ($s -match '\(([^\)]*)\)') { $name = $matches[1] }
            $schemes += [pscustomobject]@{
                Guid   = $guid
                Name   = $name
                Line   = $s
                Active = ($s -match '\*')
            }
        }
    }
    return @($schemes)
}

function Get-ActivePowerSchemeGuid {
    $out = & powercfg.exe /getactivescheme 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /getactivescheme :: $(Join-NativeOutput $out)"
        return $null
    }

    $activeText = Join-NativeOutput $out
    if ($activeText -match '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})') {
        return $matches[1].ToLowerInvariant()
    }
    return $null
}

function Find-PowerSchemeByGuidOrName {
    param(
        [string]$Guid,
        [Parameter(Mandatory)][string]$NamePattern
    )

    $schemes = @(Get-PowerSchemes)
    if (-not [string]::IsNullOrWhiteSpace($Guid)) {
        $exact = $schemes | Where-Object { $_.Guid -eq $Guid.ToLowerInvariant() } | Select-Object -First 1
        if ($null -ne $exact) { return $exact.Guid }
    }

    $named = $schemes | Where-Object { $_.Name -match $NamePattern -or $_.Line -match $NamePattern } | Select-Object -First 1
    if ($null -ne $named) { return $named.Guid }

    return $null
}

function Find-HighPerformanceScheme {
    return Find-PowerSchemeByGuidOrName -Guid "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -NamePattern '(?i)high\s*performance|고\s*성능'
}

function Find-UltimatePerformanceScheme {
    return Find-PowerSchemeByGuidOrName -Guid "e9a42b02-d5df-448d-aa00-03f14749eb61" -NamePattern '(?i)ultimate\s+performance|최고\s*의?\s*성능|최고\s*성능'
}

function Set-PowerSchemeName {
    param(
        [Parameter(Mandatory)][string]$Guid,
        [Parameter(Mandatory)][string]$Name
    )
    $out = & powercfg.exe /changename $Guid $Name 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /changename $Guid $Name :: $(Join-NativeOutput $out)"
    }
}

function New-PowerSchemeFromTemplate {
    param(
        [Parameter(Mandatory)][string]$TemplateGuid,
        [Parameter(Mandatory)][string]$DisplayName
    )

    $template = $TemplateGuid.ToLowerInvariant()
    $newGuid = ([guid]::NewGuid()).ToString().ToLowerInvariant()
    $dupOut = & powercfg.exe /duplicatescheme $template $newGuid 2>&1
    if ($LASTEXITCODE -eq 0) {
        Set-PowerSchemeName -Guid $newGuid -Name $DisplayName
        return $newGuid
    }

    Write-Warning "powercfg failed: powercfg /duplicatescheme $template $newGuid :: $(Join-NativeOutput $dupOut)"

    $dupOut = & powercfg.exe /duplicatescheme $template 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /duplicatescheme $template :: $(Join-NativeOutput $dupOut)"
        return $null
    }

    $dupText = Join-NativeOutput $dupOut
    $guidMatches = [regex]::Matches($dupText, '([0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12})')
    if ($guidMatches.Count -gt 0) {
        $createdGuid = $guidMatches[$guidMatches.Count - 1].Groups[1].Value.ToLowerInvariant()
        Set-PowerSchemeName -Guid $createdGuid -Name $DisplayName
        return $createdGuid
    }

    Write-Warning "powercfg /duplicatescheme succeeded, but the new scheme GUID could not be parsed."
    return $null
}

function Set-ACPerformanceDefaults {
    param([Parameter(Mandatory)][string]$Guid)

    $settings = @(
        @("SUB_PROCESSOR", "PROCTHROTTLEMIN", "100"),
        @("SUB_PROCESSOR", "PROCTHROTTLEMAX", "100"),
        @("SUB_PROCESSOR", "PERFEPP", "0")
    )

    foreach ($setting in $settings) {
        $out = & powercfg.exe /setacvalueindex $Guid $setting[0] $setting[1] $setting[2] 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "powercfg failed: powercfg /setacvalueindex $Guid $($setting[0]) $($setting[1]) $($setting[2]) :: $(Join-NativeOutput $out)"
        }
    }
}

function Get-OrCreateHighPerformanceScheme {
    $highGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"

    $targetGuid = Find-HighPerformanceScheme
    if (-not [string]::IsNullOrWhiteSpace($targetGuid)) {
        Write-Host "Existing High Performance scheme found: $targetGuid"
        return $targetGuid
    }

    Write-Host "High Performance scheme was not found. Creating it."
    $targetGuid = New-PowerSchemeFromTemplate -TemplateGuid $highGuid -DisplayName "High performance"
    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        Write-Warning "The built-in High Performance template is unavailable. Creating a high-performance compatible scheme from Balanced."
        $targetGuid = New-PowerSchemeFromTemplate -TemplateGuid $balancedGuid -DisplayName "High performance"
    }

    if (-not [string]::IsNullOrWhiteSpace($targetGuid)) {
        Set-ACPerformanceDefaults -Guid $targetGuid
        return $targetGuid
    }

    return $null
}

function Get-OrCreateUltimatePerformanceScheme {
    $ultimateGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"
    $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"

    $targetGuid = Find-UltimatePerformanceScheme
    if (-not [string]::IsNullOrWhiteSpace($targetGuid)) {
        Write-Host "Existing Ultimate Performance scheme found: $targetGuid"
        return $targetGuid
    }

    Write-Host "Ultimate Performance scheme was not found. Creating it from the built-in template."
    $targetGuid = New-PowerSchemeFromTemplate -TemplateGuid $ultimateGuid -DisplayName "Ultimate Performance"

    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        Write-Warning "The built-in Ultimate Performance template is unavailable on this system. Creating an Ultimate Performance compatible scheme from High Performance or Balanced."
        $sourceGuid = Find-HighPerformanceScheme
        if ([string]::IsNullOrWhiteSpace($sourceGuid)) {
            $sourceGuid = Get-OrCreateHighPerformanceScheme
        }
        if (-not [string]::IsNullOrWhiteSpace($sourceGuid)) {
            $targetGuid = New-PowerSchemeFromTemplate -TemplateGuid $sourceGuid -DisplayName "Ultimate Performance"
        }
        if ([string]::IsNullOrWhiteSpace($targetGuid)) {
            $targetGuid = New-PowerSchemeFromTemplate -TemplateGuid $balancedGuid -DisplayName "Ultimate Performance"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($targetGuid)) {
        Set-ACPerformanceDefaults -Guid $targetGuid
        return $targetGuid
    }

    return $null
}

function Set-ActivePowerSchemeAndVerify {
    param(
        [Parameter(Mandatory)][string]$Guid,
        [string]$DisplayName = "Power scheme"
    )

    $normalizedGuid = $Guid.ToLowerInvariant()
    $setOut = & powercfg.exe /setactive $normalizedGuid 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "powercfg failed: powercfg /setactive $normalizedGuid :: $(Join-NativeOutput $setOut)"
        return $false
    }

    Start-Sleep -Milliseconds 300
    $activeGuid = Get-ActivePowerSchemeGuid
    if ($activeGuid -eq $normalizedGuid) {
        Write-Host "Active power scheme verified: $normalizedGuid"
        return $true
    }

    Start-Sleep -Milliseconds 700
    $activeGuid = Get-ActivePowerSchemeGuid
    if ($activeGuid -eq $normalizedGuid) {
        Write-Host "Active power scheme verified after retry: $normalizedGuid"
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($activeGuid)) {
        Write-Warning "$DisplayName setactive command was issued, but active power scheme could not be verified."
    }
    else {
        Write-Warning "$DisplayName was not activated. Current active scheme: $activeGuid; target scheme: $normalizedGuid"
    }
    return $false
}


function Get-WindowsPowerModeOverlayGuid {
    param([Parameter(Mandatory)][ValidateSet("Balanced", "BestPowerEfficiency", "BetterPerformance", "BestPerformance")][string]$Mode)

    switch ($Mode) {
        "Balanced"            { return "00000000-0000-0000-0000-000000000000" }
        "BestPowerEfficiency" { return "961cc777-2547-4f9d-8174-7d86181b8a7a" }
        "BetterPerformance"   { return "00000000-0000-0000-0000-000000000000" }
        "BestPerformance"     { return "ded574b5-45a0-4f42-8737-46345c09c238" }
    }
}

function Get-WindowsPowerModeOverlayAlias {
    param([Parameter(Mandatory)][ValidateSet("Balanced", "BestPowerEfficiency", "BetterPerformance", "BestPerformance")][string]$Mode)

    switch ($Mode) {
        "Balanced"            { return "OVERLAY_SCHEME_NONE" }
        "BestPowerEfficiency" { return "OVERLAY_SCHEME_MIN" }
        "BetterPerformance"   { return "OVERLAY_SCHEME_NONE" }
        "BestPerformance"     { return "OVERLAY_SCHEME_MAX" }
    }
}

function Get-WindowsPowerModeOverlayCurrentText {
    <#
        Read the current Windows power mode overlay by powercfg only.
        Do not call undocumented DLL APIs and do not write protected HKLM registry values.
    #>

    $qOut = & powercfg.exe /q OVERLAY_SCHEME_CURRENT 2>&1
    if ($LASTEXITCODE -eq 0) {
        return (Join-NativeOutput $qOut)
    }

    $qOut2 = & powercfg.exe /query OVERLAY_SCHEME_CURRENT 2>&1
    if ($LASTEXITCODE -eq 0) {
        return (Join-NativeOutput $qOut2)
    }

    return $null
}

function Test-WindowsPowerModeOverlayActive {
    param([Parameter(Mandatory)][ValidateSet("Balanced", "BestPowerEfficiency", "BetterPerformance", "BestPerformance")][string]$Mode)

    $targetGuid = (Get-WindowsPowerModeOverlayGuid -Mode $Mode).ToLowerInvariant()
    $targetAlias = Get-WindowsPowerModeOverlayAlias -Mode $Mode
    $currentText = Get-WindowsPowerModeOverlayCurrentText

    if ([string]::IsNullOrWhiteSpace($currentText)) {
        return $false
    }

    if ($currentText.ToLowerInvariant().Contains($targetGuid)) {
        return $true
    }

    if ($currentText -match [regex]::Escape($targetAlias)) {
        return $true
    }

    # Some builds report only localized display names rather than the alias/GUID.
    if ($Mode -eq "BestPerformance" -and $currentText -match '(?i)best\s+performance|최고\s*의?\s*성능') {
        return $true
    }
    if ($Mode -eq "Balanced" -and $currentText -match '(?i)recommended|balanced|권장|균형') {
        return $true
    }

    return $false
}

function Set-WindowsPowerModeOverlayAc {
    param(
        [Parameter(Mandatory)][ValidateSet("Balanced", "BestPowerEfficiency", "BetterPerformance", "BestPerformance")][string]$Mode,
        [string]$DisplayName = "Windows power mode"
    )

    $alias = Get-WindowsPowerModeOverlayAlias -Mode $Mode
    $guid = (Get-WindowsPowerModeOverlayGuid -Mode $Mode).ToLowerInvariant()

    # Correct power-mode path: use powercfg /overlaysetactive.
    # Do not use /setacvalueindex scheme_current overlay <settingGuid> <overlayGuid>.
    # That command treats the last argument as a numeric setting index on many Windows builds
    # and returns "value format is incorrect or out of range."
    # Do not call undocumented powrprof.dll overlay APIs; they can crash powershell.exe.
    # Do not write HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes directly.

    $attempts = @(
        @($alias),
        @($guid)
    )

    $messages = New-Object System.Collections.Generic.List[string]
    foreach ($args in $attempts) {
        $out = & powercfg.exe /overlaysetactive @args 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$DisplayName command succeeded: powercfg /overlaysetactive $($args -join ' ')"
            Start-Sleep -Milliseconds 300
            if (Test-WindowsPowerModeOverlayActive -Mode $Mode) {
                Write-Host "$DisplayName verified by powercfg query."
            }
            else {
                Write-Host "$DisplayName command completed. Reopen Settings or reboot if the UI has not refreshed yet."
            }
            return $true
        }
        $messages.Add("powercfg /overlaysetactive $($args -join ' ') :: $(Join-NativeOutput $out)")
    }

    Write-Warning "$DisplayName could not be changed with powercfg /overlaysetactive."
    foreach ($message in $messages) { Write-Warning $message }
    Write-Warning "The script did not call undocumented DLL APIs and did not write protected HKLM overlay registry values."
    return $false
}

function Enable-SettingsBestPerformancePowerModeOnAC {
    Write-Step "Applying Windows Settings Power mode: Best performance on AC power"
    if (-not (Test-ACPowerOnline)) {
        Write-Host "Windows Settings power mode activation skipped because AC power was not confirmed. DC power mode was not changed."
        return $false
    }

    # Windows Settings > System > Power & battery > Power mode is available with the Balanced base plan.
    # Do not activate the legacy Control Panel High Performance plan for menu item 1.
    $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
    if (-not (Set-ActivePowerSchemeAndVerify -Guid $balancedGuid -DisplayName "Balanced base scheme for Windows power mode")) {
        Write-Warning "Balanced base power scheme could not be activated. Windows Settings power mode may not be available."
        return $false
    }

    return Set-WindowsPowerModeOverlayAc -Mode "BestPerformance" -DisplayName "Windows Settings power mode: Best performance"
}

function Read-PowerPlanOptimizationChoice {
    Write-Host ""
    Write-Host "전원 최적화 방식을 선택하십시오." -ForegroundColor Yellow
    Write-Host " 1. 고성능 - Windows 설정 > 시스템 > 전원 및 배터리 > 전원 모드: 최고의 성능"
    Write-Host " 2. 최고의 성능 - 제어판 전원 관리 옵션 / Ultimate Performance 전원 계획"
    Write-Host "취소하려면 Esc 또는 n을 누르십시오."

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 27) { Write-Host "취소되었습니다."; return "Cancel" }
        $ch = [string]$key.Character
        if ($ch -eq "1") { Write-Host "고성능을 선택했습니다. Windows 설정의 전원 모드를 최고의 성능으로 설정합니다."; return "HighPerformance" }
        if ($ch -eq "2") { Write-Host "최고의 성능을 선택했습니다. Ultimate Performance 전원 계획을 설정합니다."; return "UltimatePerformance" }
        if ($ch -match '^[nN]$') { Write-Host "취소되었습니다."; return "Cancel" }
        Write-Host "잘못된 입력입니다. 1, 2, n, Esc 중 하나를 누르십시오."
    }
}

function Enable-HighPerformanceOnAC {
    # Menu item 1 intentionally uses the Windows 11 Settings power mode overlay,
    # not the legacy Control Panel High Performance power plan.
    return Enable-SettingsBestPerformancePowerModeOnAC
}

function Enable-UltimatePerformanceOnAC {
    Write-Step "Applying Ultimate Performance power scheme on AC power only"
    if (-not (Test-ACPowerOnline)) {
        Write-Host "Ultimate Performance activation skipped because AC power was not confirmed. DC power policy was not changed."
        return $false
    }

    $targetGuid = Get-OrCreateUltimatePerformanceScheme
    if ([string]::IsNullOrWhiteSpace($targetGuid)) {
        Write-Warning "Ultimate Performance scheme could not be created or found. Active power scheme was not changed."
        return $false
    }

    if (Set-ActivePowerSchemeAndVerify -Guid $targetGuid -DisplayName "Ultimate Performance") {
        Write-Host "Ultimate Performance active on AC power: $targetGuid"
        return $true
    }
    return $false
}

function Restore-BalancedPowerScheme {
    Write-Step "Restoring Balanced power scheme and Windows power mode"
    $balancedGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
    [void](Set-ActivePowerSchemeAndVerify -Guid $balancedGuid -DisplayName "Balanced")
    [void](Set-WindowsPowerModeOverlayAc -Mode "Balanced" -DisplayName "Windows Settings power mode: Balanced")
    Write-Host "Balanced power scheme restore command was issued: $balancedGuid"

    if ($RemoveUltimatePerformanceSchemes) {
        $schemes = Get-PowerSchemes
        foreach ($scheme in $schemes) {
            if (($scheme.Name -match '(?i)ultimate\s+performance|최고\s*의?\s*성능|최고\s*성능' -or $scheme.Line -match '(?i)ultimate\s+performance|최고\s*의?\s*성능|최고\s*성능') -and $scheme.Guid -ne $balancedGuid) {
                Invoke-Native powercfg.exe "/delete" $scheme.Guid | Out-Null
            }
        }
    }
}

function Invoke-MMAgentEnable {
    Write-Step "Enabling Memory Compression and Page Combining"
    try {
        Import-Module MMAgent -ErrorAction Stop
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

function Invoke-MMAgentDisable {
    Write-Step "Disabling Memory Compression and Page Combining"
    try {
        Import-Module MMAgent -ErrorAction Stop
        Disable-MMAgent -mc -ErrorAction Stop
        Disable-MMAgent -PageCombining -ErrorAction Stop
        $mma = Get-MMAgent -ErrorAction SilentlyContinue
        if ($null -ne $mma) {
            Write-Host "MemoryCompression : $($mma.MemoryCompression)"
            Write-Host "PageCombining     : $($mma.PageCombining)"
        }
    }
    catch {
        Write-Warning "MMAgent restore/disable skipped: $(Get-ErrorText $_)"
    }
}

function Disable-AndStopService {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$DisplayName = ""
    )
    $label = $Name
    if (-not [string]::IsNullOrWhiteSpace($DisplayName)) { $label = "$DisplayName ($Name)" }
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
            }
            else {
                Write-Host "StartupType restored: $DisplayName = Automatic (Delayed Start)"
            }
        }
        else {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Host "StartupType restored: $DisplayName = $StartupType"
        }
    }
    catch {
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
            $svc.Refresh()
            if ($svc.Status -ne 'Running') {
                Start-Service -Name $Name -ErrorAction Stop
                Write-Host "Started service: $DisplayName"
            }
        }
        catch {
            Write-Warning "Start-Service failed: $DisplayName :: $(Get-ErrorText $_)"
        }
    }
}

function Remove-AppxByPatterns {
    param([Parameter(Mandatory)][object[]]$Items)
    foreach ($item in $Items) {
        $pattern = if ($item -is [string]) { $item } else { $item.Pattern }
        $description = if ($item -is [string]) { $item } else { $item.Description }
        Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern } | ForEach-Object {
            Write-Host "Remove-AppxPackage [$description]: $($_.Name)"
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $pattern -or $_.PackageName -like $pattern } | ForEach-Object {
            Write-Host "Remove-AppxProvisionedPackage [$description]: $($_.DisplayName)"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function Restore-AppxFromExistingPackage {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][string[]]$Patterns
    )
    $registered = $false
    foreach ($pattern in $Patterns) {
        $pkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $pattern -or $_.PackageFullName -like $pattern }
        foreach ($pkg in $pkgs) {
            $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
            if (Test-Path $manifest) {
                try {
                    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                    Write-Host "Appx re-registered [$Description]: $($pkg.Name)"
                    $registered = $true
                }
                catch {
                    Write-Warning "Appx re-register failed [$Description]: $($pkg.Name) :: $(Get-ErrorText $_)"
                }
            }
        }
    }
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
                            $registered = $true
                        }
                        catch {
                            Write-Warning "WindowsApps re-register failed [$Description]: $($_.Name) :: $(Get-ErrorText $_)"
                        }
                    }
                }
            }
            catch {
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
    }
    catch { }
}

function Restore-AppxByItems {
    param([Parameter(Mandatory)][object[]]$Items)
    $manualStoreItems = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Items) {
        $registered = Restore-AppxFromExistingPackage -Description $item.Description -Patterns $item.Patterns
        if (-not $registered) {
            $installed = Install-AppFromStoreWithWinget -Description $item.Description -StoreId $item.StoreId -StoreQuery $item.StoreQuery
            if (-not $installed) {
                $manualStoreItems.Add($item.StoreQuery) | Out-Null
                Open-StoreSearch -Query $item.StoreQuery
            }
        }
    }
    if ($manualStoreItems.Count -gt 0) {
        Write-Host ""
        Write-Warning "Some Store apps could not be restored automatically. Install/search these manually in Microsoft Store:"
        $manualStoreItems | Sort-Object -Unique | ForEach-Object { Write-Host " - $_" }
    }
}

function Invoke-GpUpdateSafe {
    param(
        [Parameter(Mandatory)][ValidateSet('computer','user')][string]$Target,
        [int]$TimeoutSeconds = 20
    )
    try {
        $args = @("/target:$Target", "/force", "/wait:0")
        $proc = Start-Process -FilePath "gpupdate.exe" -ArgumentList $args -WindowStyle Hidden -PassThru -ErrorAction Stop
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill() } catch { }
            Write-Warning "gpupdate timeout skipped: target=$Target"
            return
        }
        if ($proc.ExitCode -ne 0) {
            Write-Warning "gpupdate returned exit code $($proc.ExitCode): target=$Target"
        }
    }
    catch {
        Write-Warning "gpupdate failed: target=$Target :: $(Get-ErrorText $_)"
    }
}

function Refresh-PoliciesAndShell {
    param(
        [switch]$SkipGpUpdate,
        [switch]$SkipShellRestart
    )
    Write-Step "Refreshing policies and restarting shell components"

    if (-not $SkipGpUpdate) {
        Invoke-GpUpdateSafe -Target "computer"
        Invoke-GpUpdateSafe -Target "user"
    }
    else {
        Write-Host "Policy refresh skipped for this group."
    }

    if (-not $SkipShellRestart) {
        $procNames = @("explorer", "SearchHost", "StartMenuExperienceHost", "Widgets", "WidgetService")
        foreach ($p in $procNames) {
            Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        Start-Process explorer.exe
    }
    else {
        Write-Host "Shell restart skipped for this group."
    }
}

function Backup-CurrentRegistryState {
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
        "HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes",
        "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    )
    foreach ($k in $keysToBackup) { Export-RegKey $k }
    Write-Host "Registry backup path: $BackupDir"
}

function Get-ServiceOptimizationItems {
    return @(
        [pscustomobject]@{ Name = "DiagTrack"; DisplayName = "Connected User Experiences and Telemetry" },
        [pscustomobject]@{ Name = "SCardSvr"; DisplayName = "Smart Card" },
        [pscustomobject]@{ Name = "ScDeviceEnum"; DisplayName = "Smart Card Device Enumeration Service" },
        [pscustomobject]@{ Name = "SCPolicySvc"; DisplayName = "Smart Card Removal Policy" },
        [pscustomobject]@{ Name = "CertPropSvc"; DisplayName = "Certificate Propagation" },
        [pscustomobject]@{ Name = "WSearch"; DisplayName = "Windows Search" },
        [pscustomobject]@{ Name = "SEMgrSvc"; DisplayName = "Payments and NFC/SE Manager" }
    )
}

function Get-ServiceRestoreItems {
    return @(
        [pscustomobject]@{ Name = "DiagTrack"; DisplayName = "Connected User Experiences and Telemetry"; StartupType = "Automatic"; DelayedAuto = $false; StartService = $true },
        [pscustomobject]@{ Name = "SCardSvr"; DisplayName = "Smart Card"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
        [pscustomobject]@{ Name = "ScDeviceEnum"; DisplayName = "Smart Card Device Enumeration Service"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
        [pscustomobject]@{ Name = "SCPolicySvc"; DisplayName = "Smart Card Removal Policy"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
        [pscustomobject]@{ Name = "CertPropSvc"; DisplayName = "Certificate Propagation"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false },
        [pscustomobject]@{ Name = "WSearch"; DisplayName = "Windows Search"; StartupType = "Automatic"; DelayedAuto = $true; StartService = $true },
        [pscustomobject]@{ Name = "SEMgrSvc"; DisplayName = "Payments and NFC/SE Manager"; StartupType = "Manual"; DelayedAuto = $false; StartService = $false }
    )
}

function Get-WeatherNewsRemoveItems {
    return @(
        [pscustomobject]@{ Pattern = "*Microsoft.BingWeather*"; Description = "Microsoft Bing Weather" },
        [pscustomobject]@{ Pattern = "*Microsoft.BingNews*"; Description = "Microsoft Bing News" },
        [pscustomobject]@{ Pattern = "*Microsoft.News*"; Description = "Microsoft News" },
        [pscustomobject]@{ Pattern = "*Microsoft.MicrosoftNews*"; Description = "Microsoft MicrosoftNews" }
    )
}

function Get-WeatherNewsRestoreItems {
    return @(
        [pscustomobject]@{ Description = "MSN Weather"; Patterns = @("*Microsoft.BingWeather*"); StoreId = "9WZDNCRFJ3Q2"; StoreQuery = "MSN Weather" },
        [pscustomobject]@{ Description = "Microsoft News"; Patterns = @("*Microsoft.BingNews*", "*Microsoft.News*", "*Microsoft.MicrosoftNews*"); StoreId = "9WZDNCRFHVFW"; StoreQuery = "Microsoft News" }
    )
}

function Get-XboxGameRemoveItems {
    return @(
        [pscustomobject]@{ Pattern = "*Microsoft.GamingApp*"; Description = "Xbox" },
        [pscustomobject]@{ Pattern = "*Microsoft.XboxApp*"; Description = "Xbox legacy app" },
        [pscustomobject]@{ Pattern = "*Microsoft.XboxIdentityProvider*"; Description = "Xbox Identity Provider" },
        [pscustomobject]@{ Pattern = "*Microsoft.Xbox.TCUI*"; Description = "Xbox Live" },
        [pscustomobject]@{ Pattern = "*Microsoft.XboxGamingOverlay*"; Description = "Game Bar" },
        [pscustomobject]@{ Pattern = "*Microsoft.XboxGameOverlay*"; Description = "Game Bar overlay component" },
        [pscustomobject]@{ Pattern = "*Microsoft.XboxSpeechToTextOverlay*"; Description = "Game Speech Window" }
    )
}

function Get-XboxGameRestoreItems {
    return @(
        [pscustomobject]@{ Description = "Xbox"; Patterns = @("*Microsoft.GamingApp*", "*Microsoft.XboxApp*"); StoreId = "9MV0B5HZVK9Z"; StoreQuery = "Xbox" },
        [pscustomobject]@{ Description = "Xbox Identity Provider"; Patterns = @("*Microsoft.XboxIdentityProvider*"); StoreId = "9WZDNCRD1HKW"; StoreQuery = "Xbox Identity Provider" },
        [pscustomobject]@{ Description = "Xbox Game Bar / Game Speech Window"; Patterns = @("*Microsoft.XboxGamingOverlay*", "*Microsoft.XboxGameOverlay*", "*Microsoft.XboxSpeechToTextOverlay*", "*Microsoft.Xbox.TCUI*"); StoreId = "9NZKPSTSNW4P"; StoreQuery = "Xbox Game Bar" }
    )
}

function Get-AdditionalAppRemoveItems {
    return @(
        [pscustomobject]@{ Pattern = "*MicrosoftCorporationII.MicrosoftFamily*"; Description = "Family" },
        [pscustomobject]@{ Pattern = "*MicrosoftFamily*"; Description = "Family" },
        [pscustomobject]@{ Pattern = "*Microsoft.MicrosoftSolitaireCollection*"; Description = "Solitaire and Casual Games" },
        [pscustomobject]@{ Pattern = "*Microsoft.WindowsFeedbackHub*"; Description = "Feedback Hub" }
    )
}

function Get-AdditionalAppRestoreItems {
    return @(
        [pscustomobject]@{ Description = "Microsoft Family"; Patterns = @("*MicrosoftCorporationII.MicrosoftFamily*", "*MicrosoftFamily*"); StoreId = ""; StoreQuery = "Microsoft Family Safety" },
        [pscustomobject]@{ Description = "Solitaire & Casual Games"; Patterns = @("*Microsoft.MicrosoftSolitaireCollection*"); StoreId = "9WZDNCRFHWD2"; StoreQuery = "Microsoft Solitaire Collection" },
        [pscustomobject]@{ Description = "Feedback Hub"; Patterns = @("*Microsoft.WindowsFeedbackHub*"); StoreId = "9NBLGGH4R32N"; StoreQuery = "Feedback Hub" }
    )
}

function Apply-Group01 {
    Write-ActionHeader "활성화/최적화" "1. 개인정보 / 추천 / 광고 관련 기능 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1
    Set-Dword "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0
    $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $cdmDwords = @(
        "ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled",
        "PreInstalledAppsEverEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SubscribedContentEnabled",
        "SystemPaneSuggestionsEnabled", "RotatingLockScreenEnabled", "RotatingLockScreenOverlayEnabled", "SlideshowEnabled",
        "SubscribedContent-310093Enabled", "SubscribedContent-314559Enabled", "SubscribedContent-338380Enabled",
        "SubscribedContent-338387Enabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
        "SubscribedContent-338393Enabled", "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled",
        "SubscribedContent-353698Enabled", "SubscribedContent-88000326Enabled"
    )
    foreach ($name in $cdmDwords) { Set-Dword $cdmPath $name 0 }
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
    Set-Dword $cloudHKCU "DisableSoftLanding" 1
    Set-Dword $cloudHKCU "DisableConsumerFeatures" 1
}

function Restore-Group01 {
    Write-ActionHeader "비활성화/원복" "1. 개인정보 / 추천 / 광고 관련 기능 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 1
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy"
    Set-Dword "HKCU:\Control Panel\International\User Profile" "HttpAcceptLanguageOptOut" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 1
    $cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $cdmDwords = @(
        "ContentDeliveryAllowed", "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled",
        "PreInstalledAppsEverEnabled", "SilentInstalledAppsEnabled", "SoftLandingEnabled", "SubscribedContentEnabled",
        "SystemPaneSuggestionsEnabled", "RotatingLockScreenEnabled", "RotatingLockScreenOverlayEnabled", "SlideshowEnabled",
        "SubscribedContent-310093Enabled", "SubscribedContent-314559Enabled", "SubscribedContent-338380Enabled",
        "SubscribedContent-338387Enabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
        "SubscribedContent-338393Enabled", "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled",
        "SubscribedContent-353698Enabled", "SubscribedContent-88000326Enabled"
    )
    foreach ($name in $cdmDwords) { Set-Dword $cdmPath $name 1 }
    $cloudHKLM = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $cloudHKCU = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
    foreach ($name in @("DisableWindowsConsumerFeatures", "DisableConsumerFeatures", "DisableSoftLanding", "DisableThirdPartySuggestions", "DisableWindowsSpotlightFeatures", "DisableWindowsSpotlightOnSettings", "DisableWindowsSpotlightOnActionCenter", "DisableWindowsSpotlightWindowsWelcomeExperience", "DisableTailoredExperiencesWithDiagnosticData")) {
        Remove-RegValue $cloudHKLM $name
    }
    Remove-RegValue $cloudHKCU "DisableTailoredExperiencesWithDiagnosticData"
    Remove-RegValue $cloudHKCU "DisableSoftLanding"
    Remove-RegValue $cloudHKCU "DisableConsumerFeatures"
}

function Apply-Group02 {
    Write-ActionHeader "활성화/최적화" "2. 피드백 및 진단 데이터 관련 설정 조정"
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
}

function Restore-Group02 {
    Write-ActionHeader "비활성화/원복" "2. 피드백 및 진단 데이터 관련 설정 조정"
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
}

function Apply-Group03 {
    Write-ActionHeader "활성화/최적화" "3. 계정 / Windows 백업 / 내 앱 기억하기 비활성화"
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableAppSyncSettingSync" 2
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableAppSyncSettingSyncUserOverride" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableApplicationSettingSync" 2
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync" "DisableApplicationSettingSyncUserOverride" 1
}

function Restore-Group03 {
    Write-ActionHeader "비활성화/원복" "3. 계정 / Windows 백업 / 내 앱 기억하기 비활성화"
    $settingSyncPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
    foreach ($name in @("DisableAppSyncSettingSync", "DisableAppSyncSettingSyncUserOverride", "DisableApplicationSettingSync", "DisableApplicationSettingSyncUserOverride")) {
        Remove-RegValue $settingSyncPath $name
    }
}

function Apply-Group04 {
    Write-ActionHeader "활성화/최적화" "4. Windows 검색 / Bing / Cortana / 클라우드 검색 / Store 검색 비활성화"
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
    Set-Dword "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith" 1
}

function Restore-Group04 {
    Write-ActionHeader "비활성화/원복" "4. Windows 검색 / Bing / Cortana / 클라우드 검색 / Store 검색 비활성화"
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
    Remove-RegValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions"
    Remove-RegValue "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoUseStoreOpenWith"
}

function Apply-Group05 {
    Write-ActionHeader "활성화/최적화" "5. 지정 Windows 서비스 비활성화 및 중지"
    foreach ($service in (Get-ServiceOptimizationItems)) {
        Disable-AndStopService -Name $service.Name -DisplayName $service.DisplayName
    }
}

function Restore-Group05 {
    Write-ActionHeader "비활성화/원복" "5. 지정 Windows 서비스 비활성화 및 중지"
    foreach ($svc in (Get-ServiceRestoreItems)) {
        Set-ServiceRestoreState -Name $svc.Name -DisplayName $svc.DisplayName -StartupType $svc.StartupType -DelayedAuto $svc.DelayedAuto -StartService $svc.StartService
    }
}

function Apply-Group06 {
    Write-ActionHeader "활성화/최적화" "6. Windows Update 배달 최적화 비활성화"
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0
    Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DownloadMode" 0
    Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 0
}

function Restore-Group06 {
    Write-ActionHeader "비활성화/원복" "6. Windows Update 배달 최적화 비활성화"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode"
    Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DownloadMode" 1
    Set-Dword "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" 1
}

function Apply-Group07 {
    Write-ActionHeader "활성화/최적화" "7. 전원 설정 조정"
    $powerChoice = Read-PowerPlanOptimizationChoice
    if ($powerChoice -eq "Cancel") {
        $script:GroupActionCanceled = $true
        return
    }

    $ok = $false
    if ($powerChoice -eq "HighPerformance") {
        $ok = Enable-HighPerformanceOnAC
    }
    elseif ($powerChoice -eq "UltimatePerformance") {
        $ok = Enable-UltimatePerformanceOnAC
    }

    if (-not $ok) {
        $script:GroupActionFailed = $true
    }
}

function Restore-Group07 {
    Write-ActionHeader "비활성화/원복" "7. 전원 설정 조정"
    Restore-BalancedPowerScheme
}

function Apply-Group08 {
    Write-ActionHeader "활성화/최적화" "8. 메모리 관리 기능 활성화"
    Invoke-MMAgentEnable
}

function Restore-Group08 {
    Write-ActionHeader "비활성화/원복" "8. 메모리 관리 기능 활성화"
    Invoke-MMAgentDisable
}

function Apply-Group09 {
    Write-ActionHeader "활성화/최적화" "9. Xbox Game Bar 관련 기능 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 0
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 0
}

function Restore-Group09 {
    Write-ActionHeader "비활성화/원복" "9. Xbox Game Bar 관련 기능 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 1
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "ShowStartupPanel" 1
    Set-Dword "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
}

function Apply-Group10 {
    Write-ActionHeader "활성화/최적화" "10. Xbox / Game Bar 관련 앱 제거"
    foreach ($processName in @("GameBar", "GameBarFTServer", "GameBarPresenceWriter", "XboxAppServices", "XboxPcApp")) {
        Get-Process -Name $processName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Remove-AppxByPatterns -Items (Get-XboxGameRemoveItems)
}

function Restore-Group10 {
    Write-ActionHeader "비활성화/원복" "10. Xbox / Game Bar 관련 앱 제거"
    Restore-AppxByItems -Items (Get-XboxGameRestoreItems)
}

function Apply-Group11 {
    Write-ActionHeader "활성화/최적화" "11. Family / Solitaire & Casual Games / Feedback Hub 앱 제거"
    Remove-AppxByPatterns -Items (Get-AdditionalAppRemoveItems)
}

function Restore-Group11 {
    Write-ActionHeader "비활성화/원복" "11. Family / Solitaire & Casual Games / Feedback Hub 앱 제거"
    Restore-AppxByItems -Items (Get-AdditionalAppRestoreItems)
}

function Apply-Group12 {
    Write-ActionHeader "활성화/최적화" "12. 접근성 / 시각 효과 / 투명 효과 및 애니메이션 효과 비활성화"
    # Do not modify "Smooth edges of screen fonts".
    # FontSmoothing, FontSmoothingType, SPI_SETFONTSMOOTHING, and UserPreferencesMask are intentionally untouched.
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3
    Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 0
    Set-StringValue "HKCU:\Control Panel\Desktop" "DragFullWindows" "1"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
    Set-StringValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "0"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 0
    Invoke-SystemParametersInfoAnimation -Enabled $false -Label "Animation effects"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
    Invoke-SystemParametersInfoBool -Action 0x0025 -Value $true -Label "Show window contents while dragging"
}

function Restore-Group12 {
    Write-ActionHeader "비활성화/원복" "12. 접근성 / 시각 효과 / 투명 효과 및 애니메이션 효과 비활성화"
    # Do not modify "Smooth edges of screen fonts".
    # FontSmoothing, FontSmoothingType, SPI_SETFONTSMOOTHING, and UserPreferencesMask are intentionally untouched.
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "EnableAeroPeek" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisablePreviewDesktop" 0
    Set-StringValue "HKCU:\Control Panel\Desktop" "DragFullWindows" "1"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "IconsOnly" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewAlphaSelect" 1
    Set-StringValue "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate" "1"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAnimations" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ListviewShadow" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1
    Invoke-SystemParametersInfoAnimation -Enabled $true -Label "Animation effects"
    Invoke-SystemParametersInfoBool -Action 0x0025 -Value $true -Label "Show window contents while dragging"
}

function Apply-Group13 {
    Write-ActionHeader "활성화/최적화" "13. 파일 탐색기 / 폴더 옵션 / 시작 위치 및 개인 정보 보호 설정"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowRecent" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowFrequent" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudFilesInQuickAccess" 0
}

function Restore-Group13 {
    Write-ActionHeader "비활성화/원복" "13. 파일 탐색기 / 폴더 옵션 / 시작 위치 및 개인 정보 보호 설정"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 2
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowRecent" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowFrequent" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCloudFilesInQuickAccess" 1
}

function Apply-Group14 {
    Write-ActionHeader "활성화/최적화" "14. 잠금 화면 추천 / 팁 / 상태 표시 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 0
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0
    Set-StringValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "DetailedStatusApp" ""
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsOnLockScreen" 1
}

function Restore-Group14 {
    Write-ActionHeader "비활성화/원복" "14. 잠금 화면 추천 / 팁 / 상태 표시 비활성화"
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenOverlayEnabled" 1
    Set-Dword "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 1
    Remove-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen" "DetailedStatusApp"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsOnLockScreen"
}

function Apply-Group15 {
    Write-ActionHeader "활성화/최적화" "15. 작업 표시줄 위젯 비활성화"
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
    Set-Dword "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsBoard" 1
    Write-Warning "TaskbarDa user toggle was skipped. Widgets policy is already applied."
}

function Restore-Group15 {
    Write-ActionHeader "비활성화/원복" "15. 작업 표시줄 위젯 비활성화"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
    Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "DisableWidgetsBoard"
    Write-Host "TaskbarDa direct write is intentionally not used; Widgets are restored by removing HKLM policies."
}

function Apply-Group16 {
    Write-ActionHeader "활성화/최적화" "16. 날씨 / 뉴스 앱 제거"
    Remove-AppxByPatterns -Items (Get-WeatherNewsRemoveItems)
}

function Restore-Group16 {
    Write-ActionHeader "비활성화/원복" "16. 날씨 / 뉴스 앱 제거"
    Restore-AppxByItems -Items (Get-WeatherNewsRestoreItems)
}

$Groups = @(
    [pscustomobject]@{ No = 1;  Title = "개인정보 / 추천 / 광고 관련 기능 비활성화"; Apply = "Apply-Group01"; Restore = "Restore-Group01" },
    [pscustomobject]@{ No = 2;  Title = "피드백 및 진단 데이터 관련 설정 조정"; Apply = "Apply-Group02"; Restore = "Restore-Group02" },
    [pscustomobject]@{ No = 3;  Title = "계정 / Windows 백업 / 내 앱 기억하기 비활성화"; Apply = "Apply-Group03"; Restore = "Restore-Group03" },
    [pscustomobject]@{ No = 4;  Title = "Windows 검색 / Bing / Cortana / 클라우드 검색 / Store 검색 비활성화"; Apply = "Apply-Group04"; Restore = "Restore-Group04" },
    [pscustomobject]@{ No = 5;  Title = "지정 Windows 서비스 비활성화 및 중지"; Apply = "Apply-Group05"; Restore = "Restore-Group05" },
    [pscustomobject]@{ No = 6;  Title = "Windows Update 배달 최적화 비활성화"; Apply = "Apply-Group06"; Restore = "Restore-Group06" },
    [pscustomobject]@{ No = 7;  Title = "전원 설정 조정"; Apply = "Apply-Group07"; Restore = "Restore-Group07" },
    [pscustomobject]@{ No = 8;  Title = "메모리 관리 기능 활성화"; Apply = "Apply-Group08"; Restore = "Restore-Group08" },
    [pscustomobject]@{ No = 9;  Title = "Xbox Game Bar 관련 기능 비활성화"; Apply = "Apply-Group09"; Restore = "Restore-Group09" },
    [pscustomobject]@{ No = 10; Title = "Xbox / Game Bar 관련 앱 제거"; Apply = "Apply-Group10"; Restore = "Restore-Group10" },
    [pscustomobject]@{ No = 11; Title = "Family / Solitaire & Casual Games / Feedback Hub 앱 제거"; Apply = "Apply-Group11"; Restore = "Restore-Group11" },
    [pscustomobject]@{ No = 12; Title = "접근성 / 시각 효과 / 투명 효과 및 애니메이션 효과 비활성화"; Apply = "Apply-Group12"; Restore = "Restore-Group12" },
    [pscustomobject]@{ No = 13; Title = "파일 탐색기 / 폴더 옵션 / 시작 위치 및 개인 정보 보호 설정"; Apply = "Apply-Group13"; Restore = "Restore-Group13" },
    [pscustomobject]@{ No = 14; Title = "잠금 화면 추천 / 팁 / 상태 표시 비활성화"; Apply = "Apply-Group14"; Restore = "Restore-Group14" },
    [pscustomobject]@{ No = 15; Title = "작업 표시줄 위젯 비활성화"; Apply = "Apply-Group15"; Restore = "Restore-Group15" },
    [pscustomobject]@{ No = 16; Title = "날씨 / 뉴스 앱 제거"; Apply = "Apply-Group16"; Restore = "Restore-Group16" }
)

function Show-Menu {
    Write-Host ""
    Write-Host "Windows11 One Click Optimizer - Group Toggle" -ForegroundColor Cyan
    Write-Host "활성화 = 최적화 적용 / 비활성화 = 원복" -ForegroundColor DarkGray
    Write-Host ""
    foreach ($g in $Groups) {
        Write-Host (("{0,2}. {1}" -f $g.No, $g.Title))
    }
    Write-Host ""
    Write-Host "번호를 입력하고 Enter를 누르십시오. 종료하려면 q를 입력하십시오."
}

function Read-OptimizationChoice {
    param([Parameter(Mandatory)][object]$Group)
    Write-Host ""
    Write-Host ("선택 항목: {0}. {1}" -f $Group.No, $Group.Title) -ForegroundColor Yellow
    Write-Host "최적화를 하시려면 y 또는 엔터, 원복하시려면 r을 눌러주세요. 취소하려면 esc 또는 n을 눌러주세요"
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($key.VirtualKeyCode -eq 27) { Write-Host "취소되었습니다."; return "Cancel" }
        if ($key.VirtualKeyCode -eq 13) { Write-Host "활성화/최적화를 선택했습니다."; return "Apply" }
        $ch = [string]$key.Character
        if ($ch -match '^[yY]$') { Write-Host "활성화/최적화를 선택했습니다."; return "Apply" }
        if ($ch -match '^[rR]$') { Write-Host "비활성화/원복을 선택했습니다."; return "Restore" }
        if ($ch -match '^[nN]$') { Write-Host "취소되었습니다."; return "Cancel" }
        Write-Host "잘못된 입력입니다. y, Enter, r, n, Esc 중 하나를 누르십시오."
    }
}

function Invoke-GroupAction {
    param(
        [Parameter(Mandatory)][object]$Group,
        [Parameter(Mandatory)][ValidateSet('Apply','Restore')][string]$Mode
    )
    $fn = if ($Mode -eq 'Apply') { $Group.Apply } else { $Group.Restore }
    $script:GroupActionCanceled = $false
    $script:GroupActionFailed = $false
    try {
        & $fn
        if ($script:GroupActionCanceled) {
            Write-Host "작업이 취소되었습니다."
            return
        }
        if ($script:GroupActionFailed) {
            Write-Warning "작업이 완료되지 않았습니다: $($Group.No). $($Group.Title) / $Mode"
            return
        }
        if ($Group.No -eq 7) {
            Write-Host "Power settings do not require gpupdate or shell restart. Post-action refresh was skipped."
        }
        else {
            Refresh-PoliciesAndShell
        }
        Write-Host ""
        Write-Host "작업 완료: $($Group.No). $($Group.Title) / $Mode" -ForegroundColor Green
        Write-Host "재부팅을 권장합니다."
    }
    catch {
        Write-Warning "Group action failed: $($Group.No). $($Group.Title) / $Mode :: $(Get-ErrorText $_)"
    }
}

Backup-CurrentRegistryState

while ($true) {
    Show-Menu
    $selection = Read-Host "선택"
    if ([string]::IsNullOrWhiteSpace($selection)) { continue }
    if ($selection -match '^[qQ]$') { break }
    [int]$num = 0
    if (-not [int]::TryParse($selection, [ref]$num)) {
        Write-Warning "숫자 1~16 또는 q만 입력하십시오."
        continue
    }
    $group = $Groups | Where-Object { $_.No -eq $num } | Select-Object -First 1
    if ($null -eq $group) {
        Write-Warning "해당 번호의 그룹이 없습니다: $num"
        continue
    }
    $choice = Read-OptimizationChoice -Group $group
    if ($choice -eq "Cancel") { continue }
    Invoke-GroupAction -Group $group -Mode $choice
    Write-Host ""
    Write-Host "계속하려면 아무 키나 누르십시오. 종료하려면 다음 메뉴에서 q를 입력하십시오."
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { }
}

Write-Host ""
Write-Host "종료합니다."
Write-Host "Registry backup path: $BackupDir"
