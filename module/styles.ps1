# Import utility functions from utils.ps1
. "$PSScriptRoot\utils.ps1"

function Hide-Taskbar {
    try {
        # Try StuckRects4 first (newer Windows versions)
        $stuckRectsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects4"
        
        # If StuckRects4 doesn't exist, try StuckRects3
        if (-not (Test-Path $stuckRectsPath)) {
            $stuckRectsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
            Write-Log "Using StuckRects3 as fallback"
        }

        # Create the key if it doesn't exist
        if (-not (Test-Path $stuckRectsPath)) {
            New-Item -Path $stuckRectsPath -Force | Out-Null
            Write-Log "Created new StuckRects registry key"
        }

        $stuckRectsValue = [byte[]](
            0x28,0x00,0x00,0x00,
            0xFF,0xFF,0xFF,0xFF,
            0x03,0x00,0x00,0x00,
            0x03,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,
            0x2C,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,
            0x00,0x00,0x00,0x00,
            0x80,0x07,0x00,0x00,
            0x2C,0x00,0x00,0x00
        )
        
        Set-ItemProperty -Path $stuckRectsPath -Name "Settings" -Value $stuckRectsValue
        Write-Log "Successfully configured taskbar settings at: $stuckRectsPath"

        # Additional taskbar settings for reliability
        $explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
        Set-RegistryValue -Path $explorerPath -Name "EnableAutoTray" -Value 1
        Set-RegistryValue -Path "$explorerPath\Advanced" -Name "TaskbarAl" -Value 0
        
    }
    catch {
        Write-Log "Error hiding taskbar: $_"
        throw
    }
}

function Hide-DesktopIcons {
    try {
        $explorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-RegistryValue -Path $explorerPath -Name "HideIcons" -Value 1
        Write-Log "Successfully hidden desktop icons"
    }
    catch {
        Write-Log "Error hiding desktop icons: $_"
        throw
    }
}

function Set-WindowsStyle {
    [CmdletBinding()]
    param (
        [switch]$HideTaskbar,
        [switch]$HideDesktopIcons
    )
    
    try {
        Write-Log "Starting style configuration..."
        
        if ($HideTaskbar) {
            Hide-Taskbar
        }
        
        if ($HideDesktopIcons) {
            Hide-DesktopIcons
        }
        
        Restart-Explorer
        Write-Log "Style configuration completed successfully"
    }
    catch {
        Write-Log "Critical error in style configuration: $_"
        throw
    }
}

function Set-Fonts {
    try {
        Write-Log "Starting font installation..."
        
        # Install FiraCode Nerd Font using Chocolatey
        Write-Log "Installing FiraCode Nerd Font..."
        choco install nerd-fonts-firacode -y
        
        # Refresh font cache
        Write-Log "Refreshing font cache..."
        $FONTS = 0x14
        $objShell = New-Object -ComObject Shell.Application
        $objFolder = $objShell.Namespace($FONTS)
        
        # Release COM objects
        $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objShell)
        $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objFolder)
        
        Write-Log "Font installation and cache refresh completed successfully"
        Write-Host "Font installation complete. Please restart WezTerm for the changes to take effect."
    }
    catch {
        Write-Log "Error installing fonts: $_"
        throw
    }
}

# Return a hashtable of functions instead of using Export-ModuleMember
@{
    'Set-WindowsStyle' = ${function:Set-WindowsStyle}
    'Hide-Taskbar' = ${function:Hide-Taskbar}
    'Hide-DesktopIcons' = ${function:Hide-DesktopIcons}
    'Set-Fonts' = ${function:Set-Fonts}
}
