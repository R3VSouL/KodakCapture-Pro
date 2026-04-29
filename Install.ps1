# =============================================================================
# Install.ps1
# Application  : CapProSW 7.0.1 + Kodak License Manager 7.0.1
# Description  : Silently installs Kodak License Manager followed by CapProSW.
#                Designed for deployment via Microsoft Intune as a Win32 app.
#                Install behavior must be set to "System" in Intune.
# =============================================================================

# --- Configuration -----------------------------------------------------------

$LicenseKey       = "INSERT LICENSE KEY HERE"

$ScriptDir        = Split-Path -Parent $MyInvocation.MyCommand.Definition
$LicenseManagerEXE = Join-Path $ScriptDir "KodakLicenseManager_7_0_1.exe"
$CapProEXE         = Join-Path $ScriptDir "CapProSW_7_0_1.exe"

$LogDir           = "C:\Windows\Logs\Intune"
$LogFile          = Join-Path $LogDir "CapProSW_Install.log"

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

# Verify installer files exist before proceeding
if (-not (Test-Path $LicenseManagerEXE)) {
    Write-Log "ERROR: KodakLicenseManager_7_0_1.exe not found at $LicenseManagerEXE"
    exit 1
}

if (-not (Test-Path $CapProEXE)) {
    Write-Log "ERROR: CapProSW_7_0_1.exe not found at $CapProEXE"
    exit 1
}

# --- Step 1: Install Kodak License Manager -----------------------------------

Write-Log "Step 1: Installing Kodak License Manager 7.0.1"

$LMArgs = "/S /quiet"    # Verify silent flags with vendor documentation

try {
    $LMProcess = Start-Process -FilePath $LicenseManagerEXE `
                               -ArgumentList $LMArgs `
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

# --- Step 2: Apply License Key -----------------------------------------------

Write-Log "Step 2: Applying license key"

# INSERT LICENSE APPLICATION LOGIC HERE
# Example options depending on how Kodak License Manager accepts a key:
#
#   Option A - CLI flag:
#     Start-Process -FilePath $LicenseManagerEXE -ArgumentList "/license $LicenseKey /S" -Wait -NoNewWindow
#
#   Option B - Registry write:
#     Set-ItemProperty -Path "HKLM:\SOFTWARE\Kodak\LicenseManager" -Name "LicenseKey" -Value $LicenseKey
#
#   Option C - License file drop:
#     Set-Content -Path "C:\ProgramData\Kodak\license.lic" -Value $LicenseKey
#
# Replace the placeholder below with the correct method per vendor documentation.

Write-Log "License key application placeholder — update with correct method before deployment"

# --- Step 3: Install CapProSW ------------------------------------------------

Write-Log "Step 3: Installing CapProSW 7.0.1"

$CapProArgs = "/S /quiet"    # Verify silent flags with vendor documentation

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

# --- Completion --------------------------------------------------------------

Write-Log "Installation completed successfully"
Write-Log "============================================================"
exit 0
