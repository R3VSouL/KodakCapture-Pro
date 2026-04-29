# Intune Win32 App Packaging - Kodak Capture Pro Software 7.0.1

## Overview

This repository contains PowerShell scripts used to deploy, remove, and detect **Kodak Capture Pro Software (CapProSW)** and its associated **Kodak License Manager** via Microsoft Intune as a Win32 application package (`.intunewin`).

Capture Pro is a document scanning and capture application by Kodak Alaris. The License Manager is a companion utility required for license retrieval and management on endpoints without a hardware dongle.

All scripts are designed for fully silent, unattended execution with no user interaction. Licensing is handled via a 16-digit Software Serial Number (SSN) and a Registration ID — both represented as placeholders in the install script. These values must be populated before packaging. **Do not commit populated serial numbers to this repository.**

---

## Repository Structure

```
/
├── README.md                        <- This file
├── Install.ps1                      <- Installs Kodak License Manager and CapProSW
├── Uninstall.ps1                    <- Silently removes both applications
├── Detect.ps1                       <- Detects whether both apps are installed
├── CapProSW_7_0_1.exe               <- Capture Pro Software installer (not committed)
└── KodakLicenseManager_7_0_1.exe   <- License Manager installer (not committed)
```

> The EXE files are not stored in this repository. They must be placed in the same staging folder as the scripts before packaging the `.intunewin` file.

---

## Script Descriptions

---

### Install.ps1

Silently installs Kodak License Manager followed by Capture Pro Software 7.0.1 in the correct dependency order. Designed to run under the SYSTEM context via Intune.

**How it works:**

The script first validates that both EXE files are present in the package directory and that the serial number placeholders have been replaced with real values before proceeding. If either check fails, the script exits with a non-zero code and logs the reason.

The Kodak License Manager is installed first using the `/s` silent flag. The script waits for the process to fully exit and evaluates the exit code before continuing.

Capture Pro uses InstallShield for its installer, which requires a response file (`.iss`) to run silently — it cannot be silenced with a simple flag alone. The script dynamically generates this response file at runtime by writing the SSN and Registration ID into the correct InstallShield format, based on Scenario 1 of the official Kodak Alaris Silent Install Procedure documentation (Stand-alone, Typical setup, Internet Access, No Legacy Hardware Key). The response file is written to a temp location and deleted after the install completes.

The installer is then called with the InstallShield silent flag and a pointer to the generated response file:

```
CapProSW_7_0_1.exe /s /f1"<path_to_response_file.iss>"
```

During installation, the Capture Pro installer contacts the Kodak Alaris license server using the provided SSN and Registration ID to retrieve and activate the license. The endpoint must have internet access at time of install for this to succeed.

Exit codes are evaluated after each installer runs. Code `0` is success, code `3010` indicates a soft reboot is required. Any other code is treated as a failure and the script exits immediately with that code so Intune can report the error accurately.

All actions are written with timestamps to `C:\Windows\Logs\Intune\CapProSW_Install.log`.

**Before deploying, populate these two variables at the top of the script:**

| Variable | Description |
|---|---|
| `$SSN` | 16-digit Software Serial Number provided by Kodak Alaris |
| `$RegistrationID` | Registration ID associated with your license, format `KC12345678` |

---

### Uninstall.ps1

Silently removes Capture Pro Software and Kodak License Manager from the endpoint, then cleans up residual files and registry entries.

**How it works:**

The script searches both the 64-bit and 32-bit registry uninstall paths (`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and `WOW6432Node`) for each application by display name. This approach is used rather than hardcoding an uninstall string, as the exact string can vary between machines depending on how the application was originally installed.

Capture Pro is removed first, followed by the License Manager. For each application, the script determines whether the uninstall string is MSI-based (`msiexec`) or EXE-based and handles both cases, appending the appropriate silent flags before invoking the process. The script waits for each uninstaller to fully exit before proceeding.

After both applications are uninstalled, the script checks for and removes any residual install directories and Kodak-related registry keys that the uninstallers may leave behind.

If either application is not found in the registry, the script logs the result and continues rather than failing — this handles scenarios where the app may have already been partially removed.

All actions are written with timestamps to `C:\Windows\Logs\Intune\CapProSW_Uninstall.log`. The script exits with code `0` on completion so Intune marks the uninstall as successful.

---

### Detect.ps1

Detects whether Capture Pro Software 7.0.1 and Kodak License Manager 7.0.1 are correctly installed on the endpoint. This script is used as the custom detection rule in the Intune Win32 app configuration.

**How it works:**

The script searches both the 64-bit and 32-bit registry uninstall paths for each application, matching on both display name and version number `7.0.1`. It also verifies that the Capture Pro executable is present on disk at the confirmed default install path:

```
C:\Program Files (x86)\Kodak\Capture Pro
```

This path is confirmed in the Kodak Alaris Silent Install Procedure documentation. The application installs as 32-bit on 64-bit Windows.

If all checks pass, the script writes output to stdout and exits with code `0`. Intune interprets any stdout output combined with exit code `0` as the application being detected and compliant. If any check fails, the script exits with code `1` and no stdout output, which Intune interprets as not detected and will trigger a reinstall.

No log file is written by this script as detection runs on a recurring schedule and logging would create unnecessary overhead.

---

## Intune Win32 App Configuration

| Field | Value |
|---|---|
| Install command | `powershell.exe -ExecutionPolicy Bypass -File Install.ps1` |
| Uninstall command | `powershell.exe -ExecutionPolicy Bypass -File Uninstall.ps1` |
| Detection rule | Custom script — `Detect.ps1` |
| Install behavior | System |
| Device restart behavior | Determine behavior based on return codes |
| Return code 0 | Success |
| Return code 3010 | Soft reboot |

---

## License and Serial Number Handling

> **Never commit real serial numbers or Registration IDs to this repository.**

The install script contains two placeholders:

```powershell
$SSN            = "INSERT 16-DIGIT SSN HERE"
$RegistrationID = "INSERT REGISTRATION ID HERE"
```

Before packaging, replace these values with the actual credentials provided by Kodak Alaris. The script includes a validation check that will intentionally fail the deployment if the placeholders have not been replaced. Once populated, the scripts are packaged locally using the Microsoft Win32 Content Prep Tool and uploaded to Intune — the serial numbers exist only within the `.intunewin` package and are never stored in source control.

---

## Packaging Instructions

1. Create a staging folder and place all required files together:

```
/StagingFolder/
├── Install.ps1
├── Uninstall.ps1
├── Detect.ps1
├── CapProSW_7_0_1.exe
└── KodakLicenseManager_7_0_1.exe
```

2. Open `Install.ps1` and replace the SSN and Registration ID placeholders with the real values.

3. Run the Microsoft Win32 Content Prep Tool:

```
IntuneWinAppUtil.exe -c "C:\StagingFolder" -s Install.ps1 -o "C:\Output"
```

4. Upload the resulting `.intunewin` file to Intune under Apps > Windows > Add > Windows app (Win32).

5. Configure the install command, uninstall command, and detection rule per the table above.

---

## Requirements

- Endpoints must have internet access at time of installation for the Kodak Alaris license server to activate the license.
- PowerShell execution policy must allow script execution or the Intune install command must include `-ExecutionPolicy Bypass`.
- Install behavior in Intune must be set to System.
- Tested against Windows 10 and Windows 11.
