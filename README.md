# NOVA ICAC VECTOR Windows Forensic Triage Suite

A PowerShell toolkit for fast, live triage of a Windows computer. It is run from removable media, collects volatile and system artifacts, writes everything to a time-stamped case folder on that media, logs every action in UTC, and hashes the results so they can be verified later.

> **Legal notice.** Use this tool only with lawful authority (a warrant, valid consent, or agency policy). Validate it on a test system before using it on a live case. The examiner is responsible for documenting its use.

> **Important.** Do not open the collected files on the target computer. Move the collection drive to a forensic workstation first.

---

## Contents

1. [Features](#1-features)
2. [Requirements](#2-requirements)
3. [Folder layout](#3-folder-layout)
4. [Setup](#4-setup)
5. [Running the tool](#5-running-the-tool)
6. [What is collected](#6-what-is-collected)
7. [Output layout](#7-output-layout)
8. [Logging, hashing and chain of custody](#8-logging-hashing-and-chain-of-custody)
9. [Configuration](#9-configuration)
10. [Footprint on the target](#10-footprint-on-the-target)
11. [Sensitive data](#11-sensitive-data)
12. [Known limitations](#12-known-limitations)
13. [Troubleshooting](#13-troubleshooting)
14. [Development notes](#14-development-notes)
15. [License](#15-license)

---

## 1. Features

- Ten collection modules (device, users, network, processes, system, prefetch, event logs, firewall, encryption, internet) that can be run all together or selected individually.
- Optional captures using third-party tools: Encrypted Disk Detector, Magnet Process Capture and Magnet RAM Capture.
- Per-user registry data for **every** profile on the machine (logged-on or not), not only the account running the script.
- Browser history, searches and downloads for Chrome, Edge, Brave, Vivaldi, and Firefox (all profiles).
- Three ways to run it: interactive console, fully unattended (for EDR or remote shells), and a GUI.
- Meaningful exit codes for automation.
- Trusted-binary checks: tools in `/bin/` are verified against a SHA-256 manifest and refused if they do not match.
- UTC timestamps in a single log file, a `case_info.json` record of how the run was started, SHA-256 (and MD5) hashes of all evidence, and an optional zip archive with its own hash.

---

## 2. Requirements

| Item             | Requirement                          |
| ---------------- | --------------------------------------------------------- |
| Operating system | Windows 10 / 11 or Windows Server |
| PowerShell       | Windows PowerShell 5.1 (the tested platform) |
| Privileges       | Local Administrator (the tool exits with code 2 otherwise) |
| Collection drive | NTFS or exFAT. Do not use FAT32 (4 GB file limit breaks RAM images). When capturing RAM, free space should exceed installed RAM by about 10 percent |
| Binaries         | The files listed in[Setup](#4-setup), placed in `/bin/` |

---

## 3. Folder layout

```
WinTriageScript/
|-- run-triage.cmd                 Launcher (recommended)
|-- run-triage.ps1                 Entry point: console, unattended and GUI modes
|-- config/
|   |-- TriageConfig.psd1          Shared settings (module list, binaries, event logs, browsers, defaults)
|-- modules/
|   |-- triage.psd1                Module manifest
|   |-- triage.psm1                Orchestrator (Invoke-DfirTriageScan)
|   |-- functions.psm1             Shared helpers (logging, config, hashing helpers, registry, hives)
|   |-- GuiMain.psm1               GUI
|   |-- 001_Device.psm1            Collection modules
|   |-- 002_Users.psm1             "
|   |-- 003_Network.psm1           "
|   |-- 004_Processes.psm1         "
|   |-- 005_System.psm1            "
|   |-- 006_Prefetch.psm1          "
|   |-- 007_EventLogs.psm1         "
|   |-- 008_Firewall.psm1          "
|   |-- 009_Encryption.psm1        "
|   |-- 010_Internet.psm1          "
|   |-- Get_ComputerDetails.psm1   Helper function for the 001_Devices.psm1 module
|   |-- Get_ComputerRam.psm1       Optional captures
|   |-- Get_RunningProcesses.psm1  "
|   |-- Invoke_EDD.psm1            "
|   |-- Get_FileHashes.psm1        File Hashing
|   |-- Get_CaseArchive.psm1       Archiving
|-- bin/                           Third-party and trusted binaries (not stored in git)
|-- _scratch/                      Temporary working folder (created and removed automatically)
|-- Get_BinaryFileHashes.ps1       File that hashes files in the /bin/ folder and creates the .json file
|-- LICENSE
`-- README.md
```

`.gitignore` excludes /`bin/`, `/_scratch/` and `/TESTING/` directories.

---

## 4. Setup

### 4.1 Third-party tools

Download these directly from their publishers and place them in `/bin/` at the root of the folder that contains `run-triage.ps1`:

| File                                                      | Source                                                                                        |
| --------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `sqlite3.exe` (from `sqlite-tools-win-x64-3530100.zip`)   | [SQLite](https://sqlite.org/)                                                                 |
| `PsInfo.exe` (Sysinternals Suite)                         | [PsInfo](https://learn.microsoft.com/en-us/sysinternals/downloads/psinfo)                     |
| `MagnetRAMCapture.exe`                                    | [Magnet RAM Capture](https://www.magnetforensics.com/resources/magnet-ram-capture/)           |
| `MagnetProcessCapture.exe`                                | [Magnet Process Capture](https://www.magnetforensics.com/resources/magnet-process-capture/)   |
| `EDDv310.exe`                                             | [Encrypted Disk Detector](https://www.magnetforensics.com/resources/encrypted-disk-detector/) |

### 4.2 Trusted copies of Windows utilities

To avoid running executables from the computer being examined, copy these from a **known-clean machine of the same Windows build and architecture** into `/bin/`:

`ipconfig.exe`, `NETSTAT.EXE`, `systeminfo.exe`, `whoami.exe`, `net.exe` (and `net1.exe`), `netsh.exe`, `auditpol.exe`, `driverquery.exe`, `openfiles.exe`, `reg.exe`

Also copy each tool's resource file from `/en-US/` (for example `/en-US/netstat.exe.mui`) if it has one. The list is defined under `Binaries` in `/config/TriageConfig.psd1`.

### 4.3 Build the hash manifest

Every file in `/bin/` must be listed in `/bin/__hashes.json`. At start-up the tool re-hashes each file and registers only those that match. A missing or modified tool is refused, and the collector that needs it logs an error instead of running the target's copy.

The helper file `Get_BinaryFilesHashes.ps1` creates the manifest. Run it from the toolkit root after any change to `/bin/`, and make sure it writes `/bin/__hashes.json` (the file name the loader reads).

Record the SHA-256 of `__hashes.json` in your SOP so you can detect tampering with the manifest itself.

---

## 5. Running the tool

### 5.1 Launcher (recommended)

Right-click `run-triage.cmd` and choose **Run as administrator**. The launcher:

- checks for administrator rights,
- starts PowerShell with `-NoLogo -NoProfile -ExecutionPolicy Bypass` (the target's profile scripts are not run, and the launch command is not recorded in PowerShell history),
- passes any arguments through to `run-triage.ps1`.

```bat
run-triage.cmd
run-triage.cmd -Gui
run-triage.cmd -Unattended -Operator "J. Smith" -Agency "Example PD" -CaseNumber 2026-0142 -CaptureRam -CreateArchive -RunEdd -Modules [<Modules>]
```

### 5.2 Interactive console

From an elevated PowerShell prompt:

```powershell
.\run-triage.ps1
```

All questions are asked up front (operator, agency, case number, and which optional captures to run). After you confirm, collection runs with no further prompts. Any value supplied as a parameter is not asked again.

### 5.3 Unattended

For EDR, remote shells, or scheduled use, add `-Unattended`. Nothing is ever prompted. `-Operator` and `-CaseNumber` are required, and optional captures run only if their switch is given.

```powershell
.\run-triage.ps1 -Unattended -Operator "J. Smith" -CaseNumber 2026-0142 -Modules 001_Device,003_Network -OutputRoot D:\Cases
```

The tool also behaves as unattended when no console is available (redirected input or `-NonInteractive`).

### 5.4 GUI

```powershell
.\run-triage.ps1 -Gui
```

Enter the operator, agency and case number, tick the modules and options, and press **Start Triage**. Collection runs in a background runspace so the window stays responsive, and the log is shown live. The window cannot be closed while a run is in progress. Options that are not implemented yet are refused with a message instead of being ignored.

### 5.5 Parameters

| Parameter           | Description |
| ------------------- | ----------- |
| `-Gui`              | Show the graphical interface |
| `-Unattended`       | Never prompt; requires`-Operator` and `-CaseNumber` |
| `-Operator`         | Examiner name recorded in the log and`case_info.json` |
| `-Agency`           | Agency name (optional) |
| `-CaseNumber`       | Case number recorded in the log and`case_info.json` |
| `-Modules`          | One or more of: `001_Device`, `002_Users`, `003_Network`, `004_Process`, `005_System`, `006_Prefetch`, `007_Event_Logs`, `008_Firewall`, `009_Encryption`, `010_Internet`. Default: all |
| `-RunEdd`           | Run Encrypted Disk Detector |
| `-CaptureProcesses` | Run Magnet Process Capture |
| `-CaptureRam`       | Run Magnet RAM Capture |
| `-CreateArchive`    | Create a zip of the case folder when finished |
| `-OutputRoot`       | Folder in which the case folder is created. Default: the toolkit folder |

Run `Get-Help .\run-triage.ps1 -Full` for the built-in help.

### 5.6 Exit codes

| Code | Meaning                                                                                           |
| ---- | ------------------------------------------------------------------------------------------------- |
| 0    | Completed with no logged errors                                                                   |
| 1    | Completed, but at least one collector logged an ERROR (read the log)                              |
| 2    | Could not start: not administrator, bad parameters, or the module or configuration failed to load |
| 3    | Unexpected fatal error                                                                            |

---

## 6. What is collected

Each module writes to its own numbered folder inside the case folder. See the functions in each `.psm1` for the complete list.


1. **001_Device.**  Computer details (OS, install and boot dates, time zone, BIOS, domain role, license status, minimum password length, USB storage setting), PsInfo output,`Get-ComputerInfo`, `systeminfo`, hardware information, disk partitions, start-up programs (machine and per-user Run keys), full file listing of the system drive with timestamps.

2. **002_User.**  Current user (`whoami`), user profiles, local users, Win32 user accounts, PowerShell console history for each user profile.

3. **003_Network.**  IP configuration (`Get-NetIPAddress`, `ipconfig /all`), adapter configuration, established connections with owning process, full `netstat`, `Get-NetTCPConnection`, DNS cache, network locations used by each user (MountPoints2), SMB shares.

4. **004_Process.**  Running processes with command lines, SHA-256 of every running executable, services hosted by`svchost`, running services, drivers (`driverquery`, system drivers).

5. **005_System.**  PnP devices and signed drivers, USB device history, logical and mapped disks, hotfixes, shadow copies, 50 newest DLLs, persistence-related registry locations (AppCertDLLs, AppInit_DLLs, Active Setup, Winlogon values, Session Manager, shell extensions and commands, LSA packages, browser helper objects), UAC and audit policy, boot configuration, Run-dialog history and typed paths (per user), Start menu data, executables under the Windows folder that are not validly signed.

6. **006_Prefetch.**  Metadata for Prefetch files, file listing of the Windows Temp folder and each profile's Roaming and Temp folders.

7. **007_Event_Logs.**  List of available logs and a CSV export of the logs named under`EventLogs` in the configuration file (entry counts are shown as each log is read).

8. **008_Firewall.**  Windows Firewall rules, Microsoft Defender preferences and exclusions, Defender support logs.

9. **009_Encryption.**  BitLocker volume status and recovery protectors (**sensitive**).

10. **010_Internet.**  Temporary internet files (last 5 days), cookies, typed URLs, Internet settings and trusted domains (per user), browser history, visits, search terms and downloads for every profile of every supported browser, with a summary file listing what was found.


### Optional captures

| Switch              | Tool                                           | Output                 |
| --------------------| ---------------------------------------------- | ---------------------- |
| `-RunEdd`           | Encrypted Disk Detector (`/batch`)             | `/EDD/edd_results.txt` |
| `-CaptureProcesses` | Magnet Process Capture (`/saveall`)            | `/Process_Capture/`    |
| `-CaptureRam`       | Magnet RAM Capture (`/accepteula /go /silent`) | `/Ram_Capture/*.raw`   |

Before a RAM capture the tool checks that the destination is not FAT32 and has enough free space, and afterwards checks that a `.raw` file was actually produced.

### User registry hives

For every local, domain or Entra ID profile the tool finds:

- **Logged-on user :** the live hive under `HKEY_USERS\<SID>` is read, and a snapshot is saved with `reg save`.
- **Logged-off user :** `NTUSER.DAT` and its `.LOG1` / `.LOG2` files are copied unchanged into `Registry_Hives\<SID>\`.

A **working copy** is loaded temporarily as `HKU\TRIAGE_<SID>`, read, and unloaded. The original is never loaded.

Registry results from these hives include the user name and SID in every row.

---

## 7. Output layout

The **case folder** is named `yyyyMMdd_HHmmss_<IPv4>_<COMPUTERNAME>` and is created under `-OutputRoot`.

```
<case folder>/
|-- case_info.json              How the run was started (operator, case, options, versions)
|-- 001_Device/                 Contents varies on which modules were selected and which functions ran
|-- 002_Users.psm1/             "
|-- 003_Network.psm1/           "
|-- 004_Processes.psm1/         "
|-- 005_System.psm1/            "
|-- 006_Prefetch.psm1/          "
|-- 007_EventLogs.psm1/         "
|-- 008_Firewall.psm1/          "
|-- 009_Encryption.psm/         "
|-- 010_Internet/               "
|-- EDD/                        (if selected)
|-- Logs/
|   |-- <name>_Script.log       UTC log of everything the tool did
|   |-- task_timings.csv        Time taken by each task
|-- Hash_Results/
|   |-- <name>_hash_values.csv  Hashes of all evidence files
|   |-- final_hashes.csv        Hashes of the closed log and of the CSV above
|-- Registry_Hives/<SID>/       Pristine NTUSER.DAT copies or reg-save snapshots
|-- Process_Capture/            (if selected)
|-- Ram_Capture/                (if selected)
<case folder>.zip               (if selected; RAM image excluded)
<case folder>.zip.sha256        Hash of the zip, stored beside it
```

---

## 8. Logging, hashing and chain of custody

1. **Log.**  Every message is written to `/Logs/<name>_Script.log` as `[ISO-8601 UTC] [LEVEL] message`. Levels are *INFO*, *SUCCESS*, *WARNING*, and *ERROR*. A task that finishes prints how long it took, for example `Process completed. Output saved to 'available_log_files.txt' (3.45 seconds)`.

2. **Case record.**  `case_info.json` stores operator, agency, case number, computer, the account that ran the tool, start time in UTC with the local offset, PowerShell version, the full command line, the options selected, and the SHA-256 of the configuration file used.

3. **Evidence hashes.**  After collection, every file outside `/Logs/` and `/Hash_Results/` is hashed (SHA-256 and MD5, one read per file) into `/Hash_Results/<name>_hash_values.csv`. Paths are relative to the case folder, so the CSV stays valid after the folder is copied.

4. **Closing the log.**  The log is then closed, and nothing more is written to it. `final_hashes.csv` records the SHA-256 of every file in `/Logs/` and of the evidence hash CSV.

5. **Archive.**  With `-CreateArchive`, the case folder is zipped (without `/Ram_Capture/`), re-opened to confirm the entry count, and hashed into `<name>.zip.sha256`.

6. **Record two values.**  The tool prints the SHA-256 of `final_hashes.csv` and of the zip when it finishes. Write both in your case notes.

To verify later, hash each file listed in the CSV and compare it with the recorded value.

---

## 9. Configuration

Shared settings are in `/config/TriageConfig.psd1` and are read through `Get-TriageConfig`. The file is a PowerShell **data file**: it can contain only literal values (strings, numbers, `$true`, `$false`, `$null`, arrays and hashtables). Variables such as `$PSScriptRoot` or `$env:...` are not allowed and cause the tool to exit with code 2.

| Key                   | Purpose                                                                       |
| --------------------- | ----------------------------------------------------------------------------- |
| `SchemaVersion`       | Version of the configuration layout                                           |
| `Branding`            | Tool name, author, and last-updated date shown in the banner                  |
| `Modules`             | Module names, in run order                                                    |
| `Binaries`            | Tool name to path (relative to the toolkit root)                              |
| `Defaults`            | `ScratchFolder`, `HashIncludeMd5`, `ArchiveExcludeFolders`, `TimestampFormat` |
| `ExecutableFileTypes` | File patterns used by the executable searches                                 |
| `EventLogs`           | Logs to export (`Log` = channel name, `File` = output CSV name)               |
| `Browsers`            | Browser name, type (`Chromium` or `Firefox`) and profile root                 |

The loader adds `ToolkitRoot`, the full binary paths, and the SHA-256 of the configuration file itself.

---

## 10. Footprint on the target

The tool is designed to change as little as possible, but running any program changes a live system. Document these in your case notes:

1. **PowerShell history.**  Launching from `run-triage.cmd` keeps the launch command out of PSReadLine history. As a safety net the script also turns off history saving for its own session.

2. **Profiles.**  `-NoProfile` stops the target's PowerShell profile scripts from running.

3. **PsInfo EULA.**  `PsInfo.exe -accepteula` creates `HKCU\Software\Sysinternals\PsInfo\EulaAccepted` for the account running the tool.

4. **Temporary hives.**  Logged-off users' hive copies are loaded briefly under `HKU\TRIAGE_<SID>` from a working copy in `/_scratch/` on the toolkit drive, then unloaded and deleted.

5. **Execution artifacts.**  `powershell.exe` and each tool run from `/bin/` leave the usual traces (Prefetch, Amcache, ShimCache, event logs).

6. **Not used.** The tool does not use `Get-WindowsUpdateLog` or `dism /online`.

---

## 11. Sensitive data

The case folder can contain:

- BitLocker recovery passwords from the `009_Encryption` module,
- browser history, searches, downloads and cookie data,
- PowerShell console history, which may contain credentials,
- copies of user registry hives and, optionally, a RAM image.

Treat the collection drive as sensitive media. Consider protecting it with BitLocker To Go. Recovery passwords are written only to the BitLocker output file, not to the console or the log.

---

## 12. Known limitations

1. This is a **triage** tool, not a forensic image. The system keeps changing while it runs.
1. RAM is captured through the Magnet tool. The order in which items are collected is set in `Invoke-DfirTriageScan`.
1. Browser databases of a running browser may be locked. The tool retries with shared-read access, and reports a `CopyFailed` row in the browser summary if that also fails.
1. Event logs are exported as CSV, not native `.evtx`.
1. Some parsing depends on English output (for example, `net accounts`).
1. Windows PowerShell 5.1 is the supported platform. Several cmdlets used (BitLocker and others) are not available in PowerShell 7.
1. GUI checkboxes for options not yet written (copy of **registry hives**, **Prefetch**, **NTUSER.DAT**, **SRUDB**, and a **full file list**) are refused.
1. Firefox cookies, saved logins and form history are not read.

---

## 13. Troubleshooting

| Symptom                                              | Likely cause and fix |
| ---------------------------------------------------- | -------------------- |
| `CRITICAL: cannot load the triage module`            | Read the message. A missing name means it is not listed in`FunctionsToExport` in `triage.psd1`. A message about a dynamic expression means `/config/TriageConfig.psd1` contains a variable |
| `Configuration file ... is missing the required key` | `/config/TriageConfig.psd1` is missing `Modules`, `Binaries` or `Defaults` |
| `... is missing from /bin/ or failed its hash check`  | The file is not in `/bin/`, or it changed since `__hashes.json` was built. Re-copy it, or rebuild the manifest if the change was intended |
| Exit code 2 from`run-triage.cmd`                     | Not run as administrator, or an unattended run is missing`-Operator` or `-CaseNumber` |
| Exit code 1                                          | Search the log for`[ERROR]` |
| `The process cannot access the file ... .DAT`        | A hive from an interrupted run is still loaded. Run`reg query HKU \| findstr TRIAGE_` and `reg unload HKU\<name>`, or just run the tool again (it unloads leftovers at start). Run from a local folder, not a cloud-synced one |
| The tool seems to hang in the Internet module        | A call to`sqlite3.exe` has no arguments and is waiting at its prompt. Type `.quit`. Calls must pass the database and query as arguments and use `-batch` |
| An event log shows "No data was found"               | The log exists but is empty. This is informational, not an error |
| A usage screen from `net` appears                    | The trusted`net.exe` could not run. Copy `net1.exe` (and its `.mui` file) into `/bin/` and rebuild the manifest |

---

## 14. Development notes

### Adding a collector

1. Write the function inside the relevant `Get-Triage<Name>Data` function. Return data to `Write-OutputToCsv` or `Write-OutputToFile`.
2. Register it in that module's task list with a message and the output file names. The shared runner (`Invoke-TriageTask`) logs the start, catches errors, checks the expected files exist, and prints the elapsed time.
3. Read `HKLM` values through `Invoke-RegistryCommand`. Read per-user registry data through `Export-PerUserRegistry`.
4. Run an external program through `Get-TriageBinary`, and add the tool under `Binaries` in the configuration file. Capture its output with `2>&1` so error text cannot reach the screen.
5. Rebuild `/bin/__hashes.json` if a new binary or other file was added.

### Quality checks

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse
Test-ModuleManifest -Path .\modules\triage.psd1
Import-PowerShellDataFile -Path .\config\TriageConfig.psd1
```

### Repository conventions

- Save `.ps1`, `.psm1` and `.psd1` files as UTF-8 with BOM (required for non-ASCII text in Windows PowerShell 5.1) and CRLF line endings.
- A `.gitattributes` line such as `*.ps1 *.psm1 *.psd1 text eol=crlf` keeps them consistent.
- Test on a lab virtual machine with one logged-on and one logged-off user before using a change on a case.

---

## 15. License

Released under the GNU General Public License, version 3 or later. See [LICENSE](LICENSE). The third-party tools in `/bin/` are not covered by this license; each has its own terms.
