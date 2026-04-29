# =============================================================================
# Uninstall.ps1
# Application  : CapProSW 7.0.1 + Kodak License Manager 7.0.1
# Description  : Silently uninstalls CapProSW first, then Kodak License Manager.
#                Cleans up residual registry keys and install directories.
#                Designed for deployment via Microsoft Intune as a Win32 app.
#                Install behavior must be set to "System" in Intune.
# =============================================================================

# --- Configuration -----------------------------------------------------------

$LogDir  = "C:\Windows\Logs\Intune"
$LogFile = Join-Path $LogDir "CapProSW_Uninstall.log"

# Display names as they appear in Add/Remove Programs — adjust if different
$CapProDisplayName   = "Capture Pro Software"
$LicenseMgrDisplayName = "Kodak License Manager"

# Known residual paths — adjust to match actual install locations
$CapProInstallPath   = "C:\Program Files\Kodak\CapturePro"
$LicenseMgrInstallPath = "C:\Program Files\Kodak\LicenseManager"
$KodakRegistryPath   = "HKLM:\SOFTWARE\Kodak"

# Registry locations to search for uninstall strings
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

# --- Logging Function --------------------------------------------------------

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Entry = "$Timestamp  $Message"
    Write-Output $Entry
    Add-Content -Path $LogFile -Value $Entry
}

# --- Registry Lookup Function ------------------------------------------------

function Get-UninstallString {
    param ([string]$DisplayName)

    foreach ($Path in $UninstallPaths) {
        $Keys = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
        foreach ($Key in $Keys) {
            $Name = $Key.GetValue("DisplayName")
            if ($Name -like "*$DisplayName*") {
                return $Key.GetValue("UninstallString")
            }
        }
    }
    return $null
}

# --- Silent Uninstall Function -----------------------------------------------

function Invoke-SilentUninstall {
    param (
        [string]$DisplayName,
        [string]$UninstallString
    )

    Write-Log "Uninstall string found for ${DisplayName}: $UninstallString"

    # Handle both EXE and MsiExec uninstall strings
    if ($UninstallString -match "msiexec") {
        # Strip any existing UI flags and enforce quiet uninstall
        $CleanArgs = $UninstallString -replace "msiexec.exe", "" -replace "/I", "/X"
        $CleanArgs = "$CleanArgs /quiet /norestart"

        Write-Log "Running MsiExec uninstall for $DisplayName"
        $Process = Start-Process -FilePath "msiexec.exe" `
                                 -ArgumentList $CleanArgs `
                                 -Wait `
                                 -PassThru `
                                 -NoNewWindow
    } else {
        # EXE-based uninstaller — append silent flags
        $CleanString = $UninstallString.Trim('"')
        $SilentArgs  = "/S /quiet"    # Verify silent flags with vendor documentation

        Write-Log "Running EXE uninstall for $DisplayName"
        $Process = Start-Process -FilePath $CleanString `
                                 -ArgumentList $SilentArgs `
                                 -Wait `
                                 -PassThru `
                                 -NoNewWindow
    }

    Write-Log "$DisplayName uninstall exit code: $($Process.ExitCode)"

    if ($Process.ExitCode -notin @(0, 3010)) {
        Write-Log "WARNING: $DisplayName uninstall returned unexpected exit code $($Process.ExitCode)"
    }

    return $Process.ExitCode
}

# --- Pre-flight --------------------------------------------------------------

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-Log "============================================================"
Write-Log "Starting CapProSW 7.0.1 uninstallation"
Write-Log "Running as: $($env:USERNAME)  |  ComputerName: $($env:COMPUTERNAME)"

# --- Step 1: Uninstall CapProSW ----------------------------------------------

Write-Log "Step 1: Locating CapProSW in registry"

$CapProUninstall = Get-UninstallString -DisplayName $CapProDisplayName

if ($CapProUninstall) {
    Invoke-SilentUninstall -DisplayName $CapProDisplayName -UninstallString $CapProUninstall
} else {
    Write-Log "CapProSW not found in registry — may already be uninstalled, continuing"
}

# --- Step 2: Uninstall Kodak License Manager ---------------------------------

Write-Log "Step 2: Locating Kodak License Manager in registry"

$LicenseMgrUninstall = Get-UninstallString -DisplayName $LicenseMgrDisplayName

if ($LicenseMgrUninstall) {
    Invoke-SilentUninstall -DisplayName $LicenseMgrDisplayName -UninstallString $LicenseMgrUninstall
} else {
    Write-Log "Kodak License Manager not found in registry — may already be uninstalled, continuing"
}

# --- Step 3: Remove Residual Install Directories -----------------------------

Write-Log "Step 3: Checking for residual install directories"

foreach ($Path in @($CapProInstallPath, $LicenseMgrInstallPath)) {
    if (Test-Path $Path) {
        Write-Log "Removing residual directory: $Path"
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Log "Removed: $Path"
        } catch {
            Write-Log "WARNING: Could not remove $Path — $_"
        }
    } else {
        Write-Log "Directory not found, skipping: $Path"
    }
}

# --- Step 4: Remove Residual Registry Keys -----------------------------------

Write-Log "Step 4: Checking for residual Kodak registry keys"

if (Test-Path $KodakRegistryPath) {
    try {
        Remove-Item -Path $KodakRegistryPath -Recurse -Force -ErrorAction Stop
        Write-Log "Removed residual registry key: $KodakRegistryPath"
    } catch {
        Write-Log "WARNING: Could not remove registry key $KodakRegistryPath — $_"
    }
} else {
    Write-Log "Kodak registry key not found, skipping"
}

# --- Completion --------------------------------------------------------------

Write-Log "Uninstallation completed"
Write-Log "============================================================"
exit 0
