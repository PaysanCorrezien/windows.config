#!/usr/bin/env pwsh
#Requires -RunAsAdministrator
Set-StrictMode -Version 3.0

# Import required modules
$modulePath = Join-Path $PSScriptRoot "module"
. "$modulePath\utils.ps1"
. "$modulePath\styles.ps1"
. "$modulePath\setup-neovim-menu-entry.ps1"
. "$modulePath\keyboard-layout.ps1"
. "$modulePath\Install-rust.ps1"

function Get-UserConfirmation {
    param (
        [string]$Message
    )
    $title = "Confirmation Required"
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Yes", "The action was successful")
        [System.Management.Automation.Host.ChoiceDescription]::new("&No", "The action failed or needs to be retried")
    )
    $decision = $Host.UI.PromptForChoice($title, $Message, $choices, 0)
    return $decision -eq 0
}

function Test-ScoopInstallation {
    return Test-Command "scoop"
}

# Main installation process
Write-Host "`nStarting installation process...`n" -ForegroundColor Cyan

# 1. Initial Windows Setup - Windows Utility
if (-not (Test-StageFlag "windows-utility")) {
    Write-Status "Running Windows setup utility..." -Status "Starting" -Color "Yellow"
    
    # Run Windows setup utility with error handling
    try {
        $setupCommand = 'irm "https://christitus.com/win" | iex'
        if (-not (Invoke-ExternalCommand -Command $setupCommand -Description "Windows Setup Utility" -UseShell)) {
            throw "Failed to run Windows setup utility"
        }
    } catch {
        Write-Warning "Windows setup utility encountered an error: $_"
        Write-Host "You can try running it manually by visiting: https://christitus.com/win" -ForegroundColor Yellow
        if (-not (Get-UserConfirmation "Would you like to continue with the rest of the installation?")) {
            exit 1
        }
    }
    
    Write-Host "`nPlease review and complete the Windows setup utility configuration." -ForegroundColor Yellow
    if (Get-UserConfirmation "Did you successfully complete the Windows setup utility configuration?") {
        Set-StageFlag "windows-utility"
        Write-Status "Windows setup utility" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Windows setup utility was not completed successfully. Please run the script again."
        exit 1
    }
}

