#Requires AutoHotkey v2.0
#SingleInstance Force

class App {
    __New(title, shortcutName) {
        this.title := title
        this.shortcutPath := A_Desktop "\" shortcutName ".lnk"
    }
}

apps := Map(
    "yazi", App("TUI File Explorer - Yazi", 
        "Yazi File Explorer"),
    "claude", App("Claude", 
        "Claude"),
    "github", App("GitHub", 
        "GitHub"),
    "youtube", App("YouTube", 
        "YouTube"),
    "chatgpt", App("ChatGPT", 
        "ChatGPT")
)

FindWindow(app) {
    ; Search for the window using both title and class
    return WinExist(app.title " ahk_class Chrome_WidgetWin_1")
}

ToggleWindow(app) {
    hwnd := FindWindow(app)
    
    if (hwnd) {
        if (WinActive("ahk_id " hwnd)) {
            WinMinimize("ahk_id " hwnd)
        } else {
            if (WinGetMinMax("ahk_id " hwnd) = -1) {
                WinRestore("ahk_id " hwnd)
            }
            WinActivate("ahk_id " hwnd)
        }
    } else {
        if FileExist(app.shortcutPath) {
            Run(app.shortcutPath)
        } else {
            MsgBox "Shortcut not found: " app.shortcutPath
        }
    }
}

; Debug - Alt+Shift+X
!+x:: {
    MouseGetPos(,, &mouseWin)
    if mouseWin {
        title := WinGetTitle("ahk_id " mouseWin)
        class := WinGetClass("ahk_id " mouseWin)
        process := WinGetProcessName("ahk_id " mouseWin)
        state := WinGetMinMax("ahk_id " mouseWin)
        active := WinActive("ahk_id " mouseWin) ? "Yes" : "No"
        MsgBox "Window Title: " title 
            . "`nClass: " class 
            . "`nProcess: " process 
            . "`nMinimized: " (state = -1 ? "Yes" : "No")
            . "`nActive: " active
    }
}

; Hotkeys
!e:: ToggleWindow(apps["yazi"])      ; Alt+E for Yazi
; !c:: ToggleWindow(apps["claude"])     ; Alt+C for Claude
!+g:: ToggleWindow(apps["github"])     ; Alt+G for GitHub
; !y:: ToggleWindow(apps["youtube"])    ; Alt+Y for YouTube
; !g:: ToggleWindow(apps["chatgpt"])    ; Alt+I for ChatGP

; Alt+Shift+S for text correction
