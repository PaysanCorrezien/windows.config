@echo off
setlocal enabledelayedexpansion

echo [DEBUG] Starting script...
echo [DEBUG] File to edit: %~f1

set "FILE_PATH=%~f1"
if "%FILE_PATH%"=="" (
    echo [ERROR] No file specified
    exit /b 1
)

:: Create workspace name from filename
for %%F in ("%FILE_PATH%") do (
    set "WORKSPACE_NAME=edit_%%~nxF"
    echo [DEBUG] Base filename: %%~nxF
)
set "WORKSPACE_NAME=%WORKSPACE_NAME: =_%"
set "WORKSPACE_NAME=%WORKSPACE_NAME:.=_%"
echo [DEBUG] Using workspace name: %WORKSPACE_NAME%

:: Get PID of running WezTerm and set socket path
set "WEZTERM_PID="
set "SOCKET_FILE="
for /f "tokens=2" %%p in ('tasklist /fi "imagename eq wezterm-gui.exe" /nh ^| findstr /i "wezterm-gui"') do (
    set "WEZTERM_PID=%%p"
    echo [DEBUG] Found WezTerm PID: %%p
)

if defined WEZTERM_PID (
    set "SOCKET_FILE=C:\Users\admin\.local\share\wezterm\gui-sock-%WEZTERM_PID%"
    if exist "!SOCKET_FILE!" (
        echo [DEBUG] Found matching socket: !SOCKET_FILE!
        goto :try_connect
    )
)

goto :new_window

:try_connect
echo [DEBUG] Using socket: !SOCKET_FILE!
set "WEZTERM_UNIX_SOCKET=!SOCKET_FILE!"

:: Test socket connection
echo [DEBUG] Testing socket connection...
wezterm.exe cli list > nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [DEBUG] Socket connection successful
    
    :: Get window ID and spawn
    for /f "skip=1 tokens=1" %%a in ('wezterm.exe cli list') do (
        echo [DEBUG] Found window ID: %%a
        echo [DEBUG] Spawning in window %%a
        wezterm.exe cli spawn --window-id %%a -- nvim "%FILE_PATH%"
        exit /b 0
    )
) else (
    echo [DEBUG] Socket connection failed
    goto :new_window
)

:new_window
echo [DEBUG] Starting new WezTerm instance...
start "" wezterm.exe start -- nvim "%FILE_PATH%"