# 2. Initial Windows Setup - Activation
if (-not (Test-StageFlag "windows-activation")) {
    Write-Status "Running Windows activation..." -Status "Starting" -Color "Yellow"
    
    # Activate Windows
    if (-not (Invoke-ExternalCommand -Command 'irm https://get.activated.win | iex' `
            -Description "Windows Activation" -UseShell)) {
        Write-Error "Failed to activate Windows"
        exit 1
    }
    
    Write-Host "`nPlease verify that Windows was activated correctly." -ForegroundColor Yellow
    if (Get-UserConfirmation "Was Windows activated successfully?") {
        Set-StageFlag "windows-activation"
        Write-Status "Windows activation" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Windows activation was not completed successfully. Please run the script again."
        exit 1
    }
}

# 3. Keyboard Layout
Write-Status "Checking keyboard layout..." -Status "Checking" -Color "Yellow"
if (-not (Test-KeyboardLayout)) {
    Write-Host "Installing custom keyboard layout..." -ForegroundColor Yellow
    Set-CustomKeyboardLayout
    if (-not $?) {
        Write-Error "Failed to install keyboard layout"
        exit 1
    }
    Write-Status "Keyboard layout installation" -Status "Installed" -Color "Green"
} else {
    Write-Status "Keyboard layout" -Status "Already installed" -Color "Green"
}

# 4. Style Settings
Write-Status "Applying style settings..." -Status "In Progress" -Color "Yellow"
Set-WindowsStyle -HideTaskbar -HideDesktopIcons
if (-not $?) {
    Write-Error "Failed to apply style settings"
    exit 1
}
Write-Status "Style settings" -Status "Applied" -Color "Green"

# 5. Scoop Installation
if (-not (Test-ScoopInstallation)) {
    Write-Status "Installing Scoop..." -Status "Starting" -Color "Yellow"
    
    # Set execution policy and install Scoop
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    if (-not (Invoke-ExternalCommand -Command 'Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression' `
            -Description "Scoop Installation" -UseShell)) {
        Write-Error "Failed to install Scoop"
        exit 1
    }
    
    # Add main bucket
    if (-not (Invoke-ExternalCommand -Command 'scoop bucket add main' `
            -Description "Adding Scoop main bucket")) {
        Write-Error "Failed to add Scoop main bucket"
        exit 1
    }
    
    # Reload PATH after Scoop installation
    Reload-Path
    
    Write-Status "Scoop installation" -Status "Completed" -Color "Green"
} else {
    Write-Status "Scoop" -Status "Already installed" -Color "Green"
}

# 6. Rust Installation
Write-Status "Checking Rust installation..." -Status "Checking" -Color "Yellow"
if (-not (Test-RustInstallation)) {
    Write-Host "Installing Rust..." -ForegroundColor Yellow
    Install-Rust
    if (-not $?) {
        Write-Error "Failed to install Rust"
        exit 1
    }
    Write-Status "Rust installation" -Status "Installed" -Color "Green"
} else {
    Write-Status "Rust" -Status "Already installed" -Color "Green"
}

# 7. Yazi Dependencies
if (-not (Test-StageFlag "yazi-deps")) {
    Write-Status "Installing Yazi and dependencies..." -Status "Starting" -Color "Yellow"
    
    # Check for Python
    if (-not (Test-Command "python")) {
        Write-Status "Python not found. Installing Python..." -Status "Starting" -Color "Yellow"
        if (-not (Invoke-ExternalCommand -Command 'winget install Python.Python.3.11' `
                -Description "Installing Python")) {
            Write-Error "Failed to install Python"
            exit 1
        }
        Reload-Path
    }
    
    # Add Git usr/bin to PATH for Yazi
    $gitUsrBinPath = "C:\Program Files\Git\usr\bin"
    if (Test-Path $gitUsrBinPath) {
        if (-not (Invoke-ExternalCommand -Command "Set-Env -Name 'PATH' -Value '$gitUsrBinPath' -Scope 'Machine' -Verbose" `
                -Description "Adding Git usr/bin to PATH")) {
            Write-Error "Failed to add Git usr/bin to PATH"
            exit 1
        }
        Reload-Path
    } else {
        Write-Error "Git usr/bin path not found. Please ensure Git is installed correctly."
        exit 1
    }
    
    # Install Yazi
    if (-not (Invoke-ExternalCommand -Command 'winget install sxyazi.yazi' `
            -Description "Installing Yazi")) {
        Write-Error "Failed to install Yazi"
        exit 1
    }
    
    # Install dependencies
    $deps = @(
        "Gyan.FFmpeg",
        "7zip.7zip",
        "jqlang.jq",
        "sharkdp.fd",
        "BurntSushi.ripgrep.MSVC",
        "junegunn.fzf",
        "ajeetdsouza.zoxide",
        "ImageMagick.ImageMagick",
        "charmbracelet.glow"
    )
    
    foreach ($dep in $deps) {
        if (-not (Invoke-ExternalCommand -Command "winget install $dep --silent" `
                -Description "Installing $dep")) {
            Write-Error "Failed to install $dep"
            exit 1
        }
    }
    
    # Install rich-cli via pip
    if (-not (Invoke-ExternalCommand -Command 'python -m pip install rich-cli --quiet' `
            -Description "Installing rich-cli")) {
        Write-Error "Failed to install rich-cli"
        exit 1
    }
    
    # Reload PATH after installing all dependencies
    Reload-Path
    
    Set-StageFlag "yazi-deps"
    Write-Status "Yazi dependencies" -Status "Completed" -Color "Green"
} else {
    Write-Status "Yazi dependencies" -Status "Already installed" -Color "Green"
}

# 8. Nextcloud Setup
if (-not (Test-StageFlag "nextcloud-setup")) {
    Write-Status "Installing Nextcloud..." -Status "Starting" -Color "Yellow"
    
    # Install Nextcloud
    if (-not (Invoke-ExternalCommand -Command 'winget install --id=Nextcloud.NextcloudDesktop -e' `
            -Description "Installing Nextcloud")) {
        Write-Error "Failed to install Nextcloud"
        exit 1
    }
    
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Launch Nextcloud" -ForegroundColor Yellow
    Write-Host "2. Log in to your account" -ForegroundColor Yellow
    Write-Host "3. Configure sync settings" -ForegroundColor Yellow
    Write-Host "4. Verify sync is working" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully set up Nextcloud and verify sync is working?") {
        Set-StageFlag "nextcloud-setup"
        Write-Status "Nextcloud setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Nextcloud setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "Nextcloud" -Status "Already installed" -Color "Green"
}

# 9. UniGet UI Setup
if (-not (Test-StageFlag "uniget-setup")) {
    Write-Status "Installing UniGet UI..." -Status "Starting" -Color "Yellow"
    
    # Install UniGet UI
    if (-not (Invoke-ExternalCommand -Command 'winget install --exact --id MartiCliment.UniGetUI --source winget' `
            -Description "Installing UniGet UI")) {
        Write-Error "Failed to install UniGet UI"
        exit 1
    }
    
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Launch UniGet UI" -ForegroundColor Yellow
    Write-Host "2. Accept dependencies" -ForegroundColor Yellow
    Write-Host "3. Load your previous settings" -ForegroundColor Yellow
    Write-Host "4. Reinstall your previous working state" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully set up UniGet UI and restore your settings?") {
        Set-StageFlag "uniget-setup"
        Write-Status "UniGet UI setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "UniGet UI setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "UniGet UI" -Status "Already configured" -Color "Green"
}

# 10. OpenSSH Setup
Write-Status "Setting up OpenSSH..." -Status "Starting" -Color "Yellow"
if (-not (Test-Command "ssh")) {
    # Install OpenSSH Client
    if (-not (Invoke-ExternalCommand -Command 'Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0' `
            -Description "Installing OpenSSH Client")) {
        Write-Error "Failed to install OpenSSH Client"
        exit 1
    }
    
    # Configure SSH Agent service
    if (-not (Invoke-ExternalCommand -Command 'Set-Service -Name ssh-agent -StartupType Automatic' `
            -Description "Configuring SSH Agent")) {
        Write-Error "Failed to configure SSH Agent"
        exit 1
    }
    
    if (-not (Invoke-ExternalCommand -Command 'Start-Service ssh-agent' `
            -Description "Starting SSH Agent")) {
        Write-Error "Failed to start SSH Agent"
        exit 1
    }
    
    Write-Status "OpenSSH setup" -Status "Completed" -Color "Green"
} else {
    Write-Status "OpenSSH" -Status "Already installed" -Color "Green"
}

# 11. KeePassXC Setup
if (-not (Test-StageFlag "keepassxc-setup")) {
    Write-Status "Installing KeePassXC..." -Status "Starting" -Color "Yellow"
    
    # Install KeePassXC
    if (-not (Invoke-ExternalCommand -Command 'winget install --id KeePassXCTeam.KeePassXC' `
            -Description "Installing KeePassXC")) {
        Write-Error "Failed to install KeePassXC"
        exit 1
    }
    
    Write-Host "`nPlease configure KeePassXC:" -ForegroundColor Yellow
    Write-Host "1. Enable SSH Agent integration" -ForegroundColor Yellow
    Write-Host "2. Allow browser authentication" -ForegroundColor Yellow
    Write-Host "3. Test SSH key integration" -ForegroundColor Yellow
    Write-Host "4. Test browser integration" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully configure KeePassXC?") {
        Set-StageFlag "keepassxc-setup"
        Write-Status "KeePassXC setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "KeePassXC setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "KeePassXC" -Status "Already configured" -Color "Green"
}

# 12. GPG Setup
if (-not (Test-StageFlag "gpg-setup")) {
    Write-Status "Installing GnuPG..." -Status "Starting" -Color "Yellow"
    
    # Install GnuPG
    if (-not (Invoke-ExternalCommand -Command 'winget install GnuPG.GnuPG' `
            -Description "Installing GnuPG")) {
        Write-Error "Failed to install GnuPG"
        exit 1
    }
    
    # Reload PATH after GPG installation
    Reload-Path
    
    # Configure Git to use GPG
    if (-not (Invoke-ExternalCommand -Command 'git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"' `
            -Description "Configuring Git GPG")) {
        Write-Error "Failed to configure Git GPG"
        exit 1
    }
    
    Write-Host "`nPlease complete GPG setup:" -ForegroundColor Yellow
    Write-Host "1. Retrieve your private key (private.asc) from your password manager" -ForegroundColor Yellow
    Write-Host "2. Import your key using:" -ForegroundColor Yellow
    Write-Host "   gpg --import private.asc" -ForegroundColor Cyan
    Write-Host "3. Verify the key was imported using:" -ForegroundColor Yellow
    Write-Host "   gpg --list-secret-keys" -ForegroundColor Cyan
    
    if (Get-UserConfirmation "Did you successfully import your GPG key?") {
        Set-StageFlag "gpg-setup"
        Write-Status "GPG setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "GPG setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "GPG" -Status "Already configured" -Color "Green"
}

# 13. Work Tools Setup
if (-not (Test-StageFlag "work-tools-setup")) {
    Write-Status "Setting up work tools..." -Status "Starting" -Color "Yellow"
    
    # Install FortiClient VPN
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Visit https://www.fortinet.com/support/product-downloads" -ForegroundColor Yellow
    Write-Host "2. Download FortiClient VPN" -ForegroundColor Yellow
    Write-Host "3. Install FortiClient VPN" -ForegroundColor Yellow
    Write-Host "4. Disable 'Launch on Startup' in settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you install and configure FortiClient VPN?")) {
        Write-Error "FortiClient VPN setup was not completed. Please run the script again."
        exit 1
    }
    
    # Install Avaya Workplace
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Download Avaya Workplace" -ForegroundColor Yellow
    Write-Host "2. Install Avaya Workplace" -ForegroundColor Yellow
    Write-Host "3. Disable 'Launch on Startup' in settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you install and configure Avaya Workplace?")) {
        Write-Error "Avaya Workplace setup was not completed. Please run the script again."
        exit 1
    }
    
    Set-StageFlag "work-tools-setup"
    Write-Status "Work tools setup" -Status "Completed" -Color "Green"
} else {
    Write-Status "Work tools" -Status "Already configured" -Color "Green"
}

