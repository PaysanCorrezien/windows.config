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

# Import functions into current scope for easier access
${function:Write-Status} = $utils['Write-Status']
${function:Write-Log} = $utils['Write-Log']
${function:Set-StageFlag} = $utils['Set-StageFlag']
${function:Test-StageFlag} = $utils['Test-StageFlag']
${function:Invoke-ExternalCommand} = $utils['Invoke-ExternalCommand']
${function:Set-Env} = $utils['Set-Env']
${function:Reload-Path} = $utils['Reload-Path']
${function:Test-Command} = $utils['Test-Command']

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

function Handle-Error {
    param (
        [string]$ErrorMessage,
        [string]$Stage
    )
    Write-Error $ErrorMessage
    Write-Host "`nAn error occurred during $Stage." -ForegroundColor Red
    Write-Host "You can investigate the error before deciding to continue or exit." -ForegroundColor Yellow
    if (-not (Get-UserConfirmation "Would you like to continue with the rest of the installation?")) {
        Write-Host "Script stopped. You can run it again after fixing the issue." -ForegroundColor Yellow
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        return $false
    }
    Write-Host "Continuing with the next step..." -ForegroundColor Green
    return $true
}

function Pause-Script {
    Write-Host "Press any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Exit-Script {
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    return
}

# Main installation process
Write-Host "`nStarting installation process...`n" -ForegroundColor Cyan

