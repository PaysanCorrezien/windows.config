@echo off
setlocal enabledelayedexpansion

set "FILE_PATH=%~f1"
if "%FILE_PATH%"=="" exit /b 1

set "WEZTERM_PID="
set "SOCKET_FILE="
for /f "tokens=2" %%p in ('tasklist /fi "imagename eq wezterm-gui.exe" /nh ^| findstr /i "wezterm-gui"') do (
    set "WEZTERM_PID=%%p"
)

if defined WEZTERM_PID (
    set "SOCKET_FILE=%USERPROFILE%\.local\share\wezterm\gui-sock-%WEZTERM_PID%"
    if exist "!SOCKET_FILE!" goto :try_connect
)
goto :new_window

:try_connect
set "WEZTERM_UNIX_SOCKET=!SOCKET_FILE!"
wezterm.exe cli list > nul 2>&1
if !ERRORLEVEL! equ 0 (
    for /f "skip=1 tokens=1" %%a in ('wezterm.exe cli list') do (
        wezterm.exe cli spawn --window-id %%a -- nvim "%FILE_PATH%" > nul 2>&1
        exit /b 0
    )
)
goto :new_window

:new_window
start /b "" wezterm.exe start -- nvim "%FILE_PATH%"
