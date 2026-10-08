@echo off
rem Launcher: keeps the launch command out of PowerShell history, skips target profiles.
rem Right-click => Run as administrator.

fltmc >nul 2>&1 || (
    echo This launcher must be run as Administrator.
    pause
    exit /b 1
)

cd /d "%~dp0"
REM `%~dp0` is the folder the .cmd lives in, so it works from any drive letter
REM `%*` passes arguments through, so `Run-Triage.cmd -Gui` works
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-triage.ps1" %*
exit /b %ERRORLEVEL%


REM ----- TO TEST APP USING THE PARAMETERS -----

REM powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\run-triage.ps1 -Operator test -CaseNumber T1 -Modules 001_Device
REM echo %ERRORLEVEL%

REM Expect 0 (or 1, which means a collector logged an error and tells you to read the log). Re-run without -CaseNumber and expect 2. Then run .\run-triage.ps1 interactively and .\run-triage.ps1 -Gui to check the other two paths.

REM .\run-triage.ps1 -Operator "Operator" -CaseNumber 26-0001 -Agency "Agency" -Modules 010_Internet -RunEdd

REM .\run-triage.cmd -Op "Operator" -A "Agency" -CN 26-00001 -Edd N -Proc N -Ram N -Zip N -Mods "001","005"

REM To unload the reg hives, use =>

REM reg unload HKU\TRIAGE_S-1-5-21-2365395819-2293360843-1847361048-1001
