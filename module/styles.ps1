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
        
        # Color values in ABGR format
        $colorMap = @{
            'Default' = 0xFF0078D7  # Windows blue
            'Rose'    = 0xFF2D7D9A  # Soft pink
            'Sky'     = 0xFFE3A02B  # Light blue
            'Purple'  = 0xFF8B3D8A  # Royal purple
            'Orange'  = 0xFF3B83F7  # Vibrant orange
            'Forest'  = 0xFF2D8A5F  # Forest green
            'Ocean'   = 0xFFB15C31  # Deep blue
        }
        
        $colorValue = $colorMap[$ColorScheme]
        
        # Enable Windows color scheme
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "ColorPrevalence" -Value 1
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "ColorPrevalence" -Value 1
        
        # Set accent color
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AccentColor" -Value $colorValue -Type "DWORD"
        Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -Name "AccentColor" -Value $colorValue -Type "DWORD"
        
        Write-Log "Accent color set successfully"
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

function Install-Cursor {
    try {
        Write-Log "Installing BreezeX-RosePine cursor..."
        
        $cursorPath = Join-Path $PSScriptRoot "..\BreezeX-RosePine-Windows"
        if (-not (Test-Path $cursorPath)) {
            throw "Cursor directory not found at: $cursorPath"
        }

        # Create the destination directory in Windows
        $destDir = "$env:SystemRoot\Cursors\BreezeX-RoséPine Cursors"
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Copy all cursor files
        Get-ChildItem -Path $cursorPath -File -Include "*.cur","*.ani" | ForEach-Object {
            Copy-Item $_.FullName -Destination $destDir -Force
        }

        # Set cursor scheme in registry
        $schemeKey = "HKCU:\Control Panel\Cursors\Schemes"
        $cursorsKey = "HKCU:\Control Panel\Cursors"
        
        if (-not (Test-Path $schemeKey)) {
            New-Item -Path $schemeKey -Force | Out-Null
        }

        # Set cursor scheme
        $cursorMapping = @{
            "AppStarting" = "Work.ani"
            "Arrow"       = "Default.cur"
            "Crosshair"   = "Cross.cur"
            "Hand"        = "Link.cur"
            "Help"        = "Help.cur"
            "IBeam"       = "IBeam.cur"
            "No"          = "Unavailiable.cur"
            "NWPen"       = "Handwriting.cur"
            "SizeAll"     = "Move.cur"
            "SizeNESW"    = "Diagonal_2.cur"
            "SizeNS"      = "Vertical.cur"
            "SizeNWSE"    = "Diagonal_1.cur"
            "SizeWE"      = "Horizontal.cur"
            "UpArrow"     = "Alternate.cur"
            "Wait"        = "Busy.ani"
        }

        # Build the scheme string
        $schemeString = ($cursorMapping.Values | ForEach-Object { "%10%\%CUR_DIR%\$_" }) -join ","
        Set-ItemProperty -Path $schemeKey -Name "BreezeX-RoséPine Cursors" -Value $schemeString

        # Set each cursor individually
        foreach ($cursor in $cursorMapping.GetEnumerator()) {
            $value = Join-Path $destDir $cursor.Value
            Set-ItemProperty -Path $cursorsKey -Name $cursor.Key -Value $value
        }

        # Set scheme as default
        Set-ItemProperty -Path $cursorsKey -Name "(default)" -Value "BreezeX-RoséPine Cursors"
        
        # Force cursor update with both methods
        $signature = @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, String pvParam, uint fWinIni);
'@
        $systemParamInfo = Add-Type -MemberDefinition $signature -Name WinAPICall -Namespace SystemParamInfo -PassThru
        $systemParamInfo::SystemParametersInfo(0x0057, 0, $null, 0x03) | Out-Null  # Changed to 0x03 for SPIF_UPDATEINIFILE | SPIF_SENDCHANGE

        # Additional registry settings to ensure cursor update
        Set-ItemProperty -Path $cursorsKey -Name "Scheme Source" -Value 1
        Set-ItemProperty -Path $cursorsKey -Name "CursorDelay" -Value 1

        Write-Log "Cursor installation completed successfully"
        Write-Host "Please log out and log back in for the cursor changes to take full effect."
    }
    catch {
        Write-Log "Error installing cursor: $_"
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
        [switch]$EnableDarkMode = $true,
        [switch]$InstallCursor = $true
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

        if ($InstallCursor) {
            Install-Cursor
        }
        
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
    'Install-Cursor' = ${function:Install-Cursor}
}