# 1. Initial Windows Setup - Windows Utility
if (-not (Test-StageFlag "windows-utility")) {
    Write-Status "Running Windows setup utility..." -Status "Starting" -Color "Yellow"
    
    try {
        # Run the command directly
        Write-Host "Running Windows setup utility..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm christitus.com/win | iex`"" -Wait -Verb RunAs
        
        Write-Host "`nPlease review and complete the Windows setup utility configuration." -ForegroundColor Yellow
        if (Get-UserConfirmation "Did you successfully complete the Windows setup utility configuration?") {
            Set-StageFlag "windows-utility"
            Write-Status "Windows setup utility" -Status "Completed" -Color "Green"
        } else {
            Write-Host "Windows setup utility was not completed successfully." -ForegroundColor Red
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    } catch {
        Write-Warning "Windows setup utility encountered an error: $_"
        Write-Host "You can try running it manually by opening a new PowerShell window and running:" -ForegroundColor Yellow
        Write-Host "irm christitus.com/win | iex" -ForegroundColor Cyan
        if (-not (Get-UserConfirmation "Would you like to continue with the rest of the installation?")) {
            Write-Host "Press any key to exit..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            return
        }
    }
}

# 2. Initial Windows Setup - Activation
if (-not (Test-StageFlag "windows-activation")) {
    Write-Status "Running Windows activation..." -Status "Starting" -Color "Yellow"
    
    # Activate Windows
    if (-not (Invoke-ExternalCommand -Command 'irm https://get.activated.win | iex' `
            -Description "Windows Activation" -UseShell)) {
        if (-not (Handle-Error "Failed to activate Windows" "Windows Activation")) {
            Exit-Script
            return
        }
    } else {
        Write-Host "`nPlease verify that Windows was activated correctly." -ForegroundColor Yellow
        if (Get-UserConfirmation "Was Windows activated successfully?") {
            Set-StageFlag "windows-activation"
            Write-Status "Windows activation" -Status "Completed" -Color "Green"
        } else {
            if (-not (Handle-Error "Windows activation was not completed successfully" "Windows Activation")) {
                Exit-Script
                return
            }
        }
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
    Set-WindowsStyle -HideTaskbar -HideDesktopIcons
    if (-not $?) {
        if (-not (Handle-Error "Failed to apply style settings" "Style Settings")) {
            Exit-Script
            return
        }
    } else {
        Set-StageFlag "style-settings"
        Write-Status "Style settings" -Status "Applied" -Color "Green"
    }
} else {
    Write-Status "Style settings" -Status "Already configured" -Color "Green"
}

# 5. Scoop Installation
if (-not (Test-ScoopInstallation)) {
    Write-Status "Installing Scoop..." -Status "Starting" -Color "Yellow"
    
    try {
        # Create a temporary script file for Scoop installation
        $tempScriptPath = Join-Path $env:TEMP "install-scoop.ps1"
        @'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-RestMethod -Uri get.scoop.sh | Invoke-Expression
'@ | Set-Content -Path $tempScriptPath

        # Start a new non-elevated PowerShell process to run the script
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = "powershell.exe"
        $startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$tempScriptPath'`""
        $startInfo.UseShellExecute = $true
        $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        
        Write-Host "Starting Scoop installation in a new window. Please wait for it to complete..." -ForegroundColor Yellow
        $process = [System.Diagnostics.Process]::Start($startInfo)
        $process.WaitForExit()

        # Clean up the temporary script
        Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -ne 0) {
            throw "Scoop installation process exited with code: $($process.ExitCode)"
        }

        # Verify Scoop installation
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
            throw "Scoop command not found after installation"
        }

        # Add main bucket
        Write-Host "Adding Scoop main bucket..." -ForegroundColor Yellow
        if (-not (Invoke-ExternalCommand -Command 'scoop bucket add main' -Description "Adding Scoop main bucket")) {
            throw "Failed to add Scoop main bucket"
        }
        
        Write-Status "Scoop installation" -Status "Completed" -Color "Green"
    }
    catch {
        if (-not (Handle-Error "Error during Scoop installation: $_" "Scoop Installation")) {
            Write-Host "`nYou can try installing Scoop manually:" -ForegroundColor Yellow
            Write-Host "1. Open a new PowerShell window (non-admin)" -ForegroundColor Yellow
            Write-Host "2. Run this command:" -ForegroundColor Yellow
            Write-Host "   irm get.scoop.sh | iex" -ForegroundColor Cyan
            Exit-Script
            return
        }
    }
} else {
    Write-Status "Scoop" -Status "Already installed" -Color "Green"
}

# 6. Rust Installation
Write-Status "Checking Rust installation..." -Status "Checking" -Color "Yellow"
if (-not (Test-RustInstallation)) {
    Write-Host "Installing Rust..." -ForegroundColor Yellow
    Install-Rust
    if (-not $?) {
        Handle-Error "Failed to install Rust" "Rust Installation"
    } else {
        Write-Status "Rust installation" -Status "Installed" -Color "Green"
    }
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
            Handle-Error "Failed to install Python" "Python Installation"
        }
        Reload-Path
    }
    
    # Add Git usr/bin to PATH for Yazi
    $gitUsrBinPath = "C:\Program Files\Git\usr\bin"
    if (Test-Path $gitUsrBinPath) {
        if (-not (Invoke-ExternalCommand -Command "Set-Env -Name 'PATH' -Value '$gitUsrBinPath' -Scope 'Machine' -Verbose" `
                -Description "Adding Git usr/bin to PATH")) {
            Handle-Error "Failed to add Git usr/bin to PATH" "Git usr/bin to PATH"
        }
        Reload-Path
    } else {
        Handle-Error "Git usr/bin path not found. Please ensure Git is installed correctly." "Git usr/bin path"
    }
    
    # Install Yazi
    if (-not (Invoke-ExternalCommand -Command 'winget install sxyazi.yazi' `
            -Description "Installing Yazi")) {
        Handle-Error "Failed to install Yazi" "Yazi Installation"
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
            Handle-Error "Failed to install $dep" "Dependency Installation"
        }
    }
    
    # Install rich-cli via pip
    if (-not (Invoke-ExternalCommand -Command 'python -m pip install rich-cli --quiet' `
            -Description "Installing rich-cli")) {
        Handle-Error "Failed to install rich-cli" "rich-cli Installation"
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
        Handle-Error "Failed to install Nextcloud" "Nextcloud Installation"
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
        Handle-Error "Nextcloud setup was not completed successfully" "Nextcloud Setup"
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
        Handle-Error "Failed to install UniGet UI" "UniGet UI Installation"
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
        Handle-Error "UniGet UI setup was not completed successfully" "UniGet UI Setup"
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
        Handle-Error "Failed to install OpenSSH Client" "OpenSSH Client Installation"
    }
    
    # Configure SSH Agent service
    if (-not (Invoke-ExternalCommand -Command 'Set-Service -Name ssh-agent -StartupType Automatic' `
            -Description "Configuring SSH Agent")) {
        Handle-Error "Failed to configure SSH Agent" "SSH Agent Configuration"
    }
    
    if (-not (Invoke-ExternalCommand -Command 'Start-Service ssh-agent' `
            -Description "Starting SSH Agent")) {
        Handle-Error "Failed to start SSH Agent" "SSH Agent Starting"
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
        Handle-Error "Failed to install KeePassXC" "KeePassXC Installation"
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
        Handle-Error "KeePassXC setup was not completed successfully" "KeePassXC Setup"
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
        Handle-Error "Failed to install GnuPG" "GnuPG Installation"
    }
    
    # Reload PATH after GPG installation
    Reload-Path
    
    # Configure Git to use GPG
    if (-not (Invoke-ExternalCommand -Command 'git config --global gpg.program "C:\Program Files (x86)\GnuPG\bin\gpg.exe"' `
            -Description "Configuring Git GPG")) {
        Handle-Error "Failed to configure Git GPG" "Git GPG Configuration"
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
        Handle-Error "GPG setup was not completed successfully" "GPG Setup"
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
        Handle-Error "FortiClient VPN setup was not completed" "FortiClient VPN Setup"
    }
    
    # Install Avaya Workplace
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Download Avaya Workplace" -ForegroundColor Yellow
    Write-Host "2. Install Avaya Workplace" -ForegroundColor Yellow
    Write-Host "3. Disable 'Launch on Startup' in settings" -ForegroundColor Yellow
    
    if (-not (Get-UserConfirmation "Did you install and configure Avaya Workplace?")) {
        Handle-Error "Avaya Workplace setup was not completed" "Avaya Workplace Setup"
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
        Handle-Error "Edge configuration was not completed successfully" "Edge Configuration"
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
        Handle-Error "Failed to add scripts to PATH" "Scripts to PATH"
    }
    
    # Set Neovim as default editor
    if (-not (Invoke-ExternalCommand -Command "[System.Environment]::SetEnvironmentVariable('EDITOR', 'nvim', [System.EnvironmentVariableTarget]::Machine)" `
            -Description "Setting Neovim as default editor")) {
        Handle-Error "Failed to set Neovim as default editor" "Neovim as default editor"
    }
    
    # Add context menu entries
    if (-not (Add-NeovimContextMenu -Verbose)) {
        Handle-Error "Failed to add context menu entries" "Context menu entries"
    }
    
    # Set file associations
    if (-not (Set-FileAssociation -FileExtensions @("txt", "md", "json", "js", "py", "lua", "vim", "sh", "bat", "ps1", "config", "yml", "yaml", "xml", "ini", "conf", "log") -Verbose)) {
        Handle-Error "Failed to set file associations" "File associations"
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
        Handle-Error "Failed to install ChatGPT" "ChatGPT Installation"
    }
    
    Write-Host "`nPlease configure ChatGPT:" -ForegroundColor Yellow
    Write-Host "1. Launch ChatGPT" -ForegroundColor Yellow
    Write-Host "2. Sign in to your OpenAI account" -ForegroundColor Yellow
    Write-Host "3. Configure your preferred settings" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully set up ChatGPT?") {
        Set-StageFlag "chatgpt-setup"
        Write-Status "ChatGPT setup" -Status "Completed" -Color "Green"
    } else {
        Handle-Error "ChatGPT setup was not completed successfully" "ChatGPT Setup"
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
        Handle-Error "Failed to install Todoist" "Todoist Installation"
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
        Handle-Error "Todoist setup was not completed successfully" "Todoist Setup"
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
        Handle-Error "Failed to install PowerToys" "PowerToys Installation"
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
        Handle-Error "PowerToys setup was not completed successfully" "PowerToys Setup"
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
            Handle-Error "Failed to clone Neovim config" "Neovim config cloning"
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
            Handle-Error "Failed to clone WezTerm config" "WezTerm config cloning"
        }
        Write-Status "WezTerm config" -Status "Cloned" -Color "Green"
    } else {
        Write-Status "WezTerm config" -Status "Already exists" -Color "Green"
    }
    
    # Setup Chezmoi
    if (-not (Test-Command "chezmoi")) {
        if (-not (Invoke-ExternalCommand -Command "winget install --id twpayne.chezmoi" `
                -Description "Installing Chezmoi")) {
            Handle-Error "Failed to install Chezmoi" "Chezmoi Installation"
        }
        
        # Reload PATH to ensure chezmoi is available
        Reload-Path
    }
    
    Write-Host "`nInitializing Chezmoi with dotfiles:" -ForegroundColor Yellow
    if (-not (Invoke-ExternalCommand -Command "chezmoi init https://github.com/paysancorrezien/chezmoi-win.git" `
            -Description "Initializing Chezmoi")) {
        Handle-Error "Failed to initialize Chezmoi" "Chezmoi initialization"
    }
    
    Write-Host "`nPlease review Chezmoi changes:" -ForegroundColor Yellow
    Write-Host "1. Review proposed changes with: chezmoi diff" -ForegroundColor Yellow
    Write-Host "2. Apply changes with: chezmoi apply -v" -ForegroundColor Yellow
    
    if (Get-UserConfirmation "Did you successfully review and apply Chezmoi changes?") {
        Set-StageFlag "personal-repos-setup"
        Write-Status "Personal repositories setup" -Status "Completed" -Color "Green"
    } else {
        Handle-Error "Personal repositories setup was not completed successfully" "Personal repositories setup"
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
        Handle-Error "Failed to configure Git SSH command" "Git SSH command configuration"
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
            Handle-Error "Failed to rename computer" "Computer renaming"
        }
        Write-Host "`nComputer has been renamed to '$newName'. A restart will be required for this change to take effect." -ForegroundColor Yellow
    }
    
    Set-StageFlag "final-system-config"
    Write-Status "Final system configurations" -Status "Completed" -Color "Green"
} else {
    Write-Status "Final system configurations" -Status "Already configured" -Color "Green"
}

Write-Host "`nInstallation completed successfully!`n" -ForegroundColor Green
Pause-Script 