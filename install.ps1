#!/usr/bin/env pwsh
#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

# Import required modules
$modulePath = Join-Path $PSScriptRoot "module"

# Initialize logging
$logging = . "$modulePath\logging.ps1"
$Logger = $logging.Logger
$Logger::Initialize($null)  # Use default log file location

$Logger::Section("Windows Configuration Setup")
$Logger::Info("Starting installation process...")

# Import module functions into current scope
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
$script:gitSync = . "$modulePath\git-sync.ps1"

# Import common functions into current scope
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

# 1. Initial Windows Setup - Windows Utility
$Logger::StartTask("Windows Utility Setup")
if (-not (Test-StageFlag "windows-utility"))
{
  if (-not (& $installStages['Install-WindowsUtility']))
  {
    $Logger::Error("Windows Utility installation failed", $null)
    Exit-Script
    return
  }
  Set-StageFlag "windows-utility"
}
$Logger::EndTask($true)

# 2. Initial Windows Setup - Activation
$Logger::StartTask("Windows Activation")
if (-not (Test-StageFlag "windows-activation"))
{
  if (-not (& $installStages['Install-WindowsActivation']))
  {
    $Logger::Error("Windows Activation failed", $null)
    Exit-Script
    return
  }
  Set-StageFlag "windows-activation"
}
$Logger::EndTask($true)

# 3. Keyboard Layout
$Logger::StartTask("Keyboard Layout Setup")
if (-not (Test-KeyboardLayout))
{
  $Logger::Info("Installing custom keyboard layout...")
  Set-CustomKeyboardLayout
  if (-not $?)
  {
    if (-not (Handle-Error "Failed to install keyboard layout" "Keyboard Layout Installation"))
    {
      $Logger::Error("Keyboard layout installation failed", $null)
      Exit-Script
      return
    }
  }
  $Logger::Success("Keyboard layout installed successfully")
  Set-StageFlag "keyboard-layout"
} else
{
  $Logger::Info("Keyboard layout already installed")
}
$Logger::EndTask($true)

# 4. Style Settings
$Logger::StartTask("Style Configuration")
if (-not (Test-StageFlag "style-settings"))
{
  $Logger::Info("Applying style settings...")
  Set-WindowsStyle -HideTaskbar -HideDesktopIcons -EnableDarkMode -AccentColor 'Rose'
  if (-not $?)
  {
    if (-not (Handle-Error "Failed to apply style settings" "Style Settings"))
    {
      $Logger::Error("Style settings application failed", $null)
      Exit-Script
      return
    }
  }
  Set-StageFlag "style-settings"
}
$Logger::EndTask($true)

# 5. OpenSSH Setup
$Logger::StartTask("OpenSSH Configuration")
if (-not (Test-StageFlag "openssh-setup"))
{
  if (-not (& $systemConfig['Set-OpenSSH']))
  {
    if (-not (Handle-Error "Failed to set up OpenSSH" "OpenSSH Setup"))
    {
      $Logger::Error("OpenSSH setup failed", $null)
      Exit-Script
      return
    }
  }
  Set-StageFlag "openssh-setup"
}
$Logger::EndTask($true)

# 6. Personal Repositories Setup
$Logger::StartTask("Personal Repositories Setup")
if (-not (Test-StageFlag "personal-repos-setup"))
{
  if (-not (& $installStages['Install-PersonalRepositories']))
  {
    if (-not (Handle-Error "Failed to set up personal repositories" "Personal Repositories Setup"))
    {
      $Logger::Error("Personal repositories setup failed", $null)
      Exit-Script
      return
    }
  }
  Set-StageFlag "personal-repos-setup"
}
$Logger::EndTask($true)

# 7. CLI Utilities Installation
$Logger::StartTask("CLI Utilities Installation")
if (-not (Test-StageFlag "cli-utils-setup"))
{
  if (-not (& $installStages['Install-CLIUtilities']))
  {
    if (-not (Handle-Error "Failed to install CLI utilities" "CLI Utilities Installation"))
    {
      $Logger::Error("CLI utilities installation failed", $null)
      Exit-Script
      return
    }
  }
  Set-StageFlag "cli-utils-setup"
}
$Logger::EndTask($true)

# 8. Application Installations
$Logger::Section("Application Installations")

# Nextcloud
$Logger::StartTask("Nextcloud Installation")
if (-not (Test-StageFlag "nextcloud-setup"))
{
  if (-not (& $appInstallations['Install-Nextcloud']))
  {
    $Logger::Error("Nextcloud installation failed", $null)
    Handle-Error "Failed to install Nextcloud" "Nextcloud Installation"
  } else 
  {
    Set-StageFlag "nextcloud-setup"
  }
} else
{
  $Logger::Info("Nextcloud already installed, skipping...")
}
$Logger::EndTask($true)

# KeePassXC
$Logger::StartTask("KeePassXC Installation")
if (-not (Test-StageFlag "keepassxc-setup"))
{
  if (-not (& $appInstallations['Install-KeePassXC']))
  {
    $Logger::Error("KeePassXC installation failed", $null)
    Handle-Error "Failed to install KeePassXC" "KeePassXC Installation"
  } else
  {
    Set-StageFlag "keepassxc-setup"
  }
} else
{
  $Logger::Info("KeePassXC already installed, skipping...")
}
$Logger::EndTask($true)