# 14. Edge Configuration
if (-not (Test-StageFlag "edge-config")) {
    Write-Status "Configuring Microsoft Edge..." -Status "Starting" -Color "Yellow"
    
    Write-Host "`nPlease configure Edge:" -ForegroundColor Yellow
    Write-Host "1. Sign in with your Outlook account" -ForegroundColor Yellow
    Write-Host "2. Sign in with your WorkM account" -ForegroundColor Yellow
    Write-Host "3. Verify sync is working" -ForegroundColor Yellow
    Write-Host "4. Install necessary extensions" -ForegroundColor Yellow
    Write-Host "5. Configure your preferred settings" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully configure Edge with both accounts?") {
        Set-StageFlag "edge-config"
        Write-Status "Edge configuration" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Edge configuration was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "Edge configuration" -Status "Already configured" -Color "Green"
}

# 15. Opener Setup
if (-not (Test-StageFlag "opener-setup")) {
    Write-Status "Setting up Neovim opener..." -Status "Starting" -Color "Yellow"
    
    # Add scripts to PATH
    $scriptsPath = Join-Path $PSScriptRoot "scripts"
    if (-not (Invoke-ExternalCommand -Command "Set-Env -Name 'PATH' -Value '$scriptsPath' -Scope 'Machine' -Verbose" `
            -Description "Adding scripts to PATH")) {
        Write-Error "Failed to add scripts to PATH"
        exit 1
    }
    
    # Set Neovim as default editor
    if (-not (Invoke-ExternalCommand -Command "[System.Environment]::SetEnvironmentVariable('EDITOR', 'nvim', [System.EnvironmentVariableTarget]::Machine)" `
            -Description "Setting Neovim as default editor")) {
        Write-Error "Failed to set Neovim as default editor"
        exit 1
    }
    
    # Add context menu entries
    if (-not (Add-NeovimContextMenu -Verbose)) {
        Write-Error "Failed to add context menu entries"
        exit 1
    }
    
    # Set file associations
    if (-not (Set-FileAssociation -FileExtensions @("txt", "md", "json", "js", "py", "lua", "vim", "sh", "bat", "ps1", "config", "yml", "yaml", "xml", "ini", "conf", "log") -Verbose)) {
        Write-Error "Failed to set file associations"
        exit 1
    }
    
    # Reload PATH to ensure changes are available
    Reload-Path
    
    Set-StageFlag "opener-setup"
    Write-Status "Opener setup" -Status "Completed" -Color "Green"
} else {
    Write-Status "Opener" -Status "Already configured" -Color "Green"
}

