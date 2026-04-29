# =============================================================================
# Install_UserLicense.ps1
# Application  : CapProSW 7.0.1
# Description  : Silently installs Capture Pro Software without a Software
#                Serial Number or Registration ID. The application files are
#                deployed to the endpoint but no license is activated at install
#                time. The user is prompted to enter their own SSN and retrieve
#                a license when they launch Capture Pro for the first time.
#
#                Use this script for testing or in scenarios where each user
#                manages their own license activation.
#
#                Designed for deployment via Microsoft Intune as a Win32 app.
#                Install behavior must be set to "System" in Intune.
#
# References   : Kodak Capture Pro Silent Install Procedure (Scenario 9)
#                Stand-alone | Typical | Internet Access | No Hardware Key
#                No Software Serial Number
# =============================================================================

# --- Configuration -----------------------------------------------------------

$AppVersion = "7.0.1"

$ScriptDir  = $PSScriptRoot
$CapProEXE  = Join-Path $ScriptDir "CapProSW_7_0_1.exe"

$LogDir  = "C:\Windows\Logs\Intune"
$LogFile = Join-Path $LogDir "CapProSW_Install_UserLicense.log"

# Temp location for the dynamically generated response file
$ISSFile = Join-Path $env:TEMP "CapProSW_userlic_silent.iss"

# --- Logging Function --------------------------------------------------------

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$Timestamp  $Message"
    Write-Output $Entry
    Add-Content -Path $LogFile -Value $Entry
}

# --- Pre-flight --------------------------------------------------------------

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-Log "============================================================"
Write-Log "Starting CapProSW 7.0.1 installation (User License mode)"
Write-Log "Running as: $($env:USERNAME)  |  ComputerName: $($env:COMPUTERNAME)"

if (-not (Test-Path $CapProEXE)) {
    Write-Log "ERROR: CapProSW_7_0_1.exe not found at $CapProEXE"
    exit 1
}

# --- Step 1: Generate InstallShield Response File ----------------------------
# Per Kodak Alaris Silent Install Procedure — Scenario 9:
#   Stand-alone | Typical | Internet Access | No Hardware Key | No SSN
#
# SSN is set to the literal string "Silent without SSN" with Result=9999.
# This is the exact format specified in the Kodak documentation for this
# scenario — it is not a placeholder, do not modify these values.
#
# No modification to the .iss file is required per the documentation.
# The Version field under [Application] is updated to reflect 7.0.1.

Write-Log "Step 1: Generating InstallShield response file"

$ISSContent = @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-DlgOrder]
Dlg0={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdLicense2Rtf-0
Count=7
Dlg1={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-WibuInstallDialog-0
Dlg2={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-InstallOption-0
Dlg3={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Software Serial Number-0
Dlg4={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SetupType2-0
Dlg5={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdShowInfoList-0
Dlg6={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdStartCopy2-0
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdLicense2Rtf-0]
Result=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-WibuInstallDialog-0]
Result=1
nWibuInstall=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-InstallOption-0]
Result=1
Sel-0=0
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Software Serial Number-0]
SSN=Silent without SSN
Result=9999
TrialEdition=0
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SetupType2-0]
Result=304
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdShowInfoList-0]
Result=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdStartCopy2-0]
Result=1
[Application]
Name=Kodak Capture Pro Software
Version=$AppVersion
Company=Kodak Alaris Inc.
Lang=0409
[{B29FF64D-7D6F-431B-A8AF-C644309F08CA}-DlgOrder]
Count=0
[{43C0781F-CA07-47F1-8FD6-D7075AC588CA}-DlgOrder]
Count=0
"@

try {
    Set-Content -Path $ISSFile -Value $ISSContent -Encoding ASCII -Force
    Write-Log "Response file written to: $ISSFile"
} catch {
    Write-Log "ERROR: Failed to write response file: $_"
    exit 1
}

# --- Step 2: Install CapProSW ------------------------------------------------

Write-Log "Step 2: Installing CapProSW 7.0.1"

$CapProArgs = "/s /f1`"$ISSFile`""

try {
    $CapProProcess = Start-Process -FilePath $CapProEXE `
                                   -ArgumentList $CapProArgs `
                                   -Wait `
                                   -PassThru `
                                   -NoNewWindow

    Write-Log "CapProSW exit code: $($CapProProcess.ExitCode)"

    if ($CapProProcess.ExitCode -notin @(0, 3010)) {
        Write-Log "ERROR: CapProSW installation failed with exit code $($CapProProcess.ExitCode)"
        exit $CapProProcess.ExitCode
    }
} catch {
    Write-Log "ERROR: Exception during CapProSW installation: $_"
    exit 1
}

# --- Cleanup -----------------------------------------------------------------

if (Test-Path $ISSFile) {
    Remove-Item -Path $ISSFile -Force -ErrorAction SilentlyContinue
    Write-Log "Response file cleaned up"
}

# --- Completion --------------------------------------------------------------

Write-Log "Installation completed successfully — user must activate license on first launch"
Write-Log "============================================================"
exit 0