# GnuPG
$Logger::StartTask("GnuPG Installation")
if (-not (Test-StageFlag "gpg-setup"))
{
  if (-not (& $appInstallations['Install-GnuPG']))
  {
    $Logger::Error("GnuPG installation failed", $null)
    Handle-Error "Failed to install GnuPG" "GnuPG Installation"
  } else
  {
    Set-StageFlag "gpg-setup"
  }
} else
{
  $Logger::Info("GnuPG already installed, skipping...")
}
$Logger::EndTask($true)

# Edge Configuration
$Logger::StartTask("Edge Configuration")
if (-not (Test-StageFlag "edge-config"))
{
  if (-not (& $edgeConfig['Install-EdgeConfiguration']))
  {
    $Logger::Error("Edge configuration failed", $null)
    Handle-Error "Failed to configure Edge" "Edge Configuration"
  } else
  {
    Set-StageFlag "edge-config"
  }
} else
{
  $Logger::Info("Edge already configured, skipping...")
}
$Logger::EndTask($true)

# PowerToys
$Logger::StartTask("PowerToys Installation")
if (-not (Test-StageFlag "powertoys-setup"))
{
  if (-not (& $appInstallations['Install-PowerToys']))
  {
    $Logger::Error("PowerToys installation failed", $null)
    Handle-Error "Failed to install PowerToys" "PowerToys Installation"
  } else
  {
    Set-StageFlag "powertoys-setup"
  }
} else
{
  $Logger::Info("PowerToys already installed, skipping...")
}
$Logger::EndTask($true)

# 9. Work Tools Setup
$Logger::Section("Work Tools Setup")
# Main Work Tools
$Logger::StartTask("Work Tools Installation")
if (-not (Test-StageFlag "work-tools-setup"))
{
  if (-not (& $workSetup['Install-WorkTools']))
  {
    $Logger::Error("Work tools setup failed", $null)
    if (-not (Handle-Error "Failed to set up work tools" "Work Tools Setup"))
    {
      $Logger::EndTask($false)
      Exit-Script
      return $false
    }
  } else
  {
    Set-StageFlag "work-tools-setup"
    $Logger::Success("Work tools setup completed successfully")
    $Logger::EndTask($true)
  }
} else
{
  $Logger::Info("Work tools already installed, skipping...")
  $Logger::EndTask($true)
}

# UniGet UI
$Logger::StartTask("UniGet UI Installation")
if (-not (Test-StageFlag "uniget-setup"))
{
  if (-not (& $workSetup['Install-UniGetUI']))
  {
    $Logger::Error("UniGet UI installation failed", $null)
    Handle-Error "Failed to install UniGet UI" "UniGet UI Installation"
  } else
  {
    Set-StageFlag "uniget-setup"
  }
} else
{
  $Logger::Info("UniGet UI already installed, skipping...")
}
$Logger::EndTask($true)

# ChatGPT
$Logger::StartTask("ChatGPT Setup")
if (-not (Test-StageFlag "chatgpt-setup"))
{
  if (-not (& $workSetup['Install-ChatGPT']))
  {
    $Logger::Error("ChatGPT setup failed", $null)
    Handle-Error "Failed to set up ChatGPT" "ChatGPT Setup"
  } else
  {
    Set-StageFlag "chatgpt-setup"
  }
} else
{
  $Logger::Info("ChatGPT already installed, skipping...")
}
$Logger::EndTask($true)

# Todoist
$Logger::StartTask("Todoist Installation")
if (-not (Test-StageFlag "todoist-setup"))
{
  if (-not (& $workSetup['Install-Todoist']))
  {
    $Logger::Error("Todoist installation failed", $null)
    Handle-Error "Failed to install Todoist" "Todoist Installation"
  } else
  {
    Set-StageFlag "todoist-setup"
  }
} else
{
  $Logger::Info("Todoist already installed, skipping...")
}
$Logger::EndTask($true)

# 10. Final System Configurations
$Logger::StartTask("Final System Configuration")
if (-not (Test-StageFlag "final-system-config"))
{
  if (-not (& $systemConfig['Set-FinalSystemConfigurations']))
  {
    $Logger::Error("Final system configuration failed", $null)
    Handle-Error "Failed to apply final system configurations" "Final System Configuration"
  } else
  {
    Set-StageFlag "final-system-config"
  }
} else
{
  $Logger::Info("Final system configuration already completed, skipping...")
}
$Logger::EndTask($true)

# 11. Update Configurations
$Logger::StartTask("Configuration Updates")
if (-not (& $gitSync['Update-ConfigurationRepositories']))
{
  $Logger::Error("Configuration repositories update failed", $null)
  Handle-Error "Failed to update configuration repositories" "Configuration Updates"
}
$Logger::EndTask($true)

$Logger::Section("Installation Complete")
$Logger::Success("Windows configuration setup completed successfully!")
$Logger::Info("Log file location: $($Logger::LogFile)")

Pause-Script
