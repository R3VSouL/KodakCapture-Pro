# =============================================================================
# Detect.ps1
# Application  : CapProSW 7.0.1 + Kodak License Manager 7.0.1
# Description  : Detects whether both applications are correctly installed.
#                Used as the custom detection rule in Intune Win32 app config.
#
# Install path confirmed from Kodak Alaris documentation:
#   C:\Program Files (x86)\Kodak\Capture Pro
#
# Intune Detection Behavior:
#   Detected     : Script exits 0 AND writes any output to stdout
#   Not Detected : Script exits 0 with no stdout output, OR exits non-zero
# =============================================================================

# --- Configuration -----------------------------------------------------------

$CapProDisplayName     = "Capture Pro Software"
$CapProVersion         = "7.0.1"

$LicenseMgrDisplayName = "Kodak License Manager"
$LicenseMgrVersion     = "7.0.1"

# Confirmed install path per Kodak Alaris Silent Install Procedure documentation
$CapProExePath = "C:\Program Files (x86)\Kodak\Capture Pro\CapProSW.exe"

# Registry locations to search
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# --- Registry Lookup Function ------------------------------------------------

function Get-InstalledApp {
    param (
        [string]$DisplayName,
        [string]$Version
    )

    foreach ($Path in $UninstallPaths) {
        $Keys = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
        foreach ($Key in $Keys) {
            $Name             = $Key.GetValue("DisplayName")
            $InstalledVersion = $Key.GetValue("DisplayVersion")

            if ($Name -like "*$DisplayName*" -and $InstalledVersion -like "*$Version*") {
                return $true
            }
        }
    }
    return $false
}

# --- Detection Logic ---------------------------------------------------------

$CapProDetected     = Get-InstalledApp -DisplayName $CapProDisplayName     -Version $CapProVersion
$LicenseMgrDetected = Get-InstalledApp -DisplayName $LicenseMgrDisplayName -Version $LicenseMgrVersion
$ExeExists          = Test-Path $CapProExePath

# --- Result ------------------------------------------------------------------

if ($CapProDetected -and $LicenseMgrDetected -and $ExeExists) {
    Write-Output "Detected: CapProSW $CapProVersion and Kodak License Manager $LicenseMgrVersion are installed"
    exit 0
} else {
    exit 1
}
