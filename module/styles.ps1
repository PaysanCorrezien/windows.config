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

function Set-DarkMode {
    try {
        Write-Log "Enabling dark mode..."
        
        # Enable dark mode for system
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
        
        # Enable dark mode for apps
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
        
        # Enable dark mode for Explorer
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Themes" -Name "AppsUseLightTheme" -Value 0
        
        Write-Log "Dark mode enabled successfully"
    }
    catch {
        Write-Log "Error enabling dark mode: $_"
        throw
    }
}

function Set-AccentColor {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Default', 'Rose', 'Sky', 'Purple', 'Orange', 'Forest', 'Ocean')]
        [string]$ColorScheme = 'Default'
    )
    
    try {
        Write-Log "Setting accent color to $ColorScheme..."
        
        # Color values in ARGB format (FF + RGB hex)
        $colorMap = @{
            'Default' = 'FF0078D7'  # Windows blue
            'Rose'    = 'FF191724'  # Rose Pine base color
            'Sky'     = 'FF2B90E3'  # Light blue
            'Purple'  = 'FF8A3D8B'  # Royal purple
            'Orange'  = 'FFF7833B'  # Vibrant orange
            'Forest'  = 'FF5F8A2D'  # Forest green
            'Ocean'   = 'FF315CB1'  # Deep blue
        }
        
        $colorHex = $colorMap[$ColorScheme]
        $colorDecimal = [convert]::ToInt32($colorHex, 16)
        
        Write-Log "Setting color $colorHex (decimal: $colorDecimal)"
        
        # Set accent color in all required locations
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -Value $colorDecimal -Type "DWORD"
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentColor" -Value $colorDecimal -Type "DWORD"
        
        # Enable accent color on title bars and windows borders
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 1 -Type "DWORD"
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence" -Value 1 -Type "DWORD"
        
        Write-Log "Accent color set successfully"
        
        # Restart explorer to apply changes
        Restart-Explorer
    }
    catch {
        Write-Log "Error setting accent color: $_"
        throw
    }
}

function Set-Fonts {
    try {
        Write-Log "Starting font installation..."
        
        # Install required fonts using Chocolatey
        $fonts = @(
            "nerd-fonts-firacode",    # Primary coding font
            "nerd-fonts-jetbrainsmono", # Alternative coding font
            "nerd-fonts-hack",        # System font
            "nerd-fonts-cascadiacode" # Terminal font
        )
        
        foreach ($font in $fonts) {
            Write-Log "Installing $font..."
            choco install $font -y
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Warning: Failed to install $font"
            }
        }
        
        # Refresh font cache
        Write-Log "Refreshing font cache..."
        $FONTS = 0x14
        $objShell = New-Object -ComObject Shell.Application
        $objFolder = $objShell.Namespace($FONTS)
        
        # Release COM objects
        $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objShell)
        $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objFolder)
        
        Write-Log "Font installation and cache refresh completed successfully"
        Write-Host "Font installation complete. Please restart applications for the changes to take effect."
    }
    catch {
        Write-Log "Error installing fonts: $_"
        throw
    }
}


function Set-WindowsStyle {
    [CmdletBinding()]
    param (
        [switch]$HideTaskbar,
        [switch]$HideDesktopIcons,
        [ValidateSet('Default', 'Rose', 'Sky', 'Purple', 'Orange', 'Forest', 'Ocean')]
        [string]$AccentColor = 'Default',
        [switch]$EnableDarkMode = $true
    )
    
    try {
        Write-Log "Starting style configuration..."
        
        if ($HideTaskbar) {
            Hide-Taskbar
        }
        
        if ($HideDesktopIcons) {
            Hide-DesktopIcons
        }
        
        if ($EnableDarkMode) {
            Set-DarkMode
        }
        
        Set-AccentColor -ColorScheme $AccentColor
        Set-Fonts
        
        Restart-Explorer
        Write-Log "Style configuration completed successfully"
    }
    catch {
        Write-Log "Critical error in style configuration: $_"
        throw
    }
}

# Return a hashtable of functions instead of using Export-ModuleMember
@{
    'Set-WindowsStyle' = ${function:Set-WindowsStyle}
    'Hide-Taskbar' = ${function:Hide-Taskbar}
    'Hide-DesktopIcons' = ${function:Hide-DesktopIcons}
    'Set-DarkMode' = ${function:Set-DarkMode}
    'Set-AccentColor' = ${function:Set-AccentColor}
    'Set-Fonts' = ${function:Set-Fonts}
}
