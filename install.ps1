#!/usr/bin/env pwsh
#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

# Import required modules
$modulePath = Join-Path $PSScriptRoot "module"

# Create a new scope for the imports to avoid namespace pollution
$script:utils = . "$modulePath\utils.ps1"
$script:styles = . "$modulePath\styles.ps1"
$script:neovimMenu = . "$modulePath\setup-neovim-menu-entry.ps1"
$script:keyboardLayout = . "$modulePath\keyboard-layout.ps1"
$script:rustInstall = . "$modulePath\Install-rust.ps1"
$script:installStages = . "$modulePath\install-stages.ps1"
$script:systemConfig = . "$modulePath\system-config.ps1"
$script:packageManagement = . "$modulePath\package-management.ps1"
$script:appInstallations = . "$modulePath\app-installations.ps1"
$script:workSetup = . "$modulePath\work-setup.ps1"
$script:edgeConfig = . "$modulePath\edge-config.ps1"

# Import functions into current scope for easier access
${function:Write-Status} = $utils['Write-Status']
${function:Write-Log} = $utils['Write-Log']
${function:Set-StageFlag} = $utils['Set-StageFlag']
${function:Test-StageFlag} = $utils['Test-StageFlag']
${function:Invoke-ExternalCommand} = $utils['Invoke-ExternalCommand']
${function:Set-Env} = $utils['Set-Env']
${function:Reload-Path} = $utils['Reload-Path']
${function:Test-Command} = $utils['Test-Command']
${function:Install-WithWinget} = $utils['Install-WithWinget']
${function:Get-UserConfirmation} = $utils['Get-UserConfirmation']
${function:Handle-Error} = $utils['Handle-Error']
${function:Pause-Script} = $utils['Pause-Script']
${function:Exit-Script} = $utils['Exit-Script']

# Main installation process
Write-Host "`nStarting installation process...`n" -ForegroundColor Cyan

# 1. Initial Windows Setup - Windows Utility
if (-not (Test-StageFlag "windows-utility")) {
    if (-not (& $installStages['Install-WindowsUtility'])) {
        Exit-Script
        return
    }
}

# 2. Initial Windows Setup - Activation
if (-not (Test-StageFlag "windows-activation")) {
    if (-not (& $installStages['Install-WindowsActivation'])) {
        Exit-Script
        return
    }
}

# 3. Keyboard Layout
Write-Status "Checking keyboard layout..." -Status "Checking" -Color "Yellow"
if (-not (Test-KeyboardLayout)) {
    Write-Host "Installing custom keyboard layout..." -ForegroundColor Yellow
    Set-CustomKeyboardLayout
    if (-not $?) {
        if (-not (Handle-Error "Failed to install keyboard layout" "Keyboard Layout Installation")) {
            Exit-Script
            return
        }
    } else {
        Write-Status "Keyboard layout installation" -Status "Installed" -Color "Green"
    }
} else {
    Write-Status "Keyboard layout" -Status "Already installed" -Color "Green"
}

# 4. Style Settings
if (-not (Test-StageFlag "style-settings")) {
    Write-Status "Applying style settings..." -Status "In Progress" -Color "Yellow"
    Set-WindowsStyle -HideTaskbar -HideDesktopIcons -EnableDarkMode -AccentColor 'Rose'
    if (-not $?) {
        if (-not (Handle-Error "Failed to apply style settings" "Style Settings")) {
            Exit-Script
            return
        }
    } else {
        Set-StageFlag "style-settings"
        Write-Status "Style settings" -Status "Applied" -Color "Green"
    }
}

# 5. OpenSSH Setup
if (-not (& $systemConfig['Set-OpenSSH'])) {
    if (-not (Handle-Error "Failed to set up OpenSSH" "OpenSSH Setup")) {
        Exit-Script
        return
    }
}

# 6. Personal Repositories Setup
if (-not (Test-StageFlag "personal-repos-setup")) {
    if (-not (& $installStages['Install-PersonalRepositories'])) {
        if (-not (Handle-Error "Failed to set up personal repositories" "Personal Repositories Setup")) {
            Exit-Script
            return
        }
    }
}

# 7. CLI Utilities Installation
if (-not (Test-StageFlag "cli-utils-setup")) {
    if (-not (& $installStages['Install-CLIUtilities'])) {
        if (-not (Handle-Error "Failed to install CLI utilities" "CLI Utilities Installation")) {
            Exit-Script
            return
        }
    }
}

# 8. Application Installations
if (-not (Test-StageFlag "nextcloud-setup")) {
    if (-not (& $appInstallations['Install-Nextcloud'])) {
        Handle-Error "Failed to install Nextcloud" "Nextcloud Installation"
    }
    Set-StageFlag "nextcloud-setup"
}

if (-not (Test-StageFlag "keepassxc-setup")) {
    if (-not (& $appInstallations['Install-KeePassXC'])) {
        Handle-Error "Failed to install KeePassXC" "KeePassXC Installation"
    }
    Set-StageFlag "keepassxc-setup"
}

if (-not (Test-StageFlag "gpg-setup")) {
    if (-not (& $appInstallations['Install-GnuPG'])) {
        Handle-Error "Failed to install GnuPG" "GnuPG Installation"
    }
    Set-StageFlag "gpg-setup"
}

if (-not (Test-StageFlag "edge-config")) {
    if (-not (& $edgeConfig['Install-EdgeConfiguration'])) {
        Handle-Error "Failed to configure Edge" "Edge Configuration"
    }
    Set-StageFlag "edge-config"
}

if (-not (Test-StageFlag "powertoys-setup")) {
    if (-not (& $appInstallations['Install-PowerToys'])) {
        Handle-Error "Failed to install PowerToys" "PowerToys Installation"
    }
    Set-StageFlag "powertoys-setup"
}

# 9. Work Tools Setup
if (-not (Test-StageFlag "work-tools-setup")) {
    if (-not (& $workSetup['Install-WorkTools'])) {
        Handle-Error "Failed to set up work tools" "Work Tools Setup"
    }
    Set-StageFlag "work-tools-setup"
}

if (-not (Test-StageFlag "uniget-setup")) {
    if (-not (& $workSetup['Install-UniGetUI'])) {
        Handle-Error "Failed to install UniGet UI" "UniGet UI Installation"
    }
    Set-StageFlag "uniget-setup"
}

if (-not (Test-StageFlag "chatgpt-setup")) {
    if (-not (& $workSetup['Install-ChatGPT'])) {
        Handle-Error "Failed to set up ChatGPT" "ChatGPT Setup"
    }
    Set-StageFlag "chatgpt-setup"
}

if (-not (Test-StageFlag "todoist-setup")) {
    if (-not (& $workSetup['Install-Todoist'])) {
        Handle-Error "Failed to install Todoist" "Todoist Installation"
    }
    Set-StageFlag "todoist-setup"
}

# 10. Final System Configurations
if (-not (Test-StageFlag "final-system-config")) {
    if (-not (& $systemConfig['Set-FinalSystemConfigurations'])) {
        Handle-Error "Failed to apply final system configurations" "Final System Configuration"
    }
    Set-StageFlag "final-system-config"
}

# 11. Update Configurations
if (-not (& $systemConfig['Update-ConfigurationRepositories'])) {
    Handle-Error "Failed to update configuration repositories" "Configuration Updates"
}

Write-Host "`nInstallation completed successfully!`n" -ForegroundColor Green
Pause-Script 