# 16. ChatGPT Setup
if (-not (Test-StageFlag "chatgpt-setup")) {
    Write-Status "Installing ChatGPT Desktop..." -Status "Starting" -Color "Yellow"
    
    # Install ChatGPT
    if (-not (Invoke-ExternalCommand -Command 'winget install --id=OpenAI.ChatGPT' `
            -Description "Installing ChatGPT Desktop")) {
        Write-Error "Failed to install ChatGPT"
        exit 1
    }
    
    Write-Host "`nPlease configure ChatGPT:" -ForegroundColor Yellow
    Write-Host "1. Launch ChatGPT" -ForegroundColor Yellow
    Write-Host "2. Sign in to your OpenAI account" -ForegroundColor Yellow
    Write-Host "3. Configure your preferred settings" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully set up ChatGPT?") {
        Set-StageFlag "chatgpt-setup"
        Write-Status "ChatGPT setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "ChatGPT setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "ChatGPT" -Status "Already configured" -Color "Green"
}

# 17. Todoist Setup
if (-not (Test-StageFlag "todoist-setup")) {
    Write-Status "Installing Todoist..." -Status "Starting" -Color "Yellow"
    
    # Install Todoist
    if (-not (Invoke-ExternalCommand -Command 'winget install --id Doist.Todoist' `
            -Description "Installing Todoist")) {
        Write-Error "Failed to install Todoist"
        exit 1
    }
    
    Write-Host "`nPlease configure Todoist:" -ForegroundColor Yellow
    Write-Host "1. Launch Todoist and sign in" -ForegroundColor Yellow
    Write-Host "2. Bind Alt + T and Alt + Shift + T for quick actions" -ForegroundColor Yellow
    Write-Host "3. Enable 'Start on Startup'" -ForegroundColor Yellow
    Write-Host "4. Enable 'Run in Background'" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully configure Todoist?") {
        Set-StageFlag "todoist-setup"
        Write-Status "Todoist setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Todoist setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "Todoist" -Status "Already configured" -Color "Green"
}

# 18. PowerToys Setup
if (-not (Test-StageFlag "powertoys-setup")) {
    Write-Status "Installing PowerToys..." -Status "Starting" -Color "Yellow"
    
    # Install PowerToys
    if (-not (Invoke-ExternalCommand -Command 'winget install --id Microsoft.PowerToys' `
            -Description "Installing PowerToys")) {
        Write-Error "Failed to install PowerToys"
        exit 1
    }
    
    # Reload PATH after PowerToys installation
    Reload-Path
    
    Write-Host "`nPlease configure PowerToys:" -ForegroundColor Yellow
    Write-Host "1. Launch PowerToys" -ForegroundColor Yellow
    Write-Host "2. Configure FancyZones for window management" -ForegroundColor Yellow
    Write-Host "3. Set up PowerToys Run shortcuts" -ForegroundColor Yellow
    Write-Host "4. Configure any other modules you need" -ForegroundColor Yellow
    Write-Host "5. Enable 'Run at startup'" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully configure PowerToys?") {
        Set-StageFlag "powertoys-setup"
        Write-Status "PowerToys setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "PowerToys setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "PowerToys" -Status "Already configured" -Color "Green"
}

# 19. Personal Repositories Setup
if (-not (Test-StageFlag "personal-repos-setup")) {
    Write-Status "Setting up personal repositories..." -Status "Starting" -Color "Yellow"
    
    # Create parent directories if needed
    $repoParentPath = "$env:USERPROFILE\repo"
    if (-not (Test-Path $repoParentPath)) {
        New-Item -ItemType Directory -Path $repoParentPath -Force | Out-Null
        Write-Status "Created repositories directory" -Status "Done" -Color "Green"
    }
    
    # Setup Neovim config
    $nvimConfigParent = Split-Path $nvimConfigPath -Parent
    if (-not (Test-Path $nvimConfigParent)) {
        New-Item -ItemType Directory -Path $nvimConfigParent -Force | Out-Null
        Write-Status "Created Neovim config parent directory" -Status "Done" -Color "Green"
    }
    
    $nvimConfigPath = "$env:LOCALAPPDATA\nvim"
    if (-not (Test-Path $nvimConfigPath)) {
        if (-not (Invoke-ExternalCommand -Command "git clone https://github.com/PaysanCorrezien/config.nvim.git $nvimConfigPath" `
                -Description "Cloning Neovim config")) {
            Write-Error "Failed to clone Neovim config"
            exit 1
        }
        Write-Status "Neovim config" -Status "Cloned" -Color "Green"
    } else {
        Write-Status "Neovim config" -Status "Already exists" -Color "Green"
    }
    
    # Setup WezTerm config
    $weztermConfigPath = "$env:USERPROFILE\repo\config.wezterm"
    if (-not (Test-Path $weztermConfigPath)) {
        if (-not (Invoke-ExternalCommand -Command "git clone https://github.com/PaysanCorrezien/config.wezterm $weztermConfigPath" `
                -Description "Cloning WezTerm config")) {
            Write-Error "Failed to clone WezTerm config"
            exit 1
        }
        Write-Status "WezTerm config" -Status "Cloned" -Color "Green"
    } else {
        Write-Status "WezTerm config" -Status "Already exists" -Color "Green"
    }
    
    # Setup Chezmoi
    if (-not (Test-Command "chezmoi")) {
        if (-not (Invoke-ExternalCommand -Command "winget install --id twpayne.chezmoi" `
                -Description "Installing Chezmoi")) {
            Write-Error "Failed to install Chezmoi"
            exit 1
        }
        
        # Reload PATH to ensure chezmoi is available
        Reload-Path
    }
    
    Write-Host "`nInitializing Chezmoi with dotfiles:" -ForegroundColor Yellow
    if (-not (Invoke-ExternalCommand -Command "chezmoi init https://github.com/paysancorrezien/chezmoi-win.git" `
            -Description "Initializing Chezmoi")) {
        Write-Error "Failed to initialize Chezmoi"
        exit 1
    }
    
    Write-Host "`nPlease review Chezmoi changes:" -ForegroundColor Yellow
    Write-Host "1. Review proposed changes with: chezmoi diff" -ForegroundColor Yellow
    Write-Host "2. Apply changes with: chezmoi apply -v" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully review and apply Chezmoi changes?") {
        Set-StageFlag "personal-repos-setup"
        Write-Status "Personal repositories setup" -Status "Completed" -Color "Green"
    } else {
        Write-Error "Personal repositories setup was not completed successfully. Please run the script again."
        exit 1
    }
} else {
    Write-Status "Personal repositories" -Status "Already configured" -Color "Green"
}

# 20. Final System Configurations
if (-not (Test-StageFlag "final-system-config")) {
    Write-Status "Applying final system configurations..." -Status "Starting" -Color "Yellow"
    
    # Configure Git SSH command
    if (-not (Invoke-ExternalCommand -Command 'git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"' `
            -Description "Configuring Git SSH command")) {
        Write-Error "Failed to configure Git SSH command"
        exit 1
    }
    Write-Status "Git SSH configuration" -Status "Completed" -Color "Green"
    
    # Rename computer
    $currentName = $env:COMPUTERNAME
    Write-Host "`nCurrent computer name: $currentName" -ForegroundColor Yellow
    Write-Host "Would you like to rename your computer? If yes, provide a new name." -ForegroundColor Yellow
    $newName = Read-Host "Enter new computer name (or press Enter to skip)"
    
    if ($newName -and ($newName -ne $currentName)) {
        if (-not (Invoke-ExternalCommand -Command "Rename-Computer -NewName '$newName' -Force" `
                -Description "Renaming computer")) {
            Write-Error "Failed to rename computer"
            exit 1
        }
        Write-Host "`nComputer has been renamed to '$newName'. A restart will be required for this change to take effect." -ForegroundColor Yellow
    }
    
    Set-StageFlag "final-system-config"
    Write-Status "Final system configurations" -Status "Completed" -Color "Green"
} else {
    Write-Status "Final system configurations" -Status "Already configured" -Color "Green"
}

Write-Host "`nInstallation completed successfully!`n" -ForegroundColor Green 