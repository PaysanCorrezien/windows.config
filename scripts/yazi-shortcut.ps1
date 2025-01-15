function Create-WeztermYaziShortcut {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]$ShortcutName = "Yazi File Explorer",
        
        [Parameter(Position = 1)]
        [string]$WindowTitle = "TUI File Explorer - Yazi",
        
        [Parameter()]
        [string]$DesktopPath = [System.Environment]::GetFolderPath('Desktop'),
        
        [Parameter()]
        [string]$WezTermPath = "C:\Program Files\WezTerm\wezterm-gui.exe",

        [Parameter()]
        [string]$IconPath = ""
    )

    # Function to find icon file
    function Find-IconFile {
        $possiblePaths = @(
            $IconPath,  # User provided path
            ".\apps\yazi\yazi.ico",  # Current directory git repo structure
            "$PSScriptRoot\apps\yazi\yazi.ico",  # PSScriptRoot git repo structure
            "$env:APPDATA\yazi\yazi.ico",  # AppData location
            $WezTermPath  # Default to WezTerm icon if nothing else found
        )

        foreach ($path in $possiblePaths) {
            if ($path -and (Test-Path $path)) {
                Write-Host "Using icon from: $path"
                return $path
            }
        }

        Write-Host "No custom icon found, using WezTerm icon"
        return $WezTermPath
    }

    # Validate WezTerm installation
    if (-not (Test-Path $WezTermPath)) {
        Write-Error "WezTerm not found at $WezTermPath. Please install WezTerm or correct the path."
        return
    }

    try {
        # Find appropriate icon
        $finalIconPath = Find-IconFile

        # Create shortcut path
        $shortcutPath = Join-Path $DesktopPath "$ShortcutName.lnk"

        # Create the shortcut
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($shortcutPath)

        # Configure the shortcut
        # Using PowerShell with custom window title and launching yazi
        $Shortcut.TargetPath = $WezTermPath
        $Shortcut.Arguments = "-e pwsh.exe -NoExit -Command `"& { `$Host.UI.RawUI.WindowTitle = '$WindowTitle'; yazi }`""
        $Shortcut.WorkingDirectory = Split-Path $WezTermPath -Parent
        $Shortcut.IconLocation = $finalIconPath
        $Shortcut.Save()

        Write-Host "Created shortcut at: $shortcutPath"
        Write-Host "Window Title set to: $WindowTitle"
        Write-Host "Icon set from: $finalIconPath"
    }
    catch {
        Write-Error "Failed to create shortcut: $_"
    }
}
