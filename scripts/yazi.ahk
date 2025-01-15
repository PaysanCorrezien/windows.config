#Requires AutoHotkey v2.0
#SingleInstance Force

; Set working directory to script location
SetWorkingDir(A_ScriptDir)

; Alt + E hotkey
!e:: {
    ; Define the window title (must match the one we set in the PowerShell shortcut)
    windowTitle := "TUI File Explorer - Yazi"
    ; Path to the shortcut we created (adjust the path if you used a different name)
    shortcutPath := A_Desktop "\Yazi File Explorer.lnk"

    ; Check if the window exists
    if (hwnd := WinExist(windowTitle)) {
        ; If window is active, minimize it
        if (WinActive(windowTitle)) {
            WinMinimize(hwnd)
        } else {
            ; Restore and activate the window
            if (WinGetMinMax(windowTitle) = -1) { ; -1 means minimized
                WinRestore(hwnd)
            }
            WinActivate(hwnd)
        }
    } else {
        ; Launch the shortcut if the window doesn't exist
        Run(shortcutPath)
        
        ; Wait for the window to appear (timeout after 10 seconds)
        try {
            hwnd := WinWait(windowTitle,, 10)
            WinActivate(hwnd)
        }
    }
}
