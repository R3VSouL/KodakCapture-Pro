# Intune Win32 App Packaging — CapProSW 7.0.1 + Kodak License Manager 7.0.1

## Overview

This repository contains PowerShell scripts used to deploy, remove, and detect the **Capture Pro Software (CapProSW)** and its associated **Kodak License Manager** via Microsoft Intune as a Win32 application package (`.intunewin`).

All scripts are designed for fully silent/unattended execution with no user interaction required. License keys are represented as placeholders (`# INSERT LICENSE KEY HERE`) — populate them before deployment. **Do not commit live license keys to this repository.**

---

## Repository Structure

```
/
├── README.md                  ← This file
├── Install.ps1                ← Installs CapProSW and Kodak License Manager
├── Uninstall.ps1              ← Silently removes both applications
└── Detect.ps1                 ← Detects whether the apps are correctly installed
```

---

## Script Descriptions

---

### Install.ps1

**Purpose:** Silently installs the Kodak License Manager first, then CapProSW 7.0.1 in the correct dependency order.

**What it does — step by step:**

1. **Sets execution context** — Confirms the script is running under SYSTEM context as expected by Intune.
2. **Defines file paths** — Points to `KodakLicenseManager_7_0_1.exe` and `CapProSW_7_0_1.exe` relative to the script/package source directory.
3. **Installs Kodak License Manager first** — Runs `KodakLicenseManager_7_0_1.exe` with silent flags (e.g. `/S`, `/quiet`, or `/silent` — confirm with vendor documentation). Waits for the process to fully exit before continuing.
4. **Applies the license key** — After the license manager installs, the script writes or applies the license key using the appropriate method (registry write, CLI call, or config file). The license key value is stored as a placeholder: `# INSERT LICENSE KEY HERE`.
5. **Installs CapProSW** — Runs `CapProSW_7_0_1.exe` with full silent/quiet parameters. Waits for the process to exit.
6. **Checks exit codes** — Evaluates the exit codes from both installers. Exit code `0` = success. Common known codes (like `3010` = reboot required) are handled and logged.
7. **Writes to log** — Outputs timestamped installation results to `C:\Windows\Logs\Intune\CapProSW_Install.log` for troubleshooting.
8. **Returns appropriate exit code** — Exits with `0` on success or a non-zero code on failure so Intune can correctly report deployment status.

**Silent install flags used (adjust per vendor):**
| Executable | Silent Flag |
|---|---|
| `KodakLicenseManager_7_0_1.exe` | `/S /quiet` *(verify with vendor)* |
| `CapProSW_7_0_1.exe` | `/S /quiet` *(verify with vendor)* |

---

### Uninstall.ps1

**Purpose:** Silently removes both CapProSW 7.0.1 and the Kodak License Manager from the endpoint without user interaction.

**What it does — step by step:**

1. **Queries the Windows registry** — Searches `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and the `WOW6432Node` path (for 32-bit apps on 64-bit OS) to locate the uninstall strings for both applications by display name.
2. **Uninstalls CapProSW first** — Calls the found uninstall string with silent flags appended (e.g. `/S`, `/quiet`, `/uninstall`). Waits for process exit.
3. **Uninstalls Kodak License Manager second** — After the main application is removed, calls the License Manager's uninstall string with the same silent approach.
4. **Clears residual registry keys** — Optionally removes any leftover registry entries under `HKLM:\SOFTWARE\Kodak` or similar paths if they are not cleared by the uninstaller automatically.
5. **Removes leftover files/folders** — Checks for and removes known residual install directories (e.g. `C:\Program Files\Kodak\CapturePro`) if they remain after uninstallation.
6. **Writes to log** — Outputs timestamped uninstall results to `C:\Windows\Logs\Intune\CapProSW_Uninstall.log`.
7. **Returns exit code** — Exits `0` on clean removal so Intune marks the uninstall as successful.

---

### Detect.ps1

**Purpose:** Detects whether CapProSW 7.0.1 and the Kodak License Manager are correctly installed. Used by Intune as the **custom detection rule** on the Win32 app configuration.

**What it does — step by step:**

1. **Checks the registry for CapProSW** — Queries `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` (and `WOW6432Node`) for a display name matching `Capture Pro Software` with a `DisplayVersion` of `7.0.1`.
2. **Checks the registry for Kodak License Manager** — Performs the same registry lookup for `KodakLicenseManager` version `7.0.1`.
3. **Optionally verifies the executable exists** — Checks that the main `.exe` or key application file is present on disk at the expected install path (e.g. `C:\Program Files\Kodak\CapturePro\CapProSW.exe`).
4. **Optionally validates license state** — If the license manager writes a detectable state (registry key, file, or license file), the script checks that value to confirm licensing is active. Placeholder: `# INSERT LICENSE VALIDATION LOGIC HERE`.
5. **Outputs detection result:**
   - If **all checks pass** → writes any output to stdout (e.g. `"Installed"`) and exits with code `0`. Intune interprets any stdout output + exit `0` as **detected/compliant**.
   - If **any check fails** → produces no stdout output and exits with a non-zero code. Intune interprets this as **not detected**, triggering a reinstall.
6. **No log file written** — Detection scripts in Intune run frequently; logging is intentionally omitted here to avoid log bloat. Add logging only during testing if needed.

---

## Intune Win32 App Configuration Reference

| Field | Value |
|---|---|
| **Install command** | `powershell.exe -ExecutionPolicy Bypass -File Install.ps1` |
| **Uninstall command** | `powershell.exe -ExecutionPolicy Bypass -File Uninstall.ps1` |
| **Detection rule** | Custom script → `Detect.ps1` |
| **Install behavior** | System |
| **Device restart behavior** | Determine behavior based on return codes |
| **Return code 0** | Success |
| **Return code 3010** | Soft reboot |

---

## License Key Handling

> **Never commit real license keys to this repository.**

All scripts contain the placeholder comment:
```powershell
# INSERT LICENSE KEY HERE
```

Before packaging the `.intunewin` file, replace this placeholder in the script with the actual license key string. The populated scripts are then packaged locally using the **Microsoft Win32 Content Prep Tool** and uploaded to Intune — the license key is never stored in source control.

---

## Packaging Instructions

1. Place all files in a single staging folder:
   ```
   /StagingFolder/
   ├── Install.ps1
   ├── Uninstall.ps1
   ├── Detect.ps1
   ├── CapProSW_7_0_1.exe
   └── KodakLicenseManager_7_0_1.exe
   ```
2. **Insert license keys** into `Install.ps1` and/or `Detect.ps1` before this step.
3. Run the **Microsoft Win32 Content Prep Tool**:
   ```
   IntuneWinAppUtil.exe -c "C:\StagingFolder" -s Install.ps1 -o "C:\Output"
   ```
4. Upload the resulting `.intunewin` file to **Intune > Apps > Windows > Add > Windows app (Win32)**.
5. Configure install/uninstall commands and detection rule per the table above.

---

## Notes

- Confirm exact silent install flags with Kodak/Alaris vendor documentation before finalizing `Install.ps1` and `Uninstall.ps1`.
- Test all three scripts in a **non-production VM** before deploying to Intune.
- Review `C:\Windows\Logs\Intune\` for install/uninstall log output during testing.
- If the application requires a reboot post-install, set Intune's restart behavior accordingly and handle exit code `3010`.
