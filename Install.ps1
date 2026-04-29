# =============================================================================
# Install.ps1
# Application  : CapProSW 7.0.1 + Kodak License Manager 7.0.1
# Description  : Silently installs Kodak License Manager followed by CapProSW.
#                Uses InstallShield silent install with a dynamically generated
#                response file (.iss) per the Kodak Alaris Silent Install
#                Procedure documentation.
#                Designed for deployment via Microsoft Intune as a Win32 app.
#                Install behavior must be set to "System" in Intune.
#
# Licensing    : Capture Pro uses a 16-digit Software Serial Number (SSN) and
#                a Registration ID. Both are required for license retrieval.
#                The endpoint must have internet access to reach the Kodak
#                Alaris license server during installation.
#
# References   : Kodak Capture Pro Silent Install Procedure (Scenario 1)
#                Stand-alone | Typical | Internet Access | No Hardware Key
# =============================================================================

# --- Configuration -----------------------------------------------------------
# Replace placeholder values with your actual serial numbers before packaging.
# DO NOT commit populated values to source control.

$SSN            = "INSERT 16-DIGIT SSN HERE"       # 16-digit Software Serial Number
$RegistrationID = "INSERT REGISTRATION ID HERE"    # Format: KC12345678
$AppVersion     = "7.0.1"

$ScriptDir         = $PSScriptRoot
$LicenseManagerEXE = Join-Path $ScriptDir "KodakLicenseManager_7_0_1.exe"
$CapProEXE         = Join-Path $ScriptDir "CapProSW_7_0_1.exe"

$LogDir  = "C:\Windows\Logs\Intune"
$LogFile = Join-Path $LogDir "CapProSW_Install.log"

# Temp location for the dynamically generated response file
$ISSFile = Join-Path $env:TEMP "CapProSW_silent.iss"

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
Write-Log "Starting CapProSW 7.0.1 installation"
Write-Log "Running as: $($env:USERNAME)  |  ComputerName: $($env:COMPUTERNAME)"

if (-not (Test-Path $LicenseManagerEXE)) {
    Write-Log "ERROR: KodakLicenseManager_7_0_1.exe not found at $LicenseManagerEXE"
    exit 1
}

if (-not (Test-Path $CapProEXE)) {
    Write-Log "ERROR: CapProSW_7_0_1.exe not found at $CapProEXE"
    exit 1
}

# Validate placeholders have been replaced before deployment
if ($SSN -like "*INSERT*" -or $RegistrationID -like "*INSERT*") {
    Write-Log "ERROR: Serial number placeholders have not been replaced. Update SSN and RegistrationID before deploying."
    exit 1
}

# --- Step 1: Install Kodak License Manager -----------------------------------
# The License Manager is a prerequisite for offline license operations.
# Silent flag syntax may vary — verify with vendor if this step fails.

Write-Log "Step 1: Installing Kodak License Manager 7.0.1"

try {
    $LMProcess = Start-Process -FilePath $LicenseManagerEXE `
                               -ArgumentList "/s" `
                               -Wait `
                               -PassThru `
                               -NoNewWindow

    Write-Log "Kodak License Manager exit code: $($LMProcess.ExitCode)"

    if ($LMProcess.ExitCode -notin @(0, 3010)) {
        Write-Log "ERROR: Kodak License Manager installation failed with exit code $($LMProcess.ExitCode)"
        exit $LMProcess.ExitCode
    }
} catch {
    Write-Log "ERROR: Exception during Kodak License Manager installation: $_"
    exit 1
}

# --- Step 2: Generate InstallShield Response File ----------------------------
# Per Kodak Alaris Silent Install Procedure — Scenario 1:
#   Stand-alone | Typical | Internet Access | No Legacy Hardware Key
#
# The installer contacts the Kodak Alaris license server using the SSN and
# RegistrationID to retrieve and activate the license automatically.

Write-Log "Step 2: Generating InstallShield response file"

$ISSContent = @"
[InstallShield Silent]
Version=v7.00
File=Response File
[File Transfer]
OverwrittenReadOnly=NoToAll
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-DlgOrder]
Dlg0={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdLicense2Rtf-0
Count=8
Dlg1={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-WibuInstallDialog-0
Dlg2={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-InstallOption-0
Dlg3={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Software Serial Number-0
Dlg4={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Product Registration-1
Dlg5={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SetupType2-0
Dlg6={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdShowInfoList-0
Dlg7={3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdStartCopy2-0
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-SdLicense2Rtf-0]
Result=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-WibuInstallDialog-0]
Result=1
nWibuInstall=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-InstallOption-0]
Result=1
Sel-0=0
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Software Serial Number-0]
SSN=$SSN
Result=1
[{3C08FCA5-C302-4538-BBFB-E2520A6292A3}-Product Registration-1]
RegistrationID=$RegistrationID
Result=1
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
[{4E9DE7F6-8844-40D9-9C81-16C90AB77CB5}-DlgOrder]
Count=0
"@

try {
    Set-Content -Path $ISSFile -Value $ISSContent -Encoding ASCII -Force
    Write-Log "Response file written to: $ISSFile"
} catch {
    Write-Log "ERROR: Failed to write response file: $_"
    exit 1
}

# --- Step 3: Install CapProSW ------------------------------------------------
# Command format per Kodak documentation:
#   CapProSW_7_0_1.exe /s /f1"path_to_response_file.iss"
# No space between /f1 and the quoted path — this is required by InstallShield.

Write-Log "Step 3: Installing CapProSW 7.0.1"

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

Write-Log "Installation completed successfully"
Write-Log "============================================================"
exit 0
